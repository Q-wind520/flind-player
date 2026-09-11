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

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;

import 'package:flind_player/core/repositories/settings_repository.dart';
import 'package:flind_player/data/providers/cache_providers.dart';
import 'package:flind_player/data/providers/database_providers.dart';
import 'package:flind_player/data/providers/library_providers.dart';
import 'package:flind_player/data/services/library_sync_service.dart';
import 'package:flind_player/features/settings/settings_providers.dart';
import 'package:flind_player/platform/permissions/permission_providers.dart';
import 'package:flind_player/platform/permissions/permission_service.dart';
import 'package:flind_player/shared/error_messages.dart';
import 'package:flind_player/shared/error_snack_bar.dart';
import 'package:flind_player/shared/format_bytes.dart';

/// Application settings: playback (cache), library, and about sections.
class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  /// Preset cache caps offered as choice chips (`docs/local-library.md` §4.4).
  static const List<int> limitOptions = <int>[
    256 * 1024 * 1024,
    512 * 1024 * 1024,
    1024 * 1024 * 1024,
    2 * 1024 * 1024 * 1024,
    5 * 1024 * 1024 * 1024,
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: AppBar(title: const Text('设置')),
      body: ListView(
        padding: const EdgeInsets.symmetric(vertical: 8),
        children: [
          // ── 播放 ──
          const _SectionHeader('播放'),
          _PlaybackSection(limitOptions: limitOptions),

          // ── 曲库 ──
          const _SectionHeader('曲库'),
          const _LibrarySection(),

          // ── 关于 ──
          const _SectionHeader('关于'),
          const _AboutSection(),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// 播放 section
// ---------------------------------------------------------------------------

/// Cache / playback settings, moved from the original single-section layout.
class _PlaybackSection extends ConsumerWidget {
  const _PlaybackSection({required this.limitOptions});

  final List<int> limitOptions;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings =
        ref.watch(cacheSettingsProvider).value ?? CacheSettings.defaults;
    final usage = ref.watch(audioCacheUsageProvider).value ?? 0;
    final count = ref.watch(audioCacheEntryCountProvider).value;

    return Column(
      children: [
        SwitchListTile(
          secondary: const Icon(Icons.cached_outlined),
          title: const Text('启用缓存'),
          subtitle: const Text('把在线音频缓存到本地，离线也能播放'),
          value: settings.enabled,
          onChanged: (value) => _write(ref, settings.copyWith(enabled: value)),
        ),
        SwitchListTile(
          secondary: const Icon(Icons.play_circle_outline),
          title: const Text('播放时自动缓存'),
          subtitle: const Text('播放时在后台缓存，不计入手动下载'),
          value: settings.autoOnPlay,
          onChanged: settings.enabled
              ? (value) => _write(ref, settings.copyWith(autoOnPlay: value))
              : null,
        ),
        const Divider(height: 1),
        ListTile(
          leading: const Icon(Icons.sd_storage_outlined),
          title: const Text('缓存上限'),
          subtitle: Text('当前：${formatBytes(settings.limitBytes)}'),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          child: Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final limit in limitOptions)
                ChoiceChip(
                  label: Text(formatBytes(limit)),
                  selected: settings.limitBytes == limit,
                  onSelected: (_) =>
                      _write(ref, settings.copyWith(limitBytes: limit)),
                ),
            ],
          ),
        ),
        const Divider(height: 1),
        _UsageSection(
          usageBytes: usage,
          limitBytes: settings.limitBytes,
          trackCount: count,
        ),
        const Divider(height: 1),
        Padding(
          padding: const EdgeInsets.all(16),
          child: Align(
            alignment: Alignment.centerLeft,
            child: FilledButton.tonalIcon(
              style: FilledButton.styleFrom(
                backgroundColor: Theme.of(context).colorScheme.errorContainer,
                foregroundColor: Theme.of(context).colorScheme.onErrorContainer,
              ),
              onPressed: () => _confirmClear(context, ref),
              icon: const Icon(Icons.delete_outline),
              label: const Text('清空缓存'),
            ),
          ),
        ),
      ],
    );
  }

  /// Persists [next] and refreshes the usage figures it can affect.
  Future<void> _write(WidgetRef ref, CacheSettings next) async {
    await ref.read(settingsRepositoryProvider).updateCacheSettings(next);
    ref.invalidate(audioCacheUsageProvider);
    ref.invalidate(audioCacheEntryCountProvider);
  }

  /// Asks for confirmation, then deletes every cached file and row.
  Future<void> _confirmClear(BuildContext context, WidgetRef ref) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('清空缓存？'),
        content: const Text('将删除全部已缓存的音频，包括手动下载的曲目。此操作无法撤销。'),
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
            child: const Text('清空'),
          ),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;

    final messenger = ScaffoldMessenger.of(context);
    final freed = ref.read(audioCacheUsageProvider).value ?? 0;
    await ref.read(audioCacheStoreProvider).clear();
    ref.invalidate(audioCacheUsageProvider);
    ref.invalidate(audioCacheEntryCountProvider);
    messenger.showSnackBar(
      SnackBar(content: Text('已清空缓存，释放 ${formatBytes(freed)}')),
    );
  }
}

