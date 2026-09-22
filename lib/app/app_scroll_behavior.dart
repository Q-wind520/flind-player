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

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

/// Scroll behaviour that also lets the **mouse** and **trackpad** drag
/// scrollables, not just touch.
///
/// Flutter's default [MaterialScrollBehavior] omits [PointerDeviceKind.mouse]
/// from [dragDevices], so on Windows/Linux/macOS a horizontal pager (such as
/// the library's three-section `PageView`) simply cannot be swiped with a
/// mouse — only the wheel, a trackpad pan, or Shift+wheel would move it. Adding
/// the pointer kinds below restores pointer-drag on desktop so the pager feels
/// the same there as it does on touch.
///
/// On touch-only devices this is a no-op: those pointer kinds are never
/// emitted, so the default touch behaviour is unchanged.
///
/// The same approach (a `MaterialScrollBehavior` subclass whose `dragDevices`
/// includes mouse/trackpad) is what the reference client PiliPlus does in its
/// `CustomScrollBehavior`; unlike PiliPlus this deliberately does **not** patch
/// the Flutter SDK — no custom drag recognizer is needed, because the only
/// thing missing on desktop is the pointer-kind permission.
///
/// Deliberately **not** overridden here: [buildScrollbar] and
/// [buildOverscrollIndicator]. PiliPlus strips scrollbars on desktop, but that
/// is a look-and-feel decision affecting every scrollable in the app, so this
/// behaviour stays limited to pointer kinds.
class AppScrollBehavior extends MaterialScrollBehavior {
  /// Creates the app-wide scroll behaviour.
  const AppScrollBehavior();

  @override
  Set<PointerDeviceKind> get dragDevices => const <PointerDeviceKind>{
    PointerDeviceKind.touch,
    PointerDeviceKind.mouse,
    PointerDeviceKind.trackpad,
    PointerDeviceKind.stylus,
    PointerDeviceKind.invertedStylus,
    PointerDeviceKind.unknown,
  };
}
