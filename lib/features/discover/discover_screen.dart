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
import 'package:flind_player/core/models/playback_queue.dart';
import 'package:flind_player/core/models/track.dart';
import 'package:flind_player/core/sources/remote_playlist.dart';
import 'package:flind_player/data/providers/auth_providers.dart';
import 'package:flind_player/data/providers/database_providers.dart';
import 'package:flind_player/data/providers/netease_library_providers.dart';
import 'package:flind_player/data/providers/online_source_providers.dart';
import 'package:flind_player/data/providers/playback_providers.dart';
import 'package:flind_player/data/providers/stats_providers.dart';
import 'package:flind_player/features/netease/netease_library_screen.dart';
import 'package:flind_player/features/library/widgets/track_actions_button.dart';
import 'package:flind_player/features/library/widgets/track_list_items.dart';
import 'package:flind_player/features/settings/account_section.dart';
import 'package:flind_player/l10n/app_localizations.dart';
import 'package:flind_player/platform/permissions/permission_providers.dart';
import 'package:flind_player/shared/app_page_header.dart';
import 'package:flind_player/shared/app_page_scaffold.dart';
import 'package:flind_player/shared/cover_image.dart';
import 'package:flind_player/shared/error_messages.dart';
import 'package:flind_player/shared/error_snack_bar.dart';
import 'package:flind_player/shared/empty_state.dart';
import 'package:flind_player/shared/responsive_center.dart';

/// Online music search across the registered sources: pick a source, submit a
/// keyword, browse the results, tap one to play.
///
/// The query is only committed on submit (never per keystroke): the search
/// endpoints are hard rate-limited and would answer `-412` on a keystroke
/// storm.
class DiscoverScreen extends ConsumerStatefulWidget {
  const DiscoverScreen({super.key});

  @override
  ConsumerState<DiscoverScreen> createState() => _DiscoverScreenState();
}

class _DiscoverScreenState extends ConsumerState<DiscoverScreen> {
  final TextEditingController _controller = TextEditingController();
  String _submittedQuery = '';
  String? _selectedSourceId;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _submit(String value) {
    final trimmed = value.trim();
    if (trimmed.isEmpty) {
      return;
    }
    FocusScope.of(context).unfocus();
    setState(() => _submittedQuery = trimmed);
  }

  void _clear() {
    _controller.clear();
    if (_submittedQuery.isNotEmpty) {
      setState(() => _submittedQuery = '');
    }
  }

  /// Plays [tracks] starting at [index] using an identity queue.
  Future<void> _play(List<Track> tracks, int index) {
    final queue = PlaybackQueue(
      tracks: tracks,
      currentIndex: index,
      originalOrder: List<int>.generate(tracks.length, (i) => i),
    );
    return ref.read(playbackControllerProvider).playQueue(queue, index: index);
  }

