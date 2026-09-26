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
import 'package:flind_player/data/repositories/drift_music_library_repository.dart';
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

    test('creates a playlist with a cover', () async {
      final p = await repository.createPlaylist(
        name: 'C',
        coverPath: '/covers/c.webp',
        coverUrl: 'https://example.com/c.webp',
      );
      final stored = await repository.playlistById(p.id);
      expect(stored!.coverPath, '/covers/c.webp');
      expect(stored.coverUrl, 'https://example.com/c.webp');
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

    test('clearCover clears an existing cover', () async {
      final p = await repository.createPlaylist(
        name: 'C',
        coverPath: '/covers/c.webp',
        coverUrl: 'https://example.com/c.webp',
      );
      await repository.updatePlaylist(p.id, clearCover: true);
      final stored = await repository.playlistById(p.id);
      expect(stored!.coverPath, isNull);
      expect(stored.coverUrl, isNull);
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
      // The promoted pool row is untouched.
      expect(await db.select(db.tracks).get(), hasLength(1));
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
    test('resolves every stored field through the pool', () async {
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

      // The member writes no metadata of its own: the pool is the only source.
      final member = await db.select(db.playlistTracks).getSingle();
      expect(member.uri, 'local:/music/song.flac');
      expect(member.playlistId, playlist.id);
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

    test('adding the same uri twice does not duplicate nor refresh the pool',
        () async {
      final playlist = await repository.createPlaylist(name: 'P');
      await repository.addTrack(playlist.id, localTrack());
      await repository.addTrack(playlist.id, localTrack(title: 'Renamed'));

      final members = await repository.playlistTracks(playlist.id);
      expect(members, hasLength(1));
      // The pool is the source of truth and promote never overwrites it, so the
      // second add keeps the original pool metadata.
      expect(members.single.title, 'Song');
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

    test('re-adding does not reset addedAt nor reorder', () async {
      final playlist = await repository.createPlaylist(name: 'P');
      await repository.addTrack(playlist.id, localTrack(path: '/m/a.flac'));
      await repository.addTrack(playlist.id, localTrack(path: '/m/b.flac'));
      expect(
        (await repository.playlistTracks(playlist.id)).map((t) => t.uri),
        ['local:/m/b.flac', 'local:/m/a.flac'],
      );

      await Future<void>.delayed(const Duration(milliseconds: 5));
      await repository.addTrack(playlist.id, localTrack(path: '/m/a.flac'));
      expect(
        (await repository.playlistTracks(playlist.id)).map((t) => t.uri),
        ['local:/m/b.flac', 'local:/m/a.flac'],
      );
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
    test('addTrack promotes the track into the pool', () async {
      final playlist = await repository.createPlaylist(name: 'P');
      await repository.addTrack(playlist.id, localTrack());

      final pool = await db.select(db.tracks).get();
      expect(pool, hasLength(1));
      expect(pool.single.uri, 'local:/music/song.flac');
    });

    test('the pool is the single source of truth', () async {
      final playlist = await repository.createPlaylist(name: 'P');
      await repository.addTrack(playlist.id, localTrack(title: 'Incoming'));

      // The already-promoted pool row is refreshed later; the member resolves
      // that pool metadata, not anything captured at add time.
      await (db.update(db.tracks)
            ..where((t) => t.uri.equals('local:/music/song.flac')))
          .write(const TracksCompanion(title: Value('Pool')));

      final members = await repository.playlistTracks(playlist.id);
      expect(members.single.title, 'Pool');
    });
  });

  group('member availability', () {
    test('member id is the pool id when present and not missing', () async {
      final playlist = await repository.createPlaylist(name: 'P');
      await repository.addTrack(playlist.id, localTrack());
      final member = (await repository.playlistTracks(playlist.id)).single;
      expect(member.id, isNotNull);
    });

    test('member id is null when the pool row is soft-deleted', () async {
      final playlist = await repository.createPlaylist(name: 'P');
      await repository.addTrack(playlist.id, localTrack(path: '/m/a.flac'));
      // A non-empty seen set marks the member's pool row missing without
      // deleting it, so the member must still resolve but as unavailable.
      await DriftMusicLibraryRepository(db).markMissingExcept('local', const {
        'local:/m/other.flac',
      });
      final member = (await repository.playlistTracks(playlist.id)).single;
      expect(member.id, isNull);
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

    test('member cover comes from the pool', () async {
      final playlist = await repository.createPlaylist(name: 'P');
      await repository.addTrack(
        playlist.id,
        localTrack(coverPath: '/covers/added.webp'),
      );
      // The already-promoted pool row is refreshed later with a fresher cover;
      // the member has no snapshot of its own to shadow it.
      await (db.update(db.tracks)
            ..where((t) => t.uri.equals('local:/music/song.flac')))
          .write(
        const TracksCompanion(coverPath: Value('/covers/pool.webp')),
      );

      final cover = await repository.watchPlaylistCover(playlist.id).first;
      expect(cover!.coverPath, '/covers/pool.webp');
    });

    test('an unknown playlist emits null', () async {
      expect(await repository.watchPlaylistCover(9999).first, isNull);
    });
  });
}