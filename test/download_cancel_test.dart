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
import 'dart:io';

import 'package:dio/dio.dart' show CancelToken;
import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:flind_player/core/models/track.dart';
import 'package:flind_player/core/sources/music_source.dart';
import 'package:flind_player/core/sources/source_track_id.dart';
import 'package:flind_player/core/sources/stream_resolver.dart';
import 'package:flind_player/data/cache/audio_cache_store.dart';
import 'package:flind_player/data/cache/audio_downloader.dart';
import 'package:flind_player/data/cache/download_manager.dart';
import 'package:flind_player/data/database/app_database.dart';

import 'support/fake_settings_repository.dart';

class _Resolver implements StreamResolver {
  @override
  Future<StreamInfo> resolve(Track track) async =>
      StreamInfo(url: Uri.parse('https://cdn.example/${track.uri}.m4a'));
}

class _BlockingDownloader extends AudioDownloader {
  _BlockingDownloader() : super(sleeper: (_) async {});

  final started = Completer<void>();
  final release = Completer<void>();

  @override
  Future<int> download({
    required Uri url,
    required Map<String, String> headers,
    required File target,
    void Function(int received, int? total)? onProgress,
    CancelToken? cancelToken,
  }) async {
    if (!started.isCompleted) started.complete();
    await release.future;
    if (cancelToken?.isCancelled ?? false) {
      throw const DownloadCanceledException();
    }
    target.parent.createSync(recursive: true);
    target.writeAsBytesSync(const [1, 2, 3, 4]);
    return 4;
  }
}

void main() {
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;

  late Directory temp;
  late AppDatabase db;
  late AudioCacheStore store;
  late _BlockingDownloader downloader;
  late DownloadManager manager;

  final first = Track(
    source: 'bilibili',
    sourceTrackId: const BiliTrackId(bvid: 'BV1', cid: 1),
    uri: 'bilibili:BV1:1',
    title: 'First',
  );
  final second = Track(
    source: 'bilibili',
    sourceTrackId: const BiliTrackId(bvid: 'BV2', cid: 2),
    uri: 'bilibili:BV2:2',
    title: 'Second',
  );

  setUp(() {
    temp = Directory.systemTemp.createTempSync('flind_download_cancel');
    db = AppDatabase(NativeDatabase.memory());
    store = AudioCacheStore(
      database: db,
      baseDir: temp,
      settings: FakeSettingsRepository(),
    );
    downloader = _BlockingDownloader();
    manager = DownloadManager(
      store: store,
      downloader: downloader,
      resolver: _Resolver(),
    );
  });

  tearDown(() async {
    await manager.dispose();
    await db.close();
    if (temp.existsSync()) temp.deleteSync(recursive: true);
  });

  test('cancels an active download and leaves no cache row', () async {
    final events = <DownloadProgress>[];
    final sub = manager.progress.listen(events.add);
    addTearDown(sub.cancel);

    final future = manager.cacheTrack(first, pinned: true);
    await downloader.started.future;

    expect(manager.cancel(first.uri), isTrue);
    downloader.release.complete();
    await future;

    expect(events.last.phase, DownloadPhase.canceled);
    expect(await store.entries(), isEmpty);
    expect(await manager.isCached(first), isFalse);
  });

  test('cancels a queued download before it starts', () async {
    final events = <DownloadProgress>[];
    final sub = manager.progress.listen(events.add);
    addTearDown(sub.cancel);

    final firstFuture = manager.cacheTrack(first, pinned: true);
    await downloader.started.future;
    final secondFuture = manager.cacheTrack(second, pinned: true);

    expect(manager.cancel(second.uri), isTrue);
    await secondFuture;

    downloader.release.complete();
    await firstFuture;

    final canceled = events.where((event) => event.trackUri == second.uri);
    expect(canceled.last.phase, DownloadPhase.canceled);
    expect(await store.entries(), hasLength(1));
  });
}
