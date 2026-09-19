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

import 'package:flind_player/core/models/track.dart';
import 'package:flind_player/core/sources/source_track_id.dart';
import 'package:flind_player/data/codec/track_codec.dart';

void main() {
  group('encodeTrack / decodeTrack', () {
    test('round-trips every field of a local track', () {
      const track = Track(
        id: 42,
        source: 'local',
        sourceTrackId: LocalTrackId('/music/song.flac'),
        uri: 'local:/music/song.flac',
        title: 'Song',
        artist: 'Artist',
        album: 'Album',
        albumArtist: 'Album Artist',
        trackNo: 3,
        discNo: 1,
        year: 2024,
        duration: Duration(milliseconds: 215000),
        bitrate: 320000,
        sampleRate: 44100,
        genre: 'Rock',
        coverPath: '/covers/abc.webp',
      );

      final decoded = decodeTrack(encodeTrack(track));

      expect(decoded, track);
      expect(decoded.id, 42);
      expect(decoded.sourceTrackId, const LocalTrackId('/music/song.flac'));
      expect(decoded.duration, const Duration(milliseconds: 215000));
    });

    test('round-trips every field of a bilibili track', () {
      const track = Track(
        id: 7,
        source: 'bilibili',
        sourceTrackId: BiliTrackId(bvid: 'BV1GJ411x7h7', cid: 137649199),
        uri: 'bilibili:BV1GJ411x7h7:137649199',
        title: 'Online Track',
        artist: 'Uploader',
        album: 'Video',
        duration: Duration(seconds: 180),
        coverPath: '/covers/online.webp',
      );

      final decoded = decodeTrack(encodeTrack(track));

      expect(decoded, track);
      expect(
        decoded.sourceTrackId,
        const BiliTrackId(bvid: 'BV1GJ411x7h7', cid: 137649199),
      );
    });

    test('encodes the sourceTrackId as a tagged discriminator', () {
      const track = Track(
        source: 'bilibili',
        sourceTrackId: BiliTrackId(bvid: 'BV1', cid: 2),
        uri: 'bilibili:BV1:2',
        title: 'T',
      );

      final json = encodeTrack(track);

      expect(json['sourceTrackId'], {'kind': 'bili', 'bvid': 'BV1', 'cid': 2});
    });

    test('round-trips a track whose optional fields are null', () {
      const track = Track(
        source: 'local',
        sourceTrackId: LocalTrackId('/music/min.mp3'),
        uri: 'local:/music/min.mp3',
        title: 'Minimal',
      );

      final decoded = decodeTrack(encodeTrack(track));

      expect(decoded, track);
      expect(decoded.artist, isNull);
      expect(decoded.duration, isNull);
    });

    test('round-trips coverUrl explicitly (equality alone cannot see it)', () {
      const url = 'https://i0.hdslb.com/bfs/archive/a.jpg@480w_270h_1c.webp';
      const track = Track(
        source: 'bilibili',
        sourceTrackId: BiliTrackId(bvid: 'BV1', cid: 2),
        uri: 'bilibili:BV1:2',
        title: 'T',
        coverPath: '/covers/abc.jpg',
        coverUrl: url,
      );

      final decoded = decodeTrack(encodeTrack(track));

      // `==` deliberately ignores coverUrl (volatile display metadata, like
      // coverPath), so only this explicit field read can observe the
      // round-trip: a codec regression that drops the key must fail here.
      expect(decoded.coverUrl, url);
      expect(decoded.coverPath, track.coverPath);
      expect(decoded, track);
    });

    test('decodes legacy JSON with no coverUrl key to null', () {
      final legacy = <String, dynamic>{
        'id': 3,
        'source': 'bilibili',
        'sourceTrackId': <String, dynamic>{
          'kind': 'bili',
          'bvid': 'BV1',
          'cid': 2,
        },
        'uri': 'bilibili:BV1:2',
        'title': 'Legacy',
        'artist': null,
        'album': null,
        'albumArtist': null,
        'trackNo': null,
        'discNo': null,
        'year': null,
        'durationMs': 1000,
        'bitrate': null,
        'sampleRate': null,
        'genre': null,
        'coverPath': null,
      };

      final decoded = decodeTrack(legacy);

      expect(decoded.coverUrl, isNull);
      expect(decoded.title, 'Legacy');
      expect(decoded.duration, const Duration(seconds: 1));
    });

    test('coverUrl null and empty round-trip without throwing', () {
      const withNull = Track(
        source: 'local',
        sourceTrackId: LocalTrackId('/music/a.mp3'),
        uri: 'local:/music/a.mp3',
        title: 'A',
        coverUrl: null,
      );
      const withEmpty = Track(
        source: 'local',
        sourceTrackId: LocalTrackId('/music/b.mp3'),
        uri: 'local:/music/b.mp3',
        title: 'B',
        coverUrl: '',
      );

      final decodedNull = decodeTrack(encodeTrack(withNull));
      final decodedEmpty = decodeTrack(encodeTrack(withEmpty));

      expect(decodedNull.coverUrl, isNull);
      // An empty cover is "no cover": it decodes to null instead of failing
      // the whole queue load.
      expect(decodedEmpty.coverUrl, isNull);
    });

    test('malformed non-string coverUrl decodes to null without throwing', () {
      final json = encodeTrack(
        const Track(
          source: 'local',
          sourceTrackId: LocalTrackId('/music/corrupt.mp3'),
          uri: 'local:/music/corrupt.mp3',
          title: 'Corrupt',
          coverUrl: 'https://i0.hdslb.com/a.jpg',
        ),
      );

      json['coverUrl'] = 42;
      expect(decodeTrack(json).coverUrl, isNull);

      json['coverUrl'] = <String, dynamic>{'nested': true};
      expect(decodeTrack(json).coverUrl, isNull);

      json['coverUrl'] = '';
      expect(decodeTrack(json).coverUrl, isNull);
    });

    test('throws FormatException for an unknown sourceTrackId kind', () {
      final json = encodeTrack(
        const Track(
          source: 'local',
          sourceTrackId: LocalTrackId('/music/song.flac'),
          uri: 'local:/music/song.flac',
          title: 'Song',
        ),
      );
      (json['sourceTrackId']! as Map<String, dynamic>)['kind'] = 'mystery';

      expect(() => decodeTrack(json), throwsFormatException);
    });

    test('throws FormatException for a missing sourceTrackId', () {
      final json = encodeTrack(
        const Track(
          source: 'local',
          sourceTrackId: LocalTrackId('/music/song.flac'),
          uri: 'local:/music/song.flac',
          title: 'Song',
        ),
      );
      json.remove('sourceTrackId');

      expect(() => decodeTrack(json), throwsFormatException);
    });
  });

  group('encodeTracks / decodeTracks', () {
    test('round-trips a list, preserving order', () {
      final tracks = <Track>[
        const Track(
          source: 'local',
          sourceTrackId: LocalTrackId('/m/a.flac'),
          uri: 'local:/m/a.flac',
          title: 'A',
        ),
        const Track(
          source: 'bilibili',
          sourceTrackId: BiliTrackId(bvid: 'BV1', cid: 2),
          uri: 'bilibili:BV1:2',
          title: 'B',
        ),
      ];

      final decoded = decodeTracks(encodeTracks(tracks));

      expect(decoded, tracks);
    });

    test('round-trips an empty list', () {
      expect(decodeTracks(encodeTracks(const [])), isEmpty);
    });

    test('round-trips coverUrl through a list snapshot', () {
      const url = 'https://i0.hdslb.com/bfs/archive/list.jpg';
      final tracks = <Track>[
        const Track(
          source: 'bilibili',
          sourceTrackId: BiliTrackId(bvid: 'BV1', cid: 2),
          uri: 'bilibili:BV1:2',
          title: 'With Cover',
          coverUrl: url,
        ),
      ];

      final decoded = decodeTracks(encodeTracks(tracks));

      // `==` deliberately ignores coverUrl, so the field must be read
      // explicitly: a codec regression that drops the key fails here.
      expect(decoded.single.coverUrl, url);
    });
  });

  group('Track.coverUrl display-metadata contract', () {
    test('is excluded from == and hashCode (queue change detection)', () {
      const a = Track(
        source: 'bilibili',
        sourceTrackId: BiliTrackId(bvid: 'BV1', cid: 2),
        uri: 'bilibili:BV1:2',
        title: 'T',
        coverUrl: 'https://i0.hdslb.com/a.jpg',
      );
      const b = Track(
        source: 'bilibili',
        sourceTrackId: BiliTrackId(bvid: 'BV1', cid: 2),
        uri: 'bilibili:BV1:2',
        title: 'T',
        coverUrl: 'https://i0.hdslb.com/b.jpg',
      );

      // PlaybackPersistenceService detects queue changes with listEquals on
      // List<Track>; a refreshed cover URL must not mark the queue as changed.
      expect(a, b);
      expect(a.hashCode, b.hashCode);
    });

    test('copyWith carries coverUrl and still sets coverPath', () {
      const track = Track(
        source: 'bilibili',
        sourceTrackId: BiliTrackId(bvid: 'BV1', cid: 2),
        uri: 'bilibili:BV1:2',
        title: 'T',
        coverUrl: 'https://i0.hdslb.com/a.jpg',
      );

      final copy = track.copyWith(coverPath: '/covers/local.jpg');

      expect(copy.coverUrl, 'https://i0.hdslb.com/a.jpg');
      expect(copy.coverPath, '/covers/local.jpg');
      expect(copy.title, 'T');
    });
  });
}
