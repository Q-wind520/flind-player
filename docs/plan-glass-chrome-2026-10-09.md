# In-App Glass Chrome (Bottom Nav + Mini Player) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Give the bottom `NavigationBar` and the `MiniPlayerBar` an in-app frosted-glass material (backdrop blur + translucent tint), with the content scrolling behind them.

**Architecture:** A new shared `GlassSurface` widget (ClipRRect → BackdropFilter → translucent tint → edge highlight → shadow) plus an `AppGlass` token set in `app_tokens.dart`. The mini player swaps its opaque `AppSurface` for `GlassSurface`; the bottom nav bar is made transparent via the theme and wrapped in `GlassSurface`; the compact scaffold uses `extendBody` and the wide layout overlays the mini bar with a measured bottom inset.

**Tech Stack:** Flutter (Material 3), `dart:ui` `ImageFilter`, `flutter_test`.

**Spec:** `docs/spec-glass-chrome-2026-10-09.md`

## Global Constraints

- **No new dependencies** (pubspec unchanged); use Flutter's built-in `BackdropFilter` + `ImageFilter.blur`.
- **In-app glass only** — do not add window-level transparency/acrylic.
- **Do not change**: the player body (`player_screen.dart`) or the wide `NavigationRail`.
- Presentation only: no data-layer or information-architecture changes.
- Blur σ = 14; tint = `scheme.surface` at alpha 0.72 (light) / 0.62 (dark).
- Use existing tokens `AppSpacing` / `AppRadius`.
- Keep `flutter analyze` clean and the whole suite green. Baseline before this plan: **850 passed**.
- Commit locally on `master` only; **do not push**.

## Review Focus

The spec says what the software must do but not every input; these are the failure modes most likely to bite a user, each with a test in the owning task.

1. **Nothing playing** must keep the mini player invisible and reserve no space — the glass must not create a ghost bar. → Task 3 (the existing "renders nothing when currentTrack is null" stays green) and Task 5 (an idle wide test asserts a zero bottom inset).
2. **The nav bar must not paint its own opaque background** over the glass (otherwise there is no blur). → Task 2.
3. **Dark and light must both stay legible** (tint alpha differs by brightness). → Task 1.
4. **The content must actually pass behind the chrome** (compact `extendBody`), or the blur has nothing to sample. → Task 4.
5. **Wide layout**: the mini bar overlays the list but its last row must stay reachable (a non-zero content bottom inset while playing). → Task 5.

---

### Task 1: Glass foundation — `AppGlass` tokens + `GlassSurface`

**Files:**
- Modify: `lib/app/theme/app_tokens.dart`
- Create: `lib/shared/glass_surface.dart`
- Test: `test/app_glass_test.dart` (create), `test/glass_surface_test.dart` (create)

**Interfaces:**
- Consumes: nothing.
- Produces:
  - `AppGlass.blurSigma` (`double`, 14), `AppGlass.tintOn(ColorScheme) -> Color`, `AppGlass.topEdgeOn(ColorScheme) -> Border`, `AppGlass.shadow` (`List<BoxShadow>`).
  - `GlassSurface({Key? key, required Widget child, BorderRadius? borderRadius, double blurSigma = AppGlass.blurSigma, Border? border, List<BoxShadow>? boxShadow})` — used by Tasks 3–5.

- [ ] **Step 1: Write the failing token test**

Create `test/app_glass_test.dart`:

```dart
// Flind Player - cross-platform music player
// Copyright (C) 2026 top.qwind.app
//
// This program is free software: you can redistribute it and/or modify
// it under the terms of the GNU General Public License as published by
// the Free Software Foundation, version 3 of the License.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:flind_player/app/theme/app_tokens.dart';

void main() {
  test('blur sigma is the documented moderate value', () {
    expect(AppGlass.blurSigma, 14);
  });

  test('the tint is translucent and heavier in light than dark', () {
    final light = ColorScheme.fromSeed(seedColor: const Color(0xFF1BA784));
    final dark = ColorScheme.fromSeed(
      seedColor: const Color(0xFF1BA784),
      brightness: Brightness.dark,
    );
    expect(AppGlass.tintOn(light).a, closeTo(0.72, 0.001));
    expect(AppGlass.tintOn(dark).a, closeTo(0.62, 0.001));
  });

  test('the top edge is a hairline on the top side only', () {
    final scheme = ColorScheme.fromSeed(seedColor: const Color(0xFF1BA784));
    final border = AppGlass.topEdgeOn(scheme);
    expect(border.top.width, 1);
    expect(border.bottom, BorderSide.none);
    expect(border.left, BorderSide.none);
    expect(border.right, BorderSide.none);
  });

  test('the shared shadow is a soft downward shadow', () {
    expect(AppGlass.shadow, hasLength(1));
    final shadow = AppGlass.shadow.single;
    expect(shadow.blurRadius, 18);
    expect(shadow.offset, const Offset(0, 6));
  });
}
```

