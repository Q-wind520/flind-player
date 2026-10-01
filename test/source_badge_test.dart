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
