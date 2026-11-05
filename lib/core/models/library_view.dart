// Flind Player - cross-platform music player
// Copyright (C) 2026 top.qwind.app
//
// This program is free software: you can redistribute it and/or modify
// it under the terms of the GNU General Public License as published by
// the Free Software Foundation, version 3 of the License.

import 'package:flutter/foundation.dart';

/// How a list of tracks (or playlists) is laid out.
enum LibraryView {
  /// Cover cards.
  ///
  /// Tracks use a masonry of intrinsic-ratio covers; playlists use square
  /// full-bleed covers with the name and count overlaid on the artwork.
  cards,

  /// Single-column rows.
  list,
}

/// A page whose view is chosen independently and persisted.
enum LibraryViewScope {
  all,
  favorites,
  playlists,
  playlistDetail;

  /// The view shown when nothing valid is stored for this scope.
  LibraryView get defaultView => switch (this) {
    LibraryViewScope.playlistDetail => LibraryView.list,
    _ => LibraryView.cards,
  };

  /// The views this scope offers.
  ///
  /// Every scope now offers the same two: cards and list.
  Set<LibraryView> get allowedViews => const {
    LibraryView.cards,
    LibraryView.list,
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
