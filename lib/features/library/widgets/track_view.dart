// Flind Player - cross-platform music player
// Copyright (C) 2026 top.qwind.app
//
// This program is free software: you can redistribute it and/or modify
// it under the terms of the GNU General Public License as published by
// the Free Software Foundation, version 3 of the License.

import 'package:flutter/material.dart';
import 'package:flutter_staggered_grid_view/flutter_staggered_grid_view.dart';

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
    return switch (view) {
      LibraryView.list => _list(),
      LibraryView.showcase => _grid(),
      LibraryView.waterfall => _waterfall(),
    };
  }

  Widget _list() {
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
          playlistId: playlistId,
          showDeleteTrack: showDeleteTrack,
          onTap: () => onPlay(index),
        );
      },
    );
  }

  Widget _grid() {
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
          playlistId: playlistId,
          showDeleteTrack: showDeleteTrack,
          onTap: () => onPlay(index),
        );
      },
    );
  }

  Widget _waterfall() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = (constraints.maxWidth / 180).round().clamp(2, 6);
        return MasonryGridView.count(
          padding: const EdgeInsets.all(12),
          crossAxisCount: columns,
          mainAxisSpacing: 10,
          crossAxisSpacing: 10,
          itemCount: tracks.length,
          itemBuilder: (context, index) {
            final track = tracks[index];
            final isCurrent = currentUri != null && track.uri == currentUri;
            return WaterfallTrackCard(
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
      },
    );
  }
}
