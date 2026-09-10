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

import 'package:flind_player/core/models/playback_state.dart';
import 'package:flind_player/core/models/track.dart';
import 'package:flind_player/core/sources/source_track_id.dart';
import 'package:flind_player/data/providers/library_providers.dart';
import 'package:flind_player/data/providers/playback_providers.dart';
import 'package:flind_player/features/library/library_screen.dart';

Track _track(String title, {String? artist, Duration? duration}) {
  final path = '/music/$title.mp3';
  return Track(
    source: 'local',
    sourceTrackId: LocalTrackId(path),
    uri: 'local:$path',
    title: title,
    artist: artist,
    duration: duration,
  );
}

/// Pumps [LibraryScreen] with both providers overridden.
///
/// `playbackStateProvider` must be overridden too: the screen watches it to
/// highlight the playing row, and the real provider would construct the
/// just_audio-backed controller, which cannot run under `flutter test`.
Widget _app(List<Track> tracks) {
  return ProviderScope(
    overrides: [
      libraryTracksProvider.overrideWith((ref) => Stream.value(tracks)),
      playbackStateProvider.overrideWith(
        (ref) => Stream.value(PlaybackState.idle),
      ),
    ],
    child: const MaterialApp(home: LibraryScreen()),
  );
}

void main() {
  testWidgets('renders tracks from the library', (tester) async {
    await tester.pumpWidget(
      _app([
        _track(
          'Alpha',
          artist: 'Artist A',
          duration: const Duration(seconds: 65),
        ),
        _track('Beta', duration: const Duration(seconds: 125)),
      ]),
    );
    await tester.pumpAndSettle();

    expect(find.text('Alpha'), findsOneWidget);
    expect(find.text('Beta'), findsOneWidget);
    expect(find.text('Artist A'), findsOneWidget);
    expect(find.text('未知艺术家'), findsOneWidget);
    expect(find.text('1:05'), findsOneWidget);
    expect(find.text('2:05'), findsOneWidget);
    expect(find.text('曲库还是空的'), findsNothing);
  });

  testWidgets('renders the empty state when the library is empty', (
    tester,
  ) async {
    await tester.pumpWidget(_app(const <Track>[]));
    await tester.pumpAndSettle();

    expect(find.text('曲库还是空的'), findsOneWidget);
    expect(find.text('导入本地音乐'), findsOneWidget);
    expect(find.byType(ListView), findsNothing);
  });
}
