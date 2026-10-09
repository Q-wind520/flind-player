# Gestures & Motion (B) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add three follow-the-finger gestures: mini-player swipe-to-skip (carousel), portrait swipe into/out of lyrics, and swipe-down to dismiss the player (drawer).

**Architecture:** Each gesture is a small self-contained widget owning an `AnimationController` in a bounded value range, driven by `GestureDetector` drag callbacks, settling with `AppMotion` curves and interruptible mid-flight. A derived `previousTrackProvider`/`nextTrackProvider` supplies the carousel neighbors. The player route becomes non-opaque so the dismiss drawer can dim the app behind it.

**Tech Stack:** Flutter (Material 3), Riverpod, `flutter_test`.

**Spec:** `docs/spec-gestures-motion-2026-10-09.md`

## Global Constraints

- Reuse `AppMotion` (`fast` 150 / `standard` 250 / `emphasized` 400 ms; `standardCurve` = easeInOutCubic, `emphasizedCurve` = easeOutCubic).
- Commit thresholds: drag distance ≥ 40% of the axis extent, or |velocity| ≥ 700 px/s; otherwise settle back.
- Gesture regions: mini bar carousel = the label area (cover + title/artist), **not** the transport buttons; portrait lyrics swipe = cover area + `LyricsPreview`, **not** the progress slider; dismiss = the **header only**.
- Directions: mini bar left-swipe = next, right-swipe = previous; portrait left-swipe = enter lyrics, right-swipe = exit; dismiss = drag down.
- No new dependencies; no data-layer or information-architecture changes.
- Keep `flutter analyze` clean and the whole suite green. Baseline before this plan: **884 passed**.
- Commit locally on `master` only; **do not push**.

## Review Focus

The spec says what the software must do but not every input; these failure modes are the most likely to bite a user, each with a test in the owning task.

1. **A swipe that does not cross the threshold** must settle back and change nothing (no accidental skip / lyrics change / dismiss). → Tasks 2, 3, 4.
2. **The queue has no neighbor** (single track, or start/end with repeat off) must not skip and must not crash. → Tasks 1, 2.
3. **Existing gestures must still work**: the progress slider seeks, the lyrics pane still scrolls, the cover long-press/right-click still opens the viewer, a tap still opens the player. → Tasks 2, 3, 4.
4. **A gesture can be interrupted mid-animation** by a new drag without the widget getting stuck mid-value. → Tasks 2, 3, 4.
5. **No duplicate Hero tags**: the carousel renders neighbors, which must not each carry a `CoverHero` for the same uri. → Task 2.
6. **Nothing playing** must keep the mini bar hidden and the header gestures inert. → Task 4 (header exists even with no track).

---

### Task 1: Adjacent-track providers

**Files:**
- Modify: `lib/data/providers/playback_providers.dart`
- Test: `test/adjacent_tracks_test.dart` (create)

**Interfaces:**
- Consumes: `playbackStateProvider`, `playbackControllerProvider`, `PlaybackQueue.previousIndex/nextIndex`.
- Produces: `previousTrackProvider` / `nextTrackProvider` (`Provider<Track?>`) — used by Task 2.

- [ ] **Step 1: Write the failing test**

Create `test/adjacent_tracks_test.dart`:

