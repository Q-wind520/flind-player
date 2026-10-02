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

import 'package:flind_player/core/repositories/settings_repository.dart';
import 'package:flind_player/data/repositories/prefs_settings_repository.dart';

/// Persisted user settings across cache, library and appearance domains.
///
/// Kept out of `cache_providers.dart` so appearance, language and library
/// consumers depend on the settings surface alone, not the whole cache data
/// graph (`dart:io`, `path_provider`, Bilibili, downloads).
final settingsRepositoryProvider = Provider<SettingsRepository>((ref) {
  final repository = PrefsSettingsRepository();
  ref.onDispose(repository.dispose);
  return repository;
});