  /// Persists [track] into the unified library.
  ///
  /// The library screen watches `watchTracks()`, so the saved track appears
  /// there automatically.
  Future<void> _saveToLibrary(Track track) async {
    final messenger = ScaffoldMessenger.of(context);
    final l10n = AppLocalizations.of(context);
    try {
      await ref.read(musicLibraryRepositoryProvider).upsertTrack(track);
      messenger.showSnackBar(
        SnackBar(content: Text(l10n.savedToLibrary(track.title))),
      );
    } catch (error) {
      if (!mounted) return;
      showErrorSnackBar(context, error);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final sources = ref.watch(onlineSourcesProvider);
    final selectedId = sources.any((d) => d.id == _selectedSourceId)
        ? _selectedSourceId!
        : (sources.isEmpty ? '' : sources.first.id);
    final compact = MediaQuery.sizeOf(context).width < AppBreakpoints.compact;
    final horizontal = compact ? 16.0 : 28.0;
    return PlaybackPermissionScope(
      child: AppPageScaffold(
        header: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            AppPageHeader(title: l10n.discover),
            Padding(
              padding: EdgeInsets.fromLTRB(
                horizontal,
                0,
                horizontal,
                AppSpacing.md,
              ),
              child: Align(
                alignment: Alignment.centerLeft,
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 960),
                  child: ValueListenableBuilder<TextEditingValue>(
                    valueListenable: _controller,
                    builder: (context, value, child) {
                      return TextField(
                        controller: _controller,
                        textInputAction: TextInputAction.search,
                        onSubmitted: _submit,
                        style: Theme.of(context).textTheme.bodyMedium,
                        decoration: InputDecoration(
                          hintText: l10n.searchHint,
                          prefixIcon: const Icon(AppIcons.search),
                          suffixIcon: value.text.isEmpty
                              ? null
                              : IconButton(
                                  icon: const Icon(AppIcons.clear),
                                  onPressed: _clear,
                                ),
                        ),
                      );
                    },
                  ),
                ),
              ),
            ),
            if (sources.length > 1)
              Padding(
                padding: EdgeInsets.fromLTRB(
                  horizontal,
                  0,
                  horizontal,
                  AppSpacing.md,
                ),
                child: _SourceSwitcher(
                  ids: [for (final source in sources) source.id],
                  selectedId: selectedId,
                  labelFor: (id) => _sourceLabel(l10n, id),
                  onSelected: (id) => setState(() => _selectedSourceId = id),
                ),
              ),
          ],
        ),
        body: _buildBody(selectedId),
      ),
    );
  }

  /// The landing surface before a query: continue playing, recent tracks and
  /// recommended NetEase playlists.
  Widget _buildDiscovery(AppLocalizations l10n) {
    final recent = ref.watch(recentTracksProvider);
    final account = ref.watch(authAccountProvider('netease'));
    // Only signed-in users hit the personalised endpoint here. Anonymous users
    // still get continue-playing/recent; a cold anonymous start stays a search
    // prompt instead of firing a network request on every app launch.
    final playlistsAsync = account == null
        ? const AsyncData<List<RemotePlaylist>>(<RemotePlaylist>[])
        : ref.watch(neteaseRecommendedPlaylistsProvider);
    final dailyAsync = account == null
        ? const AsyncData<List<Track>>(<Track>[])
        : ref.watch(neteaseRecommendedSongsProvider);
    final hotAsync = account == null
        ? const AsyncData<List<RemotePlaylist>>(<RemotePlaylist>[])
        : ref.watch(neteasePopularPlaylistsProvider);
    final daily = dailyAsync.value ?? const <Track>[];
    final recommended = playlistsAsync.value ?? const <RemotePlaylist>[];
    final hot = hotAsync.value ?? const <RemotePlaylist>[];
    final compact = MediaQuery.sizeOf(context).width < AppBreakpoints.compact;
    final horizontal = compact ? 16.0 : 28.0;

    if (recent.isEmpty &&
        daily.isEmpty &&
        recommended.isEmpty &&
        hot.isEmpty) {
      return EmptyState(
        icon: AppIcons.search,
        title: l10n.searchSourcesTitle,
        message: l10n.searchSourcesHint,
        action: account == null
            ? FilledButton.tonalIcon(
                onPressed: () =>
                    showAccountLoginSheet(context, sourceId: 'netease'),
                icon: const Icon(AppIcons.person, size: 18),
                label: Text(l10n.accountLoginTitle(l10n.sourceNetease)),
              )
            : null,
      );
    }

    return ListView(
      padding: EdgeInsets.fromLTRB(
        horizontal,
        0,
        horizontal,
        AppSpacing.md + MediaQuery.paddingOf(context).bottom,
      ),
      children: [
        if (daily.isNotEmpty) ...[
          _DiscoverySection(
            title: l10n.dailyRecommendations,
            child: _PosterTrackCarousel(
              tracks: daily.take(10).toList(growable: false),
              onPlay: (tracks, index) => _play(tracks, index),
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
        ],
        if (recent.isNotEmpty) ...[
          _DiscoverySection(
            title: l10n.recentPlays,
            child: _RecentTrackCarousel(
              tracks: recent.take(10).toList(growable: false),
              onPlay: (tracks, index) => _play(tracks, index),
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
        ],
        if (recommended.isNotEmpty) ...[
          _DiscoverySection(
            title: l10n.recommendedPlaylists,
            child: playlistsAsync.when(
              loading: () => const SizedBox(
                height: 180,
                child: Center(child: CircularProgressIndicator()),
              ),
              error: (error, stackTrace) => TextButton.icon(
                onPressed: () =>
                    ref.invalidate(neteaseRecommendedPlaylistsProvider),
                icon: const Icon(AppIcons.refresh),
                label: Text(l10n.retry),
              ),
              data: (playlists) =>
                  _PlaylistPosterCarousel(playlists: playlists),
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
        ],
        if (hot.isNotEmpty)
          _DiscoverySection(
            title: l10n.hotPlaylists,
            child: _HotPlaylistCarousel(playlists: hot),
          ),
      ],
    );
  }

  Widget _buildBody(String sourceId) {
    final l10n = AppLocalizations.of(context);
    if (_submittedQuery.isEmpty) {
      return _buildDiscovery(l10n);
    }

    final resultsAsync = ref.watch(
      onlineSearchProvider((sourceId, _submittedQuery)),
    );
    final playback = ref.watch(playbackStateProvider).value;
    final currentUri = playback?.currentTrack?.uri;
    final isPlaying = playback?.isPlaying ?? false;

    return resultsAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, stackTrace) => _SearchError(
        error: error,
        onRetry: () =>
            ref.invalidate(onlineSearchProvider((sourceId, _submittedQuery))),
      ),
      data: (tracks) {
        if (tracks.isEmpty) {
          return EmptyState(
            icon: AppIcons.searchOff,
            title: l10n.noResults,
            message: l10n.tryAnotherKeyword,
          );
        }
        final compact =
            MediaQuery.sizeOf(context).width < AppBreakpoints.compact;
        final horizontal = compact ? 16.0 : 28.0;
        final side = (horizontal - AppSpacing.md).clamp(0.0, 16.0);
        final bottomInset = MediaQuery.paddingOf(context).bottom;
        return ListView.separated(
          padding: EdgeInsets.fromLTRB(
            side,
            0,
            side,
            AppSpacing.md + bottomInset,
          ),
          itemCount: tracks.length,
          separatorBuilder: (context, index) => Divider(
            height: 1,
            indent: 60,
            color: Theme.of(context).colorScheme.outlineVariant
                .withValues(alpha: 0.55),
          ),
          itemBuilder: (context, index) {
            final track = tracks[index];
            final isCurrent = currentUri != null && track.uri == currentUri;
            return _SearchResultTile(
              track: track,
              isCurrent: isCurrent,
              isPlaying: isCurrent && isPlaying,
              onTap: () => _play(tracks, index),
              onSave: () => _saveToLibrary(track),
            );
          },
        );
      },
    );
  }
}

class _DiscoverySection extends StatelessWidget {
  const _DiscoverySection({required this.title, required this.child});

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(title, style: theme.textTheme.titleMedium),
        const SizedBox(height: AppSpacing.sm),
        child,
      ],
    );
  }
}

