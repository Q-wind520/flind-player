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

import 'package:flind_player/core/models/track.dart';
import 'package:flind_player/core/repositories/favorites_repository.dart';
import 'package:flind_player/core/repositories/music_library_repository.dart';
import 'package:flind_player/core/sources/music_source.dart';
import 'package:flind_player/core/sources/source_track_id.dart';
import 'package:flind_player/data/cache/audio_cache_store.dart';
import 'package:flind_player/data/cache/download_manager.dart';
import 'package:flind_player/data/providers/cache_providers.dart';
import 'package:flind_player/data/providers/database_providers.dart';
import 'package:flind_player/data/providers/persistence_providers.dart';
import 'package:flind_player/features/library/widgets/cache_action_button.dart';
import 'package:flind_player/features/library/widgets/track_actions_button.dart';

import 'support/l10n.dart';

Track _track([String title = 'Online Song']) {
  final bvid = 'BV_$title';
  return Track(
    source: 'bilibili',
    sourceTrackId: BiliTrackId(bvid: bvid, cid: -1),
    uri: 'bilibili:$bvid:-1',
    title: title,
  );
}

CachedAudio _cached(Track track, {required bool pinned}) => CachedAudio(
  id: 1,
  source: track.source,
  sourceTrackId: 'BV_$track:-1',
  filePath: '/cache/audio.m4a',
  bytes: 1024,
  qualityId: 'q',
  pinned: pinned,
  cachedAt: DateTime(2026),
  lastAccessedAt: DateTime(2026),
  coverBytes: 0,
);

/// Minimal [FavoritesRepository]; [TrackActionsButton] only reads favourites.
class _FakeFavorites implements FavoritesRepository {
  @override
  Stream<List<Track>> watchFavorites() => Stream.value(const <Track>[]);

  @override
  Future<bool> isFavorite(String uri) async => false;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

/// Records [upsertTrack] calls and answers [findByUri] from its in-memory map.
class _FakeLibraryRepository implements MusicLibraryRepository {
  final Map<String, Track> tracks = <String, Track>{};
  final List<Track> upserted = <Track>[];

  @override
  Future<Track?> findByUri(String uri) async => tracks[uri];

  @override
  Future<int> upsertTrack(Track track) async {
    upserted.add(track);
    tracks[track.uri] = track;
    return 1;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

/// Captures [cacheTrack] calls without touching the network or disk.
class _RecordingDownloadManager implements DownloadManager {
  final List<(Track, bool)> calls = <(Track, bool)>[];

  @override
  Future<void> cacheTrack(
    Track track, {
    bool pinned = false,
    StreamInfo? knownInfo,
  }) async {
    calls.add((track, pinned));
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

Widget _app({
  required Track track,
  required _RecordingDownloadManager manager,
  required _FakeLibraryRepository library,
  CachedAudio? entry,
}) {
  final favorites = _FakeFavorites();
  return ProviderScope(
    overrides: [
      audioCacheEntryProvider.overrideWith((ref, t) async => entry),
      downloadManagerProvider.overrideWithValue(manager),
      musicLibraryRepositoryProvider.overrideWithValue(library),
      favoritesRepositoryProvider.overrideWithValue(favorites),
      favoritesProvider.overrideWith((ref) => favorites.watchFavorites()),
    ],
    child: localizedApp(
      Scaffold(
        body: Center(child: TrackActionsButton(track: track)),
      ),
    ),
  );
}

Future<void> _openMenu(WidgetTester tester) async {
  await tester.tap(find.byType(TrackActionsButton));
  await tester.pumpAndSettle();
}

PopupMenuItem<dynamic> _menuItemFor(WidgetTester tester, String label) {
  return tester.widget<PopupMenuItem<dynamic>>(
    find.ancestor(
      of: find.text(label),
      matching: find.byWidgetPredicate((widget) => widget is PopupMenuItem),
    ),
  );
}

void main() {
  testWidgets('uncached track offers an enabled 离线缓存 item', (tester) async {
    final track = _track();
    await tester.pumpWidget(
      _app(
        track: track,
        manager: _RecordingDownloadManager(),
        library: _FakeLibraryRepository(),
      ),
    );
    await tester.pumpAndSettle();
    await _openMenu(tester);

    expect(find.text('离线缓存'), findsOneWidget);
    expect(find.text('已缓存'), findsNothing);
    expect(_menuItemFor(tester, '离线缓存').enabled, isTrue);
  });

  testWidgets('online-cached (unpinned) track still offers 离线缓存', (
    tester,
  ) async {
    final track = _track();
    await tester.pumpWidget(
      _app(
        track: track,
        manager: _RecordingDownloadManager(),
        library: _FakeLibraryRepository(),
        entry: _cached(track, pinned: false),
      ),
    );
    await tester.pumpAndSettle();
    await _openMenu(tester);

    // The play-through online cache must not masquerade as an offline download.
    expect(find.text('离线缓存'), findsOneWidget);
    expect(find.text('已缓存'), findsNothing);
    expect(_menuItemFor(tester, '离线缓存').enabled, isTrue);
  });

  testWidgets('offline-cached (pinned) track shows a disabled 已缓存 item', (
    tester,
  ) async {
    final track = _track();
    await tester.pumpWidget(
      _app(
        track: track,
        manager: _RecordingDownloadManager(),
        library: _FakeLibraryRepository(),
        entry: _cached(track, pinned: true),
      ),
    );
    await tester.pumpAndSettle();
    await _openMenu(tester);

    expect(find.text('已缓存'), findsOneWidget);
    expect(find.text('离线缓存'), findsNothing);
    expect(_menuItemFor(tester, '已缓存').enabled, isFalse);
  });

  testWidgets(
    'offline-caching a track outside the library adds it to the library',
    (tester) async {
      final track = _track();
      final manager = _RecordingDownloadManager();
      final library = _FakeLibraryRepository();
      await tester.pumpWidget(
        _app(track: track, manager: manager, library: library),
      );
      await tester.pumpAndSettle();
      await _openMenu(tester);

      await tester.tap(find.text('离线缓存'));
      await tester.pumpAndSettle();

      expect(library.upserted, [track]);
      expect(manager.calls, [(track, true)]);
      expect(find.text('已存入曲库：Online Song'), findsOneWidget);
    },
  );

  testWidgets(
    'offline-caching a track already in the library does not re-add it',
    (tester) async {
      final track = _track();
      final manager = _RecordingDownloadManager();
      final library = _FakeLibraryRepository()..tracks[track.uri] = track;
      await tester.pumpWidget(
        _app(track: track, manager: manager, library: library),
      );
      await tester.pumpAndSettle();
      await _openMenu(tester);

      await tester.tap(find.text('离线缓存'));
      await tester.pumpAndSettle();

      expect(library.upserted, isEmpty);
      expect(manager.calls, [(track, true)]);
      expect(find.textContaining('已存入曲库'), findsNothing);
    },
  );
}
