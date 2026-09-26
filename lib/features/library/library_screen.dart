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
import 'package:flind_player/features/library/track_sorting.dart';
import 'package:flind_player/features/library/widgets/playlist_editor_dialog.dart';
import 'package:flind_player/features/library/widgets/playlists_section.dart';
import 'package:flind_player/features/library/widgets/track_list_items.dart';
import 'package:flind_player/features/playlists/bilibili_favorites_screen.dart';
import 'package:flind_player/l10n/app_localizations.dart';
import 'package:flind_player/platform/permissions/permission_providers.dart';
import 'package:flind_player/platform/permissions/permission_service.dart';
import 'package:flind_player/app/theme/app_theme.dart';
import 'package:flind_player/shared/app_surface.dart';
import 'package:flind_player/shared/error_messages.dart';
import 'package:flind_player/shared/error_snack_bar.dart';
import 'package:flind_player/shared/platform_support.dart';
import 'package:flind_player/shared/responsive_center.dart';

/// Actions exposed by the library overflow menu.
///
/// The `sortBy*` variants carry the [TrackSort] they apply, so the sort choices
/// live in the same menu as the library actions.
enum _LibraryAction {
  addFolder,
  rescan,
  importFiles,
  bilibiliFavorites,
  sortByTitle(TrackSort.title),
  sortByArtist(TrackSort.artist),
  sortByAlbum(TrackSort.album),
  sortByRecentlyAdded(TrackSort.recentlyAdded);

  const _LibraryAction([this.sort]);

  /// The sort order applied by a `sortBy*` variant; `null` for other actions.
  final TrackSort? sort;
}

/// Library sections: all tracks, favourites, and user playlists.
///
/// Order matters: the cyclic section pager maps a virtual page index with
/// `(_initialPageIndex - pageIndex) % values.length`, anchoring the deep initial
/// page to enum index 0. Keep [all] first, or the pager's initial page will no
/// longer land on 全部.
enum LibrarySection { all, favorites, playlists }

/// The music library: a searchable, mixed local + online track browser with
/// folder scanning, import, tap-to-play and a favourites filter.
class LibraryScreen extends ConsumerStatefulWidget {
  const LibraryScreen({super.key});

  @override
  ConsumerState<LibraryScreen> createState() => _LibraryScreenState();
}

class _LibraryScreenState extends ConsumerState<LibraryScreen> {
  final TextEditingController _searchController = TextEditingController();

  /// Controller for the cyclic section [PageView] in [_buildBody].
  final PageController _pageController = PageController(
    initialPage: _initialPageIndex,
  );

  /// Deep starting index for the section pager, so both swipe directions can
  /// keep cycling through `index % 3` essentially forever without ever
  /// reaching a scroll-extent edge (a bounded `itemCount: 3` pager cannot
  /// wrap without a visible jump).
  static const int _initialPageIndex = 1 << 20;

  Timer? _debounce;
  String _query = '';
  LibrarySection _section = LibrarySection.all;

  /// The pager's current virtual page; kept in sync with [_section] so a
  /// selector tap can compute the adjacent page to glide to.
  int _pageIndex = _initialPageIndex;

  /// Whether the inline search field is expanded under the header row.
  bool _searchOpen = false;

  /// Text of the sync bubble currently shown, so identical progress updates do
  /// not re-trigger the notification.
  String? _syncBubbleText;

  /// Local FTS is fast, but debouncing keeps the family provider from churning
  /// on every keystroke.
  static const Duration _debounceDelay = Duration(milliseconds: 250);

  @override
  void dispose() {
    _debounce?.cancel();
    _searchController.dispose();
    _pageController.dispose();
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

  /// Expands/collapses the inline search field; collapsing clears the query.
  void _toggleSearch() {
    if (_searchOpen) {
      _debounce?.cancel();
      _searchController.clear();
      _query = '';
    }
    setState(() => _searchOpen = !_searchOpen);
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
      case _LibraryAction.sortByTitle ||
          _LibraryAction.sortByArtist ||
          _LibraryAction.sortByAlbum ||
          _LibraryAction.sortByRecentlyAdded:
        final sort = action.sort;
        if (sort != null) {
          await ref.read(librarySortProvider.notifier).setSort(sort);
        }
    }
  }