/// Shared rounded, tonal surface for every discovery card. The visible
/// background + hairline keeps cards distinct from the near-black page.
class _DiscoveryCardSurface extends StatelessWidget {
  const _DiscoveryCardSurface({
    required this.width,
    required this.onTap,
    required this.child,
  });

  final double width;
  final VoidCallback onTap;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return SizedBox(
      width: width,
      child: Material(
        color: scheme.surfaceContainerLow,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.md),
          side: BorderSide(
            color: scheme.outlineVariant.withValues(alpha: 0.55),
          ),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.sm),
            child: child,
          ),
        ),
      ),
    );
  }
}

/// Daily picks: a poster card — large square cover, text underneath.
class _PosterTrackCarousel extends StatelessWidget {
  const _PosterTrackCarousel({required this.tracks, required this.onPlay});

  final List<Track> tracks;
  final void Function(List<Track>, int) onPlay;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 236,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: tracks.length,
        separatorBuilder: (context, index) => const SizedBox(width: 12),
        itemBuilder: (context, index) {
          final track = tracks[index];
          return _PosterTrackCard(
            track: track,
            onTap: () => onPlay(tracks, index),
          );
        },
      ),
    );
  }
}

class _PosterTrackCard extends StatelessWidget {
  const _PosterTrackCard({required this.track, required this.onTap});

