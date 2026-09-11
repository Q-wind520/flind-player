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
import 'package:flind_player/core/sources/music_source.dart';
import 'package:flind_player/data/playback/just_audio_playback_controller.dart';
import 'package:flind_player/data/providers/bilibili_providers.dart';
import 'package:flind_player/data/providers/playback_providers.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:just_audio_media_kit/just_audio_media_kit.dart';

/// M1 acceptance smoke test against the LIVE Bilibili API:
/// search -> resolve stream (with Referer headers) -> actually play it.
///
/// Run with:
/// `flutter test integration_test/bilibili_smoke_test.dart -d linux`
///
/// This test hits the network and is therefore excluded from `flutter test`
/// (which only runs `test/`). Keep request volume minimal — Bilibili
/// rate-limits aggressively (`-412`).
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('Bilibili: search, resolve and play a real track', (
    tester,
  ) async {
    if (Platform.isLinux || Platform.isWindows) {
      JustAudioMediaKit.ensureInitialized();
    }

    final container = ProviderContainer();
    addTearDown(container.dispose);

    final source = container.read(biliSourceProvider);

    // 1. Search -------------------------------------------------------------
    final keyword = Platform.environment['FLIND_TEST_QUERY'] ?? '纯音乐';
    final results = await source.search(keyword);
    debugPrint('search("$keyword") -> ${results.length} results');
    for (final track in results.take(5)) {
      debugPrint('  - ${track.title}  |  ${track.artist}  |  ${track.uri}');
    }
    expect(results, isNotEmpty, reason: 'search returned no results');

    // 2. Resolve (try a few results; some videos have no audio stream) ------
    StreamInfo? info;
    Track? picked;
    for (final candidate in results.take(3)) {
      try {
        info = await source.resolveStream(candidate);
        picked = candidate;
        break;
      } catch (error) {
        debugPrint('resolve failed for "${candidate.title}": $error');
      }
    }
    expect(info, isNotNull, reason: 'no result produced a playable stream');
    debugPrint(
      'resolved: ${info!.qualityId} -> ${info.url} '
      '(backups: ${info.backupUrls.length}, expires: ${info.expiresAt})',
    );
    expect(info.url.toString(), isNotEmpty);
    expect(
      info.headers['Referer'],
      contains('bilibili.com'),
      reason: 'CDN rejects requests without a bilibili Referer',
    );

    // 3. Play it for real ---------------------------------------------------
    final resolver = container.read(streamResolverProvider);
    final controller = JustAudioPlaybackController(resolver: resolver);
    addTearDown(controller.dispose);

    await controller.playQueue(
      PlaybackQueue(
        tracks: [picked!],
        currentIndex: 0,
        originalOrder: const [0],
      ),
    );

    var started = false;
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
        started = true;
        break;
      }
    }

    final state = controller.currentState;
    expect(started, isTrue, reason: 'Bilibili stream never started playing');
    expect(state.position, greaterThan(Duration.zero));
  }, timeout: const Timeout(Duration(minutes: 3)));
}