// ---------------------------------------------------------------------------
// 曲库 section
// ---------------------------------------------------------------------------

/// Library statistics, scan root management and rescan trigger.
class _LibrarySection extends ConsumerStatefulWidget {
  const _LibrarySection();

  @override
  ConsumerState<_LibrarySection> createState() => _LibrarySectionState();
}

class _LibrarySectionState extends ConsumerState<_LibrarySection> {
  @override
  Widget build(BuildContext context) {
    final tracksAsync = ref.watch(libraryTracksProvider);
    final trackCount = tracksAsync.value?.length;
    final cacheCount = ref.watch(audioCacheEntryCountProvider).value;
    final scanRootsAsync = ref.watch(scanRootsProvider);
    final syncState =
        ref.watch(librarySyncStateProvider).value ?? LibrarySyncState.idle;
    final isSyncing = switch (syncState.phase) {
      LibrarySyncPhase.scanning ||
      LibrarySyncPhase.saving ||
      LibrarySyncPhase.artwork => true,
      _ => false,
    };

    return Column(
      children: [
        // ── Statistics ──
        ListTile(
          leading: const Icon(Icons.analytics_outlined),
          title: const Text('曲库统计'),
          subtitle: Text(_trackCountLabel(trackCount, cacheCount)),
        ),
        const Divider(height: 1),

        // ── Scan roots ──
        _ScanRootHeader(isSyncing: isSyncing),
        scanRootsAsync.when(
          loading: () => const Padding(
            padding: EdgeInsets.all(16),
            child: Center(child: CircularProgressIndicator()),
          ),
          error: (e, _) => ListTile(
            leading: const Icon(Icons.error_outline),
            title: Text('加载失败：${describeError(e)}'),
            trailing: IconButton(
              icon: const Icon(Icons.refresh),
              tooltip: '重试',
              onPressed: () => ref.invalidate(scanRootsProvider),
            ),
          ),
          data: (roots) {
            if (roots.isEmpty) {
              return const Padding(
                padding: EdgeInsets.fromLTRB(16, 0, 16, 16),
                child: Text('未配置扫描根目录', style: TextStyle(color: Colors.grey)),
              );
            }
            return Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                for (final root in roots)
                  ListTile(
                    title: Text(p.basename(root)),
                    subtitle: Text(
                      root,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    trailing: IconButton(
                      icon: const Icon(Icons.delete_outline),
                      tooltip: '删除',
                      onPressed: () => _confirmRemoveRoot(context, ref, root),
                    ),
                  ),
              ],
            );
          },
        ),

        // ── Add folder ──
        ListTile(
          leading: const Icon(Icons.create_new_folder_outlined),
          title: const Text('添加文件夹'),
          onTap: isSyncing ? null : () => _addFolder(ref),
        ),
        const Divider(height: 1),

        // ── Rescan ──
        ListTile(
          key: const Key('rescan'),
          leading: Icon(
            Icons.refresh,
            color: isSyncing
                ? Theme.of(context).colorScheme.onSurfaceVariant
                : null,
          ),
          title: const Text('重新扫描'),
          subtitle: _syncSubtitle(syncState),
          onTap: isSyncing ? null : () => _startSync(ref),
        ),
      ],
    );
  }

  String _trackCountLabel(int? trackCount, int? cacheCount) {
    final parts = <String>[];
    if (trackCount != null) {
      parts.add('$trackCount 首曲目');
    }
    if (cacheCount != null && cacheCount > 0) {
      parts.add('$cacheCount 首已缓存');
    }
    return parts.isEmpty ? '加载中…' : parts.join('，');
  }

  Widget? _syncSubtitle(LibrarySyncState state) {
    final scheme = Theme.of(context).colorScheme;
    return switch (state.phase) {
      LibrarySyncPhase.idle => null,
      LibrarySyncPhase.scanning => Text(
        '扫描中 ${state.processed}/${state.discovered}',
        style: TextStyle(color: scheme.primary),
      ),
      LibrarySyncPhase.saving => Text(
        '保存中…',
        style: TextStyle(color: scheme.primary),
      ),
      LibrarySyncPhase.artwork => Text(
        '缓存封面 ${state.coversCached}/${state.saved}',
        style: TextStyle(color: scheme.primary),
      ),
      LibrarySyncPhase.done => Text(
        '已同步 ${state.discovered} 首 · 新增 ${state.saved}',
        style: TextStyle(color: scheme.tertiary),
      ),
      LibrarySyncPhase.failed => Text(
        '同步失败',
        style: TextStyle(color: scheme.error),
      ),
    };
  }

  Future<void> _addFolder(WidgetRef ref) async {
    final messenger = ScaffoldMessenger.of(context);
    final permission = await ref
        .read(permissionCoordinatorProvider)
        .ensureAudioLibrary();
    if (permission != PermissionResult.granted) {
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            permissionDeniedMessage(
              AppPermission.audioLibrary,
              permanentlyDenied:
                  permission == PermissionResult.permanentlyDenied,
            ),
          ),
        ),
      );
      return;
    }
    try {
      final path = await FilePicker.getDirectoryPath(dialogTitle: '选择音乐文件夹');
      if (path == null) return;
      await ref.read(musicLibraryRepositoryProvider).addScanRoot(path);
      ref.invalidate(scanRootsProvider);
      _startSync(ref);
      messenger.showSnackBar(SnackBar(content: Text('已添加文件夹：$path')));
    } catch (error) {
      if (!mounted) return;
      showErrorSnackBar(context, error);
    }
  }

  void _startSync(WidgetRef ref) {
    unawaited(ref.read(librarySyncServiceProvider).sync());
  }

  Future<void> _confirmRemoveRoot(
    BuildContext context,
    WidgetRef ref,
    String path,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('删除扫描根目录？'),
        content: Text('将移除「$path」，后续扫描不再包含此目录中的文件。'),
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
            child: const Text('删除'),
          ),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;

    final messenger = ScaffoldMessenger.of(context);
    await ref.read(musicLibraryRepositoryProvider).removeScanRoot(path);
    ref.invalidate(scanRootsProvider);
    unawaited(ref.read(librarySyncServiceProvider).sync());
    messenger.showSnackBar(SnackBar(content: Text('已移除扫描根目录：$path')));
  }
}

