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

import 'package:flind_player/app/theme/app_icons.dart';
import 'package:flind_player/app/theme/app_theme.dart';
import 'package:flind_player/app/theme/app_tokens.dart';
import 'package:flind_player/core/models/download_task.dart';
import 'package:flind_player/core/models/track.dart';
import 'package:flind_player/data/cache/audio_cache_store.dart';
import 'package:flind_player/data/providers/cache_providers.dart';
import 'package:flind_player/data/providers/cover_providers.dart';
import 'package:flind_player/data/providers/download_providers.dart';
import 'package:flind_player/data/providers/library_providers.dart';
import 'package:flind_player/data/providers/offline_cache_providers.dart';
import 'package:flind_player/features/settings/settings_providers.dart';
import 'package:flind_player/l10n/app_localizations.dart';
import 'package:flind_player/shared/app_async_view.dart';
import 'package:flind_player/shared/app_page_header.dart';
import 'package:flind_player/shared/app_page_scaffold.dart';
import 'package:flind_player/shared/cover_image.dart';
import 'package:flind_player/shared/empty_state.dart';
import 'package:flind_player/shared/format_bytes.dart';

enum _DownloadFilter { all, active, finished, failed }

/// The merged offline library: active/finished download tasks plus the pinned
/// songs that are already available without a network connection.
class DownloadLibraryScreen extends ConsumerStatefulWidget {
  const DownloadLibraryScreen({super.key});

  @override
  ConsumerState<DownloadLibraryScreen> createState() =>
      _DownloadLibraryScreenState();
}

class _DownloadLibraryScreenState extends ConsumerState<DownloadLibraryScreen> {
  _DownloadFilter _filter = _DownloadFilter.all;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final tasksAsync = ref.watch(downloadTasksProvider);
    final entriesAsync = ref.watch(offlineCacheEntriesProvider);
    final tasks = tasksAsync.value ?? const <DownloadTask>[];
    final entries = entriesAsync.value ?? const <CachedAudio>[];
    final usage = ref.watch(offlineCacheUsageProvider).value ?? 0;
    final compact = MediaQuery.sizeOf(context).width < AppBreakpoints.compact;