- [ ] **Step 2: Write the failing widget test**

Create `test/glass_surface_test.dart`:

```dart
// Flind Player - cross-platform music player
// Copyright (C) 2026 top.qwind.app
//
// This program is free software: you can redistribute it and/or modify
// it under the terms of the GNU General Public License as published by
// the Free Software Foundation, version 3 of the License.

import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:flind_player/app/theme/app_theme.dart';
import 'package:flind_player/app/theme/app_tokens.dart';
import 'package:flind_player/shared/glass_surface.dart';

import 'support/l10n.dart';

void main() {
  testWidgets('blurs its backdrop, clips to the radius and tints the surface', (
    tester,
  ) async {
    final theme = AppTheme.light(const Color(0xFF1BA784));
    await tester.pumpWidget(
      localizedApp(
        const Scaffold(
          body: GlassSurface(
            borderRadius: BorderRadius.all(Radius.circular(AppRadius.xl)),
            child: Text('glass'),
          ),
        ),
        theme: theme,
      ),
    );

    expect(find.text('glass'), findsOneWidget);

    final backdrop = tester.widget<BackdropFilter>(find.byType(BackdropFilter));
    expect(backdrop.filter, isA<ImageFilter>());

    final clip = tester.widget<ClipRRect>(
      find
          .descendant(
            of: find.byType(GlassSurface),
            matching: find.byType(ClipRRect),
          )
          .first,
    );
    expect(
      clip.borderRadius,
      const BorderRadius.all(Radius.circular(AppRadius.xl)),
    );

    final tint = AppGlass.tintOn(theme.colorScheme);
    final decorations = tester
        .widgetList<DecoratedBox>(
          find.descendant(
            of: find.byType(GlassSurface),
            matching: find.byType(DecoratedBox),
          ),
        )
        .map((d) => d.decoration)
        .whereType<BoxDecoration>();
    expect(decorations.any((d) => d.color == tint), isTrue);
    expect(tint.a, lessThan(1));
  });
}
```

- [ ] **Step 3: Run the tests to verify they fail**

Run: `flutter test test/app_glass_test.dart test/glass_surface_test.dart`
Expected: FAIL — `AppGlass` and `GlassSurface` are undefined.

- [ ] **Step 4: Implement the tokens**

In `lib/app/theme/app_tokens.dart`, replace the two imports with a single material import (material provides `@immutable`, `Curve`, `Curves`, `ColorScheme`, `BoxShadow`):

```dart
import 'package:flutter/material.dart';
```

Append after `AppMotion`:

```dart
/// Frosted-glass tokens for the bottom chrome.
@immutable
class AppGlass {
  const AppGlass._();

  /// Backdrop blur strength (Gaussian sigma).
  static const double blurSigma = 14;

  /// The translucent tint laid over the blur. Heavier in light mode so text
  /// stays legible; lighter in dark mode so the glass reads as glass.
  static Color tintOn(ColorScheme scheme) => scheme.surface.withValues(
    alpha: scheme.brightness == Brightness.light ? 0.72 : 0.62,
  );

  /// A 1px highlight along the top edge of a glass sheet.
  static Border topEdgeOn(ColorScheme scheme) => Border(
    top: BorderSide(color: scheme.outlineVariant.withValues(alpha: 0.6)),
  );

  /// The soft shadow shared by glass sheets and the floating mini capsule.
  static const List<BoxShadow> shadow = [
    BoxShadow(
      color: Color(0x1F000000), // ~12% black
      blurRadius: 18,
      offset: Offset(0, 6),
    ),
  ];
}
```

