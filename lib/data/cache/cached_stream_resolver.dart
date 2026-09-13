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
import 'dart:io';

import 'package:flutter/foundation.dart';

import 'package:flind_player/core/models/track.dart';
import 'package:flind_player/core/sources/music_source.dart';
import 'package:flind_player/core/sources/stream_resolver.dart';
import 'package:flind_player/data/cache/audio_cache_store.dart';
import 'package:flind_player/data/cache/download_manager.dart';

/// Cache-first [StreamResolver] (docs/local-library.md §4.6).
///
/// On a hit the cached file is returned as a `file:` [StreamInfo] with no
/// headers and no expiry, so playback works fully offline. On a miss the
/// request is delegated to [inner] and a background download is always
/// enqueued with the freshly resolved [StreamInfo] so the next play is offline.
///
/// A cache-layer failure must never break playback: lookups are best-effort and
/// fall through to [inner].
class CachedStreamResolver implements StreamResolver {
  CachedStreamResolver({
    required StreamResolver inner,
    required AudioCacheStore store,
    required DownloadManager manager,
  }) : _inner = inner, // ignore: prefer_initializing_formals
       _store = store, // ignore: prefer_initializing_formals
       _manager = manager; // ignore: prefer_initializing_formals

  final StreamResolver _inner;
  final AudioCacheStore _store;
  final DownloadManager _manager;

  @override
  Future<StreamInfo> resolve(Track track) async {
    try {
      final cached = await _store.lookup(
        track.source,
        cacheSourceTrackId(track),
      );
      if (cached != null && File(cached.filePath).existsSync()) {
        await _store.touch(cached.id);
        return StreamInfo(url: Uri.file(cached.filePath));
      }
    } catch (error) {
      debugPrint('CachedStreamResolver: cache lookup failed: $error');
    }

    final info = await _inner.resolve(track);

    if (_isNetworkUrl(info.url)) {
      // Fire-and-forget: the download manager reports its own progress and
      // turns failures into progress events, so nothing is awaited here.
      unawaited(
        _manager.cacheTrack(track, knownInfo: info).catchError((Object _) {}),
      );
    }

    return info;
  }

  bool _isNetworkUrl(Uri url) => url.scheme == 'http' || url.scheme == 'https';
}
