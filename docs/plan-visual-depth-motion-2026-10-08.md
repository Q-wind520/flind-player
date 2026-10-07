# Visual Depth & Motion (B2 + M2) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Land the chosen "layered" visual direction (B2) and its motion (M2): tonal list panel, tinted playing row, floating mini-player capsule, and a cover Hero transition from the mini bar into the full-screen player.

**Architecture:** Everything flows through the existing design-token and theme layer. Motion durations/curves become `AppMotion` in `app_tokens.dart`; the playing-row tint and rounded list tiles become `listTileTheme` rules in `app_theme.dart`; the list backing becomes a new shared `ListPanel`; the mini player and player covers are wired together with a small shared `CoverHero` and a fade route. No new dependencies and no functional/IA changes.

**Tech Stack:** Flutter (Material 3), Dart SDK `^3.13.3`, `flutter_test`, Riverpod (test overrides only).

**Spec:** `docs/spec-visual-depth-motion-2026-10-08.md`

## Global Constraints

- Do **not** change functionality or information architecture; this is presentation only.
- Do **not** add any dependency (pubspec must stay unchanged).
- Use the existing tokens: `AppSpacing` (4/8/12/16/24/32) and `AppRadius` (8/12/16/20/pill) from `lib/app/theme/app_tokens.dart`.
- Radius mapping: list row cover `AppRadius.md` (12), `cardTheme` shape `AppRadius.md` (12), list panel `AppRadius.xl` (20), playing row `AppRadius.md` (12), mini player bar `AppRadius.xl` (20), player large cover `AppRadius.xl` (20, unchanged).
- Motion: `fast` = 150ms, `standard` = 250ms, `emphasized` = 400ms; curves `standard = Curves.easeInOutCubic`, `emphasized = Curves.easeOutCubic`.
- Style: two-space indent, trailing commas (repo formatter), one focused commit per task, commit messages prefixed `style:`/`test:`.
- Keep `flutter analyze` clean and the whole suite green. Baseline before this plan: **831 passed**.
- Commit locally on `master` only; **do not push**.

## Review Focus

The spec says what changes but not every input it will meet. These are the failure modes most likely to bite a user; each has a test in the owning task.

1. **A track with no cover** (`coverPath`/`coverUrl` both null) must still show a placeholder in the mini bar, in the player, and mid-flight (blank or crash would look broken). → Task 8 (flight-shuttle placeholder test), with the dock placeholders already covered in Tasks 9–10.
2. **No track playing** must keep the mini player invisible with **zero** reserved spacing (a floating margin must not leave an empty gap above the nav bar). → Task 7.
3. **Narrow 400px window with a very long title** must not overflow the now-inset mini bar. → Task 7 (keeps the existing 400px test green).
4. **A playing track changing** must not leave a stuck tint or double-tint (theme rule *and* per-row animation must not both paint). → Task 5.
5. **A list of many rows** must still settle and scroll (one implicit animation per row must not loop forever). → Task 5 / Task 6.

---

### Task 1: Motion tokens + theme animation wiring

**Files:**
- Modify: `lib/app/theme/app_tokens.dart`
- Modify: `lib/app/app.dart`
- Test: `test/app_motion_test.dart` (create)

**Interfaces:**
- Consumes: nothing.
- Produces: `AppMotion.fast` / `.standard` / `.emphasized` (`Duration`), `AppMotion.standardCurve` / `.emphasizedCurve` (`Curve`).

- [ ] **Step 1: Write the failing test**

Create `test/app_motion_test.dart`:

```dart
// Flind Player - cross-platform music player
// Copyright (C) 2026 top.qwind.app
//
// This program is free software: you can redistribute it and/or modify
// it under the terms of the GNU General Public License as published by
// the Free Software Foundation, version 3 of the License.

import 'package:flutter/animation.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:flind_player/app/theme/app_tokens.dart';

void main() {
  test('motion durations follow the fast/standard/emphasized scale', () {
    expect(AppMotion.fast, const Duration(milliseconds: 150));
    expect(AppMotion.standard, const Duration(milliseconds: 250));
    expect(AppMotion.emphasized, const Duration(milliseconds: 400));
  });

  test('motion curves are the documented easing', () {
    expect(AppMotion.standardCurve, Curves.easeInOutCubic);
    expect(AppMotion.emphasizedCurve, Curves.easeOutCubic);
  });
}
```

- [ ] **Step 2: Run the test to verify it fails**

Run: `flutter test test/app_motion_test.dart`
Expected: FAIL — `AppMotion` is not defined.

- [ ] **Step 3: Add `AppMotion` to the tokens**

In `lib/app/theme/app_tokens.dart`, add the import (keep alphabetical order, `animation` before `foundation`):

