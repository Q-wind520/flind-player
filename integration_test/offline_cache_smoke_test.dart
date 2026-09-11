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
import 'package:flind_player/data/cache/download_manager.dart';
import 'package:flind_player/data/providers/bilibili_providers.dart';
import 'package:flind_player/data/providers/cache_providers.dart';
import 'package:flind_player/data/providers/playback_providers.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:just_audio_media_kit/just_audio_media_kit.dart';

/// M3 acceptance smoke test on the real stack:
/// resolve a live Bilibili stream -> cache it to disk -> resolve again (must be
/// a local `file:` URI with no headers) -> play the cached copy.
///
/// Run with:
/// `flutter test integration_test/offline_cache_smoke_test.dart -d linux`
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('cache a Bilibili track then play it from disk', (tester) async {
    if (Platform.isLinux || Platform.isWindows) {
      JustAudioMediaKit.ensureInitialized();
    }

    final container = ProviderContainer();
    addTearDown(container.dispose);

    final source = container.read(biliSourceProvider);
    final resolver = container.read(streamResolverProvider);
    final manager = container.read(downloadManagerProvider);
    final store = container.read(audioCacheStoreProvider);

    // 1. Find something playable ------------------------------------------
    final keyword = Platform.environment['FLIND_TEST_QUERY'] ?? '纯音乐';
    final results = await source.search(keyword);
    expect(results, isNotEmpty, reason: 'search returned no results');

    Track? picked;
    StreamInfo? online;
    for (final candidate in results.take(3)) {
      try {
        online = await source.resolveStream(candidate);
        picked = candidate;
        break;
      } catch (error) {
        debugPrint('resolve failed for "${candidate.title}": $error');
      }
    }
    expect(picked, isNotNull, reason: 'no result produced a playable stream');
    debugPrint('picked: ${picked!.title} (${online!.qualityId})');

    // 2. Cache it ----------------------------------------------------------
    await manager.cacheTrack(picked, pinned: true, knownInfo: online);

    final cached = await store.lookup(picked.source, cacheSourceTrackId(picked));
    expect(cached, isNotNull, reason: 'cache index entry missing');
    final cachedFile = File(cached!.filePath);
    expect(cachedFile.existsSync(), isTrue, reason: 'cached file missing');
    expect(cached.bytes, greaterThan(0));
    expect(cached.pinned, isTrue);
    debugPrint(
      'cached: ${cached.filePath} '
      '(${cached.bytes} bytes, quality ${cached.qualityId})',
    );
    addTearDown(() async {
      await store.remove(cached.id);
    });

    // 3. Resolve again — must come from disk with no headers ----------------
    final offline = await resolver.resolve(picked);
    debugPrint('offline resolve -> ${offline.url} headers=${offline.headers}');
    expect(offline.url.scheme, 'file', reason: 'cache hit must be a file URI');
    expect(offline.headers, isEmpty, reason: 'local files need no headers');
    expect(offline.url.toFilePath(), cached.filePath);

    // 4. Play the cached copy ----------------------------------------------
    final controller = container.read(playbackControllerProvider);
    addTearDown(controller.dispose);
    await controller.playQueue(
      PlaybackQueue(tracks: [picked], currentIndex: 0, originalOrder: const [0]),
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
        'position=${snapshot.position.inMilliseconds}ms '
        'duration=${snapshot.duration?.inMilliseconds}ms',
      );
      if (snapshot.isPlaying && snapshot.position > Duration.zero) {
        started = true;
        break;
      }
    }

    expect(started, isTrue, reason: 'cached track never started playing');
  }, timeout: const Timeout(Duration(minutes: 4)));
}