```dart
// Flind Player - cross-platform music player
// Copyright (C) 2026 top.qwind.app
//
// This program is free software: you can redistribute it and/or modify
// it under the terms of the GNU General Public License as published by
// the Free Software Foundation, version 3 of the License.

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:flind_player/core/models/playback_queue.dart';
import 'package:flind_player/core/models/playback_state.dart';
import 'package:flind_player/core/models/repeat_mode.dart';
import 'package:flind_player/core/models/track.dart';
import 'package:flind_player/core/services/playback_controller.dart';
import 'package:flind_player/core/sources/source_track_id.dart';
import 'package:flind_player/data/providers/playback_providers.dart';

import 'support/fake_playback_controller.dart';

Track _track(int i) => Track(
  source: 'local',
  sourceTrackId: LocalTrackId('/music/$i.mp3'),
  uri: 'local:/music/$i.mp3',
  title: 'Song $i',
);

ProviderContainer _container({
  required PlaybackQueue queue,
  required RepeatMode repeatMode,
}) {
  return ProviderContainer(
    overrides: [
      playbackStateProvider.overrideWith(
        (ref) => Stream.value(
          PlaybackState(
            isPlaying: true,
            isBuffering: false,
            isCompleted: false,
            position: Duration.zero,
            repeatMode: repeatMode,
            currentTrack: queue.currentTrack,
          ),
        ),
      ),
      playbackControllerProvider.overrideWithValue(
        FakePlaybackController(queue: queue),
      ),
    ],
  );
}

/// Waits until the overridden state stream has emitted once.
Future<ProviderContainer> _ready(ProviderContainer container) async {
  await container.read(playbackStateProvider.future);
  return container;
}

PlaybackQueue _queue(int index, int length) => PlaybackQueue(
  tracks: [for (var i = 0; i < length; i++) _track(i)],
  currentIndex: index,
  originalOrder: [for (var i = 0; i < length; i++) i],
);

void main() {
  test('returns the neighbours in the middle of the queue', () async {
    final container = await _ready(
      _container(queue: _queue(1, 3), repeatMode: RepeatMode.off),
    );
    addTearDown(container.dispose);
    expect(container.read(previousTrackProvider)?.title, 'Song 0');
    expect(container.read(nextTrackProvider)?.title, 'Song 2');
  });

  test('returns null past the ends with repeat off', () async {
    final last = await _ready(
      _container(queue: _queue(2, 3), repeatMode: RepeatMode.off),
    );
    addTearDown(last.dispose);
    expect(last.read(nextTrackProvider), isNull);

    final first = await _ready(
      _container(queue: _queue(0, 3), repeatMode: RepeatMode.off),
    );
    addTearDown(first.dispose);
    expect(first.read(previousTrackProvider), isNull);
  });

  test('wraps past the ends with repeat all', () async {
    final last = await _ready(
      _container(queue: _queue(2, 3), repeatMode: RepeatMode.all),
    );
    addTearDown(last.dispose);
    expect(last.read(nextTrackProvider)?.title, 'Song 0');
  });

  test('returns null when nothing is playing', () async {
    final container = await _ready(
      ProviderContainer(
        overrides: [
          playbackStateProvider.overrideWith(
            (ref) => Stream.value(PlaybackState.idle),
          ),
          playbackControllerProvider.overrideWithValue(
            FakePlaybackController(queue: PlaybackQueue.empty),
          ),
        ],
      ),
    );
    addTearDown(container.dispose);
    expect(container.read(previousTrackProvider), isNull);
    expect(container.read(nextTrackProvider), isNull);
  });
}
```

- [ ] **Step 2: Add the shared fake controller**

Create `test/support/fake_playback_controller.dart`:

```dart
// Flind Player - cross-platform music player
// Copyright (C) 2026 top.qwind.app
//
// This program is free software: you can redistribute it and/or modify
// it under the terms of the GNU General Public License as published by
// the Free Software Foundation, version 3 of the License.

import 'package:flind_player/core/models/playback_queue.dart';
import 'package:flind_player/core/models/playback_state.dart';
import 'package:flind_player/core/models/repeat_mode.dart';
import 'package:flind_player/core/services/playback_controller.dart';

/// A [PlaybackController] that records transport calls and returns a fixed
/// [queue]; every other member is inert.
class FakePlaybackController implements PlaybackController {
  FakePlaybackController({this.queue = PlaybackQueue.empty});

  @override
  PlaybackQueue queue;

  int nextCalls = 0;
  int previousCalls = 0;
  int toggleCalls = 0;

  @override
  Stream<PlaybackState> get state => const Stream.empty();

  @override
  PlaybackState get currentState => PlaybackState.idle;

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
  Future<void> togglePlayPause() async {
    toggleCalls++;
  }

  @override
  Future<void> next() async {
    nextCalls++;
  }

  @override
  Future<void> previous() async {
    previousCalls++;
  }

  @override
  Future<void> seek(Duration position) async {}

  @override
  Future<void> setRepeatMode(RepeatMode mode) async {}

  @override
  Future<void> setShuffle(bool enabled) async {}

  @override
  Future<void> setSpeed(double speed) async {}

  @override
  Future<void> setVolume(double volume) async {}

  @override
  Future<void> dispose() async {}
}
```

- [ ] **Step 3: Run the test to verify it fails**

Run: `flutter test test/adjacent_tracks_test.dart`
Expected: FAIL — `previousTrackProvider`/`nextTrackProvider` are undefined.

- [ ] **Step 4: Implement the providers**

In `lib/data/providers/playback_providers.dart`, add the imports:

```dart
import 'package:flind_player/core/models/track.dart';
```

Add after `playbackStateProvider`:

```dart
/// The track that would play on "previous" from the current queue, or `null`
/// when there is none (queue start with repeat off, or nothing playing).
final previousTrackProvider = Provider<Track?>((ref) {
  final state = ref.watch(playbackStateProvider).value;
  if (state == null || state.currentTrack == null) return null;
  final queue = ref.watch(playbackControllerProvider).queue;
  final index = queue.previousIndex(repeatMode: state.repeatMode);
  if (index == null || index < 0 || index >= queue.tracks.length) return null;
  return queue.tracks[index];
});

/// The track that would play on "next" from the current queue, or `null`.
final nextTrackProvider = Provider<Track?>((ref) {
  final state = ref.watch(playbackStateProvider).value;
  if (state == null || state.currentTrack == null) return null;
  final queue = ref.watch(playbackControllerProvider).queue;
  final index = queue.nextIndex(repeatMode: state.repeatMode);
  if (index == null || index < 0 || index >= queue.tracks.length) return null;
  return queue.tracks[index];
});
```

