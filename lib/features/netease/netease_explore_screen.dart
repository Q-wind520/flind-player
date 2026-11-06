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
import 'package:flind_player/core/sources/remote_album.dart';
import 'package:flind_player/core/sources/remote_artist.dart';
import 'package:flind_player/data/providers/netease_library_providers.dart';
import 'package:flind_player/data/providers/playback_providers.dart';
import 'package:flind_player/features/netease/widgets/netease_track_row.dart';
import 'package:flind_player/l10n/app_localizations.dart';
import 'package:flind_player/shared/app_page_header.dart';
import 'package:flind_player/shared/app_page_scaffold.dart';
import 'package:flind_player/shared/cover_image.dart';
import 'package:flind_player/shared/empty_state.dart';

enum _ExploreMode { albums, artists }

/// Search NetEase albums and artists, then open their detail pages.
class NeteaseExploreScreen extends ConsumerStatefulWidget {
  const NeteaseExploreScreen({super.key});

  @override
  ConsumerState<NeteaseExploreScreen> createState() =>
      _NeteaseExploreScreenState();
}

class _NeteaseExploreScreenState extends ConsumerState<NeteaseExploreScreen> {
  final TextEditingController _controller = TextEditingController();
  _ExploreMode _mode = _ExploreMode.albums;
  String _query = '';

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _submit(String value) {
    final trimmed = value.trim();
    if (trimmed.isEmpty) return;
    FocusScope.of(context).unfocus();
    setState(() => _query = trimmed);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final compact = MediaQuery.sizeOf(context).width < AppBreakpoints.compact;
    final horizontal = compact ? 16.0 : 28.0;

    return AppPageScaffold(
      header: Column(
        children: [
          AppPageHeader(
            title: l10n.discover,
            compact: compact,
            leading: IconButton(
              key: const Key('netease_explore_back'),
              tooltip: '',
              icon: const Icon(AppIcons.arrowBack),
              onPressed: () => Navigator.of(context).maybePop(),
            ),
          ),
          Padding(
            padding: EdgeInsets.fromLTRB(
              horizontal,
              0,
              horizontal,
              AppSpacing.sm,
            ),
            child: TextField(
              key: const Key('netease_explore_search'),
              controller: _controller,
              textInputAction: TextInputAction.search,
              onSubmitted: _submit,
              decoration: InputDecoration(
                hintText: _mode == _ExploreMode.albums
                    ? l10n.searchAlbums
                    : l10n.searchArtists,
                prefixIcon: const Icon(AppIcons.search),
              ),
            ),
          ),
          Padding(
            padding: EdgeInsets.symmetric(horizontal: horizontal),
            child: SegmentedButton<_ExploreMode>(
              segments: [
                ButtonSegment(
                  value: _ExploreMode.albums,
                  label: Text(l10n.albums),
                ),
                ButtonSegment(
                  value: _ExploreMode.artists,
                  label: Text(l10n.artists),
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
      body: _query.isEmpty
          ? EmptyState(
              icon: AppIcons.search,
              title: _mode == _ExploreMode.albums
                  ? l10n.searchAlbums
                  : l10n.searchArtists,
            )
          : _mode == _ExploreMode.albums
          ? _AlbumResults(query: _query)
          : _ArtistResults(query: _query),
    );
  }
}

class _AlbumResults extends ConsumerWidget {
  const _AlbumResults({required this.query});

  final String query;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final async = ref.watch(neteaseAlbumSearchProvider(query));
    return async.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, stackTrace) => Center(
        child: TextButton.icon(
          onPressed: () => ref.invalidate(neteaseAlbumSearchProvider(query)),
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
              itemBuilder: (context, index) => _AlbumTile(album: albums[index]),
            ),
    );
  }
}

class _ArtistResults extends ConsumerWidget {
  const _ArtistResults({required this.query});

  final String query;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final async = ref.watch(neteaseArtistSearchProvider(query));
    return async.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, stackTrace) => Center(
        child: TextButton.icon(
          onPressed: () => ref.invalidate(neteaseArtistSearchProvider(query)),
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
              itemBuilder: (context, index) =>
                  _ArtistTile(artist: artists[index]),
            ),
    );
  }
}

class _AlbumTile extends StatelessWidget {
  const _AlbumTile({required this.album});

  final RemoteAlbum album;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: CoverImage(url: album.coverUrl, size: 56),
      title: Text(album.title, maxLines: 1, overflow: TextOverflow.ellipsis),
      subtitle: Text(
        [
          if (album.artist != null) album.artist!,
          if (album.year != null) '${album.year}',
        ].join(' · '),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      trailing: const Icon(AppIcons.chevronRight),
      onTap: () => Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (context) => NeteaseAlbumScreen(album: album),
        ),
      ),
    );
  }
}

class _ArtistTile extends StatelessWidget {
  const _ArtistTile({required this.artist});

