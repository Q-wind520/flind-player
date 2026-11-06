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

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:flind_player/core/models/download_task.dart';
import 'package:flind_player/core/models/track.dart';
import 'package:flind_player/core/sources/source_track_id.dart';
import 'package:flind_player/data/cache/audio_cache_store.dart';
import 'package:flind_player/data/providers/download_providers.dart';
import 'package:flind_player/data/providers/library_providers.dart';
import 'package:flind_player/data/providers/offline_cache_providers.dart';
import 'package:flind_player/features/downloads/download_library_screen.dart';

import 'support/l10n.dart';

Track _track(String title) => Track(
  source: 'bilibili',
  sourceTrackId: BiliTrackId(bvid: 'BV_$title', cid: 1),
  uri: 'bilibili:BV_$title:1',
  title: title,
  artist: 'Artist',
);

CachedAudio _entry(int id, String title) => CachedAudio(
  id: id,
  source: 'bilibili',
  sourceTrackId: 'BVID',
  filePath: '/tmp/$title.mp3',
  bytes: 4 * 1024 * 1024,
  qualityId: 'q',
  pinned: true,
  cachedAt: DateTime.fromMillisecondsSinceEpoch(id),
  lastAccessedAt: DateTime.fromMillisecondsSinceEpoch(id),
  coverBytes: 0,
);

DownloadTask _task(int id, Track track, DownloadStatus status) => DownloadTask(
  id: id,
  publicId: 'task-$id',
  trackUri: track.uri,
  track: track,
  status: status,
  bytesDone: 1024,
  bytesTotal: 2048,
  createdAt: DateTime.fromMillisecondsSinceEpoch(id),
  updatedAt: DateTime.fromMillisecondsSinceEpoch(id),
);

Widget _app({
  List<DownloadTask> tasks = const <DownloadTask>[],
  List<CachedAudio> entries = const <CachedAudio>[],
  List<Track> tracks = const <Track>[],
  int usage = 0,
  Future<void> Function(int id)? onRemove,
  Future<bool> Function()? onClearAll,
}) {
  return ProviderScope(
    overrides: [
      downloadTasksProvider.overrideWith((ref) => Stream.value(tasks)),
      offlineCacheEntriesProvider.overrideWith((ref) async => entries),
      offlineCacheUsageProvider.overrideWith((ref) async => usage),
      libraryTracksProvider.overrideWith((ref) => Stream.value(tracks)),
      offlineCacheMaintenanceProvider.overrideWithValue(
        OfflineCacheMaintenance(
          onRemove: onRemove ?? (_) async {},
          onClearAll: onClearAll ?? () async => true,
        ),
      ),
    ],
    child: localizedApp(const DownloadLibraryScreen()),
  );
}

void main() {
  testWidgets('empty state names both download states', (tester) async {
    await tester.pumpWidget(_app());
    await tester.pumpAndSettle();

    expect(find.text(testL10n().downloadsEmpty), findsOneWidget);
    expect(find.text(testL10n().offlineCacheEmpty), findsOneWidget);
  });

  testWidgets('merges active tasks and downloaded songs', (tester) async {
    final track = _track('Alpha');
    await tester.pumpWidget(
      _app(
        tasks: [
          _task(1, track, DownloadStatus.downloading),
          _task(2, track, DownloadStatus.done),
        ],
        entries: [_entry(3, 'Alpha')],
        tracks: [track],
        usage: 4 * 1024 * 1024,
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text(testL10n().downloadsActive), findsWidgets);
    expect(find.text(testL10n().downloadsFinished), findsWidgets);
    expect(find.text(testL10n().downloadedSongs), findsOneWidget);
    expect(find.text('Alpha'), findsWidgets);
  });

  testWidgets('removing a downloaded song confirms before deleting', (
    tester,
  ) async {
    final removed = <int>[];
    await tester.pumpWidget(
      _app(
        entries: [_entry(7, 'Alpha')],
        onRemove: (id) async => removed.add(id),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('download_entry_remove_7')));
    await tester.pumpAndSettle();
    expect(find.text(testL10n().removeDownloadTitle), findsOneWidget);
    expect(removed, isEmpty);

    await tester.tap(find.text(testL10n().delete));
    await tester.pumpAndSettle();
    expect(removed, [7]);
  });

  testWidgets('clearing the offline cache confirms first', (tester) async {
    var clears = 0;
    await tester.pumpWidget(
      _app(
        entries: [_entry(7, 'Alpha')],
        onClearAll: () async {
          clears++;
          return true;
        },
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip(testL10n().clearOfflineCache));
    await tester.pumpAndSettle();
    expect(find.text(testL10n().clearOfflineTitle), findsOneWidget);
    expect(clears, 0);

    await tester.tap(find.text(testL10n().clear));
    await tester.pumpAndSettle();
    expect(clears, 1);
  });
}