  final Track track;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final l10n = AppLocalizations.of(context);
    return _DiscoveryCardSurface(
      width: 168,
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(AppRadius.sm),
            child: CoverImage(
              path: track.coverPath,
              url: track.coverUrl,
              size: 152,
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          SizedBox(
            height: 40,
            child: Text(
              track.title,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          const SizedBox(height: 2),
          Text(
            track.artist ?? l10n.unknownArtist,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.bodySmall?.copyWith(
              color: scheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}

/// Recently played: a compact row card so it reads differently from the
/// poster-style daily picks.
class _RecentTrackCarousel extends StatelessWidget {
  const _RecentTrackCarousel({required this.tracks, required this.onPlay});

  final List<Track> tracks;
  final void Function(List<Track>, int) onPlay;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 80,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: tracks.length,
        separatorBuilder: (context, index) => const SizedBox(width: 12),
        itemBuilder: (context, index) {
          final track = tracks[index];
          return _RecentTrackCard(
            track: track,
            onTap: () => onPlay(tracks, index),
          );
        },
      ),
    );
  }
}

class _RecentTrackCard extends StatelessWidget {
  const _RecentTrackCard({required this.track, required this.onTap});

  final Track track;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final l10n = AppLocalizations.of(context);
    return _DiscoveryCardSurface(
      width: 276,
      onTap: onTap,
      child: Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(AppRadius.sm),
            child: CoverImage(
              path: track.coverPath,
              url: track.coverUrl,
              size: 56,
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  track.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  track.artist ?? l10n.unknownArtist,
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
          Icon(AppIcons.playArrow, size: 20, color: scheme.primary),
        ],
      ),
    );
  }
}

/// Recommended playlists: a poster with the title/count overlaid on the cover.
class _PlaylistPosterCarousel extends StatelessWidget {
  const _PlaylistPosterCarousel({required this.playlists});

  final List<RemotePlaylist> playlists;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 184,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: playlists.length,
        separatorBuilder: (context, index) => const SizedBox(width: 12),
        itemBuilder: (context, index) {
          final playlist = playlists[index];
          return _PlaylistPosterCard(playlist: playlist);
        },
      ),
    );
  }
}

class _PlaylistPosterCard extends StatelessWidget {
  const _PlaylistPosterCard({required this.playlist});

  final RemotePlaylist playlist;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);
    return _DiscoveryCardSurface(
      width: 176,
      onTap: () => Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (context) => NeteasePlaylistScreen(playlist: playlist),
        ),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(AppRadius.sm),
        child: SizedBox(
          width: 160,
          height: 160,
          child: Stack(
            fit: StackFit.expand,
            children: [
              CoverImage(url: playlist.coverUrl, size: 160),
              const DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.center,
                    end: Alignment.bottomCenter,
                    colors: [Colors.transparent, Color(0xCC000000)],
                  ),
                ),
              ),
              Positioned(
                left: AppSpacing.sm,
                right: AppSpacing.sm,
                bottom: AppSpacing.sm,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      playlist.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      l10n.trackCount(playlist.trackCount),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: Colors.white70,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Hot playlists: ranked rows with tabular rank numbers.
class _HotPlaylistCarousel extends StatelessWidget {
  const _HotPlaylistCarousel({required this.playlists});

  final List<RemotePlaylist> playlists;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 80,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: playlists.length,
        separatorBuilder: (context, index) => const SizedBox(width: 12),
        itemBuilder: (context, index) {
          return _HotPlaylistCard(playlist: playlists[index], rank: index + 1);
        },
      ),
    );
  }
}

