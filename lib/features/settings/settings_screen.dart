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
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;

import 'package:flind_player/app/language.dart';
import 'package:flind_player/app/theme_mode.dart';
import 'package:flind_player/core/models/app_language.dart';
import 'package:flind_player/core/models/app_theme_mode.dart';
import 'package:flind_player/core/repositories/settings_repository.dart';
import 'package:flind_player/data/cache/audio_cache_store.dart';
import 'package:flind_player/data/cache/download_manager.dart';
import 'package:flind_player/data/providers/cache_providers.dart';
import 'package:flind_player/data/providers/cover_providers.dart';
import 'package:flind_player/data/providers/database_providers.dart';
import 'package:flind_player/data/providers/library_providers.dart';
import 'package:flind_player/data/providers/offline_cache_providers.dart';
import 'package:flind_player/data/services/library_sync_service.dart';
import 'package:flind_player/features/settings/settings_providers.dart';
import 'package:flind_player/l10n/app_localizations.dart';
import 'package:flind_player/platform/permissions/permission_providers.dart';
import 'package:flind_player/platform/permissions/permission_service.dart';
import 'package:flind_player/shared/app_surface.dart';
import 'package:flind_player/shared/error_messages.dart';
import 'package:flind_player/shared/error_snack_bar.dart';
import 'package:flind_player/shared/format_bytes.dart';
import 'package:flind_player/shared/platform_support.dart';

/// Application settings: playback (cache), library, and about sections.
class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    return Scaffold(
      backgroundColor: AppSurface.colorOf(context),
      body: ListView(
        padding: const EdgeInsets.symmetric(vertical: 8),
        children: [
          _SectionHeader(l10n.general),
          const _GeneralSection(),

          // ── 播放 ──
          _SectionHeader(l10n.sectionPlayback),
          const _PlaybackSection(),

          // ── 离线缓存 ──
          _SectionHeader(l10n.offlineCache),
          const _OfflineCacheSection(),

          // ── 曲库 ──
          _SectionHeader(l10n.sectionLibrary),
          if (supportsLocalLibrary)
            const _LibrarySection()
          else
            const _UnsupportedLibraryNotice(),

          // ── 关于 ──
          _SectionHeader(l10n.about),
          const _AboutSection(),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// 通用 section
// ---------------------------------------------------------------------------

/// UI language and appearance selection, applied app-wide and persisted
/// across restarts.
class _GeneralSection extends ConsumerWidget {
  const _GeneralSection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final language = ref.watch(appLanguageProvider).value ?? AppLanguage.system;
    final themeMode =
        ref.watch(appThemeModeProvider).value ?? AppThemeMode.system;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ListTile(
          leading: const Icon(Icons.language_outlined),
          title: Text(l10n.language),
          subtitle: Text(_languageLabel(l10n, language)),
          onTap: () => _pickLanguage(context, ref, language),
        ),
        ListTile(
          leading: const Icon(Icons.brightness_6_outlined),
          title: Text(l10n.themeMode),
          subtitle: Text(_themeModeLabel(l10n, themeMode)),
          onTap: () => _pickThemeMode(context, ref, themeMode),
        ),
      ],
    );
  }

  static String _languageLabel(AppLocalizations l10n, AppLanguage language) =>
      switch (language) {
        AppLanguage.system => l10n.languageSystem,
        AppLanguage.english => l10n.languageEnglish,
        AppLanguage.simplifiedChinese => l10n.languageSimplifiedChinese,
      };

  static String _themeModeLabel(AppLocalizations l10n, AppThemeMode mode) =>
      switch (mode) {
        AppThemeMode.system => l10n.themeModeAuto,
        AppThemeMode.light => l10n.themeModeLight,
        AppThemeMode.dark => l10n.themeModeDark,
      };

  Future<void> _pickLanguage(
    BuildContext context,
    WidgetRef ref,
    AppLanguage current,
  ) async {
    final l10n = AppLocalizations.of(context);
    final selected = await showDialog<AppLanguage>(
      context: context,
      builder: (dialogContext) => SimpleDialog(
        title: Text(l10n.language),
        children: [
          for (final language in AppLanguage.values)
            SimpleDialogOption(
              onPressed: () => Navigator.of(dialogContext).pop(language),
              child: Row(
                children: [
                  Icon(
                    language == current
                        ? Icons.radio_button_checked
                        : Icons.radio_button_unchecked,
                    size: 20,
                  ),
                  const SizedBox(width: 12),
                  Text(_languageLabel(l10n, language)),
                ],
              ),
            ),
        ],
      ),
    );
    if (selected == null || selected == current) return;
    await ref.read(appLanguageProvider.notifier).setLanguage(selected);
  }

  Future<void> _pickThemeMode(
    BuildContext context,
    WidgetRef ref,
    AppThemeMode current,
  ) async {
    final l10n = AppLocalizations.of(context);
    final selected = await showDialog<AppThemeMode>(
      context: context,
      builder: (dialogContext) => SimpleDialog(
        title: Text(l10n.themeMode),
        children: [
          for (final mode in AppThemeMode.values)
            SimpleDialogOption(
              onPressed: () => Navigator.of(dialogContext).pop(mode),
              child: Row(
                children: [
                  Icon(
                    mode == current
                        ? Icons.radio_button_checked
                        : Icons.radio_button_unchecked,
                    size: 20,
                  ),
                  const SizedBox(width: 12),
                  Text(_themeModeLabel(l10n, mode)),
                ],
              ),
            ),
        ],
      ),
    );
    if (selected == null || selected == current) return;
    await ref.read(appThemeModeProvider.notifier).setThemeMode(selected);
  }
}

