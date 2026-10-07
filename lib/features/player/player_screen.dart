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

// Flutter 3.47 exports its own `RepeatMode` (for `RepeatingAnimationBuilder`),
// which collides with the playback model of the same name.
import 'package:flutter/material.dart' hide RepeatMode;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:flind_player/app/theme/app_tokens.dart';
import 'package:flind_player/core/models/playback_state.dart';
import 'package:flind_player/core/models/track.dart';
import 'package:flind_player/data/providers/playback_providers.dart';
import 'package:flind_player/data/providers/persistence_providers.dart';
import 'package:flind_player/features/player/lyrics_view.dart';
import 'package:flind_player/features/player/mini_settings.dart';
import 'package:flind_player/features/player/player_panels.dart';
import 'package:flind_player/shared/app_surface.dart';
import 'package:flind_player/l10n/app_localizations.dart';
import 'package:flind_player/shared/cover_image.dart';
import 'package:flind_player/shared/duration_format.dart';
import 'package:flind_player/shared/empty_state.dart';

/// The "now playing" screen: artwork, progress and transport controls.
///
/// Shown full-screen on every platform. The whole body sits on a single
/// [AppSurface]; the collapse button and the current track title and artist
/// live in a header row above the content so the same layout works in both
/// orientations.
class PlayerScreen extends StatelessWidget {
  const PlayerScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: AppSurface(child: SafeArea(child: const PlayerView())),
    );
  }
}

/// The core now-playing content: artwork, progress and transport controls.
///
/// Embedded by [PlayerScreen] as the full-screen body without duplicating the
/// layout in the route that opens it. Owns two UI states: the volume overlay
/// and the portrait lyrics pane.
class PlayerView extends ConsumerStatefulWidget {
  const PlayerView({super.key});

  @override
  ConsumerState<PlayerView> createState() => _PlayerViewState();
}

class _PlayerViewState extends ConsumerState<PlayerView> {
  /// Whether the volume overlay is open above the settings bar.
  bool _volumeOpen = false;

  /// Whether the portrait body shows lyrics instead of the cover.
  bool _lyricsExpanded = false;

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(playbackStateProvider).value;
    final track = state?.currentTrack;
    final l10n = AppLocalizations.of(context);
    final title = track?.title ?? '';
    final artist = track == null ? '' : (track.artist ?? l10n.unknownArtist);

