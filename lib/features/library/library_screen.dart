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

import 'dart:async';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:flind_player/core/models/playback_queue.dart';
import 'package:flind_player/core/models/track.dart';
import 'package:flind_player/core/models/track_sort.dart';
import 'package:flind_player/data/providers/database_providers.dart';
import 'package:flind_player/data/providers/library_providers.dart';
import 'package:flind_player/data/providers/persistence_providers.dart';
import 'package:flind_player/data/providers/playback_providers.dart';
import 'package:flind_player/data/services/library_sync_service.dart';
import 'package:flind_player/features/library/library_sort_provider.dart';
import 'package:flind_player/features/library/widgets/track_actions_button.dart';
import 'package:flind_player/features/playlists/bilibili_favorites_screen.dart';
import 'package:flind_player/l10n/app_localizations.dart';
import 'package:flind_player/platform/permissions/permission_providers.dart';
import 'package:flind_player/platform/permissions/permission_service.dart';
import 'package:flind_player/app/theme/app_theme.dart';
import 'package:flind_player/shared/cover_image.dart';
import 'package:flind_player/shared/duration_format.dart';
import 'package:flind_player/shared/error_messages.dart';
import 'package:flind_player/shared/error_snack_bar.dart';
import 'package:flind_player/shared/platform_support.dart';
import 'package:flind_player/shared/responsive_center.dart';

/// Actions exposed by the library overflow menu.
enum _LibraryAction { addFolder, rescan, importFiles, bilibiliFavorites }

/// Library list mode: all tracks vs. favourites only.
enum LibraryFilter { all, favourites }

/// The music library: a searchable, mixed local + online track browser with
/// folder scanning, import, tap-to-play and a favourites filter.
class LibraryScreen extends ConsumerStatefulWidget {
  const LibraryScreen({super.key});

  @override
  ConsumerState<LibraryScreen> createState() => _LibraryScreenState();
}

class _LibraryScreenState extends ConsumerState<LibraryScreen> {
  final TextEditingController _searchController = TextEditingController();
  Timer? _debounce;
  String _query = '';
  LibraryFilter _filter = LibraryFilter.all;

  /// Local FTS is fast, but debouncing keeps the family provider from churning
  /// on every keystroke.
  static const Duration _debounceDelay = Duration(milliseconds: 250);

