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

import 'package:flind_player/core/models/track.dart';
import 'package:flind_player/data/cache/audio_cache_store.dart';
import 'package:flind_player/data/cache/download_manager.dart';
import 'package:flind_player/data/providers/cache_providers.dart';

/// The cache index row for [track], or `null` when it is not cached.
///
/// A failed lookup resolves to `null` (treated as "not cached") instead of
/// surfacing an error into every list row. Automatic Riverpod retries are
/// disabled so a broken index does not hide the download action behind an
/// endless retry loop.
final audioCacheEntryProvider = FutureProvider.family<CachedAudio?, Track>(
  (ref, track) => ref
      .watch(audioCacheStoreProvider)
      .lookup(track.source, cacheSourceTrackId(track)),
  retry: (_, _) => null,
);

/// Compact per-track offline-cache action for library and search rows.
///
/// Hidden for local tracks: their audio already lives on disk, so caching it
/// would be meaningless. For online tracks the icon reflects the current state:
///
/// * not cached — `download_outlined`, taps enqueue a pinned download;
/// * queued/downloading — a small progress ring (fraction when the total is
///   known);
/// * cached & pinned — `download_done`, taps remove the entry after confirming;
/// * cached but not pinned — `offline_pin_outlined`, taps pin it.
class CacheActionButton extends ConsumerWidget {
  const CacheActionButton({super.key, required this.track});

  /// The row's track.
  final Track track;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (track.source == 'local') {
      return const SizedBox.shrink();
    }

    final sourceTrackId = cacheSourceTrackId(track);
    final entry = ref.watch(audioCacheEntryProvider(track)).value;
    final progress = ref.watch(downloadProgressProvider).value;
    final active =
        progress != null &&
        progress.source == track.source &&
        progress.sourceTrackId == sourceTrackId &&
        (progress.phase == DownloadPhase.queued ||
            progress.phase == DownloadPhase.downloading);

    // Re-read the index when this track's download settles so the icon flips
    // from the progress ring to the cached state (or back to the download
    // action on failure).
    ref.listen(downloadProgressProvider, (previous, next) {
      final event = next.value;
      if (event == null ||
          event.source != track.source ||
          event.sourceTrackId != sourceTrackId) {
        return;
      }
      switch (event.phase) {
        case DownloadPhase.done:
        case DownloadPhase.skipped:
        case DownloadPhase.failed:
          ref.invalidate(audioCacheEntryProvider(track));
          ref.invalidate(audioCacheUsageProvider);
        case DownloadPhase.queued:
        case DownloadPhase.downloading:
          break;
      }
    });

    if (active) {
      final total = progress.total;
      return _CompactProgress(
        value: total > 0 ? (progress.received / total).clamp(0.0, 1.0) : null,
      );
    }

    if (entry == null) {
      return _iconButton(
        icon: Icons.download_outlined,
        tooltip: '缓存到本地',
        onPressed: () =>
            ref.read(downloadManagerProvider).cacheTrack(track, pinned: true),
      );
    }

    if (entry.pinned) {
      return _iconButton(
        icon: Icons.download_done,
        tooltip: '已缓存，点击取消',
        onPressed: () => _confirmRemove(context, ref, entry),
      );
    }

    return _iconButton(
      icon: Icons.offline_pin_outlined,
      tooltip: '已缓存',
      onPressed: () {
        // Already downloaded, so only the pin flag is missing. `cacheTrack`
        // skips the network download for an indexed file. Note: the current
        // DownloadManager does NOT update the pin flag on that skip path, so
        // this tap does not actually flip `pinned` — reported rather than
        // worked around.
        ref.read(downloadManagerProvider).cacheTrack(track, pinned: true);
      },
    );
  }

  /// Confirms and then deletes this track's cache entry (row + file).
  Future<void> _confirmRemove(
    BuildContext context,
    WidgetRef ref,
    CachedAudio entry,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('移除缓存？'),
        content: Text('将从本地缓存中删除《${track.title}》。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('取消'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(dialogContext).colorScheme.error,
              foregroundColor: Theme.of(dialogContext).colorScheme.onError,
            ),
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('移除'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    await ref.read(audioCacheStoreProvider).remove(entry.id);
    ref.invalidate(audioCacheEntryProvider(track));
    ref.invalidate(audioCacheUsageProvider);
  }
}

/// Compact, overflow-safe icon button sized to sit beside a row's duration.
Widget _iconButton({
  required IconData icon,
  required String tooltip,
  required VoidCallback onPressed,
}) {
  return IconButton(
    icon: Icon(icon),
    tooltip: tooltip,
    onPressed: onPressed,
    iconSize: 20,
    visualDensity: VisualDensity.compact,
    padding: EdgeInsets.zero,
    constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
  );
}

/// A small progress ring occupying the same footprint as [_iconButton].
class _CompactProgress extends StatelessWidget {
  const _CompactProgress({this.value});

  /// Download fraction in `0..1`, or `null` when the total is unknown.
  final double? value;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 36,
      height: 36,
      child: Center(
        child: SizedBox(
          width: 20,
          height: 20,
          child: CircularProgressIndicator(value: value, strokeWidth: 2.5),
        ),
      ),
    );
  }
}
