// Flind Player - cross-platform music player
// Copyright (C) 2026 top.qwind.app
//
// This program is free software: you can redistribute it and/or modify
// it under the terms of the GNU General Public License as published by
// the Free Software Foundation, version 3 of the License.

import 'package:flutter/material.dart';
import 'package:flutter_staggered_grid_view/flutter_staggered_grid_view.dart';

import 'package:flind_player/app/theme/app_tokens.dart';
import 'package:flind_player/core/models/library_view.dart';
import 'package:flind_player/core/models/track.dart';
import 'package:flind_player/features/library/widgets/track_list_items.dart';
import 'package:flind_player/features/library/widgets/waterfall_track_card.dart';

/// Renders [tracks] in the layout chosen by [view].
class TrackView extends StatelessWidget {
  const TrackView({
    super.key,
    required this.tracks,
    required this.view,
    required this.currentUri,
    required this.isPlaying,
    required this.onPlay,
    this.playlistId,
    this.showDeleteTrack = false,
  });

  final List<Track> tracks;
  final LibraryView view;
  final String? currentUri;
  final bool isPlaying;
  final void Function(int index) onPlay;
  final int? playlistId;
  final bool showDeleteTrack;

  @override
  Widget build(BuildContext context) {
    // The shell floats the bottom chrome over the content, so scrollables must
    // reserve its height themselves; a view with an explicit `padding` does
    // not pick up the injected `MediaQuery` inset automatically.
    final bottomInset = MediaQuery.paddingOf(context).bottom;
    final compact = MediaQuery.sizeOf(context).width < 600;
    final horizontal = compact ? 16.0 : 28.0;
    return switch (view) {
      LibraryView.list => _list(bottomInset, horizontal),
      LibraryView.showcase => _grid(bottomInset, horizontal),
      LibraryView.waterfall => _waterfall(bottomInset, horizontal),
    };
  }

  Widget _list(double bottomInset, double horizontal) {
    final side = (horizontal - AppSpacing.md).clamp(0.0, 16.0);
    return ListView.separated(
      padding: EdgeInsets.fromLTRB(
        side,
        AppSpacing.xs,
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
        return TrackTile(
          track: track,
          isCurrent: isCurrent,
          isPlaying: isCurrent && isPlaying,
          unavailable: track.id == null,
          playlistId: playlistId,
          showDeleteTrack: showDeleteTrack,
          onTap: () => onPlay(index),
        );
      },
    );
  }

  Widget _grid(double bottomInset, double horizontal) {
    return GridView.builder(
      padding: EdgeInsets.fromLTRB(
        horizontal,
        AppSpacing.sm,
        horizontal,
        AppSpacing.md + bottomInset,
      ),
      gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
        maxCrossAxisExtent: 260,
        childAspectRatio: 0.82,
        crossAxisSpacing: 24,
        mainAxisSpacing: 28,
      ),
      itemCount: tracks.length,
      itemBuilder: (context, index) {
        final track = tracks[index];
        final isCurrent = currentUri != null && track.uri == currentUri;
        return TrackCard(
          track: track,
          isPlaying: isCurrent && isPlaying,
          unavailable: track.id == null,
          playlistId: playlistId,
          showDeleteTrack: showDeleteTrack,
          onTap: () => onPlay(index),
        );
      },
    );
  }

  Widget _waterfall(double bottomInset, double horizontal) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = (constraints.maxWidth / 240).round().clamp(2, 5);
        return MasonryGridView.count(
          padding: EdgeInsets.fromLTRB(
            horizontal,
            AppSpacing.sm,
            horizontal,
            AppSpacing.md + bottomInset,
          ),
          crossAxisCount: columns,
          mainAxisSpacing: 24,
          crossAxisSpacing: 20,
          itemCount: tracks.length,
          itemBuilder: (context, index) {
            final track = tracks[index];
            final isCurrent = currentUri != null && track.uri == currentUri;
            return WaterfallTrackCard(
              track: track,
              isPlaying: isCurrent && isPlaying,
              unavailable: track.id == null,
              playlistId: playlistId,
              showDeleteTrack: showDeleteTrack,
              onTap: () => onPlay(index),
            );
          },
        );
      },
    );
  }
}
