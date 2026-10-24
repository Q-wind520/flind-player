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

/// Invisible hook that asks for the audio-library permission once at launch.
///
/// A local track is resolved to its raw on-disk path and handed to `just_audio`,
/// which cannot open a file the app has no permission to read (Android 13+
/// `READ_MEDIA_AUDIO`; below that `READ_EXTERNAL_STORAGE`). Requesting the
/// permission only when the user added a folder or imported files left tracks
/// that arrived by other means (a restore, an older build) silently unplayable:
/// the load failure is swallowed by the playback controller, so neither a prompt
/// nor an error ever appeared, and playback never reached `isPlaying` — which in
/// turn kept the notification request from ever firing. Asking on the first
/// frame makes the system dialog show right after install/open, before any
/// playback.
///
/// On desktop and web [PermissionService] is a no-op, so this is harmless there.
class StartupPermissionScope extends ConsumerStatefulWidget {
  const StartupPermissionScope({required this.child, super.key});

  final Widget child;

  @override
  ConsumerState<StartupPermissionScope> createState() =>
      _StartupPermissionScopeState();
}

class _StartupPermissionScopeState
    extends ConsumerState<StartupPermissionScope> {
  @override
  void initState() {
    super.initState();
    // Wait for the first frame: the platform permission dialog needs the
    // Activity attached, and requesting before that is a no-op.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      unawaited(
        ref.read(permissionCoordinatorProvider).ensureAudioLibrary(),
      );
    });
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
