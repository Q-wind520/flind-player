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

import 'package:flind_player/core/models/playback_queue.dart';
import 'package:flind_player/core/models/track.dart';
import 'package:flind_player/data/providers/database_providers.dart';
import 'package:flind_player/data/providers/online_source_providers.dart';
import 'package:flind_player/data/providers/playback_providers.dart';
import 'package:flind_player/features/library/widgets/track_actions_button.dart';
import 'package:flind_player/l10n/app_localizations.dart';
import 'package:flind_player/platform/permissions/permission_providers.dart';
import 'package:flind_player/shared/app_surface.dart';
import 'package:flind_player/shared/cover_image.dart';
import 'package:flind_player/shared/duration_format.dart';
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
class SearchScreen extends ConsumerStatefulWidget {
  const SearchScreen({super.key});

  @override
  ConsumerState<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends ConsumerState<SearchScreen> {
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
    return PlaybackPermissionScope(
      child: Scaffold(
        backgroundColor: AppSurface.colorOf(context),
        body: SafeArea(
          bottom: false,
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
                child: ValueListenableBuilder<TextEditingValue>(
                  valueListenable: _controller,
                  builder: (context, value, child) {
                    return TextField(
                      controller: _controller,
                      textInputAction: TextInputAction.search,
                      onSubmitted: _submit,
                      decoration: InputDecoration(
                        hintText: l10n.searchHint,
                        prefixIcon: const Icon(Icons.search),
                        suffixIcon: value.text.isEmpty
                            ? null
                            : IconButton(
                                icon: const Icon(Icons.clear),
                                onPressed: _clear,
                              ),
                        border: const OutlineInputBorder(),
                        isDense: true,
                      ),
                    );
                  },
                ),
              ),
              if (sources.length > 1)
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                  child: SegmentedButton<String>(
                    showSelectedIcon: false,
                    segments: <ButtonSegment<String>>[
                      for (final descriptor in sources)
                        ButtonSegment<String>(
                          value: descriptor.id,
                          label: Text(_sourceLabel(l10n, descriptor.id)),
                        ),
                    ],
                    selected: <String>{selectedId},
                    onSelectionChanged: (selection) {
                      setState(() => _selectedSourceId = selection.first);
                    },
                  ),
                ),
              Expanded(child: _buildBody(selectedId)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBody(String sourceId) {
    final l10n = AppLocalizations.of(context);
    if (_submittedQuery.isEmpty) {
      return EmptyState(
        icon: Icons.search,
        title: l10n.searchSourcesTitle,
        message: l10n.searchSourcesHint,
      );
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
            icon: Icons.search_off,
            title: l10n.noResults,
            message: l10n.tryAnotherKeyword,
          );
        }
        return ListView.builder(
          itemCount: tracks.length,
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
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final l10n = AppLocalizations.of(context);

    return ListTile(
      onTap: onTap,
      selected: isCurrent,
      leading: _SearchResultCover(track: track),
      title: Text(track.title, maxLines: 1, overflow: TextOverflow.ellipsis),
      subtitle: Text(
        track.artist ?? l10n.unknownUp,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (isPlaying) ...[
            Icon(Icons.graphic_eq, size: 20, color: scheme.primary),
            const SizedBox(width: 8),
          ],
          Text(
            formatTrackDuration(track.duration),
            style: theme.textTheme.labelMedium,
          ),
          TrackActionsButton(
            track: track,
            showSaveToLibrary: true,
            onSaveToLibrary: onSave,
          ),
        ],
      ),
    );
  }
}

/// Small square cover for a search result, falling back to a music note.
class _SearchResultCover extends StatelessWidget {
  const _SearchResultCover({required this.track});

  final Track track;

  static const double _size = 48;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final coverPath = track.coverPath;
    final coverUrl = track.coverUrl;
    final hasCover =
        (coverPath != null && coverPath.isNotEmpty) ||
        (coverUrl != null && coverUrl.isNotEmpty);

    return ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: Container(
        width: _size,
        height: _size,
        color: scheme.surfaceContainerHighest,
        child: hasCover
            ? CoverImage(
                path: coverPath,
                url: coverUrl,
                size: _size,
                errorBuilder: (context, error, stackTrace) =>
                    Icon(Icons.music_note, color: scheme.onSurfaceVariant),
              )
            : Icon(Icons.music_note, color: scheme.onSurfaceVariant),
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
            Icon(Icons.error_outline, size: 48, color: theme.colorScheme.error),
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
              icon: const Icon(Icons.refresh),
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
