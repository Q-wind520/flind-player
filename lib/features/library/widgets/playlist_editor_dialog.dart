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

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:flind_player/core/repositories/playlist_repository.dart';
import 'package:flind_player/data/providers/playlist_providers.dart';
import 'package:flind_player/l10n/app_localizations.dart';
import 'package:flind_player/shared/cover_image.dart';
import 'package:flind_player/shared/error_snack_bar.dart';

/// Shows the create/edit playlist dialog.
///
/// Returns the playlist id when a playlist was created or updated, or `null`
/// when the user cancelled. Never offered for the built-in favourites playlist.
Future<int?> showPlaylistEditorDialog(
  BuildContext context, {
  Playlist? playlist,
}) {
  return showDialog<int>(
    context: context,
    builder: (context) => PlaylistEditorDialog(playlist: playlist),
  );
}

/// Create/edit form for a custom playlist: required name, optional
/// description and optional cover image.
class PlaylistEditorDialog extends ConsumerStatefulWidget {
  const PlaylistEditorDialog({super.key, this.playlist});

  /// The playlist being edited, or `null` to create a new one.
  final Playlist? playlist;

  @override
  ConsumerState<PlaylistEditorDialog> createState() =>
      _PlaylistEditorDialogState();
}

class _PlaylistEditorDialogState extends ConsumerState<PlaylistEditorDialog> {
  late final TextEditingController _nameController;
  late final TextEditingController _descriptionController;
  String? _coverPath;
  String? _coverUrl;
  bool _clearCover = false;
  String? _nameError;
  bool _saving = false;

  bool get _isEdit => widget.playlist != null;

  AppLocalizations get l10n => AppLocalizations.of(context);

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.playlist?.name ?? '');
    _descriptionController = TextEditingController(
      text: widget.playlist?.description ?? '',
    );
    _coverPath = widget.playlist?.coverPath;
    _coverUrl = widget.playlist?.coverUrl;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _pickCover() async {
    // file_picker 12 exposes `pickFiles` as a static returning the selected
    // files directly (empty list on cancel).
    final files = await FilePicker.pickFiles(type: FileType.image);
    if (files.isEmpty) return;
    final path = files.single.path;
    if (path == null || !mounted) return;
    setState(() {
      _coverPath = path;
      _coverUrl = null;
      _clearCover = false;
    });
  }

  Future<void> _save() async {
    final name = _nameController.text.trim();
    if (name.isEmpty) {
      setState(() => _nameError = l10n.playlistNameRequired);
      return;
    }
    setState(() {
      _saving = true;
      _nameError = null;
    });
    final repo = ref.read(playlistRepositoryProvider);
    final description = _descriptionController.text.trim();
    try {
      final int id;
      if (_isEdit) {
        await repo.updatePlaylist(
          widget.playlist!.id,
          name: name,
          description: description,
          coverPath: _coverPath,
          coverUrl: _coverUrl,
          clearCover: _clearCover,
        );
        id = widget.playlist!.id;
      } else {
        final created = await repo.createPlaylist(
          name: name,
          description: description.isEmpty ? null : description,
          coverPath: _coverPath,
          coverUrl: _coverUrl,
        );
        id = created.id;
      }
      if (!mounted) return;
      Navigator.of(context).pop(id);
    } catch (error) {
      if (!mounted) return;
      setState(() => _saving = false);
      showErrorSnackBar(context, error);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return AlertDialog(
      title: Text(_isEdit ? l10n.editPlaylist : l10n.newPlaylist),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextField(
              controller: _nameController,
              autofocus: true,
              decoration: InputDecoration(
                labelText: l10n.playlistName,
                errorText: _nameError,
              ),
              onChanged: (_) {
                if (_nameError != null) {
                  setState(() => _nameError = null);
                }
              },
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _descriptionController,
              maxLines: 2,
              decoration: InputDecoration(labelText: l10n.playlistDescription),
            ),
            const SizedBox(height: 16),
            _buildCoverSection(theme),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _saving ? null : () => Navigator.of(context).pop(),
          child: Text(l10n.cancel),
        ),
        FilledButton(
          onPressed: _saving ? null : _save,
          child: Text(_saving ? l10n.saving : l10n.confirm),
        ),
      ],
    );
  }

  Widget _buildCoverSection(ThemeData theme) {
    final scheme = theme.colorScheme;
    final hasCover =
        (_coverPath != null && _coverPath!.isNotEmpty) ||
        (_coverUrl != null && _coverUrl!.isNotEmpty);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(l10n.playlistCover, style: theme.textTheme.labelLarge),
        const SizedBox(height: 8),
        Row(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: Container(
                width: 56,
                height: 56,
                color: scheme.surfaceContainerHighest,
                child: hasCover
                    ? CoverImage(
                        path: _coverPath,
                        url: _coverUrl,
                        size: 56,
                        errorBuilder: (context, error, stackTrace) =>
                            const Icon(Icons.music_note),
                      )
                    : const Icon(Icons.music_note),
              ),
            ),
            const SizedBox(width: 12),
            TextButton.icon(
              onPressed: _pickCover,
              icon: const Icon(Icons.image_outlined),
              label: Text(l10n.chooseCover),
            ),
            if (hasCover)
              TextButton.icon(
                onPressed: () => setState(() {
                  _coverPath = null;
                  _coverUrl = null;
                  _clearCover = true;
                }),
                icon: const Icon(Icons.delete_outline),
                label: Text(l10n.removeCover),
              ),
          ],
        ),
      ],
    );
  }
}