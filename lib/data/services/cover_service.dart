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
import 'package:flind_player/core/repositories/music_library_repository.dart';
import 'package:flind_player/core/sources/source_track_id.dart';
import 'package:flind_player/data/cache/audio_cache_store.dart';
import 'package:flind_player/data/cache/cache_keys.dart';
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
/// 3. routing by cache layer comes first: while the song is in the offline
///    audio cache (layer 1), its cover is materialised beside the audio file
///    via [AudioCacheStore.coverFileFor] — reusing `track.coverPath` or a
///    layer-2 copy when present, downloading otherwise — so offline artwork
///    survives the layer-2 wipe;
/// 4. for an un-cached song, a cache hit on the URL is served without a
///    network round-trip;
/// 5. a miss downloads the bytes, decode-validates them off the UI isolate
///    and stores them in the session-scoped [CoverCacheStore] (layer 2);
/// 6. the resulting local path and URL are written back to the pool row, when
///    it exists.
///
/// Every failure is non-fatal: [ensureCover] returns `null` instead of throwing,
/// so a missing cover can never break playback or a library scan.
class CoverService {
  /// Creates a service.
  CoverService({
    required CoverCacheStore store,
    required AudioCacheStore audioStore,
    required CoverDownloader downloader,
    required MusicLibraryRepository library,
    required CoverUrlResolver resolveRemoteUrl,
  }) : _store = store, // ignore: prefer_initializing_formals
       _audioStore = audioStore, // ignore: prefer_initializing_formals
       _downloader = downloader, // ignore: prefer_initializing_formals
       _library = library, // ignore: prefer_initializing_formals
       // ignore: prefer_initializing_formals
       _resolveRemoteUrl = resolveRemoteUrl;

  final CoverCacheStore _store;
  final AudioCacheStore _audioStore;
  final CoverDownloader _downloader;
  final MusicLibraryRepository _library;
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
      // Layer routing comes first: while the song is cached, its cover must
      // always end up beside the audio file (layer 1) — even when a copy
      // already exists as `track.coverPath` or in layer 2, both of which the
      // next start can wipe.
      final cachedAudio = await _cachedAudioFor(track);
      if (cachedAudio != null) {
        return await _ensureLayer1(track, cachedAudio, force: force);
      }

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

