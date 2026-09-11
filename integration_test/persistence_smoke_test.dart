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
import 'package:flind_player/core/models/repeat_mode.dart';
import 'package:flind_player/core/models/track.dart';
import 'package:flind_player/core/repositories/favorites_repository.dart';
import 'package:flind_player/core/sources/source_track_id.dart';
import 'package:flind_player/data/providers/persistence_providers.dart';
import 'package:flind_player/data/providers/playback_providers.dart';
import 'package:flind_player/data/services/playback_persistence_service.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:just_audio_media_kit/just_audio_media_kit.dart';

/// M5 acceptance smoke test on the real (on-disk) database:
/// play + seek + set repeat/shuffle -> persist -> "restart" (fresh container)
/// -> restore -> the queue/favourites come back, paused.
///
/// Run with:
/// `flutter test integration_test/persistence_smoke_test.dart -d linux`
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  Track track(String name) {
    final path = '${Directory.current.path}/test/fixtures/$name';
    return Track(
      source: 'local',
      sourceTrackId: LocalTrackId(path),
      uri: 'local:$path',
      title: 'M5 $name',
      artist: 'Flind',
    );
  }

  /// This test runs against the real on-disk database, so reset the favourites
  /// table instead of assuming it is empty (earlier runs leave rows behind).
  Future<void> clearFavorites(FavoritesRepository repository) async {
    for (final favourite in await repository.allFavorites()) {
      await repository.removeFavorite(favourite.uri);
    }
  }

  testWidgets('queue and favourites survive a restart', (tester) async {
    if (Platform.isLinux || Platform.isWindows) {
      JustAudioMediaKit.ensureInitialized();
    }

    // Two LOCAL tracks: resolving a remote one would need the network and make
    // this persistence test flaky.
    final tempDir = Directory.systemTemp.createTempSync('flind_m5');
    addTearDown(() {
      if (tempDir.existsSync()) tempDir.deleteSync(recursive: true);
    });
    final secondPath = '${tempDir.path}/second.mp3';
    File('${Directory.current.path}/test/fixtures/tone.mp3')
        .copySync(secondPath);

    final first = track('tone.mp3');
    final second = Track(
      source: 'local',
      sourceTrackId: LocalTrackId(secondPath),
      uri: 'local:$secondPath',
      title: 'M5 Second',
      artist: 'Flind',
    );

    // ---- session 1: play, seek, configure, favourite ------------------------
    final session1 = ProviderContainer();
    final controller1 = session1.read(playbackControllerProvider);
    final persistence1 = PlaybackPersistenceService(
      playback: controller1,
      repository: session1.read(playbackSnapshotRepositoryProvider),
    );

    await controller1.playQueue(
      PlaybackQueue(
        tracks: [first, second],
        currentIndex: 0,
        originalOrder: const [0, 1],
      ),
      index: 1,
    );
    await controller1.setRepeatMode(RepeatMode.all);
    await controller1.setShuffle(false);
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 1500)),
    );
    await controller1.seek(const Duration(seconds: 3));
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 1200)),
    );
    persistence1.start();
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 1200)),
    );

    final saved = await session1
        .read(playbackSnapshotRepositoryProvider)
        .load();
    debugPrint(
      'saved snapshot: tracks=${saved?.queue.length} '
      'index=${saved?.queue.currentIndex} '
      'position=${saved?.position.inMilliseconds}ms '
      'repeat=${saved?.repeatMode}',
    );
    expect(saved, isNotNull);
    expect(saved!.queue.length, 2);
    expect(saved.queue.currentIndex, 1);
    expect(saved.repeatMode, RepeatMode.all);

    final favorites = session1.read(favoritesRepositoryProvider);
    await clearFavorites(favorites);
    await favorites.toggleFavorite(first);
    await favorites.toggleFavorite(second);
    expect(await favorites.isFavorite(first.uri), isTrue);

    await persistence1.dispose();
    await controller1.dispose();
    session1.dispose();
    debugPrint('session 1 closed (simulating app exit)');

    // ---- session 2: a fresh container, i.e. a restart ----------------------
    final session2 = ProviderContainer();
    final controller2 = session2.read(playbackControllerProvider);
    final persistence2 = PlaybackPersistenceService(
      playback: controller2,
      repository: session2.read(playbackSnapshotRepositoryProvider),
    );
    addTearDown(() async {
      // Clean up the shared database BEFORE tearing the container down.
      final repo = session2.read(playbackSnapshotRepositoryProvider);
      final favs = session2.read(favoritesRepositoryProvider);
      await repo.clear();
      await clearFavorites(favs);

      await persistence2.dispose();
      await controller2.dispose();
      session2.dispose();
    });

    await persistence2.restore();

    final restored = controller2.currentState;
    debugPrint(
      'restored: queue=${controller2.queue.length} '
      'index=${controller2.queue.currentIndex} '
      'track=${restored.currentTrack?.title} '
      'position=${restored.position.inMilliseconds}ms '
      'playing=${restored.isPlaying} '
      'repeat=${restored.repeatMode}',
    );
    expect(controller2.queue.length, 2);
    expect(controller2.queue.currentIndex, 1);
    expect(restored.currentTrack?.title, 'M5 Second');
    // The seek landed at 3 s and playback kept advancing before the snapshot
    // was written, so assert a window rather than an exact value.
    expect(restored.position.inMilliseconds, greaterThanOrEqualTo(3000));
    expect(restored.position.inMilliseconds, lessThan(8000));
    expect(restored.repeatMode, RepeatMode.all);
    expect(restored.isPlaying, isFalse, reason: 'restore must come up paused');

    final restoredFavorites = await session2
        .read(favoritesRepositoryProvider)
        .allFavorites();
    debugPrint('restored favourites: ${restoredFavorites.length}');
    expect(restoredFavorites, hasLength(2));
  }, timeout: const Timeout(Duration(minutes: 3)));
}
