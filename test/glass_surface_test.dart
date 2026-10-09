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
