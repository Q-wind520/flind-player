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

import 'package:flind_player/app/theme/app_icons.dart';
import 'package:flind_player/app/theme/app_theme.dart';
import 'package:flind_player/app/theme/app_tokens.dart';
import 'package:flind_player/core/models/playback_queue.dart';
import 'package:flind_player/core/models/library_view.dart';
import 'package:flind_player/core/models/track.dart';
import 'package:flind_player/core/models/track_sort.dart';
import 'package:flind_player/data/providers/database_providers.dart';
import 'package:flind_player/data/providers/library_providers.dart';
import 'package:flind_player/data/providers/persistence_providers.dart';
import 'package:flind_player/data/providers/playback_providers.dart';
import 'package:flind_player/data/services/library_sync_service.dart';
import 'package:flind_player/features/library/library_sort_provider.dart';
import 'package:flind_player/features/library/library_view_provider.dart';
import 'package:flind_player/features/library/track_sorting.dart';
import 'package:flind_player/features/library/widgets/library_sort_menu_button.dart';
import 'package:flind_player/features/library/widgets/library_sources.dart';
import 'package:flind_player/features/library/widgets/library_view_menu_button.dart';
import 'package:flind_player/features/library/widgets/playlist_editor_dialog.dart';
import 'package:flind_player/features/library/widgets/playlists_section.dart';
import 'package:flind_player/features/library/widgets/track_view.dart';
import 'package:flind_player/l10n/app_localizations.dart';
import 'package:flind_player/platform/permissions/permission_providers.dart';
import 'package:flind_player/platform/permissions/permission_service.dart';
import 'package:flind_player/shared/app_page_header.dart';
import 'package:flind_player/shared/app_page_scaffold.dart';
import 'package:flind_player/shared/app_search_field.dart';
import 'package:flind_player/shared/empty_state.dart';
import 'package:flind_player/shared/error_messages.dart';
import 'package:flind_player/shared/error_snack_bar.dart';
import 'package:flind_player/shared/platform_support.dart';
import 'package:flind_player/shared/responsive_center.dart';

/// Library sections: all tracks, favourites, and user playlists.
///
/// The enum order is also the `TabBar`/`TabBarView` order.
enum LibrarySection { all, favorites, playlists }

/// The music library: a searchable, mixed local + online track browser with
/// folder scanning, import, tap-to-play and a favourites filter.
class LibraryScreen extends ConsumerStatefulWidget {
  const LibraryScreen({super.key});

  @override
  ConsumerState<LibraryScreen> createState() => _LibraryScreenState();
}

