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
import 'package:flind_player/data/providers/database_providers.dart';
import 'package:flind_player/data/providers/online_source_providers.dart';
import 'package:flind_player/data/providers/playback_providers.dart';
import 'package:flind_player/features/library/widgets/track_actions_button.dart';
import 'package:flind_player/features/library/widgets/track_list_items.dart';
import 'package:flind_player/l10n/app_localizations.dart';
import 'package:flind_player/platform/permissions/permission_providers.dart';
import 'package:flind_player/shared/app_surface.dart';
import 'package:flind_player/shared/app_page_header.dart';
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
    final compact = MediaQuery.sizeOf(context).width < AppBreakpoints.compact;
    final horizontal = compact ? 16.0 : 28.0;
    return PlaybackPermissionScope(
      child: Scaffold(
        backgroundColor: AppSurface.colorOf(context),
        body: SafeArea(
          bottom: false,
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 960),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  AppPageHeader(title: l10n.navSearch),
                  Padding(
                    padding: EdgeInsets.fromLTRB(
                      horizontal,
                      0,
                      horizontal,
                      AppSpacing.md,
                    ),
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
                        onSelected: (id) =>
                            setState(() => _selectedSourceId = id),
                      ),
                    ),
                  Expanded(child: _buildBody(selectedId)),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildBody(String sourceId) {
    final l10n = AppLocalizations.of(context);
    if (_submittedQuery.isEmpty) {
      return EmptyState(
        icon: AppIcons.search,
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
