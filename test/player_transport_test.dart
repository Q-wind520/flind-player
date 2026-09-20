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
import 'package:flind_player/features/player/mini_settings.dart';
import 'package:flind_player/features/player/player_screen.dart';

import 'support/l10n.dart';

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

      expect(modeButton(Icons.playlist_play), findsOneWidget);

      // 顺序播放 → 列表循环.
      await tester.tap(modeButton(Icons.playlist_play));
      await tester.pumpAndSettle();
      expect(controller.calls, [
        ('shuffle', false),
        ('repeat', RepeatMode.all),
      ]);
      expect(modeButton(Icons.repeat), findsOneWidget);

      // 列表循环 → 单曲循环.
      await tester.tap(modeButton(Icons.repeat));
      await tester.pumpAndSettle();
      expect(controller.calls.sublist(2), [
        ('shuffle', false),
        ('repeat', RepeatMode.one),
      ]);
      expect(modeButton(Icons.repeat_one), findsOneWidget);

      // 单曲循环 → 随机播放 (shuffle is applied before the repeat mode).
      await tester.tap(modeButton(Icons.repeat_one));
      await tester.pumpAndSettle();
      expect(controller.calls.sublist(4), [
        ('shuffle', true),
        ('repeat', RepeatMode.off),
      ]);
      expect(modeButton(Icons.shuffle), findsOneWidget);

      // 随机播放 → 顺序播放.
      await tester.tap(modeButton(Icons.shuffle));
      await tester.pumpAndSettle();
      expect(controller.calls.sublist(6), [
        ('shuffle', false),
        ('repeat', RepeatMode.off),
      ]);
      expect(modeButton(Icons.playlist_play), findsOneWidget);
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
          .getTopLeft(find.byIcon(Icons.favorite_border))
          .dx;
      final previous = tester.getTopLeft(find.byIcon(Icons.skip_previous)).dx;
      final playPause = tester.getTopLeft(find.byIcon(Icons.play_arrow)).dx;
      final next = tester.getTopLeft(find.byIcon(Icons.skip_next)).dx;
      final playlist = tester.getTopLeft(find.byIcon(Icons.queue_music)).dx;

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

      expect(find.byIcon(Icons.favorite_border), findsOneWidget);
      expect(find.byIcon(Icons.skip_previous), findsOneWidget);
      expect(find.byIcon(Icons.play_arrow), findsOneWidget);
      expect(find.byIcon(Icons.skip_next), findsOneWidget);
      expect(find.byIcon(Icons.queue_music), findsOneWidget);
      // The mode cycler still fits, now in MiniSettings.
      expect(find.byIcon(Icons.playlist_play), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });
}