class _LibraryScreenState extends ConsumerState<LibraryScreen>
    with SingleTickerProviderStateMixin {
  final TextEditingController _searchController = TextEditingController();

  late final TabController _tabs;

  Timer? _debounce;
  String _query = '';
  LibrarySection _section = LibrarySection.all;

  /// Text of the sync bubble currently shown, so identical progress updates do
  /// not re-trigger the notification.
  String? _syncBubbleText;

  @override
  void initState() {
    super.initState();
    _tabs = TabController(
      length: LibrarySection.values.length,
      vsync: this,
    )..addListener(_onTabChanged);
  }

  void _onTabChanged() {
    final next = LibrarySection.values[_tabs.index];
    if (next == _section) return;
    setState(() => _section = next);
  }

  /// Local FTS is fast, but debouncing keeps the family provider from churning
  /// on every keystroke.
  static const Duration _debounceDelay = Duration(milliseconds: 250);

  @override
  void dispose() {
    _debounce?.cancel();
    _searchController.dispose();
    _tabs
      ..removeListener(_onTabChanged)
      ..dispose();
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

  /// Opens the create-playlist dialog from the header "+" button.
  void _createPlaylist() {
    unawaited(showPlaylistEditorDialog(context));
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
    ref.listen(librarySyncStateProvider, (previous, next) {
      _onSyncStateChanged(next);
    });

    return AppPageScaffold(
      header: _buildHeaderRow(),
      body: _buildBody(),
    );
  }

  /// The page header: title, sort/view actions, and the three library tabs.
  Widget _buildHeaderRow() {
    final l10n = AppLocalizations.of(context);
    final compact = MediaQuery.sizeOf(context).width < AppBreakpoints.compact;
    final horizontal = compact ? 16.0 : 28.0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        AppPageHeader(
          title: l10n.navLibrary,
          compact: compact,
          actions: <Widget>[
            if (_section != LibrarySection.playlists)
              const LibrarySortMenuButton(),
            LibraryViewMenuButton(scope: _scopeForSection(_section)),
            if (_section == LibrarySection.playlists)
              IconButton(
                key: const Key('library_add_playlist'),
                tooltip: '',
                icon: const Icon(AppIcons.add),
                onPressed: _createPlaylist,
              ),
          ],
        ),
        Padding(
          padding: EdgeInsets.symmetric(horizontal: horizontal),
          child: TabBar(
            controller: _tabs,
            isScrollable: false,
            dividerColor: Colors.transparent,
            indicatorSize: TabBarIndicatorSize.label,
            tabs: [
              Tab(text: l10n.tabAll),
              Tab(text: l10n.tabFavorites),
              Tab(text: l10n.tabPlaylists),
            ],
          ),
        ),
      ],
    );
  }

  /// Maps a library section to its persisted view scope.
  static LibraryViewScope _scopeForSection(LibrarySection section) =>
      switch (section) {
        LibrarySection.all => LibraryViewScope.all,
        LibrarySection.favorites => LibraryViewScope.favorites,
        LibrarySection.playlists => LibraryViewScope.playlists,
      };

  /// The inline search field, shown under the header on the 全部 section.
  Widget _buildSearchField() {
    final l10n = AppLocalizations.of(context);
    final compact = MediaQuery.sizeOf(context).width < AppBreakpoints.compact;
    final horizontal = compact ? 16.0 : 28.0;
    return Padding(
      padding: EdgeInsets.fromLTRB(horizontal, 0, horizontal, AppSpacing.md),
      child: AppSearchField(
        controller: _searchController,
        hintText: l10n.searchLibrary,
        onChanged: _onSearchChanged,
        onClear: _clearSearch,
      ),
    );
  }

  /// Surfaces sync progress and results as floating bubble notifications.
  void _onSyncStateChanged(AsyncValue<LibrarySyncState> asyncState) {
    if (!mounted) return;
    final state = asyncState.value;
    if (state == null) return;
    final l10n = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);

    switch (state.phase) {
      case LibrarySyncPhase.idle:
        return;
      case LibrarySyncPhase.scanning:
      case LibrarySyncPhase.saving:
      case LibrarySyncPhase.artwork:
        final text = switch (state.phase) {
          LibrarySyncPhase.scanning => l10n.scanning(
            state.processed,
            state.discovered,
          ),
          LibrarySyncPhase.saving => l10n.saving,
          _ => l10n.coversCached(state.coversCached, state.saved),
        };
        if (_syncBubbleText == text) return;
        _syncBubbleText = text;
        messenger
          ..hideCurrentSnackBar()
          ..showSnackBar(
            SnackBar(
              duration: const Duration(days: 1),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(text),
                  const SizedBox(height: 8),
                  LinearProgressIndicator(value: _syncProgress(state)),
                ],
              ),
            ),
          );
      case LibrarySyncPhase.done:
        _syncBubbleText = null;
        messenger
          ..hideCurrentSnackBar()
          ..showSnackBar(
            SnackBar(
              duration: const Duration(seconds: 3),
              content: Text(
                l10n.syncedAddedRemoved(
                  state.discovered,
                  state.saved,
                  state.markedMissing,
                ),
              ),
            ),
          );
      case LibrarySyncPhase.failed:
        _syncBubbleText = null;
        messenger
          ..hideCurrentSnackBar()
          ..showSnackBar(
            SnackBar(
              duration: const Duration(seconds: 3),
              content: Text(
                l10n.syncFailedWith(
                  state.error == null
                      ? l10n.unknownError
                      : describeError(l10n, state.error!),
                ),
              ),
            ),
          );
    }
  }

  /// Fractional progress for an in-progress sync, or `null` when unknown.
  static double? _syncProgress(LibrarySyncState state) => switch (state.phase) {
    LibrarySyncPhase.scanning =>
      state.discovered > 0 ? state.processed / state.discovered : null,
    LibrarySyncPhase.artwork =>
      state.saved > 0 ? state.coversCached / state.saved : null,
    _ => null,
  };

  /// The three section bodies live inside a standard [TabBarView].
  Widget _buildBody() {
    return TabBarView(
      controller: _tabs,
      children: [
        _buildSectionBody(LibrarySection.all),
        _buildSectionBody(LibrarySection.favorites),
        _buildSectionBody(LibrarySection.playlists),
      ],
    );
  }

  /// The body of a single library section.
  ///
  /// The 全部 page owns its inline search field so the field travels with the
  /// page instead of appearing and disappearing above the pager.
  Widget _buildSectionBody(LibrarySection section) {
    final playback = ref.watch(playbackStateProvider).value;
    final currentUri = playback?.currentTrack?.uri;
    final isPlaying = playback?.isPlaying ?? false;

    if (section == LibrarySection.playlists) {
      final playlistsView =
          (ref.watch(libraryViewsProvider).value ?? LibraryViews.defaults)
              .viewOf(LibraryViewScope.playlists);
      return PlaylistsSection(
        view: playlistsView,
        header: const LibrarySources(),
      );
    }

    if (section == LibrarySection.favorites) {
      return _buildFavouritesBody(currentUri, isPlaying);
    }

    if (!supportsLocalLibrary) {
      return const _UnsupportedLibraryNotice();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _buildSearchField(),
        Expanded(child: _buildAllBody(currentUri, isPlaying)),
      ],
    );
  }

  /// The 全部 section's track area: search results when a query is active,
  /// otherwise the full library.
  Widget _buildAllBody(String? currentUri, bool isPlaying) {
    final l10n = AppLocalizations.of(context);
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
          return _trackDisplay(
            tracks,
            currentUri,
            isPlaying,
            LibrarySection.all,
          );
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
        return _trackDisplay(tracks, currentUri, isPlaying, LibrarySection.all);
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
    final sort =
        ref.watch(librarySortProvider).value ?? TrackSort.recentlyAdded;
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
        final sorted = sortFavouriteTracks(favourites, sort);
        return _trackDisplay(
          sorted,
          currentUri,
          isPlaying,
          LibrarySection.favorites,
        );
      },
    );
  }

  Widget _trackDisplay(
    List<Track> tracks,
    String? currentUri,
    bool isPlaying,
    LibrarySection section,
  ) {
    final scope = _scopeForSection(section);
    final view =
        (ref.watch(libraryViewsProvider).value ?? LibraryViews.defaults).viewOf(
          scope,
        );
    return TrackView(
      tracks: tracks,
      view: view,
      currentUri: currentUri,
      isPlaying: isPlaying,
      onPlay: (index) => _play(tracks, index),
      showDeleteTrack: true,
    );
  }
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
              AppIcons.libraryMusicOutlined,
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
    final l10n = AppLocalizations.of(context);
    return EmptyState(
      icon: AppIcons.libraryMusicOutlined,
      title: l10n.emptyLibraryTitle,
      message: l10n.emptyLibraryHint,
      action: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          FilledButton.tonalIcon(
            onPressed: onAddFolder,
            icon: const Icon(AppIcons.createNewFolder),
            label: Text(l10n.addFolder),
          ),
          const SizedBox(height: 8),
          TextButton.icon(
            onPressed: onImport,
            icon: const Icon(AppIcons.add),
            label: Text(l10n.importLocalMusic),
          ),
        ],
      ),
    );
  }
}

/// Shown when the library search returns no tracks.
class _NoSearchResults extends StatelessWidget {
  const _NoSearchResults();

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return EmptyState(
      icon: AppIcons.searchOff,
      title: l10n.noMatchingTracks,
      message: l10n.tryAnotherKeyword,
    );
  }
}

/// Shown when favourites mode is active but there are no favourited tracks.
class _EmptyFavourites extends StatelessWidget {
  const _EmptyFavourites();

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return EmptyState(
      icon: AppIcons.favoriteBorder,
      title: l10n.noFavorites,
      message: l10n.noFavoritesHint,
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
    final l10n = AppLocalizations.of(context);
    final scheme = Theme.of(context).colorScheme;
    final retry = onRetry;
    return EmptyState(
      icon: AppIcons.error,
      iconSize: 48,
      iconColor: scheme.error,
      title: title ?? l10n.loadLibraryFailed,
      message: describeError(l10n, error),
      action: retry == null
          ? null
          : OutlinedButton.icon(
              onPressed: retry,
              icon: const Icon(AppIcons.refresh),
              label: Text(l10n.retry),
            ),
    );
  }
}