  @override
  void dispose() {
    _debounce?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  void _onSearchChanged(String value) {
    _debounce?.cancel();
    _debounce = Timer(_debounceDelay, () {
      if (!mounted) return;
      final trimmed = value.trim();
      if (trimmed == _query) return;
      setState(() => _query = trimmed);
    });
  }

  void _clearSearch() {
    _debounce?.cancel();
    _searchController.clear();
    if (_query.isNotEmpty) {
      setState(() => _query = '');
    }
  }

  Future<void> _onAction(_LibraryAction action) async {
    switch (action) {
      case _LibraryAction.addFolder:
        await _addFolder();
      case _LibraryAction.rescan:
        _startSync();
      case _LibraryAction.importFiles:
        await _importFiles();
      case _LibraryAction.bilibiliFavorites:
        await _openBilibiliFavorites();
    }
  }

  /// Pushes the anonymous Bilibili public-favourites browser.
  Future<void> _openBilibiliFavorites() {
    return Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (context) => const BilibiliFavoritesScreen(),
      ),
    );
  }

  /// Picks a directory, persists it as a scan root and starts a sync.
  Future<void> _addFolder() async {
    final messenger = ScaffoldMessenger.of(context);
    final l10n = AppLocalizations.of(context);
    final permission = await ref
        .read(permissionCoordinatorProvider)
        .ensureAudioLibrary();
    if (permission != PermissionResult.granted) {
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            permissionDeniedMessage(
              l10n,
              AppPermission.audioLibrary,
              permanentlyDenied:
                  permission == PermissionResult.permanentlyDenied,
            ),
          ),
        ),
      );
      return;
    }
    try {
      final path = await FilePicker.getDirectoryPath(
        dialogTitle: l10n.selectMusicFolder,
      );
      if (path == null) {
        return;
      }
      await ref.read(musicLibraryRepositoryProvider).addScanRoot(path);
      ref.invalidate(scanRootsProvider);
      _startSync();
      messenger.showSnackBar(SnackBar(content: Text(l10n.folderAdded(path))));
    } catch (error) {
      if (!mounted) return;
      showErrorSnackBar(context, error);
    }
  }

  /// Runs a full library sync. The service publishes progress through
  /// [librarySyncStateProvider] and is a no-op while already running.
  void _startSync() {
    unawaited(ref.read(librarySyncServiceProvider).sync());
  }

  /// Picks local files, persists every readable track, and reports the result.
  Future<void> _importFiles() async {
    final messenger = ScaffoldMessenger.of(context);
    final l10n = AppLocalizations.of(context);
    final permission = await ref
        .read(permissionCoordinatorProvider)
        .ensureAudioLibrary();
    if (permission != PermissionResult.granted) {
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            permissionDeniedMessage(
              l10n,
              AppPermission.audioLibrary,
              permanentlyDenied:
                  permission == PermissionResult.permanentlyDenied,
            ),
          ),
        ),
      );
      return;
    }
    try {
      final importer = ref.read(localFileImporterProvider);
      final repository = ref.read(musicLibraryRepositoryProvider);

      final tracks = await importer.pickAndImport();
      if (tracks.isEmpty) {
        messenger.showSnackBar(SnackBar(content: Text(l10n.noImportableFiles)));
        return;
      }

      for (final track in tracks) {
        await repository.upsertTrack(track);
      }
      messenger.showSnackBar(
        SnackBar(content: Text(l10n.importedTracks(tracks.length))),
      );
    } catch (error) {
      if (!mounted) return;
      showErrorSnackBar(context, error);
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

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final hasLocalLibrary = supportsLocalLibrary;
    final syncState =
        ref.watch(librarySyncStateProvider).value ?? LibrarySyncState.idle;
    final isSyncing = switch (syncState.phase) {
      LibrarySyncPhase.scanning ||
      LibrarySyncPhase.saving ||
      LibrarySyncPhase.artwork => true,
      _ => false,
    };

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.musicLibrary),
        actions: [
          if (hasLocalLibrary)
            _SortButton(
              currentSort:
                  ref.watch(librarySortProvider).value ?? TrackSort.title,
              onSortChanged: (sort) =>
                  ref.read(librarySortProvider.notifier).setSort(sort),
            ),
          PopupMenuButton<_LibraryAction>(
            // Empty message suppresses the default "Show menu" hover bubble.
            tooltip: '',
            onSelected: _onAction,
            itemBuilder: (context) => <PopupMenuEntry<_LibraryAction>>[
              if (hasLocalLibrary) ...[
                PopupMenuItem(
                  value: _LibraryAction.addFolder,
                  enabled: !isSyncing,
                  child: _MenuRow(
                    icon: Icons.create_new_folder_outlined,
                    label: l10n.addFolder,
                  ),
                ),
                PopupMenuItem(
                  value: _LibraryAction.rescan,
                  enabled: !isSyncing,
                  child: _MenuRow(icon: Icons.refresh, label: l10n.rescan),
                ),
                PopupMenuItem(
                  value: _LibraryAction.importFiles,
                  child: _MenuRow(icon: Icons.add, label: l10n.importFiles),
                ),
              ],
              PopupMenuItem(
                value: _LibraryAction.bilibiliFavorites,
                child: _MenuRow(
                  icon: Icons.cloud_outlined,
                  label: l10n.browseBiliFavorites,
                ),
              ),
            ],
          ),
        ],
        bottom: hasLocalLibrary ? _buildSearchBar() : null,
      ),
      body: hasLocalLibrary
          ? Column(
              children: [
                _SyncStatus(state: syncState),
                _FilterBar(
                  filter: _filter,
                  onFilterChanged: (f) => setState(() => _filter = f),
                ),
                Expanded(child: _buildBody()),
              ],
            )
          : const _UnsupportedLibraryNotice(),
    );
  }

  /// The search field pinned under the library AppBar.
  PreferredSize _buildSearchBar() {
    final l10n = AppLocalizations.of(context);
    return PreferredSize(
      preferredSize: const Size.fromHeight(64),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
        child: ValueListenableBuilder<TextEditingValue>(
          valueListenable: _searchController,
          builder: (context, value, child) {
            return TextField(
              controller: _searchController,
              textInputAction: TextInputAction.search,
              onChanged: _onSearchChanged,
              decoration: InputDecoration(
                hintText: _filter == LibraryFilter.favourites
                    ? l10n.searchFavorites
                    : l10n.searchLibrary,
                prefixIcon: const Icon(Icons.search),
                suffixIcon: value.text.isEmpty
                    ? null
                    : IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: _clearSearch,
                      ),
                border: const OutlineInputBorder(),
                isDense: true,
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildBody() {
    final l10n = AppLocalizations.of(context);
    final playback = ref.watch(playbackStateProvider).value;
    final currentUri = playback?.currentTrack?.uri;
    final isPlaying = playback?.isPlaying ?? false;

    if (_filter == LibraryFilter.favourites) {
      return _buildFavouritesBody(currentUri, isPlaying);
    }

    if (_query.isNotEmpty) {
      final resultsAsync = ref.watch(librarySearchProvider(_query));
      return resultsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stackTrace) => _LibraryError(
          error: error,
          title: l10n.searchFailed,
          onRetry: () => ref.invalidate(librarySearchProvider(_query)),
        ),
        data: (tracks) {
          if (tracks.isEmpty) {
            return const _NoSearchResults();
          }
          return _trackDisplay(tracks, currentUri, isPlaying);
        },
      );
    }

    final tracksAsync = ref.watch(libraryTracksProvider);
    return tracksAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, stackTrace) => _LibraryError(
        error: error,
        onRetry: () => ref.invalidate(libraryTracksProvider),
      ),
      data: (tracks) {
        if (tracks.isEmpty) {
          return _EmptyLibrary(onImport: _importFiles, onAddFolder: _addFolder);
        }
        return _trackDisplay(tracks, currentUri, isPlaying);
      },
    );
  }

  /// Builds the body for favourites-only mode.
  ///
  /// Client-side filtering is used: favourites are typically small (tens to
  /// low hundreds), so there is no need for server-side/FTS filtering.
  ///
  /// Favourites are also sorted client-side using the same comparator as the
  /// server-side library sort: the list is small enough that a simple
  /// `List.sort` is cheaper than a round-trip to the repository.
  Widget _buildFavouritesBody(String? currentUri, bool isPlaying) {
    final l10n = AppLocalizations.of(context);
    final favouritesAsync = ref.watch(favoritesProvider);
    final sort = ref.watch(librarySortProvider).value ?? TrackSort.title;
    return favouritesAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, stackTrace) => _LibraryError(
        error: error,
        title: l10n.loadFavoritesFailed,
        onRetry: () => ref.invalidate(favoritesProvider),
      ),
      data: (favourites) {
        if (favourites.isEmpty) {
          return const _EmptyFavourites();
        }
        final sorted = _sortTracks(favourites, sort);
        if (_query.isNotEmpty) {
          final lowerQuery = _query.toLowerCase();
          final filtered = sorted
              .where(
                (t) =>
                    t.title.toLowerCase().contains(lowerQuery) ||
                    (t.artist?.toLowerCase().contains(lowerQuery) ?? false),
              )
              .toList();
          if (filtered.isEmpty) {
            return const _NoFavouritesSearchResults();
          }
          return _trackDisplay(filtered, currentUri, isPlaying);
        }
        return _trackDisplay(sorted, currentUri, isPlaying);
      },
    );
  }

  Widget _trackDisplay(List<Track> tracks, String? currentUri, bool isPlaying) {
    return LayoutBuilder(
      builder: (context, constraints) {
        if (!AppBreakpoints.isCompact(constraints.biggest)) {
          return _trackGrid(tracks, currentUri, isPlaying);
        }
        return _trackList(tracks, currentUri, isPlaying);
      },
    );
  }

  Widget _trackList(List<Track> tracks, String? currentUri, bool isPlaying) {
    return ListView.builder(
      itemCount: tracks.length,
      itemBuilder: (context, index) {
        final track = tracks[index];
        final isCurrent = currentUri != null && track.uri == currentUri;
        return _TrackTile(
          track: track,
          isCurrent: isCurrent,
          isPlaying: isCurrent && isPlaying,
          onTap: () => _play(tracks, index),
        );
      },
    );
  }

  Widget _trackGrid(List<Track> tracks, String? currentUri, bool isPlaying) {
    return GridView.builder(
      padding: const EdgeInsets.all(12),
      gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
        maxCrossAxisExtent: 220,
        childAspectRatio: 0.82,
        crossAxisSpacing: 10,
        mainAxisSpacing: 10,
      ),
      itemCount: tracks.length,
      itemBuilder: (context, index) {
        final track = tracks[index];
        final isCurrent = currentUri != null && track.uri == currentUri;
        return _TrackCard(
          track: track,
          isCurrent: isCurrent,
          isPlaying: isCurrent && isPlaying,
          onTap: () => _play(tracks, index),
        );
      },
    );
  }

  /// Client-side sort matching the server-side [TrackSort] comparators.
  ///
  /// Used for the favourites list, which is too small to warrant a DB round-trip.
  static List<Track> _sortTracks(List<Track> tracks, TrackSort sort) {
    final sorted = List<Track>.from(tracks);
    sorted.sort((a, b) {
      return switch (sort) {
        TrackSort.title => a.title.toLowerCase().compareTo(
          b.title.toLowerCase(),
        ),
        TrackSort.artist => _compareNullable(
          a.artist?.toLowerCase(),
          b.artist?.toLowerCase(),
        ),
        TrackSort.album => _compareNullable(
          a.album?.toLowerCase(),
          b.album?.toLowerCase(),
        ),
        TrackSort.recentlyAdded => b.id?.compareTo(a.id ?? 0) ?? 0,
      };
    });
    return sorted;
  }

  static int _compareNullable(String? a, String? b) {
    if (a == null && b == null) return 0;
    if (a == null) return 1; // nulls last
    if (b == null) return -1;
    return a.compareTo(b);
  }
}

