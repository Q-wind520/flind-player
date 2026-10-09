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

import 'package:flind_player/core/models/playback_state.dart';
import 'package:flind_player/core/models/track.dart';
import 'package:flind_player/core/services/playback_controller.dart';
import 'package:flind_player/core/sources/stream_resolver.dart';
import 'package:flind_player/data/cache/cached_stream_resolver.dart';
import 'package:flind_player/data/playback/just_audio_playback_controller.dart';
import 'package:flind_player/data/providers/cache_providers.dart';

/// Resolves tracks to playable streams, cache first.
///
/// Cached tracks return a `file:` URL with no headers (offline playback); a
/// miss delegates to the online/local resolver and enqueues a background
/// download. The download manager uses the *inner* resolver, not this one, to
/// avoid a dependency cycle.
final streamResolverProvider = Provider<StreamResolver>((ref) {
  return CachedStreamResolver(
    inner: ref.watch(innerStreamResolverProvider),
    store: ref.watch(audioCacheStoreProvider),
    manager: ref.watch(downloadManagerProvider),
  );
});

/// The application's playback engine.
final playbackControllerProvider = Provider<PlaybackController>((ref) {
  final controller = JustAudioPlaybackController(
    resolver: ref.watch(streamResolverProvider),
  );
  ref.onDispose(controller.dispose);
  return controller;
});

/// Broadcasts [PlaybackState] updates to the UI.
final playbackStateProvider = StreamProvider<PlaybackState>(
  (ref) => ref.watch(playbackControllerProvider).state,
);

/// The track that would play on "previous" from the current queue, or `null`
/// when there is none (queue start with repeat off, or nothing playing).
final previousTrackProvider = Provider<Track?>((ref) {
  final state = ref.watch(playbackStateProvider).value;
  if (state == null || state.currentTrack == null) return null;
  final queue = ref.watch(playbackControllerProvider).queue;
  final index = queue.previousIndex(repeatMode: state.repeatMode);
  if (index == null || index < 0 || index >= queue.tracks.length) return null;
  return queue.tracks[index];
});

/// The track that would play on "next" from the current queue, or `null`.
final nextTrackProvider = Provider<Track?>((ref) {
  final state = ref.watch(playbackStateProvider).value;
  if (state == null || state.currentTrack == null) return null;
  final queue = ref.watch(playbackControllerProvider).queue;
  final index = queue.nextIndex(repeatMode: state.repeatMode);
  if (index == null || index < 0 || index >= queue.tracks.length) return null;
  return queue.tracks[index];
});