    return LayoutBuilder(
      builder: (context, constraints) {
        final landscape = constraints.maxWidth > constraints.maxHeight;
        final hasTrack = state != null && track != null;

        final Widget body;
        if (!hasTrack) {
          body = EmptyState(
            icon: Icons.play_circle_outline,
            title: AppLocalizations.of(context).notPlaying,
            message: AppLocalizations.of(context).notPlayingHint,
          );
        } else if (landscape) {
          body = _LandscapeBody(
            state: state,
            track: track,
            onVolumeTap: () => setState(() => _volumeOpen = true),
          );
        } else {
          body = _PortraitBody(
            state: state,
            track: track,
            lyricsExpanded: _lyricsExpanded,
            onLyricsTap: () => setState(() => _lyricsExpanded = true),
            onLyricsCollapse: () => setState(() => _lyricsExpanded = false),
          );
        }

        // The settings slot is hidden while the portrait lyrics page is
        // expanded and whenever nothing is playing.
        final settingsVisible = hasTrack && !(!landscape && _lyricsExpanded);

        // The volume overlay can only exist while its slot is visible; if the
        // slot disappears (lyrics page, no track) the overlay must close.
        if (!settingsVisible && _volumeOpen) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted && _volumeOpen) {
              setState(() => _volumeOpen = false);
            }
          });
        }
        final volumeOpen = _volumeOpen && settingsVisible;

        return Stack(
          children: [
            Column(
              children: [
                // The header spans both panes in landscape and sits above the
                // whole portrait body, so the title and artist stay visible on
                // the lyrics page too.
                _HeaderRow(title: title, artist: artist),
                Expanded(child: body),
                // Portrait docks MiniSettings at the bottom of the screen;
                // landscape embeds it in the left pane instead.
                if (!landscape)
                  AnimatedSize(
                    duration: const Duration(milliseconds: 220),
                    curve: Curves.easeOutCubic,
                    alignment: Alignment.topCenter,
                    child: settingsVisible
                        ? MiniSettings(
                            key: const ValueKey('mini_settings'),
                            onVolumeTap: () =>
                                setState(() => _volumeOpen = true),
                          )
                        : const SizedBox(width: double.infinity),
                  ),
              ],
            ),
            // Volume overlay: a full-area scrim plus the volume bar exactly
            // over the settings slot.
            Positioned.fill(
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 220),
                switchInCurve: Curves.easeOutCubic,
                switchOutCurve: Curves.easeInCubic,
                transitionBuilder: (child, animation) {
                  return FadeTransition(
                    opacity: animation,
                    child: SlideTransition(
                      position: Tween<Offset>(
                        begin: const Offset(0, 0.1),
                        end: Offset.zero,
                      ).animate(animation),
                      child: child,
                    ),
                  );
                },
                child: volumeOpen
                    ? Stack(
                        key: const ValueKey('volume_overlay'),
                        fit: StackFit.expand,
                        children: [
                          GestureDetector(
                            behavior: HitTestBehavior.opaque,
                            onTap: () => setState(() => _volumeOpen = false),
                          ),
                          Positioned(
                            left: 0,
                            bottom: 0,
                            right: landscape ? null : 0,
                            width: landscape ? constraints.maxWidth / 2 : null,
                            height: kMiniSettingsHeight,
                            child: const VolumeBar(),
                          ),
                        ],
                      )
                    : const SizedBox.shrink(key: ValueKey('no_volume')),
              ),
            ),
          ],
        );
      },
    );
  }
}

/// The top row of the player content: the collapse (hide) button and the
/// current track title and artist. Replaces the former [AppBar] so the same
/// header works in both orientations and on the lyrics page.
class _HeaderRow extends StatelessWidget {
  const _HeaderRow({required this.title, required this.artist});

  /// The track title to show; empty when nothing is playing.
  final String title;

  /// The artist to show; empty when nothing is playing.
  final String artist;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      children: [
        IconButton(
          icon: const Icon(Icons.keyboard_arrow_down),
          onPressed: () => Navigator.of(context).maybePop(),
        ),
        Expanded(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              Text(
                artist,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
        // Balances the leading IconButton so the centred title/artist block
        // is truly screen-centred.
        const SizedBox(width: 48),
      ],
    );
  }
}

/// Portrait body: cover, a 5-line lyrics teaser, then progress and transport.
/// When [lyricsExpanded] the cover and teaser are replaced by the full
/// [LyricsView] while progress and transport stay pinned at the bottom.
class _PortraitBody extends StatelessWidget {
  const _PortraitBody({
    required this.state,
    required this.track,
    required this.lyricsExpanded,
    required this.onLyricsTap,
    required this.onLyricsCollapse,
  });

  final PlaybackState state;
  final Track track;
  final bool lyricsExpanded;
  final VoidCallback onLyricsTap;
  final VoidCallback onLyricsCollapse;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Expanded(
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 260),
            switchInCurve: Curves.easeOutCubic,
            switchOutCurve: Curves.easeInCubic,
            transitionBuilder: (child, animation) {
              return FadeTransition(
                opacity: animation,
                child: SlideTransition(
                  position: Tween<Offset>(
                    begin: const Offset(0, 0.08),
                    end: Offset.zero,
                  ).animate(animation),
                  child: child,
                ),
              );
            },
            child: lyricsExpanded
                ? LyricsView(
                    key: const ValueKey('lyrics'),
                    onTap: onLyricsCollapse,
                  )
                : _PortraitNormal(
                    key: const ValueKey('normal'),
                    track: track,
                    onLyricsTap: onLyricsTap,
                  ),
          ),
        ),
        _ProgressBar(state: state),
        _TransportControls(state: state),
        // A larger gap before the docked MiniSettings so the controls and the
        // settings bar read as two separated rows; the expanded lyrics page
        // keeps the transport clear of the very bottom instead.
        SizedBox(height: lyricsExpanded ? 24 : 16),
      ],
    );
  }
}