/// Compact filter bar at the top of the library list.
class _FilterBar extends StatelessWidget {
  const _FilterBar({required this.filter, required this.onFilterChanged});

  final LibraryFilter filter;
  final ValueChanged<LibraryFilter> onFilterChanged;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: SegmentedButton<LibraryFilter>(
        segments: [
          ButtonSegment<LibraryFilter>(
            value: LibraryFilter.all,
            label: Text(l10n.tabAll),
          ),
          ButtonSegment<LibraryFilter>(
            value: LibraryFilter.favourites,
            label: Text(l10n.tabFavorites),
          ),
        ],
        selected: {filter},
        onSelectionChanged: (selected) {
          if (selected.isNotEmpty) onFilterChanged(selected.first);
        },
        style: ButtonStyle(
          visualDensity: VisualDensity.compact,
          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        ),
      ),
    );
  }
}

/// Popup button that lets the user choose the library sort order.
class _SortButton extends StatelessWidget {
  const _SortButton({required this.currentSort, required this.onSortChanged});

  final TrackSort currentSort;
  final ValueChanged<TrackSort> onSortChanged;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return PopupMenuButton<TrackSort>(
      // Empty message suppresses the default "Show menu" hover bubble.
      tooltip: '',
      initialValue: currentSort,
      onSelected: onSortChanged,
      itemBuilder: (context) => [
        for (final sort in TrackSort.values)
          PopupMenuItem<TrackSort>(
            value: sort,
            child: Row(
              children: [
                if (sort == currentSort)
                  Icon(
                    Icons.check,
                    size: 20,
                    color: Theme.of(context).colorScheme.primary,
                  )
                else
                  const SizedBox(width: 20),
                const SizedBox(width: 8),
                Text(_sortLabel(l10n, sort)),
              ],
            ),
          ),
      ],
      icon: const Icon(Icons.sort),
    );
  }

  static String _sortLabel(AppLocalizations l10n, TrackSort sort) =>
      switch (sort) {
        TrackSort.title => l10n.sortByTitle,
        TrackSort.artist => l10n.sortByArtist,
        TrackSort.album => l10n.sortByAlbum,
        TrackSort.recentlyAdded => l10n.sortRecentlyAdded,
      };
}

