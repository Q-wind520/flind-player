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
import 'package:flind_player/core/sources/source_track_id.dart';
import 'package:flind_player/data/providers/auth_providers.dart';
import 'package:flind_player/data/providers/netease_library_providers.dart';
import 'package:flind_player/data/providers/netease_providers.dart';
import 'package:flind_player/data/providers/playback_providers.dart';
import 'package:flind_player/l10n/app_localizations.dart';
import 'package:flind_player/shared/app_page_header.dart';
import 'package:flind_player/shared/app_surface.dart';
import 'package:flind_player/shared/cover_image.dart';
import 'package:flind_player/shared/empty_state.dart';

/// NetEase account playlists plus recommended playlists.
class NeteaseLibraryScreen extends ConsumerWidget {
  const NeteaseLibraryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final account = ref.watch(authAccountProvider('netease'));
    final mine = ref.watch(neteaseMyPlaylistsProvider);
    final recommended = ref.watch(neteaseRecommendedPlaylistsProvider);
    final compact = MediaQuery.sizeOf(context).width < AppBreakpoints.compact;

    return Scaffold(
      backgroundColor: AppSurface.colorOf(context),
      body: SafeArea(
        bottom: false,
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 960),
            child: Column(
              children: [
                AppPageHeader(
                  title: l10n.neteaseLibrary,
                  compact: compact,
                  leading: IconButton(
                    key: const Key('netease_library_back'),
                    tooltip: '',
                    icon: const Icon(AppIcons.arrowBack),
                    onPressed: () => Navigator.of(context).maybePop(),
                  ),
                ),
                Expanded(
                  child: ListView(
                    padding: EdgeInsets.fromLTRB(
                      compact ? 16 : 28,
                      0,
                      compact ? 16 : 28,
                      AppSpacing.md + MediaQuery.paddingOf(context).bottom,
                    ),
                    children: [
                      _Section(
                        title: l10n.myPlaylists,
                        child: account == null
                            ? _Hint(text: l10n.loginToSeeNetease)
                            : _PlaylistList(
                                async: mine,
                                empty: l10n.emptyPlaylist,
                                onRetry: () =>
                                    ref.invalidate(neteaseMyPlaylistsProvider),
                              ),
                      ),
                      const SizedBox(height: AppSpacing.lg),
                      _Section(
                        title: l10n.recommendedPlaylists,
                        child: _PlaylistList(
                          async: recommended,
                          empty: l10n.emptyPlaylist,
                          onRetry: () => ref.invalidate(
                            neteaseRecommendedPlaylistsProvider,
                          ),
                        ),
                      ),
                    ],
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

class _Section extends StatelessWidget {
  const _Section({required this.title, required this.child});

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(title, style: theme.textTheme.titleMedium),
        const SizedBox(height: AppSpacing.xs),
        child,
      ],
    );
  }
}

class _Hint extends StatelessWidget {
  const _Hint({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
      child: Text(
        text,
        style: theme.textTheme.bodyMedium?.copyWith(
          color: theme.colorScheme.onSurfaceVariant,
        ),
      ),
    );
  }
}

class _PlaylistList extends StatelessWidget {
  const _PlaylistList({
    required this.async,
    required this.empty,
    required this.onRetry,
  });

  final AsyncValue<List<RemotePlaylist>> async;
  final String empty;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return async.when(
      loading: () => const Padding(
        padding: EdgeInsets.all(AppSpacing.lg),
        child: Center(child: CircularProgressIndicator()),
      ),
      error: (error, stackTrace) => TextButton.icon(
        onPressed: onRetry,
        icon: const Icon(AppIcons.refresh),
        label: Text(AppLocalizations.of(context).retry),
      ),
      data: (playlists) => playlists.isEmpty
          ? _Hint(text: empty)
          : Column(
              children: [
                for (final playlist in playlists)
                  _PlaylistTile(playlist: playlist),
              ],
            ),
    );
  }
}

class _PlaylistTile extends StatelessWidget {
  const _PlaylistTile({required this.playlist});

  final RemotePlaylist playlist;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: CoverImage(url: playlist.coverUrl, size: 56),
      title: Text(playlist.title, maxLines: 1, overflow: TextOverflow.ellipsis),
      subtitle: Text(l10n.trackCount(playlist.trackCount)),
      trailing: const Icon(AppIcons.chevronRight),
      onTap: () => Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (context) => NeteasePlaylistScreen(playlist: playlist),
        ),
      ),
    );
  }
}

/// Tracks in one NetEase playlist.
class NeteasePlaylistScreen extends ConsumerWidget {
  const NeteasePlaylistScreen({super.key, required this.playlist});

