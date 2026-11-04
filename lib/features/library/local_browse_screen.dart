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
import 'package:flind_player/core/models/library_view.dart';
import 'package:flind_player/core/models/local_collection.dart';
import 'package:flind_player/core/models/playback_queue.dart';
import 'package:flind_player/core/models/track.dart';
import 'package:flind_player/data/providers/local_browse_providers.dart';
import 'package:flind_player/data/providers/playback_providers.dart';
import 'package:flind_player/features/library/widgets/track_view.dart';
import 'package:flind_player/l10n/app_localizations.dart';
import 'package:flind_player/shared/app_page_header.dart';
import 'package:flind_player/shared/app_page_scaffold.dart';
import 'package:flind_player/shared/cover_image.dart';
import 'package:flind_player/shared/empty_state.dart';

enum _LocalMode { artists, albums }

/// Local artists and albums aggregated from the unified pool.
class LocalBrowseScreen extends ConsumerStatefulWidget {
  const LocalBrowseScreen({super.key});

  @override
  ConsumerState<LocalBrowseScreen> createState() => _LocalBrowseScreenState();
}

class _LocalBrowseScreenState extends ConsumerState<LocalBrowseScreen> {
  _LocalMode _mode = _LocalMode.artists;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final compact = MediaQuery.sizeOf(context).width < AppBreakpoints.compact;
    final horizontal = compact ? 16.0 : 28.0;

    return AppPageScaffold(
      width: AppContentKind.standard,
      header: Column(
        children: [
          AppPageHeader(
            title: l10n.localLibrary,
            compact: compact,
            leading: IconButton(
              key: const Key('local_browse_back'),
              tooltip: '',
              icon: const Icon(AppIcons.arrowBack),
              onPressed: () => Navigator.of(context).maybePop(),
            ),
          ),
          Padding(
            padding: EdgeInsets.symmetric(horizontal: horizontal),
            child: SegmentedButton<_LocalMode>(
              segments: [
                ButtonSegment(
                  value: _LocalMode.artists,
                  label: Text(l10n.artists),
                ),
                ButtonSegment(
                  value: _LocalMode.albums,
                  label: Text(l10n.albums),
                ),
              ],
              selected: {_mode},
              onSelectionChanged: (value) =>
                  setState(() => _mode = value.first),
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
        ],
      ),
      body: _mode == _LocalMode.artists
          ? const _ArtistList()
          : const _AlbumList(),
    );
  }
}

class _ArtistList extends ConsumerWidget {
  const _ArtistList();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final async = ref.watch(localArtistsProvider);
    return async.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, stackTrace) => Center(
        child: TextButton.icon(
          onPressed: () => ref.invalidate(localArtistsProvider),
          icon: const Icon(AppIcons.refresh),
          label: Text(l10n.retry),
        ),
      ),
      data: (artists) => artists.isEmpty
          ? EmptyState(icon: AppIcons.person, title: l10n.noArtists)
          : ListView.builder(
              padding: EdgeInsets.only(
                bottom: AppSpacing.md + MediaQuery.paddingOf(context).bottom,
              ),
              itemCount: artists.length,
              itemBuilder: (context, index) {
                final artist = artists[index];
                return ListTile(
                  leading: ClipOval(
                    child: CoverImage(
                      path: artist.coverPath,
                      url: artist.coverUrl,
                      size: 52,
                    ),
                  ),
                  title: Text(
                    artist.name.isEmpty ? l10n.unknownArtist : artist.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  subtitle: Text(l10n.trackCount(artist.trackCount)),
                  trailing: const Icon(AppIcons.chevronRight),
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (context) =>
                          _LocalArtistTracksScreen(artist: artist),
                    ),
                  ),
                );
              },
            ),
    );
  }
}

class _AlbumList extends ConsumerWidget {
  const _AlbumList();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final async = ref.watch(localAlbumsProvider);
    return async.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, stackTrace) => Center(
        child: TextButton.icon(
          onPressed: () => ref.invalidate(localAlbumsProvider),
          icon: const Icon(AppIcons.refresh),
          label: Text(l10n.retry),
        ),
      ),
      data: (albums) => albums.isEmpty
          ? EmptyState(icon: AppIcons.album, title: l10n.noAlbums)
          : ListView.builder(
              padding: EdgeInsets.only(
                bottom: AppSpacing.md + MediaQuery.paddingOf(context).bottom,
              ),
              itemCount: albums.length,
              itemBuilder: (context, index) {
                final album = albums[index];
                return ListTile(
                  leading: CoverImage(
                    path: album.coverPath,
                    url: album.coverUrl,
                    size: 52,
                  ),
                  title: Text(
                    album.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  subtitle: Text(
                    [
                      if (album.artist != null && album.artist!.isNotEmpty)
                        album.artist!,
                      if (album.year != null) '${album.year}',
                    ].join(' · '),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  trailing: const Icon(AppIcons.chevronRight),
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (context) =>
                          _LocalAlbumTracksScreen(album: album),
                    ),
                  ),
                );
              },
            ),
    );
  }
}

class _LocalArtistTracksScreen extends ConsumerWidget {
  const _LocalArtistTracksScreen({required this.artist});

  final LocalArtist artist;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final tracksAsync = ref.watch(localArtistTracksProvider(artist.name));
    return _LocalTracksScaffold(
      title: artist.name.isEmpty ? l10n.unknownArtist : artist.name,
      tracksAsync: tracksAsync,
      onRetry: () => ref.invalidate(localArtistTracksProvider(artist.name)),
    );
  }
}

class _LocalAlbumTracksScreen extends ConsumerWidget {
  const _LocalAlbumTracksScreen({required this.album});

  final LocalAlbum album;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final key = (album.title, album.artist);
    final tracksAsync = ref.watch(localAlbumTracksProvider(key));
    return _LocalTracksScaffold(
      title: album.title,
      tracksAsync: tracksAsync,
      onRetry: () => ref.invalidate(localAlbumTracksProvider(key)),
    );
  }
}

class _LocalTracksScaffold extends ConsumerWidget {
  const _LocalTracksScaffold({
    required this.title,
    required this.tracksAsync,
    required this.onRetry,
  });

  final String title;
  final AsyncValue<List<Track>> tracksAsync;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final playback = ref.watch(playbackStateProvider).value;
    final compact = MediaQuery.sizeOf(context).width < AppBreakpoints.compact;

    return AppPageScaffold(
      width: AppContentKind.standard,
      header: AppPageHeader(
        title: title,
        compact: compact,
        leading: IconButton(
          tooltip: '',
          icon: const Icon(AppIcons.arrowBack),
          onPressed: () => Navigator.of(context).maybePop(),
        ),
      ),
      body: tracksAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stackTrace) => Center(
          child: TextButton.icon(
            onPressed: onRetry,
            icon: const Icon(AppIcons.refresh),
            label: Text(l10n.retry),
          ),
        ),
        data: (tracks) => tracks.isEmpty
            ? EmptyState(icon: AppIcons.musicOff, title: l10n.noResults)
            : TrackView(
                tracks: tracks,
                view: LibraryView.list,
                currentUri: playback?.currentTrack?.uri,
                isPlaying: playback?.isPlaying ?? false,
                onPlay: (index) => _play(ref, tracks, index),
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
}
