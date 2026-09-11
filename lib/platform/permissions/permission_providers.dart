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

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:flind_player/data/providers/playback_providers.dart';
import 'package:flind_player/platform/permissions/permission_service.dart';

/// The app-wide [PermissionService].
///
/// Overridable in tests so no platform channel is ever touched.
final permissionServiceProvider = Provider<PermissionService>(
  (ref) => PermissionService(),
);

/// The app-wide [PermissionCoordinator] (when and what to request).
final permissionCoordinatorProvider = Provider<PermissionCoordinator>(
  (ref) => PermissionCoordinator(ref.watch(permissionServiceProvider)),
);

/// Invisible hook that asks for the notification permission once, after the
/// first successful playback start.
///
/// Mount it around a screen that is always alive (the search tab lives in the
/// shell's `IndexedStack`), so one listener covers playback started from any
/// screen. Playback state is watched rather than polled, and the coordinator
/// guarantees the request happens at most once.
class PlaybackPermissionScope extends ConsumerWidget {
  const PlaybackPermissionScope({required this.child, super.key});

  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.listen(playbackStateProvider, (previous, next) {
      final state = next.value;
      if (state == null || !state.isPlaying || state.currentTrack == null) {
        return;
      }
      unawaited(
        ref
            .read(permissionCoordinatorProvider)
            .requestNotificationsAfterPlayback(),
      );
    });
    return child;
  }
}
