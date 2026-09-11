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

import 'package:flind_player/data/providers/cache_providers.dart';

/// Number of audio files currently indexed in the offline cache.
///
/// Recomputes whenever [audioCacheUsageProvider] changes (for example after a
/// download completes or the cache is cleared), so the settings screen keeps
/// the count and the usage figure in sync. Automatic retries are disabled so a
/// broken index surfaces instead of retrying forever.
final audioCacheEntryCountProvider = FutureProvider<int>((ref) async {
  ref.watch(audioCacheUsageProvider);
  final entries = await ref.watch(audioCacheStoreProvider).entries();
  return entries.length;
}, retry: (_, _) => null);
