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
import 'package:flind_player/core/sources/music_source.dart';
import 'package:flind_player/core/sources/source_track_id.dart';
import 'package:flind_player/core/sources/stream_resolver.dart';
import 'package:flind_player/data/sources/composite_stream_resolver.dart';
import 'package:flind_player/data/sources/local/local_stream_resolver.dart';

/// Records the tracks it was asked to resolve.
class _RecordingResolver implements StreamResolver {
  _RecordingResolver(this.info);

  final StreamInfo info;
  final List<Track> calls = <Track>[];

  @override
  Future<StreamInfo> resolve(Track track) async {
    calls.add(track);
    return info;
  }
}

void main() {
  const localTrack = Track(
    source: 'local',
    sourceTrackId: LocalTrackId('/music/song.flac'),
    uri: 'local:/music/song.flac',
    title: 'Local Song',
  );

  const biliTrack = Track(
    source: 'bilibili',
    sourceTrackId: BiliTrackId(bvid: 'BV1GJ411x7h7', cid: 137649199),
    uri: 'bilibili:BV1GJ411x7h7:137649199',
    title: 'Remote Song',
  );

  group('CompositeStreamResolver', () {
    test('routes local tracks to the injected local resolver', () async {
      final resolver = CompositeStreamResolver(
        localResolver: const LocalStreamResolver(),
        sources: const <String, StreamResolver>{},
      );

      final info = await resolver.resolve(localTrack);

      expect(info.url.scheme, 'file');
      expect(info.url.toFilePath(), p.normalize('/music/song.flac'));
    });

    test('routes bilibili tracks to the registered source', () async {
      final bili = _RecordingResolver(
        StreamInfo(
          url: Uri.parse('https://cdn/audio.m4s'),
          headers: const <String, String>{
            'Referer': 'https://www.bilibili.com/',
          },
        ),
      );
      final resolver = CompositeStreamResolver(
        localResolver: const LocalStreamResolver(),
        sources: <String, StreamResolver>{'bilibili': bili},
      );

      final info = await resolver.resolve(biliTrack);

      expect(info.url, Uri.parse('https://cdn/audio.m4s'));
      expect(info.headers['Referer'], 'https://www.bilibili.com/');
      expect(bili.calls, <Track>[biliTrack]);
    });

    test('throws UnsupportedError for an unknown source', () {
      const unknown = Track(
        source: 'spotify',
        sourceTrackId: LocalTrackId('/x'),
        uri: 'spotify:1',
        title: 'Unknown',
      );
      final resolver = CompositeStreamResolver(
        localResolver: const LocalStreamResolver(),
        sources: const <String, StreamResolver>{},
      );

      expect(
        () => resolver.resolve(unknown),
        throwsA(
          isA<UnsupportedError>().having(
            (e) => e.message,
            'message',
            'No stream resolver registered for source "spotify"',
          ),
        ),
      );
    });
  });
}
