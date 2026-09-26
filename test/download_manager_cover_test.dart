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

import 'audio_cache_store_test.dart' show FakeSettingsRepository;

class _StubResolver implements StreamResolver {
  @override
  Future<StreamInfo> resolve(Track track) async =>
      StreamInfo(url: Uri.parse('https://cdn.example/audio.m4a'));
}

class _StubDownloader extends AudioDownloader {
  _StubDownloader() : super(sleeper: (_) async {});

  @override
  Future<int> download({
    required Uri url,
    required Map<String, String> headers,
    required File target,
    void Function(int received, int? total)? onProgress,
  }) async {
    target.parent.createSync(recursive: true);
    target.writeAsBytesSync(const [1, 2, 3, 4]);
    return 4;
  }
}

const _track = Track(
  source: 'bilibili',
  sourceTrackId: BiliTrackId(bvid: 'BV1', cid: 1),
  uri: 'bilibili:BV1:1',
  title: 'Song',
);

void main() {
  /// Builds a [DownloadManager] around a throwaway cache, wiring up all of
  /// its teardowns, with [ensureCover] attached as the companion-cover
  /// callback.
  DownloadManager makeManager(Future<void> Function(Track)? ensureCover) {
    final root = Directory.systemTemp.createTempSync('flind_dl_cover');
    addTearDown(() {
      if (root.existsSync()) root.deleteSync(recursive: true);
    });
    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);
    final manager = DownloadManager(
      store: AudioCacheStore(
        database: db,
        baseDir: root,
        settings: FakeSettingsRepository(),
      ),
      downloader: _StubDownloader(),
      resolver: _StubResolver(),
      ensureCover: ensureCover,
    );
    addTearDown(manager.dispose);
    return manager;
  }

  test('a pinned download invokes ensureCover once after success', () async {
    final covers = <Track>[];
    final manager = makeManager((track) async => covers.add(track));

    await manager.cacheTrack(_track, pinned: true);

    expect(covers.single, _track);
  });

  test('a failing ensureCover never fails a pinned download', () async {
    final manager = makeManager(
      (track) async => throw StateError('cover backend down'),
    );
    final phases = <DownloadPhase>[];
    final subscription = manager.progress.listen((p) => phases.add(p.phase));

    // `cacheTrack` must complete without throwing and still report success.
    await manager.cacheTrack(_track, pinned: true);
    await pumpEventQueue();
    await subscription.cancel();

    expect(phases, isNot(contains(DownloadPhase.failed)));
    expect(phases.last, DownloadPhase.done);
  });

  test('a non-pinned download never invokes ensureCover', () async {
    final covers = <Track>[];
    final manager = makeManager((track) async => covers.add(track));

    await manager.cacheTrack(_track);

    expect(covers, isEmpty);
  });
}
