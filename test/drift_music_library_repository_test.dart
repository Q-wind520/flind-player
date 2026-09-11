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

import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:flind_player/core/models/track.dart';
import 'package:flind_player/core/sources/source_track_id.dart';
import 'package:flind_player/data/database/app_database.dart';
import 'package:flind_player/data/repositories/drift_music_library_repository.dart';

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
  // The migration test opens more than one AppDatabase (on distinct executors)
  // to exercise the v1 -> v2 upgrade, which triggers drift's multi-instance
  // debug warning. Suppress it; there is no shared executor here.
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;

  // NOTE: `package:sqlite3/open.dart` (and its `open.overrideFor`) does not
  // exist in the resolved sqlite3 3.5.2, which loads libsqlite3 through Dart
  // native assets. `flutter test` builds/resolves that asset automatically, so
  // no dynamic-library override is needed on this environment.
  late AppDatabase db;
  late DriftMusicLibraryRepository repository;

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    repository = DriftMusicLibraryRepository(db);
  });

  tearDown(() async {
    await db.close();
  });

  Track sampleTrack({String path = '/music/song.flac'}) => Track(
    source: 'local',
    sourceTrackId: LocalTrackId(path),
    uri: 'local:$path',
    title: 'Song',
    artist: 'Artist',
    album: 'Album',
    albumArtist: 'Album Artist',
    trackNo: 3,
    discNo: 1,
    year: 2024,
    duration: const Duration(milliseconds: 215000),
    bitrate: 320000,
    sampleRate: 44100,
    genre: 'Rock',
    coverPath: '/covers/abc.webp',
  );

  /// Minimal local track used by the search/scan tests.
  Track libraryTrack({
    required String path,
    required String title,
    String? artist,
    String? album,
  }) => Track(
    source: 'local',
    sourceTrackId: LocalTrackId(path),
    uri: 'local:$path',
    title: title,
    artist: artist,
    album: album,
  );

  group('upsertTrack', () {
    test('inserts and returns the new row id', () async {
      final id = await repository.upsertTrack(sampleTrack());

      expect(id, greaterThan(0));
      final tracks = await repository.allTracks();
      expect(tracks, hasLength(1));
      expect(tracks.single.id, id);
    });

    test(
      'updates instead of duplicating when the uri already exists',
      () async {
        final firstId = await repository.upsertTrack(sampleTrack());
        final secondId = await repository.upsertTrack(
          sampleTrack().copyWith(title: 'Updated Title'),
        );

        expect(secondId, firstId);
        final tracks = await repository.allTracks();
        expect(tracks, hasLength(1));
        expect(tracks.single.title, 'Updated Title');
      },
    );

    test('preserves createdAt across updates', () async {
      await repository.upsertTrack(sampleTrack());
      final before = await db
          .customSelect('SELECT created_at FROM tracks')
          .getSingle();
      await repository.upsertTrack(sampleTrack().copyWith(title: 'Again'));
      final after = await db
          .customSelect('SELECT created_at FROM tracks')
          .getSingle();

      expect(after.data['created_at'], before.data['created_at']);
    });
  });

  group('findByUri', () {
    test('round-trips every mapped field', () async {
      final insertedId = await repository.upsertTrack(sampleTrack());

      final found = await repository.findByUri('local:/music/song.flac');

      expect(found, isNotNull);
      expect(found!.id, insertedId);
      expect(found.source, 'local');
      expect(found.sourceTrackId, const LocalTrackId('/music/song.flac'));
      expect(found.uri, 'local:/music/song.flac');
      expect(found.title, 'Song');
      expect(found.artist, 'Artist');
      expect(found.album, 'Album');
      expect(found.albumArtist, 'Album Artist');
      expect(found.trackNo, 3);
      expect(found.discNo, 1);
      expect(found.year, 2024);
      expect(found.duration, const Duration(milliseconds: 215000));
      expect(found.bitrate, 320000);
      expect(found.sampleRate, 44100);
      expect(found.genre, 'Rock');
      expect(found.coverPath, '/covers/abc.webp');
    });

    test('returns null for an unknown uri', () async {
      expect(await repository.findByUri('local:/nope.mp3'), isNull);
    });
  });

  group('watchTracks', () {
    test('emits the new list after an insert', () async {
      final emissions = <List<Track>>[];
      final subscription = repository.watchTracks().listen(emissions.add);
      addTearDown(subscription.cancel);

      await _waitFor(() => emissions.isNotEmpty);
      expect(emissions.last, isEmpty);

      await repository.upsertTrack(sampleTrack());
      await _waitFor(() => emissions.any((tracks) => tracks.length == 1));

      expect(emissions.last, hasLength(1));
      expect(emissions.last.single.title, 'Song');
    });

    test('orders tracks by title, case-insensitively', () async {
      await repository.upsertTrack(
        sampleTrack(path: '/b.flac').copyWith(title: 'banana'),
      );
      await repository.upsertTrack(
        sampleTrack(path: '/a.flac').copyWith(title: 'Apple'),
      );
      await repository.upsertTrack(
        sampleTrack(path: '/c.flac').copyWith(title: 'cherry'),
      );

      final titles = (await repository.allTracks())
          .map((t) => t.title)
          .toList();
      expect(titles, ['Apple', 'banana', 'cherry']);
    });
  });

  group('deleteTrack', () {
    test('removes the row', () async {
      final id = await repository.upsertTrack(sampleTrack());

      await repository.deleteTrack(id);

      expect(await repository.allTracks(), isEmpty);
      expect(await repository.findByUri('local:/music/song.flac'), isNull);
    });
  });

  group('scan roots', () {
    test('add, list (sorted) and remove', () async {
      expect(await repository.scanRoots(), isEmpty);

      await repository.addScanRoot('/music/b');
      await repository.addScanRoot('/music/a');
      expect(await repository.scanRoots(), ['/music/a', '/music/b']);

      await repository.removeScanRoot('/music/a');
      expect(await repository.scanRoots(), ['/music/b']);
    });

    test('adding the same path twice is idempotent', () async {
      await repository.addScanRoot('/music');
      await repository.addScanRoot('/music');

      expect(await repository.scanRoots(), ['/music']);
    });
  });

  group('searchTracks', () {
    Future<void> seed() async {
      await repository.upsertTracks([
        libraryTrack(
          path: '/m/beet1.flac',
          title: 'Beethoven Symphony No. 5',
          artist: 'Ludwig van Beethoven',
          album: 'Classical Masters',
        ),
        libraryTrack(
          path: '/m/beet2.flac',
          title: 'Moonlight Sonata',
          artist: 'Beethoven',
          album: 'Piano Works',
        ),
        libraryTrack(
          path: '/m/other.flac',
          title: 'Banana Pancakes',
          artist: 'Jack Johnson',
          album: 'In Between Dreams',
        ),
      ]);
    }

    test('finds matches by title, artist and album', () async {
      await seed();

      expect((await repository.searchTracks('Symphony')).map((t) => t.title), [
        'Beethoven Symphony No. 5',
      ]);
      expect((await repository.searchTracks('Ludwig')).map((t) => t.title), [
        'Beethoven Symphony No. 5',
      ]);
      expect(
        (await repository.searchTracks('Piano Works')).map((t) => t.title),
        ['Moonlight Sonata'],
      );
    });

    test('is case-insensitive', () async {
      await seed();

      expect(await repository.searchTracks('bEeThOvEn'), hasLength(2));
    });

    test('prefix-matches the last token', () async {
      await seed();

      final titles = (await repository.searchTracks('beet'))
          .map((t) => t.title)
          .toList();
      expect(titles, ['Beethoven Symphony No. 5', 'Moonlight Sonata']);
    });

    test('supports multi-token queries', () async {
      await seed();

      expect(
        (await repository.searchTracks('ludwig beet')).map((t) => t.title),
        ['Beethoven Symphony No. 5'],
      );
      expect(await repository.searchTracks('beethoven banana'), isEmpty);
    });

    test('returns an empty list for a blank query', () async {
      await seed();

      expect(await repository.searchTracks(''), isEmpty);
      expect(await repository.searchTracks('   '), isEmpty);
    });

    test('returns an empty list when nothing matches', () async {
      await seed();

      expect(await repository.searchTracks('zzzzzz'), isEmpty);
    });

    test('survives FTS5-hostile input', () async {
      await seed();

      for (final query in ['"', '*', 'NEAR(', '-', 'a"b', '(', 'AND']) {
        expect(
          await repository.searchTracks(query),
          isEmpty,
          reason: 'query $query should not throw',
        );
      }
    });

    test('falls back to a LIKE scan when FTS is unavailable', () async {
      await seed();
      await db.customStatement('DROP TABLE tracks_fts');

      expect((await repository.searchTracks('beet')).map((t) => t.title), [
        'Beethoven Symphony No. 5',
        'Moonlight Sonata',
      ]);
    });

    test('excludes soft-deleted rows', () async {
      await seed();
      await repository.markMissingExcept('local', {
        'local:/m/beet2.flac',
        'local:/m/other.flac',
      });

      expect((await repository.searchTracks('beet')).map((t) => t.title), [
        'Moonlight Sonata',
      ]);
    });
  });

  group('upsertTracks', () {
    test('inserts many rows in one call', () async {
      await repository.upsertTracks([
        libraryTrack(path: '/m/a.flac', title: 'A'),
        libraryTrack(path: '/m/b.flac', title: 'B'),
        libraryTrack(path: '/m/c.flac', title: 'C'),
      ]);

      expect(await repository.allTracks(), hasLength(3));
    });

    test('updates existing rows on conflict without duplicating', () async {
      await repository.upsertTracks([
        libraryTrack(path: '/m/a.flac', title: 'Old A'),
      ]);
      final before = await db
          .customSelect(
            "SELECT created_at FROM tracks WHERE uri = 'local:/m/a.flac'",
          )
          .getSingle();

      await repository.upsertTracks([
        libraryTrack(path: '/m/a.flac', title: 'New A'),
        libraryTrack(path: '/m/b.flac', title: 'B'),
      ]);

      final tracks = await repository.allTracks();
      expect(tracks, hasLength(2));
      expect(
        tracks.firstWhere((t) => t.uri == 'local:/m/a.flac').title,
        'New A',
      );

      final after = await db
          .customSelect(
            "SELECT created_at FROM tracks WHERE uri = 'local:/m/a.flac'",
          )
          .getSingle();
      expect(after.data['created_at'], before.data['created_at']);
    });

    test('is a no-op for an empty list', () async {
      await repository.upsertTracks(const []);

      expect(await repository.allTracks(), isEmpty);
    });
  });

  group('trackUrisForSource', () {
    test('includes soft-deleted rows', () async {
      await repository.upsertTracks([
        libraryTrack(path: '/m/a.flac', title: 'A'),
        libraryTrack(path: '/m/b.flac', title: 'B'),
      ]);
      await repository.markMissingExcept('local', {'local:/m/a.flac'});

      expect(await repository.trackUrisForSource('local'), {
        'local:/m/a.flac',
        'local:/m/b.flac',
      });
    });

    test('is scoped to the requested source', () async {
      await repository.upsertTracks([
        libraryTrack(path: '/m/a.flac', title: 'A'),
      ]);
      await repository.upsertTrack(
        Track(
          source: 'bilibili',
          sourceTrackId: const BiliTrackId(bvid: 'BV1', cid: 2),
          uri: 'bilibili:BV1:2',
          title: 'Online',
        ),
      );

      expect(await repository.trackUrisForSource('local'), {'local:/m/a.flac'});
      expect(await repository.trackUrisForSource('bilibili'), {
        'bilibili:BV1:2',
      });
    });
  });

  group('markMissingExcept', () {
    test('marks absent rows missing and returns the count', () async {
      await repository.upsertTracks([
        libraryTrack(path: '/m/a.flac', title: 'A'),
        libraryTrack(path: '/m/b.flac', title: 'B'),
        libraryTrack(path: '/m/c.flac', title: 'C'),
      ]);

      final marked = await repository.markMissingExcept('local', {
        'local:/m/a.flac',
      });

      expect(marked, 2);
      expect((await repository.allTracks()).map((t) => t.uri), [
        'local:/m/a.flac',
      ]);
    });

    test('returns 0 when nothing newly goes missing', () async {
      await repository.upsertTracks([
        libraryTrack(path: '/m/a.flac', title: 'A'),
        libraryTrack(path: '/m/b.flac', title: 'B'),
      ]);
      await repository.markMissingExcept('local', {'local:/m/a.flac'});

      final marked = await repository.markMissingExcept('local', {
        'local:/m/a.flac',
      });

      expect(marked, 0);
    });

    test('restores rows when they reappear', () async {
      await repository.upsertTracks([
        libraryTrack(path: '/m/a.flac', title: 'A'),
        libraryTrack(path: '/m/b.flac', title: 'B'),
      ]);
      await repository.markMissingExcept('local', {'local:/m/b.flac'});
      expect(await repository.allTracks(), hasLength(1));

      final marked = await repository.markMissingExcept('local', {
        'local:/m/a.flac',
        'local:/m/b.flac',
      });

      expect(marked, 0);
      expect(await repository.allTracks(), hasLength(2));
      final rows = await db.customSelect('SELECT missing_at FROM tracks').get();
      expect(rows.every((row) => row.data['missing_at'] == null), isTrue);
    });

    test('does nothing when seenUris is empty', () async {
      await repository.upsertTracks([
        libraryTrack(path: '/m/a.flac', title: 'A'),
        libraryTrack(path: '/m/b.flac', title: 'B'),
      ]);

      final marked = await repository.markMissingExcept('local', const {});

      expect(marked, 0);
      expect(await repository.allTracks(), hasLength(2));
    });

    test('empty seenUris leaves already-missing rows missing', () async {
      await repository.upsertTracks([
        libraryTrack(path: '/m/a.flac', title: 'A'),
        libraryTrack(path: '/m/b.flac', title: 'B'),
      ]);
      await repository.markMissingExcept('local', {'local:/m/a.flac'});
      expect(await repository.allTracks(), hasLength(1));

      expect(await repository.markMissingExcept('local', const {}), 0);
      expect(await repository.allTracks(), hasLength(1));
    });
  });

  group('soft delete', () {
    test(
      'missing rows vanish from list/watch/search but stay in trackUris',
      () async {
        await repository.upsertTracks([
          libraryTrack(path: '/m/beet.flac', title: 'Beethoven'),
          libraryTrack(path: '/m/banana.flac', title: 'Banana'),
        ]);
        await repository.markMissingExcept('local', {'local:/m/beet.flac'});

        expect((await repository.allTracks()).map((t) => t.title), [
          'Beethoven',
        ]);
        expect(await repository.searchTracks('banana'), isEmpty);

        final emissions = <List<Track>>[];
        final subscription = repository.watchTracks().listen(emissions.add);
        addTearDown(subscription.cancel);
        await _waitFor(() => emissions.isNotEmpty);
        expect(emissions.last.map((t) => t.title), ['Beethoven']);

        expect(await repository.trackUrisForSource('local'), {
          'local:/m/beet.flac',
          'local:/m/banana.flac',
        });
      },
    );
  });

  group('bilibili mapping', () {
    test('round-trips a BiliTrackId through the database', () async {
      const id = BiliTrackId(bvid: 'BV1GJ411x7h7', cid: 137649199);
      await repository.upsertTrack(
        Track(
          source: 'bilibili',
          sourceTrackId: id,
          uri: 'bilibili:BV1GJ411x7h7:137649199',
          title: 'Online Track',
        ),
      );

      final stored = await db
          .customSelect('SELECT source_track_id FROM tracks')
          .getSingle();
      expect(stored.data['source_track_id'], 'BV1GJ411x7h7:137649199');

      final found = await repository.findByUri(
        'bilibili:BV1GJ411x7h7:137649199',
      );
      expect(found, isNotNull);
      expect(found!.sourceTrackId, id);

      final listed = await repository.allTracks();
      expect(listed.single.sourceTrackId, id);
    });

    test('keeps local identity for local rows', () async {
      await repository.upsertTrack(sampleTrack());

      final found = await repository.findByUri('local:/music/song.flac');
      expect(found!.sourceTrackId, const LocalTrackId('/music/song.flac'));
    });
  });

  group('schema migration', () {
    test('v1 -> v2 installs FTS and indexes existing rows', () async {
      final dir = Directory.systemTemp.createTempSync('flind_migration');
      addTearDown(() {
        if (dir.existsSync()) dir.deleteSync(recursive: true);
      });
      final file = File('${dir.path}/library.sqlite');

      // Build a current-schema file, then roll it back to a v1 shape: v1 had
      // neither the FTS index nor the `missing_at` column.
      final before = AppDatabase(NativeDatabase(file));
      await DriftMusicLibraryRepository(before).upsertTrack(
        libraryTrack(path: '/m/beethoven.flac', title: 'Beethoven'),
      );

      await before.customStatement('DROP TRIGGER IF EXISTS tracks_fts_ai');
      await before.customStatement('DROP TRIGGER IF EXISTS tracks_fts_ad');
      await before.customStatement('DROP TRIGGER IF EXISTS tracks_fts_au');
      await before.customStatement('DROP TABLE IF EXISTS tracks_fts');
      await before.customStatement('ALTER TABLE tracks DROP COLUMN missing_at');
      await before.customStatement('PRAGMA user_version = 1');
      await before.close();

      // Reopening runs the v1 -> v2 migration.
      final after = AppDatabase(NativeDatabase(file));
      addTearDown(after.close);
      final afterRepository = DriftMusicLibraryRepository(after);

      // `rebuild` indexed the row that already existed before the upgrade.
      expect((await afterRepository.searchTracks('beet')).map((t) => t.title), [
        'Beethoven',
      ]);

      // Recreated triggers keep newly inserted rows indexed too.
      await afterRepository.upsertTrack(
        libraryTrack(path: '/m/mozart.flac', title: 'Mozart'),
      );
      expect((await afterRepository.searchTracks('moza')).map((t) => t.title), [
        'Mozart',
      ]);
    });
  });
}
