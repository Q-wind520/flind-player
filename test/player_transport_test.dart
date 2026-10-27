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

import 'package:flind_player/app/theme/app_icons.dart';
import 'package:flind_player/core/models/playback_queue.dart';
import 'package:flind_player/core/models/playback_state.dart';
import 'package:flind_player/core/models/repeat_mode.dart';
import 'package:flind_player/core/models/track.dart';
import 'package:flind_player/core/repositories/favorites_repository.dart';
import 'package:flind_player/core/services/playback_controller.dart';
import 'package:flind_player/core/sources/source_track_id.dart';
import 'package:flind_player/data/providers/playback_providers.dart';
import 'package:flind_player/data/providers/persistence_providers.dart';
import 'package:flind_player/features/player/mini_settings.dart';
import 'package:flind_player/features/player/player_screen.dart';

import 'support/l10n.dart';
import 'support/motion.dart';

/// A fake [PlaybackController] that records mode changes and emits the
/// resulting [PlaybackState], driving the transport row through a full cycle.
class _FakePlaybackController implements PlaybackController {
  _FakePlaybackController(this._currentState);

  final _stateController = StreamController<PlaybackState>.broadcast();

  /// Ordered log of `(method, argument)` pairs, e.g. `('shuffle', true)`.
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
  Future<void> setRepeatMode(RepeatMode mode) async {
    calls.add(('repeat', mode));
    _emit(_currentState.copyWith(repeatMode: mode));
  }

  @override
  Future<void> setShuffle(bool enabled) async {
    calls.add(('shuffle', enabled));
    _emit(_currentState.copyWith(shuffleEnabled: enabled));
  }

