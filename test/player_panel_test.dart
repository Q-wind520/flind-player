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
import 'dart:io';

import 'package:flutter/material.dart' hide RepeatMode;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:package_info_plus/package_info_plus.dart';

import 'package:flind_player/core/models/playback_queue.dart';
import 'package:flind_player/core/models/playback_state.dart';
import 'package:flind_player/core/models/repeat_mode.dart';
import 'package:flind_player/core/models/track.dart';
import 'package:flind_player/core/models/track_sort.dart';
import 'package:flind_player/core/repositories/settings_repository.dart';
import 'package:flind_player/core/services/playback_controller.dart';
import 'package:flind_player/core/sources/source_track_id.dart';
import 'package:flind_player/data/cache/audio_cache_store.dart';
import 'package:flind_player/data/cache/download_manager.dart';
import 'package:flind_player/data/providers/cache_providers.dart';
import 'package:flind_player/data/providers/library_providers.dart';
import 'package:flind_player/data/providers/playback_providers.dart';
import 'package:flind_player/data/services/library_sync_service.dart';
import 'package:flind_player/features/home/home_shell.dart';
import 'package:flind_player/features/library/widgets/cache_action_button.dart';
import 'package:flind_player/features/player/mini_player_bar.dart';
import 'package:flind_player/features/player/player_sheet.dart';
import 'package:flind_player/features/search/search_providers.dart';
import 'package:flind_player/features/settings/settings_providers.dart';

// ---------------------------------------------------------------------------
// Fakes
// ---------------------------------------------------------------------------

class _FakeSettingsRepository implements SettingsRepository {
  _FakeSettingsRepository(this.current);

  CacheSettings current;

  @override
  Future<CacheSettings> cacheSettings() async => current;

  @override
  Future<void> updateCacheSettings(CacheSettings settings) async {
    current = settings;
  }

  @override
  Stream<CacheSettings> watchCacheSettings() async* {
    yield current;
  }

  @override
  Future<TrackSort> librarySort() async => TrackSort.title;

  @override
  Future<void> setLibrarySort(TrackSort sort) async {}

  Future<void> dispose() async {}
}

class _FakeCacheStore implements AudioCacheStore {
  @override
  Future<void> clear() async {}

  @override
  Future<void> remove(int id) async {}

  @override
  Future<List<CachedAudio>> entries() async => const <CachedAudio>[];

  @override
  Future<int> totalBytes() async => 0;

  @override
  Future<CachedAudio?> lookup(String source, String sourceTrackId) async =>
      null;

  @override
  Future<void> touch(int id) async {}

  @override
  Future<void> setPinned(int id, bool pinned) async {}

  @override
  Future<CachedAudio> insert({
    required String source,
    required String sourceTrackId,
    required String filePath,
    required int bytes,
    required String qualityId,
    required bool pinned,
  }) async => throw UnimplementedError();

  @override
  Future<EvictionResult> ensureSpace(int incomingBytes) async =>
      const EvictionResult(evictedCount: 0, freedBytes: 0, hasSpace: true);

  @override
  Future<IntegrityReport> checkIntegrity() async =>
      const IntegrityReport(rowsRemoved: 0, orphansRemoved: 0);

  @override
  File fileFor({
    required String source,
    required String sourceTrackId,
    required String extension,
  }) => throw UnimplementedError();
}

class _FakeLibrarySyncService implements LibrarySyncService {
  @override
  LibrarySyncState get current => LibrarySyncState.idle;

  @override
  bool get isRunning => false;

  @override
  Stream<LibrarySyncState> get state =>
      Stream<LibrarySyncState>.value(LibrarySyncState.idle);

  @override
  Future<void> sync() async {}

  @override
  Future<void> dispose() async {}
}

/// A minimal fake [PlaybackController] that records calls.
class _FakePlaybackController implements PlaybackController {
  int togglePlayPauseCalls = 0;
  int pauseCalls = 0;
  int nextCalls = 0;
  final List<Duration> seeks = <Duration>[];

  @override
  Future<void> togglePlayPause() async {
    togglePlayPauseCalls++;
  }

  @override
  Future<void> next() async {
    nextCalls++;
  }