- [ ] **Step 5: Run the test and the analyzer**

Run: `flutter test test/adjacent_tracks_test.dart && flutter analyze`
Expected: PASS (4 tests), no analyzer issues.

- [ ] **Step 6: Commit**

```bash
git add lib/data/providers/playback_providers.dart test/adjacent_tracks_test.dart test/support/fake_playback_controller.dart
git commit -m "feat: expose adjacent queue tracks for swipe navigation"
```

---

### Task 2: Mini-player swipe-to-skip carousel

**Files:**
- Modify: `lib/features/player/mini_player_bar.dart`
- Test: `test/mini_player_swipe_test.dart` (create)

**Interfaces:**
- Consumes: `previousTrackProvider`, `nextTrackProvider` (Task 1), `FakePlaybackController` (Task 1), `AppMotion`.
- Produces: nothing new (behavior only).

- [ ] **Step 1: Write the failing test**

Create `test/mini_player_swipe_test.dart`:

```dart
// Flind Player - cross-platform music player
// Copyright (C) 2026 top.qwind.app
//
// This program is free software: you can redistribute it and/or modify
// it under the terms of the GNU General Public License as published by
// the Free Software Foundation, version 3 of the License.

import 'package:flutter/material.dart' hide RepeatMode;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:flind_player/core/models/playback_queue.dart';
import 'package:flind_player/core/models/playback_state.dart';
import 'package:flind_player/core/models/repeat_mode.dart';
import 'package:flind_player/core/models/track.dart';
import 'package:flind_player/core/repositories/favorites_repository.dart';
import 'package:flind_player/core/sources/source_track_id.dart';
import 'package:flind_player/data/providers/persistence_providers.dart';
import 'package:flind_player/data/providers/playback_providers.dart';
import 'package:flind_player/features/player/mini_player_bar.dart';
import 'package:flind_player/features/player/player_screen.dart';

import 'support/fake_playback_controller.dart';
import 'support/l10n.dart';

Track _track(int i) => Track(
  source: 'local',
  sourceTrackId: LocalTrackId('/music/$i.mp3'),
  uri: 'local:/music/$i.mp3',
  title: 'Song $i',
);

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

PlaybackQueue _queue(int index, int length) => PlaybackQueue(
  tracks: [for (var i = 0; i < length; i++) _track(i)],
  currentIndex: index,
  originalOrder: [for (var i = 0; i < length; i++) i],
);

Widget _app(FakePlaybackController controller, {int index = 1, int length = 3}) {
  final queue = _queue(index, length);
  controller.queue = queue;
  return ProviderScope(
    overrides: [
      playbackStateProvider.overrideWith(
        (ref) => Stream.value(
          PlaybackState(
            isPlaying: true,
            isBuffering: false,
            isCompleted: false,
            position: Duration.zero,
            repeatMode: RepeatMode.off,
            currentTrack: queue.currentTrack,
          ),
        ),
      ),
      playbackControllerProvider.overrideWithValue(controller),
      favoritesRepositoryProvider.overrideWithValue(_FakeFavoritesRepository()),
    ],
    child: localizedApp(const Scaffold(body: MiniPlayerBar())),
  );
}

void main() {
  testWidgets('left-swipe past the threshold skips to the next track', (
    tester,
  ) async {
    final controller = FakePlaybackController();
    await tester.pumpWidget(_app(controller));
    await tester.pumpAndSettle();

    await tester.drag(find.byKey(MiniPlayerBar.barKey), const Offset(-400, 0));
    await tester.pumpAndSettle();

    expect(controller.nextCalls, 1);
    expect(controller.previousCalls, 0);
  });

  testWidgets('right-swipe past the threshold goes to the previous track', (
    tester,
  ) async {
    final controller = FakePlaybackController();
    await tester.pumpWidget(_app(controller));
    await tester.pumpAndSettle();

    await tester.drag(find.byKey(MiniPlayerBar.barKey), const Offset(400, 0));
    await tester.pumpAndSettle();

    expect(controller.previousCalls, 1);
    expect(controller.nextCalls, 0);
  });

  testWidgets('a short swipe settles back without skipping', (tester) async {
    final controller = FakePlaybackController();
    await tester.pumpWidget(_app(controller));
    await tester.pumpAndSettle();

    await tester.drag(find.byKey(MiniPlayerBar.barKey), const Offset(-30, 0));
    await tester.pumpAndSettle();

    expect(controller.nextCalls, 0);
    expect(controller.previousCalls, 0);
  });

  testWidgets('a tap still opens the player without skipping', (tester) async {
    final controller = FakePlaybackController();
    await tester.pumpWidget(_app(controller));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(MiniPlayerBar.barKey));
    await tester.pumpAndSettle();

    expect(find.byType(PlayerScreen), findsOneWidget);
    expect(controller.nextCalls, 0);
    expect(controller.previousCalls, 0);
  });

  testWidgets('does not skip when there is no neighbour', (tester) async {
    final controller = FakePlaybackController();
    // A single-track queue has no neighbours.
    await tester.pumpWidget(_app(controller, index: 0, length: 1));
    await tester.pumpAndSettle();

    await tester.drag(find.byKey(MiniPlayerBar.barKey), const Offset(-400, 0));
    await tester.pumpAndSettle();

    expect(controller.nextCalls, 0);
  });
}
```

