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

import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:flind_player/core/models/track.dart';
import 'package:flind_player/core/sources/source_track_id.dart';
import 'package:flind_player/data/database/app_database.dart';
import 'package:flind_player/data/repositories/drift_local_browse_repository.dart';
import 'package:flind_player/data/repositories/drift_music_library_repository.dart';

void main() {
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;

  late AppDatabase db;
  late DriftMusicLibraryRepository library;
  late DriftLocalBrowseRepository browse;

  Track track({
    required String path,
    String? artist,
    String? album,
    int? year,
    String? coverPath,
    String source = 'local',
  }) {
    return Track(
      source: source,
      sourceTrackId: source == 'local'
          ? LocalTrackId(path)
          : const BiliTrackId(bvid: 'BV1', cid: 1),
      uri: '$source:$path',
      title: path.split('/').last,
      artist: artist,
      album: album,
      year: year,
      coverPath: coverPath,
    );
  }

  setUp(() async {
    db = AppDatabase(NativeDatabase.memory());
    library = DriftMusicLibraryRepository(db);
    browse = DriftLocalBrowseRepository(db);
    await library.upsertTracks([
      track(
        path: '/music/a1.flac',
        artist: 'Alpha',
        album: 'First',
        year: 2020,
        coverPath: '/covers/a.jpg',
      ),
      track(path: '/music/a2.flac', artist: 'Alpha', album: 'Second'),
      track(path: '/music/b1.flac', artist: 'Beta', album: 'First', year: 2021),
      track(
        path: '/remote.flac',
        artist: 'Alpha',
        album: 'First',
        source: 'bilibili',
      ),
    ]);
  });

  tearDown(() async {
    await db.close();
  });

  test('artists aggregate local tracks only', () async {
    final artists = await browse.watchArtists().first;
    expect(artists.map((a) => a.name), ['Alpha', 'Beta']);
    expect(artists[0].trackCount, 2);
    expect(artists[0].coverPath, '/covers/a.jpg');
    expect(artists[1].trackCount, 1);
  });

  test('albums group by title and artist and keep the first year', () async {
    final albums = await browse.watchAlbums().first;
    expect(albums, hasLength(3));
    final firstAlpha = albums.firstWhere(
      (album) => album.title == 'First' && album.artist == 'Alpha',
    );
    expect(firstAlpha.year, 2020);
    expect(firstAlpha.trackCount, 1);
    expect(firstAlpha.coverPath, '/covers/a.jpg');

    final firstBeta = albums.firstWhere(
      (album) => album.title == 'First' && album.artist == 'Beta',
    );
    expect(firstBeta.year, 2021);
  });

  test('artist and album track queries return the matching local rows', () async {
    final alpha = await browse.tracksForArtist('alpha');
    expect(alpha.map((t) => t.title), ['a1.flac', 'a2.flac']);

    final first = await browse.tracksForAlbum('First', artist: 'Alpha');
    expect(first.single.title, 'a1.flac');

    final allFirst = await browse.tracksForAlbum('First');
    expect(allFirst.map((t) => t.title).toSet(), {'a1.flac', 'b1.flac'});
  });
}