// ---------------------------------------------------------------------------
// 播放 section
// ---------------------------------------------------------------------------

/// Cache / playback settings, moved from the original single-section layout.
class _PlaybackSection extends ConsumerWidget {
  const _PlaybackSection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final settings =
        ref.watch(cacheSettingsProvider).value ?? CacheSettings.defaults;
    // Audio and remote covers share one cap, so both are shown as one figure.
    final usage = ref.watch(combinedCacheUsageProvider).value ?? 0;

    // Keep usage fresh when downloads finish, skip, or fail.
    ref.listen(downloadProgressProvider, (prev, next) {
      final phase = next.value?.phase;
      if (phase == DownloadPhase.done ||
          phase == DownloadPhase.skipped ||
          phase == DownloadPhase.failed) {
        ref.invalidate(combinedCacheUsageProvider);
        ref.invalidate(coverCacheUsageProvider);
        ref.invalidate(audioCacheUsageProvider);
        ref.invalidate(audioCacheEntryCountProvider);
        // A finished download adds a pinned row, so the offline list and its
        // usage figure must be refetched too.
        ref.invalidate(offlineCacheEntriesProvider);
        ref.invalidate(offlineCacheUsageProvider);
      }
    });

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ListTile(
          leading: const Icon(Icons.folder_outlined),
          title: Text(l10n.cacheLocation),
          subtitle: FutureBuilder<String>(
            future: ref.read(audioCacheStoreProvider).cacheDirectoryPath(),
            builder: (context, snapshot) => Text(
              snapshot.data ?? '…',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          onTap: () => _showCacheLocationDialog(context, ref),
        ),
        ListTile(
          leading: const Icon(Icons.sd_storage_outlined),
          title: Text(l10n.cacheLimit),
          subtitle: Text(
            l10n.cacheUsage(
              formatMegabytes(usage),
              formatMegabytes(settings.limitBytes),
            ),
          ),
          onTap: () => _showCustomLimitDialog(context, ref, settings),
        ),
      ],
    );
  }

  /// Shows a dialog with the cache directory path, a copy action, and a
  /// destructive clear-cache action.
  Future<void> _showCacheLocationDialog(
    BuildContext context,
    WidgetRef ref,
  ) async {
    final store = ref.read(audioCacheStoreProvider);
    final pathFuture = store.cacheDirectoryPath();

    await showDialog<void>(
      context: context,
      builder: (dialogContext) => _CacheLocationDialog(pathFuture: pathFuture),
    );
  }

  /// Shows a dialog for entering a custom cache size limit, in megabytes.
  Future<void> _showCustomLimitDialog(
    BuildContext context,
    WidgetRef ref,
    CacheSettings settings,
  ) async {
    const int megabyte = 1024 * 1024;

    await showDialog<void>(
      context: context,
      builder: (dialogContext) => _CustomLimitDialog(
        initialMegabytes: settings.limitBytes / megabyte,
        onConfirm: (bytes) async {
          await ref
              .read(settingsRepositoryProvider)
              .updateCacheSettings(settings.copyWith(limitBytes: bytes));
          // Both stores share the cap, so both must shed whatever no longer fits.
          await ref.read(cacheMaintenanceProvider).onEnforceLimits();
          ref.invalidate(combinedCacheUsageProvider);
          ref.invalidate(coverCacheUsageProvider);
          ref.invalidate(audioCacheUsageProvider);
          ref.invalidate(audioCacheEntryCountProvider);
        },
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// 离线缓存 section
// ---------------------------------------------------------------------------

/// Manually downloaded songs: their list, per-download removal and a full
/// clear.
///
/// The complementary counterpart of the "clear cache" action, which now only
/// drops the online layer, so downloads can only be removed from here.
class _OfflineCacheSection extends ConsumerWidget {
  const _OfflineCacheSection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final entries =
        ref.watch(offlineCacheEntriesProvider).value ?? const <CachedAudio>[];
    final usage = ref.watch(offlineCacheUsageProvider).value ?? 0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ListTile(
          leading: const Icon(Icons.download_done_outlined),
          title: Text(l10n.offlineCache),
          subtitle: Text(
            '${l10n.offlineCacheCount(entries.length)} · ${l10n.offlineCacheUsage(formatMegabytes(usage))}',
          ),
          trailing: entries.isEmpty
              ? null
              : IconButton(
                  icon: const Icon(Icons.delete_sweep_outlined),
                  tooltip: l10n.clearOfflineCache,
                  onPressed: () => _confirmClearOffline(context, ref),
                ),
        ),
        if (entries.isEmpty)
          ListTile(
            dense: true,
            title: Text(
              l10n.offlineCacheEmpty,
              style: Theme.of(context).textTheme.bodySmall,
            ),
          )
        else
          for (final entry in entries)
            ListTile(
              dense: true,
              title: Text(entry.sourceTrackId),
              subtitle: Text(formatMegabytes(entry.bytes)),
              trailing: IconButton(
                icon: const Icon(Icons.delete_outline),
                onPressed: () => _confirmRemoveDownload(context, ref, entry),
              ),
            ),
      ],
    );
  }

  /// Confirms, then deletes the single pinned download [entry].
  ///
  /// The dialog names the download by its raw source track id: the settings
  /// screen holds no library row, so that id is all it can show.
  Future<void> _confirmRemoveDownload(
    BuildContext context,
    WidgetRef ref,
    CachedAudio entry,
  ) async {
    final l10n = AppLocalizations.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(l10n.removeDownloadTitle),
        content: Text(l10n.removeDownloadBody(entry.sourceTrackId)),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: Text(l10n.cancel),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(dialogContext).colorScheme.error,
              foregroundColor: Theme.of(dialogContext).colorScheme.onError,
            ),
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: Text(l10n.delete),
          ),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;

    await ref.read(offlineCacheMaintenanceProvider).onRemove(entry.id);
    ref.invalidate(offlineCacheEntriesProvider);
    ref.invalidate(offlineCacheUsageProvider);
    // The removal frees layer-1 bytes, so the top-of-screen usage line and
    // the library's cached-count must refresh too.
    ref.invalidate(combinedCacheUsageProvider);
    ref.invalidate(audioCacheUsageProvider);
    ref.invalidate(audioCacheEntryCountProvider);
  }

  /// Confirms, then removes every pinned download.
  Future<void> _confirmClearOffline(BuildContext context, WidgetRef ref) async {
    final l10n = AppLocalizations.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(l10n.clearOfflineTitle),
        content: Text(l10n.clearOfflineBody),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: Text(l10n.cancel),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(dialogContext).colorScheme.error,
              foregroundColor: Theme.of(dialogContext).colorScheme.onError,
            ),
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: Text(l10n.clear),
          ),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;

    final messenger = ScaffoldMessenger.of(context);
    final freed = ref.read(offlineCacheUsageProvider).value ?? 0;
    await ref.read(offlineCacheMaintenanceProvider).onClearAll();
    ref.invalidate(offlineCacheEntriesProvider);
    ref.invalidate(offlineCacheUsageProvider);
    // Clearing frees layer-1 bytes; keep the top-of-screen usage line and the
    // library's cached-count in sync with the empty list.
    ref.invalidate(combinedCacheUsageProvider);
    ref.invalidate(audioCacheUsageProvider);
    ref.invalidate(audioCacheEntryCountProvider);
    messenger.showSnackBar(
      SnackBar(content: Text(l10n.offlineCacheCleared(formatMegabytes(freed)))),
    );
  }
}

