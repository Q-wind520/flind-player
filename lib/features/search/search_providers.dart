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
import 'package:flind_player/data/providers/bilibili_providers.dart';

/// Search results for a query, cached per query string by Riverpod.
///
/// Automatic provider retries are disabled: the Bilibili search endpoint is
/// aggressively rate-limited (`-412` blocks the IP, `-352` triggers risk
/// control) and the HTTP layer's `RateLimiter` already paces requests and backs
/// off. A provider-level retry would hammer a blocked IP and hide the error
/// state behind a spinner, so failures surface immediately instead.
final biliSearchResultsProvider = FutureProvider.family<List<Track>, String>((
  ref,
  query,
) async {
  final trimmed = query.trim();
  if (trimmed.isEmpty) return const <Track>[];
  return ref.watch(biliSourceProvider).search(trimmed);
}, retry: (_, _) => null);
