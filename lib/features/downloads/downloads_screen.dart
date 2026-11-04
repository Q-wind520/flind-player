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
import 'package:flind_player/data/providers/cache_providers.dart';
import 'package:flind_player/data/providers/download_providers.dart';
import 'package:flind_player/l10n/app_localizations.dart';
import 'package:flind_player/shared/app_page_header.dart';
import 'package:flind_player/shared/app_surface.dart';
import 'package:flind_player/shared/cover_image.dart';
import 'package:flind_player/shared/empty_state.dart';
import 'package:flind_player/shared/format_bytes.dart';

/// The download centre: active tasks on top, finished/failed below.
class DownloadsScreen extends ConsumerWidget {
  const DownloadsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final tasksAsync = ref.watch(downloadTasksProvider);
    final compact = MediaQuery.sizeOf(context).width < AppBreakpoints.compact;

    return Scaffold(
      backgroundColor: AppSurface.colorOf(context),
      body: SafeArea(
        bottom: false,
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1120),
            child: Column(
              children: [
                AppPageHeader(
                  title: l10n.downloads,
                  compact: compact,
                  leading: IconButton(
                    key: const Key('downloads_back'),
                    tooltip: '',
                    icon: const Icon(AppIcons.arrowBack),
                    onPressed: () => Navigator.of(context).maybePop(),
                  ),
                ),
                Expanded(
                  child: tasksAsync.when(
                    loading: () =>
                        const Center(child: CircularProgressIndicator()),
                    error: (error, stackTrace) => Center(
                      child: TextButton.icon(
                        onPressed: () => ref.invalidate(downloadTasksProvider),
                        icon: const Icon(AppIcons.refresh),
                        label: Text(l10n.retry),
                      ),
                    ),
                    data: (tasks) => tasks.isEmpty
                        ? EmptyState(
                            icon: AppIcons.download,
                            title: l10n.downloadsEmpty,
                          )
                        : _TaskList(tasks: tasks),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _TaskList extends ConsumerWidget {
  const _TaskList({required this.tasks});

  final List<DownloadTask> tasks;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final active = tasks.where((task) => task.isActive).toList(growable: false);
    final finished = tasks
        .where((task) => !task.isActive)
        .toList(growable: false);
    final compact = MediaQuery.sizeOf(context).width < AppBreakpoints.compact;
    final horizontal = compact ? 16.0 : 28.0;

    return ListView(
      padding: EdgeInsets.fromLTRB(
        horizontal,
        0,
        horizontal,
        AppSpacing.md + MediaQuery.paddingOf(context).bottom,
      ),
      children: [
        if (active.isNotEmpty) ...[
          _SectionLabel(label: l10n.downloadsActive),
          for (final task in active) _TaskTile(task: task),
        ],
        if (finished.isNotEmpty) ...[
          if (active.isNotEmpty) const SizedBox(height: AppSpacing.md),
          _SectionLabel(label: l10n.downloadsFinished),
          for (final task in finished) _TaskTile(task: task),
        ],
      ],
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
