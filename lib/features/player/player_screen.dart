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

import 'package:flind_player/app/theme/app_theme.dart';
import 'package:flind_player/core/models/playback_state.dart';
import 'package:flind_player/core/models/repeat_mode.dart';
import 'package:flind_player/core/models/track.dart';
import 'package:flind_player/data/providers/playback_providers.dart';
import 'package:flind_player/data/providers/persistence_providers.dart';
import 'package:flind_player/features/player/lyrics_view.dart';
import 'package:flind_player/features/player/mini_settings.dart';
import 'package:flind_player/shared/app_surface.dart';
import 'package:flind_player/l10n/app_localizations.dart';
import 'package:flind_player/shared/cover_image.dart';
import 'package:flind_player/shared/duration_format.dart';
import 'package:flind_player/shared/responsive_center.dart';

/// The "now playing" screen: artwork, progress and transport controls.
///
/// Shown full-screen on every platform. The whole body sits on a single
/// [AppSurface]; the collapse button and the current artist live in a
/// header row inside the content so the same layout works in both
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
    final artist = track == null ? '' : (track.artist ?? l10n.unknownArtist);

    return LayoutBuilder(
      builder: (context, constraints) {
        final landscape = constraints.maxWidth > constraints.maxHeight;
        final hasTrack = state != null && track != null;

        final Widget body;
        if (!hasTrack) {
          body = Column(
            children: [
              _HeaderRow(artist: ''),
              const Expanded(child: _NothingPlaying()),
            ],
          );
        } else if (landscape) {
          body = _LandscapeBody(
            state: state,
            track: track,
            artist: artist,
            onVolumeTap: () => setState(() => _volumeOpen = true),
          );
        } else {
          body = _PortraitBody(
            state: state,
            track: track,
            artist: artist,
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
/// current artist. Replaces the former [AppBar] so the same header works in
/// both orientations and on the lyrics page.
class _HeaderRow extends StatelessWidget {
  const _HeaderRow({required this.artist});

  /// The artist to show; empty when nothing is playing.
  final String artist;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        IconButton(
          icon: const Icon(Icons.keyboard_arrow_down),
          onPressed: () => Navigator.of(context).maybePop(),
        ),
        Expanded(
          child: Text(
            artist,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.titleLarge,
          ),
        ),
      ],
    );
  }
}

/// Portrait body: header, title, cover, a 25%-height lyrics teaser, then
/// progress and transport. When [lyricsExpanded] the title/cover/teaser are
/// replaced by the full [LyricsView] while progress and transport stay pinned
/// at the bottom.
class _PortraitBody extends StatelessWidget {
  const _PortraitBody({
    required this.state,
    required this.track,
    required this.artist,
    required this.lyricsExpanded,
    required this.onLyricsTap,
    required this.onLyricsCollapse,
  });

  final PlaybackState state;
  final Track track;
  final String artist;
  final bool lyricsExpanded;
  final VoidCallback onLyricsTap;
  final VoidCallback onLyricsCollapse;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = AppBreakpoints.isCompact(constraints.biggest);
        final lyricsStripHeight = constraints.maxHeight * 0.25;
        return Column(
          children: [
            _HeaderRow(artist: artist),
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
                        compact: compact,
                        lyricsStripHeight: lyricsStripHeight,
                        onLyricsTap: onLyricsTap,
                      ),
              ),
            ),
            _ProgressBar(state: state),
            const SizedBox(height: 8),
            _TransportControls(state: state),
          ],
        );
      },
    );
  }
}

/// The collapsed portrait content: track title, adaptive cover and the
/// 25%-height lyrics teaser strip.
class _PortraitNormal extends StatelessWidget {
  const _PortraitNormal({
    super.key,
    required this.track,
    required this.compact,
    required this.lyricsStripHeight,
    required this.onLyricsTap,
  });

  final Track track;
  final bool compact;
  final double lyricsStripHeight;
  final VoidCallback onLyricsTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
          child: Text(
            track.title,
            style: theme.textTheme.titleLarge,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
          ),
        ),
        Expanded(
          child: _CoverArt(track: track, compact: compact),
        ),
        SizedBox(
          height: lyricsStripHeight,
          child: LyricsPreview(onTap: onLyricsTap),
        ),
      ],
    );
  }
}