```dart
import 'package:flutter/animation.dart';
import 'package:flutter/foundation.dart';
```

Append the class after `AppRadius`:

```dart
/// Motion durations and curves, shared by every animated transition.
@immutable
class AppMotion {
  const AppMotion._();

  /// Short feedback: presses and colour transitions.
  static const Duration fast = Duration(milliseconds: 150);

  /// The default duration for most state changes.
  static const Duration standard = Duration(milliseconds: 250);

  /// Large transitions, such as the mini player growing into the player.
  static const Duration emphasized = Duration(milliseconds: 400);

  /// The default easing for state changes.
  static const Curve standardCurve = Curves.easeInOutCubic;

  /// The easing for large entrance transitions.
  static const Curve emphasizedCurve = Curves.easeOutCubic;
}
```

- [ ] **Step 4: Wire the theme-change duration**

In `lib/app/app.dart`, add the token import (after `app_theme.dart`, before `theme_color.dart`):

```dart
import 'package:flind_player/app/theme/app_theme.dart';
import 'package:flind_player/app/theme/app_tokens.dart';
```

Then add `themeAnimationDuration` to the `MaterialApp` (right after `themeMode:`):

```dart
      themeMode: themeModeForAppThemeMode(themeMode),
      // A theme-colour / brightness change cross-fades instead of snapping.
      themeAnimationDuration: AppMotion.standard,
```

- [ ] **Step 5: Run the test and the analyzer**

Run: `flutter test test/app_motion_test.dart && flutter analyze`
Expected: PASS (2 tests), analyzer reports no issues.

- [ ] **Step 6: Commit**

```bash
git add lib/app/theme/app_tokens.dart lib/app/app.dart test/app_motion_test.dart
git commit -m "style: add motion tokens and theme-change duration"
```

---

### Task 2: Theme rules — card radius, playing-row tint and shape

**Files:**
- Modify: `lib/app/theme/app_theme.dart`
- Test: `test/app_theme_test.dart`

**Interfaces:**
- Consumes: `AppRadius.md`, `AppMotion` not needed here.
- Produces:
  - `AppTheme.playingRowTintAlpha` (`double`, 0.12)
  - `AppTheme.playingRowTint(ColorScheme scheme, [double opacity = AppTheme.playingRowTintAlpha]) -> Color` — used again by Task 5.

- [ ] **Step 1: Update the failing test expectations**

In `test/app_theme_test.dart`, inside `'component themes derive from the tokens and the colour scheme'`, change the card-radius expectation to the medium radius:

```dart
      expect(
        (shape! as RoundedRectangleBorder).borderRadius,
        BorderRadius.circular(AppRadius.md),
      );
```

Add a new test at the end of `main()`:

```dart
  test('the playing row uses the primary tint and a rounded shape', () {
    for (final theme in [AppTheme.light(seed), AppTheme.dark(seed)]) {
      expect(
        theme.listTileTheme.selectedTileColor,
        AppTheme.playingRowTint(theme.colorScheme),
      );
      final shape = theme.listTileTheme.shape;
      expect(shape, isA<RoundedRectangleBorder>());
      expect(
        (shape! as RoundedRectangleBorder).borderRadius,
        BorderRadius.circular(AppRadius.md),
      );
    }
  });
```

- [ ] **Step 2: Run the test to verify it fails**

Run: `flutter test test/app_theme_test.dart`
Expected: FAIL — `AppTheme.playingRowTint` is undefined and the card radius is still `AppRadius.sm`.

- [ ] **Step 3: Implement the theme changes**

In `lib/app/theme/app_theme.dart`, add the tint constants/method inside `AppTheme` (e.g. right after `dark`):

```dart
  /// Opacity of the primary colour painted behind the currently-playing row.
  static const double playingRowTintAlpha = 0.12;

  /// The tint painted behind the currently-playing list row (and any other
  /// `selected` list tile), at [opacity] of the scheme's primary colour.
  static Color playingRowTint(
    ColorScheme scheme, [
    double opacity = playingRowTintAlpha,
  ]) => scheme.primary.withValues(alpha: opacity);
```

Change the card shape to the medium radius:

```dart
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.md),
        ),
```

Replace the `const listTileTheme` with a non-const one carrying the tint and shape:

```dart
      listTileTheme: ListTileThemeData(
        contentPadding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
        selectedTileColor: playingRowTint(colorScheme),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.md),
        ),
      ),
```

- [ ] **Step 4: Run the test to verify it passes**

Run: `flutter test test/app_theme_test.dart`
Expected: PASS.

- [ ] **Step 5: Run the analyzer**

Run: `flutter analyze`
Expected: no issues.

- [ ] **Step 6: Commit**

```bash
git add lib/app/theme/app_theme.dart test/app_theme_test.dart
git commit -m "style: tint the playing row and round list tiles and cards"
```