  final RemoteArtist artist;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: ClipOval(child: CoverImage(url: artist.avatarUrl, size: 56)),
      title: Text(artist.name, maxLines: 1, overflow: TextOverflow.ellipsis),
      subtitle: Text('${artist.albumCount} · ${artist.songCount}'),
      trailing: const Icon(AppIcons.chevronRight),
      onTap: () => Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (context) => NeteaseArtistScreen(artist: artist),
        ),
      ),
    );
  }
}

/// One album: header plus its tracks.
class NeteaseAlbumScreen extends ConsumerWidget {
  const NeteaseAlbumScreen({super.key, required this.album});

  final RemoteAlbum album;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final tracksAsync = ref.watch(neteaseAlbumTracksProvider(album.id));
    final playback = ref.watch(playbackStateProvider).value;
    final compact = MediaQuery.sizeOf(context).width < AppBreakpoints.compact;

    return AppPageScaffold(
      header: AppPageHeader(
        title: album.title,
        subtitle: [
          if (album.artist != null) album.artist!,
          if (album.year != null) '${album.year}',
        ].join(' · '),
        compact: compact,
        leading: IconButton(
          key: const Key('netease_album_back'),
          tooltip: '',
          icon: const Icon(AppIcons.arrowBack),
          onPressed: () => Navigator.of(context).maybePop(),
        ),
      ),
      body: tracksAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stackTrace) => Center(
          child: TextButton.icon(
            onPressed: () =>
                ref.invalidate(neteaseAlbumTracksProvider(album.id)),
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
                      AppSpacing.md + MediaQuery.paddingOf(context).bottom,
                ),
                itemCount: tracks.length,
                separatorBuilder: (context, index) =>
                    const Divider(height: 1),
                itemBuilder: (context, index) {
                  final track = tracks[index];
                  return NeteaseTrackRow(
                    track: track,
                    isCurrent: playback?.currentTrack?.uri == track.uri,
                    isPlaying: playback?.isPlaying ?? false,
                    isLiked: false,
                    onTap: () => _play(ref, tracks, index),
                  );
                },
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

/// One artist: albums and hot songs.
class NeteaseArtistScreen extends ConsumerWidget {
  const NeteaseArtistScreen({super.key, required this.artist});

  final RemoteArtist artist;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final songsAsync = ref.watch(neteaseArtistSongsProvider(artist.id));
    final albumsAsync = ref.watch(neteaseArtistAlbumsProvider(artist.id));
    final playback = ref.watch(playbackStateProvider).value;
    final compact = MediaQuery.sizeOf(context).width < AppBreakpoints.compact;
    final horizontal = compact ? 16.0 : 28.0;

    return AppPageScaffold(
      header: AppPageHeader(
        title: artist.name,
        subtitle: '${artist.albumCount} · ${artist.songCount}',
        compact: compact,
        leading: IconButton(
          key: const Key('netease_artist_back'),
          tooltip: '',
          icon: const Icon(AppIcons.arrowBack),
          onPressed: () => Navigator.of(context).maybePop(),
        ),
      ),
      body: ListView(
        padding: EdgeInsets.fromLTRB(
          horizontal,
          0,
          horizontal,
          AppSpacing.md + MediaQuery.paddingOf(context).bottom,
        ),
        children: [
          if (albumsAsync.value?.isNotEmpty ?? false) ...[
            Text(
              l10n.albums,
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: AppSpacing.sm),
            SizedBox(
              height: 184,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: albumsAsync.value!.length,
                separatorBuilder: (context, index) =>
                    const SizedBox(width: 12),
                itemBuilder: (context, index) {
                  final album = albumsAsync.value![index];
                  return _AlbumCard(album: album);
                },
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
          ],
          Text(
            l10n.hotSongs,
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: AppSpacing.xs),
          songsAsync.when(
            loading: () => const Padding(
              padding: EdgeInsets.all(AppSpacing.lg),
              child: Center(child: CircularProgressIndicator()),
            ),
            error: (error, stackTrace) => TextButton.icon(
              onPressed: () => ref.invalidate(
                neteaseArtistSongsProvider(artist.id),
              ),
              icon: const Icon(AppIcons.refresh),
              label: Text(l10n.retry),
            ),
            data: (tracks) => Column(
              children: [
                for (var i = 0; i < tracks.length; i++)
                  NeteaseTrackRow(
                    track: tracks[i],
                    isCurrent: playback?.currentTrack?.uri == tracks[i].uri,
                    isPlaying: playback?.isPlaying ?? false,
                    isLiked: false,
                    onTap: () => _play(ref, tracks, i),
                  ),
              ],
            ),
          ),
        ],
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

class _AlbumCard extends StatelessWidget {
  const _AlbumCard({required this.album});

  final RemoteAlbum album;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return InkWell(
      onTap: () => Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (context) => NeteaseAlbumScreen(album: album),
        ),
      ),
      child: SizedBox(
        width: 128,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            CoverImage(url: album.coverUrl, size: 128),
            const SizedBox(height: 6),
            Text(
              album.title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.bodyMedium,
            ),
            if (album.year != null)
              Text(
                '${album.year}',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
          ],
        ),
      ),
    );
  }
}