- [ ] **Step 2: Run the test to verify it fails**

Run: `flutter test test/mini_player_swipe_test.dart`
Expected: FAIL — the bar has no horizontal drag handling (nextCalls stays 0 for the swipe).

- [ ] **Step 3: Implement the carousel**

In `lib/features/player/mini_player_bar.dart`, add the import:

```dart
import 'package:flind_player/data/providers/playback_providers.dart';
```

Replace the `InkWell(...)` inside the `Column` with a gesture-driven strip plus fixed buttons:

```dart
            Row(
              children: [
                Expanded(child: _MiniLabelStrip(current: track)),
                // Play/pause.
                IconButton(
                  onPressed: () =>
                      ref.read(playbackControllerProvider).togglePlayPause(),
                  icon: Icon(
                    state.isPlaying ? Icons.pause : Icons.play_arrow,
                  ),
                ),
                // Next.
                IconButton(
                  onPressed: state.hasNext
                      ? () => ref.read(playbackControllerProvider).next()
                      : null,
                  icon: const Icon(Icons.skip_next),
                ),
              ],
            ),
```

Add the strip and its label below `MiniPlayerBar` (before `_MiniCover`):

```dart
/// The swipeable cover + title/artist strip: `[previous][current][next]`,
/// following the finger, committing to the neighbour past the threshold.
class _MiniLabelStrip extends ConsumerStatefulWidget {
  const _MiniLabelStrip({required this.current});

  final Track current;

  @override
  ConsumerState<_MiniLabelStrip> createState() => _MiniLabelStripState();
}

class _MiniLabelStripState extends ConsumerState<_MiniLabelStrip>
    with SingleTickerProviderStateMixin {
  /// -1 = next shown, 0 = resting on current, +1 = previous shown.
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: AppMotion.standard,
    lowerBound: -1,
    upperBound: 1,
    value: 0,
  );

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  Future<void> _commit(int direction) async {
    await _c.animateTo(
      direction.toDouble(),
      curve: AppMotion.standardCurve,
    );
    final controller = ref.read(playbackControllerProvider);
    if (direction > 0) {
      await controller.previous();
    } else {
      await controller.next();
    }
    if (mounted) _c.value = 0;
  }

  @override
  Widget build(BuildContext context) {
    // Re-centre when the loaded track actually changes.
    ref.listen(playbackStateProvider, (previous, next) {
      if (previous?.value?.currentTrack?.uri != next.value?.currentTrack?.uri &&
          !_c.isAnimating) {
        _c.value = 0;
      }
    });
    final previousTrack = ref.watch(previousTrackProvider);
    final nextTrack = ref.watch(nextTrackProvider);

    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        return GestureDetector(
          key: MiniPlayerBar.barKey,
          behavior: HitTestBehavior.opaque,
          onTap: () => Navigator.of(context).push(playerRoute(context)),
          onHorizontalDragUpdate: (details) {
            _c.value = (_c.value + details.delta.dx / width).clamp(-1.0, 1.0);
          },
          onHorizontalDragEnd: (details) {
            final velocity = details.velocity.pixelsPerSecond.dx;
            if ((_c.value <= -0.4 || velocity < -700) && nextTrack != null) {
              _commit(-1);
            } else if ((_c.value >= 0.4 || velocity > 700) &&
                previousTrack != null) {
              _commit(1);
            } else {
              _c.animateTo(0, curve: AppMotion.standardCurve);
            }
          },
          child: ClipRect(
            child: AnimatedBuilder(
              animation: _c,
              builder: (context, child) {
                final dx = -_c.value * width;
                return Stack(
                  clipBehavior: Clip.hardEdge,
                  children: [
                    _pane(previousTrack, dx - width, width, hero: false),
                    _pane(widget.current, dx, width, hero: true),
                    _pane(nextTrack, dx + width, width, hero: false),
                  ],
                );
              },
            ),
          ),
        );
      },
    );
  }

  Widget _pane(Track? track, double left, double width, {required bool hero}) {
    final value = track;
    if (value == null) return const SizedBox.shrink();
    return Positioned(
      left: left,
      width: width,
      top: 0,
      bottom: 0,
      child: _MiniLabel(track: value, hero: hero),
    );
  }
}

/// Cover + title/artist for one carousel pane. Only the centred pane carries a
/// [CoverHero] (neighbours must not share the tag).
class _MiniLabel extends StatelessWidget {
  const _MiniLabel({required this.track, required this.hero});

  final Track track;
  final bool hero;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final l10n = AppLocalizations.of(context);
    final cover = _MiniCover(track: track);
    return Row(
      children: [
        if (hero)
          CoverHero(
            uri: track.uri,
            coverPath: track.coverPath,
            coverUrl: track.coverUrl,
            child: cover,
          )
        else
          cover,
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                track.title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              Text(
                track.artist ?? l10n.unknownArtist,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(
                  context,
                ).textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
```

