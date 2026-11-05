import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_staggered_grid_view/flutter_staggered_grid_view.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:flind_player/core/models/library_view.dart';
import 'package:flind_player/core/models/track.dart';
import 'package:flind_player/core/sources/source_track_id.dart';
import 'package:flind_player/data/providers/persistence_providers.dart';
import 'package:flind_player/features/library/widgets/cache_action_button.dart';
import 'package:flind_player/features/library/widgets/library_card_shell.dart';
import 'package:flind_player/features/library/widgets/track_list_items.dart';
import 'package:flind_player/features/library/widgets/track_view.dart';
import 'package:flind_player/features/library/widgets/waterfall_track_card.dart';

import 'support/l10n.dart';

Track _track(int i, {Duration? duration}) => Track(
  id: i,
  source: 'local',
  sourceTrackId: LocalTrackId('/music/$i.mp3'),
  uri: 'local:/music/$i.mp3',
  title: 'Song $i',
  duration: duration,
);

/// Rows/cards embed `TrackActionsButton`, which watches favourites + cache.
Widget _wrap(Widget child) => ProviderScope(
  overrides: [
    isFavoriteProvider.overrideWith((ref, uri) async => false),
    audioCacheEntryProvider.overrideWith((ref, track) async => null),
  ],
  child: localizedApp(Scaffold(body: child)),
);

/// Like [_wrap] but with a bottom system inset injected, mirroring what the
/// shell adds for the floating bottom chrome.
Widget _wrapWithBottomInset(Widget child, double bottom) => ProviderScope(
  overrides: [
    isFavoriteProvider.overrideWith((ref, uri) async => false),
    audioCacheEntryProvider.overrideWith((ref, track) async => null),
  ],
  child: localizedApp(
    Scaffold(
      body: MediaQuery(
        data: MediaQueryData(padding: EdgeInsets.only(bottom: bottom)),
        child: child,
      ),
    ),
  ),
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
    expect(find.byType(MasonryGridView), findsNothing);
    expect(find.byType(WaterfallTrackCard), findsNothing);
  });

  testWidgets('cards view renders masonry track cards', (tester) async {
    await tester.pumpWidget(
      _wrap(
        TrackView(
          tracks: [_track(1), _track(2)],
          view: LibraryView.cards,
          currentUri: null,
          isPlaying: false,
          onPlay: (_) {},
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byType(WaterfallTrackCard), findsNWidgets(2));
    expect(find.byType(TrackTile), findsNothing);
  });

  testWidgets('cards do not overflow at 400 px', (tester) async {
    await tester.binding.setSurfaceSize(const Size(400, 800));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      _wrap(
        TrackView(
          tracks: <Track>[_track(1), _track(2), _track(3), _track(4)],
          view: LibraryView.cards,
          currentUri: null,
          isPlaying: false,
          onPlay: (_) {},
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
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

  testWidgets('list view is a flat separated list', (tester) async {
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

    expect(find.byType(ListView), findsOneWidget);
    expect(find.byType(Divider), findsOneWidget);
  });

  testWidgets('list playing badge sits on the cover, clear of the duration', (
    tester,
  ) async {
    final track = _track(1, duration: const Duration(minutes: 4));
    await tester.pumpWidget(
      _wrap(
        TrackView(
          tracks: [track],
          view: LibraryView.list,
          currentUri: track.uri,
          isPlaying: true,
          onPlay: (_) {},
        ),
      ),
    );
    await tester.pumpAndSettle();

    final badge = tester.getRect(find.byType(NowPlayingBadge));
    final cover = tester.getRect(find.byType(TrackCover));
    final duration = tester.getRect(find.text('4:00'));

    expect(cover.contains(badge.center), isTrue);
    expect(badge.overlaps(duration), isFalse);
  });

  testWidgets('cards reserves the injected bottom inset', (tester) async {
    await tester.pumpWidget(
      _wrapWithBottomInset(
        TrackView(
          tracks: [_track(1)],
          view: LibraryView.cards,
          currentUri: null,
          isPlaying: false,
          onPlay: (_) {},
        ),
        72,
      ),
    );
    await tester.pumpAndSettle();

    final masonry = tester.widget<MasonryGridView>(
      find.byType(MasonryGridView),
    );
    expect((masonry.padding! as EdgeInsets).bottom, 12 + 72);
  });
}
