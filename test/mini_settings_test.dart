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

import 'dart:async';

import 'package:flutter/material.dart' hide RepeatMode;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:flind_player/core/models/playback_queue.dart';
import 'package:flind_player/core/models/playback_state.dart';
import 'package:flind_player/core/models/repeat_mode.dart';
import 'package:flind_player/core/models/track.dart';
import 'package:flind_player/core/repositories/favorites_repository.dart';
import 'package:flind_player/core/services/playback_controller.dart';
import 'package:flind_player/core/sources/source_track_id.dart';
import 'package:flind_player/data/providers/playback_providers.dart';
import 'package:flind_player/data/providers/persistence_providers.dart';
import 'package:flind_player/features/player/lyrics_view.dart';
import 'package:flind_player/features/player/mini_settings.dart';
import 'package:flind_player/features/player/player_screen.dart';

import 'support/l10n.dart';

/// A fake [PlaybackController] that records volume changes and emits the
/// resulting [PlaybackState].
class _FakePlaybackController implements PlaybackController {
  _FakePlaybackController(this._currentState);

  final _stateController = StreamController<PlaybackState>.broadcast();

  /// Ordered log of `(method, argument)` pairs, e.g. `('volume', 0.8)`.
  final calls = <(String, Object)>[];

  PlaybackState _currentState;

  @override
  Stream<PlaybackState> get state async* {
    yield _currentState;
    yield* _stateController.stream;
  }

  @override
  PlaybackState get currentState => _currentState;

  @override
  Future<void> setVolume(double volume) async {
    calls.add(('volume', volume));
    _emit(_currentState.copyWith(volume: volume));
  }

  void _emit(PlaybackState next) {
    _currentState = next;
    _stateController.add(next);
  }

  // Unused members.
  @override
  PlaybackQueue get queue =>
      const PlaybackQueue(tracks: [], currentIndex: 0, originalOrder: []);
  @override
  Future<void> playQueue(
    PlaybackQueue queue, {
    int index = 0,
    bool autoPlay = true,
  }) async {}
  @override
  Future<void> updateTrackCover(
    String uri, {
    String? coverPath,
    String? coverUrl,
  }) async {}
  @override
  Future<void> play() async {}
  @override
  Future<void> pause() async {}
  @override
  Future<void> togglePlayPause() async {}
  @override
  Future<void> next() async {}
  @override
  Future<void> previous() async {}
  @override
  Future<void> seek(Duration position) async {}
  @override
  Future<void> setRepeatMode(RepeatMode mode) async {}
  @override
  Future<void> setShuffle(bool enabled) async {}
  @override
  Future<void> dispose() async {
    await _stateController.close();
  }
}

/// Minimal in-memory [FavoritesRepository] used only for read paths.
class _FakeFavoritesRepository implements FavoritesRepository {
  @override
  Stream<List<Track>> watchFavorites() => Stream.value(const <Track>[]);

  @override
  Future<List<Track>> allFavorites() async => const <Track>[];

  @override
  Future<bool> isFavorite(String uri) async => false;

  @override
  Future<void> addFavorite(Track track) async {}

  @override
  Future<void> removeFavorite(String uri) async {}

  @override
  Future<void> updateFavoriteCover(
    String uri, {
    String? coverPath,
    String? coverUrl,
  }) async {}

  @override
  Future<bool> toggleFavorite(Track track) async => false;
}

Track _track() {
  return Track(
    source: 'local',
    sourceTrackId: const LocalTrackId('/music/test.mp3'),
    uri: 'local:/music/test.mp3',
    title: 'Test Song',
  );
}

/// A state with a loaded track and both neighbours available.
PlaybackState _playingState() {
  return PlaybackState(
    isPlaying: false,
    isBuffering: false,
    isCompleted: false,
    position: Duration.zero,
    currentTrack: _track(),
    hasNext: true,
    hasPrevious: true,
  );
}

/// Pumps [PlayerScreen] with playback and favourites overridden.
Widget _app(_FakePlaybackController controller) {
  return ProviderScope(
    overrides: [
      playbackStateProvider.overrideWith((ref) => controller.state),
      playbackControllerProvider.overrideWith((ref) => controller),
      favoritesRepositoryProvider.overrideWithValue(_FakeFavoritesRepository()),
    ],
    child: localizedApp(const PlayerScreen()),
  );
}

