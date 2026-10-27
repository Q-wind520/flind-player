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

import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:flind_player/app/theme/app_icons.dart';
import 'package:flind_player/core/models/lyric.dart';
import 'package:flind_player/core/models/track.dart';
import 'package:flind_player/data/providers/lyrics_providers.dart';
import 'package:flind_player/data/providers/playback_providers.dart';
import 'package:flind_player/l10n/app_localizations.dart';

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
class LyricsView extends ConsumerWidget {
  const LyricsView({super.key, this.onTap});

  /// Called when the pane is tapped.
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
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
      return _LyricsPlaceholder(l10n: l10n, track: track, onTap: onTap);
    }

    return _LyricsScroll(
      key: ValueKey<String>(track.uri),
      lyric: lyric,
      currentIndex: lyric.indexAt(position) ?? 0,
      onTap: onTap,
    );
  }
}

/// The auto-centring line list shared by [LyricsView] and [LyricsPreview].
///
/// The current line is centred by real geometry with [Scrollable.ensureVisible]
/// whenever it changes: a fixed per-line height estimate drifts as soon as a
/// line wraps or carries a translation, and the accumulated error eventually
/// scrolls the current line off-screen.
///
/// Every line is laid out in a non-lazy scroll view — `ensureVisible` cannot
/// reach a sliver child that has not been built yet, and `ListView` is lazy
/// even with an explicit child list. Lyrics are bounded (no word-by-word), so
/// laying them all out is cheap and keeps centring exact.
class _LyricsScroll extends StatefulWidget {
  const _LyricsScroll({
    super.key,
    required this.lyric,
    required this.currentIndex,
    this.onTap,
    this.compact = false,
    this.verticalPadding = 0,
  });

  final Lyric lyric;

  /// Index of the line covering the playback position.
  final int currentIndex;

  /// Called when the list is tapped.
  final VoidCallback? onTap;

  /// Compact preview typography, spacing and translations.
  final bool compact;

  /// Space above and below the list so the first and last lines can still be
  /// centred in a short viewport.
  final double verticalPadding;

  @override
  State<_LyricsScroll> createState() => _LyricsScrollState();
}

class _LyricsScrollState extends State<_LyricsScroll> {
  /// Attached to the current line so it can be centred by real geometry.
  final GlobalKey _currentLineKey = GlobalKey();
  int? _lastCentredIndex;

  @override
  void didUpdateWidget(covariant _LyricsScroll oldWidget) {
    super.didUpdateWidget(oldWidget);
    // A new lyric (another track, a late translation) must re-centre even when
    // the index happens to be unchanged.
    if (!identical(oldWidget.lyric, widget.lyric)) _lastCentredIndex = null;
  }

