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
import 'package:flind_player/core/services/playback_controller.dart';
import 'package:flind_player/core/sources/stream_resolver.dart';
import 'package:flind_player/data/playback/just_audio_playback_controller.dart';
import 'package:flind_player/data/providers/bilibili_providers.dart';
import 'package:flind_player/data/sources/composite_stream_resolver.dart';
import 'package:flind_player/data/sources/local/local_stream_resolver.dart';

/// Resolves tracks to playable streams.
///
/// Local files go through [LocalStreamResolver]; online sources register
/// themselves in the [CompositeStreamResolver] (Bilibili for M1).
final streamResolverProvider = Provider<StreamResolver>((ref) {
  final biliSource = ref.watch(biliSourceProvider);
  return CompositeStreamResolver(
    localResolver: const LocalStreamResolver(),
    sources: <String, StreamResolver>{biliSource.id: biliSource},
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
