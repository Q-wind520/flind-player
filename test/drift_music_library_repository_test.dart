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
import 'package:flind_player/core/models/track_sort.dart';
import 'package:flind_player/core/sources/source_track_id.dart';
import 'package:flind_player/data/database/app_database.dart';
import 'package:flind_player/data/repositories/drift_music_library_repository.dart';
import 'package:flind_player/data/repositories/drift_playlist_repository.dart';
import 'package:flind_player/data/sources/local/local_library_scanner.dart';

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

  /// A scanned track whose fingerprint points at [root].
  ScannedTrack scannedTrack({
    required String path,
    required String title,
    required String root,
    int sizeBytes = 100,
    int mtimeMs = 200,
    String? artist,
    String? album,
  }) => ScannedTrack(
    track: libraryTrack(path: path, title: title, artist: artist, album: album),
    file: ScannedFile(
      path: path,
      uri: 'local:$path',
      root: root,
      sizeBytes: sizeBytes,
      mtimeMs: mtimeMs,
    ),
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

  /// Inserts a row straight into the `tracks` pool, bypassing the repository,
  /// so a test can arrange pre-existing state (e.g. a soft-deleted row).
  Future<int> insertPoolTrack({
    required String uri,
    required String title,
  }) {
    final path = uri.startsWith('local:') ? uri.substring('local:'.length) : uri;
    final now = DateTime.now().millisecondsSinceEpoch;
    return db
        .into(db.tracks)
        .insert(
          TracksCompanion.insert(
            source: 'local',
            sourceTrackId: path,
            uri: uri,
            title: title,
            createdAt: now,
            updatedAt: now,
          ),
        );
  }

  group('promoteTrack', () {
    test('inserts a new track into the pool', () async {
      final id = await repository.promoteTrack(
        const Track(
          source: 'bilibili',
          sourceTrackId: BiliTrackId(bvid: 'BV1', cid: 7),
          uri: 'bilibili:BV1:7',
          title: 'Online',
        ),
      );
      expect(id, greaterThan(0));
      final stored = await repository.findByUri('bilibili:BV1:7');
      expect(stored!.title, 'Online');
    });

    test('does not overwrite an existing row (pool wins)', () async {
      await insertPoolTrack(uri: 'local:/m/a.flac', title: 'Original');
      await repository.promoteTrack(
        const Track(
          source: 'local',
          sourceTrackId: LocalTrackId('/m/a.flac'),
          uri: 'local:/m/a.flac',
          title: 'Incoming',
        ),
      );
      expect(
        (await repository.findByUri('local:/m/a.flac'))!.title,
        'Original',
      );
    });

    test('does not resurrect a soft-deleted row', () async {
      await insertPoolTrack(uri: 'local:/m/b.flac', title: 'Gone');
      // A non-empty scan that does not see `/m/b.flac` marks it missing; the
      // row has no `scanRoot`, so it stays eligible for the sweep.
      await repository.markMissingExcept('local', {'local:/m/other.flac'});
      await repository.promoteTrack(
        const Track(
          source: 'local',
          sourceTrackId: LocalTrackId('/m/b.flac'),
          uri: 'local:/m/b.flac',
          title: 'Gone',
        ),
      );
      expect(await repository.allTracks(), isEmpty); // still missing
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

  group('upsertScannedTracks', () {
    test('persists size, mtime and scanRoot', () async {
      await repository.upsertScannedTracks([
        scannedTrack(
          path: '/m/a.flac',
          title: 'A',
          root: '/music',
          sizeBytes: 1234,
          mtimeMs: 5678,
        ),
      ]);

      final fingerprints = await repository.trackFingerprints('local');
      expect(fingerprints, hasLength(1));
      final fingerprint = fingerprints['local:/m/a.flac']!;
      expect(fingerprint.sizeBytes, 1234);
      expect(fingerprint.mtimeMs, 5678);
      expect(fingerprint.scanRoot, '/music');
    });

    test('preserves createdAt across rescans', () async {
      await repository.upsertScannedTracks([
        scannedTrack(path: '/m/a.flac', title: 'A', root: '/music'),
      ]);
      final before = await db
          .customSelect(
            "SELECT created_at FROM tracks WHERE uri = 'local:/m/a.flac'",
          )
          .getSingle();

      await repository.upsertScannedTracks([
        scannedTrack(
          path: '/m/a.flac',
          title: 'A2',
          root: '/music',
          sizeBytes: 999,
        ),
      ]);

      final after = await db
          .customSelect(
            "SELECT created_at FROM tracks WHERE uri = 'local:/m/a.flac'",
          )
          .getSingle();
      expect(after.data['created_at'], before.data['created_at']);
      expect((await repository.allTracks()).single.title, 'A2');
      expect(
        (await repository.trackFingerprints(
          'local',
        ))['local:/m/a.flac']!.sizeBytes,
        999,
      );
    });

    test('a metadata-only upsert does not clear the fingerprint', () async {
      await repository.upsertScannedTracks([
        scannedTrack(
          path: '/m/a.flac',
          title: 'A',
          root: '/music',
          sizeBytes: 1234,
          mtimeMs: 5678,
        ),
      ]);

      // Mirrors the artwork pass, which writes metadata without a file.
      await repository.upsertTracks([
        libraryTrack(path: '/m/a.flac', title: 'A with cover'),
      ]);

      final fingerprint = (await repository.trackFingerprints(
        'local',
      ))['local:/m/a.flac']!;
      expect(fingerprint.sizeBytes, 1234);
      expect(fingerprint.mtimeMs, 5678);
      expect(fingerprint.scanRoot, '/music');
    });

    test('is a no-op for an empty list', () async {
      await repository.upsertScannedTracks(const []);

      expect(await repository.allTracks(), isEmpty);
    });
  });

  group('trackFingerprints', () {
    test('tolerates null columns for rows without a fingerprint', () async {
      await repository.upsertTracks([
        libraryTrack(path: '/m/legacy.flac', title: 'Legacy'),
      ]);

      final fingerprint = (await repository.trackFingerprints(
        'local',
      ))['local:/m/legacy.flac']!;
      expect(fingerprint.sizeBytes, isNull);
      expect(fingerprint.mtimeMs, isNull);
      expect(fingerprint.scanRoot, isNull);
    });

    test('includes soft-deleted rows and is scoped to the source', () async {
      await repository.upsertScannedTracks([
        scannedTrack(path: '/m/a.flac', title: 'A', root: '/music'),
      ]);
      await repository.upsertTrack(
        Track(
          source: 'bilibili',
          sourceTrackId: const BiliTrackId(bvid: 'BV1', cid: 2),
          uri: 'bilibili:BV1:2',
          title: 'Online',
        ),
      );
      await repository.markMissingExcept('local', {'local:/m/other.flac'});

      expect(await repository.trackFingerprints('local'), hasLength(1));
      expect(await repository.trackFingerprints('bilibili'), hasLength(1));
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

    test('roots leave tracks from an unscanned root untouched', () async {
      await repository.upsertScannedTracks([
        scannedTrack(path: '/m/online.flac', title: 'Online', root: '/online'),
        scannedTrack(
          path: '/m/offline.flac',
          title: 'Offline',
          root: '/offline',
        ),
      ]);

      // `/offline` is absent from the scan, but its root was not scanned, so
      // it must survive.
      final marked = await repository.markMissingExcept(
        'local',
        {'local:/m/online.flac'},
        roots: {'/online'},
      );

      expect(marked, 0);
      expect((await repository.allTracks()).map((t) => t.uri).toSet(), {
        'local:/m/online.flac',
        'local:/m/offline.flac',
      });
    });

    test('roots still mark a vanished track whose root was scanned', () async {
      await repository.upsertScannedTracks([
        scannedTrack(path: '/m/online.flac', title: 'Online', root: '/online'),
        scannedTrack(
          path: '/m/offline.flac',
          title: 'Offline',
          root: '/offline',
        ),
      ]);

      // Both roots were scanned; only the offline file was seen again.
      final marked = await repository.markMissingExcept(
        'local',
        {'local:/m/offline.flac'},
        roots: {'/online', '/offline'},
      );

      expect(marked, 1);
      expect((await repository.allTracks()).map((t) => t.uri), [
        'local:/m/offline.flac',
      ]);
    });

    test('unattributed tracks stay eligible when roots are scoped', () async {
      await repository.upsertTracks([
        libraryTrack(path: '/m/imported.flac', title: 'Imported'),
      ]);
      await repository.upsertScannedTracks([
        scannedTrack(path: '/m/online.flac', title: 'Online', root: '/online'),
      ]);

      final marked = await repository.markMissingExcept(
        'local',
        {'local:/m/online.flac'},
        roots: {'/online'},
      );

      expect(marked, 1);
      expect((await repository.allTracks()).map((t) => t.uri), [
        'local:/m/online.flac',
      ]);
    });

    test('an empty roots set only sweeps unattributed tracks', () async {
      await repository.upsertTracks([
        libraryTrack(path: '/m/imported.flac', title: 'Imported'),
      ]);
      await repository.upsertScannedTracks([
        scannedTrack(path: '/m/online.flac', title: 'Online', root: '/online'),
      ]);

      final marked = await repository.markMissingExcept('local', {
        'local:/m/other.flac',
      }, roots: const <String>{});

      expect(marked, 1);
      expect((await repository.allTracks()).map((t) => t.uri), [
        'local:/m/online.flac',
      ]);
    });
  });

  group('track sort', () {
    Future<void> seedSortLibrary() async {
      await repository.upsertTrack(
        libraryTrack(path: '/1', title: 'Delta', artist: 'Zed', album: 'Beta'),
      );
      await Future<void>.delayed(const Duration(milliseconds: 5));
      await repository.upsertTrack(
        libraryTrack(path: '/2', title: 'alpha', album: 'Gamma'),
      );
      await Future<void>.delayed(const Duration(milliseconds: 5));
      await repository.upsertTrack(
        libraryTrack(path: '/3', title: 'Charlie', artist: 'Abe'),
      );
    }

    test('every sort produces the expected order', () async {
      await seedSortLibrary();

      Future<List<String>> uris(TrackSort sort) async =>
          (await repository.allTracks(sort: sort)).map((t) => t.uri).toList();

      expect(await uris(TrackSort.title), ['local:/2', 'local:/3', 'local:/1']);
      // Artist: 'Abe', 'Zed', then the null artist last.
      expect(await uris(TrackSort.artist), [
        'local:/3',
        'local:/1',
        'local:/2',
      ]);
      // Album: 'Beta', 'Gamma', then the null album last.
      expect(await uris(TrackSort.album), ['local:/1', 'local:/2', 'local:/3']);
      // Recency: /3 inserted last.
      expect(await uris(TrackSort.recentlyAdded), [
        'local:/3',
        'local:/2',
        'local:/1',
      ]);
    });

    test('title sort is the default', () async {
      await seedSortLibrary();

      final explicit = await repository.allTracks(sort: TrackSort.title);
      final implicit = await repository.allTracks();

      expect(implicit.map((t) => t.uri), explicit.map((t) => t.uri));
    });

    test('breaks ties on id for a stable order', () async {
      await repository.upsertTrack(libraryTrack(path: '/b', title: 'Same'));
      await repository.upsertTrack(libraryTrack(path: '/a', title: 'same'));

      expect((await repository.allTracks()).map((t) => t.uri), [
        'local:/b',
        'local:/a',
      ]);
    });

    test('watchTracks honours the requested sort', () async {
      await seedSortLibrary();
      final emissions = <List<Track>>[];
      final subscription = repository
          .watchTracks(sort: TrackSort.artist)
          .listen(emissions.add);
      addTearDown(subscription.cancel);

      await _waitFor(() => emissions.isNotEmpty);
      expect(emissions.last.map((t) => t.uri), [
        'local:/3',
        'local:/1',
        'local:/2',
      ]);
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
      await before.customStatement('DROP TABLE IF EXISTS playlists');
      await before.customStatement('DROP TABLE IF EXISTS playlist_tracks');
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

    test('v4 -> v5 adds the fingerprint columns without losing rows', () async {
      final dir = Directory.systemTemp.createTempSync('flind_migration_v5');
      addTearDown(() {
        if (dir.existsSync()) dir.deleteSync(recursive: true);
      });
      final file = File('${dir.path}/library.sqlite');

      // Build a current-schema file, then roll it back to a v4 shape by
      // dropping the columns v5 introduced.
      final before = AppDatabase(NativeDatabase(file));
      await DriftMusicLibraryRepository(before)
          .upsertTrack(libraryTrack(path: '/m/a.flac', title: 'A'));
      await before.customStatement('ALTER TABLE tracks DROP COLUMN size_bytes');
      await before.customStatement('ALTER TABLE tracks DROP COLUMN mtime_ms');
      await before.customStatement('ALTER TABLE tracks DROP COLUMN scan_root');
      await before.customStatement('DROP TABLE IF EXISTS playlists');
      await before.customStatement('DROP TABLE IF EXISTS playlist_tracks');
      await before.customStatement('PRAGMA user_version = 4');
      await before.close();

      final after = AppDatabase(NativeDatabase(file));
      addTearDown(after.close);
      final afterRepository = DriftMusicLibraryRepository(after);

      // The existing row survives and defaults to a null fingerprint.
      final migrated = (await afterRepository.trackFingerprints(
        'local',
      ))['local:/m/a.flac']!;
      expect(migrated.sizeBytes, isNull);
      expect(migrated.mtimeMs, isNull);
      expect(migrated.scanRoot, isNull);

      // The added columns are writable after the upgrade.
      await afterRepository.upsertScannedTracks([
        scannedTrack(
          path: '/m/a.flac',
          title: 'A',
          root: '/music',
          sizeBytes: 10,
          mtimeMs: 20,
        ),
      ]);
      final updated = (await afterRepository.trackFingerprints(
        'local',
      ))['local:/m/a.flac']!;
      expect(updated.sizeBytes, 10);
      expect(updated.mtimeMs, 20);
      expect(updated.scanRoot, '/music');
    });

    test('v5 -> v6 adds the cache content hash without losing rows', () async {
      final dir = Directory.systemTemp.createTempSync('flind_migration_v6');
      addTearDown(() {
        if (dir.existsSync()) dir.deleteSync(recursive: true);
      });
      final file = File('${dir.path}/library.sqlite');

      // Build a current-schema file, then roll the cache table back to v5 by
      // dropping the column v6 introduced.
      final before = AppDatabase(NativeDatabase(file));
      await before.customStatement(
        'INSERT INTO audio_cache '
        '(source, source_track_id, file_path, bytes, quality_id, pinned, '
        'cached_at, last_accessed_at) '
        "VALUES ('bilibili', 'BV1:1', '/tmp/x.m4a', 10, '30280', 0, 1, 1)",
      );
      await before.customStatement(
        'ALTER TABLE audio_cache DROP COLUMN content_hash',
      );
      await before.customStatement('DROP TABLE IF EXISTS playlists');
      await before.customStatement('DROP TABLE IF EXISTS playlist_tracks');
      await before.customStatement('PRAGMA user_version = 5');
      await before.close();

      final after = AppDatabase(NativeDatabase(file));
      addTearDown(after.close);

      // The existing cache row survives with a null hash.
      final migrated = await after
          .customSelect('SELECT content_hash FROM audio_cache')
          .getSingle();
      expect(migrated.data['content_hash'], isNull);

      // The added column is writable after the upgrade.
      await after.customStatement(
        "UPDATE audio_cache SET content_hash = 'abc'",
      );
      final updated = await after
          .customSelect('SELECT content_hash FROM audio_cache')
          .getSingle();
      expect(updated.data['content_hash'], 'abc');
    });

    test('v6 -> v7 adds the cover columns and the cover cache table', () async {
      final dir = Directory.systemTemp.createTempSync('flind_migration_v7');
      addTearDown(() {
        if (dir.existsSync()) dir.deleteSync(recursive: true);
      });
      final file = File('${dir.path}/library.sqlite');

      // Build a current-schema file, then roll it back to v6 by dropping the
      // two cover_url columns and the cover_cache table v7 introduces, plus the
      // v8 playlists tables. The legacy `favorites` table is no longer created
      // by the current schema (schema v8 removed it), so recreate it here to
      // build the v6 fixture.
      final before = AppDatabase(NativeDatabase(file));
      await before.customStatement(
        'CREATE TABLE IF NOT EXISTS favorites ('
        'id INTEGER PRIMARY KEY AUTOINCREMENT, '
        'uri TEXT NOT NULL UNIQUE, '
        'source TEXT NOT NULL, '
        'source_track_id TEXT NOT NULL, '
        'title TEXT NOT NULL, '
        'artist TEXT, '
        'album TEXT, '
        'duration_ms INTEGER, '
        'cover_path TEXT, '
        'cover_url TEXT, '
        'favorited_at INTEGER NOT NULL)',
      );
      await before.customStatement(
        'INSERT INTO tracks '
        '(source, source_track_id, uri, title, cover_path, created_at, '
        'updated_at) '
        "VALUES ('bilibili', 'BV1:1', 'bilibili:BV1:1', 'Song', NULL, 1, 1)",
      );
      await before.customStatement(
        'INSERT INTO favorites '
        '(uri, source, source_track_id, title, favorited_at) '
        "VALUES ('bilibili:BV1:1', 'bilibili', 'BV1:1', 'Song', 1)",
      );
      await before.customStatement('DROP TABLE cover_cache');
      await before.customStatement('DROP TABLE IF EXISTS playlists');
      await before.customStatement('DROP TABLE IF EXISTS playlist_tracks');
      await before.customStatement('ALTER TABLE tracks DROP COLUMN cover_url');
      await before.customStatement(
        'ALTER TABLE favorites DROP COLUMN cover_url',
      );
      await before.customStatement('PRAGMA user_version = 6');
      await before.close();

      final after = AppDatabase(NativeDatabase(file));
      addTearDown(after.close);

      // Existing rows survive with a null cover URL.
      final track = await after
          .customSelect('SELECT cover_url FROM tracks')
          .getSingle();
      expect(track.data['cover_url'], isNull);
      // The legacy favourites row migrated into the built-in playlist (the v8
      // upgrade converts `favorites` into playlist members and drops the old
      // table, then v9 backfills the pool and makes members reference-only),
      // carrying the null cover URL the v7 column add produced. Members now
      // resolve entirely through the pool.
      final member = await after
          .customSelect(
            "SELECT cover_url FROM tracks WHERE uri = 'bilibili:BV1:1'",
          )
          .getSingle();
      expect(member.data['cover_url'], isNull);

      // The recreated table is writable after the upgrade.
      await after.customStatement(
        'INSERT INTO cover_cache '
        '(url_hash, file_path, content_hash, bytes, cached_at, '
        'last_accessed_at) '
        "VALUES ('h', '/tmp/c.jpg', 'c', 1, 1, 1)",
      );
      final cover = await after
          .customSelect('SELECT url_hash FROM cover_cache')
          .getSingle();
      expect(cover.data['url_hash'], 'h');
    });

    test('v7 -> v8 converts legacy favourites into the built-in playlist',
        () async {
      final dir = Directory.systemTemp.createTempSync('flind_migration_v8');
      addTearDown(() {
        if (dir.existsSync()) dir.deleteSync(recursive: true);
      });
      final file = File('${dir.path}/library.sqlite');

      // Build a current-schema file, then roll it back to a v7 shape: no
      // playlists, and the standalone `favorites` table (with the v7 `cover_url`
      // column) carrying two rows.
      final before = AppDatabase(NativeDatabase(file));
      await before.customStatement(
        'INSERT INTO tracks '
        '(source, source_track_id, uri, title, cover_path, created_at, '
        'updated_at) '
        "VALUES ('bilibili', 'BV1:1', 'bilibili:BV1:1', 'Song', NULL, 1, 1)",
      );
      await before.customStatement('DROP TABLE IF EXISTS playlists');
      await before.customStatement('DROP TABLE IF EXISTS playlist_tracks');
      await before.customStatement(
        'CREATE TABLE IF NOT EXISTS favorites ('
        'id INTEGER PRIMARY KEY AUTOINCREMENT, '
        'uri TEXT NOT NULL UNIQUE, '
        'source TEXT NOT NULL, '
        'source_track_id TEXT NOT NULL, '
        'title TEXT NOT NULL, '
        'artist TEXT, '
        'album TEXT, '
        'duration_ms INTEGER, '
        'cover_path TEXT, '
        'cover_url TEXT, '
        'favorited_at INTEGER NOT NULL)',
      );
      await before.customStatement(
        'INSERT INTO favorites '
        '(uri, source, source_track_id, title, favorited_at) '
        "VALUES ('bilibili:BV1:1', 'bilibili', 'BV1:1', 'Song', 10)",
      );
      await before.customStatement(
        'INSERT INTO favorites '
        '(uri, source, source_track_id, title, favorited_at) '
        "VALUES ('bilibili:BV1:2', 'bilibili', 'BV1:2', 'Song 2', 20)",
      );
      await before.customStatement('PRAGMA user_version = 7');
      await before.close();

      final after = AppDatabase(NativeDatabase(file));
      addTearDown(after.close);

      // The built-in favourites playlist is seeded with the pinned id.
      final playlist = await after
          .customSelect(
            "SELECT id, name, kind FROM playlists WHERE id = 1",
          )
          .getSingle();
      expect(playlist.data['name'], 'Favorites');
      expect(playlist.data['kind'], 'favorites');

      // Legacy rows became members; `favorited_at` became `added_at`.
      final members = await after.customSelect(
        'SELECT uri, added_at FROM playlist_tracks '
        'ORDER BY added_at DESC',
      ).get();
      expect(members.map((r) => r.data['uri']), [
        'bilibili:BV1:2',
        'bilibili:BV1:1',
      ]);
      expect(members[0].data['added_at'], 20);
      expect(members[1].data['added_at'], 10);

      // The legacy table is gone.
      final legacy = await after.customSelect(
        "SELECT 1 FROM sqlite_master WHERE type='table' AND name='favorites'",
      ).get();
      expect(legacy, isEmpty);

      // The short-lived v8 `content_hash` column is gone again in v9.
      final columns = await after.customSelect(
        'PRAGMA table_info(tracks)',
      ).get();
      expect(
        columns.map((r) => r.data['name']),
        isNot(contains('content_hash')),
      );
    });

    test('v7 -> v8 without a legacy favourites table still seeds the playlist',
        () async {
      final dir = Directory.systemTemp.createTempSync('flind_migration_v8b');
      addTearDown(() {
        if (dir.existsSync()) dir.deleteSync(recursive: true);
      });
      final file = File('${dir.path}/library.sqlite');

      // A v7 file that never had the `favorites` table (e.g. a user who never
      // favourited anything).
      final before = AppDatabase(NativeDatabase(file));
      await before.customStatement('DROP TABLE IF EXISTS playlists');
      await before.customStatement('DROP TABLE IF EXISTS playlist_tracks');
      await before.customStatement('PRAGMA user_version = 7');
      await before.close();

      final after = AppDatabase(NativeDatabase(file));
      addTearDown(after.close);

      final playlist = await after
          .customSelect(
            "SELECT id, name, kind FROM playlists WHERE id = 1",
          )
          .getSingle();
      expect(playlist.data['name'], 'Favorites');
      expect(playlist.data['kind'], 'favorites');
      final members = await after
          .customSelect('SELECT COUNT(*) AS n FROM playlist_tracks')
          .getSingle();
      expect(members.data['n'], 0);
    });

    test('v7 -> v8 is idempotent when re-run over an upgraded file', () async {
      final dir = Directory.systemTemp.createTempSync('flind_migration_v8c');
      addTearDown(() {
        if (dir.existsSync()) dir.deleteSync(recursive: true);
      });
      final file = File('${dir.path}/library.sqlite');

      // Migrate once with a legacy favourite, then force the upgrade to run
      // again by rolling `user_version` back to 7.
      final first = AppDatabase(NativeDatabase(file));
      await first.customStatement('DROP TABLE IF EXISTS playlists');
      await first.customStatement('DROP TABLE IF EXISTS playlist_tracks');
      await first.customStatement(
        'CREATE TABLE IF NOT EXISTS favorites ('
        'id INTEGER PRIMARY KEY AUTOINCREMENT, '
        'uri TEXT NOT NULL UNIQUE, '
        'source TEXT NOT NULL, '
        'source_track_id TEXT NOT NULL, '
        'title TEXT NOT NULL, '
        'artist TEXT, '
        'album TEXT, '
        'duration_ms INTEGER, '
        'cover_path TEXT, '
        'cover_url TEXT, '
        'favorited_at INTEGER NOT NULL)',
      );
      await first.customStatement(
        'INSERT INTO favorites '
        '(uri, source, source_track_id, title, favorited_at) '
        "VALUES ('bilibili:BV1:1', 'bilibili', 'BV1:1', 'Song', 10)",
      );
      await first.customStatement('PRAGMA user_version = 7');
      await first.close();

      final upgraded = AppDatabase(NativeDatabase(file));
      await upgraded.customStatement('PRAGMA user_version = 7');
      await upgraded.close();

      // Re-running the upgrade must not duplicate members nor fail.
      final after = AppDatabase(NativeDatabase(file));
      addTearDown(after.close);
      final members = await after
          .customSelect('SELECT COUNT(*) AS n FROM playlist_tracks')
          .getSingle();
      expect(members.data['n'], 1);
    });

    test('a fresh v9 database seeds the built-in favourites playlist', () async {
      final db = AppDatabase(NativeDatabase.memory());
      addTearDown(db.close);

      final playlist = await db
          .customSelect(
            "SELECT id, name, kind FROM playlists WHERE id = 1",
          )
          .getSingle();
      expect(playlist.data['name'], 'Favorites');
      expect(playlist.data['kind'], 'favorites');
    });

    test('v8 -> v9 backfills the pool and rebuilds playlist_tracks', () async {
      final dir = Directory.systemTemp.createTempSync('flind_migration_v9');
      addTearDown(() {
        if (dir.existsSync()) dir.deleteSync(recursive: true);
      });
      final file = File('${dir.path}/library.sqlite');

      // Build a current (v9) file, then roll `playlist_tracks` back to its v8
      // shape (snapshot columns + position), restore the v8-only bits, pin v8.
      final before = AppDatabase(NativeDatabase(file));
      await before.customStatement('DROP TABLE playlist_tracks');
      await before.customStatement('''
CREATE TABLE playlist_tracks (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  playlist_id INTEGER NOT NULL,
  uri TEXT NOT NULL,
  source TEXT NOT NULL,
  source_track_id TEXT NOT NULL,
  title TEXT NOT NULL,
  artist TEXT,
  album TEXT,
  duration_ms INTEGER,
  cover_path TEXT,
  cover_url TEXT,
  added_at INTEGER NOT NULL,
  position INTEGER,
  UNIQUE (playlist_id, uri)
)
''');
      // A member that is NOT in tracks — the v8 favourites-snapshot case.
      await before.customStatement(
        'INSERT INTO playlist_tracks '
        '(playlist_id, uri, source, source_track_id, title, artist, added_at, '
        "cover_url) VALUES (1, 'bilibili:BV1:7', 'bilibili', 'BV1:7', 'Online', "
        "'UP', 5, 'https://x/c.webp')",
      );
      await before.customStatement(
        'ALTER TABLE tracks ADD COLUMN content_hash TEXT',
      );
      await before.customStatement(
        'CREATE TABLE scan_state (key TEXT PRIMARY KEY, value TEXT)',
      );
      await before.customStatement('PRAGMA user_version = 8');
      await before.close();

      final after = AppDatabase(NativeDatabase(file));
      addTearDown(after.close);

      // Backfill promoted the member into the pool.
      final pool = await after.select(after.tracks).get();
      expect(pool, hasLength(1));
      expect(pool.single.uri, 'bilibili:BV1:7');
      expect(pool.single.title, 'Online');

      // tracks.content_hash removed.
      final cols = await after.customSelect('PRAGMA table_info(tracks)').get();
      expect(cols.map((r) => r.data['name']), isNot(contains('content_hash')));

      // scan_state removed.
      final tables = await after
          .customSelect(
            "SELECT name FROM sqlite_master WHERE type='table' "
            "AND name='scan_state'",
          )
          .get();
      expect(tables, isEmpty);

      // playlist_tracks is reference-only.
      final ptCols = await after
          .customSelect('PRAGMA table_info(playlist_tracks)')
          .get();
      expect(ptCols.map((r) => r.data['name']).toSet(), {
        'id',
        'playlist_id',
        'uri',
        'added_at',
      });

      // The ordering index survives the rebuild.
      final idx = await after
          .customSelect(
            "SELECT name FROM sqlite_master WHERE type='index' "
            "AND name='idx_playlist_tracks_order'",
          )
          .get();
      expect(idx, hasLength(1));

      // The member resolves through the pool.
      final repo = DriftPlaylistRepository(after);
      final members = await repo.playlistTracks(1);
      expect(members.single.title, 'Online');
      expect(members.single.id, isNotNull);
    });
  });
}