/// Landscape body: two equal panes — the left [MiniMain] and the full-height
/// [LyricsView] on the right. No divider: both panes share the same
/// [AppSurface] background.
class _LandscapeBody extends StatelessWidget {
  const _LandscapeBody({
    required this.state,
    required this.track,
    required this.artist,
    required this.onVolumeTap,
  });

  final PlaybackState state;
  final Track track;
  final String artist;
  final VoidCallback onVolumeTap;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: MiniMain(
            state: state,
            track: track,
            artist: artist,
            onVolumeTap: onVolumeTap,
          ),
        ),
        Expanded(child: LyricsView()),
      ],
    );
  }
}

/// The landscape left pane: header, title, cover, progress, transport and the
/// docked [MiniSettings].
///
/// The cover lives in an [Expanded] so it shrinks with the window; the title
/// is hidden when vertical space is very small. The artist lives in the
/// header row instead of a separate bar.
class MiniMain extends StatelessWidget {
  const MiniMain({
    super.key,
    required this.state,
    required this.track,
    required this.artist,
    required this.onVolumeTap,
  });

  final PlaybackState state;
  final Track track;
  final String artist;
  final VoidCallback onVolumeTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return LayoutBuilder(
      builder: (context, constraints) {
        final showTitle = constraints.maxHeight >= 220;
        return Column(
          children: [
            _HeaderRow(artist: artist),
            if (showTitle)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Text(
                  track.title,
                  style: theme.textTheme.titleLarge,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                ),
              ),
            Expanded(
              child: LayoutBuilder(
                builder: (context, coverConstraints) {
                  final coverSize = math
                      .min(
                        coverConstraints.maxWidth * 0.7,
                        coverConstraints.maxHeight,
                      )
                      .clamp(80.0, 280.0);
                  return ResponsiveCenter(
                    child: _PlayerCover(track: track, size: coverSize),
                  );
                },
              ),
            ),
            _ProgressBar(state: state),
            _TransportControls(state: state),
            MiniSettings(onVolumeTap: onVolumeTap),
          ],
        );
      },
    );
  }
}

/// Centred cover art that scales with the available space, scroll-safe on
/// short viewports.
class _CoverArt extends StatelessWidget {
  const _CoverArt({required this.track, required this.compact});

