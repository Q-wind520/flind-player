// Flind Player - cross-platform music player
// Copyright (C) 2026 top.qwind.app
//
// This program is free software: you can redistribute it and/or modify
// it under the terms of the GNU General Public License as published by
// the Free Software Foundation, version 3 of the License.

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:flind_player/core/models/library_view.dart';
import 'package:flind_player/data/providers/settings_repository_provider.dart';

/// Persisted per-scope library views, seeded from [SettingsRepository].
class LibraryViewsNotifier extends AsyncNotifier<LibraryViews> {
  @override
  Future<LibraryViews> build() async {
    return ref.watch(settingsRepositoryProvider).libraryViews();
  }

  /// Persists [view] for [scope] and emits the updated set.
  Future<void> setView(LibraryViewScope scope, LibraryView view) async {
    final repository = ref.read(settingsRepositoryProvider);
    final sanitized = scope.sanitize(view);
    await repository.setLibraryView(scope, sanitized);
    final current = state.value ?? LibraryViews.defaults;
    state = AsyncData(current.withView(scope, sanitized));
  }
}

/// The user's chosen view for every library scope.
final libraryViewsProvider =
    AsyncNotifierProvider<LibraryViewsNotifier, LibraryViews>(
      LibraryViewsNotifier.new,
    );