/// The collapsed portrait content: adaptive cover and the 5-line lyrics
/// teaser strip. The title and artist live in the shared header row.
class _PortraitNormal extends StatelessWidget {
  const _PortraitNormal({
    super.key,
    required this.track,
    required this.onLyricsTap,
  });

  final Track track;
  final VoidCallback onLyricsTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    // Five lines of the lyrics text style, so the strip reads as a teaser of
    // the lyrics page rather than an arbitrary fraction of the viewport.
    final lyricsStyle = theme.textTheme.titleMedium;
    final lineHeight =
        (lyricsStyle?.fontSize ?? 16) * (lyricsStyle?.height ?? 1.4);
    final lyricsStripHeight = lineHeight * 5 * 2;
    return Column(
      children: [
        Expanded(child: _CoverArt(track: track)),
        SizedBox(
          height: lyricsStripHeight,
          child: LyricsPreview(onTap: onLyricsTap),
        ),
      ],
    );
  }
}

/// Landscape body: two equal panes — the left [MiniMain] and the full-height
/// [LyricsView] on the right. The shared header row above both panes is
/// rendered by the parent. No divider: both panes share the same
/// [AppSurface] background.
class _LandscapeBody extends StatelessWidget {
  const _LandscapeBody({
    required this.state,
    required this.track,
    required this.onVolumeTap,
  });

  final PlaybackState state;
  final Track track;
  final VoidCallback onVolumeTap;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: MiniMain(state: state, track: track, onVolumeTap: onVolumeTap),
        ),
        Expanded(child: LyricsView()),
      ],
    );
  }
}

/// The edge length of the square cover art that fits [constraints].
///
/// Both the landscape left pane and the portrait cover use this single
/// formula: the artwork is 65 % of the smaller available edge, leaving a
/// ~17.5 % breathing margin on each side. A higher fraction made the cover
/// crowd the pane at 4:3 / 9:16 windows. The 80 px floor is itself bounded by
/// [edge] so a tiny pane still lays out. The 480 px ceiling keeps the artwork
/// from dominating a very large window.
double _coverSizeFor(BoxConstraints constraints) {
  final edge = math.min(constraints.maxWidth, constraints.maxHeight);
  return (edge * 0.65).clamp(math.min(80.0, edge), 480.0);
}

/// The landscape left pane: cover, progress, transport and the docked
/// [MiniSettings]. The track title and artist live in the shared header row
/// above both panes.
///
/// The cover lives in an [Expanded] so it shrinks with the window.
class MiniMain extends StatelessWidget {
  const MiniMain({
    super.key,
    required this.state,
    required this.track,
    required this.onVolumeTap,
  });

  final PlaybackState state;
  final Track track;
  final VoidCallback onVolumeTap;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Expanded(
          child: LayoutBuilder(
            builder: (context, coverConstraints) {
              return Center(
                child: _PlayerCover(
                  track: track,
                  size: _coverSizeFor(coverConstraints),
                ),
              );
            },
          ),
        ),
        _ProgressBar(state: state),
        _TransportControls(state: state),
        // Same gap as portrait: keep the controls and the settings bar apart.
        const SizedBox(height: 16),
        MiniSettings(onVolumeTap: onVolumeTap),
      ],
    );
  }
}

/// Centred cover art that scales with the available space.
///
/// The cover uses the same [_coverSizeFor] formula as the landscape pane, so
/// it grows with the smaller window edge; the fixed 24 px horizontal padding
/// keeps it clear of the screen edges.
class _CoverArt extends StatelessWidget {
  const _CoverArt({required this.track});

  final Track track;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        return Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
            child: _PlayerCover(track: track, size: _coverSizeFor(constraints)),
          ),
        );
      },
    );
  }
}

/// Large rounded cover art with a tonal music-note placeholder.
class _PlayerCover extends StatelessWidget {
  const _PlayerCover({required this.track, required this.size});

