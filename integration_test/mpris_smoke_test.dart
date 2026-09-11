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

import 'dart:io';

import 'package:audio_service/audio_service.dart';
import 'package:flind_player/core/models/playback_queue.dart';
import 'package:flind_player/core/models/repeat_mode.dart';
import 'package:flind_player/core/models/track.dart';
import 'package:flind_player/core/sources/source_track_id.dart';
import 'package:flind_player/data/providers/playback_providers.dart';
import 'package:flind_player/platform/audio_handler.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:just_audio_media_kit/just_audio_media_kit.dart';

/// M4 acceptance smoke test: start playback, then drive it from OUTSIDE the app
/// through MPRIS using `playerctl`, asserting the effects land back on the
/// playback controller.
///
/// Run with:
/// `flutter test integration_test/mpris_smoke_test.dart -d linux`
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  Future<String> playerctl(List<String> args) async {
    final result = await Process.run('playerctl', args, runInShell: false);
    return result.stdout.toString().trim();
  }

  Future<String> findPlayer() async {
    for (var attempt = 0; attempt < 20; attempt++) {
      final list = await playerctl(<String>['-l']);
      final match = list
          .split('\n')
          .map((line) => line.trim())
          .where((line) => line.contains('flind'))
          .toList();
      if (match.isNotEmpty) return match.first;
      await Future<void>.delayed(const Duration(milliseconds: 250));
    }
    return '';
  }

  Future<void> settle(WidgetTester tester, {int ticks = 8}) async {
    for (var i = 0; i < ticks; i++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 250)),
      );
      await tester.pump();
    }
  }

  testWidgets('MPRIS publishes metadata and accepts transport commands', (
    tester,
  ) async {
    if (Platform.isLinux || Platform.isWindows) {
      JustAudioMediaKit.ensureInitialized();
    }

    final container = ProviderContainer();
    addTearDown(container.dispose);

    await AudioService.init(
      builder: () => FlindAudioHandler(
        playback: container.read(playbackControllerProvider),
      ),
      config: const AudioServiceConfig(
        androidNotificationChannelId:
            'top.qwind.app.flind_player.channel.audio',
        androidNotificationChannelName: 'Flind Player',
        androidNotificationOngoing: false,
        androidStopForegroundOnPause: false,
      ),
    );
    debugPrint('audio_service initialised');

    final controller = container.read(playbackControllerProvider);
    addTearDown(controller.dispose);

    final path = '${Directory.current.path}/test/fixtures/tone.mp3';
    final track = Track(
      source: 'local',
      sourceTrackId: LocalTrackId(path),
      uri: 'local:$path',
      title: 'MPRIS Tone',
      artist: 'Flind',
    );

    await controller.playQueue(
      PlaybackQueue(tracks: [track], currentIndex: 0, originalOrder: const [0]),
    );
    // Loop the 8 s fixture so playback stays active throughout the test.
    await controller.setRepeatMode(RepeatMode.one);
    await settle(tester, ticks: 12);
    expect(controller.currentState.isPlaying, isTrue);

    // 1. The MPRIS server must be discoverable --------------------------------
    final player = await findPlayer();
    debugPrint('MPRIS player: $player');
    expect(player, isNotEmpty, reason: 'no Flind MPRIS player found');

    // 2. Published status + metadata ------------------------------------------
    final status = await playerctl(<String>['-p', player, 'status']);
    debugPrint('status: $status');
    expect(status, 'Playing');

    final metadata = await playerctl(<String>['-p', player, 'metadata']);
    debugPrint('metadata:\n$metadata');
    expect(metadata, contains('MPRIS Tone'));
    expect(metadata, contains('Flind'));

    // 3. External pause reaches the playback controller ------------------------
    await playerctl(<String>['-p', player, 'play-pause']);
    await settle(tester, ticks: 8);
    debugPrint(
      'after external pause: playing=${controller.currentState.isPlaying}',
    );
    expect(
      controller.currentState.isPlaying,
      isFalse,
      reason: 'MPRIS pause must reach the playback controller',
    );
    expect(await playerctl(<String>['-p', player, 'status']), 'Paused');

    // 4. External resume reaches the playback controller ----------------------
    await playerctl(<String>['-p', player, 'play-pause']);
    await settle(tester, ticks: 8);
    debugPrint(
      'after external play: playing=${controller.currentState.isPlaying}',
    );
    expect(
      controller.currentState.isPlaying,
      isTrue,
      reason: 'MPRIS play must reach the playback controller',
    );
    expect(await playerctl(<String>['-p', player, 'status']), 'Playing');

    // 5. Position is still advancing after the round trip ---------------------
    final before = controller.currentState.position;
    await settle(tester, ticks: 6);
    debugPrint('position $before -> ${controller.currentState.position}');
    expect(controller.currentState.position, greaterThan(before));
  }, timeout: const Timeout(Duration(minutes: 3)));
}
