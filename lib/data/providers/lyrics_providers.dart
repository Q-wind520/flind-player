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

import 'package:flind_player/core/models/lyric.dart';
import 'package:flind_player/core/models/track.dart';
import 'package:flind_player/core/services/lyrics_provider.dart';
import 'package:flind_player/data/providers/auth_providers.dart';
import 'package:flind_player/data/providers/online_source_providers.dart';

/// Whether the source registered for [sourceId] can supply lyrics.
///
/// The lyrics UI uses this to choose between "this source has no lyrics
/// adapted" and "this track has no lyrics".
final sourceSupportsLyricsProvider = Provider.family<bool, String>((
  ref,
  sourceId,
) {
  for (final descriptor in ref.watch(onlineSourcesProvider)) {
    if (descriptor.id == sourceId) return descriptor.source is LyricsProvider;
  }
  return false;
});

/// Whether this source's lyrics are gated behind a missing login.
///
/// Used by the lyrics placeholder to offer the account sheet instead of a
/// misleading "no lyrics" message.
final lyricsLoginRequiredProvider = Provider.family<bool, String>((
  ref,
  sourceId,
) {
  final policy = ref.watch(authSourcePoliciesProvider)[sourceId];
  if (policy == null || !policy.lyricsRequireLogin) return false;
  return ref.watch(authSessionProvider(sourceId)) == null;
});

/// Lyrics for one track, routed to the registered source matching
/// `track.source`. Missing lyrics (unsupported source, no lyric, or a network
/// failure) resolve to `null` so the UI shows its placeholder.
final trackLyricsProvider = FutureProvider.family<Lyric?, Track>((
  ref,
  track,
) async {
  // Signing in/out changes whether a gate-protected source can answer; make
  // the family re-run instead of serving a cached anonymous miss. Sources whose
  // lyrics work anonymously do not touch the account state at all.
  final policy = ref.watch(authSourcePoliciesProvider)[track.source];
  if (policy?.lyricsRequireLogin ?? false) {
    ref.watch(authSessionProvider(track.source));
  }

  LyricsProvider? provider;
  for (final descriptor in ref.watch(onlineSourcesProvider)) {
    if (descriptor.id == track.source && descriptor.source is LyricsProvider) {
      provider = descriptor.source as LyricsProvider;
      break;
    }
  }
  if (provider == null) return null;
  try {
    return await provider.lyricsFor(track);
  } catch (_) {
    return null;
  }
}, retry: (_, _) => null);
