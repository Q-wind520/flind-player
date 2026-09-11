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
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:flind_player/core/models/playback_state.dart';
import 'package:flind_player/core/repositories/settings_repository.dart';
import 'package:flind_player/core/models/track.dart';
import 'package:flind_player/data/cache/audio_cache_store.dart';
import 'package:flind_player/data/cache/download_manager.dart';
import 'package:flind_player/data/providers/cache_providers.dart';
import 'package:flind_player/data/providers/library_providers.dart';
import 'package:flind_player/data/providers/playback_providers.dart';
import 'package:flind_player/data/services/library_sync_service.dart';
import 'package:flind_player/features/home/home_shell.dart';
import 'package:flind_player/features/library/widgets/cache_action_button.dart';
import 'package:flind_player/features/search/search_providers.dart';
import 'package:flind_player/features/settings/settings_providers.dart';

/// In-memory [SettingsRepository] that satisfies the settings screen.
class _FakeSettingsRepository implements SettingsRepository {
  _FakeSettingsRepository(this.current);

  CacheSettings current;

  @override
  Future<CacheSettings> cacheSettings() async => current;

  @override
  Future<void> updateCacheSettings(CacheSettings settings) async {
    current = settings;
  }

  @override
  Stream<CacheSettings> watchCacheSettings() async* {
    yield current;
  }

  Future<void> dispose() async {}
}

/// [AudioCacheStore] stand-in that never touches a database or filesystem.
class _FakeCacheStore implements AudioCacheStore {
  @override
  Future<void> clear() async {}

  @override
  Future<void> remove(int id) async {}

  @override
  Future<List<CachedAudio>> entries() async => const <CachedAudio>[];

  @override
  Future<int> totalBytes() async => 0;

  @override
  Future<CachedAudio?> lookup(String source, String sourceTrackId) async =>
      null;

  @override
  Future<void> touch(int id) async {}

  @override
  Future<void> setPinned(int id, bool pinned) async {}

  @override
  Future<CachedAudio> insert({
    required String source,
    required String sourceTrackId,
    required String filePath,
    required int bytes,
    required String qualityId,
    required bool pinned,
  }) async => throw UnimplementedError();

  @override
  Future<EvictionResult> ensureSpace(int incomingBytes) async =>
      const EvictionResult(evictedCount: 0, freedBytes: 0, hasSpace: true);

  @override
  Future<IntegrityReport> checkIntegrity() async =>
      const IntegrityReport(rowsRemoved: 0, orphansRemoved: 0);

  @override
  File fileFor({
    required String source,
    required String sourceTrackId,
    required String extension,
  }) => throw UnimplementedError();
}

/// Pumps [HomeShell] with all providers overridden so no real database,
/// network, controller or sync service is constructed.
Widget _app() {
  final settings = _FakeSettingsRepository(CacheSettings.defaults);
  final store = _FakeCacheStore();

  return ProviderScope(
    overrides: [
      // Playback.
      playbackStateProvider.overrideWith(
        (ref) => Stream.value(PlaybackState.idle),
      ),
      // Library.
      libraryTracksProvider.overrideWith((ref) => Stream.value(<Track>[])),
      librarySyncStateProvider.overrideWith(
        (ref) => Stream.value(LibrarySyncState.idle),
      ),
      downloadProgressProvider.overrideWith(
        (ref) => const Stream<DownloadProgress>.empty(),
      ),
      audioCacheEntryProvider.overrideWith((ref, track) async => null),
      // Search (not used initially, but overrides needed if the search
      // screen is pumped).
      biliSearchResultsProvider.overrideWith((ref, query) async => <Track>[]),
      // Settings.
      settingsRepositoryProvider.overrideWith((ref) => settings),
      audioCacheStoreProvider.overrideWith((ref) => store),
      audioCacheUsageProvider.overrideWith((ref) async => 0),
      audioCacheEntryCountProvider.overrideWith((ref) async => 0),
    ],
    child: const MaterialApp(home: HomeShell()),
  );
}

void main() {
  testWidgets('renders three destinations with correct labels', (tester) async {
    await tester.pumpWidget(_app());
    await tester.pumpAndSettle();

    expect(find.text('首页'), findsOneWidget);
    expect(find.text('曲库'), findsOneWidget);
    expect(find.text('账户'), findsOneWidget);

    // The old navigation destinations are gone. The SearchScreen's AppBar
    // still says "搜索", but it should not appear as a nav destination label.
    expect(find.text('设置'), findsNothing);
    expect(find.text('正在播放'), findsNothing);
    // Verify no old nav icons remain.
    expect(find.byIcon(Icons.play_circle_outline), findsNothing);
    expect(find.byIcon(Icons.settings_outlined), findsNothing);
  });

  testWidgets('tapping 曲库 shows the library screen', (tester) async {
    await tester.pumpWidget(_app());
    await tester.pumpAndSettle();

    // Default is 首页 (SearchScreen) which shows the search hint.
    expect(find.text('搜索 Bilibili 上的音乐'), findsOneWidget);

    // Tap 曲库.
    await tester.tap(find.text('曲库'));
    await tester.pumpAndSettle();

    // LibraryScreen shows the empty library message.
    expect(find.text('曲库还是空的'), findsOneWidget);
  });

  testWidgets('tapping 账户 shows the settings screen', (tester) async {
    await tester.pumpWidget(_app());
    await tester.pumpAndSettle();

    await tester.tap(find.text('账户'));
    await tester.pumpAndSettle();

    // SettingsScreen shows the cache settings.
    expect(find.text('启用缓存'), findsOneWidget);
  });

  testWidgets('does not have 正在播放 in navigation', (tester) async {
    await tester.pumpWidget(_app());
    await tester.pumpAndSettle();

    // Verify no NavigationDestination with 正在播放 label exists.
    expect(find.text('正在播放'), findsNothing);
    expect(find.byIcon(Icons.play_circle_outline), findsNothing);
  });
}