---

### Task 3: Enlarge the list cover radius to `AppRadius.md`

**Files:**
- Modify: `lib/features/library/widgets/track_list_items.dart` (`TrackCover`)
- Test: `test/track_cover_test.dart`

**Interfaces:**
- Consumes: `AppRadius.md`.
- Produces: nothing new.

- [ ] **Step 1: Update the failing test**

In `test/track_cover_test.dart`, rename the test and change the expectation:

```dart
  testWidgets('TrackCover rounds to the shared medium radius', (tester) async {
```

```dart
    expect(clip.borderRadius, BorderRadius.circular(AppRadius.md));
```

- [ ] **Step 2: Run the test to verify it fails**

Run: `flutter test test/track_cover_test.dart`
Expected: FAIL — still rounded with `AppRadius.sm`.

- [ ] **Step 3: Implement**

In `lib/features/library/widgets/track_list_items.dart`, inside `TrackCover.build`:

```dart
    final borderRadius = BorderRadius.circular(AppRadius.md);
```

- [ ] **Step 4: Run the test to verify it passes**

Run: `flutter test test/track_cover_test.dart`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add lib/features/library/widgets/track_list_items.dart test/track_cover_test.dart
git commit -m "style: round list covers to the medium radius"
```

---

### Task 4: Shared `ListPanel`

**Files:**
- Create: `lib/shared/list_panel.dart`
- Test: `test/list_panel_test.dart` (create)

**Interfaces:**
- Consumes: `AppSpacing`, `AppRadius`.
- Produces: `ListPanel({Key? key, required Widget child, EdgeInsetsGeometry? padding})` — used by Task 6.

- [ ] **Step 1: Write the failing test**

Create `test/list_panel_test.dart`:

```dart
// Flind Player - cross-platform music player
// Copyright (C) 2026 top.qwind.app
//
// This program is free software: you can redistribute it and/or modify
// it under the terms of the GNU General Public License as published by
// the Free Software Foundation, version 3 of the License.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:flind_player/app/theme/app_theme.dart';
import 'package:flind_player/app/theme/app_tokens.dart';
import 'package:flind_player/shared/list_panel.dart';

import 'support/l10n.dart';

void main() {
  testWidgets('renders its child on a tonal rounded panel', (tester) async {
    final theme = AppTheme.light(const Color(0xFF1BA784));
    await tester.pumpWidget(
      localizedApp(
        const Scaffold(body: ListPanel(child: Text('row'))),
        theme: theme,
      ),
    );

    expect(find.text('row'), findsOneWidget);

    final decorated = tester.widget<DecoratedBox>(
      find
          .descendant(
            of: find.byType(ListPanel),
            matching: find.byType(DecoratedBox),
          )
          .first,
    );
    final decoration = decorated.decoration as BoxDecoration;
    expect(decoration.color, theme.colorScheme.surfaceContainerLow);
    expect(decoration.borderRadius, BorderRadius.circular(AppRadius.xl));

    final clip = tester.widget<ClipRRect>(
      find
          .descendant(
            of: find.byType(ListPanel),
            matching: find.byType(ClipRRect),
          )
          .first,
    );
    expect(clip.borderRadius, BorderRadius.circular(AppRadius.xl));
  });
}
```

- [ ] **Step 2: Run the test to verify it fails**

Run: `flutter test test/list_panel_test.dart`
Expected: FAIL — `lib/shared/list_panel.dart` does not exist.

- [ ] **Step 3: Implement the widget**

Create `lib/shared/list_panel.dart`:

```dart
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

import 'package:flutter/material.dart';

import 'package:flind_player/app/theme/app_tokens.dart';

/// A tonal, rounded panel the main track lists sit on.
///
/// The page background stays [`AppSurface`] (`surfaceContainerHigh`) and the
/// panel is `surfaceContainerLow`, so a list reads as a sheet resting on the
/// page. The panel clips its child to the rounded corners and casts a very
/// subtle shadow so it stays quiet in both light and dark themes.
class ListPanel extends StatelessWidget {
  const ListPanel({super.key, required this.child, this.padding});

  /// The list (or other content) shown on the panel.
  final Widget child;

