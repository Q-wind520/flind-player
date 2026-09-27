import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:flind_player/core/models/track.dart';
import 'package:flind_player/core/sources/source_track_id.dart';
import 'package:flind_player/data/providers/persistence_providers.dart';
import 'package:flind_player/features/library/cover_aspect_ratio_provider.dart';
import 'package:flind_player/features/library/widgets/cache_action_button.dart';
import 'package:flind_player/features/library/widgets/waterfall_track_card.dart';

import 'support/l10n.dart';

Track _track({String? coverPath}) => Track(
  id: 1,
  source: 'local',
  sourceTrackId: LocalTrackId('/music/a.mp3'),
  uri: 'local:/music/a.mp3',
  title: 'Alpha',
  artist: 'Artist A',
  coverPath: coverPath,
);

/// Pumps one card. The card embeds `TrackActionsButton`, which watches
/// favourites + cache, so both are overridden; [ratio] pins the cover ratio.
Widget _app({required Track track, double? ratio}) => ProviderScope(
  overrides: [
    isFavoriteProvider.overrideWith((ref, uri) async => false),
    audioCacheEntryProvider.overrideWith((ref, track) async => null),
    if (ratio != null)
      coverAspectRatioProvider.overrideWith((ref, key) async => ratio),
  ],
  child: localizedApp(
    Scaffold(
      body: SizedBox(
        width: 200,
        child: WaterfallTrackCard(
          track: track,
          isCurrent: false,
          isPlaying: false,
          onTap: () {},
        ),
      ),
    ),
  ),
);

void main() {
  testWidgets('cover height follows the resolved aspect ratio', (tester) async {
    await tester.pumpWidget(
      _app(track: _track(coverPath: '/covers/a.jpg'), ratio: 0.5),
    );
    await tester.pumpAndSettle();

    expect(find.byType(AspectRatio), findsOneWidget);
    final aspect = tester.widget<AspectRatio>(find.byType(AspectRatio));
    expect(aspect.aspectRatio, 0.5);
  });

  testWidgets('an unresolvable cover falls back to 1:1 without throwing', (
    tester,
  ) async {
    await tester.pumpWidget(_app(track: _track(coverPath: '/missing/never.jpg')));
    await tester.pumpAndSettle();

    final aspect = tester.widget<AspectRatio>(find.byType(AspectRatio));
    expect(aspect.aspectRatio, 1.0);
    expect(tester.takeException(), isNull);
  });
}
