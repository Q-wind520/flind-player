// Flind Player - cross-platform music player
// Copyright (C) 2026 top.qwind.app
//
// This program is free software: you can redistribute it and/or modify
// it under the terms of the GNU General Public License as published by
// the Free Software Foundation, version 3 of the License.
//
// This program is distributed in the hope that it will be useful,
// but WITHOUT ANY WARRANTY; without even the implied warranty of
// MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
// GNU General Public License for more details.
//
// You should have received a copy of the GNU General Public License
// along with this program.  If not, see <https://www.gnu.org/licenses/>.

import 'dart:io';

import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:flind_player/core/models/track.dart';
import 'package:flind_player/core/models/track_sort.dart';
import 'package:flind_player/core/repositories/settings_repository.dart';
import 'package:flind_player/core/sources/music_source.dart';
import 'package:flind_player/core/sources/source_track_id.dart';
import 'package:flind_player/core/sources/stream_resolver.dart';
import 'package:flind_player/data/cache/audio_cache_store.dart';
import 'package:flind_player/data/cache/audio_downloader.dart';
import 'package:flind_player/data/cache/cached_stream_resolver.dart';
import 'package:flind_player/data/cache/download_manager.dart';
import 'package:flind_player/data/database/app_database.dart';

/// Polls until [condition] is true, failing after [timeout].
Future<void> _waitFor(
  bool Function() condition, {
  Duration timeout = const Duration(seconds: 5),
}) async {
  final deadline = DateTime.now().add(timeout);
  while (!condition()) {
    if (DateTime.now().isAfter(deadline)) {
      fail('Timed out waiting for condition');
    }
    await Future<void>.delayed(const Duration(milliseconds: 10));
  }
}

/// In-memory [SettingsRepository] whose value the test can mutate.
class _FakeSettingsRepository implements SettingsRepository {
  CacheSettings current = CacheSettings.defaults;

  @override
  Future<CacheSettings> cacheSettings() async => current;

  @override
  Future<void> updateCacheSettings(CacheSettings settings) async {
    current = settings;
  }

  @override
  Stream<CacheSettings> watchCacheSettings() =>
      const Stream<CacheSettings>.empty();

  @override
  Future<TrackSort> librarySort() async => TrackSort.title;

  @override
  Future<void> setLibrarySort(TrackSort sort) async {}
}

/// Inner resolver that records its calls.
class _RecordingInner implements StreamResolver {
  int calls = 0;
  final List<Track> tracks = <Track>[];
  Object? error;
  StreamInfo info = StreamInfo(
    url: Uri.parse('https://cdn.example/audio.m4a'),
    headers: const <String, String>{'Referer': 'https://www.bilibili.com/'},
    qualityId: '30280',
  );

  @override
  Future<StreamInfo> resolve(Track track) async {
    calls++;
    tracks.add(track);
    final failure = error;
    if (failure != null) throw failure;
    return info;
  }
}

/// A resolver that is never expected to be called by the manager under test.
class _UnusedResolver implements StreamResolver {
  @override
  Future<StreamInfo> resolve(Track track) async =>
      StreamInfo(url: Uri.parse('https://unused.example/x.m4a'));
}

/// Records the tracks the resolver asked it to cache.
class _SpyManager extends DownloadManager {
  _SpyManager({
    required super.store,
    required super.downloader,
    required super.resolver,
  });

  final List<Track> cachedTracks = <Track>[];
  final List<StreamInfo?> knownInfos = <StreamInfo?>[];

  @override
  Future<void> cacheTrack(
    Track track, {
    bool pinned = false,
    StreamInfo? knownInfo,
  }) async {
    cachedTracks.add(track);
    knownInfos.add(knownInfo);
  }
}

/// A store whose index is always broken, to prove lookups never break playback.
class _ThrowingStore extends AudioCacheStore {
  _ThrowingStore({
    required super.database,
    required super.baseDir,
    required super.settings,
  });

  @override
  Future<CachedAudio?> lookup(String source, String sourceTrackId) async {
    throw StateError('corrupt index');
  }
}