  final RemotePlaylist playlist;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final tracksAsync = ref.watch(neteasePlaylistTracksProvider(playlist.id));
    final state = ref.watch(playbackStateProvider).value;
    final account = ref.watch(authAccountProvider('netease'));
    final liked = account == null
        ? const <String>{}
        : (ref.watch(neteaseLikedIdsProvider).value ?? const <String>{});
    final compact = MediaQuery.sizeOf(context).width < AppBreakpoints.compact;

    return Scaffold(
      backgroundColor: AppSurface.colorOf(context),
      body: SafeArea(
        bottom: false,
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 960),
            child: Column(
              children: [
                AppPageHeader(
                  title: playlist.title,
                  subtitle: l10n.trackCount(playlist.trackCount),
                  compact: compact,
                  leading: IconButton(
                    key: const Key('netease_playlist_back'),
                    tooltip: '',
                    icon: const Icon(AppIcons.arrowBack),
                    onPressed: () => Navigator.of(context).maybePop(),
                  ),
                ),
                Expanded(
                  child: tracksAsync.when(
                    loading: () =>
                        const Center(child: CircularProgressIndicator()),
                    error: (error, stackTrace) => Center(
                      child: TextButton.icon(
                        onPressed: () => ref.invalidate(
                          neteasePlaylistTracksProvider(playlist.id),
                        ),
                        icon: const Icon(AppIcons.refresh),
                        label: Text(l10n.retry),
                      ),
                    ),
                    data: (tracks) => tracks.isEmpty
                        ? EmptyState(
                            icon: AppIcons.musicOff,
                            title: l10n.neteasePlaylistEmpty,
                          )
                        : ListView.separated(
                            padding: EdgeInsets.only(
                              bottom:
                                  AppSpacing.md +
                                  MediaQuery.paddingOf(context).bottom,
                            ),
                            itemCount: tracks.length,
                            separatorBuilder: (context, index) => Divider(
                              height: 1,
                              indent: 60,
                              color: Theme.of(context)
                                  .colorScheme
                                  .outlineVariant
                                  .withValues(alpha: 0.55),
                            ),
                            itemBuilder: (context, index) {
                              final track = tracks[index];
                              final likedId =
                                  track.sourceTrackId is NeteaseTrackId
                                  ? '${(track.sourceTrackId as NeteaseTrackId).songId}'
                                  : null;
                              return _TrackRow(
                                track: track,
                                isCurrent:
                                    state?.currentTrack?.uri == track.uri,
                                isPlaying: state?.isPlaying ?? false,
                                isLiked:
                                    likedId != null && liked.contains(likedId),
                                onTap: () => _play(ref, tracks, index),
                                onLike: account == null || likedId == null
                                    ? null
                                    : () => _toggleLike(
                                        ref,
                                        likedId,
                                        liked.contains(likedId),
                                      ),
                              );
                            },
                          ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _play(WidgetRef ref, List<Track> tracks, int index) {
    final queue = PlaybackQueue(
      tracks: tracks,
      currentIndex: index,
      originalOrder: List<int>.generate(tracks.length, (i) => i),
    );
    ref.read(playbackControllerProvider).playQueue(queue, index: index);
  }

  Future<void> _toggleLike(WidgetRef ref, String songId, bool liked) async {
    await ref.read(neteaseLikeSourceProvider).setLiked(songId, !liked);
    ref.invalidate(neteaseLikedIdsProvider);
  }
}

class _TrackRow extends StatelessWidget {
  const _TrackRow({
    required this.track,
    required this.isCurrent,
    required this.isPlaying,
    required this.isLiked,
    required this.onTap,
    this.onLike,
  });

  final Track track;
  final bool isCurrent;
  final bool isPlaying;
  final bool isLiked;
  final VoidCallback onTap;
  final VoidCallback? onLike;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ListTile(
      leading: CoverImage(path: track.coverPath, url: track.coverUrl, size: 44),
      title: Text(
        track.title,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: isCurrent ? TextStyle(color: theme.colorScheme.primary) : null,
      ),
      subtitle: Text(
        track.artist ?? '',
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (isCurrent && isPlaying)
            Icon(AppIcons.graphicEq, color: theme.colorScheme.primary),
          if (onLike != null)
            IconButton(
              tooltip: '',
              onPressed: onLike,
              icon: Icon(
                isLiked ? AppIcons.favoriteActive : AppIcons.favoriteBorder,
                color: isLiked ? theme.colorScheme.error : null,
              ),
            ),
        ],
      ),
      onTap: onTap,
    );
  }
}