  /// Padding between the panel edge and [child]. Defaults to [AppSpacing.xs].
  final EdgeInsetsGeometry? padding;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final radius = BorderRadius.circular(AppRadius.xl);
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.md,
        AppSpacing.xs,
        AppSpacing.md,
        AppSpacing.sm,
      ),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: scheme.surfaceContainerLow,
          borderRadius: radius,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 3,
              offset: const Offset(0, 1),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: radius,
          child: Padding(
            padding: padding ?? const EdgeInsets.all(AppSpacing.xs),
            child: child,
          ),
        ),
      ),
    );
  }
}
```

- [ ] **Step 4: Run the test to verify it passes**

Run: `flutter test test/list_panel_test.dart && flutter analyze`
Expected: PASS, no analyzer issues.

- [ ] **Step 5: Commit**

```bash
git add lib/shared/list_panel.dart test/list_panel_test.dart
git commit -m "style: add the shared tonal ListPanel"
```

---

### Task 5: Animate the playing-row tint in `TrackTile`

**Files:**
- Modify: `lib/features/library/widgets/track_list_items.dart` (`TrackTile`)
- Test: `test/track_tile_test.dart` (create)

**Interfaces:**
- Consumes: `AppMotion.standard`, `AppMotion.standardCurve`, `AppTheme.playingRowTint`, `AppTheme.playingRowTintAlpha`.
- Produces: nothing new (visual behavior only).

- [ ] **Step 1: Write the failing test**

Create `test/track_tile_test.dart`:

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

import 'package:flind_player/app/theme/app_theme.dart';
import 'package:flind_player/core/models/track.dart';
import 'package:flind_player/core/sources/source_track_id.dart';
import 'package:flind_player/data/providers/persistence_providers.dart';
import 'package:flind_player/features/library/widgets/cache_action_button.dart';
import 'package:flind_player/features/library/widgets/track_list_items.dart';

import 'support/l10n.dart';

Track _track() => Track(
  source: 'local',
  sourceTrackId: const LocalTrackId('/music/a.mp3'),
  uri: 'local:/music/a.mp3',
  title: 'A',
);

Widget _app({required bool isCurrent}) => ProviderScope(
  overrides: [
    isFavoriteProvider.overrideWith((ref, uri) async => false),
    audioCacheEntryProvider.overrideWith((ref, track) async => null),
  ],
  child: localizedApp(
    Scaffold(
      body: TrackTile(
        track: _track(),
        isCurrent: isCurrent,
        isPlaying: isCurrent,
        onTap: () {},
      ),
    ),
    theme: AppTheme.light(const Color(0xFF1BA784)),
  ),
);

void main() {
  testWidgets('the current row is tinted with the playing-row colour', (
    tester,
  ) async {
    await tester.pumpWidget(_app(isCurrent: true));
    await tester.pumpAndSettle();

    final scheme = Theme.of(tester.element(find.byType(TrackTile))).colorScheme;
    final tile = tester.widget<ListTile>(find.byType(ListTile));
    expect(tile.selected, isTrue);
    expect(tile.selectedTileColor, AppTheme.playingRowTint(scheme));
  });

  testWidgets('a non-current row paints no tint', (tester) async {
    await tester.pumpWidget(_app(isCurrent: false));
    await tester.pumpAndSettle();

    final scheme = Theme.of(tester.element(find.byType(TrackTile))).colorScheme;
    final tile = tester.widget<ListTile>(find.byType(ListTile));
    expect(tile.selectedTileColor, AppTheme.playingRowTint(scheme, 0));
  });
}
```

- [ ] **Step 2: Run the test to verify it fails**

Run: `flutter test test/track_tile_test.dart`
Expected: FAIL — `selectedTileColor` is `null` (the tile inherits the theme rule but is not animated).

- [ ] **Step 3: Implement the animated tint**

In `lib/features/library/widgets/track_list_items.dart`, add the `AppTheme` import (above `app_tokens.dart`):

```dart
import 'package:flind_player/app/theme/app_theme.dart';
import 'package:flind_player/app/theme/app_tokens.dart';
```

Replace the body of `TrackTile.build` (the `return ListTile(...)`) with the animated wrapper:

```dart
    return TweenAnimationBuilder<double>(
      tween: Tween<double>(begin: 0, end: isCurrent ? 1 : 0),
      duration: AppMotion.standard,
      curve: AppMotion.standardCurve,
      builder: (context, tint, child) => ListTile(
        onTap: unavailable ? null : onTap,
        enabled: !unavailable,
        selected: isCurrent,
        selectedTileColor: AppTheme.playingRowTint(
          scheme,
          AppTheme.playingRowTintAlpha * tint,
        ),
        leading: TrackCover(track: track, size: 48),
        title: Text(track.title, maxLines: 1, overflow: TextOverflow.ellipsis),
        subtitle: Row(
          children: [
            Expanded(
              child: Text(
                unavailable
                    ? l10n.trackUnavailable
                    : track.artist ?? l10n.unknownArtist,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(width: 8),
            SourceBadge(source: track.source),
          ],
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (isPlaying) ...[
              Icon(Icons.graphic_eq, size: 20, color: scheme.primary),
              const SizedBox(width: 8),
            ],
            Text(
              formatTrackDuration(track.duration),
              style: theme.textTheme.labelMedium,
            ),
            TrackActionsButton(
              track: track,
              playlistId: playlistId,
              showDeleteTrack: showDeleteTrack,
            ),
          ],
        ),
      ),
    );
```

