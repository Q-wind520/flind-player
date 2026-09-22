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
import 'package:flutter_test/flutter_test.dart';

import 'package:flind_player/app/app_scroll_behavior.dart';

void main() {
  group('AppScrollBehavior', () {
    test('allows mouse and trackpad dragging, not only touch', () {
      const behavior = AppScrollBehavior();

      expect(behavior.dragDevices, contains(PointerDeviceKind.touch));
      expect(behavior.dragDevices, contains(PointerDeviceKind.mouse));
      expect(behavior.dragDevices, contains(PointerDeviceKind.trackpad));
      expect(behavior.dragDevices, contains(PointerDeviceKind.stylus));
    });
  });

  group('mouse dragging a horizontal pager', () {
    testWidgets('pages when the app opts into AppScrollBehavior', (
      tester,
    ) async {
      await tester.pumpWidget(_pagerApp(const AppScrollBehavior()));
      await tester.pumpAndSettle();
      expect(find.text('page-0'), findsOneWidget);

      final dragged = await _mouseDragLeft(tester);

      // The drag was accepted at all...
      expect(
        dragged,
        greaterThan(0),
        reason: 'a mouse drag should move the pager',
      );
      // ...and it settled on the next page.
      expect(find.text('page-1'), findsOneWidget);
      expect(find.text('page-0'), findsNothing);
    });

    testWidgets('does nothing with the framework default behaviour', (
      tester,
    ) async {
      await tester.pumpWidget(_pagerApp(null));
      await tester.pumpAndSettle();
      expect(find.text('page-0'), findsOneWidget);

      final dragged = await _mouseDragLeft(tester);

      expect(
        dragged,
        0,
        reason: 'the default behaviour must ignore mouse drags — this is the '
            'gap AppScrollBehavior exists to close',
      );
      expect(find.text('page-0'), findsOneWidget);
      expect(find.text('page-1'), findsNothing);
    });
  });
}

/// A two-page horizontal pager under a [MaterialApp] using [behavior].
///
/// Passing `null` exercises Flutter's stock [MaterialScrollBehavior].
Widget _pagerApp(ScrollBehavior? behavior) => MaterialApp(
  scrollBehavior: behavior,
  home: PageView(
    children: const <Widget>[
      Center(child: Text('page-0')),
      Center(child: Text('page-1')),
    ],
  ),
);

/// Drags the pager leftwards with a **mouse** pointer and releases.
///
/// Returns how far the scroll position had travelled *before* the release, so
/// the caller can assert that the mouse drag was recognised at all (which is
/// independent of the snap-to-page heuristic).
Future<double> _mouseDragLeft(WidgetTester tester) async {
  final scrollable = find.byType(Scrollable);
  final gesture = await tester.startGesture(
    tester.getCenter(scrollable),
    kind: PointerDeviceKind.mouse,
  );

  // Several steps so the recogniser wins the arena and the position tracks.
  for (var i = 0; i < 5; i++) {
    await gesture.moveBy(const Offset(-100, 0));
    await tester.pump();
  }

  final dragged = tester.state<ScrollableState>(scrollable).position.pixels;
  await gesture.up();
  await tester.pumpAndSettle();
  return dragged;
}