  @override
  Future<void> pause() async {
    pauseCalls++;
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
  Future<void> play() async {}
  @override
  Future<void> previous() async {}
  @override
  Future<void> seek(Duration position) async {
    seeks.add(position);
  }
  @override
  Future<void> setRepeatMode(RepeatMode mode) async {}
  @override
  Future<void> setShuffle(bool enabled) async {}
  @override
  Future<void> dispose() async {}
}

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

Track _track(String title, {String? artist}) {
  return Track(
    source: 'local',
    sourceTrackId: const LocalTrackId('/music/test.mp3'),
    uri: 'local:/music/test.mp3',
    title: title,
    artist: artist,
  );
}

PlaybackState _playingState({Track? track}) {
  return PlaybackState(
    isPlaying: true,
    isBuffering: false,
    isCompleted: false,
    position: const Duration(seconds: 30),
    duration: const Duration(minutes: 3),
    currentTrack: track ?? _track('Panel Test Song', artist: 'Panel Artist'),
  );
}

Widget _app({PlaybackState? state, PlaybackController? controller}) {
  final settings = _FakeSettingsRepository(CacheSettings.defaults);
  final store = _FakeCacheStore();
  final fakeController = controller ?? _FakePlaybackController();
  final playbackState = state ?? PlaybackState.idle;

  return ProviderScope(
    overrides: [
      playbackStateProvider.overrideWith((ref) => Stream.value(playbackState)),
      playbackControllerProvider.overrideWith((ref) => fakeController),
      libraryTracksProvider.overrideWith((ref) => Stream.value(<Track>[])),
      librarySyncStateProvider.overrideWith(
        (ref) => Stream.value(LibrarySyncState.idle),
      ),
      downloadProgressProvider.overrideWith(
        (ref) => const Stream<DownloadProgress>.empty(),
      ),
      audioCacheEntryProvider.overrideWith((ref, track) async => null),
      biliSearchResultsProvider.overrideWith((ref, query) async => <Track>[]),
      settingsRepositoryProvider.overrideWith((ref) => settings),
      audioCacheStoreProvider.overrideWith((ref) => store),
      audioCacheUsageProvider.overrideWith((ref) async => 0),
      audioCacheEntryCountProvider.overrideWith((ref) async => 0),
      scanRootsProvider.overrideWith((ref) async => <String>[]),
      librarySyncServiceProvider.overrideWith(
        (ref) => _FakeLibrarySyncService(),
      ),
      packageInfoProvider.overrideWith(
        (ref) async => PackageInfo(
          appName: 'Flind Player',
          packageName: 'flind_player',
          version: '0.0.0',
          buildNumber: '0',
        ),
      ),
    ],
    child: const MaterialApp(home: HomeShell()),
  );
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  setUpAll(() {
    TestWidgetsFlutterBinding.ensureInitialized();
  });

  testWidgets('at 400 px: tapping mini bar opens sheet, no docked panel', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(400, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(_app(state: _playingState()));
    await tester.pumpAndSettle();

    // The panel should not exist at 400 px.
    expect(find.byKey(HomeShell.playerPanelKey), findsNothing);

    // Tap the mini bar — should open the modal sheet.
    await tester.tap(find.byKey(MiniPlayerBar.barKey));
    await tester.pumpAndSettle();

    // Sheet drag handle is visible.
    expect(find.byKey(PlayerSheet.dragHandleKey), findsOneWidget);
    // Panel still absent.
    expect(find.byKey(HomeShell.playerPanelKey), findsNothing);
  });

  testWidgets('at 1200 px: tapping mini bar shows panel, no sheet', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1200, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(_app(state: _playingState()));
    await tester.pumpAndSettle();

    // Tap the mini bar — should open the docked panel, not a sheet.
    await tester.tap(find.byKey(MiniPlayerBar.barKey));
    await tester.pumpAndSettle();

    expect(find.byKey(HomeShell.playerPanelKey), findsOneWidget);
    expect(find.byKey(PlayerSheet.dragHandleKey), findsNothing);
  });