- [ ] **Step 5: Implement `GlassSurface`**

Create `lib/shared/glass_surface.dart`:

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

import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';

import 'package:flind_player/app/theme/app_tokens.dart';

/// A frosted-glass surface: a backdrop blur, a translucent tonal tint, an
/// optional edge highlight, a soft shadow, and rounded-corner clipping.
///
/// The blur samples what is painted behind the widget within the app (content
/// scrolling under a glass bar), never the desktop behind the window.
class GlassSurface extends StatelessWidget {
  const GlassSurface({
    super.key,
    required this.child,
    this.borderRadius,
    this.blurSigma = AppGlass.blurSigma,
    this.border,
    this.boxShadow,
  });

  final Widget child;

  /// Clips the blur and tint to this radius; `null` leaves square corners.
  final BorderRadius? borderRadius;

  /// Backdrop blur strength.
  final double blurSigma;

  /// Optional edge highlight, painted above the child.
  final Border? border;

  /// Optional shadow behind the surface.
  final List<BoxShadow>? boxShadow;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final radius = borderRadius;

    Widget surface = BackdropFilter(
      filter: ImageFilter.blur(sigmaX: blurSigma, sigmaY: blurSigma),
      child: DecoratedBox(
        position: DecorationPosition.background,
        decoration: BoxDecoration(color: AppGlass.tintOn(scheme)),
        child: DecoratedBox(
          position: DecorationPosition.foreground,
          decoration: BoxDecoration(border: border, borderRadius: radius),
          child: child,
        ),
      ),
    );

    if (radius != null) {
      surface = ClipRRect(borderRadius: radius, child: surface);
    }

    return DecoratedBox(
      position: DecorationPosition.background,
      decoration: BoxDecoration(borderRadius: radius, boxShadow: boxShadow),
      child: surface,
    );
  }
}
```

- [ ] **Step 6: Run the tests and the analyzer**

Run: `flutter test test/app_glass_test.dart test/glass_surface_test.dart && flutter analyze`
Expected: PASS (4 + 1 tests), no analyzer issues.

- [ ] **Step 7: Commit**

```bash
git add lib/app/theme/app_tokens.dart lib/shared/glass_surface.dart test/app_glass_test.dart test/glass_surface_test.dart
git commit -m "feat: add the GlassSurface widget and AppGlass tokens"
```

---

### Task 2: Make the bottom navigation bar transparent

**Files:**
- Modify: `lib/app/theme/app_theme.dart`
- Test: `test/app_theme_test.dart`

**Interfaces:**
- Consumes: nothing.
- Produces: `navigationBarTheme.backgroundColor == Colors.transparent` (so the glass behind it shows through) — used by Task 4.

- [ ] **Step 1: Write the failing test**

Add to `test/app_theme_test.dart` inside `main()`:

```dart
  test('the bottom navigation bar is transparent so glass can show through', () {
    for (final theme in [AppTheme.light(seed), AppTheme.dark(seed)]) {
      expect(theme.navigationBarTheme.backgroundColor, Colors.transparent);
    }
  });
