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
import 'package:flutter_test/flutter_test.dart';

import 'package:flind_player/shared/empty_state.dart';

import 'support/l10n.dart';

void main() {
  testWidgets('renders icon, title, message and action', (tester) async {
    await tester.pumpWidget(
      localizedApp(
        Scaffold(
          body: EmptyState(
            icon: Icons.search,
            title: '标题',
            message: '说明',
            action: const Text('操作'),
          ),
        ),
      ),
    );

    expect(find.byIcon(Icons.search), findsOneWidget);
    expect(find.text('标题'), findsOneWidget);
    expect(find.text('说明'), findsOneWidget);
    expect(find.text('操作'), findsOneWidget);
  });

  testWidgets('omits message and action when absent', (tester) async {
    await tester.pumpWidget(
      localizedApp(
        const Scaffold(
          body: EmptyState(icon: Icons.search, title: '仅标题'),
        ),
      ),
    );

    // Only the title renders; no message, no action.
    expect(find.byType(Text), findsOneWidget);
    expect(find.text('仅标题'), findsOneWidget);
  });
}
