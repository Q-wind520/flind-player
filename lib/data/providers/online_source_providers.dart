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

import 'package:flind_player/core/models/track.dart';
import 'package:flind_player/core/sources/online_source.dart';
import 'package:flind_player/data/providers/bilibili_providers.dart';
import 'package:flind_player/data/providers/netease_providers.dart';

/// Source ids disabled at runtime (remote kill-switch hook).
///
/// MVP returns an empty set; a remote config could override it later.
final disabledSourceIdsProvider = Provider<Set<String>>(
  (ref) => const <String>{},
);

/// Ordered registry of enabled online sources.
final onlineSourcesProvider = Provider<List<SourceDescriptor>>((ref) {
  final disabled = ref.watch(disabledSourceIdsProvider);
  final bili = ref.watch(biliSourceProvider);
  final netease = ref.watch(neteaseSourceProvider);
  return filterDisabledSources(<SourceDescriptor>[
    SourceDescriptor(id: bili.id, source: bili),
    SourceDescriptor(id: netease.id, source: netease),
  ], disabled);
});

/// Search results for one `(sourceId, query)` pair.
final onlineSearchProvider =
    FutureProvider.family<List<Track>, (String, String)>((ref, key) async {
  final query = key.$2.trim();
  if (query.isEmpty) return const <Track>[];
  SourceDescriptor? descriptor;
  for (final candidate in ref.watch(onlineSourcesProvider)) {
    if (candidate.id == key.$1) {
      descriptor = candidate;
      break;
    }
  }
  if (descriptor == null) return const <Track>[];
  return descriptor.source.search(query);
}, retry: (_, _) => null);
