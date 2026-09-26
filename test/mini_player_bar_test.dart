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
import 'package:flind_player/features/player/mini_player_bar.dart';
import 'package:flind_player/features/player/player_screen.dart';

import 'support/l10n.dart';

/// A minimal fake [PlaybackController] that records calls.
class _FakePlaybackController implements PlaybackController {
  int togglePlayPauseCalls = 0;
  int nextCalls = 0;

  @override
  Future<void> togglePlayPause() async {
    togglePlayPauseCalls++;
  }

  @override
  Future<void> next() async {
    nextCalls++;
  }

  // Unused members.
  @override
  Stream<PlaybackState> get state => const Stream.empty();
  @override
  PlaybackState get currentState => PlaybackState.idle;
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
  Future<void> previous() async {}
  @override
  Future<void> seek(Duration position) async {}
  @override
  Future<void> setRepeatMode(RepeatMode mode) async {}
  @override
  Future<void> setShuffle(bool enabled) async {}

  @override
  Future<void> setVolume(double volume) async {}
  @override
  Future<void> dispose() async {}
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

Track _track(String title, {String? artist}) {
  return Track(
    source: 'local',
    sourceTrackId: const LocalTrackId('/music/test.mp3'),
    uri: 'local:/music/test.mp3',
    title: title,
    artist: artist,
  );
}

Widget _app({
  PlaybackState state = PlaybackState.idle,
  PlaybackController? controller,
}) {
  final fakeController = controller ?? _FakePlaybackController();
  return ProviderScope(
    overrides: [
      playbackStateProvider.overrideWith((ref) => Stream.value(state)),
      playbackControllerProvider.overrideWith((ref) => fakeController),
      favoritesRepositoryProvider.overrideWithValue(_FakeFavoritesRepository()),
    ],
    child: localizedApp(const Scaffold(body: MiniPlayerBar())),
  );
}

void main() {
  testWidgets('renders nothing when currentTrack is null', (tester) async {
    await tester.pumpWidget(_app());
    await tester.pumpAndSettle();

    expect(find.byType(SizedBox), findsOneWidget);
    expect(find.byType(InkWell), findsNothing);
  });

  testWidgets('renders title and artist when a track is loaded', (
    tester,
  ) async {
    final state = PlaybackState(
      isPlaying: false,
      isBuffering: false,
      isCompleted: false,
      position: Duration.zero,
      currentTrack: _track('Test Song', artist: 'Test Artist'),
    );

    await tester.pumpWidget(_app(state: state));
    await tester.pumpAndSettle();

    expect(find.text('Test Song'), findsOneWidget);
    expect(find.text('Test Artist'), findsOneWidget);
  });

  testWidgets('falls back to 未知艺术家 when artist is null', (tester) async {
    final state = PlaybackState(
      isPlaying: false,
      isBuffering: false,
      isCompleted: false,
      position: Duration.zero,
      currentTrack: _track('No Artist Song'),
    );

    await tester.pumpWidget(_app(state: state));
    await tester.pumpAndSettle();

    expect(find.text('No Artist Song'), findsOneWidget);
    expect(find.text('未知艺术家'), findsOneWidget);
  });

  testWidgets('play/pause button calls togglePlayPause', (tester) async {
    final fakeController = _FakePlaybackController();
    final state = PlaybackState(
      isPlaying: false,
      isBuffering: false,
      isCompleted: false,
      position: Duration.zero,
      currentTrack: _track('Play Test'),
    );

    await tester.pumpWidget(_app(state: state, controller: fakeController));
    await tester.pumpAndSettle();

    // Play button visible when not playing.
    expect(find.byIcon(Icons.play_arrow), findsOneWidget);
    expect(find.byIcon(Icons.pause), findsNothing);

    await tester.tap(find.byIcon(Icons.play_arrow));
    await tester.pumpAndSettle();

    expect(fakeController.togglePlayPauseCalls, 1);
  });

  testWidgets('play button shows pause icon when playing', (tester) async {
    final state = PlaybackState(
      isPlaying: true,
      isBuffering: false,
      isCompleted: false,
      position: Duration.zero,
      currentTrack: _track('Playing Song'),
    );

    await tester.pumpWidget(_app(state: state));
    await tester.pumpAndSettle();

    expect(find.byIcon(Icons.pause), findsOneWidget);
    expect(find.byIcon(Icons.play_arrow), findsNothing);
  });

  testWidgets('next button is disabled when hasNext is false', (tester) async {
    final fakeController = _FakePlaybackController();
    final state = PlaybackState(
      isPlaying: true,
      isBuffering: false,
      isCompleted: false,
      position: Duration.zero,
      currentTrack: _track('Next Test'),
      hasNext: false,
    );

    await tester.pumpWidget(_app(state: state, controller: fakeController));
    await tester.pumpAndSettle();

    // The next IconButton should have onPressed == null (disabled).
    final nextIcon = tester.widget<Icon>(find.byIcon(Icons.skip_next));
    expect(nextIcon, isNotNull);

    // The IconButton wrapping it should be disabled — verify by tapping and
    // checking no next() call was made.
    await tester.tap(find.byIcon(Icons.skip_next));
    await tester.pumpAndSettle();
    expect(fakeController.nextCalls, 0);
  });

  testWidgets('next button is enabled when hasNext is true', (tester) async {
    final fakeController = _FakePlaybackController();
    final state = PlaybackState(
      isPlaying: true,
      isBuffering: false,
      isCompleted: false,
      position: Duration.zero,
      currentTrack: _track('Next Test'),
      hasNext: true,
    );

    await tester.pumpWidget(_app(state: state, controller: fakeController));
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.skip_next));
    await tester.pumpAndSettle();

    expect(fakeController.nextCalls, 1);
  });

  testWidgets('tapping the bar opens the full-screen player', (tester) async {
    final state = PlaybackState(
      isPlaying: false,
      isBuffering: false,
      isCompleted: false,
      position: Duration.zero,
      currentTrack: _track('Player Test'),
    );

    await tester.pumpWidget(_app(state: state));
    await tester.pumpAndSettle();

    // Tap the bar area (not the buttons).
    await tester.tap(find.byKey(MiniPlayerBar.barKey));
    await tester.pumpAndSettle();

    // The full-screen player route is on top.
    expect(find.byType(PlayerScreen), findsOneWidget);
  });

  testWidgets('does not overflow at 400 px width', (tester) async {
    tester.view.physicalSize = const Size(400, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final state = PlaybackState(
      isPlaying: false,
      isBuffering: false,
      isCompleted: false,
      position: Duration.zero,
      currentTrack: _track('一个非常非常长的歌曲标题用来验证在窄屏下不会溢出', artist: '一个同样非常长的艺术家名称'),
    );

    await tester.pumpWidget(_app(state: state));
    await tester.pumpAndSettle();

    expect(find.text('一个非常非常长的歌曲标题用来验证在窄屏下不会溢出'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
