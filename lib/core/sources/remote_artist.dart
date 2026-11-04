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

/// An artist profile owned by an online source.
@immutable
class RemoteArtist {
  const RemoteArtist({
    required this.id,
    required this.name,
    this.avatarUrl,
    this.albumCount = 0,
    this.songCount = 0,
  });

  final String id;
  final String name;
  final String? avatarUrl;
  final int albumCount;
  final int songCount;

  @override
  String toString() => 'RemoteArtist($id, $name)';
}
