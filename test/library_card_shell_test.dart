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
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:flind_player/core/models/track.dart';
import 'package:flind_player/core/sources/source_track_id.dart';
import 'package:flind_player/data/providers/persistence_providers.dart';
import 'package:flind_player/features/library/widgets/cache_action_button.dart';
import 'package:flind_player/features/library/widgets/library_card_shell.dart';
import 'package:flind_player/features/library/widgets/track_actions_button.dart';
import 'package:flind_player/features/library/widgets/track_list_items.dart';
import 'package:flind_player/features/library/widgets/waterfall_track_card.dart';

import 'support/l10n.dart';

Track _track() => Track(
  id: 1,
  source: 'local',
  sourceTrackId: LocalTrackId('/music/a.mp3'),
  uri: 'local:/music/a.mp3',
  title: 'Alpha',
  artist: 'Artist A',
);

Widget _app({required Widget child}) => ProviderScope(
  overrides: [
    isFavoriteProvider.overrideWith((ref, uri) async => false),
    audioCacheEntryProvider.overrideWith((ref, track) async => null),
  ],
  child: localizedApp(
    Scaffold(
      body: SingleChildScrollView(
        child: Center(child: SizedBox(width: 240, child: child)),
      ),
    ),
  ),
);

BoxDecoration _surface(WidgetTester tester) =>
    tester.widget<AnimatedContainer>(find.byType(AnimatedContainer)).decoration!
        as BoxDecoration;

void main() {
  testWidgets('a playing card shows only the equalizer badge', (tester) async {
    await tester.pumpWidget(
      _app(
        child: WaterfallTrackCard(
          track: _track(),
          isPlaying: true,
          onTap: () {},
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byType(NowPlayingBadge), findsOneWidget);
    expect(find.text('正在播放'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('hover lifts the card surface', (tester) async {
    await tester.pumpWidget(
      _app(
        child: WaterfallTrackCard(
          track: _track(),
          isPlaying: false,
          onTap: () {},
        ),
      ),
    );
    await tester.pumpAndSettle();

    final before = _surface(tester).color;
    final gesture = await tester.createGesture(kind: PointerDeviceKind.mouse);
    await gesture.addPointer(location: Offset.zero);
    addTearDown(gesture.removePointer);

    await gesture.moveTo(tester.getCenter(find.byType(WaterfallTrackCard)));
    await tester.pumpAndSettle();

    expect(_surface(tester).color, isNot(before));
  });

  testWidgets('an unavailable card ignores taps', (tester) async {
    var taps = 0;
    await tester.pumpWidget(
      _app(
        child: WaterfallTrackCard(
          track: _track(),
          isPlaying: false,
          unavailable: true,
          onTap: () => taps++,
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byType(WaterfallTrackCard));
    expect(taps, 0);
  });

  testWidgets('source sits on the cover and actions use a compact row slot', (
    tester,
  ) async {
    await tester.pumpWidget(
      _app(
        child: WaterfallTrackCard(
          track: _track(),
          isPlaying: false,
          onTap: () {},
        ),
      ),
    );
    await tester.pumpAndSettle();

    final source = tester.getRect(find.byType(SourceBadge));
    final title = tester.getRect(find.text('Alpha'));
    final actions = tester.getRect(find.byType(TrackActionsButton));

    expect(source.bottom, lessThan(title.top));
    expect(actions.top, greaterThan(title.top));
    expect(actions.width, lessThanOrEqualTo(32));
    expect(actions.height, lessThanOrEqualTo(32));
    expect(find.text('本地'), findsOneWidget);
  });
}
