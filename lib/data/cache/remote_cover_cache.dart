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
import 'dart:typed_data';

import 'package:crypto/crypto.dart';

import 'package:flind_player/data/sources/bilibili/bili_models.dart'
    show normalizeCoverUrl;

/// Looks up a cached cover file path by its `sha1(normalized url)` key.
typedef CoverPathLookup = Future<String?> Function(String urlHash);

/// Downloads a remote cover's raw bytes, or `null` on any failure.
typedef CoverBytesDownload = Future<Uint8List?> Function(String url);

/// Stores cover bytes under their URL/content hashes and returns the file path.
typedef CoverBytesStore =
    Future<String> Function({
      required String urlHash,
      required String contentHash,
      required Uint8List bytes,
    });

/// Resolves a remote cover URL to a locally cached file path.
///
/// Cache-first: a hit is served without a network round-trip; a miss downloads
/// the bytes, validates them as an image and stores them. Concurrent resolves
/// for the same URL share one download. Every failure yields `null` — a cover
/// is decorative and must never surface an error.
///
/// This is the shared path behind the UI's network fallback and the playback
/// prefetch: both use the same layer-2 [CoverPathLookup]/[CoverBytesStore] so a
/// cover downloaded once is shown everywhere.
class RemoteCoverCache {
  /// Creates a resolver from its cache/download/store primitives.
  RemoteCoverCache({
    required CoverPathLookup lookupPath,
    required CoverBytesDownload download,
    required CoverBytesStore store,
    required bool Function(Uint8List bytes) isImage,
  }) : _lookupPath = lookupPath, // ignore: prefer_initializing_formals
       _download = download, // ignore: prefer_initializing_formals
       _store = store, // ignore: prefer_initializing_formals
       _isImage = isImage; // ignore: prefer_initializing_formals

  final CoverPathLookup _lookupPath;
  final CoverBytesDownload _download;
  final CoverBytesStore _store;
  final bool Function(Uint8List bytes) _isImage;

  /// In-flight downloads keyed by URL hash, so concurrent callers share one.
  final Map<String, Future<String?>> _inFlight = <String, Future<String?>>{};

  /// Resolves [url] to a cached file path, downloading on a miss.
  Future<String?> resolve(String url) {
    final normalized = normalizeCoverUrl(url);
    if (normalized == null) return Future<String?>.value();

    final urlHash = _sha1Text(normalized);
    final pending = _inFlight[urlHash];
    if (pending != null) return pending;

    final future = _resolve(normalized, urlHash);
    _inFlight[urlHash] = future;
    return future.whenComplete(() {
      if (identical(_inFlight[urlHash], future)) _inFlight.remove(urlHash);
    });
  }

  Future<String?> _resolve(String normalized, String urlHash) async {
    final hit = await _lookupPath(urlHash);
    if (hit != null) return hit;

    final bytes = await _download(normalized);
    if (bytes == null || bytes.isEmpty) return null;
    if (!_isImage(bytes)) return null;

    return _store(
      urlHash: urlHash,
      contentHash: sha1.convert(bytes).toString(),
      bytes: bytes,
    );
  }

  static String _sha1Text(String value) =>
      sha1.convert(utf8.encode(value)).toString();
}
