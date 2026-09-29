import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:flind_player/core/models/app_language.dart';
import 'package:flind_player/core/models/app_theme_mode.dart';
import 'package:flind_player/core/models/library_view.dart';
import 'package:flind_player/core/models/track_sort.dart';
import 'package:flind_player/core/repositories/settings_repository.dart';
import 'package:flind_player/data/providers/settings_repository_provider.dart';
import 'package:flind_player/features/library/library_view_provider.dart';

class _FakeSettings implements SettingsRepository {
  LibraryViews _views = LibraryViews.defaults;

  @override
  Future<LibraryViews> libraryViews() async => _views;

  @override
  Future<void> setLibraryView(LibraryViewScope scope, LibraryView view) async {
    _views = _views.withView(scope, view);
  }

  @override
  Future<CacheSettings> cacheSettings() async => CacheSettings.defaults;
  @override
  Future<void> updateCacheSettings(CacheSettings settings) async {}
  @override
  Stream<CacheSettings> watchCacheSettings() => const Stream.empty();
  @override
  Future<TrackSort> librarySort() async => TrackSort.recentlyAdded;
  @override
  Future<void> setLibrarySort(TrackSort sort) async {}
  @override
  Future<AppLanguage> appLanguage() async => AppLanguage.system;
  @override
  Future<void> setAppLanguage(AppLanguage language) async {}
  @override
  Future<AppThemeMode> appThemeMode() async => AppThemeMode.system;
  @override
  Future<void> setAppThemeMode(AppThemeMode mode) async {}
}

void main() {
  test('build reads the persisted views', () async {
    final container = ProviderContainer(
      overrides: [
        settingsRepositoryProvider.overrideWithValue(_FakeSettings()),
      ],
    );
    addTearDown(container.dispose);

    final views = await container.read(libraryViewsProvider.future);
    expect(views.viewOf(LibraryViewScope.all), LibraryView.waterfall);
  });

  test('setView persists and emits the new value', () async {
    final fake = _FakeSettings();
    final container = ProviderContainer(
      overrides: [settingsRepositoryProvider.overrideWithValue(fake)],
    );
    addTearDown(container.dispose);

    await container.read(libraryViewsProvider.future);
    await container
        .read(libraryViewsProvider.notifier)
        .setView(LibraryViewScope.all, LibraryView.list);

    final views = container.read(libraryViewsProvider).value!;
    expect(views.viewOf(LibraryViewScope.all), LibraryView.list);
  });

  test('setView sanitizes an unsupported choice', () async {
    final container = ProviderContainer(
      overrides: [
        settingsRepositoryProvider.overrideWithValue(_FakeSettings()),
      ],
    );
    addTearDown(container.dispose);

    await container.read(libraryViewsProvider.future);
    await container
        .read(libraryViewsProvider.notifier)
        .setView(LibraryViewScope.playlists, LibraryView.waterfall);

    final views = container.read(libraryViewsProvider).value!;
    expect(views.viewOf(LibraryViewScope.playlists), LibraryView.showcase);
  });
}
