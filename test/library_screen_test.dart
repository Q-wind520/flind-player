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

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:flind_player/core/models/playback_state.dart';
import 'package:flind_player/core/models/track.dart';
import 'package:flind_player/core/sources/source_track_id.dart';
import 'package:flind_player/data/providers/library_providers.dart';
import 'package:flind_player/data/providers/playback_providers.dart';
import 'package:flind_player/data/services/library_sync_service.dart';
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

Track _biliTrack(String title, {String? artist, Duration? duration}) {
  final bvid = 'BV_$title';
  return Track(
    source: 'bilibili',
    sourceTrackId: BiliTrackId(bvid: bvid, cid: -1),
    uri: 'bilibili:$bvid:-1',
    title: title,
    artist: artist,
    duration: duration,
  );
}

/// Pumps [LibraryScreen] with the library, sync and playback providers
/// overridden.
///
/// `playbackStateProvider` must be overridden: the screen watches it to
/// highlight the playing row, and the real provider would construct the
/// just_audio-backed controller, which cannot run under `flutter test`.
/// `librarySyncStateProvider` is overridden so the real sync service (and its
/// database) is never constructed.
Widget _app({
  List<Track> tracks = const <Track>[],
  LibrarySyncState syncState = LibrarySyncState.idle,
  FutureOr<List<Track>> Function(Ref ref, String query)? search,
}) {
  return ProviderScope(
    overrides: [
      libraryTracksProvider.overrideWith((ref) => Stream.value(tracks)),
      playbackStateProvider.overrideWith(
        (ref) => Stream.value(PlaybackState.idle),
      ),
      librarySyncStateProvider.overrideWith((ref) => Stream.value(syncState)),
      if (search != null) librarySearchProvider.overrideWith(search),
    ],
    child: const MaterialApp(home: LibraryScreen()),
  );
}

void main() {
  testWidgets('renders tracks from the library', (tester) async {
    await tester.pumpWidget(
      _app(
        tracks: [
          _track(
            'Alpha',
            artist: 'Artist A',
            duration: const Duration(seconds: 65),
          ),
          _track('Beta', duration: const Duration(seconds: 125)),
        ],
      ),
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
    await tester.pumpWidget(_app());
    await tester.pumpAndSettle();

    expect(find.text('曲库还是空的'), findsOneWidget);
    expect(find.text('导入本地音乐'), findsOneWidget);
    expect(find.byType(ListView), findsNothing);
  });

  testWidgets('renders local and bilibili tracks with source badges', (
    tester,
  ) async {
    await tester.pumpWidget(
      _app(tracks: [_track('Local Song'), _biliTrack('Online Song')]),
    );
    await tester.pumpAndSettle();

    expect(find.text('Local Song'), findsOneWidget);
    expect(find.text('Online Song'), findsOneWidget);
    expect(find.text('本地'), findsOneWidget);
    expect(find.text('B站'), findsOneWidget);
  });

  testWidgets('typing a query shows search results and hides the full list', (
    tester,
  ) async {
    await tester.pumpWidget(
      _app(
        tracks: [_track('Local Song')],
        search: (ref, query) async =>
            query == 'Hit' ? <Track>[_biliTrack('Search Hit')] : <Track>[],
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Local Song'), findsOneWidget);

    await tester.enterText(find.byType(TextField), 'Hit');
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pumpAndSettle();

    expect(find.text('Search Hit'), findsOneWidget);
    expect(find.text('Local Song'), findsNothing);
  });

  testWidgets('a search with no matches shows the empty-search state', (
    tester,
  ) async {
    await tester.pumpWidget(
      _app(
        tracks: [_track('Local Song')],
        search: (ref, query) async => <Track>[],
      ),
    );
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField), 'nothing');
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pumpAndSettle();

    expect(find.text('没有找到匹配的歌曲'), findsOneWidget);
  });

  testWidgets('shows progress and counts while scanning', (tester) async {
    await tester.pumpWidget(
      _app(
        tracks: [_track('Alpha')],
        syncState: const LibrarySyncState(
          phase: LibrarySyncPhase.scanning,
          discovered: 48,
          processed: 12,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byType(LinearProgressIndicator), findsOneWidget);
    expect(find.text('扫描中 12/48'), findsOneWidget);
  });

  testWidgets('shows the error message when a sync fails', (tester) async {
    await tester.pumpWidget(
      _app(
        tracks: [_track('Alpha')],
        syncState: LibrarySyncState(
          phase: LibrarySyncPhase.failed,
          error: StateError('扫描目录不可读'),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.textContaining('扫描目录不可读'), findsOneWidget);
    expect(find.byType(LinearProgressIndicator), findsNothing);
  });

  testWidgets('does not overflow at 400 px width', (tester) async {
    tester.view.physicalSize = const Size(400, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      _app(
        tracks: [
          _track(
            '一个非常非常长的歌曲标题用来验证在窄屏下会被省略号截断',
            artist: '一个同样非常长的艺术家名称',
            duration: const Duration(minutes: 12, seconds: 34),
          ),
          _biliTrack('另一个很长的在线歌曲标题同样需要被截断', artist: '一个很长的UP主名称'),
        ],
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('一个非常非常长的歌曲标题用来验证在窄屏下会被省略号截断'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
