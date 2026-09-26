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

void main() {
  test('a pinned download invokes ensureCover once after success', () async {
    final root = Directory.systemTemp.createTempSync('flind_dl_cover');
    addTearDown(() {
      if (root.existsSync()) root.deleteSync(recursive: true);
    });
    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);
    final covers = <Track>[];
    final manager = DownloadManager(
      store: AudioCacheStore(
        database: db,
        baseDir: root,
        settings: FakeSettingsRepository(),
      ),
      downloader: _StubDownloader(),
      resolver: _StubResolver(),
      ensureCover: (track) async => covers.add(track),
    );
    addTearDown(manager.dispose);

    const track = Track(
      source: 'bilibili',
      sourceTrackId: BiliTrackId(bvid: 'BV1', cid: 1),
      uri: 'bilibili:BV1:1',
      title: 'Song',
    );

    await manager.cacheTrack(track, pinned: true);

    expect(covers.single, track);
  });
}