> Note: `ListTile.selectedTileColor` overrides the inherited theme tint, so the theme paints nothing and only the animated colour shows — no double tint.

- [ ] **Step 4: Run the test to verify it passes**

Run: `flutter test test/track_tile_test.dart && flutter test test/track_view_test.dart test/playlist_ui_test.dart`
Expected: PASS (the `ListTile`/`TrackTile` finders in the existing tests still resolve).

- [ ] **Step 5: Run the analyzer**

Run: `flutter analyze`
Expected: no issues.

- [ ] **Step 6: Commit**

```bash
git add lib/features/library/widgets/track_list_items.dart test/track_tile_test.dart
git commit -m "style: animate the playing-row tint"
```

---

### Task 6: Put the list view on a `ListPanel`

**Files:**
- Modify: `lib/features/library/widgets/track_view.dart` (`_list()`)
- Test: `test/track_view_test.dart`

**Interfaces:**
- Consumes: `ListPanel` (Task 4).
- Produces: nothing new.

- [ ] **Step 1: Write the failing test**

In `test/track_view_test.dart`, add the `ListPanel` import:

```dart
import 'package:flind_player/shared/list_panel.dart';
```

Add these tests inside `main()`:

```dart
  testWidgets('list view sits on a ListPanel', (tester) async {
    await tester.pumpWidget(
      _wrap(
        TrackView(
          tracks: [_track(1)],
          view: LibraryView.list,
          currentUri: null,
          isPlaying: false,
          onPlay: (_) {},
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byType(ListPanel), findsOneWidget);
  });

  testWidgets('grid and waterfall views do not use a ListPanel', (
    tester,
  ) async {
    await tester.pumpWidget(
      _wrap(
        TrackView(
          tracks: [_track(1)],
          view: LibraryView.showcase,
          currentUri: null,
          isPlaying: false,
          onPlay: (_) {},
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byType(ListPanel), findsNothing);
  });
```

- [ ] **Step 2: Run the test to verify it fails**

Run: `flutter test test/track_view_test.dart`
Expected: FAIL — no `ListPanel` is present.

- [ ] **Step 3: Implement**

In `lib/features/library/widgets/track_view.dart`, add the import:

```dart
import 'package:flind_player/shared/list_panel.dart';
```

Wrap the list in `_list()`:

```dart
  Widget _list() {
    return ListPanel(
      child: ListView.builder(
        itemCount: tracks.length,
        itemBuilder: (context, index) {
          final track = tracks[index];
          final isCurrent = currentUri != null && track.uri == currentUri;
          return TrackTile(
            track: track,
            isCurrent: isCurrent,
            isPlaying: isCurrent && isPlaying,
            unavailable: track.id == null,
            playlistId: playlistId,
            showDeleteTrack: showDeleteTrack,
            onTap: () => onPlay(index),
          );
        },
      ),
    );
  }
```

- [ ] **Step 4: Run the tests to verify they pass**

Run: `flutter test test/track_view_test.dart test/library_sort_test.dart test/favorites_ui_test.dart test/playlist_ui_test.dart`
Expected: PASS.

- [ ] **Step 5: Run the analyzer**

Run: `flutter analyze`
Expected: no issues.

- [ ] **Step 6: Commit**

```bash
git add lib/features/library/widgets/track_view.dart test/track_view_test.dart
git commit -m "style: rest the list view on a tonal ListPanel"
```

---

### Task 7: Floating mini-player capsule

**Files:**
- Modify: `lib/features/player/mini_player_bar.dart`
- Test: `test/mini_player_bar_test.dart`

**Interfaces:**
- Consumes: `AppSpacing`, `AppRadius`.
- Produces: nothing new.

> Margin decision: the inset lives **inside** `MiniPlayerBar` (not `HomeShell`) so that when nothing is playing the widget still returns `SizedBox.shrink` and reserves no space above the nav bar.

- [ ] **Step 1: Update the failing test**

In `test/mini_player_bar_test.dart`, add the `AppSurface` import:

```dart
import 'package:flind_player/shared/app_surface.dart';
```

Change the cover-radius expectation (and its test name):

```dart
  testWidgets('cover is rounded with the shared medium radius', (tester) async {
```

```dart
    expect(clip.borderRadius, BorderRadius.circular(AppRadius.md));
```

Add a new test at the end of `main()`:

