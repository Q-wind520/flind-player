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

import 'package:flind_player/core/sources/music_source.dart';

/// A registered online source: its stable [id] and the adapter itself.
class SourceDescriptor {
  final String id;
  final MusicSource source;

  const SourceDescriptor({required this.id, required this.source});
}

/// Drops every descriptor whose id appears in [disabled], preserving order.
///
/// Extracted from the registry provider so the kill-switch filter can be
/// verified directly instead of through provider overrides.
List<SourceDescriptor> filterDisabledSources(
  List<SourceDescriptor> all,
  Set<String> disabled,
) => all
    .where((descriptor) => !disabled.contains(descriptor.id))
    .toList(growable: false);
