import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_staggered_grid_view/flutter_staggered_grid_view.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:flind_player/core/models/library_view.dart';
import 'package:flind_player/core/models/track.dart';
import 'package:flind_player/core/sources/source_track_id.dart';
import 'package:flind_player/data/providers/persistence_providers.dart';
import 'package:flind_player/features/library/widgets/cache_action_button.dart';
import 'package:flind_player/features/library/widgets/track_list_items.dart';
import 'package:flind_player/features/library/widgets/track_view.dart';

import 'support/l10n.dart';

Track _track(int i) => Track(
  id: i,
  source: 'local',
  sourceTrackId: LocalTrackId('/music/$i.mp3'),
  uri: 'local:/music/$i.mp3',
  title: 'Song $i',
);

/// Rows/cards embed `TrackActionsButton`, which watches favourites + cache.
Widget _wrap(Widget child) => ProviderScope(
  overrides: [
    isFavoriteProvider.overrideWith((ref, uri) async => false),
    audioCacheEntryProvider.overrideWith((ref, track) async => null),
  ],
  child: localizedApp(Scaffold(body: child)),
);

void main() {
  testWidgets('list view renders TrackTile rows', (tester) async {
    await tester.pumpWidget(
      _wrap(
        TrackView(
          tracks: [_track(1), _track(2)],
          view: LibraryView.list,
          currentUri: null,
          isPlaying: false,
          onPlay: (_) {},
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byType(TrackTile), findsNWidgets(2));
    expect(find.byType(TrackCard), findsNothing);
    expect(find.byType(MasonryGridView), findsNothing);
  });

  testWidgets('showcase view renders TrackCard grid', (tester) async {
    await tester.pumpWidget(
      _wrap(
        TrackView(
          tracks: [_track(1), _track(2)],
          view: LibraryView.showcase,
          currentUri: null,
          isPlaying: false,
          onPlay: (_) {},
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byType(TrackCard), findsNWidgets(2));
    expect(find.byType(TrackTile), findsNothing);
  });

  testWidgets('waterfall view renders a MasonryGridView', (tester) async {
    await tester.pumpWidget(
      _wrap(
        TrackView(
          tracks: [_track(1), _track(2)],
          view: LibraryView.waterfall,
          currentUri: null,
          isPlaying: false,
          onPlay: (_) {},
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byType(MasonryGridView), findsOneWidget);
  });

  testWidgets('onPlay reports the tapped index', (tester) async {
    final played = <int>[];
    await tester.pumpWidget(
      _wrap(
        TrackView(
          tracks: [_track(1), _track(2)],
          view: LibraryView.list,
          currentUri: null,
          isPlaying: false,
          onPlay: played.add,
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Song 2'));
    expect(played, [1]);
  });
}