    return AppPageScaffold(
      header: AppPageHeader(
        title: l10n.offlineCache,
        compact: compact,
        leading: IconButton(
          key: const Key('downloads_back'),
          tooltip: '',
          icon: const Icon(AppIcons.arrowBack),
          onPressed: () => Navigator.of(context).maybePop(),
        ),
        actions: [
          if (entries.isNotEmpty)
            IconButton(
              tooltip: l10n.clearOfflineCache,
              icon: const Icon(AppIcons.deleteSweep),
              onPressed: () => _confirmClearOffline(entries),
            ),
        ],
      ),
      body: Column(
        children: [
          _StorageSummary(
            downloadCount: entries.length,
            usageBytes: usage,
            activeCount: tasks.where((task) => task.isActive).length,
          ),
          _DownloadFilterBar(
            filter: _filter,
            onChanged: (filter) => setState(() => _filter = filter),
          ),
          Expanded(
            child: AppAsyncView<List<DownloadTask>>(
              value: tasksAsync,
              onRetry: () => ref.invalidate(downloadTasksProvider),
              data: (tasks) => _buildBody(tasks, entries),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBody(List<DownloadTask> tasks, List<CachedAudio> entries) {
    final l10n = AppLocalizations.of(context);
    final tracksByUri = <String, Track>{
      for (final track
          in ref.watch(libraryTracksProvider).value ?? const <Track>[])
        track.uri: track,
    };
    String labelFor(CachedAudio entry) =>
        tracksByUri['${entry.source}:${entry.sourceTrackId}']?.title ??
        entry.sourceTrackId;

    final active = tasks.where((task) => task.isActive).toList(growable: false);
    final finished = tasks
        .where((task) => task.status == DownloadStatus.done)
        .toList(growable: false);
    final failed = tasks
        .where((task) => task.status == DownloadStatus.failed)
        .toList(growable: false);

    final children = <Widget>[];
    void addSection(String title, List<Widget> rows) {
      if (rows.isEmpty) return;
      if (children.isNotEmpty) {
        children.add(const SizedBox(height: AppSpacing.md));
      }
      children
        ..add(_SectionLabel(label: title))
        ..addAll(rows);
    }

    if (_filter == _DownloadFilter.all || _filter == _DownloadFilter.active) {
      addSection(
        l10n.downloadsActive,
        [for (final task in active) _TaskTile(task: task)],
      );
    }
    if (_filter == _DownloadFilter.all || _filter == _DownloadFilter.finished) {
      addSection(
        l10n.downloadsFinished,
        [for (final task in finished) _TaskTile(task: task)],
      );
    }
    if (_filter == _DownloadFilter.all || _filter == _DownloadFilter.failed) {
      addSection(
        l10n.downloadFilterFailed,
        [for (final task in failed) _TaskTile(task: task)],
      );
    }
    if (_filter == _DownloadFilter.all || _filter == _DownloadFilter.finished) {
      addSection(
        l10n.downloadedSongs,
        [
          for (final entry in entries)
            _DownloadedTrackRow(
              entry: entry,
              label: labelFor(entry),
              onRemove: () => _confirmRemoveEntry(entry, labelFor(entry)),
            ),
        ],
      );
    }

    if (children.isEmpty) {
      return EmptyState(
        icon: AppIcons.download,
        title: l10n.downloadsEmpty,
        message: l10n.offlineCacheEmpty,
      );
    }

    return ListView(
      padding: EdgeInsets.fromLTRB(
        16,
        0,
        16,
        AppSpacing.md + MediaQuery.paddingOf(context).bottom,
      ),
      children: children,
    );
  }

  Future<void> _confirmClearOffline(List<CachedAudio> entries) async {
    final l10n = AppLocalizations.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.clearOfflineTitle),
        content: Text(l10n.clearOfflineBody),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(l10n.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(l10n.clear),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    final freedBytes = entries.fold<int>(
      0,
      (sum, entry) => sum + entry.bytes + entry.coverBytes,
    );
    final ok = await ref.read(offlineCacheMaintenanceProvider).onClearAll();
    ref.invalidate(offlineCacheEntriesProvider);
    ref.invalidate(offlineCacheUsageProvider);
    ref.invalidate(combinedCacheUsageProvider);
    ref.invalidate(audioCacheUsageProvider);
    ref.invalidate(audioCacheEntryCountProvider);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          ok
              ? l10n.offlineCacheCleared(formatMegabytes(freedBytes))
              : l10n.offlineCacheClearFailed,
        ),
      ),
    );
  }

  Future<void> _confirmRemoveEntry(CachedAudio entry, String label) async {
    final l10n = AppLocalizations.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.removeDownloadTitle),
        content: Text(l10n.removeDownloadBody(label)),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(l10n.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(l10n.delete),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    await ref.read(offlineCacheMaintenanceProvider).onRemove(entry.id);
    ref.invalidate(offlineCacheEntriesProvider);
    ref.invalidate(offlineCacheUsageProvider);
    ref.invalidate(combinedCacheUsageProvider);
    ref.invalidate(audioCacheUsageProvider);
    ref.invalidate(audioCacheEntryCountProvider);
  }
}

class _StorageSummary extends StatelessWidget {
  const _StorageSummary({
    required this.downloadCount,
    required this.usageBytes,
    required this.activeCount,
  });

  final int downloadCount;
  final int usageBytes;
  final int activeCount;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Card(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, AppSpacing.sm),
      child: ListTile(
        leading: const Icon(AppIcons.offlinePin),
        title: Text(l10n.offlineCache),
        subtitle: Text(
          '${l10n.offlineCacheCount(downloadCount)} · '
          '${l10n.offlineCacheUsage(formatMegabytes(usageBytes))}'
          '${activeCount == 0 ? '' : ' · ${l10n.downloadsActive}: $activeCount'}',
        ),
      ),
    );
  }
}

class _DownloadFilterBar extends StatelessWidget {
  const _DownloadFilterBar({required this.filter, required this.onChanged});

  final _DownloadFilter filter;
  final ValueChanged<_DownloadFilter> onChanged;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.fromLTRB(16, 0, 16, AppSpacing.sm),
      child: SegmentedButton<_DownloadFilter>(
        showSelectedIcon: false,
        segments: [
          ButtonSegment(
            value: _DownloadFilter.all,
            label: Text(l10n.downloadFilterAll),
          ),
          ButtonSegment(
            value: _DownloadFilter.active,
            label: Text(l10n.downloadFilterActive),
          ),
          ButtonSegment(
            value: _DownloadFilter.finished,
            label: Text(l10n.downloadFilterFinished),
          ),
          ButtonSegment(
            value: _DownloadFilter.failed,
            label: Text(l10n.downloadFilterFailed),
          ),
        ],
        selected: {filter},
        onSelectionChanged: (value) => onChanged(value.first),
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(top: AppSpacing.md, bottom: AppSpacing.xs),
      child: Text(
        label,
        style: theme.textTheme.titleSmall?.copyWith(
          color: theme.colorScheme.onSurfaceVariant,
        ),
      ),
    );
  }
}

