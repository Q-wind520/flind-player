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
import 'package:flind_player/core/repositories/favorites_repository.dart';
import 'package:flind_player/core/sources/source_track_id.dart';
import 'package:flind_player/data/cache/download_manager.dart';
import 'package:flind_player/data/providers/cache_providers.dart';
import 'package:flind_player/data/providers/persistence_providers.dart';
import 'package:flind_player/data/providers/playback_providers.dart';
import 'package:flind_player/data/sources/bilibili/bili_client.dart';
import 'package:flind_player/features/library/widgets/cache_action_button.dart';
import 'package:flind_player/features/search/search_providers.dart';
import 'package:flind_player/features/search/search_screen.dart';

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

/// In-memory [FavoritesRepository] for tests.
///
/// Each subscriber to [watchFavorites] receives the current state immediately,
/// then live updates.
class _InMemoryFavoritesRepository implements FavoritesRepository {
  final _favourites = <String, Track>{};
  final List<StreamController<List<Track>>> _listeners = [];

  @override
  Stream<List<Track>> watchFavorites() async* {
    yield _favourites.values.toList();
    final controller = StreamController<List<Track>>();
    _listeners.add(controller);
    yield* controller.stream;
    // ignore: use_key_synchronously
    controller.onCancel = () => _listeners.remove(controller);
  }

  @override
  Future<List<Track>> allFavorites() async => _favourites.values.toList();

  @override
  Future<bool> isFavorite(String uri) async => _favourites.containsKey(uri);

  @override
  Future<void> addFavorite(Track track) async {
    _favourites[track.uri] = track;
    _notify();
  }

  @override
  Future<void> removeFavorite(String uri) async {
    _favourites.remove(uri);
    _notify();
  }

  @override
  Future<void> updateFavoriteCover(
    String uri, {
    String? coverPath,
    String? coverUrl,
  }) async {}

  @override
  Future<bool> toggleFavorite(Track track) async {
    if (_favourites.containsKey(track.uri)) {
      _favourites.remove(track.uri);
      _notify();
      return false;
    } else {
      _favourites[track.uri] = track;
      _notify();
      return true;
    }
  }

  void _notify() {
    final value = _favourites.values.toList();
    for (final c in _listeners) {
      if (!c.isClosed) c.add(value);
    }
  }

  void dispose() {
    for (final c in _listeners) {
      c.close();
    }
    _listeners.clear();
  }
}

/// Pumps [SearchScreen] with the search family, playback state and
/// favourites providers overridden.
///
/// Overriding [biliSearchResultsProvider] keeps the test offline; overriding
/// [playbackStateProvider] prevents the real just_audio-backed controller from
/// being constructed (the screen watches it to highlight the playing row).
Widget _app({
  required FutureOr<List<Track>> Function(Ref ref, String query) search,
}) {
  final favRepo = _InMemoryFavoritesRepository();
  return ProviderScope(
    overrides: [
      biliSearchResultsProvider.overrideWith(search),
      playbackStateProvider.overrideWith(
        (ref) => Stream.value(PlaybackState.idle),
      ),
      downloadProgressProvider.overrideWith(
        (ref) => const Stream<DownloadProgress>.empty(),
      ),
      audioCacheEntryProvider.overrideWith((ref, track) async => null),
      favoritesRepositoryProvider.overrideWithValue(favRepo),
      favoritesProvider.overrideWith((ref) => favRepo.watchFavorites()),
    ],
    child: localizedApp(const SearchScreen()),
  );
}

Future<void> _submitQuery(WidgetTester tester, String query) async {
  await tester.enterText(find.byType(TextField), query);
  await tester.testTextInput.receiveAction(TextInputAction.search);
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('renders search results after submitting a query', (
    tester,
  ) async {
    await tester.pumpWidget(
      _app(
        search: (ref, query) async => <Track>[
          _track(
            'Alpha',
            artist: 'UP主 A',
            duration: const Duration(seconds: 65),
          ),
          _track('Beta', duration: const Duration(seconds: 125)),
        ],
      ),
    );

    expect(find.text('搜索 Bilibili 上的音乐'), findsOneWidget);

    await _submitQuery(tester, '周杰伦');

    expect(find.text('Alpha'), findsOneWidget);
    expect(find.text('Beta'), findsOneWidget);
    expect(find.text('UP主 A'), findsOneWidget);
    expect(find.text('未知UP主'), findsOneWidget);
    expect(find.text('1:05'), findsOneWidget);
    expect(find.text('2:05'), findsOneWidget);
  });

  testWidgets('renders the empty state when a search returns no results', (
    tester,
  ) async {
    await tester.pumpWidget(_app(search: (ref, query) async => <Track>[]));

    await _submitQuery(tester, '不存在的东西');

    expect(find.text('没有找到结果'), findsOneWidget);
    expect(find.byType(ListView), findsNothing);
  });

  testWidgets('renders an error panel when the source throws', (tester) async {
    await tester.pumpWidget(
      _app(
        search: (ref, query) => Future<List<Track>>.error(StateError('网络错误')),
      ),
    );

    await _submitQuery(tester, '周杰伦');

    expect(find.text('搜索失败'), findsOneWidget);
    expect(find.textContaining('网络错误'), findsOneWidget);
  });

  testWidgets('shows a rate-limit hint for Bilibili error -412', (
    tester,
  ) async {
    await tester.pumpWidget(
      _app(
        search: (ref, query) => Future<List<Track>>.error(
          const BiliApiException(-412, 'Bilibili blocked this IP (code: -412)'),
        ),
      ),
    );

    await _submitQuery(tester, '周杰伦');

    expect(find.text('请求过于频繁，请稍后再试'), findsOneWidget);
    expect(find.textContaining('-412'), findsNothing);
  });

  testWidgets('does not overflow at 400 px width', (tester) async {
    tester.view.physicalSize = const Size(400, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      _app(
        search: (ref, query) async => <Track>[
          _track(
            '一个非常非常长的歌曲标题用来验证在窄屏下会被省略号截断',
            artist: '一个同样非常长的UP主名称',
            duration: const Duration(minutes: 12, seconds: 34),
          ),
        ],
      ),
    );

    await _submitQuery(tester, '周杰伦');

    expect(find.text('一个非常非常长的歌曲标题用来验证在窄屏下会被省略号截断'), findsOneWidget);
  });
}
