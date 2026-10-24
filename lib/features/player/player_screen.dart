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
import 'dart:ui' show ImageFilter;

// Flutter 3.47 exports its own `RepeatMode` (for `RepeatingAnimationBuilder`),
// which collides with the playback model of the same name.
import 'package:flutter/material.dart' hide RepeatMode;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:flind_player/app/theme/app_icons.dart';
import 'package:flind_player/app/system_ui_overlay.dart';
import 'package:flind_player/app/theme/app_theme.dart';
import 'package:flind_player/app/theme/app_tokens.dart';
import 'package:flind_player/core/models/playback_state.dart';
import 'package:flind_player/core/models/track.dart';
import 'package:flind_player/core/services/playback_controller.dart';
import 'package:flind_player/data/providers/playback_providers.dart';
import 'package:flind_player/features/player/cover_viewer_screen.dart';
import 'package:flind_player/features/player/favorite_button.dart';
import 'package:flind_player/features/player/lyrics_view.dart';
import 'package:flind_player/features/player/mini_settings.dart';
import 'package:flind_player/features/player/player_panels.dart';
import 'package:flind_player/features/player/player_progress_bar.dart';
import 'package:flind_player/l10n/app_localizations.dart';
import 'package:flind_player/shared/cover_hero.dart';
import 'package:flind_player/shared/cover_image.dart';
import 'package:flind_player/shared/duration_format.dart';
import 'package:flind_player/shared/empty_state.dart';

/// The "now playing" screen: artwork, progress and transport controls.
///
/// Shown full-screen on every platform as a dark listening room, even when the
/// app itself is in light mode. The backdrop is the current cover blurred to a
/// low-frequency wash; the local dark theme keeps every control legible over
/// it without threading white-on-dark colours through individual widgets.
class PlayerScreen extends StatelessWidget {
  const PlayerScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final current = Theme.of(context);
    final playerTheme = current.brightness == Brightness.dark
        ? current
        : AppTheme.dark(current.colorScheme.primary);

    return Theme(
      data: playerTheme,
      child: AppSystemUiOverlay(
        child: Scaffold(
          // Transparent so the non-opaque route shows the app behind while the
          // dismiss drawer takes over the background.
          backgroundColor: Colors.transparent,
          body: BlockSemantics(
            child: _PlayerDismissWrapper(child: const PlayerView()),
          ),
        ),
      ),
    );
  }
}

/// The header drag handle that dismisses the player.
const Key playerDismissHandleKey = Key('player_dismiss_handle');

/// Provides the dismiss drag callbacks to the header.
class _PlayerDismissScope extends InheritedWidget {
  const _PlayerDismissScope({
    required this.onDrag,
    required this.onEnd,
    required super.child,
  });

  final void Function(double dyFraction) onDrag;
  final void Function(double velocity) onEnd;

  static _PlayerDismissScope? maybeOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<_PlayerDismissScope>();

  @override
  bool updateShouldNotify(_PlayerDismissScope oldWidget) => false;
}

/// Slides the player down with a header drag and pops on commit, dimming the
/// app behind (the route is non-opaque).
class _PlayerDismissWrapper extends StatefulWidget {
  const _PlayerDismissWrapper({required this.child});

  final Widget child;

  @override
  State<_PlayerDismissWrapper> createState() => _PlayerDismissWrapperState();
}

