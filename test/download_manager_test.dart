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

import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';

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
import 'package:flind_player/data/cache/download_manager.dart';
import 'package:flind_player/data/database/app_database.dart';

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

/// Records resolve calls and returns a fixed [StreamInfo].
class _FakeResolver implements StreamResolver {
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

/// Writes [bytes] to [target], reporting completion, and returns the size.
Future<int> _writeFile(
  File target,
  void Function(int received, int? total)? onProgress, {
  List<int>? bytes,
}) async {
  final data = bytes ?? utf8.encode('flind-audio-payload');
  target.parent.createSync(recursive: true);
  target.writeAsBytesSync(data);
  onProgress?.call(data.length, data.length);
  return data.length;
}

typedef _DownloadHandler = Future<int> Function(
  Uri url,
  Map<String, String> headers,
  File target,
  void Function(int received, int? total)? onProgress,
);

/// [AudioDownloader] stand-in that never touches the network.
class _FakeDownloader extends AudioDownloader {
  _FakeDownloader() : super(sleeper: (_) async {});

  _DownloadHandler? handler;
  int calls = 0;
  final List<Uri> urls = <Uri>[];

  @override
  Future<int> download({
    required Uri url,
    required Map<String, String> headers,
    required File target,
    void Function(int received, int? total)? onProgress,
  }) {
    calls++;
    urls.add(url);
    final custom = handler;
    if (custom != null) {
      return custom(url, headers, target, onProgress);
    }
    return _writeFile(target, onProgress);
  }
}

void main() {
  late Directory root;
  late AppDatabase db;
  late _FakeSettingsRepository settings;
  late AudioCacheStore store;
  late _FakeResolver resolver;
  late _FakeDownloader downloader;
  late DownloadManager manager;

  const biliTrack = Track(
    source: 'bilibili',
    sourceTrackId: BiliTrackId(bvid: 'BV1GJ411x7h7', cid: 137649199),
    uri: 'bilibili:BV1GJ411x7h7:137649199',
    title: 'Remote Song',
  );

  setUp(() {
    root = Directory.systemTemp.createTempSync('flind_download_manager');
    db = AppDatabase(NativeDatabase.memory());
    settings = _FakeSettingsRepository();
    store = AudioCacheStore(database: db, baseDir: root, settings: settings);
    resolver = _FakeResolver();
    downloader = _FakeDownloader();
    manager = DownloadManager(
      store: store,
      downloader: downloader,
      resolver: resolver,
      settings: settings,
    );
  });

  tearDown(() async {
    await manager.dispose();
    await db.close();
    if (root.existsSync()) {
      root.deleteSync(recursive: true);
    }
  });

  /// Inserts a pinned entry backed by a real file of [bytes] zero bytes.
  Future<CachedAudio> addPinned(String trackId, int bytes) async {
    final file = store.fileFor(
      source: 'bilibili',
      sourceTrackId: trackId,
      extension: 'm4a',
    );
    file.parent.createSync(recursive: true);
    file.writeAsBytesSync(List<int>.filled(bytes, 0));
    return store.insert(
      source: 'bilibili',
      sourceTrackId: trackId,
      filePath: file.path,
      bytes: bytes,
      qualityId: '30280',
      pinned: true,
    );
  }

  test('cacheTrack downloads, indexes and marks the track cached', () async {
    final events = <DownloadProgress>[];
    final subscription = manager.progress.listen(events.add);
    addTearDown(subscription.cancel);

    await manager.cacheTrack(biliTrack);

    expect(await manager.isCached(biliTrack), isTrue);
    final entry = await store.lookup('bilibili', cacheSourceTrackId(biliTrack));
    expect(entry, isNotNull);
    expect(entry!.bytes, greaterThan(0));
    expect(entry.bytes, File(entry.filePath).lengthSync());
    expect(entry.pinned, isFalse);
    expect(entry.qualityId, '30280');
    expect(entry.filePath, endsWith('.m4a'));

    final phases = events.map((event) => event.phase).toList();
    expect(
      phases,
      containsAll(<DownloadPhase>[
        DownloadPhase.queued,
        DownloadPhase.downloading,
        DownloadPhase.done,
      ]),
    );
  });

  test('a second cacheTrack is a no-op skipped event', () async {
    await manager.cacheTrack(biliTrack);
    expect(downloader.calls, 1);

    final events = <DownloadProgress>[];
    final subscription = manager.progress.listen(events.add);
    addTearDown(subscription.cancel);

    await manager.cacheTrack(biliTrack);

    expect(downloader.calls, 1);
    expect(events.last.phase, DownloadPhase.skipped);
  });

  test('pinning an already cached track flips the flag, not skip', () async {
    await manager.cacheTrack(biliTrack);
    expect(downloader.calls, 1);

    final cached = await store.lookup(
      biliTrack.source,
      cacheSourceTrackId(biliTrack),
    );
    expect(cached, isNotNull);
    expect(cached!.pinned, isFalse);

    final events = <DownloadProgress>[];
    final subscription = manager.progress.listen(events.add);
    addTearDown(subscription.cancel);

    await manager.cacheTrack(biliTrack, pinned: true);

    expect(downloader.calls, 1, reason: 'must not download again');
    final repinned = await store.lookup(
      biliTrack.source,
      cacheSourceTrackId(biliTrack),
    );
    expect(repinned!.pinned, isTrue);
    expect(events.last.phase, DownloadPhase.done);
  });

  test('an oversized single file is rejected after download', () async {
    // Budget is 500 bytes; the payload turns out to be 1000.
    settings.current = CacheSettings.defaults.copyWith(limitBytes: 500);
    downloader.handler = (url, headers, target, onProgress) async {
      final payload = List<int>.filled(1000, 0);
      target.parent.createSync(recursive: true);
      target.writeAsBytesSync(payload);
      onProgress?.call(payload.length, payload.length);
      return payload.length;
    };

    final events = <DownloadProgress>[];
    final subscription = manager.progress.listen(events.add);
    addTearDown(subscription.cancel);

    await manager.cacheTrack(biliTrack);

    expect(events.last.phase, DownloadPhase.failed);
    expect(await store.entries(), isEmpty, reason: 'must not be indexed');
    expect(await manager.isCached(biliTrack), isFalse);
  });

  test('concurrent calls run one download at a time', () async {
    var inFlight = 0;
    var maxInFlight = 0;
    final started = Completer<void>();
    final gate = Completer<void>();

    downloader.handler = (url, headers, target, onProgress) async {
      inFlight++;
      maxInFlight = max(maxInFlight, inFlight);
      if (!started.isCompleted) started.complete();
      await gate.future;
      final result = await _writeFile(target, onProgress);
      inFlight--;
      return result;
    };

    final secondTrack = biliTrack.copyWith(
      sourceTrackId: const BiliTrackId(bvid: 'BV1GJ411x7h7', cid: 2),
      uri: 'bilibili:BV1GJ411x7h7:2',
      title: 'Second Song',
    );

    final first = manager.cacheTrack(biliTrack);
    final second = manager.cacheTrack(secondTrack);

    await started.future;
    expect(inFlight, 1);
    expect(manager.isBusy, isTrue);

    gate.complete();
    await Future.wait(<Future<void>>[first, second]);

    expect(maxInFlight, 1);
    expect(downloader.calls, 2);
    expect(manager.isBusy, isFalse);
    expect(await manager.isCached(biliTrack), isTrue);
    expect(await manager.isCached(secondTrack), isTrue);
  });

  test('a full cache yields failed without evicting pinned rows', () async {
    settings.current = CacheSettings.defaults.copyWith(limitBytes: 1000);
    await addPinned('pinnedA', 800);
    await addPinned('pinnedB', 800);

    final events = <DownloadProgress>[];
    final subscription = manager.progress.listen(events.add);
    addTearDown(subscription.cancel);

    await manager.cacheTrack(biliTrack);

    expect(downloader.calls, 0);
    expect(events.last.phase, DownloadPhase.failed);
    expect(events.last.error.toString(), contains('缓存空间不足'));
    expect(await store.lookup('bilibili', 'pinnedA'), isNotNull);
    expect(await store.lookup('bilibili', 'pinnedB'), isNotNull);
    expect(await manager.isCached(biliTrack), isFalse);
  });

  test('caching disabled emits skipped and downloads nothing', () async {
    settings.current = CacheSettings.defaults.copyWith(enabled: false);

    final events = <DownloadProgress>[];
    final subscription = manager.progress.listen(events.add);
    addTearDown(subscription.cancel);

    await manager.cacheTrack(biliTrack);

    expect(downloader.calls, 0);
    expect(events.last.phase, DownloadPhase.skipped);
    expect(await manager.isCached(biliTrack), isFalse);
  });

  test(
    'StreamExpiredException triggers exactly one re-resolve then succeeds',
    () async {
      var attempts = 0;
      downloader.handler = (url, headers, target, onProgress) async {
        attempts++;
        if (attempts == 1) {
          throw StreamExpiredException(url);
        }
        return _writeFile(target, onProgress);
      };

      final events = <DownloadProgress>[];
      final subscription = manager.progress.listen(events.add);
      addTearDown(subscription.cancel);

      await manager.cacheTrack(biliTrack);

      expect(resolver.calls, 2);
      expect(downloader.calls, 2);
      expect(events.last.phase, DownloadPhase.done);
      expect(await manager.isCached(biliTrack), isTrue);
    },
  );

  test('a second expiry failure is reported as failed', () async {
    downloader.handler = (url, headers, target, onProgress) async {
      throw StreamExpiredException(url);
    };

    final events = <DownloadProgress>[];
    final subscription = manager.progress.listen(events.add);
    addTearDown(subscription.cancel);

    await manager.cacheTrack(biliTrack);

    // One initial resolve plus one re-resolve after the first expiry.
    expect(resolver.calls, 2);
    expect(events.last.phase, DownloadPhase.failed);
    expect(events.last.error, isA<StreamExpiredException>());
    expect(await manager.isCached(biliTrack), isFalse);
  });

  test(
    'a resolver failure is reported as failed without downloading',
    () async {
      resolver.error = StateError('offline');

      final events = <DownloadProgress>[];
      final subscription = manager.progress.listen(events.add);
      addTearDown(subscription.cancel);

      await manager.cacheTrack(biliTrack);

      expect(downloader.calls, 0);
      expect(events.last.phase, DownloadPhase.failed);
      expect(events.last.error, isA<StateError>());
    },
  );

  test('pinned manual downloads are indexed as pinned', () async {
    await manager.cacheTrack(biliTrack, pinned: true);

    final entry = await store.lookup('bilibili', cacheSourceTrackId(biliTrack));
    expect(entry, isNotNull);
    expect(entry!.pinned, isTrue);
  });

  test('a known StreamInfo skips the resolver', () async {
    final info = StreamInfo(
      url: Uri.parse('https://cdn.example/direct.m4a'),
      headers: const <String, String>{'Referer': 'https://www.bilibili.com/'},
      qualityId: '30216',
    );

    await manager.cacheTrack(biliTrack, knownInfo: info);

    expect(resolver.calls, 0);
    final entry = await store.lookup('bilibili', cacheSourceTrackId(biliTrack));
    expect(entry, isNotNull);
    expect(entry!.qualityId, '30216');
  });
}
