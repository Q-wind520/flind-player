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

import 'package:flind_player/core/models/playback_queue.dart';
import 'package:flind_player/core/models/track.dart';
import 'package:flind_player/core/sources/music_source.dart';
import 'package:flind_player/core/sources/source_track_id.dart';
import 'package:flind_player/core/sources/stream_resolver.dart';
import 'package:flind_player/data/playback/just_audio_playback_controller.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:just_audio_media_kit/just_audio_media_kit.dart';

/// Wraps a resolver with a configurable artificial latency, standing in for the
/// cold network/DNS latency of the first, uncached online resolve.
class _DelayedResolver implements StreamResolver {
  _DelayedResolver(this.file);

  final File file;
  Duration delay = Duration.zero;

  @override
  Future<StreamInfo> resolve(Track track) async {
    if (delay > Duration.zero) {
      await Future<void>.delayed(delay);
    }
    return StreamInfo(url: Uri.file(file.path));
  }
}

Track _track(File f, String label) => Track(
  source: 'local',
  sourceTrackId: LocalTrackId(f.path),
  uri: 'local:${f.path}',
  title: label,
  artist: 'Flind',
);

PlaybackQueue _queueOf(List<Track> tracks) => PlaybackQueue(
  tracks: tracks,
  currentIndex: 0,
  originalOrder: [for (var i = 0; i < tracks.length; i++) i],
);

Future<void> _settle(WidgetTester tester, int ms) async {
  await tester.runAsync(() => Future<void>.delayed(Duration(milliseconds: ms)));
  await tester.pump();
}

/// Regression test for the "pause restarts the track" control bug.
///
/// A track switch whose source resolve is slow (the first playback of a
/// session hits an uncached source) left `_playCurrent` awaiting the resolve
/// while the user's pause was applied to the outgoing track. When the resolve
/// finished, the trailing `play()` overrode the pause and restarted playback
/// from zero. The controller must instead honour the pause and leave the newly
/// loaded track paused until the user presses play.
///
/// Run with: `flutter test integration_test/playback_control_race_test.dart -d linux`
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('pause during a slow track switch is not overridden', (
    tester,
  ) async {
    if (Platform.isLinux || Platform.isWindows) {
      JustAudioMediaKit.ensureInitialized();
    }
    final file = File('${Directory.current.path}/test/fixtures/tone.mp3');
    expect(file.existsSync(), isTrue, reason: 'missing tone.mp3 fixture');

    final resolver = _DelayedResolver(file);
    final controller = JustAudioPlaybackController(resolver: resolver);
    addTearDown(controller.dispose);

    final a = _track(file, 'A');
    final b = _track(file, 'B');

    // Track A is playing.
    await controller.playQueue(_queueOf([a, b]), autoPlay: true);
    await _settle(tester, 400);
    expect(controller.currentState.isPlaying, isTrue);

    // User selects track B; its resolve is slow. The switch is not awaited.
    resolver.delay = const Duration(milliseconds: 800);
    unawaited(controller.playQueue(_queueOf([a, b]), index: 1, autoPlay: true));
    await _settle(tester, 200);

    // User pauses while B is still resolving.
    await controller.pause();
    await _settle(tester, 40);
    expect(controller.currentState.isPlaying, isFalse);

    // The load finishes: playback must stay paused, not restart B from zero.
    await _settle(tester, 1600);
    final paused = controller.currentState;
    expect(paused.currentTrack?.title, 'B');
    expect(
      paused.isPlaying,
      isFalse,
      reason: 'the pause must not be overridden when the load completes',
    );
    expect(paused.position, Duration.zero);

    // The user still intended to play B, so a later play starts it.
    await controller.play();
    await _settle(tester, 300);
    expect(controller.currentState.isPlaying, isTrue);
    expect(controller.currentState.currentTrack?.title, 'B');
  });
}
