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
import 'package:flind_player/data/providers/lyrics_providers.dart';
import 'package:flind_player/data/providers/playback_providers.dart';
import 'package:flind_player/l10n/app_localizations.dart';
import 'package:flind_player/shared/app_surface.dart';

/// Full-area lyrics pane: a scrollable, time-synced lyric list for the
/// current track.
///
/// Watches [playbackStateProvider] for the current track and position and
/// [trackLyricsProvider] for its lyrics. The line covering the playback
/// position is highlighted and carries the `lyric-current` key; the view
/// auto-scrolls to keep it centred. Lines with a translation render it as a
/// secondary line underneath. Tapping the area invokes [onTap] (used to
/// collapse the expanded portrait lyrics pane).
///
/// While there is no track, no lyric, or an empty lyric, the previous
/// placeholder is shown instead.
class LyricsView extends ConsumerStatefulWidget {
  const LyricsView({super.key, this.onTap});

  /// Called when the pane is tapped.
  final VoidCallback? onTap;

  @override
  ConsumerState<LyricsView> createState() => _LyricsViewState();
}

class _LyricsViewState extends ConsumerState<LyricsView> {
  /// Estimated pixel extent of one lyric line, used to centre the current
  /// line while auto-scrolling. Close enough for the common one-line case;
  /// a line with a translation simply lands slightly off-centre.
  static const double _lineExtent = 56;

  final ScrollController _controller = ScrollController();
  int? _lastIndex;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  /// Scrolls [index] to the centre of the viewport once per index change.
  void _scheduleScroll(int index) {
    if (_lastIndex == index) return;
    _lastIndex = index;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_controller.hasClients) return;
      final target = (index * _lineExtent) -
          (_controller.position.viewportDimension / 2) +
          (_lineExtent / 2);
      _controller.animateTo(
        target.clamp(0.0, _controller.position.maxScrollExtent),
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOut,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);
    final playback = ref.watch(playbackStateProvider).value;
    final track = playback?.currentTrack;
    final position = playback?.position ?? Duration.zero;
    // Only watch the family when a track exists; the placeholder decides
    // between "source not adapted" and "no lyrics for this track" itself.
    final lyric = track == null
        ? null
        : ref.watch(trackLyricsProvider(track)).value;

    if (track == null || lyric == null || lyric.lines.isEmpty) {
      return _LyricsPlaceholder(l10n: l10n, track: track, onTap: widget.onTap);
    }

    final currentIndex = lyric.indexAt(position) ?? 0;
    _scheduleScroll(currentIndex);

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: widget.onTap,
      child: ListView.builder(
        controller: _controller,
        itemCount: lyric.lines.length,
        itemBuilder: (context, index) {
          final line = lyric.lines[index];
          final isCurrent = index == currentIndex;
          return Container(
            key: isCurrent ? const ValueKey<String>('lyric-current') : null,
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  line.text,
                  style: theme.textTheme.titleMedium?.copyWith(
                    color: isCurrent
                        ? theme.colorScheme.primary
                        : theme.colorScheme.onSurfaceVariant,
                    fontWeight: isCurrent ? FontWeight.w600 : FontWeight.w400,
                  ),
                ),
                if (line.translation != null)
                  Text(
                    line.translation!,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
              ],
            ),
          );
        },
      ),
    );
  }
}

/// Full-area placeholder shown while there are no lyrics to display.
///
/// Fills its parent, scrolls instead of overflowing on short viewports, and
/// shows the "词莫见，敬聆听" placeholder prominently. The second line reads
/// "暂无歌词" when [track]'s source can supply lyrics (the track simply has
/// none) and "该音源暂未适配歌词" otherwise. Tapping the area invokes [onTap].
class _LyricsPlaceholder extends ConsumerWidget {
  const _LyricsPlaceholder({
    required this.l10n,
    required this.track,
    required this.onTap,
  });

  final AppLocalizations l10n;

  /// The track whose lyrics are missing, or `null` when nothing plays.
  final Track? track;

  /// Called when the placeholder area is tapped.
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    // Guarded by `track != null`: a missing track says nothing about any
    // source's lyrics capability, so the source falls back to the generic
    // "not adapted" hint. A local copy keeps the null check promotable.
    final currentTrack = track;
    final supportsLyrics =
        currentTrack != null &&
        ref.watch(sourceSupportsLyricsProvider(currentTrack.source));

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: LayoutBuilder(
        builder: (context, constraints) {
          return SingleChildScrollView(
            child: ConstrainedBox(
              constraints: BoxConstraints(minHeight: constraints.maxHeight),
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.lyrics_outlined,
                        size: 56,
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        l10n.lyricsUnavailable,
                        style: theme.textTheme.titleLarge,
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        supportsLyrics
                            ? l10n.lyricsNotFound
                            : l10n.lyricsPlaceholderHint,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

/// Compact teaser strip: the current lyric line for the current track.
///
/// Fills its parent (typically the 5-line portrait slot) and scrolls instead
/// of overflowing on very short viewports. With lyrics available it shows the
/// line covering the playback position plus its translation; without them it
/// falls back to the "词莫见，敬聆听" placeholder. Tapping it calls [onTap] to
/// expand the lyrics pane. A plain [GestureDetector] keeps the strip free of
/// hover/focus highlights.
class LyricsPreview extends ConsumerWidget {
  const LyricsPreview({super.key, this.onTap});

  /// Called when the strip is tapped.
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);
    final playback = ref.watch(playbackStateProvider).value;
    final track = playback?.currentTrack;
    final position = playback?.position ?? Duration.zero;
    final lyric = track == null
        ? null
        : ref.watch(trackLyricsProvider(track)).value;
    final line = lyric == null || lyric.lines.isEmpty
        ? null
        : lyric.lines[lyric.indexAt(position) ?? 0];

    return AppSurface(
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: LayoutBuilder(
          builder: (context, constraints) {
            return SingleChildScrollView(
              child: ConstrainedBox(
                constraints: BoxConstraints(minHeight: constraints.maxHeight),
                child: Center(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 8,
                    ),
                    child: line == null
                        ? Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.lyrics_outlined,
                                size: 22,
                                color: theme.colorScheme.onSurfaceVariant,
                              ),
                              const SizedBox(height: 4),
                              Text(
                                l10n.lyricsUnavailable,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: theme.textTheme.titleMedium?.copyWith(
                                  color: theme.colorScheme.onSurfaceVariant,
                                ),
                              ),
                            ],
                          )
                        : Column(
                            mainAxisSize: MainAxisSize.min,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                line.text,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: theme.textTheme.titleMedium?.copyWith(
                                  color: theme.colorScheme.primary,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              if (line.translation != null)
                                Text(
                                  line.translation!,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: theme.textTheme.bodySmall?.copyWith(
                                    color: theme.colorScheme.onSurfaceVariant,
                                  ),
                                ),
                            ],
                          ),
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}