// ---------------------------------------------------------------------------
// Cache-location dialog
// ---------------------------------------------------------------------------

/// Dialog showing the cache directory path with copy and clear actions.
class _CacheLocationDialog extends ConsumerWidget {
  const _CacheLocationDialog({required this.pathFuture});

  final Future<String> pathFuture;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    return AlertDialog(
      title: Text(l10n.cacheLocation),
      content: FutureBuilder<String>(
        future: pathFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const SizedBox(
              height: 24,
              child: Center(child: CircularProgressIndicator()),
            );
          }
          final path = snapshot.data ?? l10n.unknownPath;
          return SelectableText(
            path,
            style: Theme.of(context).textTheme.bodyMedium,
          );
        },
      ),
      actions: [
        TextButton.icon(
          onPressed: () async {
            final snapshot = await pathFuture;
            if (!context.mounted) return;
            await Clipboard.setData(ClipboardData(text: snapshot));
            if (!context.mounted) return;
            ScaffoldMessenger.of(context)
                .showSnackBar(SnackBar(content: Text(l10n.pathCopied)));
          },
          icon: const Icon(Icons.copy_outlined),
          label: Text(l10n.copy),
        ),
        TextButton.icon(
          onPressed: () async {
            await _confirmClear(context, ref);
          },
          icon: const Icon(Icons.delete_outline),
          label: Text(l10n.clearCache),
          style: TextButton.styleFrom(
            foregroundColor: Theme.of(context).colorScheme.error,
          ),
        ),
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(l10n.close),
        ),
      ],
    );
  }

  /// Asks for confirmation, then deletes every cached file and row.
  Future<void> _confirmClear(BuildContext context, WidgetRef ref) async {
    final l10n = AppLocalizations.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(l10n.clearCacheTitle),
        content: Text(l10n.clearCacheBody),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: Text(l10n.cancel),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(dialogContext).colorScheme.error,
              foregroundColor: Theme.of(dialogContext).colorScheme.onError,
            ),
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: Text(l10n.clear),
          ),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;

    final messenger = ScaffoldMessenger.of(context);
    final freed = ref.read(combinedCacheUsageProvider).value ?? 0;
    await ref.read(cacheMaintenanceProvider).onClearAll();
    ref.invalidate(combinedCacheUsageProvider);
    ref.invalidate(coverCacheUsageProvider);
    ref.invalidate(audioCacheUsageProvider);
    ref.invalidate(audioCacheEntryCountProvider);
    messenger.showSnackBar(
      SnackBar(content: Text(l10n.cacheCleared(formatMegabytes(freed)))),
    );
  }
}

