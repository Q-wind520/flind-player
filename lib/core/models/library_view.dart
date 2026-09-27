// Flind Player - cross-platform music player
// Copyright (C) 2026 top.qwind.app
//
// This program is free software: you can redistribute it and/or modify
// it under the terms of the GNU General Public License as published by
// the Free Software Foundation, version 3 of the License.

import 'package:flutter/foundation.dart';

/// How a list of tracks (or playlists) is laid out.
enum LibraryView {
  /// Card grid.
  showcase,

  /// Single-column rows.
  list,

  /// Variable-height masonry, cover aspect ratio preserved.
  waterfall,
}

/// A page whose view is chosen independently and persisted.
enum LibraryViewScope {
  all,
  favorites,
  playlists,
  playlistDetail;

  /// The view shown when nothing valid is stored for this scope.
  LibraryView get defaultView => switch (this) {
    LibraryViewScope.all => LibraryView.waterfall,
    LibraryViewScope.favorites => LibraryView.showcase,
    LibraryViewScope.playlists => LibraryView.showcase,
    LibraryViewScope.playlistDetail => LibraryView.list,
  };

  /// The views this scope offers. The playlists list has no song-cover ratio,
  /// so it has no waterfall.
  Set<LibraryView> get allowedViews => switch (this) {
    LibraryViewScope.playlists => const {
      LibraryView.showcase,
      LibraryView.list,
    },
    _ => const {
      LibraryView.showcase,
      LibraryView.list,
      LibraryView.waterfall,
    },
  };

  /// [view] when allowed, otherwise [defaultView].
  LibraryView sanitize(LibraryView view) =>
      allowedViews.contains(view) ? view : defaultView;
}

/// Every scope's chosen view. Missing scopes fall back to their default.
@immutable
class LibraryViews {
  const LibraryViews(this._views);

  final Map<LibraryViewScope, LibraryView> _views;

  /// Nothing stored: every scope uses its default.
  static const LibraryViews defaults = LibraryViews(
    <LibraryViewScope, LibraryView>{},
  );

  LibraryView viewOf(LibraryViewScope scope) =>
      _views[scope] ?? scope.defaultView;

  /// A copy with [scope] set to [view] (sanitized for the scope).
  LibraryViews withView(LibraryViewScope scope, LibraryView view) =>
      LibraryViews({..._views, scope: scope.sanitize(view)});

  @override
  bool operator ==(Object other) =>
      other is LibraryViews && mapEquals(_views, other._views);

  @override
  int get hashCode => Object.hashAll(
    LibraryViewScope.values.map((scope) => _views[scope]),
  );

  @override
  String toString() => 'LibraryViews($_views)';
}