```dart
  testWidgets('renders as a floating rounded capsule', (tester) async {
    final state = PlaybackState(
      isPlaying: false,
      isBuffering: false,
      isCompleted: false,
      position: Duration.zero,
      currentTrack: _track('Capsule Test'),
    );

    await tester.pumpWidget(_app(state: state));
    await tester.pumpAndSettle();

    final surface = tester.widget<AppSurface>(find.byType(AppSurface));
    expect(surface.borderRadius, BorderRadius.circular(AppRadius.xl));
  });
```

- [ ] **Step 2: Run the test to verify it fails**

Run: `flutter test test/mini_player_bar_test.dart`
Expected: FAIL — the surface has no `borderRadius` and the cover still uses `AppRadius.sm`.

- [ ] **Step 3: Implement the capsule**

In `lib/features/player/mini_player_bar.dart`, replace the `return AppSurface(child: Column(...))` with a floated, shadowed capsule (the `Column` is shown unrolled here; its children are unchanged from the file):

```dart
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.sm,
        0,
        AppSpacing.sm,
        AppSpacing.sm,
      ),
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(AppRadius.xl),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.12),
              blurRadius: 18,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: AppSurface(
          borderRadius: BorderRadius.circular(AppRadius.xl),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Thin progress line at the very top.
              if (durationMs > 0)
                LinearProgressIndicator(value: progress, minHeight: 2),
              InkWell(
                key: barKey,
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => const PlayerScreen(),
                  ),
                ),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                  child: Row(
                    children: [
                      // Cover art.
                      _MiniCover(track: track),
                      const SizedBox(width: 12),
                      // Title and artist.
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
                              style: Theme.of(context).textTheme.bodySmall
                                  ?.copyWith(color: scheme.onSurfaceVariant),
                            ),
                          ],
                        ),
                      ),
                      // Play/pause.
                      IconButton(
                        onPressed: () => ref
                            .read(playbackControllerProvider)
                            .togglePlayPause(),
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
                ),
              ),
            ],
          ),
        ),
      ),
    );
```

Then in `_MiniCover.build`, change the radius:

```dart
      borderRadius: BorderRadius.circular(AppRadius.md),
```

- [ ] **Step 4: Run the tests to verify they pass**

Run: `flutter test test/mini_player_bar_test.dart test/home_shell_test.dart`
Expected: PASS (including the 400px overflow test, which must stay green with the new insets).

- [ ] **Step 5: Run the analyzer**

Run: `flutter analyze`
Expected: no issues.

- [ ] **Step 6: Commit**

```bash
git add lib/features/player/mini_player_bar.dart test/mini_player_bar_test.dart
git commit -m "style: float the mini player as a rounded capsule"
```

---

### Task 8: Shared `CoverHero`

**Files:**
- Create: `lib/shared/cover_hero.dart`
- Test: `test/cover_hero_test.dart` (create)

**Interfaces:**
- Consumes: `AppRadius.xl`, `CoverImage`.
- Produces:
  - `String playerCoverHeroTag(String uri)` — used by Tasks 9 and 10.
  - `CoverHero({Key? key, required String uri, String? coverPath, String? coverUrl, required Widget child})`.

- [ ] **Step 1: Write the failing test**

Create `test/cover_hero_test.dart`:

```dart
// Flind Player - cross-platform music player
// Copyright (C) 2026 top.qwind.app
//
// This program is free software: you can redistribute it and/or modify
// it under the terms of the GNU General Public License as published by
// the Free Software Foundation, version 3 of the License.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:flind_player/shared/cover_hero.dart';

void main() {
  testWidgets('wraps its child in a Hero tagged for the track', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: CoverHero(
          uri: 'local:/music/a.mp3',
          child: SizedBox(width: 48, height: 48),
        ),
      ),
    );

    final hero = tester.widget<Hero>(find.byType(Hero));
    expect(hero.tag, playerCoverHeroTag('local:/music/a.mp3'));
  });

  testWidgets('the flight shuttle shows a placeholder for a coverless track', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: CoverHero(
          uri: 'local:/music/a.mp3',
          child: SizedBox(width: 48, height: 48),
        ),
      ),
    );

    final hero = tester.widget<Hero>(find.byType(Hero));
    final context = tester.element(find.byType(CoverHero));
    final shuttle = hero.flightShuttleBuilder!(
      context,
      const AlwaysStoppedAnimation<double>(1),
      HeroFlightDirection.push,
      context,
      context,
    );

    await tester.pumpWidget(
      MaterialApp(home: Scaffold(body: Center(child: shuttle))),
    );
    await tester.pumpAndSettle();

    expect(find.byIcon(Icons.music_note), findsOneWidget);
  });
}
```

- [ ] **Step 2: Run the test to verify it fails**

Run: `flutter test test/cover_hero_test.dart`
Expected: FAIL — `lib/shared/cover_hero.dart` does not exist.