      final path = await _storeDownload(url, urlHash, track, force: force);
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
    String urlHash,
    Track track, {
    required bool force,
  }) {
    if (!force) {
      final pending = _inFlightByUrl[urlHash];
      if (pending != null) return pending;
    }

    final future = _downloadAndStore(url, urlHash, track);
    _inFlightByUrl[urlHash] = future;
    return future.whenComplete(() {
      if (identical(_inFlightByUrl[urlHash], future)) {
        _inFlightByUrl.remove(urlHash);
      }
    });
  }

  Future<String?> _downloadAndStore(
    String url,
    String urlHash,
    Track track,
  ) async {
    final bytes = await _downloader.download(url);
    if (bytes == null) return null;

    // Decode-validate off the UI isolate so a non-image payload (e.g. an HTML
    // error page returned with HTTP 200) is rejected exactly as before. A cover
    // may be several megabytes, so this must not run on the UI isolate.
    final decodable = await Isolate.run(() => isDecodableImage(bytes));
    if (!decodable) return null;

    final cachedAudio = await _cachedAudioFor(track);
    if (cachedAudio != null) {
      // Layer 1 (race safety net): the song was cached while this download
      // was in flight, so the cover travels with it after all.
      final cover = await _writeLayer1Cover(track, cachedAudio, bytes);
      return cover.path;
    }

    // Layer 2: session-scoped cover for an un-cached song.
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

  /// Materialises [track]'s cover beside its cached audio file (layer 1) and
  /// returns that path.
  ///
  /// The bytes are reused from the row's companion cover, then from
  /// [Track.coverPath] (which may still point into layer 2 from before the
  /// song was cached), then from the layer-2 URL cache; only a miss
  /// downloads. `force` skips every reuse so a "refresh cover" re-downloads.
  /// Failures return `null` and never throw.
  Future<String?> _ensureLayer1(
    Track track,
    CachedAudio cachedAudio, {
    required bool force,
  }) async {
    var url = _normalize(track.coverUrl);
    Uint8List? bytes;
    if (!force) {
      bytes = _bytesOf(cachedAudio.coverPath) ?? _bytesOf(track.coverPath);
    }
    if (bytes == null) {
      url ??= await _resolveUrl(track);
      if (url == null) return null;
      if (!force) {
        // `lookup` (not `lookupPath`) so a hit refreshes the LRU order.
        final hit = await _store.lookup(_sha1Text(url));
        if (hit != null) bytes = _bytesOf(hit.filePath);
      }
      if (bytes == null) {
        final downloaded = await _downloader.download(url);
        if (downloaded == null) return null;
        final decodable = await Isolate.run(() => isDecodableImage(downloaded));
        if (!decodable) return null;
        bytes = downloaded;
      }
    }

    final cover = await _writeLayer1Cover(track, cachedAudio, bytes);
    // `url` is null when the bytes were reused without a known URL; the
    // library leaves the stored cover URL untouched in that case.
    await _persist(track, cover.path, url);
    return cover.path;
  }

  /// Writes [bytes] to this song's companion-cover slot in layer 1, records
  /// the path and its byte count on the row, and re-enforces the cap.
  Future<File> _writeLayer1Cover(
    Track track,
    CachedAudio cachedAudio,
    Uint8List bytes,
  ) async {
    final cover = _audioStore.coverFileFor(
      source: track.source,
      sourceTrackId: cacheSourceTrackId(track),
      extension: _extensionFor(bytes),
    );
    cover.parent.createSync(recursive: true);
    cover.writeAsBytesSync(bytes, flush: true);
    // `bytes:` so the companion cover counts toward the layer-1 quota.
    await _audioStore.setCoverPath(
      cachedAudio.id,
      cover.path,
      bytes: bytes.length,
    );
    // The companion cover adds to layer 1's footprint; re-enforce the cap.
    await _audioStore.enforceLimit();
    return cover;
  }

  /// Existing cover bytes at [path], or `null` when absent or dangling.
  static Uint8List? _bytesOf(String? path) {
    if (path == null || path.isEmpty) return null;
    final file = File(path);
    return file.existsSync() ? file.readAsBytesSync() : null;
  }

  /// The offline audio-cache row for [track], or `null` when the song is not
  /// cached (or its file vanished from disk).
  Future<CachedAudio?> _cachedAudioFor(Track track) async {
    try {
      final entry = await _audioStore.lookup(
        track.source,
        cacheSourceTrackId(track),
      );
      if (entry == null) return null;
      return File(entry.filePath).existsSync() ? entry : null;
    } catch (error) {
      debugPrint('CoverService: audio cache lookup failed: $error');
      return null;
    }
  }

  /// Picks a file extension from the image's magic bytes; defaults to `jpg`.
  static String _extensionFor(Uint8List bytes) {
    if (bytes.length >= 8 &&
        bytes[0] == 0x89 &&
        bytes[1] == 0x50 &&
        bytes[2] == 0x4E &&
        bytes[3] == 0x47) {
      return 'png';
    }
    if (bytes.length >= 12 &&
        bytes[0] == 0x52 &&
        bytes[1] == 0x49 &&
        bytes[2] == 0x46 &&
        bytes[3] == 0x46 &&
        bytes[8] == 0x57 &&
        bytes[9] == 0x45 &&
        bytes[10] == 0x42 &&
        bytes[11] == 0x50) {
      return 'webp';
    }
    return 'jpg';
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

  /// Writes the resolved cover back to the pool row that references [track],
  /// when it exists. Best-effort and never throws; a null [coverUrl] leaves
  /// the stored URL untouched.
  Future<void> _persist(Track track, String coverPath, String? coverUrl) async {
    try {
      await _library.updateTrackCover(
        track.uri,
        coverPath: coverPath,
        coverUrl: coverUrl,
      );
    } catch (error) {
      debugPrint('CoverService: library cover write failed: $error');
    }
  }

  static String? _normalize(String? raw) => normalizeCoverUrl(raw);

  static String _sha1Text(String value) =>
      sha1.convert(utf8.encode(value)).toString();

  static String _sha1Bytes(List<int> bytes) => sha1.convert(bytes).toString();
}
