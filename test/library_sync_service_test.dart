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
import 'dart:typed_data';

import 'package:audio_metadata_reader/audio_metadata_reader.dart';
import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;

import 'package:flind_player/core/models/track.dart';
import 'package:flind_player/core/sources/source_track_id.dart';
import 'package:flind_player/data/database/app_database.dart';
import 'package:flind_player/data/repositories/drift_music_library_repository.dart';
import 'package:flind_player/data/services/library_sync_service.dart';
import 'package:flind_player/data/sources/local/artwork_cache.dart';
import 'package:flind_player/data/sources/local/local_library_scanner.dart';
import 'package:flind_player/data/sources/local/local_metadata_reader.dart';
import 'package:flind_player/data/sources/local/local_stream_resolver.dart';

void main() {
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;

  late AppDatabase db;
  late DriftMusicLibraryRepository repository;
  late Directory root;
  late Directory covers;
  late LibrarySyncService service;

  final fixture = File('test/fixtures/tone.mp3');

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    repository = DriftMusicLibraryRepository(db);
    root = Directory.systemTemp.createTempSync('flind_sync');
    covers = Directory('${root.path}/covers')..createSync(recursive: true);
    service = LibrarySyncService(
      scanner: LocalLibraryScanner(reader: LocalMetadataReader()),
      repository: repository,
      artworkCache: ArtworkCache(baseDir: covers),
      enableArtworkPass: false,
    );
  });

  tearDown(() async {
    await service.dispose();
    await db.close();
    if (root.existsSync()) {
      root.deleteSync(recursive: true);
    }
  });

  /// Copies the tone fixture into the scanned tree.
  File addTrack(String name) {
    final file = File('${root.path}/$name');
    file.parent.createSync(recursive: true);
    fixture.copySync(file.path);
    return file;
  }

  test('sync upserts scanned tracks and they become searchable', () async {
    addTrack('tone.mp3');
    await repository.addScanRoot(root.path);

    await service.sync();

    final tracks = await repository.allTracks();
    expect(tracks, hasLength(1));
    expect(tracks.single.title, 'Flind Test Tone');
    expect(await repository.searchTracks('Flind'), hasLength(1));
    expect(service.current.phase, LibrarySyncPhase.done);
    expect(service.current.discovered, 1);
    expect(service.current.saved, 1);
  });

  test('a second sync does not duplicate and skips known files', () async {
    addTrack('tone.mp3');
    await repository.addScanRoot(root.path);

    await service.sync();
    expect(service.current.saved, 1);

    await service.sync();

    expect(await repository.allTracks(), hasLength(1));
    // The file is already known: it is discovered but not re-parsed.
    expect(service.current.discovered, 1);
    expect(service.current.processed, 0);
    expect(service.current.saved, 0);
  });

  test('an empty folder does not mark the existing library missing', () async {
    await repository.upsertTrack(
      Track(
        source: 'local',
        sourceTrackId: const LocalTrackId('/old/song.mp3'),
        uri: 'local:/old/song.mp3',
        title: 'Old Song',
      ),
    );
    final empty = Directory('${root.path}/empty')..createSync(recursive: true);
    await repository.addScanRoot(empty.path);

    await service.sync();

    final tracks = await repository.allTracks();
    expect(tracks, hasLength(1));
    expect(tracks.single.title, 'Old Song');
    expect(await repository.trackUrisForSource('local'), {
      'local:/old/song.mp3',
    });
    expect(service.current.markedMissing, 0);
  });

  test('a disappearing file gets soft-deleted', () async {
    final gone = addTrack('gone.mp3');
    addTrack('stays.mp3');
    await repository.addScanRoot(root.path);

    await service.sync();
    expect(await repository.allTracks(), hasLength(2));

    gone.deleteSync();
    await service.sync();

    final visible = await repository.allTracks();
    expect(visible, hasLength(1));
    expect(visible.single.uri, endsWith('/stays.mp3'));
    expect(await repository.trackUrisForSource('local'), hasLength(2));
    expect(service.current.markedMissing, 1);
  });

  test(
    'a rescan re-parses a changed file and lands the new metadata',
    () async {
      final file = addTrack('changed.mp3');
      await repository.addScanRoot(root.path);

      await service.sync();
      expect(service.current.saved, 1);
      final original = (await repository.allTracks()).single;
      final originalFp = (await repository.trackFingerprints(
        'local',
      ))[original.uri]!;

      // Rewriting the tag changes both the bytes and the mtime, so the stored
      // fingerprint no longer matches.
      updateMetadata(file, (metadata) {
        metadata.setTitle('Renamed Tone');
      });

      await service.sync();

      expect(service.current.processed, 1);
      expect(service.current.saved, 1);
      final updated = (await repository.allTracks()).single;
      expect(updated.title, 'Renamed Tone');

      final updatedFp = (await repository.trackFingerprints(
        'local',
      ))[updated.uri]!;
      expect(
        updatedFp.mtimeMs,
        file.statSync().modified.millisecondsSinceEpoch,
      );
      expect(updatedFp.scanRoot, root.path);
      expect(
        updatedFp.sizeBytes,
        isNot(originalFp.sizeBytes),
        reason: 'rewriting the tag should change the file size',
      );
    },
  );

  test('an offline scan root keeps its tracks', () async {
    final online = Directory('${root.path}/online')..createSync();
    final offline = Directory('${root.path}/offline')..createSync();
    fixture.copySync('${online.path}/online.mp3');
    fixture.copySync('${offline.path}/offline.mp3');
    await repository.addScanRoot(online.path);
    await repository.addScanRoot(offline.path);

    await service.sync();
    expect(await repository.allTracks(), hasLength(2));

    // The offline root disappears while the other root still scans.
    offline.deleteSync(recursive: true);
    await service.sync();

    final visible = await repository.allTracks();
    expect(visible, hasLength(2));
    expect(
      visible.map((track) => track.uri),
      containsAll(<String>[
        LocalStreamResolver.uriForPath('${online.path}/online.mp3'),
        LocalStreamResolver.uriForPath('${offline.path}/offline.mp3'),
      ]),
    );
    expect(service.current.markedMissing, 0);
    expect(await repository.trackUrisForSource('local'), hasLength(2));
  });

  test('a file outside the scan roots survives while it exists', () async {
    // Regression: an individually imported file (not under any scan root) must
    // not be soft-deleted merely because a folder scan ran.
    final outside = File('${root.path}/outside.mp3');
    fixture.copySync(outside.path);
    await repository.upsertTrack(
      Track(
        source: 'local',
        sourceTrackId: LocalTrackId(outside.path),
        uri: 'local:${outside.path}',
        title: 'Imported Song',
      ),
    );

    // A scan root that is NOT empty, so the empty-scan guard does not apply.
    final scanned = Directory('${root.path}/scanned')..createSync();
    fixture.copySync('${scanned.path}/tone.mp3');
    await repository.addScanRoot(scanned.path);

    await service.sync();

    final visible = await repository.allTracks();
    expect(
      visible.map((track) => track.title),
      containsAll(<String>['Imported Song', 'Flind Test Tone']),
    );
    expect(service.current.markedMissing, 0);

    // Once the file really disappears it is soft-deleted as usual.
    outside.deleteSync();
    await service.sync();

    expect(service.current.markedMissing, 1);
    expect(
      (await repository.allTracks()).map((track) => track.title),
      isNot(contains('Imported Song')),
    );
  });

  test('sync with no scan roots completes with zero counts', () async {
    await service.sync();

    expect(service.current.phase, LibrarySyncPhase.done);
    expect(service.current.saved, 0);
    expect(await repository.allTracks(), isEmpty);
  });

  test('a concurrent sync call is a no-op', () async {
    addTrack('tone.mp3');
    await repository.addScanRoot(root.path);

    final first = service.sync();
    final second = service.sync();
    await Future.wait([first, second]);

    expect(await repository.allTracks(), hasLength(1));
    expect(service.isRunning, isFalse);
  });

  test(
    'artwork pass caches embedded covers and preserves them on rescan',
    () async {
      final file = addTrack('art.mp3');
      final image = img.Image(width: 8, height: 8);
      img.fill(image, color: img.ColorRgb8(20, 120, 200));
      final png = Uint8List.fromList(img.encodePng(image));
      updateMetadata(file, (metadata) {
        metadata.setPictures([
          Picture(png, 'image/png', PictureType.coverFront),
        ]);
      });

      final artService = LibrarySyncService(
        scanner: LocalLibraryScanner(reader: LocalMetadataReader()),
        repository: repository,
        artworkCache: ArtworkCache(baseDir: covers),
      );
      addTearDown(artService.dispose);
      await repository.addScanRoot(root.path);

      await artService.sync();

      final withCover = (await repository.allTracks()).single;
      expect(withCover.coverPath, isNotNull);
      expect(File(withCover.coverPath!).existsSync(), isTrue);
      expect(artService.current.phase, LibrarySyncPhase.done);
      expect(artService.current.coversCached, 1);

      // A rescan re-reads tags without images; the existing cover must survive.
      await artService.sync();

      final afterRescan = (await repository.allTracks()).single;
      expect(afterRescan.coverPath, withCover.coverPath);
    },
  );
}