- [ ] **Step 3: Implement the widget**

Create `lib/shared/cover_hero.dart`:

```dart
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

import 'package:flutter/material.dart';

import 'package:flind_player/app/theme/app_tokens.dart';
import 'package:flind_player/shared/cover_image.dart';

/// The [Hero] tag shared by the mini-player cover and the full-screen player
/// cover, derived from the track uri so both ends of the flight match.
String playerCoverHeroTag(String uri) => 'player-cover:$uri';

/// Wraps a cover in a [Hero] that flies between the mini player bar and the
/// full-screen player.
///
/// The flight shuttle renders a cover filling the interpolated rect with the
/// large radius, so the artwork grows/shrinks smoothly instead of snapping to
/// the destination's fixed size mid-flight. A coverless track flies a tonal
/// music-note placeholder rather than a blank hole.
class CoverHero extends StatelessWidget {
  const CoverHero({
    super.key,
    required this.uri,
    this.coverPath,
    this.coverUrl,
    required this.child,
  });

  /// The track uri the [Hero.tag] is derived from.
  final String uri;

  /// File path to the cached cover, forwarded to the flight shuttle.
  final String? coverPath;

  /// Remote cover url, forwarded to the flight shuttle.
  final String? coverUrl;

  /// The docked cover shown when the hero is not in flight.
  final Widget child;

  bool get _hasCover =>
      (coverPath != null && coverPath!.isNotEmpty) ||
      (coverUrl != null && coverUrl!.isNotEmpty);

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Hero(
      tag: playerCoverHeroTag(uri),
      flightShuttleBuilder: (context, animation, direction, from, to) =>
          ClipRRect(
            borderRadius: BorderRadius.circular(AppRadius.xl),
            child: Container(
              color: scheme.surfaceContainerHighest,
              child: _hasCover
                  ? CoverImage(
                      path: coverPath,
                      url: coverUrl,
                      size: double.infinity,
                    )
                  : Center(
                      child: Icon(
                        Icons.music_note,
                        size: 40,
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
            ),
          ),
      child: child,
    );
  }
}
```

- [ ] **Step 4: Run the test to verify it passes**

Run: `flutter test test/cover_hero_test.dart && flutter analyze`
Expected: PASS, no analyzer issues.

- [ ] **Step 5: Commit**

```bash
git add lib/shared/cover_hero.dart test/cover_hero_test.dart
git commit -m "style: add the shared CoverHero flight"
```

---

### Task 9: Mini player — cover Hero + fade route

**Files:**
- Modify: `lib/features/player/mini_player_bar.dart`
- Test: `test/mini_player_bar_test.dart`

**Interfaces:**
- Consumes: `CoverHero`, `playerCoverHeroTag` (Task 8), `AppMotion.emphasized`, `AppMotion.emphasizedCurve`.
- Produces: nothing new.

- [ ] **Step 1: Write the failing test**

In `test/mini_player_bar_test.dart`, add the import:

```dart
import 'package:flind_player/shared/cover_hero.dart';
```

Add a test at the end of `main()`:

```dart
  testWidgets('the mini cover is a Hero tagged for the player transition', (
    tester,
  ) async {
    final state = PlaybackState(
      isPlaying: false,
      isBuffering: false,
      isCompleted: false,
      position: Duration.zero,
      currentTrack: _track('Hero Test'),
    );

    await tester.pumpWidget(_app(state: state));
    await tester.pumpAndSettle();

    expect(
      find.byWidgetPredicate(
        (w) => w is Hero && w.tag == playerCoverHeroTag('local:/music/test.mp3'),
      ),
      findsOneWidget,
    );
  });
```

- [ ] **Step 2: Run the test to verify it fails**

Run: `flutter test test/mini_player_bar_test.dart`
Expected: FAIL — the mini cover is not a `Hero`.

- [ ] **Step 3: Implement**

In `lib/features/player/mini_player_bar.dart`, add imports:

```dart
import 'package:flind_player/shared/cover_hero.dart';
```

Replace the `InkWell.onTap` route with a fade transition:

```dart
          InkWell(
            key: barKey,
            onTap: () => Navigator.of(context).push(
              PageRouteBuilder<void>(
                transitionDuration: AppMotion.emphasized,
                reverseTransitionDuration: AppMotion.emphasized,
                pageBuilder: (context, animation, secondaryAnimation) =>
                    const PlayerScreen(),
                transitionsBuilder:
                    (context, animation, secondaryAnimation, child) =>
                        FadeTransition(
                          opacity: CurvedAnimation(
                            parent: animation,
                            curve: AppMotion.emphasizedCurve,
                          ),
                          child: child,
                        ),
              ),
            ),
```

Wrap the mini cover's `ClipRRect` in a `CoverHero` (inside `_MiniCover.build`):