/// A menu entry: leading icon plus label.
class _MenuRow extends StatelessWidget {
  const _MenuRow({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(children: [Icon(icon), const SizedBox(width: 12), Text(label)]);
  }
}

/// Inline progress / result banner for the active or last library sync.
class _SyncStatus extends StatelessWidget {
  const _SyncStatus({required this.state});

  final LibrarySyncState state;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final scheme = Theme.of(context).colorScheme;
    return switch (state.phase) {
      LibrarySyncPhase.idle => const SizedBox.shrink(),
      LibrarySyncPhase.scanning => _SyncBanner(
        text: l10n.scanning(state.processed, state.discovered),
        color: scheme.primary,
        showProgress: true,
        progress: state.discovered > 0
            ? state.processed / state.discovered
            : null,
      ),
      LibrarySyncPhase.saving => _SyncBanner(
        text: l10n.saving,
        color: scheme.primary,
        showProgress: true,
      ),
      LibrarySyncPhase.artwork => _SyncBanner(
        text: l10n.coversCached(state.coversCached, state.saved),
        color: scheme.primary,
        showProgress: true,
        progress: state.saved > 0 ? state.coversCached / state.saved : null,
      ),
      LibrarySyncPhase.done => _SyncBanner(
        text: l10n.syncedAddedRemoved(
          state.discovered,
          state.saved,
          state.markedMissing,
        ),
        color: scheme.tertiary,
        icon: Icons.check_circle_outline,
      ),
      LibrarySyncPhase.failed => _SyncBanner(
        text: l10n.syncFailedWith(
          state.error == null
              ? l10n.unknownError
              : describeError(l10n, state.error!),
        ),
        color: scheme.error,
        icon: Icons.error_outline,
      ),
    };
  }
}

