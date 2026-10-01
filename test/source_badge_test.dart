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

import 'package:flind_player/features/library/widgets/track_list_items.dart';

import 'support/l10n.dart';

void main() {
  testWidgets('SourceBadge renders the localized netease label', (tester) async {
    await tester.pumpWidget(
      localizedApp(const Scaffold(body: SourceBadge(source: 'netease'))),
    );

    expect(find.text('网易云'), findsOneWidget);
  });

  testWidgets('SourceBadge keeps the existing local and bilibili labels', (
    tester,
  ) async {
    await tester.pumpWidget(
      localizedApp(
        const Scaffold(
          body: Row(
            children: [
              SourceBadge(source: 'local'),
              SourceBadge(source: 'bilibili'),
            ],
          ),
        ),
      ),
    );

    expect(find.text('本地'), findsOneWidget);
    expect(find.text('B站'), findsOneWidget);
  });
}