class _PlayerDismissWrapperState extends State<_PlayerDismissWrapper>
    with SingleTickerProviderStateMixin {
  /// 0 = resting, 1 = fully dismissed.
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: AppMotion.standard,
    value: 0,
  );

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  void _onDrag(double dyFraction) {
    _c.value = (_c.value + dyFraction).clamp(0.0, 1.0);
  }

  void _onEnd(double velocity) {
    if (_c.value > 0.4 || velocity > 700) {
      _c.animateTo(1, curve: AppMotion.emphasizedCurve).then((_) {
        if (mounted) Navigator.of(context).maybePop();
      });
    } else {
      _c.animateTo(0, curve: AppMotion.standardCurve);
    }
  }

  @override
  Widget build(BuildContext context) {
    return _PlayerDismissScope(
      onDrag: _onDrag,
      onEnd: _onEnd,
      child: AnimatedBuilder(
        animation: _c,
        builder: (context, child) {
          final height = MediaQuery.sizeOf(context).height;
          final progress = _c.value;
          // Round the player as soon as the drag starts so the reveal reads as
          // a sheet resting over the page, not a full-screen block that has
          // detached from it.
          final radius = BorderRadius.vertical(
            top: Radius.circular(
              28 *
                  Curves.easeOutCubic.transform((progress * 3).clamp(0.0, 1.0)),
            ),
          );
          return Stack(
            clipBehavior: Clip.none,
            children: [
              Positioned.fill(
                child: ColoredBox(
                  key: const Key('player_dismiss_scrim'),
                  color: Colors.black.withValues(alpha: 0.5 * progress),
                ),
              ),
              Positioned.fill(
                child: Transform.translate(
                  offset: Offset(0, progress * height),
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      borderRadius: radius,
                      boxShadow: progress > 0.001
                          ? [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.4),
                                blurRadius: 28,
                                offset: const Offset(0, -10),
                              ),
                            ]
                          : null,
                    ),
                    child: ClipRRect(
                      key: const Key('player_dismiss_surface'),
                      borderRadius: radius,
                      child: widget.child,
                    ),
                  ),
                ),
              ),
            ],
          );
        },
      ),
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

        // The volume control is a compact floating pill, centred in the pane
        // (the left half in landscape, the full width in portrait) rather than
        // stretching edge to edge like a second settings bar.
        final paneWidth = landscape
            ? constraints.maxWidth / 2
            : constraints.maxWidth;
        final volumeBarWidth = math.min(520.0, paneWidth - AppSpacing.lg * 2);
        final volumeBarLeft = (paneWidth - volumeBarWidth) / 2;

        final Widget body;
        if (!hasTrack) {
          body = EmptyState(
            icon: AppIcons.playCircle,
            title: AppLocalizations.of(context).notPlaying,
            message: AppLocalizations.of(context).notPlayingHint,
          );
        } else if (landscape) {
          body = _LandscapeBody(
            state: state,
            track: track,
            showSettings: !volumeOpen,
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

        return Stack(
          fit: StackFit.expand,
          children: [
            _NowPlayingBackdrop(track: track),
            SafeArea(
              child: Stack(
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
                              ? Visibility(
                                  visible: !volumeOpen,
                                  maintainSize: true,
                                  maintainAnimation: true,
                                  maintainState: true,
                                  child: MiniSettings(
                                    key: const ValueKey('mini_settings'),
                                    onVolumeTap: () =>
                                        setState(() => _volumeOpen = true),
                                  ),
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
                                  onTap: () =>
                                      setState(() => _volumeOpen = false),
                                ),
                                Positioned(
                                  left: volumeBarLeft,
                                  bottom: AppSpacing.md,
                                  width: volumeBarWidth,
                                  height: kMiniSettingsHeight,
                                  child: const VolumeBar(),
                                ),
                              ],
                            )
                          : const SizedBox.shrink(key: ValueKey('no_volume')),
                    ),
                  ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }
}

/// The blurred-cover wash behind the player.
///
/// The layer is isolated in a [RepaintBoundary] so the 200 ms position ticks
/// do not re-rasterise the blur, and the scrim keeps the header and controls
/// readable over bright artwork.
class _NowPlayingBackdrop extends StatelessWidget {
  const _NowPlayingBackdrop({required this.track});

  final Track? track;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final coverPath = track?.coverPath;
    final coverUrl = track?.coverUrl;
    final hasCover =
        (coverPath != null && coverPath.isNotEmpty) ||
        (coverUrl != null && coverUrl.isNotEmpty);

    return RepaintBoundary(
      child: Stack(
        fit: StackFit.expand,
        children: [
          ColoredBox(color: scheme.surface),
          if (hasCover)
            ImageFiltered(
              imageFilter: ImageFilter.blur(
                sigmaX: 48,
                sigmaY: 48,
                tileMode: TileMode.clamp,
              ),
              child: SizedBox.expand(
                child: CoverImage(
                  path: coverPath,
                  url: coverUrl,
                  size: double.infinity,
                  errorBuilder: (context, error, stackTrace) =>
                      const SizedBox.shrink(),
                ),
              ),
            ),
          DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Colors.black.withValues(alpha: hasCover ? 0.22 : 0),
                  Colors.black.withValues(alpha: 0.52),
                  scheme.surface.withValues(alpha: 0.94),
                ],
                stops: const [0, 0.55, 1],
              ),
            ),
          ),
          DecoratedBox(
            decoration: BoxDecoration(
              gradient: RadialGradient(
                center: const Alignment(-0.45, -0.95),
                radius: 1.3,
                colors: [
                  scheme.primary.withValues(alpha: 0.20),
                  Colors.transparent,
                ],
              ),
            ),
          ),
        ],
      ),
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
    final scheme = theme.colorScheme;
    final dismiss = _PlayerDismissScope.maybeOf(context);
    final handle = Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm,
        vertical: AppSpacing.xs,
      ),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(AppIcons.keyboardArrowDown),
            color: scheme.onSurface,
            tooltip: '',
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
                    color: scheme.onSurface,
                  ),
                ),
                Text(
                  artist,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          // Balances the leading button so the title/artist block is centred.
          const SizedBox(width: 48),
        ],
      ),
    );
    if (dismiss == null) return handle;
    // A Cupertino route is opaque, so the drawer reveal would show a void;
    // Apple platforms keep the native edge-swipe-back and the close button.
    final platform = Theme.of(context).platform;
    if (platform == TargetPlatform.iOS || platform == TargetPlatform.macOS) {
      return handle;
    }
    return GestureDetector(
      key: playerDismissHandleKey,
      behavior: HitTestBehavior.opaque,
      onVerticalDragUpdate: (details) =>
          dismiss.onDrag(details.delta.dy / MediaQuery.sizeOf(context).height),
      onVerticalDragEnd: (details) =>
          dismiss.onEnd(details.velocity.pixelsPerSecond.dy),
      child: handle,
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
          child: _PortraitPager(
            expanded: lyricsExpanded,
            onExpandedChanged: (value) {
              if (value) {
                onLyricsTap();
              } else {
                onLyricsCollapse();
              }
            },
            normal: _PortraitNormal(track: track, onLyricsTap: onLyricsTap),
            lyrics: LyricsView(onTap: onLyricsCollapse),
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

/// A horizontal, follow-the-finger pager between the cover and the lyrics.
///
/// `value` 0 shows the cover, 1 shows the lyrics. A horizontal drag over the
/// cover / lyrics preview drives the page; a commit reports the new state (the
/// parent stores it) so taps and swipes stay in sync. The detector only claims
/// horizontal drags, so the lyrics pane's vertical scroll is untouched.
class _PortraitPager extends StatefulWidget {
  const _PortraitPager({
    required this.expanded,
    required this.onExpandedChanged,
    required this.normal,
    required this.lyrics,
  });

  final bool expanded;
  final ValueChanged<bool> onExpandedChanged;
  final Widget normal;
  final Widget lyrics;

  @override
  State<_PortraitPager> createState() => _PortraitPagerState();
}

class _PortraitPagerState extends State<_PortraitPager>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: AppMotion.standard,
    value: widget.expanded ? 1 : 0,
  );

  @override
  void didUpdateWidget(covariant _PortraitPager oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.expanded != oldWidget.expanded) {
      _c.animateTo(widget.expanded ? 1 : 0, curve: AppMotion.standardCurve);
    }
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  void _onEnd(DragEndDetails details) {
    final velocity = details.velocity.pixelsPerSecond.dx;
    final bool showLyrics;
    if (velocity < -700) {
      showLyrics = true;
    } else if (velocity > 700) {
      showLyrics = false;
    } else {
      showLyrics = _c.value > 0.4;
    }
    _c.animateTo(showLyrics ? 1 : 0, curve: AppMotion.standardCurve);
    widget.onExpandedChanged(showLyrics);
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        return GestureDetector(
          behavior: HitTestBehavior.opaque,
          onHorizontalDragUpdate: (details) {
            _c.value = (_c.value - details.delta.dx / width).clamp(0.0, 1.0);
          },
          onHorizontalDragEnd: _onEnd,
          child: ClipRect(
            child: AnimatedBuilder(
              animation: _c,
              builder: (context, child) {
                return Stack(
                  children: [
                    Positioned.fill(
                      child: Transform.translate(
                        offset: Offset(-_c.value * width, 0),
                        child: Opacity(
                          opacity: 1 - _c.value,
                          child: widget.normal,
                        ),
                      ),
                    ),
                    Positioned.fill(
                      child: Transform.translate(
                        offset: Offset((1 - _c.value) * width, 0),
                        child: widget.lyrics,
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        );
      },
    );
  }
}

/// The collapsed portrait content: adaptive cover and the 5-line lyrics
/// teaser strip. The title and artist live in the shared header row.
class _PortraitNormal extends StatelessWidget {
  const _PortraitNormal({required this.track, required this.onLyricsTap});

  final Track track;
  final VoidCallback onLyricsTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    // Roughly three lyric lines including a translation, so the teaser reads
    // as a door into the lyrics page without stealing the cover's space.
    final lyricsStyle = theme.textTheme.titleMedium;
    final lineHeight =
        (lyricsStyle?.fontSize ?? 16) * (lyricsStyle?.height ?? 1.4);
    final lyricsStripHeight = lineHeight * 3.6;
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
/// rendered by the parent; no divider, so both panes sit on the same ambient
/// backdrop.
class _LandscapeBody extends StatelessWidget {
  const _LandscapeBody({
    required this.state,
    required this.track,
    required this.showSettings,
    required this.onVolumeTap,
  });

  final PlaybackState state;
  final Track track;
  final bool showSettings;
  final VoidCallback onVolumeTap;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: MiniMain(
            state: state,
            track: track,
            showSettings: showSettings,
            onVolumeTap: onVolumeTap,
          ),
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
    required this.showSettings,
    required this.onVolumeTap,
  });

  final PlaybackState state;
  final Track track;
  final bool showSettings;
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
        Visibility(
          visible: showSettings,
          maintainSize: true,
          maintainAnimation: true,
          maintainState: true,
          child: MiniSettings(onVolumeTap: onVolumeTap),
        ),
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
        // Anchor the artwork to the lyrics teaser below it; the extra breathing
        // room collects under the header instead of splitting the cover and
        // the lyrics apart.
        return Align(
          alignment: Alignment.bottomCenter,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(24, 8, 24, 12),
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

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      // Desktop: right-click. Touch: long-press.
      onSecondaryTap: () => Navigator.of(context).push(coverViewerRoute(track)),
      onLongPress: () => Navigator.of(context).push(coverViewerRoute(track)),
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(AppRadius.lg),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.38),
              blurRadius: 48,
              spreadRadius: -10,
              offset: const Offset(0, 26),
            ),
          ],
        ),
        child: CoverHero(
          uri: track.uri,
          coverPath: coverPath,
          coverUrl: coverUrl,
          child: ClipRRect(
            key: const Key('player_cover_clip'),
            borderRadius: BorderRadius.circular(AppRadius.lg),
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
          ),
        ),
      ),
    );
  }

  Widget _placeholder(ColorScheme scheme) => Icon(
    AppIcons.musicNote,
    size: size * 0.4,
    color: scheme.onSurfaceVariant,
  );
}

