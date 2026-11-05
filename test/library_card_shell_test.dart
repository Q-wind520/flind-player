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
import 'package:flind_player/features/library/widgets/track_list_items.dart';

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
      body: Center(child: SizedBox(width: 240, height: 320, child: child)),
    ),
  ),
);

BoxDecoration _surface(WidgetTester tester) =>
    tester.widget<AnimatedContainer>(find.byType(AnimatedContainer)).decoration!
        as BoxDecoration;

void main() {
  testWidgets('a playing card shows the now-playing pill', (tester) async {
    await tester.pumpWidget(
      _app(
        child: TrackCard(track: _track(), isPlaying: true, onTap: () {}),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('正在播放'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('hover lifts the card surface', (tester) async {
    await tester.pumpWidget(
      _app(
        child: TrackCard(track: _track(), isPlaying: false, onTap: () {}),
      ),
    );
    await tester.pumpAndSettle();

    final before = _surface(tester).color;
    final gesture = await tester.createGesture(kind: PointerDeviceKind.mouse);
    await gesture.addPointer(location: Offset.zero);
    addTearDown(gesture.removePointer);

    await gesture.moveTo(tester.getCenter(find.byType(TrackCard)));
    await tester.pumpAndSettle();

    expect(_surface(tester).color, isNot(before));
  });

  testWidgets('an unavailable card ignores taps', (tester) async {
    var taps = 0;
    await tester.pumpWidget(
      _app(
        child: TrackCard(
          track: _track(),
          isPlaying: false,
          unavailable: true,
          onTap: () => taps++,
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byType(TrackCard));
    expect(taps, 0);
  });
}
