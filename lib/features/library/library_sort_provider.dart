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

import 'package:flind_player/core/models/track_sort.dart';
import 'package:flind_player/data/providers/cache_providers.dart';

/// Persisted library sort order.
///
/// Reads the current value from [SettingsRepository.librarySort] on first
/// access and writes back on every change. The provider is an
/// [AsyncNotifierProvider] so downstream providers can `watch` it reactively.
class LibrarySortNotifier extends AsyncNotifier<TrackSort> {
  @override
  Future<TrackSort> build() async {
    final repo = ref.watch(settingsRepositoryProvider);
    return repo.librarySort();
  }

  /// Persists and emits [sort].
  Future<void> setSort(TrackSort sort) async {
    final repo = ref.read(settingsRepositoryProvider);
    await repo.setLibrarySort(sort);
    state = AsyncData(sort);
  }
}

/// The user's chosen library sort order, persisted across restarts.
final librarySortProvider =
    AsyncNotifierProvider<LibrarySortNotifier, TrackSort>(
      LibrarySortNotifier.new,
    );
