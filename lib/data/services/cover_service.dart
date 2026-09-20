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

import 'dart:convert';
import 'dart:io';
import 'dart:isolate';

import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:image/image.dart' as img;

import 'package:flind_player/core/models/track.dart';
import 'package:flind_player/core/repositories/favorites_repository.dart';
import 'package:flind_player/core/repositories/music_library_repository.dart';
import 'package:flind_player/core/sources/source_track_id.dart';
import 'package:flind_player/data/cache/cover_cache_store.dart';
import 'package:flind_player/data/cache/cover_downloader.dart';
import 'package:flind_player/data/sources/bilibili/bili_models.dart';

/// Returns whether [bytes] decode as an image.
///
/// Top-level so it can run inside a short-lived isolate (see
/// [_downloadAndStore]); a non-image payload (e.g. an HTML error page served
/// with HTTP 200) must not be cached.
bool isDecodableImage(Uint8List bytes) {
  try {
    return img.decodeImage(bytes) != null;
  } catch (_) {
    return false;
  }
}

/// Resolves a Bilibili video's remote cover URL from its `bvid`.
///
/// Injected so the service stays free of the API layer and is trivial to fake
/// in tests. Returns the raw `pic` value, or `null` when the video exposes none.
typedef CoverUrlResolver = Future<String?> Function(String bvid);

/// Resolves, downloads and caches a track's remote cover.
///
/// The pipeline mirrors `ArtworkCache` for storage (content-addressed, original
/// bytes) and `AudioCacheStore` for accounting (LRU, shared quota):
///
/// 1. a track that already points at an existing local file is returned as-is;
/// 2. otherwise the cover URL is taken from the track (Bilibili search/view
///    payloads already carry it) and, when absent, resolved through
///    [resolveRemoteUrl] for a Bilibili track;
/// 3. a cache hit on the URL is served without a network round-trip;
/// 4. a miss downloads the bytes, decode-validates them off the UI isolate and
///    stores them verbatim via [CoverCacheStore];
/// 5. the resulting local path and URL are written back to the library row and
///    the favourite snapshot, when either exists.
///
/// Every failure is non-fatal: [ensureCover] returns `null` instead of throwing,
/// so a missing cover can never break playback or a library scan.
class CoverService {
  /// Creates a service.
  CoverService({
    required CoverCacheStore store,
    required CoverDownloader downloader,
    required MusicLibraryRepository library,
    required FavoritesRepository favorites,
    required CoverUrlResolver resolveRemoteUrl,
  }) : _store = store, // ignore: prefer_initializing_formals
       _downloader = downloader, // ignore: prefer_initializing_formals
       _library = library, // ignore: prefer_initializing_formals
       _favorites = favorites, // ignore: prefer_initializing_formals
       // ignore: prefer_initializing_formals
       _resolveRemoteUrl = resolveRemoteUrl;

  final CoverCacheStore _store;
  final CoverDownloader _downloader;
  final MusicLibraryRepository _library;
  final FavoritesRepository _favorites;
  final CoverUrlResolver _resolveRemoteUrl;

  /// In-flight resolutions keyed by track URI, so concurrent callers (queue
  /// prefetch, lazy row rendering) share one download instead of racing.
  final Map<String, Future<String?>> _inFlight = <String, Future<String?>>{};

  /// In-flight downloads keyed by URL hash. Several parts of one video share a
  /// single `pic` URL, so this collapses them onto one download even though
  /// their track URIs differ.
  final Map<String, Future<String?>> _inFlightByUrl =
      <String, Future<String?>>{};

  /// Ensures [track] has a locally cached cover and returns its path.
  ///
  /// Returns `null` when the track has no resolvable cover, the download fails,
  /// the bytes are not a decodable image, or the cache is full. Pass
  /// [force] = true to ignore both the existing pointer and the URL cache, e.g.
  /// for a user-triggered "refresh cover".
  Future<String?> ensureCover(Track track, {bool force = false}) {
    if (!force) {
      final pending = _inFlight[track.uri];
      if (pending != null) return pending;
    }

    final future = _resolveAndCache(track, force: force);
    _inFlight[track.uri] = future;
    return future.whenComplete(() {
      if (identical(_inFlight[track.uri], future)) {
        _inFlight.remove(track.uri);
      }
    });
  }

