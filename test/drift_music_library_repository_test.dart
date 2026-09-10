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
}