/// A tonal strip carrying a sync line and optional progress bar.
class _SyncBanner extends StatelessWidget {
  const _SyncBanner({
    required this.text,
    required this.color,
    this.icon,
    this.showProgress = false,
    this.progress,
  });

  final String text;
  final Color color;
  final IconData? icon;
  final bool showProgress;
  final double? progress;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Material(
      color: theme.colorScheme.surfaceContainerHighest,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                if (icon != null) ...[
                  Icon(icon, size: 18, color: color),
                  const SizedBox(width: 8),
                ],
                Expanded(
                  child: Text(
                    text,
                    style: theme.textTheme.bodyMedium?.copyWith(color: color),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            if (showProgress) ...[
              const SizedBox(height: 8),
              LinearProgressIndicator(value: progress, color: color),
            ],
          ],
        ),
      ),
    );
  }
}

/// A single library row with cover, title, artist, source badge, duration and
/// a consolidated actions popup menu.
class _TrackTile extends StatelessWidget {
  const _TrackTile({
    required this.track,
    required this.isCurrent,
    required this.isPlaying,
    required this.onTap,
  });

  final Track track;
  final bool isCurrent;
  final bool isPlaying;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final l10n = AppLocalizations.of(context);

    return ListTile(
      onTap: onTap,
      selected: isCurrent,
      leading: _TrackCover(track: track, size: 48),
      title: Text(track.title, maxLines: 1, overflow: TextOverflow.ellipsis),
      subtitle: Row(
        children: [
          Expanded(
            child: Text(
              track.artist ?? l10n.unknownArtist,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(width: 8),
          _SourceBadge(source: track.source),
        ],
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
          TrackActionsButton(track: track),
        ],
      ),
    );
  }
}

/// A card tile for the wide-screen grid layout.
///
/// Shows a square cover, title, artist, source badge, playing indicator, and
/// a trailing actions button overlaid in the top-right corner.
class _TrackCard extends StatelessWidget {
  const _TrackCard({
    required this.track,
    required this.isCurrent,
    required this.isPlaying,
    required this.onTap,
  });

  final Track track;
  final bool isCurrent;
  final bool isPlaying;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final l10n = AppLocalizations.of(context);

    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              child: Stack(
                alignment: Alignment.center,
                children: [
                  _TrackCover(track: track, size: double.infinity),
                  if (isPlaying)
                    Positioned(
                      bottom: 6,
                      left: 6,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: scheme.primaryContainer,
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Icon(
                          Icons.graphic_eq,
                          size: 14,
                          color: scheme.onPrimaryContainer,
                        ),
                      ),
                    ),
                  Positioned(
                    top: 2,
                    right: 2,
                    child: TrackActionsButton(track: track),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 6, 8, 4),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    track.title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w500,
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
                  const SizedBox(height: 2),
                  _SourceBadge(source: track.source),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Small tonal chip naming the track's source.
class _SourceBadge extends StatelessWidget {
  const _SourceBadge({required this.source});

  final String source;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final l10n = AppLocalizations.of(context);
    final label = switch (source) {
      'local' => l10n.sourceLocal,
      'bilibili' => l10n.sourceBilibili,
      _ => source,
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
      decoration: BoxDecoration(
        color: scheme.secondaryContainer,
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        label,
        style: theme.textTheme.labelSmall?.copyWith(
          color: scheme.onSecondaryContainer,
        ),
      ),
    );
  }
}

/// Rounded cover art, falling back to a tonal music-note placeholder.
class _TrackCover extends StatelessWidget {
  const _TrackCover({required this.track, required this.size});

  final Track track;

