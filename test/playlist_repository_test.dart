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

import 'package:drift/drift.dart' show Value, driftRuntimeOptions;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:flind_player/core/models/track.dart';
import 'package:flind_player/core/repositories/playlist_repository.dart';
import 'package:flind_player/core/sources/source_track_id.dart';
import 'package:flind_player/data/database/app_database.dart';
import 'package:flind_player/data/database/playlist_defaults.dart';
import 'package:flind_player/data/repositories/drift_playlist_repository.dart';

/// Polls until [condition] is true, failing after [timeout].
///
/// drift's `watch()` re-runs queries asynchronously, so tests wait on observed
/// emissions instead of assuming a fixed number of event-loop turns.
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

void main() {
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;

  late AppDatabase db;
  late DriftPlaylistRepository repository;

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    repository = DriftPlaylistRepository(db);
  });

  tearDown(() async {
    await db.close();
  });

  Track localTrack({
    String path = '/music/song.flac',
    String title = 'Song',
    String? artist = 'Artist',
    String? album = 'Album',
    Duration? duration = const Duration(milliseconds: 215000),
    String? coverPath = '/covers/abc.webp',
    String? coverUrl,
  }) {
    return Track(
      source: 'local',
      sourceTrackId: LocalTrackId(path),
      uri: 'local:$path',
      title: title,
      artist: artist,
      album: album,
      duration: duration,
      coverPath: coverPath,
      coverUrl: coverUrl,
    );
  }

  group('createPlaylist / playlistById', () {
    test('creates a custom playlist and reads it back', () async {
      final playlist = await repository.createPlaylist(
        name: '  Road Trip  ',
        description: 'Summer',
      );

      expect(playlist.id, greaterThan(favoritesPlaylistId));
      expect(playlist.name, 'Road Trip');
      expect(playlist.kind, PlaylistKind.custom);
      expect(playlist.description, 'Summer');
      expect(playlist.coverPath, isNull);
      expect(playlist.coverUrl, isNull);

      final stored = await repository.playlistById(playlist.id);
      expect(stored, isNotNull);
      expect(stored!.name, 'Road Trip');
      expect(stored.kind, PlaylistKind.custom);
    });

    test('an empty playlist is allowed', () async {
      final playlist = await repository.createPlaylist(name: 'Empty');

      expect(await repository.playlistTracks(playlist.id), isEmpty);
    });

    test('a blank name is rejected', () async {
      expect(
        () => repository.createPlaylist(name: '   '),
        throwsArgumentError,
      );
    });

    test('an unknown id reads back as null', () async {
      expect(await repository.playlistById(9999), isNull);
    });
  });

  group('updatePlaylist', () {
    test('renames, re-describes and re-covers a custom playlist', () async {
      final playlist = await repository.createPlaylist(name: 'Old');

      await repository.updatePlaylist(
        playlist.id,
        name: 'New',
        description: 'Desc',
        coverPath: '/covers/p.webp',
        coverUrl: 'https://example.com/p.webp',
      );

      final stored = await repository.playlistById(playlist.id);
      expect(stored!.name, 'New');
      expect(stored.description, 'Desc');
      expect(stored.coverPath, '/covers/p.webp');
      expect(stored.coverUrl, 'https://example.com/p.webp');
    });

    test('a missing playlist is a no-op', () async {
      await repository.updatePlaylist(9999, name: 'Ghost');

      expect(await repository.playlistById(9999), isNull);
    });

    test('a blank name is rejected', () async {
      final playlist = await repository.createPlaylist(name: 'Keep');

      expect(
        () => repository.updatePlaylist(playlist.id, name: '  '),
        throwsArgumentError,
      );
    });

    test('the built-in favourites playlist cannot be renamed', () async {
      expect(
        () => repository.updatePlaylist(favoritesPlaylistId, name: 'Nope'),
        throwsStateError,
      );
    });
  });

  group('deletePlaylist', () {
    test('deletes the playlist and cascades its members', () async {
      final playlist = await repository.createPlaylist(name: 'Doomed');
      await repository.addTrack(playlist.id, localTrack());

      await repository.deletePlaylist(playlist.id);

      expect(await repository.playlistById(playlist.id), isNull);
      expect(await repository.playlistTracks(playlist.id), isEmpty);
      // The pool row is untouched.
      expect(await db.select(db.tracks).get(), isEmpty);
    });

    test('a missing playlist is a no-op', () async {
      await repository.deletePlaylist(9999);
    });

    test('the built-in favourites playlist cannot be deleted', () async {
      expect(
        () => repository.deletePlaylist(favoritesPlaylistId),
        throwsStateError,
      );
    });
  });

  group('addTrack / removeTrack / containsTrack', () {
    test('adds a denormalised snapshot of every stored field', () async {
      final playlist = await repository.createPlaylist(name: 'P');
      await repository.addTrack(playlist.id, localTrack());

      final stored = (await repository.playlistTracks(playlist.id)).single;
      expect(stored.uri, 'local:/music/song.flac');
      expect(stored.source, 'local');
      expect(stored.sourceTrackId, const LocalTrackId('/music/song.flac'));
      expect(stored.title, 'Song');
      expect(stored.artist, 'Artist');
      expect(stored.album, 'Album');
      expect(stored.duration, const Duration(milliseconds: 215000));
      expect(stored.coverPath, '/covers/abc.webp');
    });

    test('round-trips a bilibili sourceTrackId', () async {
      final playlist = await repository.createPlaylist(name: 'P');
      const track = Track(
        source: 'bilibili',
        sourceTrackId: BiliTrackId(bvid: 'BV1GJ411x7h7', cid: 137649199),
        uri: 'bilibili:BV1GJ411x7h7:137649199',
        title: 'Online',
      );

      await repository.addTrack(playlist.id, track);

      final stored = (await repository.playlistTracks(playlist.id)).single;
      expect(
        stored.sourceTrackId,
        const BiliTrackId(bvid: 'BV1GJ411x7h7', cid: 137649199),
      );
    });

    test('adding the same uri twice refreshes the snapshot, not the count',
        () async {
      final playlist = await repository.createPlaylist(name: 'P');
      await repository.addTrack(playlist.id, localTrack());
      await repository.addTrack(playlist.id, localTrack(title: 'Renamed'));

      final members = await repository.playlistTracks(playlist.id);
      expect(members, hasLength(1));
      expect(members.single.title, 'Renamed');
    });

    test('the same song can live in two playlists', () async {
      final a = await repository.createPlaylist(name: 'A');
      final b = await repository.createPlaylist(name: 'B');
      final track = localTrack();

      await repository.addTrack(a.id, track);
      await repository.addTrack(b.id, track);

      expect(await repository.containsTrack(a.id, track.uri), isTrue);
      expect(await repository.containsTrack(b.id, track.uri), isTrue);
      expect(await repository.playlistTracks(a.id), hasLength(1));
      expect(await repository.playlistTracks(b.id), hasLength(1));
    });

    test('removing an absent member is a no-op', () async {
      final playlist = await repository.createPlaylist(name: 'P');

      await repository.removeTrack(playlist.id, 'local:/nope.flac');

      expect(await repository.playlistTracks(playlist.id), isEmpty);
    });

    test('removing a member does not touch other playlists', () async {
      final a = await repository.createPlaylist(name: 'A');
      final b = await repository.createPlaylist(name: 'B');
      final track = localTrack();
      await repository.addTrack(a.id, track);
      await repository.addTrack(b.id, track);

      await repository.removeTrack(a.id, track.uri);

      expect(await repository.containsTrack(a.id, track.uri), isFalse);
      expect(await repository.containsTrack(b.id, track.uri), isTrue);
    });
  });

  group('updateTrackCover', () {
    test('updates the cached cover pointer without reordering', () async {
      final playlist = await repository.createPlaylist(name: 'P');
      await repository.addTrack(playlist.id, localTrack(path: '/m/a.flac'));
      await repository.addTrack(playlist.id, localTrack(path: '/m/b.flac'));

      await repository.updateTrackCover(
        playlist.id,
        'local:/m/a.flac',
        coverPath: '/covers/new.webp',
        coverUrl: 'https://example.com/new.webp',
      );

      final members = await repository.playlistTracks(playlist.id);
      expect(members.map((t) => t.uri), ['local:/m/b.flac', 'local:/m/a.flac']);
      final updated = members.last;
      expect(updated.coverPath, '/covers/new.webp');
      expect(updated.coverUrl, 'https://example.com/new.webp');
    });

    test('a missing member is a no-op', () async {
      final playlist = await repository.createPlaylist(name: 'P');

      await repository.updateTrackCover(
        playlist.id,
        'local:/nope.flac',
        coverPath: '/covers/x.webp',
      );
    });
  });

  group('watchPlaylists', () {
    test('emits favourites first, then custom playlists newest first',
        () async {
      final emissions = <List<Playlist>>[];
      final subscription = repository.watchPlaylists().listen(emissions.add);
      addTearDown(subscription.cancel);

      await _waitFor(() => emissions.isNotEmpty);
      expect(emissions.last.map((p) => p.name), ['Favorites']);

      final older = await repository.createPlaylist(name: 'Older');
      await _waitFor(() => emissions.isNotEmpty && emissions.last.length == 2);
      await repository.createPlaylist(name: 'Newer');
      await _waitFor(() => emissions.isNotEmpty && emissions.last.length == 3);

      expect(emissions.last.map((p) => p.name), [
        'Favorites',
        'Newer',
        'Older',
      ]);
      expect(emissions.last.first.kind, PlaylistKind.favorites);
      expect(emissions.last.skip(1).every((p) => p.kind == PlaylistKind.custom),
          isTrue);

      await repository.deletePlaylist(older.id);
      await _waitFor(() => emissions.isNotEmpty && emissions.last.length == 2);
      expect(emissions.last.map((p) => p.name), ['Favorites', 'Newer']);
    });
  });

  group('watchPlaylistTracks', () {
    test('emits newest first and updates on add/remove', () async {
      final playlist = await repository.createPlaylist(name: 'P');
      final emissions = <List<Track>>[];
      final subscription = repository
          .watchPlaylistTracks(playlist.id)
          .listen(emissions.add);
      addTearDown(subscription.cancel);

      await _waitFor(() => emissions.isNotEmpty);
      expect(emissions.last, isEmpty);

      await repository.addTrack(playlist.id, localTrack(path: '/m/a.flac'));
      await repository.addTrack(playlist.id, localTrack(path: '/m/b.flac'));
      await _waitFor(() => emissions.isNotEmpty && emissions.last.length == 2);

      expect(emissions.last.map((t) => t.title), ['Song', 'Song']);

      await repository.removeTrack(playlist.id, 'local:/m/b.flac');
      await _waitFor(() => emissions.isNotEmpty && emissions.last.length == 1);
      expect(emissions.last.single.uri, 'local:/m/a.flac');
    });
  });

  group('pool join semantics', () {
    test('a member survives the track being absent from the pool', () async {
      final playlist = await repository.createPlaylist(name: 'P');
      await repository.addTrack(playlist.id, localTrack());

      expect(await db.select(db.tracks).get(), isEmpty);

      final members = await repository.playlistTracks(playlist.id);
      expect(members, hasLength(1));
      expect(members.single.title, 'Song');
    });

    test('pool metadata wins over the snapshot', () async {
      final playlist = await repository.createPlaylist(name: 'P');
      await repository.addTrack(playlist.id, localTrack(title: 'Snapshot'));

      // The pool row appears later with fresher metadata.
      await db.into(db.tracks).insert(
        TracksCompanion.insert(
          source: 'local',
          sourceTrackId: 'local:/music/song.flac',
          uri: 'local:/music/song.flac',
          title: 'Pool',
          createdAt: 1,
          updatedAt: 1,
        ),
      );

      final members = await repository.playlistTracks(playlist.id);
      expect(members.single.title, 'Pool');
    });
  });

  group('watchPlaylistCover', () {
    test('falls back to the newest member cover', () async {
      final playlist = await repository.createPlaylist(name: 'P');
      final emissions = <PlaylistCover?>[];
      final subscription = repository
          .watchPlaylistCover(playlist.id)
          .listen(emissions.add);
      addTearDown(subscription.cancel);

      await _waitFor(() => emissions.isNotEmpty);
      expect(emissions.last, isNull);

      await repository.addTrack(
        playlist.id,
        localTrack(path: '/m/a.flac', coverPath: '/covers/a.webp'),
      );
      await repository.addTrack(
        playlist.id,
        localTrack(path: '/m/b.flac', coverPath: '/covers/b.webp'),
      );
      // Wait for the newest member's cover specifically: the first emission
      // after adding A is already non-null, so a bare "last != null" check
      // would race ahead of B's emission.
      await _waitFor(
        () =>
            emissions.isNotEmpty &&
            emissions.last?.coverPath == '/covers/b.webp',
      );

      expect(emissions.last!.coverPath, '/covers/b.webp');
    });

    test('an explicit playlist cover wins over members', () async {
      final playlist = await repository.createPlaylist(name: 'P');
      await repository.addTrack(
        playlist.id,
        localTrack(coverPath: '/covers/member.webp'),
      );
      await repository.updatePlaylist(
        playlist.id,
        coverPath: '/covers/playlist.webp',
      );

      final cover = await repository.watchPlaylistCover(playlist.id).first;
      expect(cover!.coverPath, '/covers/playlist.webp');
    });

    test('pool cover wins over the snapshot cover', () async {
      final playlist = await repository.createPlaylist(name: 'P');
      await repository.addTrack(
        playlist.id,
        localTrack(coverPath: '/covers/snapshot.webp'),
      );
      await db.into(db.tracks).insert(
        TracksCompanion.insert(
          source: 'local',
          sourceTrackId: 'local:/music/song.flac',
          uri: 'local:/music/song.flac',
          title: 'Song',
          coverPath: Value('/covers/pool.webp'),
          createdAt: 1,
          updatedAt: 1,
        ),
      );

      final cover = await repository.watchPlaylistCover(playlist.id).first;
      expect(cover!.coverPath, '/covers/pool.webp');
    });

    test('an unknown playlist emits null', () async {
      expect(await repository.watchPlaylistCover(9999).first, isNull);
    });
  });
}