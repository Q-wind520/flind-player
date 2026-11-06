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
import 'package:flind_player/core/models/library_view.dart';
import 'package:flind_player/core/models/playback_queue.dart';
import 'package:flind_player/core/models/track.dart';
import 'package:flind_player/data/providers/playback_providers.dart';
import 'package:flind_player/data/providers/stats_providers.dart';
import 'package:flind_player/features/library/widgets/track_view.dart';
import 'package:flind_player/l10n/app_localizations.dart';
import 'package:flind_player/shared/app_page_header.dart';
import 'package:flind_player/shared/app_page_scaffold.dart';
import 'package:flind_player/shared/empty_state.dart';

/// The tracks most recently played, newest first and de-duplicated.
class RecentPlaysScreen extends ConsumerWidget {
  const RecentPlaysScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final tracksAsync = ref.watch(recentPlayEventsProvider);
    final tracks = ref.watch(recentTracksProvider);
    final state = ref.watch(playbackStateProvider).value;
    final compact = MediaQuery.sizeOf(context).width < AppBreakpoints.compact;

    return AppPageScaffold(
      header: AppPageHeader(
        title: l10n.recentPlays,
        compact: compact,
        leading: IconButton(
          key: const Key('recent_back'),
          tooltip: '',
          icon: const Icon(AppIcons.arrowBack),
          onPressed: () => Navigator.of(context).maybePop(),
        ),
      ),
      body: tracksAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stackTrace) => Center(
          child: TextButton.icon(
            onPressed: () => ref.invalidate(recentPlayEventsProvider),
            icon: const Icon(AppIcons.refresh),
            label: Text(l10n.retry),
          ),
        ),
        data: (_) => tracks.isEmpty
            ? EmptyState(icon: AppIcons.history, title: l10n.recentEmpty)
            : TrackView(
                tracks: tracks,
                view: LibraryView.list,
                currentUri: state?.currentTrack?.uri,
                isPlaying: state?.isPlaying ?? false,
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