  /// Fixed size in pixels, or `double.infinity` when the cover should fill its
  /// parent (used inside the grid card's [Expanded] wrapper).
  final double size;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final coverPath = track.coverPath;
    final hasCover = coverPath != null && coverPath.isNotEmpty;
    final useFixedSize = !size.isInfinite;
    final borderRadius = useFixedSize ? size * 0.16 : 4.0;

    Widget child = Container(
      width: useFixedSize ? size : null,
      height: useFixedSize ? size : null,
      color: scheme.surfaceContainerHighest,
      child: hasCover
          ? CoverImage(
              path: coverPath,
              size: size,
              errorBuilder: (context, error, stackTrace) =>
                  _placeholder(scheme),
            )
          : _placeholder(scheme),
    );

    return ClipRRect(
      borderRadius: BorderRadius.circular(borderRadius),
      child: child,
    );
  }

  Widget _placeholder(ColorScheme scheme) => Center(
    child: Icon(
      Icons.music_note,
      size: size.isInfinite ? 40 : size * 0.5,
      color: scheme.onSurfaceVariant,
    ),
  );
}

/// Shown when the platform offers no local library (iOS): explains the
/// limitation instead of prompting the user to add folders or import files.
class _UnsupportedLibraryNotice extends StatelessWidget {
  const _UnsupportedLibraryNotice();

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
              Icons.library_music_outlined,
              size: 64,
              color: theme.colorScheme.onSurfaceVariant,
            ),
            const SizedBox(height: 16),
            Text(
              l10n.iosLibraryUnsupportedTitle,
              style: theme.textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            Text(
              l10n.iosLibraryUnsupportedHint,
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

/// Shown when the library has no tracks yet.
class _EmptyLibrary extends StatelessWidget {
  const _EmptyLibrary({required this.onImport, required this.onAddFolder});

  final VoidCallback onImport;
  final VoidCallback onAddFolder;

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
              Icons.library_music_outlined,
              size: 64,
              color: theme.colorScheme.onSurfaceVariant,
            ),
            const SizedBox(height: 16),
            Text(l10n.emptyLibraryTitle, style: theme.textTheme.titleMedium),
            const SizedBox(height: 8),
            Text(
              l10n.emptyLibraryHint,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            FilledButton.tonalIcon(
              onPressed: onAddFolder,
              icon: const Icon(Icons.create_new_folder_outlined),
              label: Text(l10n.addFolder),
            ),
            const SizedBox(height: 8),
            TextButton.icon(
              onPressed: onImport,
              icon: const Icon(Icons.add),
              label: Text(l10n.importLocalMusic),
            ),
          ],
        ),
      ),
    );
  }
}

/// Shown when the library search returns no tracks.
class _NoSearchResults extends StatelessWidget {
  const _NoSearchResults();

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
              Icons.search_off,
              size: 64,
              color: theme.colorScheme.onSurfaceVariant,
            ),
            const SizedBox(height: 16),
            Text(l10n.noMatchingTracks, style: theme.textTheme.titleMedium),
            const SizedBox(height: 8),
            Text(
              l10n.tryAnotherKeyword,
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

/// Shown when favourites mode is active but there are no favourited tracks.
class _EmptyFavourites extends StatelessWidget {
  const _EmptyFavourites();

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
              Icons.favorite_border,
              size: 64,
              color: theme.colorScheme.onSurfaceVariant,
            ),
            const SizedBox(height: 16),
            Text(l10n.noFavorites, style: theme.textTheme.titleMedium),
            const SizedBox(height: 8),
            Text(
              l10n.noFavoritesHint,
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

/// Shown when favourites mode is active, a query is entered, but nothing matches.
class _NoFavouritesSearchResults extends StatelessWidget {
  const _NoFavouritesSearchResults();

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
              Icons.search_off,
              size: 64,
              color: theme.colorScheme.onSurfaceVariant,
            ),
            const SizedBox(height: 16),
            Text(l10n.noMatchingFavorites, style: theme.textTheme.titleMedium),
            const SizedBox(height: 8),
            Text(
              l10n.tryAnotherKeyword,
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

/// Shown when the library stream (or a search) fails.
class _LibraryError extends StatelessWidget {
  const _LibraryError({required this.error, this.title, this.onRetry});

  final Object error;
  final String? title;
  final VoidCallback? onRetry;

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
              title ?? l10n.loadLibraryFailed,
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
            if (onRetry != null) ...[
              const SizedBox(height: 16),
              OutlinedButton.icon(
                onPressed: onRetry,
                icon: const Icon(Icons.refresh),
                label: Text(l10n.retry),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
