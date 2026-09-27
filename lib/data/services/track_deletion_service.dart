// Flind Player - cross-platform music player
// Copyright (C) 2026 top.qwind.app
//
// This program is free software: you can redistribute it and/or modify
// it under the terms of the GNU General Public License as published by
// the Free Software Foundation, version 3 of the License.

import 'package:flind_player/core/models/track.dart';
import 'package:flind_player/core/repositories/music_library_repository.dart';
import 'package:flind_player/core/repositories/playlist_repository.dart';
import 'package:flind_player/data/cache/audio_cache_store.dart';
import 'package:flind_player/data/cache/cache_keys.dart';

/// Permanently removes a track from the app: every playlist membership, the
/// library row and the offline cache. Local files on disk are never touched.
class TrackDeletionService {
  TrackDeletionService({
    required AudioCacheStore cache,
    required PlaylistRepository playlists,
    required MusicLibraryRepository library,
  }) : _cache = cache, // ignore: prefer_initializing_formals
       _playlists = playlists, // ignore: prefer_initializing_formals
       _library = library; // ignore: prefer_initializing_formals

  final AudioCacheStore _cache;
  final PlaylistRepository _playlists;
  final MusicLibraryRepository _library;

  /// Deletes [track] from playlists, library and cache. Idempotent: a missing
  /// cache entry or library row is skipped.
  Future<void> deleteEverywhere(Track track) async {
    final entry = await _cache.lookup(track.source, cacheSourceTrackId(track));
    if (entry != null) {
      await _cache.remove(entry.id);
    }
    await _playlists.removeTrackFromAllPlaylists(track.uri);
    final id = track.id;
    if (id != null) {
      await _library.deleteTrack(id);
    }
  }
}
