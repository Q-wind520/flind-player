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

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:flind_player/core/models/lyric.dart';
import 'package:flind_player/core/models/playback_state.dart';
import 'package:flind_player/core/models/track.dart';
import 'package:flind_player/core/sources/source_track_id.dart';
import 'package:flind_player/data/providers/lyrics_providers.dart';
import 'package:flind_player/data/providers/playback_providers.dart';
import 'package:flind_player/features/player/lyrics_view.dart';

import 'support/l10n.dart';

const _track = Track(
  source: 'netease',
  sourceTrackId: NeteaseTrackId(songId: 1),
  uri: 'netease:1',
  title: 'T',
);

const _lyric = Lyric(<LyricLine>[
  LyricLine(timestamp: Duration(seconds: 1), text: 'First', translation: '第一'),
  LyricLine(timestamp: Duration(seconds: 5), text: 'Second'),
]);

/// A track from a source without a lyrics provider (`local` is not even an
/// online source), used to cover the "source not adapted" placeholder.
const _localTrack = Track(
  source: 'local',
  sourceTrackId: LocalTrackId('/music/test.mp3'),
  uri: 'local:/music/test.mp3',
  title: 'L',
);

Widget _app({
  required Lyric? lyric,
  Duration position = const Duration(seconds: 2),
  Track? track = _track,
  Widget body = const LyricsView(),
}) {
  return ProviderScope(
    overrides: [
      trackLyricsProvider.overrideWith((ref, _) async => lyric),
      playbackStateProvider.overrideWith(
        (ref) => Stream.value(
          PlaybackState(
            isPlaying: true,
            isBuffering: false,
            isCompleted: false,
            position: position,
            currentTrack: track,
          ),
        ),
      ),
    ],
    child: localizedApp(Scaffold(body: body)),
  );
}

void main() {
  testWidgets('highlight the current line and render its translation', (tester) async {
    await tester.pumpWidget(_app(lyric: _lyric, position: const Duration(seconds: 2)));
    await tester.pumpAndSettle();

    expect(find.text('First'), findsOneWidget);
    expect(find.text('第一'), findsOneWidget);
    final current = tester.widget<Container>(
      find.byKey(const ValueKey<String>('lyric-current')),
    );
    expect(current, isNotNull);
    expect(find.text('First'), findsOneWidget);
  });

  testWidgets('advances the highlight with the position', (tester) async {
    await tester.pumpWidget(_app(lyric: _lyric, position: const Duration(seconds: 6)));
    await tester.pumpAndSettle();
    expect(find.text('Second'), findsOneWidget);
    expect(
      find.descendant(
        of: find.byKey(const ValueKey<String>('lyric-current')),
        matching: find.text('Second'),
      ),
      findsOneWidget,
    );
  });

  testWidgets('shows the no-lyrics placeholder when the lyric is null', (tester) async {
    await tester.pumpWidget(_app(lyric: null));
    await tester.pumpAndSettle();
    expect(find.text('暂无歌词'), findsOneWidget);
  });

  testWidgets('shows the source hint when nothing is playing', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          playbackStateProvider.overrideWith(
            (ref) => Stream.value(PlaybackState.idle),
          ),
        ],
        child: localizedApp(const Scaffold(body: LyricsView())),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('词莫见，敬聆听'), findsOneWidget);
    expect(find.text('该音源暂未适配歌词'), findsOneWidget);
    expect(find.text('暂无歌词'), findsNothing);
  });

  testWidgets('shows the source hint for a source without lyrics support', (
    tester,
  ) async {
    await tester.pumpWidget(_app(lyric: null, track: _localTrack));
    await tester.pumpAndSettle();
    expect(find.text('词莫见，敬聆听'), findsOneWidget);
    expect(find.text('该音源暂未适配歌词'), findsOneWidget);
    expect(find.text('暂无歌词'), findsNothing);
  });

  testWidgets('renders the current line and its translation in the preview', (
    tester,
  ) async {
    await tester.pumpWidget(
      _app(
        lyric: _lyric,
        position: const Duration(seconds: 2),
        body: const SizedBox(height: 120, child: LyricsPreview()),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('First'), findsOneWidget);
    expect(find.text('第一'), findsOneWidget);
    expect(
      find.descendant(
        of: find.byKey(const ValueKey<String>('lyric-current')),
        matching: find.text('First'),
      ),
      findsOneWidget,
    );
  });
}