Then change `_MiniCover` to a plain cover (drop its internal `CoverHero`, which is now applied by `_MiniLabel`):

```dart
    return ClipRRect(
      borderRadius: BorderRadius.circular(AppRadius.md),
      child: Container(
        width: _size,
        height: _size,
        color: scheme.surfaceContainerHighest,
        child: hasCover
            ? CoverImage(
                path: coverPath,
                url: coverUrl,
                size: _size,
                errorBuilder: (context, error, stackTrace) =>
                    _placeholder(scheme),
              )
            : _placeholder(scheme),
      ),
    );
```

- [ ] **Step 4: Run the tests to verify they pass**

Run: `flutter test test/mini_player_swipe_test.dart test/mini_player_bar_test.dart test/home_shell_test.dart`
Expected: PASS — including the existing mini-bar and shell tests (the `CoverHero` tag, cover radius, tap-to-open and 400px overflow all still hold).

- [ ] **Step 5: Run the analyzer**

Run: `flutter analyze`
Expected: no issues.

- [ ] **Step 6: Commit**

```bash
git add lib/features/player/mini_player_bar.dart test/mini_player_swipe_test.dart
git commit -m "feat: swipe the mini player to skip tracks"
```

---

### Task 3: Portrait swipe into and out of lyrics

**Files:**
- Modify: `lib/features/player/player_screen.dart` (`_PortraitBody`)
- Test: `test/portrait_lyrics_swipe_test.dart` (create)

**Interfaces:**
- Consumes: `AppMotion`, `LyricsView`, `_PortraitNormal`.
- Produces: nothing new (behavior only).

- [ ] **Step 1: Write the failing test**

Create `test/portrait_lyrics_swipe_test.dart`:

```dart
// Flind Player - cross-platform music player
// Copyright (C) 2026 top.qwind.app
//
// This program is free software: you can redistribute it and/or modify
// it under the terms of the GNU General Public License as published by
// the Free Software Foundation, version 3 of the License.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:flind_player/core/models/playback_state.dart';
import 'package:flind_player/core/models/track.dart';
import 'package:flind_player/core/repositories/favorites_repository.dart';
import 'package:flind_player/core/sources/source_track_id.dart';
import 'package:flind_player/data/providers/persistence_providers.dart';
import 'package:flind_player/data/providers/playback_providers.dart';
import 'package:flind_player/features/player/lyrics_view.dart';
import 'package:flind_player/features/player/player_screen.dart';

import 'support/l10n.dart';

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

Track _track() => Track(
  source: 'local',
  sourceTrackId: const LocalTrackId('/music/a.mp3'),
  uri: 'local:/music/a.mp3',
  title: 'Now Playing',
);

Widget _app() => ProviderScope(
  overrides: [
    playbackStateProvider.overrideWith(
      (ref) => Stream.value(
        PlaybackState(
          isPlaying: true,
          isBuffering: false,
          isCompleted: false,
          position: Duration.zero,
          currentTrack: _track(),
        ),
      ),
    ),
    favoritesRepositoryProvider.overrideWithValue(_FakeFavoritesRepository()),
  ],
  child: localizedApp(const PlayerScreen()),
);

/// The lyrics pane is off-screen right when collapsed and at x≈0 when shown.
double _lyricsLeft(WidgetTester tester) =>
    tester.getTopLeft(find.byType(LyricsView)).dx;

void main() {
  testWidgets('a long left-swipe over the cover enters the lyrics pane', (
    tester,
  ) async {
    await tester.pumpWidget(_app());
    await tester.pumpAndSettle();

    final width = tester.view.physicalSize.width / tester.view.devicePixelRatio;
    expect(_lyricsLeft(tester), greaterThan(0)); // collapsed: off to the right

    await tester.drag(
      find.byType(PlayerScreen),
      Offset(-width - 50, 0),
    );
    await tester.pumpAndSettle();

    expect(_lyricsLeft(tester), lessThan(1)); // shown: flush left
  });

  testWidgets('a short left-swipe settles back to the cover', (tester) async {
    await tester.pumpWidget(_app());
    await tester.pumpAndSettle();

    final width = tester.view.physicalSize.width / tester.view.devicePixelRatio;
    await tester.drag(find.byType(PlayerScreen), Offset(-width * 0.2, 0));
    await tester.pumpAndSettle();

    expect(_lyricsLeft(tester), greaterThan(0));
  });
}
```

