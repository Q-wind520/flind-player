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

import 'package:flind_player/core/models/app_theme_mode.dart';
import 'package:flind_player/data/providers/cache_providers.dart';

/// The [ThemeMode] for [mode], or `null`-free mapping to Flutter's enum.
ThemeMode themeModeForAppThemeMode(AppThemeMode mode) => switch (mode) {
  AppThemeMode.system => ThemeMode.system,
  AppThemeMode.light => ThemeMode.light,
  AppThemeMode.dark => ThemeMode.dark,
};

/// Persisted app appearance.
class AppThemeModeNotifier extends AsyncNotifier<AppThemeMode> {
  @override
  Future<AppThemeMode> build() {
    return ref.watch(settingsRepositoryProvider).appThemeMode();
  }

  /// Persists and emits [mode].
  Future<void> setThemeMode(AppThemeMode mode) async {
    final repository = ref.read(settingsRepositoryProvider);
    await repository.setAppThemeMode(mode);
    state = AsyncData(mode);
  }
}

/// The user's chosen app appearance, persisted across restarts.
final appThemeModeProvider =
    AsyncNotifierProvider<AppThemeModeNotifier, AppThemeMode>(
      AppThemeModeNotifier.new,
    );