  Future<String?> _resolveAndCache(Track track, {required bool force}) async {
    try {
      final existing = track.coverPath;
      if (!force &&
          existing != null &&
          existing.isNotEmpty &&
          File(existing).existsSync()) {
        return existing;
      }

      final url = _normalize(track.coverUrl) ?? await _resolveUrl(track);
      if (url == null) return null;

      final urlHash = _sha1Text(url);
      if (!force) {
        // `lookup` (not `lookupPath`) so a cache hit refreshes the LRU order;
        // a cover that is shown repeatedly must not be evicted first.
        final hit = await _store.lookup(urlHash);
        if (hit != null && File(hit.filePath).existsSync()) {
          await _persist(track, hit.filePath, url);
          return hit.filePath;
        }
      }

      final path = await _storeDownload(url, urlHash, force: force);
      if (path == null) return null;
      await _persist(track, path, url);
      return path;
    } catch (error) {
      debugPrint('CoverService: failed for ${track.uri}: $error');
      return null;
    }
  }

  /// Downloads and stores [url], deduping concurrent requests for the
  /// same URL (several video parts share one cover).
  Future<String?> _storeDownload(
    String url,
    String urlHash, {
    required bool force,
  }) {
    if (!force) {
      final pending = _inFlightByUrl[urlHash];
      if (pending != null) return pending;
    }

    final future = _downloadAndStore(url, urlHash);
    _inFlightByUrl[urlHash] = future;
    return future.whenComplete(() {
      if (identical(_inFlightByUrl[urlHash], future)) {
        _inFlightByUrl.remove(urlHash);
      }
    });
  }

  Future<String?> _downloadAndStore(String url, String urlHash) async {
    final bytes = await _downloader.download(url);
    if (bytes == null) return null;

    // Decode-validate off the UI isolate so a non-image payload (e.g. an HTML
    // error page returned with HTTP 200) is rejected exactly as before. A cover
    // may be several megabytes, so this must not run on the UI isolate.
    final decodable = await Isolate.run(() => isDecodableImage(bytes));
    if (!decodable) return null;

    // The original length is already known, so `ensureSpace` only needs to make
    // room for exactly what is about to be written.
    final eviction = await _store.ensureSpace(bytes.length);
    if (!eviction.hasSpace) return null;

    return _store.insert(
      urlHash: urlHash,
      contentHash: _sha1Bytes(bytes),
      bytes: bytes,
    );
  }

  /// Resolves a Bilibili track's cover URL through [CoverUrlResolver].
  Future<String?> _resolveUrl(Track track) async {
    final id = track.sourceTrackId;
    if (id is! BiliTrackId || id.bvid.isEmpty) return null;
    try {
      return _normalize(await _resolveRemoteUrl(id.bvid));
    } catch (error) {
      debugPrint(
        'CoverService: cover URL lookup failed for ${id.bvid}: $error',
      );
      return null;
    }
  }

  /// Writes the resolved cover back to the persisted rows that reference
  /// [track], when any. Both writes are best-effort and never throw.
  Future<void> _persist(Track track, String coverPath, String coverUrl) async {
    try {
      await _library.updateTrackCover(
        track.uri,
        coverPath: coverPath,
        coverUrl: coverUrl,
      );
    } catch (error) {
      debugPrint('CoverService: library cover write failed: $error');
    }
    try {
      await _favorites.updateFavoriteCover(
        track.uri,
        coverPath: coverPath,
        coverUrl: coverUrl,
      );
    } catch (error) {
      debugPrint('CoverService: favourite cover write failed: $error');
    }
  }

  static String? _normalize(String? raw) => normalizeCoverUrl(raw);

  static String _sha1Text(String value) =>
      sha1.convert(utf8.encode(value)).toString();

  static String _sha1Bytes(List<int> bytes) => sha1.convert(bytes).toString();
}