// ---------------------------------------------------------------------------
// Custom-limit dialog
// ---------------------------------------------------------------------------

/// Dialog for entering a custom cache size limit in megabytes.
///
/// The cache cap is expressed in a single unit (MB) now that audio and covers
/// share it; the former MB/GB selector only added a conversion step.
class _CustomLimitDialog extends StatefulWidget {
  const _CustomLimitDialog({
    required this.initialMegabytes,
    required this.onConfirm,
  });

  final double initialMegabytes;
  final Future<void> Function(int bytes) onConfirm;

  @override
  State<_CustomLimitDialog> createState() => _CustomLimitDialogState();
}

class _CustomLimitDialogState extends State<_CustomLimitDialog> {
  /// Bytes in one mebibyte.
  static const int _megabyte = 1024 * 1024;

  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(
      text: _formatNumber(widget.initialMegabytes),
    );
  }

  /// Formats [value] without a trailing `.0`: `1.0` renders as `1`, while
  /// `1.5` stays `1.5`.
  static String _formatNumber(double value) {
    return value == value.roundToDouble()
        ? value.toInt().toString()
        : value.toString();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  bool _validate() {
    final number = double.tryParse(_controller.text);
    if (number == null || number <= 0) return false;
    return true;
  }

  Future<void> _confirm() async {
    if (!_validate()) return;
    final number = double.parse(_controller.text);
    await widget.onConfirm((number * _megabyte).toInt());
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final errorText = _controller.text.isEmpty
        ? null
        : (_validate() ? null : l10n.enterPositiveNumber);

    return AlertDialog(
      title: Text(l10n.customCacheLimit),
      content: TextField(
        controller: _controller,
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
        decoration: InputDecoration(
          labelText: l10n.value,
          suffixText: 'MB',
          errorText: errorText,
          border: const OutlineInputBorder(),
        ),
        autofocus: true,
        onChanged: (_) => setState(() {}),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(l10n.cancel),
        ),
        FilledButton(
          onPressed: _validate() ? _confirm : null,
          child: Text(l10n.confirm),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// 曲库 section
// ---------------------------------------------------------------------------

/// Muted replacement for the library controls on platforms that expose no
/// user-selectable filesystem roots (iOS).
class _UnsupportedLibraryNotice extends StatelessWidget {
  const _UnsupportedLibraryNotice();

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      child: Text(
        l10n.iosLibraryUnsupportedTitle,
        style: theme.textTheme.bodyMedium?.copyWith(
          color: theme.colorScheme.onSurfaceVariant,
        ),
      ),
    );
  }
}

/// Library statistics, scan root management and rescan trigger.
class _LibrarySection extends ConsumerStatefulWidget {
  const _LibrarySection();

  @override
  ConsumerState<_LibrarySection> createState() => _LibrarySectionState();
}

class _LibrarySectionState extends ConsumerState<_LibrarySection> {
  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
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
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // ── Statistics ──
        ListTile(
          leading: const Icon(Icons.analytics_outlined),
          title: Text(l10n.libraryStats),
          subtitle: Text(_trackCountLabel(trackCount, cacheCount)),
        ),

        // ── Scan roots ──
        _ScanRootHeader(isSyncing: isSyncing, onAdd: () => _addFolder(ref)),
        scanRootsAsync.when(
          loading: () => const Padding(
            padding: EdgeInsets.all(16),
            child: Center(child: CircularProgressIndicator()),
          ),
          error: (e, _) => ListTile(
            leading: const Icon(Icons.error_outline),
            title: Text(l10n.loadFailedWith(describeError(l10n, e))),
            trailing: IconButton(
              icon: const Icon(Icons.refresh),
              onPressed: () => ref.invalidate(scanRootsProvider),
            ),
          ),
          data: (roots) {
            if (roots.isEmpty) {
              return Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                child: Text(
                  l10n.noScanRoots,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
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
          title: Text(l10n.addFolder),
          onTap: isSyncing ? null : () => _addFolder(ref),
        ),

        // ── Rescan ──
        ListTile(
          key: const Key('rescan'),
          leading: Icon(
            Icons.refresh,
            color: isSyncing
                ? Theme.of(context).colorScheme.onSurfaceVariant
                : null,
          ),
          title: Text(l10n.rescan),
          subtitle: _syncSubtitle(syncState),
          onTap: isSyncing ? null : () => _startSync(ref),
        ),
      ],
    );
  }

  String _trackCountLabel(int? trackCount, int? cacheCount) {
    final l10n = AppLocalizations.of(context);
    final parts = <String>[];
    if (trackCount != null) {
      parts.add(l10n.trackCount(trackCount));
    }
    if (cacheCount != null && cacheCount > 0) {
      parts.add(l10n.cachedCount(cacheCount));
    }
    return parts.isEmpty ? l10n.loading : parts.join(l10n.listSeparator);
  }

  Widget? _syncSubtitle(LibrarySyncState state) {
    final l10n = AppLocalizations.of(context);
    final scheme = Theme.of(context).colorScheme;
    return switch (state.phase) {
      LibrarySyncPhase.idle => null,
      LibrarySyncPhase.scanning => Text(
        l10n.scanning(state.processed, state.discovered),
        style: TextStyle(color: scheme.primary),
      ),
      LibrarySyncPhase.saving => Text(
        l10n.saving,
        style: TextStyle(color: scheme.primary),
      ),
      LibrarySyncPhase.artwork => Text(
        l10n.coversCached(state.coversCached, state.saved),
        style: TextStyle(color: scheme.primary),
      ),
      LibrarySyncPhase.done => Text(
        l10n.syncedAdded(state.discovered, state.saved),
        style: TextStyle(color: scheme.tertiary),
      ),
      LibrarySyncPhase.failed => Text(
        l10n.syncFailedShort,
        style: TextStyle(color: scheme.error),
      ),
    };
  }

  Future<void> _addFolder(WidgetRef ref) async {
    final l10n = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final permission = await ref
        .read(permissionCoordinatorProvider)
        .ensureAudioLibrary();
    if (permission != PermissionResult.granted) {
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            permissionDeniedMessage(
              l10n,
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
      final path = await FilePicker.getDirectoryPath(
        dialogTitle: l10n.selectMusicFolder,
      );
      if (path == null) return;
      await ref.read(musicLibraryRepositoryProvider).addScanRoot(path);
      ref.invalidate(scanRootsProvider);
      _startSync(ref);
      messenger.showSnackBar(SnackBar(content: Text(l10n.folderAdded(path))));
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
    final l10n = AppLocalizations.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(l10n.deleteScanRootTitle),
        content: Text(l10n.deleteScanRootBody(path)),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: Text(l10n.cancel),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(dialogContext).colorScheme.error,
              foregroundColor: Theme.of(dialogContext).colorScheme.onError,
            ),
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: Text(l10n.delete),
          ),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;

    final messenger = ScaffoldMessenger.of(context);
    await ref.read(musicLibraryRepositoryProvider).removeScanRoot(path);
    ref.invalidate(scanRootsProvider);
    unawaited(ref.read(librarySyncServiceProvider).sync());
    messenger.showSnackBar(SnackBar(content: Text(l10n.scanRootRemoved(path))));
  }
}

/// Header row for the scan roots sub-section with an add-folder action.
class _ScanRootHeader extends StatelessWidget {
  const _ScanRootHeader({required this.isSyncing, required this.onAdd});

  final bool isSyncing;
  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 8, 4),
      child: Row(
        children: [
          Text(
            l10n.scanRoots,
            style: Theme.of(context).textTheme.titleSmall
                ?.copyWith(color: Theme.of(context).colorScheme.primary),
          ),
          const Spacer(),
          IconButton(
            icon: const Icon(Icons.create_new_folder_outlined),
            onPressed: isSyncing ? null : onAdd,
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
    final l10n = AppLocalizations.of(context);
    final infoAsync = ref.watch(packageInfoProvider);
    final scheme = Theme.of(context).colorScheme;

    return Column(
      children: [
        infoAsync.when(
          loading: () => ListTile(
            leading: const Icon(Icons.info_outline),
            title: Text(l10n.loading),
          ),
          error: (_, _) => ListTile(
            leading: const Icon(Icons.info_outline),
            title: Text(l10n.appName),
          ),
          data: (info) => ListTile(
            leading: const Icon(Icons.info_outline),
            title: Text(l10n.appName),
            subtitle: Text('v${info.version} (${info.buildNumber})'),
          ),
        ),
        ListTile(
          leading: const Icon(Icons.description_outlined),
          title: Text(l10n.openSourceLicenses),
          subtitle: const Text('GNU General Public License v3.0'),
          onTap: () =>
              showLicensePage(context: context, applicationName: l10n.appName),
        ),
        ListTile(
          leading: const Icon(Icons.code_outlined),
          title: Text(l10n.projectHomepage),
          subtitle: Text(
            _projectUrl,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
          child: Text(
            l10n.aboutLicense,
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
