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

Widget _app({required Lyric? lyric, Duration position = const Duration(seconds: 2)}) {
  return ProviderScope(
    overrides: [
      trackLyricsProvider.overrideWith((ref, track) async => lyric),
      playbackStateProvider.overrideWith(
        (ref) => Stream.value(
          const PlaybackState(
            isPlaying: true,
            isBuffering: false,
            isCompleted: false,
            position: Duration(seconds: 2),
            currentTrack: _track,
          ).copyWith(position: position),
        ),
      ),
    ],
    child: localizedApp(const Scaffold(body: LyricsView())),
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
  });

  testWidgets('shows the no-lyrics placeholder when the lyric is null', (tester) async {
    await tester.pumpWidget(_app(lyric: null));
    await tester.pumpAndSettle();
    expect(find.text('暂无歌词'), findsOneWidget);
  });
}