  final Track track;
  final double size;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final coverPath = track.coverPath;
    final coverUrl = track.coverUrl;
    final hasCover =
        (coverPath != null && coverPath.isNotEmpty) ||
        (coverUrl != null && coverUrl.isNotEmpty);

    return ClipRRect(
      borderRadius: BorderRadius.circular(AppRadius.xl),
      child: Container(
        width: size,
        height: size,
        color: scheme.surfaceContainerHighest,
        child: hasCover
            ? CoverImage(
                path: coverPath,
                url: coverUrl,
                size: size,
                errorBuilder: (context, error, stackTrace) =>
                    _placeholder(scheme),
              )
            : _placeholder(scheme),
      ),
    );
  }

  Widget _placeholder(ColorScheme scheme) =>
      Icon(Icons.music_note, size: size * 0.4, color: scheme.onSurfaceVariant);
}

/// Seekable progress bar with `m:ss` labels on both sides of the slider.
///
/// The slider tracks the drag locally so the thumb follows the finger while
/// dragging; the seek is issued once on release.
class _ProgressBar extends ConsumerStatefulWidget {
  const _ProgressBar({required this.state});

  final PlaybackState state;

  @override
  ConsumerState<_ProgressBar> createState() => _ProgressBarState();
}

class _ProgressBarState extends ConsumerState<_ProgressBar> {
  /// In-flight drag position in milliseconds, or `null` when not dragging.
  double? _dragMs;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final state = widget.state;
    final durationMs = state.duration?.inMilliseconds ?? 0;
    final enabled = durationMs > 0;
    final maxValue = enabled ? durationMs.toDouble() : 1.0;
    final positionValue = enabled
        ? state.position.inMilliseconds.clamp(0, durationMs).toDouble()
        : 0.0;
    final dragMs = _dragMs;
    final shownPosition = dragMs == null
        ? state.position
        : Duration(milliseconds: dragMs.round());

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: Row(
        children: [
          Text(
            formatTrackDuration(shownPosition),
            style: theme.textTheme.labelMedium,
          ),
          Expanded(
            child: SliderTheme(
              data: SliderTheme.of(context).copyWith(
                trackHeight: 2,
                thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
                overlayShape: const RoundSliderOverlayShape(overlayRadius: 14),
              ),
              child: Slider(
                value: dragMs ?? positionValue,
                max: maxValue,
                onChanged: enabled
                    ? (value) => setState(() => _dragMs = value)
                    : null,
                onChangeEnd: enabled
                    ? (value) {
                        setState(() => _dragMs = null);
                        ref
                            .read(playbackControllerProvider)
                            .seek(Duration(milliseconds: value.round()));
                      }
                    : null,
              ),
            ),
          ),
          Text(
            formatTrackDuration(state.duration),
            style: theme.textTheme.labelMedium,
          ),
        ],
      ),
    );
  }
}

/// Favourite / previous / play-pause / next / playlist controls.
///
/// The five controls sit grouped in the centre rather than stretched
/// edge-to-edge, in a three-step size hierarchy that highlights play/pause
/// (64 px) over previous/next (52 px) and the favourite/playlist assists
/// (44 px). Narrow panes drop to an all-44 layout so the row cannot overflow;
/// the play-mode cycler lives in [MiniSettings] below.
class _TransportControls extends ConsumerWidget {
  const _TransportControls({required this.state});

  final PlaybackState state;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final controller = ref.read(playbackControllerProvider);
    final track = state.currentTrack;
    final scheme = Theme.of(context).colorScheme;
    // The M3 default padded tap target would force every button to at least
    // 48 px and blow the compact 236 px row; shrink it so the tight sizes
    // below are honoured exactly.
    final tapTargetStyle = IconButton.styleFrom(
      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
    );

