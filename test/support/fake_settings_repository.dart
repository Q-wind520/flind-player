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

import 'package:flind_player/core/models/app_language.dart';
import 'package:flind_player/core/models/app_theme_mode.dart';
import 'package:flind_player/core/models/library_view.dart';
import 'package:flind_player/core/models/track_sort.dart';
import 'package:flind_player/core/repositories/settings_repository.dart';

/// Base for settings fakes that supply only the slice a test needs.
///
/// A subclass (or a class mixing in one of the slice mixins below) satisfies
/// [SettingsRepository] without defining the other slices; a call outside the
/// implemented slice throws, surfacing accidental cross-slice use instead of
/// silently returning a default.
class FakeSettingsBase implements SettingsRepository {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

/// In-memory [CacheSettingsRepository]: a mutable [current] value, recorded
/// [writes], and a watch stream that seeds the current value then replays
/// updates.
mixin FakeCacheSettings on FakeSettingsBase implements CacheSettingsRepository {
  /// The currently persisted cache settings.
  CacheSettings current = CacheSettings.defaults;

  /// Every value passed to [updateCacheSettings], in order.
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

  /// Closes the update stream; the fake is unusable afterwards.
  Future<void> dispose() => _updates.close();
}

/// In-memory [AppearanceSettingsRepository].
mixin FakeAppearanceSettings
    on FakeSettingsBase
    implements AppearanceSettingsRepository {
  /// The persisted UI language.
  AppLanguage language = AppLanguage.system;

  /// The persisted app appearance.
  AppThemeMode themeMode = AppThemeMode.system;

  @override
  Future<AppLanguage> appLanguage() async => language;

  @override
  Future<void> setAppLanguage(AppLanguage value) async => language = value;

  @override
  Future<AppThemeMode> appThemeMode() async => themeMode;

  @override
  Future<void> setAppThemeMode(AppThemeMode value) async => themeMode = value;
}

/// In-memory [LibrarySettingsRepository].
mixin FakeLibrarySettings
    on FakeSettingsBase
    implements LibrarySettingsRepository {
  /// The persisted library sort order.
  TrackSort sort = TrackSort.recentlyAdded;

  /// The persisted per-scope library views.
  LibraryViews views = LibraryViews.defaults;

  @override
  Future<TrackSort> librarySort() async => sort;

  @override
  Future<void> setLibrarySort(TrackSort value) async => sort = value;

  @override
  Future<LibraryViews> libraryViews() async => views;

  @override
  Future<void> setLibraryView(LibraryViewScope scope, LibraryView view) async {
    views = views.withView(scope, view);
  }
}

/// Every settings slice in memory; the default settings fake.
///
/// Pass [cache] to start from a persisted cap other than
/// [CacheSettings.defaults].
class FakeSettingsRepository extends FakeSettingsBase
    with FakeCacheSettings, FakeAppearanceSettings, FakeLibrarySettings {
  FakeSettingsRepository([CacheSettings? cache]) {
    if (cache != null) current = cache;
  }
}