class _DownloadedTrackRow extends StatelessWidget {
  const _DownloadedTrackRow({
    required this.entry,
    required this.label,
    required this.onRemove,
  });

  final CachedAudio entry;
  final String label;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
      child: Row(
        children: [
          CoverImage(path: entry.coverPath, size: 48),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodyLarge,
                ),
                const SizedBox(height: 2),
                Text(
                  formatBytes(entry.bytes + entry.coverBytes),
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            key: Key('download_entry_remove_${entry.id}'),
            tooltip: l10n.downloadRemove,
            icon: const Icon(AppIcons.delete),
            onPressed: onRemove,
          ),
        ],
      ),
    );
  }
}

class _TaskTile extends ConsumerWidget {
  const _TaskTile({required this.task});

  final DownloadTask task;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final track = task.track;
    final subtitle = switch (task.status) {
      DownloadStatus.queued => l10n.downloadQueued,
      DownloadStatus.downloading => l10n.downloadDownloading,
      DownloadStatus.paused => l10n.downloadPaused,
      DownloadStatus.done => l10n.downloadDone,
      DownloadStatus.failed => l10n.downloadFailed,
      DownloadStatus.canceled => l10n.downloadCanceled,
    };

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
      child: Row(
        children: [
          CoverImage(path: track?.coverPath, url: track?.coverUrl, size: 48),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  track?.title ?? l10n.downloadMissingTrack,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodyLarge,
                ),
                const SizedBox(height: 2),
                Text(
                  _detail(l10n, task, subtitle),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: task.status == DownloadStatus.failed
                        ? theme.colorScheme.error
                        : theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                if (task.status == DownloadStatus.downloading) ...[
                  const SizedBox(height: 6),
                  LinearProgressIndicator(value: task.progress),
                ],
              ],
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          _actions(context, ref, l10n),
        ],
      ),
    );
  }

  String _detail(AppLocalizations l10n, DownloadTask task, String status) {
    if (task.status == DownloadStatus.downloading) {
      final total = task.bytesTotal;
      if (total != null && total > 0) {
        return '$status · ${formatBytes(task.bytesDone)} / ${formatBytes(total)}';
      }
      return '$status · ${formatBytes(task.bytesDone)}';
    }
    if (task.status == DownloadStatus.failed && task.error != null) {
      return task.error!;
    }
    if (task.status == DownloadStatus.done && task.bytesDone > 0) {
      return '$status · ${formatBytes(task.bytesDone)}';
    }
    return status;
  }

  Widget _actions(BuildContext context, WidgetRef ref, AppLocalizations l10n) {
    if (task.isActive) {
      return IconButton(
        key: Key('download_cancel_${task.id}'),
        tooltip: l10n.downloadCancel,
        icon: const Icon(AppIcons.close),
        onPressed: () => ref.read(downloadCenterServiceProvider).cancel(task),
      );
    }
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (task.status == DownloadStatus.failed && task.track != null)
          IconButton(
            key: Key('download_retry_${task.id}'),
            tooltip: l10n.downloadRetry,
            icon: const Icon(AppIcons.refresh),
            onPressed: () => ref
                .read(downloadManagerProvider)
                .cacheTrack(task.track!, pinned: true),
          ),
        IconButton(
          key: Key('download_remove_${task.id}'),
          tooltip: l10n.downloadRemove,
          icon: const Icon(AppIcons.delete),
          onPressed: () => _confirmRemove(context, ref, l10n),
        ),
      ],
    );
  }

  Future<void> _confirmRemove(
    BuildContext context,
    WidgetRef ref,
    AppLocalizations l10n,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.downloadRemove),
        content: Text(task.track?.title ?? l10n.downloadMissingTrack),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(l10n.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(l10n.delete),
          ),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;
    await ref.read(downloadCenterServiceProvider).remove(task);
  }
}