void main() {
  group('MiniSettings', () {
    testWidgets('renders all five buttons by their icons', (tester) async {
      tester.view.physicalSize = const Size(800, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      final controller = _FakePlaybackController(_playingState());
      await tester.pumpWidget(_app(controller));
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.more_vert), findsOneWidget);
      expect(find.byIcon(Icons.tune), findsOneWidget);
      expect(find.byIcon(Icons.bedtime_outlined), findsOneWidget);
      expect(find.byIcon(Icons.volume_up), findsOneWidget);
      expect(find.byIcon(Icons.queue_music), findsOneWidget);
    });

    testWidgets('tapping the volume button opens the VolumeBar', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(800, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      final controller = _FakePlaybackController(_playingState());
      await tester.pumpWidget(_app(controller));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(MiniSettings.volumeKey));
      await tester.pumpAndSettle();

      expect(find.byType(VolumeBar), findsOneWidget);
      // MiniSettings stays in the slot, covered by the full-area scrim.
      expect(find.byType(MiniSettings), findsOneWidget);
      expect(find.text(testL10n().volumePercent(100)), findsOneWidget);

      // Tapping the scrim (away from the volume bar) closes the overlay.
      await tester.tapAt(const Offset(400, 200));
      await tester.pumpAndSettle();

      expect(find.byType(VolumeBar), findsNothing);
      expect(find.byType(MiniSettings), findsOneWidget);
    });

    testWidgets('tapping 更多 opens a panel showing 暂无内容', (tester) async {
      tester.view.physicalSize = const Size(800, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      final controller = _FakePlaybackController(_playingState());
      await tester.pumpWidget(_app(controller));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(MiniSettings.moreKey));
      await tester.pumpAndSettle();

      expect(find.text(testL10n().playerPanelEmpty), findsOneWidget);
      expect(find.text(testL10n().playerMore), findsOneWidget);
    });

    testWidgets('does not overflow at 280 px width', (tester) async {
      tester.view.physicalSize = const Size(280, 640);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      final controller = _FakePlaybackController(_playingState());
      await tester.pumpWidget(_app(controller));
      await tester.pumpAndSettle();

      expect(find.byType(MiniSettings), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });

  group('PlayerScreen portrait layout', () {
    testWidgets(
      'orders title above cover above lyrics preview above transport',
      (tester) async {
        tester.view.physicalSize = const Size(800, 900);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.reset);

        final controller = _FakePlaybackController(_playingState());
        await tester.pumpWidget(_app(controller));
        await tester.pumpAndSettle();

        final titleDy = tester.getTopLeft(find.text('Test Song')).dy;
        final coverDy = tester.getTopLeft(find.byIcon(Icons.music_note)).dy;
        final lyricsDy = tester.getTopLeft(find.byType(LyricsPreview)).dy;
        final sliderDy = tester.getTopLeft(find.byType(Slider)).dy;
        final transportDy = tester.getTopLeft(find.byIcon(Icons.play_arrow)).dy;

        expect(titleDy, lessThan(coverDy));
        expect(coverDy, lessThan(lyricsDy));
        expect(lyricsDy, lessThan(sliderDy));
        expect(sliderDy, lessThan(transportDy));
      },
    );

    testWidgets('renders the artist exactly once in the header', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(800, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      final track = Track(
        source: 'local',
        sourceTrackId: const LocalTrackId('/music/test.mp3'),
        uri: 'local:/music/test.mp3',
        title: 'Test Song',
        artist: 'Test Artist',
      );
      final state = PlaybackState(
        isPlaying: false,
        isBuffering: false,
        isCompleted: false,
        position: Duration.zero,
        currentTrack: track,
        hasNext: true,
        hasPrevious: true,
      );
      final controller = _FakePlaybackController(state);
      await tester.pumpWidget(_app(controller));
      await tester.pumpAndSettle();

      // The artist lives only in the header row, never duplicated in the
      // content below.
      expect(find.text('Test Artist'), findsOneWidget);
      expect(find.text('Test Song'), findsOneWidget);
    });

    testWidgets('hides MiniSettings while the lyrics page is expanded', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(800, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      final controller = _FakePlaybackController(_playingState());
      await tester.pumpWidget(_app(controller));
      await tester.pumpAndSettle();

      expect(find.byType(MiniSettings), findsOneWidget);

      await tester.tap(find.byType(LyricsPreview));
      await tester.pumpAndSettle();

      expect(find.byType(LyricsView), findsOneWidget);
      expect(find.byType(MiniSettings), findsNothing);
      expect(find.byType(VolumeBar), findsNothing);

      // Tapping the lyrics again collapses back to the normal layout.
      await tester.tap(find.byType(LyricsView));
      await tester.pumpAndSettle();
      expect(find.byType(MiniSettings), findsOneWidget);
    });

    testWidgets('hides the settings slot when nothing is playing', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(800, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      final controller = _FakePlaybackController(PlaybackState.idle);
      await tester.pumpWidget(_app(controller));
      await tester.pumpAndSettle();

      expect(find.text(testL10n().notPlaying), findsOneWidget);
      expect(find.byType(MiniSettings), findsNothing);
      expect(find.byType(VolumeBar), findsNothing);
    });
  });

  group('PlayerScreen landscape layout', () {
    testWidgets('orders the left pane and embeds MiniSettings in it', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(800, 600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      final controller = _FakePlaybackController(_playingState());
      await tester.pumpWidget(_app(controller));
      await tester.pumpAndSettle();

      // Left pane order: header artist, title, cover, progress, transport.
      final artistDy = tester.getTopLeft(find.text('未知艺术家')).dy;
      final titleDy = tester.getTopLeft(find.text('Test Song')).dy;
      final coverDy = tester.getTopLeft(find.byIcon(Icons.music_note)).dy;
      final sliderDy = tester.getTopLeft(find.byType(Slider)).dy;
      final transportDy = tester.getTopLeft(find.byIcon(Icons.play_arrow)).dy;

      expect(artistDy, lessThan(titleDy));
      expect(titleDy, lessThan(coverDy));
      expect(coverDy, lessThan(sliderDy));
      expect(sliderDy, lessThan(transportDy));

      // MiniSettings sits inside the left pane (the left half of the screen).
      final settingsCenter = tester.getCenter(find.byType(MiniSettings));
      expect(settingsCenter.dx, lessThan(400)); // 800 / 2
      expect(settingsCenter.dx, greaterThan(0));

      // The right pane is the full-height lyrics view.
      expect(find.byType(LyricsView), findsOneWidget);
    });
  });
}
