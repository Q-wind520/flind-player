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

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:flind_player/core/models/app_theme_color.dart';
import 'package:flind_player/data/providers/settings_repository_provider.dart';

/// Persisted seed colour the whole Material 3 scheme is derived from.
class AppThemeColorNotifier extends AsyncNotifier<AppThemeColor> {
  @override
  Future<AppThemeColor> build() {
    return ref.watch(settingsRepositoryProvider).appThemeColor();
  }

  /// Persists and emits [color].
  Future<void> setThemeColor(AppThemeColor color) async {
    final repository = ref.read(settingsRepositoryProvider);
    await repository.setAppThemeColor(color);
    state = AsyncData(color);
  }
}

/// The user's chosen seed colour, persisted across restarts.
final appThemeColorProvider =
    AsyncNotifierProvider<AppThemeColorNotifier, AppThemeColor>(
      AppThemeColorNotifier.new,
    );