  testWidgets('at 1200 px: X button closes the panel', (tester) async {
    tester.view.physicalSize = const Size(1200, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(_app(state: _playingState()));
    await tester.pumpAndSettle();

    // Open panel.
    await tester.tap(find.byKey(MiniPlayerBar.barKey));
    await tester.pumpAndSettle();
    expect(find.byKey(HomeShell.playerPanelKey), findsOneWidget);

    // Close via X.
    await tester.tap(find.byKey(HomeShell.playerPanelCloseKey));
    await tester.pumpAndSettle();

    expect(find.byKey(HomeShell.playerPanelKey), findsNothing);
  });

  testWidgets('at 1200 px: opening the panel hides the mini bar', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1200, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(_app(state: _playingState()));
    await tester.pumpAndSettle();

    expect(find.byKey(MiniPlayerBar.barKey), findsOneWidget);

    // The panel carries the same transport controls as the mini bar, so the
    // bar is hidden while the panel is open to avoid duplicate controls.
    await tester.tap(find.byKey(MiniPlayerBar.barKey));
    await tester.pumpAndSettle();
    expect(find.byKey(HomeShell.playerPanelKey), findsOneWidget);
    expect(find.byKey(MiniPlayerBar.barKey), findsNothing);

    // Closing restores the mini bar.
    await tester.tap(find.byKey(HomeShell.playerPanelCloseKey));
    await tester.pumpAndSettle();
    expect(find.byKey(HomeShell.playerPanelKey), findsNothing);
    expect(find.byKey(MiniPlayerBar.barKey), findsOneWidget);
  });

  testWidgets('dragging the progress slider tracks the finger and seeks', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1200, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final fakeController = _FakePlaybackController();
    await tester.pumpWidget(
      _app(state: _playingState(), controller: fakeController),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(MiniPlayerBar.barKey));
    await tester.pumpAndSettle();

    // _playingState is 0:30 of 3:00.
    expect(find.text('0:30'), findsOneWidget);

    final gesture = await tester.startGesture(
      tester.getCenter(find.byType(Slider)),
    );
    await gesture.moveBy(const Offset(40, 0));
    await tester.pump();

    // Mid-drag the thumb and the elapsed label follow the finger, and nothing
    // is committed until the gesture ends.
    expect(find.text('0:30'), findsNothing);
    expect(fakeController.seeks, isEmpty);

    await gesture.up();
    await tester.pumpAndSettle();

    // The drag started at the centre, so the committed seek is past 1:30.
    expect(fakeController.seeks, hasLength(1));
    expect(fakeController.seeks.single.inSeconds, greaterThan(90));
  });

  testWidgets('resize from 1200 to 400 with panel open does not throw', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1200, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(_app(state: _playingState()));
    await tester.pumpAndSettle();

    // Open panel at 1200 px.
    await tester.tap(find.byKey(MiniPlayerBar.barKey));
    await tester.pumpAndSettle();
    expect(find.byKey(HomeShell.playerPanelKey), findsOneWidget);

    // Resize to 400 px — panel should disappear, no crash.
    tester.view.physicalSize = const Size(400, 800);
    await tester.pumpAndSettle();

    expect(find.byKey(HomeShell.playerPanelKey), findsNothing);
    // App still renders navigation.
    expect(find.text('搜索'), findsWidgets);
    expect(tester.takeException(), isNull);
  });

  testWidgets('opening/closing panel does not pause playback', (tester) async {
    tester.view.physicalSize = const Size(1200, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final fakeController = _FakePlaybackController();
    await tester.pumpWidget(
      _app(state: _playingState(), controller: fakeController),
    );
    await tester.pumpAndSettle();

    // Open panel.
    await tester.tap(find.byKey(MiniPlayerBar.barKey));
    await tester.pumpAndSettle();

    // Close panel via X.
    await tester.tap(find.byKey(HomeShell.playerPanelCloseKey));
    await tester.pumpAndSettle();

    // Play/pause must not have been called.
    expect(fakeController.pauseCalls, 0);
    expect(fakeController.togglePlayPauseCalls, 0);
  });

  testWidgets('panel shows player content (正在播放 title)', (tester) async {
    tester.view.physicalSize = const Size(1200, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(_app(state: _playingState()));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(MiniPlayerBar.barKey));
    await tester.pumpAndSettle();

    // The panel header title.
    expect(find.text('正在播放'), findsOneWidget);
    // The track from PlayerView (appears both in mini bar and panel).
    expect(find.text('Panel Test Song'), findsAtLeastNWidgets(1));
  });
}