```

- [ ] **Step 2: Run the test to verify it fails**

Run: `flutter test test/app_theme_test.dart`
Expected: FAIL — `backgroundColor` is `null`.

- [ ] **Step 3: Implement**

In `lib/app/theme/app_theme.dart`, add `backgroundColor: Colors.transparent` to the `navigationBarTheme`:

```dart
      navigationBarTheme: NavigationBarThemeData(
        // Transparent so the shared GlassSurface behind it provides the
        // frosted material instead of an opaque bar.
        backgroundColor: Colors.transparent,
        indicatorShape: const StadiumBorder(),
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
```

- [ ] **Step 4: Run the test to verify it passes**

Run: `flutter test test/app_theme_test.dart && flutter analyze`
Expected: PASS, no analyzer issues.

- [ ] **Step 5: Commit**

```bash
git add lib/app/theme/app_theme.dart test/app_theme_test.dart
git commit -m "style: make the bottom navigation bar transparent"
```

---

### Task 3: Mini player uses `GlassSurface`

**Files:**
- Modify: `lib/features/player/mini_player_bar.dart`
- Test: `test/mini_player_bar_test.dart`

**Interfaces:**
- Consumes: `GlassSurface`, `AppGlass.shadow` (Task 1).
- Produces: nothing new.

- [ ] **Step 1: Update the failing test**

In `test/mini_player_bar_test.dart`, swap the `AppSurface` import for the glass one:

```dart
import 'package:flind_player/shared/glass_surface.dart';
```

Replace the `'renders as a floating rounded capsule'` test with:

```dart
  testWidgets('renders as a floating glass capsule', (tester) async {
    final state = PlaybackState(
      isPlaying: false,
      isBuffering: false,
      isCompleted: false,
      position: Duration.zero,
      currentTrack: _track('Capsule Test'),
    );

    await tester.pumpWidget(_app(state: state));
    await tester.pumpAndSettle();

    final glass = tester.widget<GlassSurface>(
      find.descendant(
        of: find.byType(MiniPlayerBar),
        matching: find.byType(GlassSurface),
      ),
    );
    expect(glass.borderRadius, BorderRadius.circular(AppRadius.xl));
    expect(
      find.descendant(
        of: find.byType(MiniPlayerBar),
        matching: find.byType(BackdropFilter),
      ),
      findsOneWidget,
    );
  });
```

- [ ] **Step 2: Run the test to verify it fails**

Run: `flutter test test/mini_player_bar_test.dart`
Expected: FAIL — still an `AppSurface`, no `GlassSurface`/`BackdropFilter`.

- [ ] **Step 3: Implement**

In `lib/features/player/mini_player_bar.dart`, replace the import:

```dart
import 'package:flind_player/shared/app_surface.dart';
```

with:

```dart
import 'package:flind_player/shared/glass_surface.dart';
```

Replace the `return Padding(... DecoratedBox(... AppSurface(...)))` block with (the progress line, `InkWell`, cover, title/artist and controls are unchanged):

```dart
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.sm,
        0,
        AppSpacing.sm,
        AppSpacing.sm,
      ),
      child: GlassSurface(
        borderRadius: BorderRadius.circular(AppRadius.xl),
        boxShadow: AppGlass.shadow,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Thin progress line at the very top.
            if (durationMs > 0)
              LinearProgressIndicator(value: progress, minHeight: 2),
            InkWell(
              key: barKey,
              onTap: () => Navigator.of(context).push(playerRoute(context)),
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
    );
```

- [ ] **Step 4: Run the tests to verify they pass**

Run: `flutter test test/mini_player_bar_test.dart`
Expected: PASS — including `renders nothing when currentTrack is null` and the cover/progress tests.

- [ ] **Step 5: Run the analyzer**

Run: `flutter analyze`
Expected: no issues.

- [ ] **Step 6: Commit**

```bash
git add lib/features/player/mini_player_bar.dart test/mini_player_bar_test.dart
git commit -m "style: render the mini player as a glass capsule"
```

---

### Task 4: Compact shell — `extendBody` + glass nav bar

**Files:**
- Modify: `lib/features/home/home_shell.dart`
- Test: `test/home_shell_test.dart`

**Interfaces:**
- Consumes: `GlassSurface`, `AppGlass.topEdgeOn` (Task 1); transparent nav bar (Task 2).
- Produces: nothing new.

- [ ] **Step 1: Replace the shell-overlay test with the compact assertion**

In `test/home_shell_test.dart`, swap the `AppSurface` import for the glass one:

```dart
import 'package:flind_player/shared/glass_surface.dart';
```

Replace the whole `'the mini player sits below the content with a distinct surface'` group with:

```dart
  group('the glass chrome overlays the content', () {
    testWidgets('compact: extendBody and a glass bottom chrome', (tester) async {
      tester.view.physicalSize = const Size(400, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(_app(playback: _playingState()));
      await tester.pumpAndSettle();

      final scaffold = tester.widget<Scaffold>(
        find
            .ancestor(
              of: find.byType(NavigationBar),
              matching: find.byType(Scaffold),
            )
            .first,
      );
      expect(scaffold.extendBody, isTrue);
      expect(
        find.ancestor(
          of: find.byType(NavigationBar),
          matching: find.byType(GlassSurface),
        ),
        findsOneWidget,
      );
      expect(
        find.ancestor(
          of: find.byKey(MiniPlayerBar.barKey),
          matching: find.byType(GlassSurface),
        ),
        findsOneWidget,
      );
      // The body extends behind the bottom chrome, so the glass has content
      // to blur.
      final content = tester.getRect(find.byType(IndexedStack));
      final bar = tester.getRect(find.byKey(MiniPlayerBar.barKey));
      expect(content.bottom, greaterThanOrEqualTo(bar.bottom - 0.5));
    });
  });
```

- [ ] **Step 2: Run the test to verify it fails**

Run: `flutter test test/home_shell_test.dart`
Expected: FAIL — `extendBody` is false and the nav bar is not wrapped in a `GlassSurface`.

- [ ] **Step 3: Implement**

In `lib/features/home/home_shell.dart`, add the imports:

```dart
import 'package:flind_player/app/theme/app_tokens.dart';
import 'package:flind_player/shared/glass_surface.dart';
```

Replace the compact `return Scaffold(...)` with:

```dart
        final scheme = Theme.of(context).colorScheme;
        return Scaffold(
          backgroundColor: AppSurface.colorOf(context),
          // The list extends behind the bottom chrome so the frosted bars blur
          // it instead of sitting on a flat background.
          extendBody: true,
          body: IndexedStack(index: _selectedIndex, children: _screens),
          bottomNavigationBar: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const MiniPlayerBar(),
              GlassSurface(
                border: AppGlass.topEdgeOn(scheme),
                child: NavigationBar(
                  labelBehavior:
                      NavigationDestinationLabelBehavior.onlyShowSelected,
                  selectedIndex: _selectedIndex,
                  onDestinationSelected: _onDestinationSelected,
                  destinations: _destinations(l10n),
                ),
              ),
            ],
          ),
        );
