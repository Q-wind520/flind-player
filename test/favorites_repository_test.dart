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
import 'package:flind_player/data/repositories/drift_favorites_repository.dart';

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
  late DriftFavoritesRepository repository;

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    repository = DriftFavoritesRepository(db);
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
    );
  }

  group('isFavorite / addFavorite / removeFavorite', () {
    test('tracks the state across add and remove', () async {
      final track = localTrack();

      expect(await repository.isFavorite(track.uri), isFalse);

      await repository.addFavorite(track);
      expect(await repository.isFavorite(track.uri), isTrue);

      await repository.removeFavorite(track.uri);
      expect(await repository.isFavorite(track.uri), isFalse);
    });

    test('removing an absent favourite is a no-op', () async {
      await repository.removeFavorite('local:/nope.flac');

      expect(await repository.allFavorites(), isEmpty);
    });

    test('adds a denormalised snapshot of every stored field', () async {
      await repository.addFavorite(localTrack());

      final stored = (await repository.allFavorites()).single;
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
      const track = Track(
        source: 'bilibili',
        sourceTrackId: BiliTrackId(bvid: 'BV1GJ411x7h7', cid: 137649199),
        uri: 'bilibili:BV1GJ411x7h7:137649199',
        title: 'Online',
      );

      await repository.addFavorite(track);

      final stored = (await repository.allFavorites()).single;
      expect(
        stored.sourceTrackId,
        const BiliTrackId(bvid: 'BV1GJ411x7h7', cid: 137649199),
      );
    });
  });

  group('toggleFavorite', () {
    test('adds then removes, returning the new state each time', () async {
      final track = localTrack();

      expect(await repository.toggleFavorite(track), isTrue);
      expect(await repository.isFavorite(track.uri), isTrue);

      expect(await repository.toggleFavorite(track), isFalse);
      expect(await repository.isFavorite(track.uri), isFalse);
      expect(await repository.allFavorites(), isEmpty);
    });
  });

  group('allFavorites', () {
    test('adding the same uri twice does not duplicate', () async {
      await repository.addFavorite(localTrack());
      await repository.addFavorite(localTrack(title: 'Renamed'));

      final favorites = await repository.allFavorites();
      expect(favorites, hasLength(1));
      // The pool is the source of truth and promote never overwrites it, so the
      // second add keeps the original pool metadata.
      expect(favorites.single.title, 'Song');
    });
  });

  group('watchFavorites', () {
    test('emits newest first and updates on add/remove', () async {
      final emissions = <List<Track>>[];
      final subscription = repository.watchFavorites().listen(emissions.add);
      addTearDown(subscription.cancel);

      await _waitFor(() => emissions.isNotEmpty);
      expect(emissions.last, isEmpty);

      await repository.addFavorite(localTrack(path: '/m/a.flac', title: 'A'));
      await repository.addFavorite(localTrack(path: '/m/b.flac', title: 'B'));
      await _waitFor(() => emissions.isNotEmpty && emissions.last.length == 2);

      expect(emissions.last.map((t) => t.title), ['B', 'A']);

      await repository.removeFavorite('local:/m/b.flac');
      await _waitFor(() => emissions.isNotEmpty && emissions.last.length == 1);

      expect(emissions.last.map((t) => t.title), ['A']);
    });
  });

  group('promotion into the pool', () {
    test('addFavorite promotes the track into tracks', () async {
      await repository.addFavorite(localTrack());
      final rows = await db.select(db.tracks).get();
      expect(rows, hasLength(1));
      expect(rows.single.uri, 'local:/music/song.flac');
      expect((await repository.allFavorites()).single.title, 'Song');
    });
  });
}
