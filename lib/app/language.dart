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

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:flind_player/core/models/app_language.dart';
import 'package:flind_player/data/providers/cache_providers.dart';

/// The [Locale] for [language], or `null` to follow the system locale.
Locale? localeForAppLanguage(AppLanguage language) => switch (language) {
  AppLanguage.system => null,
  AppLanguage.english => const Locale('en'),
  AppLanguage.simplifiedChinese => const Locale('zh'),
};

/// Persisted UI language.
class AppLanguageNotifier extends AsyncNotifier<AppLanguage> {
  @override
  Future<AppLanguage> build() {
    return ref.watch(settingsRepositoryProvider).appLanguage();
  }

  /// Persists and emits [language].
  Future<void> setLanguage(AppLanguage language) async {
    final repository = ref.read(settingsRepositoryProvider);
    await repository.setAppLanguage(language);
    state = AsyncData(language);
  }
}

/// The user's chosen UI language, persisted across restarts.
///
/// `main` awaits [appLanguageProvider.future] before the first frame so a
/// non-system choice never flashes the system language on startup.
final appLanguageProvider =
    AsyncNotifierProvider<AppLanguageNotifier, AppLanguage>(
      AppLanguageNotifier.new,
    );