  /// Centres the current line once per index change.
  void _centreCurrentLine(int index) {
    if (_lastCentredIndex == index) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final lineContext = _currentLineKey.currentContext;
      if (lineContext == null) return;
      _lastCentredIndex = index;
      Scrollable.ensureVisible(
        lineContext,
        alignment: 0.5,
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOut,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    _centreCurrentLine(widget.currentIndex);

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: widget.onTap,
      child: _hideScrollbar(
        context,
        SingleChildScrollView(
          padding: EdgeInsets.symmetric(vertical: widget.verticalPadding),
          child: Column(
            children: <Widget>[
              for (var index = 0; index < widget.lyric.lines.length; index++)
                _LyricLineTile(
                  key: index == widget.currentIndex ? _currentLineKey : null,
                  line: widget.lyric.lines[index],
                  isCurrent: index == widget.currentIndex,
                  compact: widget.compact,
                  theme: theme,
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// One lyric row: the line, plus its translation when present.
class _LyricLineTile extends StatelessWidget {
  const _LyricLineTile({
    super.key,
    required this.line,
    required this.isCurrent,
    required this.theme,
    this.compact = false,
  });

  final LyricLine line;
  final bool isCurrent;
  final ThemeData theme;

  /// Compact preview rendering: smaller neighbours, no neighbour translation.
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final scheme = theme.colorScheme;
    // A rolling preview shows several lines at once; their translations would
    // double its density, so only the current line keeps its translation.
    final showTranslation =
        line.translation != null && (isCurrent || !compact);

    return Container(
      key: isCurrent ? const ValueKey<String>('lyric-current') : null,
      // Span the pane so [CrossAxisAlignment.center] centres on the screen, not
      // on a shrink-wrapped block that hugs the left edge.
      width: double.infinity,
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 20 : 24,
        vertical: compact ? 6 : 10,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: <Widget>[
          Text(
            line.text,
            textAlign: TextAlign.center,
            style:
                (compact && !isCurrent
                        ? theme.textTheme.bodyMedium
                        : theme.textTheme.titleMedium)
                    ?.copyWith(
                      color: isCurrent
                          ? scheme.primary
                          : compact
                          ? scheme.onSurfaceVariant.withValues(alpha: 0.66)
                          : scheme.onSurfaceVariant,
                      fontWeight: isCurrent
                          ? FontWeight.w600
                          : FontWeight.w400,
                    ),
          ),
          if (showTranslation)
            Text(
              line.translation!,
              textAlign: TextAlign.center,
              style: theme.textTheme.bodySmall?.copyWith(
                color: compact
                    ? scheme.onSurfaceVariant.withValues(alpha: 0.8)
                    : scheme.onSurfaceVariant,
              ),
            ),
        ],
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
          return _hideScrollbar(
            context,
            SingleChildScrollView(
              child: ConstrainedBox(
                constraints: BoxConstraints(minHeight: constraints.maxHeight),
                child: Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          AppIcons.lyrics,
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
            ),
          );
        },
      ),
    );
  }
}

/// Compact teaser strip: a rolling, time-synced lyric window.
///
/// Fills its parent (the flexible slot between the portrait cover and the
/// progress bar) and shows the lines around the playback position: the current
/// line highlighted and centred, its neighbours dimmed, both edges faded into
/// the backdrop. The window auto-scrolls with the playback position and can be
/// scrolled by hand. With lyrics available it is the same auto-centring list as
/// [LyricsView], only compact; without them it falls back to the "词莫见，敬聆听"
/// placeholder. Tapping it calls [onTap] to expand the lyrics page.
///
/// A vertical drag belongs to the scroll view; the surrounding portrait pager
/// only claims horizontal drags, so paging and hand-scrolling coexist.
class LyricsPreview extends ConsumerWidget {
  const LyricsPreview({super.key, this.onTap});

  /// Called when the strip is tapped.
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final playback = ref.watch(playbackStateProvider).value;
    final track = playback?.currentTrack;
    final position = playback?.position ?? Duration.zero;
    final lyric = track == null
        ? null
        : ref.watch(trackLyricsProvider(track)).value;

    if (track == null || lyric == null || lyric.lines.isEmpty) {
      return _LyricsPreviewPlaceholder(l10n: l10n, onTap: onTap);
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        // Half a viewport of padding lets the first and last lines reach the
        // centre; a line of slack is subtracted so the window does not gain an
        // empty screen of scroll extent at the very ends.
        final padding = math.max(0.0, constraints.maxHeight / 2 - 24);
        return ShaderMask(
          blendMode: BlendMode.dstIn,
          shaderCallback: (rect) => const LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Colors.transparent,
              Colors.white,
              Colors.white,
              Colors.transparent,
            ],
            stops: [0, 0.16, 0.84, 1],
          ).createShader(rect),
          child: _LyricsScroll(
            key: ValueKey<String>(track.uri),
            lyric: lyric,
            currentIndex: lyric.indexAt(position) ?? 0,
            compact: true,
            verticalPadding: padding,
            onTap: onTap,
          ),
        );
      },
    );
  }
}

/// The one-line "no lyrics" state of the compact preview.
class _LyricsPreviewPlaceholder extends StatelessWidget {
  const _LyricsPreviewPlaceholder({required this.l10n, required this.onTap});

  final AppLocalizations l10n;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                AppIcons.lyrics,
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
          ),
        ),
      ),
    );
  }
}

/// Wraps [child] so its scroll view never paints a scrollbar.
///
/// Desktop's default `MaterialScrollBehavior` adds a scrollbar to every
/// scrollable; the lyrics pane is a passive, auto-centring view where a
/// scrollbar is visual noise.
Widget _hideScrollbar(BuildContext context, Widget child) =>
    ScrollConfiguration(
      behavior: ScrollConfiguration.of(context).copyWith(scrollbars: false),
      child: child,
    );