  final Track track;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final coverSize = math
            .min(constraints.maxWidth * 0.7, constraints.maxHeight * 0.8)
            .clamp(80.0, 320.0);
        return ResponsiveCenter(
          child: Padding(
            padding: EdgeInsets.symmetric(
              horizontal: compact ? 24 : 48,
              vertical: 8,
            ),
            child: _PlayerCover(track: track, size: coverSize),
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
      borderRadius: BorderRadius.circular(24),
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

/// Seekable progress bar with `m:ss` labels on both sides.
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

    return Column(
      children: [
        Slider(
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
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8),
          child: Row(
            children: [
              Text(
                formatTrackDuration(shownPosition),
                style: theme.textTheme.labelMedium,
              ),
              const Spacer(),
              Text(
                formatTrackDuration(state.duration),
                style: theme.textTheme.labelMedium,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// Favourite / previous / play-pause / next / play-mode controls.
class _TransportControls extends ConsumerWidget {
  const _TransportControls({required this.state});

  final PlaybackState state;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;
    final controller = ref.read(playbackControllerProvider);
    final track = state.currentTrack;
    final mode = _PlayMode.fromState(state);

    // Five icon buttons never fit a 280 px-wide content column, so the row is
    // allowed to scale down as a whole instead of overflowing. Above its
    // intrinsic width the controls stay at full size.
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 420),
      child: FittedBox(
        fit: BoxFit.scaleDown,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            if (track != null) _FavoriteButton(track: track),
            IconButton(
              onPressed: state.hasPrevious ? controller.previous : null,
              icon: const Icon(Icons.skip_previous),
              iconSize: 36,
            ),
            IconButton.filled(
              onPressed: controller.togglePlayPause,
              icon: Icon(state.isPlaying ? Icons.pause : Icons.play_arrow),
              iconSize: 36,
            ),
            IconButton(
              onPressed: state.hasNext ? controller.next : null,
              icon: const Icon(Icons.skip_next),
              iconSize: 36,
            ),
            IconButton(
              onPressed: () {
                final next = mode.next;
                // Shuffle first so the queue is (un)shuffled before the
                // controller applies the new repeat mode.
                controller.setShuffle(next.shuffle);
                controller.setRepeatMode(next.repeat);
              },
              icon: Icon(mode.icon),
              color: mode.isActive ? scheme.primary : null,
            ),
          ],
        ),
      ),
    );
  }
}

/// Heart toggle for the current track in the player transport area.
///
/// Hidden when nothing is playing (no track).
class _FavoriteButton extends ConsumerWidget {
  const _FavoriteButton({required this.track});

  final Track track;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isFavourite =
        ref.watch(_playerFavoriteProvider(track.uri)).value ?? false;
    final scheme = Theme.of(context).colorScheme;
    final l10n = AppLocalizations.of(context);

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
      color: isFavourite ? scheme.primary : null,
    );
  }
}

/// Whether the track is favourited. Retries are disabled so errors surface
/// immediately.
final _playerFavoriteProvider = FutureProvider.family<bool, String>((ref, uri) {
  ref.watch(favoritesProvider);
  return ref.watch(favoritesRepositoryProvider).isFavorite(uri);
}, retry: (_, _) => null);

/// The playback modes cycled by the transport's single mode button.
///
/// Each mode maps to one `(repeatMode, shuffle)` pair on the controller.
enum _PlayMode {
  /// Plays through the queue once, in order.
  sequential(icon: Icons.playlist_play, repeat: RepeatMode.off, shuffle: false),

  /// Loops the whole queue.
  repeatAll(icon: Icons.repeat, repeat: RepeatMode.all, shuffle: false),

  /// Repeats the current track.
  repeatOne(icon: Icons.repeat_one, repeat: RepeatMode.one, shuffle: false),

  /// Shuffles the queue without repeating.
  shufflePlay(icon: Icons.shuffle, repeat: RepeatMode.off, shuffle: true);

  const _PlayMode({
    required this.icon,
    required this.repeat,
    required this.shuffle,
  });

  /// Icon shown on the button.
  final IconData icon;

  /// Repeat mode the controller is put into for this mode.
  final RepeatMode repeat;

  /// Whether the queue is shuffled in this mode.
  final bool shuffle;

  /// Whether this mode differs from plain sequential playback.
  bool get isActive => this != _PlayMode.sequential;

  /// The mode reached by the next tap, wrapping 随机 → 顺序.
  _PlayMode get next => switch (this) {
    _PlayMode.sequential => _PlayMode.repeatAll,
    _PlayMode.repeatAll => _PlayMode.repeatOne,
    _PlayMode.repeatOne => _PlayMode.shufflePlay,
    _PlayMode.shufflePlay => _PlayMode.sequential,
  };

  /// Derives the mode from [state]; shuffle takes precedence over repeat.
  static _PlayMode fromState(PlaybackState state) {
    if (state.shuffleEnabled) {
      return _PlayMode.shufflePlay;
    }
    return switch (state.repeatMode) {
      RepeatMode.off => _PlayMode.sequential,
      RepeatMode.all => _PlayMode.repeatAll,
      RepeatMode.one => _PlayMode.repeatOne,
    };
  }
}

/// Shown when nothing is loaded.
class _NothingPlaying extends StatelessWidget {
  const _NothingPlaying();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);
    return ResponsiveCenter(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.play_circle_outline,
              size: 64,
              color: theme.colorScheme.onSurfaceVariant,
            ),
            const SizedBox(height: 16),
            Text(l10n.notPlaying, style: theme.textTheme.titleMedium),
            const SizedBox(height: 8),
            Text(
              l10n.notPlayingHint,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
