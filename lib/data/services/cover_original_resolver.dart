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

import 'dart:io';
import 'dart:typed_data';

import 'package:flind_player/core/models/track.dart';

/// A full-resolution cover image resolved for the original-image viewer.
class CoverOriginal {
  const CoverOriginal({
    required this.bytes,
    required this.mimeType,
    required this.suggestedName,
  });

  /// The raw image bytes.
  final Uint8List bytes;

  /// The image MIME type (sniffed from [bytes]).
  final String mimeType;

  /// A filesystem-safe file name suggested for saving.
  final String suggestedName;
}

/// Resolves a track's full-resolution cover for the viewer.
///
/// The stored `coverUrl` is already the un-suffixed original, and the local
/// `coverPath` is the verbatim embedded artwork, so both are originals. The
/// URL is preferred; a fetch that fails (offline, 403, timeout, oversized)
/// falls back to the local file; when neither yields bytes the result is null.
class CoverOriginalResolver {
  const CoverOriginalResolver({
    required this.fetchRemote,
    required this.readLocal,
  });

  /// Fetches the bytes at a remote URL, or null on any failure.
  final Future<Uint8List?> Function(String url) fetchRemote;

  /// Reads the bytes at a local path, or null on any failure.
  final Future<Uint8List?> Function(String path) readLocal;

  Future<CoverOriginal?> resolve(Track track) async {
    final url = track.coverUrl;
    if (url != null && url.isNotEmpty) {
      final bytes = await fetchRemote(url);
      if (bytes != null && bytes.isNotEmpty) return _wrap(track, bytes);
    }

    final path = track.coverPath;
    if (path != null && path.isNotEmpty) {
      final bytes = await readLocal(path);
      if (bytes != null && bytes.isNotEmpty) return _wrap(track, bytes);
    }

    return null;
  }

  CoverOriginal _wrap(Track track, Uint8List bytes) {
    final mime = sniffImageMime(bytes);
    return CoverOriginal(
      bytes: bytes,
      mimeType: mime,
      suggestedName: suggestedCoverName(track, mime),
    );
  }
}

/// Sniffs common image MIME types from [bytes]; defaults to JPEG.
String sniffImageMime(Uint8List bytes) {
  if (bytes.length >= 4 &&
      bytes[0] == 0x89 &&
      bytes[1] == 0x50 &&
      bytes[2] == 0x4E &&
      bytes[3] == 0x47) {
    return 'image/png';
  }
  if (bytes.length >= 3 &&
      bytes[0] == 0x47 &&
      bytes[1] == 0x49 &&
      bytes[2] == 0x46) {
    return 'image/gif';
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
    return 'image/webp';
  }
  return 'image/jpeg';
}

/// A filesystem-safe suggested file name for [track]'s cover.
String suggestedCoverName(Track track, String mimeType) {
  final ext = switch (mimeType) {
    'image/png' => 'png',
    'image/gif' => 'gif',
    'image/webp' => 'webp',
    _ => 'jpg',
  };
  final artist = track.artist?.trim() ?? '';
  final base = <String>[
    artist,
    track.title,
  ].where((s) => s.isNotEmpty).join(' - ');
  final safe = base.replaceAll(RegExp(r'[\\/:*?"<>|]'), '_').trim();
  return '${safe.isEmpty ? 'cover' : safe}.$ext';
}

/// Reads a file's bytes, or null when it is missing or unreadable.
Future<Uint8List?> readFileBytes(String path) async {
  try {
    final file = File(path);
    if (!file.existsSync()) return null;
    return await file.readAsBytes();
  } catch (_) {
    return null;
  }
}