/// Seekable progress bar with `m:ss` labels on both sides.
///
/// The [PlayerProgressBar] owns the playing/paused wave morph and the
/// buffering dot animation; this widget keeps the drag position local so the
/// thumb follows the finger and issues the seek once on release.
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
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Row(
        children: [
          Text(
            formatTrackDuration(shownPosition),
            style: theme.textTheme.labelMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          Expanded(
            child: PlayerProgressBar(
              value: enabled
                  ? ((dragMs ?? positionValue) / maxValue).clamp(0.0, 1.0)
                  : 0,
              isPlaying: state.isPlaying,
              isBuffering: state.isBuffering,
              enabled: enabled,
              morphDuration: PlaybackController.fadeDuration,
              onChanged: enabled
                  ? (value) => setState(() => _dragMs = value * maxValue)
                  : null,
              onChangeEnd: enabled
                  ? (value) {
                      setState(() => _dragMs = null);
                      ref
                          .read(playbackControllerProvider)
                          .seek(
                            Duration(milliseconds: (value * maxValue).round()),
                          );
                    }
                  : null,
            ),
          ),
          Text(
            formatTrackDuration(state.duration),
            style: theme.textTheme.labelMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
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
    final primaryTransportStyle = IconButton.styleFrom(
      backgroundColor: scheme.primary,
      foregroundColor: scheme.onPrimary,
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
        final playIcon = comfortable ? 38.0 : 34.0;
        final skipIcon = comfortable ? 32.0 : 28.0;
        final assistIcon = comfortable ? 26.0 : 22.0;

        return Row(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.max,
          children: [
            if (track == null)
              const SizedBox.shrink()
            else
              FavoriteButton(
                track: track,
                size: assistSize,
                iconSize: assistIcon,
              ),
            SizedBox(width: outerGap),
            IconButton(
              onPressed: state.hasPrevious ? controller.previous : null,
              icon: const Icon(AppIcons.skipPrevious),
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
              icon: Icon(state.isPlaying ? AppIcons.pause : AppIcons.playArrow),
              iconSize: playIcon,
              style: primaryTransportStyle,
              padding: EdgeInsets.zero,
              constraints: BoxConstraints.tightFor(
                width: playSize,
                height: playSize,
              ),
            ),
            SizedBox(width: innerGap),
            IconButton(
              onPressed: state.hasNext ? controller.next : null,
              icon: const Icon(AppIcons.skipNext),
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
              icon: const Icon(AppIcons.queueMusic),
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
