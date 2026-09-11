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
import 'dart:io';

import 'package:audio_service/audio_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:just_audio_media_kit/just_audio_media_kit.dart';
import 'package:window_manager/window_manager.dart';

import 'package:flind_player/app/app.dart';
import 'package:flind_player/app/di/application_overrides.dart';
import 'package:flind_player/data/providers/persistence_providers.dart';
import 'package:flind_player/data/providers/playback_providers.dart';
import 'package:flind_player/platform/audio_handler.dart';
import 'package:flind_player/platform/tray/tray_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // On Linux/Windows, just_audio is backed by media_kit — must be initialized
  // before any AudioPlayer is constructed.
  if (Platform.isLinux || Platform.isWindows) {
    JustAudioMediaKit.ensureInitialized();
  }

  // A manually-owned container lets the audio handler receive the real
  // PlaybackController (and share it with the widget tree below).
  final container = ProviderContainer(overrides: buildApplicationOverrides());

  // window_manager must be initialised BEFORE runApp: its Linux plugin takes
  // over window creation, and initialising it later leaves the GTK window
  // half-configured — which in turn makes AudioService.init never complete.
  final isDesktop = Platform.isLinux || Platform.isWindows || Platform.isMacOS;
  if (isDesktop) {
    try {
      await windowManager.ensureInitialized();
    } catch (error) {
      debugPrint('Flind Player: window_manager init failed: $error');
    }
  }

  try {
    await AudioService.init(
      builder: () => FlindAudioHandler(
        playback: container.read(playbackControllerProvider),
      ),
      config: const AudioServiceConfig(
        androidNotificationChannelId:
            'top.qwind.app.flind_player.channel.audio',
        androidNotificationChannelName: 'Flind Player',
        androidNotificationOngoing: false,
        // Music players must keep the foreground service alive across pause, or
        // resuming can hit ForegroundServiceStartNotAllowedException on Android 12+.
        androidStopForegroundOnPause: false,
      ),
    );
  } catch (error, stackTrace) {
    // A platform without an audio_service implementation must not prevent the
    // app from starting.
    debugPrint('Flind Player: audio_service init failed: $error\n$stackTrace');
  }

  // Restore the last playback session (queue/position/repeat/shuffle) before the
  // UI mounts, then keep persisting changes. Both steps are guarded so a corrupt
  // snapshot or an unavailable database can never block startup.
  final playbackPersistence = container.read(
    playbackPersistenceServiceProvider,
  );
  try {
    await playbackPersistence.restore();
  } catch (error, stackTrace) {
    debugPrint(
      'Flind Player: playback snapshot restore failed: $error\n$stackTrace',
    );
  }
  try {
    playbackPersistence.start();
  } catch (error, stackTrace) {
    debugPrint(
      'Flind Player: playback persistence start failed: $error\n$stackTrace',
    );
  }

  runApp(
    UncontrolledProviderScope(container: container, child: const FlindApp()),
  );

  // The tray and window management are desktop-only and must never block or
  // break startup; a session without AppIndicator support degrades gracefully.
  if (isDesktop) {
    try {
      final trayService = TrayService(
        playback: container.read(playbackControllerProvider),
      );
      unawaited(trayService.start());
    } catch (error, stackTrace) {
      debugPrint('Flind Player: tray init failed: $error\n$stackTrace');
    }
  }
}
