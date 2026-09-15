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

import 'package:flutter/material.dart' hide RepeatMode;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:flind_player/core/models/playback_queue.dart';
import 'package:flind_player/core/models/playback_state.dart';
import 'package:flind_player/core/models/repeat_mode.dart';
import 'package:flind_player/core/models/track.dart';
import 'package:flind_player/core/services/playback_controller.dart';
import 'package:flind_player/core/sources/remote_playlist.dart';
import 'package:flind_player/core/sources/source_track_id.dart';
import 'package:flind_player/data/providers/bilibili_providers.dart';
import 'package:flind_player/data/providers/playback_providers.dart';
import 'package:flind_player/data/sources/bilibili/bili_client.dart';
import 'package:flind_player/features/playlists/bilibili_favorites_screen.dart';

import 'support/l10n.dart';

Track _track(String title, {String? artist, Duration? duration}) {
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

/// Builds a [RemoteTrackPage] with the given tracks and pagination metadata.
RemoteTrackPage _page(
  List<Track> tracks, {
  required int page,
  bool hasMore = false,
  int? totalCount,
}) => RemoteTrackPage(
  tracks: tracks,
  page: page,
  hasMore: hasMore,
  totalCount: totalCount ?? tracks.length,
);

/// A [RemotePlaylistSource] whose responses are supplied by the test.
///
/// Records every page number requested through [playlistTracks] so pagination
/// tests can assert exactly which pages were fetched, in order.
class _FakeRemotePlaylistSource implements RemotePlaylistSource {
  _FakeRemotePlaylistSource({required this.folders, required this.tracks});

  final Future<List<RemotePlaylist>> Function(String userId) folders;
  final Future<RemoteTrackPage> Function(String playlistId, int page) tracks;

  final List<int> requestedPages = <int>[];

  @override
  String get id => 'bilibili';

  @override
  Future<List<RemotePlaylist>> playlistsForUser(String userId) =>
      folders(userId);

  @override
  Future<RemoteTrackPage> playlistTracks(String playlistId, {int page = 1}) {
    requestedPages.add(page);
    return tracks(playlistId, page);
  }
}

/// Records [playQueue] calls so the test can prove the displayed list was used
/// without constructing the real just_audio-backed controller.
class _FakePlaybackController implements PlaybackController {
  PlaybackQueue? lastQueue;
  int? lastIndex;

  @override
  Future<void> playQueue(
    PlaybackQueue queue, {
    int index = 0,
    bool autoPlay = true,
  }) async {
    lastQueue = queue;
    lastIndex = index;
  }

  // Unused members.
  @override
  Stream<PlaybackState> get state => const Stream.empty();
  @override
  PlaybackState get currentState => PlaybackState.idle;
  @override
  PlaybackQueue get queue => PlaybackQueue.empty;
  @override
  Future<void> play() async {}
  @override
  Future<void> pause() async {}
  @override
  Future<void> togglePlayPause() async {}
  @override
  Future<void> next() async {}
  @override
  Future<void> previous() async {}
  @override
  Future<void> seek(Duration position) async {}
  @override
  Future<void> setRepeatMode(RepeatMode mode) async {}
  @override
  Future<void> setShuffle(bool enabled) async {}
  @override
  Future<void> dispose() async {}
}

/// Pumps [BilibiliFavoritesScreen] with a fake remote source and playback
/// controller.
///
/// Overriding [playbackStateProvider] and [playbackControllerProvider] keeps the
/// real just_audio-backed controller from ever being constructed, both when the
/// screen watches the state and when a track is tapped.
Widget _app({
  required RemotePlaylistSource source,
  PlaybackController? controller,
}) {
  return ProviderScope(
    overrides: [
      remotePlaylistSourceProvider.overrideWithValue(source),
      playbackStateProvider.overrideWith(
        (ref) => Stream.value(PlaybackState.idle),
      ),
      playbackControllerProvider.overrideWith(
        (ref) => controller ?? _FakePlaybackController(),
      ),
    ],
    child: localizedApp(const BilibiliFavoritesScreen()),
  );
}

Future<void> _submitUid(WidgetTester tester, String uid) async {
  await tester.enterText(find.byType(TextField), uid);
  await tester.tap(find.text('加载'));
  await tester.pumpAndSettle();
}

Future<void> _openFolder(WidgetTester tester) async {
  await _submitUid(tester, '17340771');
  await tester.tap(find.text('音乐收藏'));
  await tester.pumpAndSettle();
}

const _musicFolder = RemotePlaylist(
  id: '2578744971',
  title: '音乐收藏',
  trackCount: 2,
);

void main() {
  testWidgets('submitting a UID renders the folder list', (tester) async {
    final source = _FakeRemotePlaylistSource(
      folders: (uid) async => <RemotePlaylist>[
        _musicFolder,
        const RemotePlaylist(id: '2306334871', title: '视频', trackCount: 5),
      ],
      tracks: (playlistId, page) async => _page(<Track>[], page: page),
    );

    await tester.pumpWidget(_app(source: source));

    expect(find.text('浏览公开收藏夹'), findsOneWidget);

    await _submitUid(tester, '17340771');

    expect(find.text('音乐收藏'), findsOneWidget);
    expect(find.text('视频'), findsOneWidget);
    expect(find.text('2 个内容'), findsOneWidget);
    expect(find.text('5 个内容'), findsOneWidget);
  });

  testWidgets('tapping a folder renders its tracks', (tester) async {
    final source = _FakeRemotePlaylistSource(
      folders: (uid) async => <RemotePlaylist>[_musicFolder],
      tracks: (playlistId, page) async => _page(<Track>[
        _track('Alpha', artist: 'UP主 A', duration: const Duration(seconds: 65)),
      ], page: page),
    );

    await tester.pumpWidget(_app(source: source));
    await _openFolder(tester);

    expect(find.text('Alpha'), findsOneWidget);
    expect(find.text('UP主 A'), findsOneWidget);
    expect(find.text('1:05'), findsOneWidget);
    // A single-page folder shows no pagination footer.
    expect(find.text('加载更多'), findsNothing);
    expect(find.text('已全部加载'), findsNothing);
  });

  testWidgets('an empty folder renders the empty state', (tester) async {
    final source = _FakeRemotePlaylistSource(
      folders: (uid) async => <RemotePlaylist>[_musicFolder],
      tracks: (playlistId, page) async => _page(<Track>[], page: page),
    );

    await tester.pumpWidget(_app(source: source));
    await _openFolder(tester);

    expect(find.text('没有可播放的视频'), findsOneWidget);
  });

  testWidgets('a source error renders the error panel', (tester) async {
    final source = _FakeRemotePlaylistSource(
      folders: (uid) => Future<List<RemotePlaylist>>.error(StateError('网络错误')),
      tracks: (playlistId, page) async => _page(<Track>[], page: page),
    );

    await tester.pumpWidget(_app(source: source));
    await _submitUid(tester, '17340771');

    expect(find.text('加载失败'), findsOneWidget);
    expect(find.textContaining('网络错误'), findsOneWidget);
  });

  testWidgets('shows a rate-limit hint for Bilibili error -412', (
    tester,
  ) async {
    final source = _FakeRemotePlaylistSource(
      folders: (uid) => Future<List<RemotePlaylist>>.error(
        const BiliApiException(-412, 'Bilibili blocked this IP (code: -412)'),
      ),
      tracks: (playlistId, page) async => _page(<Track>[], page: page),
    );

    await tester.pumpWidget(_app(source: source));
    await _submitUid(tester, '17340771');

    expect(find.text('请求过于频繁，请稍后再试'), findsOneWidget);
    expect(find.textContaining('-412'), findsNothing);
  });

  testWidgets(
    'tapping a track plays the displayed list, not a real controller',
    (tester) async {
      final controller = _FakePlaybackController();
      final tracks = <Track>[
        _track('Alpha'),
        _track('Beta', duration: const Duration(seconds: 125)),
      ];
      final source = _FakeRemotePlaylistSource(
        folders: (uid) async => <RemotePlaylist>[_musicFolder],
        tracks: (playlistId, page) async => _page(tracks, page: page),
      );

      await tester.pumpWidget(_app(source: source, controller: controller));
      await _openFolder(tester);

      await tester.tap(find.text('Beta'));
      await tester.pumpAndSettle();

      expect(controller.lastQueue?.tracks, tracks);
      expect(controller.lastIndex, 1);
    },
  );

  testWidgets('does not overflow at 400 px width', (tester) async {
    tester.view.physicalSize = const Size(400, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final source = _FakeRemotePlaylistSource(
      folders: (uid) async => <RemotePlaylist>[
        const RemotePlaylist(
          id: '1',
          title: '一个非常非常长的收藏夹标题用来验证窄屏下的省略号截断行为',
          trackCount: 12345,
        ),
      ],
      tracks: (playlistId, page) async => _page(<Track>[
        _track(
          '一个非常非常长的歌曲标题用来验证在窄屏下会被省略号截断',
          artist: '一个同样非常长的UP主名称',
          duration: const Duration(minutes: 12, seconds: 34),
        ),
      ], page: page),
    );

    await tester.pumpWidget(_app(source: source));
    await _submitUid(tester, '17340771');
    await tester.tap(find.text('一个非常非常长的收藏夹标题用来验证窄屏下的省略号截断行为'));
    await tester.pumpAndSettle();

    expect(find.text('一个非常非常长的歌曲标题用来验证在窄屏下会被省略号截断'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('shows 加载更多 when the source reports another page', (
    tester,
  ) async {
    final source = _FakeRemotePlaylistSource(
      folders: (uid) async => <RemotePlaylist>[_musicFolder],
      tracks: (playlistId, page) async => _page(
        <Track>[_track('Alpha')],
        page: page,
        hasMore: true,
        totalCount: 2,
      ),
    );

    await tester.pumpWidget(_app(source: source));
    await _openFolder(tester);

    expect(find.text('Alpha'), findsOneWidget);
    expect(find.text('加载更多'), findsOneWidget);
    expect(find.text('已全部加载'), findsNothing);
    expect(source.requestedPages, <int>[1]);
  });

  testWidgets('tapping 加载更多 appends page 2 and hides the button', (
    tester,
  ) async {
    final alpha = _track('Alpha');
    final beta = _track('Beta');
    final source = _FakeRemotePlaylistSource(
      folders: (uid) async => <RemotePlaylist>[_musicFolder],
      tracks: (playlistId, page) async => page == 1
          ? _page(<Track>[alpha], page: 1, hasMore: true, totalCount: 2)
          : _page(<Track>[beta], page: 2, hasMore: false, totalCount: 2),
    );

    await tester.pumpWidget(_app(source: source));
    await _openFolder(tester);

    await tester.tap(find.text('加载更多'));
    await tester.pumpAndSettle();

    expect(find.text('Alpha'), findsOneWidget);
    expect(find.text('Beta'), findsOneWidget);
    expect(find.text('加载更多'), findsNothing);
    expect(find.text('已全部加载'), findsOneWidget);
    expect(source.requestedPages, <int>[1, 2]);
  });

  testWidgets('a page-2 failure shows the error and retries the same page', (
    tester,
  ) async {
    var failNext = true;
    final beta = _track('Beta');
    final source = _FakeRemotePlaylistSource(
      folders: (uid) async => <RemotePlaylist>[_musicFolder],
      tracks: (playlistId, page) async {
        if (page == 1) {
          return _page(
            <Track>[_track('Alpha')],
            page: 1,
            hasMore: true,
            totalCount: 2,
          );
        }
        if (failNext) {
          failNext = false;
          throw StateError('第二页加载失败');
        }
        return _page(<Track>[beta], page: 2, hasMore: false, totalCount: 2);
      },
    );

    await tester.pumpWidget(_app(source: source));
    await _openFolder(tester);

    await tester.tap(find.text('加载更多'));
    await tester.pumpAndSettle();

    expect(find.textContaining('第二页加载失败'), findsOneWidget);
    expect(find.text('加载更多'), findsNothing);
    expect(source.requestedPages, <int>[1, 2]);

    await tester.tap(find.text('重试'));
    await tester.pumpAndSettle();

    expect(find.text('Beta'), findsOneWidget);
    expect(find.textContaining('第二页加载失败'), findsNothing);
    expect(source.requestedPages, <int>[1, 2, 2]);
  });

  testWidgets('playing after two pages queues every loaded track in order', (
    tester,
  ) async {
    final controller = _FakePlaybackController();
    final alpha = _track('Alpha');
    final beta = _track('Beta');
    final source = _FakeRemotePlaylistSource(
      folders: (uid) async => <RemotePlaylist>[_musicFolder],
      tracks: (playlistId, page) async => page == 1
          ? _page(<Track>[alpha], page: 1, hasMore: true, totalCount: 2)
          : _page(<Track>[beta], page: 2, hasMore: false, totalCount: 2),
    );

    await tester.pumpWidget(_app(source: source, controller: controller));
    await _openFolder(tester);

    await tester.tap(find.text('加载更多'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Beta'));
    await tester.pumpAndSettle();

    expect(controller.lastQueue?.tracks, <Track>[alpha, beta]);
    expect(controller.lastIndex, 1);
  });
}