- [ ] **Step 2: Run the test to verify it fails**

Run: `flutter test test/portrait_lyrics_swipe_test.dart`
Expected: FAIL — the portrait body uses `AnimatedSwitcher`, so a horizontal drag does nothing and the lyrics pane is never laid out beside the cover.

- [ ] **Step 3: Implement the pager**

In `lib/features/player/player_screen.dart`, replace `_PortraitBody`'s `Expanded(child: AnimatedSwitcher(...))` with the swipe pager:

```dart
        Expanded(
          child: _PortraitPager(
            expanded: lyricsExpanded,
            onExpandedChanged: (value) {
              if (value) {
                onLyricsTap();
              } else {
                onLyricsCollapse();
              }
            },
            normal: _PortraitNormal(track: track, onLyricsTap: onLyricsTap),
            lyrics: LyricsView(onTap: onLyricsCollapse),
          ),
        ),
```

Add `_PortraitPager` below `_PortraitBody`:

```dart
/// A horizontal, follow-the-finger pager between the cover and the lyrics.
///
/// `value` 0 shows the cover, 1 shows the lyrics. A horizontal drag over the
/// cover / lyrics preview drives the page; a commit reports the new state (the
/// parent stores it) so taps and swipes stay in sync. The detector only claims
/// horizontal drags, so the lyrics pane's vertical scroll is untouched.
class _PortraitPager extends StatefulWidget {
  const _PortraitPager({
    required this.expanded,
    required this.onExpandedChanged,
    required this.normal,
    required this.lyrics,
  });

  final bool expanded;
  final ValueChanged<bool> onExpandedChanged;
  final Widget normal;
  final Widget lyrics;

  @override
  State<_PortraitPager> createState() => _PortraitPagerState();
}

class _PortraitPagerState extends State<_PortraitPager>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: AppMotion.standard,
    value: widget.expanded ? 1 : 0,
  );

  @override
  void didUpdateWidget(covariant _PortraitPager oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.expanded != oldWidget.expanded) {
      _c.animateTo(widget.expanded ? 1 : 0, curve: AppMotion.standardCurve);
    }
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  void _onEnd(DragEndDetails details) {
    final velocity = details.velocity.pixelsPerSecond.dx;
    final bool showLyrics;
    if (velocity < -700) {
      showLyrics = true;
    } else if (velocity > 700) {
      showLyrics = false;
    } else {
      showLyrics = _c.value > 0.4;
    }
    _c.animateTo(showLyrics ? 1 : 0, curve: AppMotion.standardCurve);
    widget.onExpandedChanged(showLyrics);
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        return GestureDetector(
          behavior: HitTestBehavior.opaque,
          onHorizontalDragUpdate: (details) {
            _c.value = (_c.value - details.delta.dx / width).clamp(0.0, 1.0);
          },
          onHorizontalDragEnd: _onEnd,
          child: ClipRect(
            child: AnimatedBuilder(
              animation: _c,
              builder: (context, child) {
                return Stack(
                  children: [
                    Positioned.fill(
                      child: Transform.translate(
                        offset: Offset(-_c.value * width, 0),
                        child: Opacity(
                          opacity: 1 - _c.value,
                          child: widget.normal,
                        ),
                      ),
                    ),
                    Positioned.fill(
                      child: Transform.translate(
                        offset: Offset((1 - _c.value) * width, 0),
                        child: widget.lyrics,
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        );
      },
    );
  }
}
```

- [ ] **Step 4: Run the tests to verify they pass**

Run: `flutter test test/portrait_lyrics_swipe_test.dart test/favorites_ui_test.dart test/lyrics_view_test.dart`
Expected: PASS — including the existing lyrics-view and favourites-player tests.

- [ ] **Step 5: Run the analyzer**

Run: `flutter analyze`
Expected: no issues.

- [ ] **Step 6: Commit**

```bash
git add lib/features/player/player_screen.dart test/portrait_lyrics_swipe_test.dart
git commit -m "feat: swipe the portrait cover into the lyrics pane"
```

---

### Task 4: Swipe-down to dismiss the player

**Files:**
- Modify: `lib/features/player/player_screen.dart` (`PlayerScreen`, `_HeaderRow`)
- Modify: `lib/features/player/mini_player_bar.dart` (`playerRoute`)
- Test: `test/player_dismiss_test.dart` (create)