```

- [ ] **Step 4: Run the tests to verify they pass**

Run: `flutter test test/home_shell_test.dart`
Expected: PASS.

- [ ] **Step 5: Run the analyzer**

Run: `flutter analyze`
Expected: no issues.

- [ ] **Step 6: Commit**

```bash
git add lib/features/home/home_shell.dart test/home_shell_test.dart
git commit -m "style: float the compact bottom chrome over glass"
```

---

### Task 5: Wide shell — overlay the glass mini bar

**Files:**
- Modify: `lib/features/home/home_shell.dart`
- Test: `test/home_shell_test.dart`

**Interfaces:**
- Consumes: `GlassSurface` (Task 1); the existing `MiniPlayerBar`.
- Produces: nothing new.

- [ ] **Step 1: Write the failing test**

In `test/home_shell_test.dart`, add this test inside the `'the glass chrome overlays the content'` group:

```dart
    testWidgets('wide: the mini bar overlays the content and reserves height', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(1200, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(_app(playback: _playingState()));
      await tester.pumpAndSettle();

      final content = tester.getRect(find.byType(IndexedStack));
      final bar = tester.getRect(find.byKey(MiniPlayerBar.barKey));
      expect(bar.overlaps(content), isTrue);
      expect(
        find.ancestor(
          of: find.byKey(MiniPlayerBar.barKey),
          matching: find.byType(GlassSurface),
        ),
        findsOneWidget,
      );
      // The content reserves the bar's height, so its last row stays reachable.
      final inset = MediaQuery.of(
        tester.element(find.byType(IndexedStack)),
      ).padding.bottom;
      expect(inset, greaterThan(0));
    });

    testWidgets('wide: idle reserves no space for the mini bar', (tester) async {
      tester.view.physicalSize = const Size(1200, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      // Default playback state is idle (no track).
      await tester.pumpWidget(_app());
      await tester.pumpAndSettle();

      final inset = MediaQuery.of(
        tester.element(find.byType(IndexedStack)),
      ).padding.bottom;
      expect(inset, 0);
    });
```

- [ ] **Step 2: Run the test to verify it fails**

Run: `flutter test test/home_shell_test.dart`
Expected: FAIL — in the wide layout the mini bar is below the content (no overlap) and there is no inset.

- [ ] **Step 3: Implement the measurement state**

In `_HomeShellState`, add:

```dart
  /// Key on the wide-layout mini player so its height can be measured after
  /// layout and reserved as the content's bottom inset.
  final GlobalKey _miniPlayerKey = GlobalKey();

  /// Measured height of the wide-layout mini player (0 when nothing plays).
  double _miniPlayerHeight = 0;

  /// Measures the wide-layout mini player once it has laid out so the content
  /// behind it can reserve exactly its height as a bottom inset.
  void _measureMiniPlayer() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final box = _miniPlayerKey.currentContext?.findRenderObject() as RenderBox?;
      final height = box?.size.height ?? 0;
      if ((height - _miniPlayerHeight).abs() > 0.5) {
        setState(() => _miniPlayerHeight = height);
      }
    });
  }