/// Header row for the scan roots sub-section with an add-folder action.
class _ScanRootHeader extends StatelessWidget {
  const _ScanRootHeader({required this.isSyncing});

  final bool isSyncing;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 8, 4),
      child: Row(
        children: [
          Text(
            '扫描根目录',
            style: Theme.of(context).textTheme.titleSmall
                ?.copyWith(color: Theme.of(context).colorScheme.primary),
          ),
          const Spacer(),
          IconButton(
            icon: const Icon(Icons.create_new_folder_outlined),
            tooltip: '添加文件夹',
            onPressed: isSyncing ? null : () {},
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// 关于 section
// ---------------------------------------------------------------------------

/// App version, open-source license and project homepage.
class _AboutSection extends ConsumerWidget {
  const _AboutSection();

  static const String _projectUrl = 'https://github.com/Q-wind520/flind-player';

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final infoAsync = ref.watch(packageInfoProvider);
    final scheme = Theme.of(context).colorScheme;

    return Column(
      children: [
        infoAsync.when(
          loading: () => const ListTile(
            leading: Icon(Icons.info_outline),
            title: Text('加载中…'),
          ),
          error: (_, _) => const ListTile(
            leading: Icon(Icons.info_outline),
            title: Text('Flind Player'),
          ),
          data: (info) => ListTile(
            leading: const Icon(Icons.info_outline),
            title: const Text('Flind Player'),
            subtitle: Text('v${info.version} (${info.buildNumber})'),
          ),
        ),
        const Divider(height: 1),
        ListTile(
          leading: const Icon(Icons.description_outlined),
          title: const Text('开源许可'),
          subtitle: const Text('GNU General Public License v3.0'),
          onTap: () => showLicensePage(
            context: context,
            applicationName: 'Flind Player',
          ),
        ),
        const Divider(height: 1),
        ListTile(
          leading: const Icon(Icons.code_outlined),
          title: const Text('项目主页'),
          subtitle: Text(
            _projectUrl,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
          child: Text(
            'Flind Player 是一款基于 GPL-3.0 许可证的自由软件。\n'
            '本程序没有任何担保，详见许可证全文。',
            style: Theme.of(context).textTheme.bodySmall
                ?.copyWith(color: scheme.onSurfaceVariant),
          ),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Shared widgets
// ---------------------------------------------------------------------------

/// A muted section heading.
class _SectionHeader extends StatelessWidget {
  const _SectionHeader(this.title);

  final String title;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
      child: Text(
        title,
        style: theme.textTheme.titleSmall?.copyWith(
          color: theme.colorScheme.primary,
        ),
      ),
    );
  }
}

/// Current usage against the configured cap, plus the cached track count.
class _UsageSection extends StatelessWidget {
  const _UsageSection({
    required this.usageBytes,
    required this.limitBytes,
    required this.trackCount,
  });

  final int usageBytes;
  final int limitBytes;
  final int? trackCount;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final ratio = limitBytes > 0
        ? (usageBytes / limitBytes).clamp(0.0, 1.0)
        : 0.0;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text('用量', style: theme.textTheme.titleSmall),
              const Spacer(),
              Text(
                '${formatBytes(usageBytes)} / ${formatBytes(limitBytes)}',
                style: theme.textTheme.bodyMedium,
              ),
            ],
          ),
          const SizedBox(height: 8),
          LinearProgressIndicator(value: ratio),
          const SizedBox(height: 8),
          Text(
            trackCount == null ? '已缓存 — 首' : '已缓存 $trackCount 首',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}
