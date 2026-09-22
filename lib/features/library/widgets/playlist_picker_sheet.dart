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
import 'package:flind_player/core/repositories/playlist_repository.dart';
import 'package:flind_player/data/providers/playlist_providers.dart';
import 'package:flind_player/features/library/widgets/playlist_editor_dialog.dart';
import 'package:flind_player/l10n/app_localizations.dart';
import 'package:flind_player/shared/cover_image.dart';
import 'package:flind_player/shared/error_snack_bar.dart';

/// Opens the bottom sheet that adds [track] to a playlist.
Future<void> showPlaylistPickerSheet(
  BuildContext context, {
  required Track track,
}) {
  return showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    builder: (context) => PlaylistPickerSheet(track: track),
  );
}

/// Bottom sheet listing every playlist (favourites first) so the user can add
/// [track] to one of them, or create a new playlist and add to it.
class PlaylistPickerSheet extends ConsumerStatefulWidget {
  const PlaylistPickerSheet({super.key, required this.track});

  final Track track;

  @override
  ConsumerState<PlaylistPickerSheet> createState() =>
      _PlaylistPickerSheetState();
}

class _PlaylistPickerSheetState extends ConsumerState<PlaylistPickerSheet> {
  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final playlists = ref.watch(playlistsProvider).value ?? const <Playlist>[];

    return SafeArea(
      top: false,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: Text(l10n.selectPlaylist, style: theme.textTheme.titleMedium),
          ),
          Flexible(
            child: ListView(
              shrinkWrap: true,
              children: [
                for (final playlist in playlists)
                  _PlaylistPickerRow(
                    playlist: playlist,
                    track: widget.track,
                    onTap: () => _addTo(playlist),
                  ),
                ListTile(
                  leading: const Icon(Icons.add),
                  title: Text(l10n.newPlaylist),
                  onTap: _createAndAdd,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _displayName(AppLocalizations l10n, Playlist playlist) =>
      playlist.kind == PlaylistKind.favorites
          ? l10n.tabFavorites
          : playlist.name;

  Future<void> _addTo(Playlist playlist) async {
    final messenger = ScaffoldMessenger.of(context);
    final l10n = AppLocalizations.of(context);
    try {
      await ref
          .read(playlistRepositoryProvider)
          .addTrack(playlist.id, widget.track);
      if (!mounted) return;
      Navigator.of(context).pop();
      messenger
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            content: Text(l10n.addedToPlaylist(_displayName(l10n, playlist))),
            duration: const Duration(seconds: 2),
          ),
        );
    } catch (error) {
      if (!mounted) return;
      showErrorSnackBar(context, error);
    }
  }

  Future<void> _createAndAdd() async {
    final createdId = await showPlaylistEditorDialog(context);
    if (createdId == null || !mounted) return;
    final playlist = await ref
        .read(playlistRepositoryProvider)
        .playlistById(createdId);
    if (playlist == null || !mounted) return;
    await _addTo(playlist);
  }
}

/// One playlist row in the picker: cover, display name, and a check when the
/// track is already a member (in which case the row is disabled).
class _PlaylistPickerRow extends ConsumerStatefulWidget {
  const _PlaylistPickerRow({
    required this.playlist,
    required this.track,
    required this.onTap,
  });

  final Playlist playlist;
  final Track track;
  final VoidCallback onTap;

  @override
  ConsumerState<_PlaylistPickerRow> createState() => _PlaylistPickerRowState();
}

class _PlaylistPickerRowState extends ConsumerState<_PlaylistPickerRow> {
  late final Future<bool> _containsFuture;

  @override
  void initState() {
    super.initState();
    _containsFuture = ref
        .read(playlistRepositoryProvider)
        .containsTrack(widget.playlist.id, widget.track.uri);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final scheme = Theme.of(context).colorScheme;
    final cover = ref.watch(playlistCoverProvider(widget.playlist.id)).value;

    return FutureBuilder<bool>(
      future: _containsFuture,
      builder: (context, snapshot) {
        final contains = snapshot.data ?? false;
        return ListTile(
          leading: _PickerCover(cover: cover, size: 40),
          title: Text(
            widget.playlist.kind == PlaylistKind.favorites
                ? l10n.tabFavorites
                : widget.playlist.name,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          subtitle: contains ? Text(l10n.playlistAlreadyContains) : null,
          trailing: contains ? Icon(Icons.check, color: scheme.primary) : null,
          enabled: !contains,
          onTap: contains ? null : widget.onTap,
        );
      },
    );
  }
}

/// Small rounded playlist cover with a tonal fallback icon.
class _PickerCover extends StatelessWidget {
  const _PickerCover({required this.cover, required this.size});

  final PlaylistCover? cover;
  final double size;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final path = cover?.coverPath;
    final url = cover?.coverUrl;
    final hasCover =
        (path != null && path.isNotEmpty) || (url != null && url.isNotEmpty);

    return ClipRRect(
      borderRadius: BorderRadius.circular(size * 0.16),
      child: Container(
        width: size,
        height: size,
        color: scheme.surfaceContainerHighest,
        child: hasCover
            ? CoverImage(
                path: path,
                url: url,
                size: size,
                errorBuilder: (context, error, stackTrace) =>
                    _placeholder(scheme),
              )
            : _placeholder(scheme),
      ),
    );
  }

  Widget _placeholder(ColorScheme scheme) => Center(
    child: Icon(
      Icons.queue_music,
      size: size * 0.5,
      color: scheme.onSurfaceVariant,
    ),
  );
}