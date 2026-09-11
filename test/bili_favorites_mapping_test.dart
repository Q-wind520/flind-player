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

import 'package:flind_player/core/sources/source_track_id.dart';
import 'package:flind_player/data/sources/bilibili/bili_mappers.dart';
import 'package:flind_player/data/sources/bilibili/bili_models.dart';

void main() {
  group('FavFolderDto', () {
    test('parses a numeric folder id and its fields', () {
      final folder = FavFolderDto.fromJson(<String, dynamic>{
        'id': 76614671,
        'title': '默认收藏夹',
        'cover': 'http://i0.hdslb.com/cover.jpg',
        'media_count': 82,
      });

      expect(folder.id, '76614671');
      expect(folder.title, '默认收藏夹');
      expect(folder.coverUrl, 'http://i0.hdslb.com/cover.jpg');
      expect(folder.mediaCount, 82);
    });

    test('accepts media_id and a string id', () {
      final folder = FavFolderDto.fromJson(<String, dynamic>{
        'media_id': '12345678',
        'title': 'x',
      });

      expect(folder.id, '12345678');
    });

    test('degrades gracefully when fields are missing or blank', () {
      final folder = FavFolderDto.fromJson(const <String, dynamic>{});

      expect(folder.id, isEmpty);
      expect(folder.title, isEmpty);
      expect(folder.coverUrl, isEmpty);
      expect(folder.mediaCount, 0);
    });
  });

  group('favoriteFolderToRemotePlaylist', () {
    test('maps id, title, cover and count', () {
      const folder = FavFolderDto(
        id: '2578744971',
        title: '<em>音乐</em>收藏',
        coverUrl: 'http://i0.hdslb.com/cover.jpg',
        mediaCount: 25,
      );

      final playlist = favoriteFolderToRemotePlaylist(folder);

      expect(playlist.id, '2578744971');
      expect(playlist.title, '音乐收藏');
      expect(playlist.coverUrl, 'http://i0.hdslb.com/cover.jpg');
      expect(playlist.trackCount, 25);
    });

    test('leaves coverUrl null when the folder exposes no cover', () {
      const folder = FavFolderDto(id: '1', title: 'No Cover');

      expect(favoriteFolderToRemotePlaylist(folder).coverUrl, isNull);
    });
  });

  group('FavResourceDto', () {
    test('parses a video entry including upper and duration', () {
      final resource = FavResourceDto.fromJson(<String, dynamic>{
        'type': 2,
        'bvid': 'BV1NVDTBsErb',
        'title': '<em>洛克王国</em>最强手柄适配',
        'cover': 'http://i0.hdslb.com/cover.jpg',
        'duration': 392,
        'attr': 0,
        'page': 1,
        'upper': <String, dynamic>{'mid': 1884519, 'name': 'UP主 A'},
      });

      expect(resource.type, 2);
      expect(resource.bvid, 'BV1NVDTBsErb');
      expect(resource.title, '<em>洛克王国</em>最强手柄适配');
      expect(resource.upperName, 'UP主 A');
      expect(resource.durationSeconds, 392);
      expect(resource.attr, 0);
      expect(resource.page, 1);
    });

    test('degrades gracefully when fields are missing', () {
      final resource = FavResourceDto.fromJson(const <String, dynamic>{});

      expect(resource.type, 0);
      expect(resource.bvid, isEmpty);
      expect(resource.title, isEmpty);
      expect(resource.upperName, isEmpty);
      expect(resource.durationSeconds, 0);
      expect(resource.attr, 0);
    });
  });

  group('favoriteResourceToTrack', () {
    test('maps a type-2 video to a Track with a placeholder cid', () {
      const resource = FavResourceDto(
        type: 2,
        bvid: 'BV1NVDTBsErb',
        title: '<em>洛克王国</em>最强手柄适配',
        upperName: 'UP主 A',
        durationSeconds: 392,
      );

      final track = favoriteResourceToTrack(resource);

      expect(track.source, 'bilibili');
      expect(track.title, '洛克王国最强手柄适配');
      expect(track.artist, 'UP主 A');
      expect(track.duration, const Duration(seconds: 392));
      expect(track.uri, 'bilibili:BV1NVDTBsErb:-1');
      expect(
        track.sourceTrackId,
        const BiliTrackId(bvid: 'BV1NVDTBsErb', cid: -1),
      );
    });

    test('leaves artist null and duration null when absent', () {
      const resource = FavResourceDto(type: 2, bvid: 'BV1', title: 'Solo');

      final track = favoriteResourceToTrack(resource);

      expect(track.artist, isNull);
      expect(track.duration, isNull);
    });
  });

  group('favoriteResourcesToTracks', () {
    test('keeps type-2 attr-0 entries and skips everything else', () {
      const resources = <FavResourceDto>[
        FavResourceDto(type: 2, bvid: 'BVok', title: 'Playable'),
        // Audio (`au`) needs a different stream endpoint.
        FavResourceDto(type: 12, bvid: 'BVaudio', title: 'Audio'),
        // Collection/season needs the season archive endpoints.
        FavResourceDto(type: 21, bvid: 'BVseason', title: 'Season'),
        // attr != 0 marks a deleted / invalid entry.
        FavResourceDto(type: 2, bvid: 'BVdead', title: '已失效视频', attr: 9),
        // Interactive video, also marked invalid.
        FavResourceDto(type: 2, bvid: 'BVinter', title: '互动视频', attr: 16),
        // No bvid: nothing to resolve.
        FavResourceDto(type: 2, bvid: '', title: 'No bvid'),
      ];

      final result = favoriteResourcesToTracks(resources);

      expect(result.tracks, hasLength(1));
      expect(result.tracks.single.title, 'Playable');
      expect(result.skipped, 5);
    });

    test('returns an empty list when there is nothing playable', () {
      final result = favoriteResourcesToTracks(const <FavResourceDto>[]);

      expect(result.tracks, isEmpty);
      expect(result.skipped, 0);
    });
  });
}
