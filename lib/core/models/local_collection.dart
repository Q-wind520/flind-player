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

import 'package:flutter/foundation.dart';

/// A local artist aggregated from the unified track pool.
@immutable
class LocalArtist {
  const LocalArtist({
    required this.name,
    required this.trackCount,
    this.coverPath,
    this.coverUrl,
  });

  final String name;
  final int trackCount;
  final String? coverPath;
  final String? coverUrl;
}

/// A local album aggregated from the unified track pool.
@immutable
class LocalAlbum {
  const LocalAlbum({
    required this.title,
    required this.trackCount,
    this.artist,
    this.year,
    this.coverPath,
    this.coverUrl,
  });

  final String title;
  final String? artist;
  final int? year;
  final int trackCount;
  final String? coverPath;
  final String? coverUrl;

  /// Stable grouping key: title plus artist, lower-cased.
  String get key =>
      '${title.toLowerCase()}\u0000${artist?.toLowerCase() ?? ''}';
}
