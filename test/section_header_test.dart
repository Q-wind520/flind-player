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

import 'package:flind_player/shared/section_header.dart';

import 'support/l10n.dart';

void main() {
  testWidgets('renders the title in the muted role colour', (tester) async {
    await tester.pumpWidget(
      localizedApp(const Scaffold(body: SectionHeader('曲库'))),
    );

    final text = tester.widget<Text>(find.text('曲库'));
    final context = tester.element(find.text('曲库'));
    expect(text.style?.color, Theme.of(context).colorScheme.onSurfaceVariant);
  });

  testWidgets('renders a trailing action', (tester) async {
    await tester.pumpWidget(
      localizedApp(
        const Scaffold(body: SectionHeader('曲库', trailing: Icon(Icons.add))),
      ),
    );

    expect(find.byIcon(Icons.add), findsOneWidget);
  });
}