void main() {
  late Directory root;
  late AppDatabase db;
  late _FakeSettingsRepository settings;
  late AudioCacheStore store;
  late _SpyManager manager;
  late _RecordingInner inner;

  const biliTrack = Track(
    source: 'bilibili',
    sourceTrackId: BiliTrackId(bvid: 'BV1GJ411x7h7', cid: 137649199),
    uri: 'bilibili:BV1GJ411x7h7:137649199',
    title: 'Remote Song',
  );

  setUp(() {
    root = Directory.systemTemp.createTempSync('flind_cached_resolver');
    db = AppDatabase(NativeDatabase.memory());
    settings = _FakeSettingsRepository();
    store = AudioCacheStore(database: db, baseDir: root, settings: settings);
    manager = _SpyManager(
      store: store,
      downloader: AudioDownloader(sleeper: (_) async {}),
      resolver: _UnusedResolver(),
    );
    inner = _RecordingInner();
  });

  tearDown(() async {
    await manager.dispose();
    await db.close();
    if (root.existsSync()) {
      root.deleteSync(recursive: true);
    }
  });

  CachedStreamResolver buildResolver({AudioCacheStore? cacheStore}) {
    return CachedStreamResolver(
      inner: inner,
      store: cacheStore ?? store,
      manager: manager,
    );
  }

  /// Inserts a cached row backed by a real file and returns the entry.
  Future<CachedAudio> addCachedEntry({
    List<int> bytes = const <int>[1, 2, 3],
  }) async {
    final file = store.fileFor(
      source: 'bilibili',
      sourceTrackId: cacheSourceTrackId(biliTrack),
      extension: 'm4a',
    );
    file.parent.createSync(recursive: true);
    file.writeAsBytesSync(bytes);
    return store.insert(
      source: 'bilibili',
      sourceTrackId: cacheSourceTrackId(biliTrack),
      filePath: file.path,
      bytes: bytes.length,
      qualityId: '30280',
      pinned: false,
    );
  }

  test('a cache hit returns a file: URI with empty headers', () async {
    final entry = await addCachedEntry();
    // Force an old access time so the touch is observable.
    await (db.update(db.audioCache)..where((t) => t.id.equals(entry.id))).write(
      const AudioCacheCompanion(lastAccessedAt: Value(0)),
    );

    final info = await buildResolver().resolve(biliTrack);

    expect(info.url.scheme, 'file');
    expect(info.url.toFilePath(), entry.filePath);
    expect(info.headers, isEmpty);
    expect(info.expiresAt, isNull);
    expect(inner.calls, 0);
    expect(manager.cachedTracks, isEmpty);

    final touched = await store.lookup(
      'bilibili',
      cacheSourceTrackId(biliTrack),
    );
    expect(touched!.lastAccessedAt.millisecondsSinceEpoch, greaterThan(0));
  });

  test(
    'a cached row whose file vanished falls through to the inner resolver',
    () async {
      final entry = await addCachedEntry();
      File(entry.filePath).deleteSync();

      final info = await buildResolver().resolve(biliTrack);

      expect(inner.calls, 1);
      expect(info.url, inner.info.url);
    },
  );

  test(
    'a miss returns the inner info unchanged and enqueues auto-caching',
    () async {
      final info = await buildResolver().resolve(biliTrack);

      expect(info, same(inner.info));
      expect(inner.calls, 1);

      await _waitFor(() => manager.cachedTracks.isNotEmpty);
      expect(manager.cachedTracks.single, biliTrack);
      expect(manager.knownInfos.single, same(inner.info));
    },
  );

  test('a local file miss does not enqueue a download', () async {
    final localTrack = Track(
      source: 'local',
      sourceTrackId: const LocalTrackId('/music/song.mp3'),
      uri: 'local:/music/song.mp3',
      title: 'Local Song',
    );
    inner.info = StreamInfo(url: Uri.file('/music/song.mp3'));

    await buildResolver().resolve(localTrack);
    await Future<void>.delayed(Duration.zero);

    expect(inner.calls, 1);
    expect(manager.cachedTracks, isEmpty);
  });

  test('an inner resolver failure propagates normally', () async {
    inner.error = StateError('network down');

    await expectLater(
      buildResolver().resolve(biliTrack),
      throwsA(
        isA<StateError>().having((e) => e.message, 'message', 'network down'),
      ),
    );
  });

  test(
    'a broken cache index still lets the inner resolver serve playback',
    () async {
      final broken = _ThrowingStore(
        database: db,
        baseDir: root,
        settings: settings,
      );

      final info = await buildResolver(cacheStore: broken).resolve(biliTrack);

      expect(inner.calls, 1);
      expect(info, same(inner.info));
    },
  );
}
