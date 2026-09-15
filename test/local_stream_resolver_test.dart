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

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

import 'package:flind_player/core/models/track.dart';
import 'package:flind_player/core/sources/source_track_id.dart';
import 'package:flind_player/data/sources/local/local_stream_resolver.dart';

Track _localTrack(String path) => Track(
  source: 'local',
  sourceTrackId: LocalTrackId(path),
  uri: 'local:$path',
  title: 'Test',
);

void main() {
  const resolver = LocalStreamResolver();

  group('LocalStreamResolver', () {
    test('resolves a local: track to the matching file: URI', () async {
      const path = '/home/user/Music/song.flac';

      final info = await resolver.resolve(_localTrack(path));

      expect(info.url, Uri.file(path));
      expect(info.url.scheme, 'file');
      expect(info.url.toFilePath(), p.normalize(path));
    });

    test('preserves spaces and unicode in paths', () async {
      const path = '/home/user/音乐/My Song — 曲.flac';

      final info = await resolver.resolve(_localTrack(path));

      expect(info.url.scheme, 'file');
      expect(info.url.toFilePath(), p.normalize(path));
    });

    test('produces no headers and no expiry for local files', () async {
      final info = await resolver.resolve(_localTrack('/music/a.mp3'));

      expect(info.headers, isEmpty);
      expect(info.expiresAt, isNull);
      expect(info.backupUrls, isEmpty);
    });

    test('falls back to LocalTrackId.path when the uri has no path', () async {
      const track = Track(
        source: 'local',
        sourceTrackId: LocalTrackId('/music/from-id.mp3'),
        uri: 'local:',
        title: 'Test',
      );

      final info = await resolver.resolve(track);

      expect(info.url, Uri.file('/music/from-id.mp3'));
    });

    test('throws UnsupportedError for a non-local source', () async {
      const track = Track(
        source: 'bilibili',
        sourceTrackId: BiliTrackId(bvid: 'BV1GJ411x7h7', cid: 137649199),
        uri: 'bilibili:BV1GJ411x7h7:137649199',
        title: 'Remote',
      );

      await expectLater(
        resolver.resolve(track),
        throwsA(
          isA<UnsupportedError>().having(
            (error) => error.message,
            'message',
            'LocalStreamResolver cannot resolve bilibili',
          ),
        ),
      );
    });
  });
}