**Interfaces:**
- Consumes: `AppMotion`, `playerRoute`.
- Produces: `const Key playerDismissHandleKey` (used by the test).

- [ ] **Step 1: Write the failing test**

Create `test/player_dismiss_test.dart`:

```dart
// Flind Player - cross-platform music player
// Copyright (C) 2026 top.qwind.app
//
// This program is free software: you can redistribute it and/or modify
// it under the terms of the GNU General Public License as published by
// the Free Software Foundation, version 3 of the License.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:flind_player/core/models/playback_state.dart';
import 'package:flind_player/core/models/track.dart';
import 'package:flind_player/core/repositories/favorites_repository.dart';
import 'package:flind_player/core/sources/source_track_id.dart';
import 'package:flind_player/data/providers/persistence_providers.dart';
import 'package:flind_player/data/providers/playback_providers.dart';
import 'package:flind_player/features/player/mini_player_bar.dart';
import 'package:flind_player/features/player/player_screen.dart';

import 'support/l10n.dart';

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

Track _track() => Track(
  source: 'local',
  sourceTrackId: const LocalTrackId('/music/a.mp3'),
  uri: 'local:/music/a.mp3',
  title: 'Now Playing',
);

Widget _host() => ProviderScope(
  overrides: [
    playbackStateProvider.overrideWith(
      (ref) => Stream.value(
        PlaybackState(
          isPlaying: true,
          isBuffering: false,
          isCompleted: false,
          position: Duration.zero,
          currentTrack: _track(),
        ),
      ),
    ),
    favoritesRepositoryProvider.overrideWithValue(_FakeFavoritesRepository()),
  ],
  child: localizedApp(
    Builder(
      builder: (context) => Scaffold(
        body: Center(
          child: ElevatedButton(
            onPressed: () => Navigator.of(context).push(playerRoute(context)),
            child: const Text('open'),
          ),
        ),
      ),
    ),
  ),
);

void main() {
  testWidgets('dragging the header down past the threshold dismisses', (
    tester,
  ) async {
    await tester.pumpWidget(_host());
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    expect(find.byType(PlayerScreen), findsOneWidget);

    await tester.drag(find.byKey(playerDismissHandleKey), const Offset(0, 500));
    await tester.pumpAndSettle();

    expect(find.byType(PlayerScreen), findsNothing);
  });

  testWidgets('a short downward drag springs back', (tester) async {
    await tester.pumpWidget(_host());
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    await tester.drag(find.byKey(playerDismissHandleKey), const Offset(0, 30));
    await tester.pumpAndSettle();

    expect(find.byType(PlayerScreen), findsOneWidget);
  });
}
```

- [ ] **Step 2: Run the test to verify it fails**

Run: `flutter test test/player_dismiss_test.dart`
Expected: FAIL — `playerDismissHandleKey` is undefined (and the header has no drag).

- [ ] **Step 3: Make the player route non-opaque**

In `lib/features/player/mini_player_bar.dart`, set `opaque: false` on the fade route so the app behind can show through while dismissing:

```dart
  return PageRouteBuilder<void>(
    opaque: false,
    transitionDuration: duration,
    reverseTransitionDuration: duration,
    pageBuilder: (context, animation, secondaryAnimation) =>
        const PlayerScreen(),
    transitionsBuilder: (context, animation, secondaryAnimation, child) =>
        FadeTransition(
          opacity: CurvedAnimation(
            parent: animation,
            curve: AppMotion.emphasizedCurve,
          ),
          child: child,
        ),
  );
```

- [ ] **Step 4: Implement the dismiss chrome + header handle**

In `lib/features/player/player_screen.dart`, add the key and the dismiss wrapper near `PlayerScreen`:

```dart
/// The header drag handle that dismisses the player.
const Key playerDismissHandleKey = Key('player_dismiss_handle');

/// Provides the dismiss drag callbacks to the header.
class _PlayerDismissScope extends InheritedWidget {
  const _PlayerDismissScope({
    required this.onDrag,
    required this.onEnd,
    required super.child,
  });

  final void Function(double dyFraction) onDrag;
  final void Function(double velocity) onEnd;

  static _PlayerDismissScope? maybeOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<_PlayerDismissScope>();

  @override
  bool updateShouldNotify(_PlayerDismissScope oldWidget) => false;
}
```

Replace `PlayerScreen.build` with the non-opaque, dismissible body:

```dart
  @override
  Widget build(BuildContext context) {
    return _PlayerDismissWrapper(
      child: AppSurface(child: SafeArea(child: const PlayerView())),
    );
  }
```

Add `_PlayerDismissWrapper` (below `PlayerScreen`):

