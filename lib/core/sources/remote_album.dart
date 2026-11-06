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

/// An album owned by an online source.
@immutable
class RemoteAlbum {
  const RemoteAlbum({
    required this.id,
    required this.title,
    this.coverUrl,
    this.artist,
    this.trackCount = 0,
    this.year,
  });

  final String id;
  final String title;
  final String? coverUrl;
  final String? artist;
  final int trackCount;
  final int? year;

  @override
  String toString() => 'RemoteAlbum($id, $title)';
}
