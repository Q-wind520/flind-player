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

import 'package:flind_player/core/models/playback_queue.dart';
import 'package:flind_player/core/models/track.dart';
import 'package:flind_player/core/sources/source_track_id.dart';
import 'package:flind_player/data/playback/just_audio_playback_controller.dart';
import 'package:flind_player/data/sources/local/local_stream_resolver.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:just_audio_media_kit/just_audio_media_kit.dart';

/// M0 acceptance smoke test: play a real local MP3 through the production
/// playback stack and assert that the transport actually advances.
///
/// Run with: `flutter test integration_test/playback_smoke_test.dart -d linux`
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('local MP3 plays and position advances', (tester) async {
    if (Platform.isLinux || Platform.isWindows) {
      JustAudioMediaKit.ensureInitialized();
    }

    final audioFile = _resolveFixture();
    expect(
      audioFile.existsSync(),
      isTrue,
      reason: 'Test fixture not found at ${audioFile.path}',
    );

    final controller = JustAudioPlaybackController(
      resolver: LocalStreamResolver(),
    );
    addTearDown(controller.dispose);

    final track = Track(
      source: 'local',
      sourceTrackId: LocalTrackId(audioFile.path),
      uri: 'local:${audioFile.path}',
      title: 'M0 Smoke Tone',
      artist: 'Flind',
    );

    await controller.playQueue(
      PlaybackQueue(tracks: [track], currentIndex: 0, originalOrder: const [0]),
    );

    for (var i = 0; i < 40; i++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 250)),
      );
      await tester.pump();

      final snapshot = controller.currentState;
      debugPrint(
        'tick $i playing=${snapshot.isPlaying} '
        'buffering=${snapshot.isBuffering} '
        'position=${snapshot.position.inMilliseconds}ms '
        'duration=${snapshot.duration?.inMilliseconds}ms',
      );
      if (snapshot.isPlaying && snapshot.position > Duration.zero) {
        break;
      }
    }

    final state = controller.currentState;
    expect(state.duration, isNotNull, reason: 'duration was never reported');
    expect(state.isPlaying, isTrue, reason: 'player never entered playing');
    expect(
      state.position,
      greaterThan(Duration.zero),
      reason: 'position never advanced',
    );
  });
}

File _resolveFixture() {
  final fromEnv = Platform.environment['FLIND_TEST_AUDIO'];
  if (fromEnv != null && fromEnv.isNotEmpty) {
    return File(fromEnv);
  }
  return File('${Directory.current.path}/test/fixtures/tone.mp3');
}
