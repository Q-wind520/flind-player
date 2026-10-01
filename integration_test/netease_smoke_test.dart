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

import 'package:flind_player/data/providers/netease_providers.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

/// Acceptance smoke test against the LIVE NetEase API:
/// search -> resolve the first result's stream -> assert a playable URL.
///
/// Run with:
/// `flutter test integration_test/netease_smoke_test.dart -d linux`
///
/// This test hits the network and is therefore excluded from `flutter test`
/// (which only runs `test/`). Keep request volume minimal.
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('NetEase: search and resolve a real stream URL', (tester) async {
    final container = ProviderContainer();
    addTearDown(container.dispose);

    final source = container.read(neteaseSourceProvider);

    // 1. Search -------------------------------------------------------------
    final keyword = Platform.environment['FLIND_TEST_QUERY'] ?? '周杰伦';
    final results = await source.search(keyword);
    debugPrint('search("$keyword") -> ${results.length} results');
    for (final track in results.take(5)) {
      debugPrint('  - ${track.title}  |  ${track.artist}  |  ${track.uri}');
    }
    expect(results, isNotEmpty, reason: 'search returned no results');

    // 2. Resolve the first result's stream ----------------------------------
    final info = await source.resolveStream(results.first);
    debugPrint(
      'resolved: ${info.qualityId} -> ${info.url} '
      '(backups: ${info.backupUrls.length}, expires: ${info.expiresAt})',
    );
    expect(
      info.url.toString(),
      isNotEmpty,
      reason: 'stream URL is empty for "${results.first.title}"',
    );
  }, timeout: const Timeout(Duration(minutes: 3)));
}