```

Call `_measureMiniPlayer();` at the top of `build`, next to `final l10n = ...`.

- [ ] **Step 4: Implement the wide overlay**

Replace the `if (!compact) { return Scaffold(...); }` block with:

```dart
        if (!compact) {
          return Scaffold(
            backgroundColor: AppSurface.colorOf(context),
            body: SafeArea(
              child: Row(
                children: [
                  NavigationRail(
                    selectedIndex: _selectedIndex,
                    onDestinationSelected: _onDestinationSelected,
                    // Like the compact NavigationBar: only the selected
                    // destination shows its label.
                    labelType: NavigationRailLabelType.selected,
                    destinations: _railDestinations(l10n),
                  ),
                  Expanded(
                    child: Stack(
                      children: [
                        Positioned.fill(
                          child: Builder(
                            builder: (context) => MediaQuery(
                              data: MediaQuery.of(context).copyWith(
                                padding: MediaQuery.of(context).padding
                                    .copyWith(
                                      bottom:
                                          MediaQuery.of(context).padding.bottom +
                                          _miniPlayerHeight,
                                    ),
                              ),
                              child: IndexedStack(
                                index: _selectedIndex,
                                children: _screens,
                              ),
                            ),
                          ),
                        ),
                        Positioned(
                          left: 0,
                          right: 0,
                          bottom: 0,
                          child: KeyedSubtree(
                            key: _miniPlayerKey,
                            child: const MiniPlayerBar(),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          );
        }
```

- [ ] **Step 5: Run the tests to verify they pass**

Run: `flutter test test/home_shell_test.dart`
Expected: PASS — both the compact and wide tests.

- [ ] **Step 6: Run the analyzer and the full suite**

Run: `flutter analyze && flutter test`
Expected: analyzer clean; the whole suite passes (baseline 850 + the new tests).

- [ ] **Step 7: Commit**

```bash
git add lib/features/home/home_shell.dart test/home_shell_test.dart
git commit -m "style: overlay the glass mini player in the wide layout"
```

---

## Final Verification

- [ ] `flutter analyze` — no issues.
- [ ] `flutter test` — all tests pass.
- [ ] Manual eyeball (required; not automatable): open the app, play a track, and confirm the nav bar + mini bar read as frosted glass with the list scrolling behind them; check a long list can still reach its last row on both narrow and wide windows; check light and dark themes for legible text over the glass.

## Self-Review Notes

- **Spec coverage:** §3.1 `GlassSurface` → Task 1; §3.2 `AppGlass` → Task 1; §3.3 mini bar → Task 3; §3.4 nav bar glass/transparent → Tasks 2/4; §3.5 geometry → Tasks 4/5; §5 tests → spread across tasks.
- **Deviation recorded:** `AppGlass` lives in `app_tokens.dart` as specced; its import there changes from `animation`+`foundation` to `material` (verified: material provides `@immutable`, `Curves`, `ColorScheme`, `BoxShadow`; `ImageFilter` still needs `dart:ui`).
- **Type consistency:** `GlassSurface.child/borderRadius/blurSigma/border/boxShadow`, `AppGlass.blurSigma/tintOn/topEdgeOn/shadow`, and `MiniPlayerBar.barKey` are named identically across producers and consumers.
