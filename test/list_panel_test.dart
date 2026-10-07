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
