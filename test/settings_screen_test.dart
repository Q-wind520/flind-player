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

import 'package:flind_player/core/repositories/settings_repository.dart';
import 'package:flind_player/data/cache/audio_cache_store.dart';
import 'package:flind_player/data/providers/cache_providers.dart';
import 'package:flind_player/features/settings/settings_providers.dart';
import 'package:flind_player/features/settings/settings_screen.dart';

/// In-memory [SettingsRepository] that records writes and replays them through
/// its watch stream.
class _FakeSettingsRepository implements SettingsRepository {
  _FakeSettingsRepository(this.current);

  CacheSettings current;
  final List<CacheSettings> writes = <CacheSettings>[];
  final StreamController<CacheSettings> _updates =
      StreamController<CacheSettings>.broadcast();

  @override
  Future<CacheSettings> cacheSettings() async => current;

  @override
  Future<void> updateCacheSettings(CacheSettings settings) async {
    current = settings;
    writes.add(settings);
    _updates.add(settings);
  }

  @override
  Stream<CacheSettings> watchCacheSettings() async* {
    yield current;
    yield* _updates.stream;
  }

  Future<void> dispose() => _updates.close();
}

/// [AudioCacheStore] stand-in that records destructive calls and never touches
/// a database or the filesystem.
class _FakeCacheStore implements AudioCacheStore {
  int clearCalls = 0;
  int removeCalls = 0;

  @override
  Future<void> clear() async {
    clearCalls++;
  }

  @override
  Future<void> remove(int id) async {
    removeCalls++;
  }

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

/// Pumps [SettingsScreen] with the settings repository, cache store, usage and
/// entry count overridden so no database, download manager or platform channel
/// is ever constructed.
Widget _app({
  required _FakeSettingsRepository settings,
  required _FakeCacheStore store,
  int usageBytes = 0,
  int trackCount = 0,
}) {
  return ProviderScope(
    overrides: [
      settingsRepositoryProvider.overrideWith((ref) => settings),
      audioCacheStoreProvider.overrideWith((ref) => store),
      audioCacheUsageProvider.overrideWith((ref) async => usageBytes),
      audioCacheEntryCountProvider.overrideWith((ref) async => trackCount),
    ],
    child: const MaterialApp(home: SettingsScreen()),
  );
}

void main() {
  testWidgets('renders the cache switches, chips and usage', (tester) async {
    final settings = _FakeSettingsRepository(CacheSettings.defaults);
    final store = _FakeCacheStore();
    addTearDown(settings.dispose);

    await tester.pumpWidget(
      _app(
        settings: settings,
        store: store,
        usageBytes: 300 * 1024 * 1024,
        trackCount: 3,
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('启用缓存'), findsOneWidget);
    expect(find.text('播放时自动缓存'), findsOneWidget);
    expect(find.text('256 MB'), findsOneWidget);
    expect(find.text('512 MB'), findsOneWidget);
    expect(find.text('1 GB'), findsWidgets); // chip plus current value
    expect(find.text('2 GB'), findsOneWidget);
    expect(find.text('5 GB'), findsOneWidget);
    expect(find.text('300 MB / 1 GB'), findsOneWidget);
    expect(find.text('已缓存 3 首'), findsOneWidget);
    expect(find.byType(LinearProgressIndicator), findsOneWidget);
    expect(find.text('清空缓存'), findsOneWidget);
  });

  testWidgets('toggling 启用缓存 persists enabled: false', (tester) async {
    final settings = _FakeSettingsRepository(CacheSettings.defaults);
    final store = _FakeCacheStore();
    addTearDown(settings.dispose);

    await tester.pumpWidget(_app(settings: settings, store: store));
    await tester.pumpAndSettle();

    await tester.tap(find.text('启用缓存'));
    await tester.pumpAndSettle();

    expect(settings.writes, isNotEmpty);
    expect(settings.current.enabled, isFalse);
    expect(settings.current.limitBytes, CacheSettings.defaults.limitBytes);
  });

  testWidgets('selecting a chip persists the new limit', (tester) async {
    final settings = _FakeSettingsRepository(CacheSettings.defaults);
    final store = _FakeCacheStore();
    addTearDown(settings.dispose);

    await tester.pumpWidget(_app(settings: settings, store: store));
    await tester.pumpAndSettle();

    await tester.tap(find.text('256 MB'));
    await tester.pumpAndSettle();

    expect(settings.current.limitBytes, 256 * 1024 * 1024);
    expect(settings.current.enabled, isTrue);
  });

  testWidgets('清空缓存 asks for confirmation before clearing', (tester) async {
    final settings = _FakeSettingsRepository(CacheSettings.defaults);
    final store = _FakeCacheStore();
    addTearDown(settings.dispose);

    await tester.pumpWidget(
      _app(
        settings: settings,
        store: store,
        usageBytes: 300 * 1024 * 1024,
        trackCount: 3,
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('清空缓存'));
    await tester.pumpAndSettle();

    expect(find.text('清空缓存？'), findsOneWidget);
    expect(store.clearCalls, 0);

    await tester.tap(find.text('取消'));
    await tester.pumpAndSettle();

    expect(store.clearCalls, 0);
    expect(find.text('清空缓存？'), findsNothing);

    await tester.tap(find.text('清空缓存'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('清空'));
    await tester.pumpAndSettle();

    expect(store.clearCalls, 1);
    expect(find.textContaining('已清空缓存'), findsOneWidget);
    expect(find.textContaining('300 MB'), findsWidgets);
  });
}
