// Flind Player - cross-platform music player
// Copyright (C) 2026 top.qwind.app
//
// This program is free software: you can redistribute it and/or modify
// it under the terms of the GNU General Public License as published by
// the Free Software Foundation, version 3 of the License.

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:flind_player/data/providers/cache_providers.dart';
import 'package:flind_player/data/providers/database_providers.dart';
import 'package:flind_player/data/providers/playlist_providers.dart';
import 'package:flind_player/data/services/track_deletion_service.dart';

/// Permanently removes a track from playlists, library and cache.
final trackDeletionServiceProvider = Provider<TrackDeletionService>(
  (ref) => TrackDeletionService(
    cache: ref.watch(audioCacheStoreProvider),
    playlists: ref.watch(playlistRepositoryProvider),
    library: ref.watch(musicLibraryRepositoryProvider),
  ),
);