```dart
/// Slides the player down with a header drag and pops on commit, dimming the
/// app behind (the route is non-opaque).
class _PlayerDismissWrapper extends StatefulWidget {
  const _PlayerDismissWrapper({required this.child});

  final Widget child;

  @override
  State<_PlayerDismissWrapper> createState() => _PlayerDismissWrapperState();
}

class _PlayerDismissWrapperState extends State<_PlayerDismissWrapper>
    with SingleTickerProviderStateMixin {
  /// 0 = resting, 1 = fully dismissed.
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: AppMotion.standard,
    value: 0,
  );

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  void _onDrag(double dyFraction) {
    _c.value = (_c.value + dyFraction).clamp(0.0, 1.0);
  }

  void _onEnd(double velocity) {
    if (_c.value > 0.4 || velocity > 700) {
      _c
          .animateTo(1, curve: AppMotion.emphasizedCurve)
          .then((_) {
            if (mounted) Navigator.of(context).maybePop();
          });
    } else {
      _c.animateTo(0, curve: AppMotion.standardCurve);
    }
  }

  @override
  Widget build(BuildContext context) {
    return _PlayerDismissScope(
      onDrag: _onDrag,
      onEnd: _onEnd,
      child: AnimatedBuilder(
        animation: _c,
        builder: (context, child) {
          final height = MediaQuery.sizeOf(context).height;
          return Stack(
            clipBehavior: Clip.none,
            children: [
              Positioned.fill(
                child: ColoredBox(
                  color: Colors.black.withValues(alpha: 0.5 * _c.value),
                ),
              ),
              Positioned.fill(
                child: Transform.translate(
                  offset: Offset(0, _c.value * height),
                  child: widget.child,
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
```

Then in `_HeaderRow.build`, wrap the `Row` in a drag handle:

```dart
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final dismiss = _PlayerDismissScope.maybeOf(context);
    final handle = Row(
      children: [
        IconButton(
          icon: const Icon(Icons.keyboard_arrow_down),
          onPressed: () => Navigator.of(context).maybePop(),
        ),
        Expanded(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              Text(
                artist,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
        // Balances the leading IconButton so the centred title/artist block
        // is truly screen-centred.
        const SizedBox(width: 48),
      ],
    );
    if (dismiss == null) return handle;
    return GestureDetector(
      key: playerDismissHandleKey,
      behavior: HitTestBehavior.opaque,
      onVerticalDragUpdate: (details) =>
          dismiss.onDrag(details.delta.dy / MediaQuery.sizeOf(context).height),
      onVerticalDragEnd: (details) =>
          dismiss.onEnd(details.velocity.pixelsPerSecond.dy),
      child: handle,
    );
  }
```

- [ ] **Step 5: Run the tests to verify they pass**

Run: `flutter test test/player_dismiss_test.dart test/cover_viewer_entry_test.dart test/favorites_ui_test.dart test/mini_player_bar_test.dart test/home_shell_test.dart`
Expected: PASS — including the existing player, mini-bar and shell tests.

- [ ] **Step 6: Run the analyzer and the full suite**

Run: `flutter analyze && flutter test`
Expected: analyzer clean; the whole suite passes (baseline 884 + the new tests).

- [ ] **Step 7: Commit**

```bash
git add lib/features/player/player_screen.dart lib/features/player/mini_player_bar.dart test/player_dismiss_test.dart
git commit -m "feat: swipe down on the player header to dismiss"
```

---

## Final Verification

- [ ] `flutter analyze` — no issues.
- [ ] `flutter test` — all tests pass.
- [ ] Manual eyeball (required; not automatable): on a device/emulator, swipe the mini bar left/right to skip (watch the carousel follow the finger and spring back on a short swipe); on the portrait player, swipe the cover left into the lyrics and right back out; drag the header down to dismiss and confirm a short drag springs back. On desktop, confirm the mini bar still opens the player on click, the slider still seeks, and the lyrics still scroll.

## Self-Review Notes

- **Spec coverage:** §3.1 providers → Task 1; §3.2 carousel → Task 2; §3.3 lyrics swipe → Task 3; §3.4 dismiss → Task 4; §3.5 animation/thresholds → all tasks; §3.6 conflicts → the "existing gestures still work" tests.
- **Interfaces:** `previousTrackProvider`/`nextTrackProvider`, `FakePlaybackController(queue)`, `playerDismissHandleKey`, `_PlayerDismissScope.onDrag/onEnd` are named identically across producers and consumers.
- **Deviations recorded for the executor:** replacing the portrait `AnimatedSwitcher` with `_PortraitPager` (spec §3.3 authorizes) and making `playerRoute` non-opaque (spec §8 anticipates the route interplay).
- **Known risk:** the carousel's reset-to-centre happens after `next()`/`previous()` resolves; if a one-frame flicker appears the plan's `ref.listen` reset also covers it. The dismiss route change to `opaque: false` is the riskiest single edit — verify the fade-in still looks right.
