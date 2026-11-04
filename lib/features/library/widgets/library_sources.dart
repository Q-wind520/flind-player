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
import 'package:flind_player/app/theme/app_tokens.dart';
import 'package:flind_player/data/providers/library_providers.dart';
import 'package:flind_player/data/providers/offline_cache_providers.dart';
import 'package:flind_player/features/downloads/download_library_screen.dart';
import 'package:flind_player/features/library/local_browse_screen.dart';
import 'package:flind_player/features/netease/netease_library_screen.dart';
import 'package:flind_player/features/playlists/bilibili_favorites_screen.dart';
import 'package:flind_player/l10n/app_localizations.dart';
import 'package:flind_player/shared/format_bytes.dart';
import 'package:flind_player/shared/platform_support.dart';
import 'package:flind_player/shared/section_header.dart';

/// Source shortcuts shown at the top of the playlists tab.
class LibrarySources extends ConsumerWidget {
  const LibrarySources({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final entries =
        ref.watch(offlineCacheEntriesProvider).value ?? const [];
    final usage = ref.watch(offlineCacheUsageProvider).value ?? 0;
    final localCount =
        ref
            .watch(libraryTracksProvider)
            .value
            ?.where((track) => track.source == 'local')
            .length ??
        0;

    final cards = <Widget>[
      _SourceCard(
        icon: AppIcons.offlinePin,
        title: l10n.offlineCache,
        subtitle:
            '${l10n.offlineCacheCount(entries.length)} · '
            '${l10n.offlineCacheUsage(formatMegabytes(usage))}',
        onTap: () => _push(context, const DownloadLibraryScreen()),
      ),
      _SourceCard(
        icon: AppIcons.cloud,
        title: l10n.bilibiliFavorites,
        subtitle: l10n.browsePublicFavorites,
        onTap: () => _push(context, const BilibiliFavoritesScreen()),
      ),
      _SourceCard(
        icon: AppIcons.musicNote,
        title: l10n.neteaseLibrary,
        subtitle: l10n.neteaseLibraryHint,
        onTap: () => _push(context, const NeteaseLibraryScreen()),
      ),
      if (supportsLocalLibrary)
        _SourceCard(
          icon: AppIcons.folder,
          title: l10n.localLibraryTitle,
          subtitle: l10n.trackCount(localCount),
          onTap: () => _push(context, const LocalBrowseScreen()),
        ),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SectionHeader(l10n.librarySources),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, AppSpacing.sm),
          child: LayoutBuilder(
            builder: (context, constraints) {
              final twoColumns = constraints.maxWidth >= 560;
              final cardWidth = twoColumns
                  ? (constraints.maxWidth - AppSpacing.sm) / 2
                  : constraints.maxWidth;
              return Wrap(
                spacing: AppSpacing.sm,
                runSpacing: AppSpacing.sm,
                children: [
                  for (final card in cards)
                    SizedBox(width: cardWidth, child: card),
                ],
              );
            },
          ),
        ),
      ],
    );
  }

  void _push(BuildContext context, Widget page) {
    Navigator.of(
      context,
    ).push(MaterialPageRoute<void>(builder: (context) => page));
  }
}

class _SourceCard extends StatelessWidget {
  const _SourceCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Material(
      color: scheme.surfaceContainerLow,
      borderRadius: BorderRadius.circular(AppRadius.md),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: scheme.primary.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(AppRadius.sm),
                ),
                child: Icon(icon, size: 20, color: scheme.primary),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Icon(
                AppIcons.chevronRight,
                size: 18,
                color: scheme.onSurfaceVariant,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