    // A three-step size hierarchy highlights play/pause and keeps the row
    // grouped in the centre (never spaceBetween). Comfortable widths get the
    // 316 px layout; anything narrower — e.g. the 240 px landscape left pane
    // at 480×320 — falls back to all-44 with 4 px gaps (236 px) so the row
    // can never overflow.
    return LayoutBuilder(
      builder: (context, constraints) {
        final comfortable = constraints.maxWidth >= 340;
        final playSize = comfortable ? 64.0 : 44.0;
        final skipSize = comfortable ? 52.0 : 44.0;
        const assistSize = 44.0;
        final outerGap = comfortable ? 20.0 : 4.0;
        final innerGap = comfortable ? 10.0 : 4.0;
        final playIcon = comfortable ? 36.0 : 32.0;
        final skipIcon = comfortable ? 32.0 : 28.0;
        final assistIcon = comfortable ? 26.0 : 22.0;

        return Row(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.max,
          children: [
            if (track == null)
              const SizedBox.shrink()
            else
              _FavoriteButton(
                track: track,
                size: assistSize,
                iconSize: assistIcon,
              ),
            SizedBox(width: outerGap),
            IconButton(
              onPressed: state.hasPrevious ? controller.previous : null,
              icon: const Icon(Icons.skip_previous),
              iconSize: skipIcon,
              style: tapTargetStyle,
              padding: EdgeInsets.zero,
              constraints: BoxConstraints.tightFor(
                width: skipSize,
                height: skipSize,
              ),
            ),
            SizedBox(width: innerGap),
            IconButton.filled(
              onPressed: controller.togglePlayPause,
              icon: Icon(state.isPlaying ? Icons.pause : Icons.play_arrow),
              iconSize: playIcon,
              style: tapTargetStyle,
              padding: EdgeInsets.zero,
              constraints: BoxConstraints.tightFor(
                width: playSize,
                height: playSize,
              ),
            ),
            SizedBox(width: innerGap),
            IconButton(
              onPressed: state.hasNext ? controller.next : null,
              icon: const Icon(Icons.skip_next),
              iconSize: skipIcon,
              style: tapTargetStyle,
              padding: EdgeInsets.zero,
              constraints: BoxConstraints.tightFor(
                width: skipSize,
                height: skipSize,
              ),
            ),
            SizedBox(width: outerGap),
            IconButton(
              onPressed: () => showPlayerPanel<void>(
                context,
                builder: (_) => const PlaylistPanel(),
              ),
              icon: const Icon(Icons.queue_music),
              iconSize: assistIcon,
              color: scheme.onSurfaceVariant,
              style: tapTargetStyle,
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints.tightFor(
                width: assistSize,
                height: assistSize,
              ),
            ),
          ],
        );
      },
    );
  }
}

/// Heart toggle for the current track in the player transport area.
///
/// Hidden when nothing is playing (no track). The filled heart is always red,
/// regardless of the theme, so a favourited track reads the same in light and
/// dark mode; the un-favourited outline is muted like the other assists.
class _FavoriteButton extends ConsumerWidget {
  const _FavoriteButton({
    required this.track,
    required this.size,
    required this.iconSize,
  });

  final Track track;

  /// The diameter of the round tap target.
  final double size;

  /// The icon glyph size inside the tap target.
  final double iconSize;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isFavourite = ref.watch(isFavoriteProvider(track.uri)).value ?? false;
    final l10n = AppLocalizations.of(context);
    final scheme = Theme.of(context).colorScheme;

    return IconButton(
      onPressed: () async {
        final repo = ref.read(favoritesRepositoryProvider);
        final isNowFavourite = await repo.toggleFavorite(track);
        if (context.mounted) {
          ScaffoldMessenger.of(context)
            ..hideCurrentSnackBar()
            ..showSnackBar(
              SnackBar(
                content: Text(
                  isNowFavourite ? l10n.favorited : l10n.unfavorited,
                ),
                duration: const Duration(seconds: 1),
              ),
            );
        }
      },
      icon: Icon(isFavourite ? Icons.favorite : Icons.favorite_border),
      iconSize: iconSize,
      // Active favourites use the theme's error role; the inactive heart is a
      // muted assist control, matching the playlist button.
      color: isFavourite ? scheme.error : scheme.onSurfaceVariant,
      style: IconButton.styleFrom(
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
      ),
      padding: EdgeInsets.zero,
      constraints: BoxConstraints.tightFor(width: size, height: size),
    );
  }
}