  /// Opens the create-playlist dialog from the header "+" button.
  void _createPlaylist() {
    unawaited(showPlaylistEditorDialog(context));
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

  /// The section shown by the page at virtual [pageIndex].
  ///
  /// The mapping is anchored at [_initialPageIndex] (全部) and negated so a
  /// *rightward* swipe — which lowers the page index — advances
  /// 全部 → 收藏 → 歌单 → 全部, while a leftward swipe retreats, matching the
  /// selector ring. Because it is pure modulo arithmetic over an unbounded
  /// index range, the wrap-around is seamless in both directions.
  static LibrarySection _sectionAt(int pageIndex) {
    final values = LibrarySection.values;
    return values[(_initialPageIndex - pageIndex) % values.length];
  }

  /// Switches sections from the selector (tap or drag) and glides the body
  /// [PageView] to the adjacent page, keeping selector and pager in sync.
  void _selectSection(LibrarySection target) {
    if (target == _section) return;
    final values = LibrarySection.values;
    final from = values.indexOf(_section);
    final to = values.indexOf(target);
    setState(() => _section = target);

    // Steps along the ring: 1 = advance (a rightward-swipe equivalent, which
    // lowers the page index), 2 = retreat one step backwards.
    final steps = (to - from) % values.length;
    final targetPage = switch (steps) {
      1 => _pageIndex - 1,
      2 => _pageIndex + 1,
      _ => _pageIndex,
    };
    _pageIndex = targetPage;
    if (_pageController.hasClients) {
      unawaited(
        _pageController.animateToPage(
          targetPage,
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOutCubic,
        ),
      );
    }
  }

  /// PageView callback: mirrors the visible page into [_section] so the
  /// selector ring follows a finger-driven swipe.
  void _onPageChanged(int pageIndex) {
    _pageIndex = pageIndex;
    final section = _sectionAt(pageIndex);
    if (section == _section) return;
    setState(() => _section = section);
  }

  @override
  Widget build(BuildContext context) {
    final hasLocalLibrary = supportsLocalLibrary;

    ref.listen(librarySyncStateProvider, (previous, next) {
      _onSyncStateChanged(next);
    });

    return Scaffold(
      backgroundColor: AppSurface.colorOf(context),
      body: SafeArea(
        bottom: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _buildHeaderRow(hasLocalLibrary: hasLocalLibrary),
            if (hasLocalLibrary) _buildSearchField(),
            Expanded(
              child: hasLocalLibrary
                  ? _buildBody()
                  : const _UnsupportedLibraryNotice(),
            ),
          ],
        ),
      ),
    );
  }

  /// The single top row: the overflow menu on the far left, the section
  /// selector centred *on screen*, and search + new-playlist on the right
  /// (＋ rightmost, visible in every section).
  ///
  /// A [Stack] (rather than a [Row]) is used so the selector's centring is
  /// independent of the unequal edge-button widths; a width reservation keeps
  /// the ring from ever colliding with the buttons at 400 px.
  Widget _buildHeaderRow({required bool hasLocalLibrary}) {
    final l10n = AppLocalizations.of(context);
    final currentSort = ref.watch(librarySortProvider).value ?? TrackSort.title;
    final syncState =
        ref.watch(librarySyncStateProvider).value ?? LibrarySyncState.idle;
    final isSyncing = switch (syncState.phase) {
      LibrarySyncPhase.scanning ||
      LibrarySyncPhase.saving ||
      LibrarySyncPhase.artwork => true,
      _ => false,
    };

    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 8, 8, 4),
      child: SizedBox(
        height: 48,
        child: LayoutBuilder(
          builder: (context, constraints) {
            // Reserve the outer gutters (more-menu on the left, search + ＋
            // on the right) so the centred ring is capped to the space that
            // actually remains, even on the narrowest supported viewport.
            final reserved = 48.0 + (hasLocalLibrary ? 96.0 : 48.0) + 8.0;
            final maxSelectorWidth = (constraints.maxWidth - reserved).clamp(
              0.0,
              double.infinity,
            );
            return Stack(
              children: [
                Align(
                  alignment: Alignment.centerLeft,
                  child: PopupMenuButton<_LibraryAction>(
                    key: const Key('library_more_menu'),
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
                        const PopupMenuDivider(),
                        for (final sort in TrackSort.values)
                          PopupMenuItem<_LibraryAction>(
                            value: _sortAction(sort),
                            child: _SortRow(
                              label: _sortLabel(l10n, sort),
                              selected: sort == currentSort,
                            ),
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
                ),
                Center(
                  child: ConstrainedBox(
                    constraints: BoxConstraints(
                      maxWidth: maxSelectorWidth.toDouble(),
                    ),
                    // Scales the ring down uniformly if a longer (e.g. English)
                    // label set ever exceeds the reserved middle gap: the three
                    // labels stay legible and never collide or overflow.
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      child: _LibraryFilterSelector(
                        section: _section,
                        onSectionChanged: _selectSection,
                      ),
                    ),
                  ),
                ),
                Align(
                  alignment: Alignment.centerRight,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (hasLocalLibrary)
                        IconButton(
                          key: const Key('library_search_button'),
                          icon: Icon(_searchOpen ? Icons.close : Icons.search),
                          onPressed: _toggleSearch,
                        ),
                      IconButton(
                        key: const Key('library_add_playlist'),
                        tooltip: '',
                        icon: const Icon(Icons.add),
                        onPressed: _createPlaylist,
                      ),
                    ],
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  /// The inline search field, expanded under the header row.
  Widget _buildSearchField() {
    final l10n = AppLocalizations.of(context);
    return AnimatedSize(
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOutCubic,
      alignment: Alignment.topCenter,
      child: _searchOpen
          ? Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
              child: ValueListenableBuilder<TextEditingValue>(
                valueListenable: _searchController,
                builder: (context, value, child) {
                  return TextField(
                    controller: _searchController,
                    textInputAction: TextInputAction.search,
                    onChanged: _onSearchChanged,
                    decoration: InputDecoration(
                      hintText: switch (_section) {
                        LibrarySection.all => l10n.searchLibrary,
                        LibrarySection.favorites => l10n.searchFavorites,
                        LibrarySection.playlists => l10n.searchPlaylists,
                      },
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
            )
          : const SizedBox(width: double.infinity),
    );
  }

  /// Maps a [TrackSort] to the overflow-menu action that applies it.
  static _LibraryAction _sortAction(TrackSort sort) => switch (sort) {
    TrackSort.title => _LibraryAction.sortByTitle,
    TrackSort.artist => _LibraryAction.sortByArtist,
    TrackSort.album => _LibraryAction.sortByAlbum,
    TrackSort.recentlyAdded => _LibraryAction.sortByRecentlyAdded,
  };

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

  /// The three section bodies live inside a cyclic [PageView].
  ///
  /// The pager runs over a deep virtual index range mapped with
  /// [_sectionAt] (`index % 3`), so swipes wrap seamlessly in both
  /// directions — a plain `itemCount: 3` pager would dead-end at the first
  /// and last page. The axis stays horizontal, so vertical drags belong to
  /// the track list/grid inside each page. [onPageChanged] mirrors the
  /// visible page back into the header selector.
  Widget _buildBody() {
    return PageView.builder(
      controller: _pageController,
      onPageChanged: _onPageChanged,
      itemBuilder: (context, pageIndex) =>
          _buildSectionBody(_sectionAt(pageIndex)),
    );
  }

  /// The body of a single library section.
  ///
  /// [section] is derived from the pager index (not read from [_section])
  /// so neighbour pages built mid-swipe render the right content. Providers,
  /// sorting, search filtering and the empty/error/loading states are
  /// unchanged from the previous per-section branches.
  Widget _buildSectionBody(LibrarySection section) {
    final l10n = AppLocalizations.of(context);
    final playback = ref.watch(playbackStateProvider).value;
    final currentUri = playback?.currentTrack?.uri;
    final isPlaying = playback?.isPlaying ?? false;

    if (section == LibrarySection.playlists) {
      return PlaylistsSection(
        query: _query,
        onOpenFavorites: () => _selectSection(LibrarySection.favorites),
      );
    }

    if (section == LibrarySection.favorites) {
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
        final sorted = sortFavouriteTracks(favourites, sort);
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
        return TrackTile(
          track: track,
          isCurrent: isCurrent,
          isPlaying: isCurrent && isPlaying,
          unavailable: track.id == null,
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
        return TrackCard(
          track: track,
          isCurrent: isCurrent,
          isPlaying: isCurrent && isPlaying,
          unavailable: track.id == null,
          onTap: () => _play(tracks, index),
        );
      },
    );
  }
}

/// The 全部/收藏/歌单 section selector, rendered as a centred ring.
///
/// The labels are ordered `[previous] [selected] [next]` with the enum
/// indices wrapped modulo 3 (e.g. 全部 → left 歌单, middle 全部, right 收藏).
/// The selected middle label is emphasised with the headline text style; the
/// flanking candidates use the muted body style. Tapping a candidate selects
/// it, and a horizontal swipe on the selector cycles through the sections
/// like a wheel (advancing or retreating, wrapping around) — synced with the
/// body pager through `onSectionChanged`.
class _LibraryFilterSelector extends StatelessWidget {
  const _LibraryFilterSelector({
    required this.section,
    required this.onSectionChanged,
  });

  final LibrarySection section;
  final ValueChanged<LibrarySection> onSectionChanged;

  static const Duration _animation = Duration(milliseconds: 250);

  /// The ring laid out as `[next, selected, previous]`, wrapping modulo the
  /// enum length so it stays continuous in both directions.
  ///
  /// _next_ is deliberately drawn on the **left**: the body pager advances on a
  /// rightward swipe, which slides the page physically sitting on the left into
  /// the middle. Mirroring the ring to match the pager keeps "the label on that
  /// side" and "the page arriving from that side" the same, so the gesture
  /// reads as one continuous wheel instead of flipping direction mid-way.
  List<LibrarySection> get _ring {
    final values = LibrarySection.values;
    final index = values.indexOf(section);
    final count = values.length;
    return <LibrarySection>[
      values[(index + 1) % count],
      section,
      values[(index - 1 + count) % count],
    ];
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);
    final selectedStyle = theme.textTheme.headlineSmall?.copyWith(
      fontWeight: FontWeight.w700,
    );
    final unselectedStyle = theme.textTheme.bodyMedium?.copyWith(
      color: theme.colorScheme.onSurfaceVariant,
    );
    final labels = _ring;

    return GestureDetector(
      key: const Key('library_filter_selector'),
      behavior: HitTestBehavior.opaque,
      onHorizontalDragEnd: (details) {
        final velocity = details.primaryVelocity ?? 0;
        // A rightward drag pulls the left-hand (_next_) candidate into the
        // middle — the same direction the body pager advances on.
        if (velocity > 200) {
          onSectionChanged(_advance());
        } else if (velocity < -200) {
          onSectionChanged(_retreat());
        }
      },
      // The whole row cross-fades between the two ring orderings. The text
      // styles are fixed per state, so only opacity/offset animate — never the
      // font size, which would force a font re-resolution every frame.
      child: AnimatedSwitcher(
        duration: _animation,
        switchInCurve: Curves.easeOutCubic,
        switchOutCurve: Curves.easeInCubic,
        transitionBuilder: (child, animation) => FadeTransition(
          opacity: animation,
          child: SlideTransition(
            position: Tween<Offset>(
              begin: const Offset(0.08, 0),
              end: Offset.zero,
            ).animate(animation),
            child: child,
          ),
        ),
        child: Row(
          key: ValueKey(section),
          mainAxisSize: MainAxisSize.min,
          children: [
            for (var i = 0; i < labels.length; i++) ...[
              if (i > 0) const SizedBox(width: 12),
              DefaultTextStyle(
                // i == 1 is the selected label in the middle of the ring.
                style:
                    (i == 1 ? selectedStyle : unselectedStyle) ??
                    const TextStyle(),
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: i == 1 ? null : () => onSectionChanged(labels[i]),
                  child: Text(_label(l10n, labels[i]), maxLines: 1),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  /// The next section, wrapping around.
  LibrarySection _advance() {
    final values = LibrarySection.values;
    return values[(values.indexOf(section) + 1) % values.length];
  }

  /// The previous section, wrapping around.
  LibrarySection _retreat() {
    final values = LibrarySection.values;
    return values[(values.indexOf(section) - 1 + values.length) % values.length];
  }

  static String _label(AppLocalizations l10n, LibrarySection section) =>
      switch (section) {
        LibrarySection.all => l10n.tabAll,
        LibrarySection.favorites => l10n.tabFavorites,
        LibrarySection.playlists => l10n.tabPlaylists,
      };
}

/// A sort option row inside the overflow menu, check-marked when active.
class _SortRow extends StatelessWidget {
  const _SortRow({required this.label, required this.selected});

  final String label;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Row(
      children: [
        if (selected)
          Icon(Icons.check, size: 20, color: scheme.primary)
        else
          const SizedBox(width: 20),
        const SizedBox(width: 8),
        Text(label),
      ],
    );
  }
}

/// The display label for a [TrackSort] option.
String _sortLabel(AppLocalizations l10n, TrackSort sort) => switch (sort) {
  TrackSort.title => l10n.sortByTitle,
  TrackSort.artist => l10n.sortByArtist,
  TrackSort.album => l10n.sortByAlbum,
  TrackSort.recentlyAdded => l10n.sortRecentlyAdded,
};

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
