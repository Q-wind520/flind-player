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
import 'package:flind_player/core/models/playback_session.dart';
import 'package:flind_player/core/models/playback_queue.dart';
import 'package:flind_player/data/providers/playback_providers.dart';
import 'package:flind_player/data/providers/stats_providers.dart';
import 'package:flind_player/l10n/app_localizations.dart';
import 'package:flind_player/shared/app_page_header.dart';
import 'package:flind_player/shared/app_surface.dart';
import 'package:flind_player/shared/cover_image.dart';
import 'package:flind_player/shared/empty_state.dart';

/// Listening stats: totals for a period plus the most-played tracks.
class PlaybackStatsScreen extends ConsumerStatefulWidget {
  const PlaybackStatsScreen({super.key});

  @override
  ConsumerState<PlaybackStatsScreen> createState() =>
      _PlaybackStatsScreenState();
}

class _PlaybackStatsScreenState extends ConsumerState<PlaybackStatsScreen> {
  PlaybackStatsPeriod _period = PlaybackStatsPeriod.all;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final summaryAsync = ref.watch(playbackStatsSummaryProvider(_period));
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
                  title: l10n.playbackStats,
                  compact: compact,
                  leading: IconButton(
                    key: const Key('stats_back'),
                    tooltip: '',
                    icon: const Icon(AppIcons.arrowBack),
                    onPressed: () => Navigator.of(context).maybePop(),
                  ),
                ),
                _PeriodPicker(
                  period: _period,
                  onChanged: (period) => setState(() => _period = period),
                ),
                Expanded(
                  child: summaryAsync.when(
                    loading: () =>
                        const Center(child: CircularProgressIndicator()),
                    error: (error, stackTrace) => Center(
                      child: TextButton.icon(
                        onPressed: () => ref.invalidate(
                          playbackStatsSummaryProvider(_period),
                        ),
                        icon: const Icon(AppIcons.refresh),
                        label: Text(l10n.retry),
                      ),
                    ),
                    data: (summary) => summary.totalPlayCount == 0
                        ? EmptyState(
                            icon: AppIcons.analytics,
                            title: l10n.statsEmpty,
                          )
                        : _StatsBody(summary: summary),
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

class _PeriodPicker extends StatelessWidget {
  const _PeriodPicker({required this.period, required this.onChanged});

  final PlaybackStatsPeriod period;
  final ValueChanged<PlaybackStatsPeriod> onChanged;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final compact = MediaQuery.sizeOf(context).width < AppBreakpoints.compact;
    final horizontal = compact ? 16.0 : 28.0;
    return SizedBox(
      height: 48,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: EdgeInsets.symmetric(horizontal: horizontal),
        children: [
          for (final value in PlaybackStatsPeriod.values)
            Padding(
              padding: const EdgeInsets.only(right: AppSpacing.sm),
              child: ChoiceChip(
                label: Text(_label(l10n, value)),
                selected: value == period,
                onSelected: (_) => onChanged(value),
              ),
            ),
        ],
      ),
    );
  }

  String _label(AppLocalizations l10n, PlaybackStatsPeriod period) {
    return switch (period) {
      PlaybackStatsPeriod.day => l10n.statsPeriodDay,
      PlaybackStatsPeriod.week => l10n.statsPeriodWeek,
      PlaybackStatsPeriod.month => l10n.statsPeriodMonth,
      PlaybackStatsPeriod.year => l10n.statsPeriodYear,
      PlaybackStatsPeriod.all => l10n.statsPeriodAll,
    };
  }
}

class _StatsBody extends ConsumerWidget {
  const _StatsBody({required this.summary});

  final PlaybackStatsSummary summary;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final compact = MediaQuery.sizeOf(context).width < AppBreakpoints.compact;
    final horizontal = compact ? 16.0 : 28.0;

    return ListView(
      padding: EdgeInsets.fromLTRB(
        horizontal,
        AppSpacing.md,
        horizontal,
        AppSpacing.md + MediaQuery.paddingOf(context).bottom,
      ),
      children: [
        Wrap(
          spacing: AppSpacing.sm,
          runSpacing: AppSpacing.sm,
          children: [
            _StatCard(
              label: l10n.statsPlaysLabel,
              value: '${summary.totalPlayCount}',
            ),
            _StatCard(
              label: l10n.statsListenLabel,
              value: _formatListenTime(summary.totalListenTime),
            ),
            _StatCard(
              label: l10n.statsTracksLabel,
              value: '${summary.trackCount}',
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.lg),
        Text(l10n.statsTopTracks, style: theme.textTheme.titleMedium),
        const SizedBox(height: AppSpacing.sm),
        for (var i = 0; i < summary.tracks.length; i++)
          _StatRow(
            rank: i + 1,
            stat: summary.tracks[i],
            onTap: () => _play(ref, summary.tracks, i),
          ),
      ],
    );
  }

  void _play(WidgetRef ref, List<TrackPlayStat> stats, int index) {
    final tracks = [for (final stat in stats) stat.track];
    final queue = PlaybackQueue(
      tracks: tracks,
      currentIndex: index,
      originalOrder: List<int>.generate(tracks.length, (i) => i),
    );
    ref.read(playbackControllerProvider).playQueue(queue, index: index);
  }
}

class _StatCard extends StatelessWidget {
  const _StatCard({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      width: 200,
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(AppRadius.md),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            value,
            style: theme.textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}

class _StatRow extends StatelessWidget {
  const _StatRow({required this.rank, required this.stat, required this.onTap});

  final int rank;
  final TrackPlayStat stat;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppRadius.sm),
      child: Padding(
        padding: const EdgeInsets.symmetric(
          vertical: AppSpacing.sm,
          horizontal: AppSpacing.xs,
        ),
        child: Row(
          children: [
            SizedBox(
              width: 28,
              child: Text(
                '$rank',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ),
            CoverImage(
              path: stat.track.coverPath,
              url: stat.track.coverUrl,
              size: 44,
            ),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    stat.track.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodyLarge,
                  ),
                  Text(
                    stat.track.artist ?? '',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  '${stat.playCount}',
                  style: theme.textTheme.bodyLarge?.copyWith(
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                ),
                Text(
                  _formatListenTime(stat.listenTime),
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

String _formatListenTime(Duration duration) {
  final hours = duration.inHours;
  final minutes = duration.inMinutes % 60;
  if (hours > 0) return '${hours}h ${minutes}m';
  return '${minutes}m';
}