class _HotPlaylistCard extends StatelessWidget {
  const _HotPlaylistCard({required this.playlist, required this.rank});

  final RemotePlaylist playlist;
  final int rank;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final l10n = AppLocalizations.of(context);
    return _DiscoveryCardSurface(
      width: 292,
      onTap: () => Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (context) => NeteasePlaylistScreen(playlist: playlist),
        ),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 28,
            child: Text(
              rank.toString().padLeft(2, '0'),
              style: theme.textTheme.titleMedium?.copyWith(
                color: rank <= 3 ? scheme.primary : scheme.onSurfaceVariant,
                fontWeight: FontWeight.w700,
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
          ),
          ClipRRect(
            borderRadius: BorderRadius.circular(AppRadius.sm),
            child: CoverImage(url: playlist.coverUrl, size: 56),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  playlist.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  l10n.trackCount(playlist.trackCount),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// A single search result row with a placeholder cover, title, UP主 and
/// duration, plus a consolidated actions menu (favourite, cache, store).
class _SearchResultTile extends StatelessWidget {
  const _SearchResultTile({
    required this.track,
    required this.isCurrent,
    required this.isPlaying,
    required this.onTap,
    required this.onSave,
  });

  final Track track;
  final bool isCurrent;
  final bool isPlaying;
  final VoidCallback onTap;
  final VoidCallback onSave;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return TrackListRow(
      track: track,
      isCurrent: isCurrent,
      isPlaying: isPlaying,
      onTap: onTap,
      subtitle: track.artist ?? l10n.unknownUp,
      action: TrackActionsButton(
        track: track,
        showSaveToLibrary: true,
        onSaveToLibrary: onSave,
      ),
    );
  }
}

/// A compact row of source chips. Replaces the stock segmented control so the
/// source switch shares the app's pill/typography language.
class _SourceSwitcher extends StatelessWidget {
  const _SourceSwitcher({
    required this.ids,
    required this.selectedId,
    required this.labelFor,
    required this.onSelected,
  });

  final List<String> ids;
  final String selectedId;
  final String Function(String id) labelFor;
  final ValueChanged<String> onSelected;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: AppSpacing.sm,
      runSpacing: AppSpacing.sm,
      children: [
        for (final id in ids)
          _SourceChip(
            label: labelFor(id),
            selected: id == selectedId,
            onTap: () => onSelected(id),
          ),
      ],
    );
  }
}

class _SourceChip extends StatelessWidget {
  const _SourceChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final radius = BorderRadius.circular(AppRadius.pill);
    return Semantics(
      button: true,
      selected: selected,
      child: Material(
        color: selected
            ? scheme.primary.withValues(alpha: 0.12)
            : scheme.surfaceContainerLow,
        borderRadius: radius,
        child: InkWell(
          onTap: onTap,
          borderRadius: radius,
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.lg,
              vertical: AppSpacing.sm,
            ),
            child: Text(
              label,
              style: Theme.of(context).textTheme.labelLarge?.copyWith(
                color: selected ? scheme.onSurface : scheme.onSurfaceVariant,
                fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Shown when the search future fails.
class _SearchError extends StatelessWidget {
  const _SearchError({required this.error, required this.onRetry});

  final Object error;
  final VoidCallback onRetry;

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
            Icon(AppIcons.error, size: 48, color: theme.colorScheme.error),
            const SizedBox(height: 16),
            Text(
              l10n.searchFailed,
              style: theme.textTheme.titleMedium,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              describeError(l10n, error),
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            OutlinedButton.icon(
              onPressed: onRetry,
              icon: const Icon(AppIcons.refresh),
              label: Text(l10n.retry),
            ),
          ],
        ),
      ),
    );
  }
}

/// Localised label for a source id, falling back to the raw id.
String _sourceLabel(AppLocalizations l10n, String id) => switch (id) {
  'bilibili' => l10n.sourceBilibili,
  'netease' => l10n.sourceNetease,
  _ => id,
};