```dart
    return CoverHero(
      uri: track.uri,
      coverPath: coverPath,
      coverUrl: coverUrl,
      child: ClipRRect(
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
      ),
    );
```

- [ ] **Step 4: Run the tests to verify they pass**

Run: `flutter test test/mini_player_bar_test.dart test/home_shell_test.dart`
Expected: PASS — including `tapping the bar opens the full-screen player` (now through the fade route).

- [ ] **Step 5: Run the analyzer**

Run: `flutter analyze`
Expected: no issues.

- [ ] **Step 6: Commit**

```bash
git add lib/features/player/mini_player_bar.dart test/mini_player_bar_test.dart
git commit -m "style: fly the mini cover into the player on a fade route"
```

---

### Task 10: Player cover Hero destination

**Files:**
- Modify: `lib/features/player/player_screen.dart` (`_PlayerCover`)
- Test: `test/favorites_ui_test.dart`

**Interfaces:**
- Consumes: `CoverHero`, `playerCoverHeroTag` (Task 8).
- Produces: nothing new.

- [ ] **Step 1: Write the failing test**

In `test/favorites_ui_test.dart`, add the import:

```dart
import 'package:flind_player/shared/cover_hero.dart';
```

Add a test inside the player group (next to `player cover is rounded with the shared large radius`):

```dart
    testWidgets('the player cover is a Hero tagged for the transition', (
      tester,
    ) async {
      final track = _track('Now Playing');
      final state = PlaybackState(
        isPlaying: true,
        isBuffering: false,
        isCompleted: false,
        position: Duration.zero,
        currentTrack: track,
      );

      await tester.pumpWidget(_playerApp(playbackState: state));
      await tester.pumpAndSettle();

      expect(
        find.byWidgetPredicate(
          (w) => w is Hero && w.tag == playerCoverHeroTag(track.uri),
        ),
        findsOneWidget,
      );
    });
```

- [ ] **Step 2: Run the test to verify it fails**

Run: `flutter test test/favorites_ui_test.dart`
Expected: FAIL — the player cover is not a `Hero`.

- [ ] **Step 3: Implement**

In `lib/features/player/player_screen.dart`, add the import:

```dart
import 'package:flind_player/shared/cover_hero.dart';
```

In `_PlayerCover.build`, wrap the existing `ClipRRect` in a `CoverHero`:

```dart
    return CoverHero(
      uri: track.uri,
      coverPath: coverPath,
      coverUrl: coverUrl,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(AppRadius.xl),
        child: Container(
          width: size,
          height: size,
          color: scheme.surfaceContainerHighest,
          child: hasCover
              ? CoverImage(
                  path: coverPath,
                  url: coverUrl,
                  size: size,
                  errorBuilder: (context, error, stackTrace) =>
                      _placeholder(scheme),
                )
              : _placeholder(scheme),
        ),
      ),
    );
```

- [ ] **Step 4: Run the tests to verify they pass**

Run: `flutter test test/favorites_ui_test.dart`
Expected: PASS — including `player cover is rounded with the shared large radius` (the first `ClipRRect` under `PlayerScreen` is still the cover).

- [ ] **Step 5: Run the full suite and analyzer**

Run: `flutter analyze && flutter test`
Expected: analyzer clean; the whole suite passes (baseline 831 + the new tests).

- [ ] **Step 6: Commit**

```bash
git add lib/features/player/player_screen.dart test/favorites_ui_test.dart
git commit -m "style: make the player cover the hero destination"
```

---

## Final Verification

- [ ] `flutter analyze` — no issues.
- [ ] `flutter test` — all tests pass.
- [ ] Manual eyeball (required; not automatable): on a desktop/device, open the player from the mini bar and watch the cover fly; switch light/dark and a theme colour and watch the cross-fade; check the playing row tint, the tonal list panel, and the floating mini capsule in both themes and at a narrow width.

## Self-Review Notes

- **Spec coverage:** §3.1 radii → Tasks 2/3/4/7/10; §3.2 playing-row tint → Task 2; §3.3 list panel → Tasks 4/6; §3.4 mini capsule → Task 7; §3.5 motion tokens → Task 1; §3.6 Hero + fade → Tasks 8/9/10; §3.7 theme animation → Task 1; §3.8 tint transition → Task 5.
- **Deviations recorded:** the mini capsule's inset lives inside `MiniPlayerBar` rather than `HomeShell` (so an idle bar reserves no space) — behavior matches the spec, mechanism differs.
- **Type consistency:** `playerCoverHeroTag`, `CoverHero.uri/coverPath/coverUrl/child`, `AppTheme.playingRowTint/playingRowTintAlpha`, and `ListPanel.child/padding` are named identically across the tasks that produce and consume them.