  @override
  Future<void> setSpeed(double speed) async {}

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
  setUpAll(disableTestMotion);
  group('Player transport controls', () {
    testWidgets('mode button cycles 顺序 → 列表循环 → 单曲循环 → 随机 → 顺序', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(800, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      final controller = _FakePlaybackController(_playingState());
      await tester.pumpWidget(_app(controller));
      await tester.pumpAndSettle();

      // The mode cycler lives in MiniSettings; the transport ends with the
      // playlist button instead.
      Finder modeButton(IconData icon) => find.descendant(
        of: find.byType(MiniSettings),
        matching: find.byIcon(icon),
      );

      expect(modeButton(AppIcons.playlistPlay), findsOneWidget);

      // 顺序播放 → 列表循环.
      await tester.tap(modeButton(AppIcons.playlistPlay));
      await tester.pumpAndSettle();
      expect(controller.calls, [
        ('shuffle', false),
        ('repeat', RepeatMode.all),
      ]);
      expect(modeButton(AppIcons.repeat), findsOneWidget);

      // 列表循环 → 单曲循环.
      await tester.tap(modeButton(AppIcons.repeat));
      await tester.pumpAndSettle();
      expect(controller.calls.sublist(2), [
        ('shuffle', false),
        ('repeat', RepeatMode.one),
      ]);
      expect(modeButton(AppIcons.repeatOne), findsOneWidget);

      // 单曲循环 → 随机播放 (shuffle is applied before the repeat mode).
      await tester.tap(modeButton(AppIcons.repeatOne));
      await tester.pumpAndSettle();
      expect(controller.calls.sublist(4), [
        ('shuffle', true),
        ('repeat', RepeatMode.off),
      ]);
      expect(modeButton(AppIcons.shuffle), findsOneWidget);

      // 随机播放 → 顺序播放.
      await tester.tap(modeButton(AppIcons.shuffle));
      await tester.pumpAndSettle();
      expect(controller.calls.sublist(6), [
        ('shuffle', false),
        ('repeat', RepeatMode.off),
      ]);
      expect(modeButton(AppIcons.playlistPlay), findsOneWidget);
      expect(controller.calls, hasLength(8));
    });

    testWidgets('favourite sits leftmost and the playlist button rightmost', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(800, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      final controller = _FakePlaybackController(_playingState());
      await tester.pumpWidget(_app(controller));
      await tester.pumpAndSettle();

      final favourite = tester
          .getTopLeft(find.byIcon(AppIcons.favoriteBorder))
          .dx;
      final previous = tester.getTopLeft(find.byIcon(AppIcons.skipPrevious)).dx;
      final playPause = tester.getTopLeft(find.byIcon(AppIcons.playArrow)).dx;
      final next = tester.getTopLeft(find.byIcon(AppIcons.skipNext)).dx;
      final playlist = tester.getTopLeft(find.byIcon(AppIcons.queueMusic)).dx;

      expect(favourite, lessThan(previous));
      expect(previous, lessThan(playPause));
      expect(playPause, lessThan(next));
      expect(next, lessThan(playlist));
    });

    testWidgets('five controls fit at 280×640 without overflow', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(280, 640);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      final controller = _FakePlaybackController(_playingState());
      await tester.pumpWidget(_app(controller));
      await tester.pumpAndSettle();

      expect(find.byIcon(AppIcons.favoriteBorder), findsOneWidget);
      expect(find.byIcon(AppIcons.skipPrevious), findsOneWidget);
      expect(find.byIcon(AppIcons.playArrow), findsOneWidget);
      expect(find.byIcon(AppIcons.skipNext), findsOneWidget);
      expect(find.byIcon(AppIcons.queueMusic), findsOneWidget);
      // The mode cycler still fits, now in MiniSettings.
      expect(find.byIcon(AppIcons.playlistPlay), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });

  group('Player layout', () {
    /// The rendered size of the [IconButton] wrapping [icon].
    double buttonSize(WidgetTester tester, IconData icon) {
      final button = find.ancestor(
        of: find.byIcon(icon),
        matching: find.byType(IconButton),
      );
      return tester.getSize(button).width;
    }

    testWidgets('transport builds a size hierarchy around play/pause', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(800, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      final controller = _FakePlaybackController(_playingState());
      await tester.pumpWidget(_app(controller));
      await tester.pumpAndSettle();

      final play = buttonSize(tester, AppIcons.playArrow);
      final previous = buttonSize(tester, AppIcons.skipPrevious);
      final next = buttonSize(tester, AppIcons.skipNext);
      final favourite = buttonSize(tester, AppIcons.favoriteBorder);
      final playlist = buttonSize(tester, AppIcons.queueMusic);

      expect(play, 64);
      expect(previous, 52);
      expect(next, 52);
      expect(favourite, 44);
      expect(playlist, 44);

      expect(play, greaterThan(previous));
      expect(previous, greaterThan(favourite));
      expect(next, greaterThan(playlist));
    });

    testWidgets('480×320 landscape left pane fits without overflow', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(480, 320);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      final controller = _FakePlaybackController(_playingState());
      await tester.pumpWidget(_app(controller));
      await tester.pumpAndSettle();

      expect(find.byIcon(AppIcons.favoriteBorder), findsOneWidget);
      expect(find.byIcon(AppIcons.skipPrevious), findsOneWidget);
      expect(find.byIcon(AppIcons.playArrow), findsOneWidget);
      expect(find.byIcon(AppIcons.skipNext), findsOneWidget);
      expect(find.byIcon(AppIcons.queueMusic), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('short portrait window fits without overflow', (tester) async {
      tester.view.physicalSize = const Size(320, 480);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      final controller = _FakePlaybackController(_playingState());
      await tester.pumpWidget(_app(controller));
      await tester.pumpAndSettle();

      expect(find.byIcon(AppIcons.playArrow), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('cover art grows with the window', (tester) async {
      double coverSize() {
        final container = find.ancestor(
          of: find.byIcon(AppIcons.musicNote),
          matching: find.byType(Container),
        );
        return tester.getSize(container).width;
      }

      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      final controller = _FakePlaybackController(_playingState());

      tester.view.physicalSize = const Size(400, 800);
      await tester.pumpWidget(_app(controller));
      await tester.pumpAndSettle();
      final small = coverSize();

      // The portrait cover is 72 % of the pane's width and the pane is
      // width-bound at 400×800, so it shrinks only when the rolling lyrics
      // need their minimum height (short viewports).
      final coverArea = tester.getSize(
        find
            .ancestor(
              of: find.byIcon(AppIcons.musicNote),
              matching: find.byType(LayoutBuilder),
            )
            .first,
      );
      expect(small, closeTo(coverArea.width * 0.72, 2));

      // A large landscape window: the old landscape formula capped the cover
      // at 280 here, so this also guards against landscape shrinking it.
      tester.view.physicalSize = const Size(1200, 800);
      await tester.pumpAndSettle();
      final large = coverSize();

      expect(small, greaterThan(0));
      expect(large, greaterThan(small));
      expect(large, greaterThan(300));

      // Very large windows stay bounded by the 480 px ceiling.
      tester.view.physicalSize = const Size(3000, 2000);
      await tester.pumpAndSettle();
      expect(coverSize(), 480);
    });
  });
}
