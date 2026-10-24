// Flind Player - cross-platform music player
// Copyright (C) 2026 top.qwind.app
//
// This program is free software: you can redistribute it and/or modify
// it under the terms of the GNU General Public License as published by
// the Free Software Foundation, version 3 of the License.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:flind_player/app/theme/app_theme.dart';
import 'package:flind_player/core/models/track.dart';
import 'package:flind_player/core/sources/source_track_id.dart';
import 'package:flind_player/data/providers/persistence_providers.dart';
import 'package:flind_player/features/library/widgets/cache_action_button.dart';
import 'package:flind_player/features/library/widgets/track_list_items.dart';

import 'support/l10n.dart';

Track _track() => Track(
  source: 'local',
  sourceTrackId: const LocalTrackId('/music/a.mp3'),
  uri: 'local:/music/a.mp3',
  title: 'A',
);

Widget _app({required bool isCurrent}) => ProviderScope(
  overrides: [
    isFavoriteProvider.overrideWith((ref, uri) async => false),
    audioCacheEntryProvider.overrideWith((ref, track) async => null),
  ],
  child: localizedApp(
    Scaffold(
      body: TrackTile(
        track: _track(),
        isCurrent: isCurrent,
        isPlaying: isCurrent,
        onTap: () {},
      ),
    ),
    theme: AppTheme.light(const Color(0xFF1BA784)),
  ),
);

Color? _rowColor(WidgetTester tester) {
  final material = tester.widget<Material>(
    find
        .descendant(of: find.byType(TrackTile), matching: find.byType(Material))
        .first,
  );
  return material.color;
}

void main() {
  testWidgets('the current row is tinted with the playing-row colour', (
    tester,
  ) async {
    await tester.pumpWidget(_app(isCurrent: true));
    await tester.pumpAndSettle();

    final scheme = Theme.of(tester.element(find.byType(TrackTile))).colorScheme;
    expect(_rowColor(tester), AppTheme.playingRowTint(scheme));
  });

  testWidgets('a non-current row paints no tint', (tester) async {
    await tester.pumpWidget(_app(isCurrent: false));
    await tester.pumpAndSettle();

    expect(_rowColor(tester), Colors.transparent);
  });

  testWidgets('the tint fades out when the row stops being current', (
    tester,
  ) async {
    await tester.pumpWidget(_app(isCurrent: true));
    await tester.pumpAndSettle();

    await tester.pumpWidget(_app(isCurrent: false));
    await tester.pump(const Duration(milliseconds: 125));

    final alpha = _rowColor(tester)!.a;
    expect(alpha, greaterThan(0));
    expect(alpha, lessThan(AppTheme.playingRowTintAlpha));

    await tester.pumpAndSettle();
    expect(_rowColor(tester), Colors.transparent);
  });
}
