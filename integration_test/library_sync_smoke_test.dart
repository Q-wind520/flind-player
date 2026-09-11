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

import 'package:flind_player/core/models/playback_queue.dart';
import 'package:flind_player/data/providers/database_providers.dart';
import 'package:flind_player/data/providers/library_providers.dart';
import 'package:flind_player/data/providers/playback_providers.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:just_audio_media_kit/just_audio_media_kit.dart';

import 'support/isolated_database.dart';

/// M2 acceptance smoke test: scan a folder -> tracks land in the library ->
/// FTS finds them -> one plays. Runs against a throwaway database so it never
/// touches the user's real library.
///
/// Run with:
/// `flutter test integration_test/library_sync_smoke_test.dart -d linux`
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('scan folder -> FTS search -> play a scanned track', (
    tester,
  ) async {
    if (Platform.isLinux || Platform.isWindows) {
      JustAudioMediaKit.ensureInitialized();
    }

    final container = ProviderContainer(overrides: isolatedDatabaseOverrides());
    addTearDown(container.dispose);

    final repository = container.read(musicLibraryRepositoryProvider);
    final syncService = container.read(librarySyncServiceProvider);

    final root = Directory.systemTemp.createTempSync('flind_m2_smoke');
    final fixture = File('test/fixtures/tone.mp3');
    expect(fixture.existsSync(), isTrue, reason: 'fixture missing');

    // Nested tree proves the recursive walk works.
    fixture.copySync('${root.path}/alpha.mp3');
    Directory('${root.path}/nested').createSync();
    fixture.copySync('${root.path}/nested/beta.mp3');
    File('${root.path}/notes.txt').writeAsStringSync('not audio');

    addTearDown(() async {
      await repository.removeScanRoot(root.path);
      if (root.existsSync()) root.deleteSync(recursive: true);
    });

    await repository.addScanRoot(root.path);
    await syncService.sync();

    final tracks = await repository.allTracks();
    final scanned = tracks
        .where((track) => track.uri.contains(root.path))
        .toList();
    debugPrint(
      'sync phase=${syncService.current.phase} '
      'discovered=${syncService.current.discovered} '
      'saved=${syncService.current.saved}',
    );
    for (final track in scanned) {
      debugPrint('  scanned: ${track.title} | ${track.artist} | ${track.uri}');
    }
    expect(scanned, hasLength(2), reason: 'both nested and flat files found');

    // FTS5 search ------------------------------------------------------------
    final byTitle = await repository.searchTracks('Flind');
    expect(byTitle, isNotEmpty, reason: 'FTS should match the tagged title');
    final byPrefix = await repository.searchTracks('tone');
    expect(byPrefix, isNotEmpty, reason: 'FTS should prefix-match');
    final byArtist = await repository.searchTracks('Flind');
    expect(byArtist, isNotEmpty, reason: 'FTS should match the artist column');
    debugPrint(
      'FTS "Flind" -> ${byTitle.length} hits, '
      '"tone" -> ${byPrefix.length} hits',
    );

    // Play the scanned file --------------------------------------------------
    final controller = container.read(playbackControllerProvider);
    addTearDown(controller.dispose);
    final picked = scanned.first;
    await controller.playQueue(
      PlaybackQueue(
        tracks: [picked],
        currentIndex: 0,
        originalOrder: const [0],
      ),
    );

    var started = false;
    for (var i = 0; i < 40; i++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 250)),
      );
      await tester.pump();
      final snapshot = controller.currentState;
      debugPrint(
        'tick $i playing=${snapshot.isPlaying} '
        'position=${snapshot.position.inMilliseconds}ms '
        'duration=${snapshot.duration?.inMilliseconds}ms',
      );
      if (snapshot.isPlaying && snapshot.position > Duration.zero) {
        started = true;
        break;
      }
    }

    expect(started, isTrue, reason: 'scanned track never started playing');
  }, timeout: const Timeout(Duration(minutes: 3)));
}
