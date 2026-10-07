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
