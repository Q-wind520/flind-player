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

import 'package:flind_player/core/repositories/settings_repository.dart';
import 'package:flind_player/data/providers/cache_providers.dart';
import 'package:flind_player/features/settings/settings_providers.dart';
import 'package:flind_player/shared/format_bytes.dart';

/// Offline cache settings: the on/off switch, play-through caching, the size
/// cap, current usage and a destructive "clear cache" action.
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
    final settings =
        ref.watch(cacheSettingsProvider).value ?? CacheSettings.defaults;
    final usage = ref.watch(audioCacheUsageProvider).value ?? 0;
    final count = ref.watch(audioCacheEntryCountProvider).value;

    return Scaffold(
      appBar: AppBar(title: const Text('设置')),
      body: ListView(
        padding: const EdgeInsets.symmetric(vertical: 8),
        children: [
          const _SectionHeader('离线缓存'),
          SwitchListTile(
            secondary: const Icon(Icons.cached_outlined),
            title: const Text('启用缓存'),
            subtitle: const Text('把在线音频缓存到本地，离线也能播放'),
            value: settings.enabled,
            onChanged: (value) =>
                _write(ref, settings.copyWith(enabled: value)),
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
                  foregroundColor: Theme.of(context)
                      .colorScheme
                      .onErrorContainer,
                ),
                onPressed: () => _confirmClear(context, ref),
                icon: const Icon(Icons.delete_outline),
                label: const Text('清空缓存'),
              ),
            ),
          ),
        ],
      ),
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
