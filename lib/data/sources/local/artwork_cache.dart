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
import 'dart:isolate';

import 'package:audio_metadata_reader/audio_metadata_reader.dart';
import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;

/// Content-addressed cache for embedded album art.
///
/// A picture's bytes are SHA-1 hashed and stored verbatim under
/// `<sha1>.<ext>` (the extension follows the picture's MIME type) in the cache
/// directory, so every track of an album shares one file and the original
/// quality is preserved (docs/local-library.md §3). The directory must be
/// inside the application support tree — never a temp directory, which the OS
/// may clear.
class ArtworkCache {
  /// Creates a cache rooted at [baseDir].
  ArtworkCache({required Directory baseDir})
    : _baseDir = baseDir, // ignore: prefer_initializing_formals
      _resolveBaseDir = null;

  /// Creates a cache whose root directory is resolved on first use.
  ///
  /// Production wiring cannot await `path_provider` from a synchronous
  /// provider, so the directory is resolved lazily here instead.
  ArtworkCache.lazy({required Future<Directory> Function() resolveBaseDir})
    : _baseDir = null,
      _resolveBaseDir = resolveBaseDir; // ignore: prefer_initializing_formals

  final Directory? _baseDir;
  final Future<Directory> Function()? _resolveBaseDir;

  /// Caches the cover embedded in the audio file at [audioPath].
  ///
  /// Returns the cached file path, or `null` when the file is missing or has no
  /// embedded picture. An already-cached hash is never rewritten, so repeated
  /// calls are cheap and dedupe across an album. Never throws.
  Future<String?> cacheFromFile(String audioPath) async {
    try {
      final basePath = (await _resolveDir()).path;
      // Reading, hashing and writing happen off the UI isolate (docs §3).
      return await _cacheInIsolate(audioPath, basePath);
    } catch (error) {
      debugPrint('ArtworkCache: failed for $audioPath: $error');
      return null;
    }
  }

  /// Removes every cached cover, keeping the cache directory itself.
  Future<void> clear() async {
    try {
      final directory = await _resolveDir();
      for (final entity in directory.listSync()) {
        entity.deleteSync(recursive: true);
      }
    } catch (error) {
      debugPrint('ArtworkCache: clear failed: $error');
    }
  }

  /// Total size of every cached cover, in bytes.
  Future<int> sizeInBytes() async {
    try {
      final directory = await _resolveDir();
      var total = 0;
      await for (final entity in directory.list(
        recursive: true,
        followLinks: false,
      )) {
        if (entity is File) {
          total += await entity.length();
        }
      }
      return total;
    } catch (error) {
      debugPrint('ArtworkCache: size failed: $error');
      return 0;
    }
  }

  Future<Directory> _resolveDir() async {
    final directory = _baseDir ?? await _resolveBaseDir!();
    if (!directory.existsSync()) {
      directory.createSync(recursive: true);
    }
    return directory;
  }
}

/// Isolate entry point: reads, hashes and stores one cover verbatim.
///
/// Top-level so it is safe to send through `Isolate.run`.
String? _cacheSync(String audioPath, String baseDirPath) {
  final file = File(audioPath);
  if (!file.existsSync()) return null;

  final metadata = readMetadata(file, getImage: true);
  if (metadata.pictures.isEmpty) return null;

  final picture = _pickCover(metadata.pictures);
  final bytes = picture.bytes;
  if (bytes.isEmpty) return null;

  final digest = sha1.convert(bytes).toString();
  final directory = Directory(baseDirPath);
  if (!directory.existsSync()) {
    directory.createSync(recursive: true);
  }

  final path = p.join(
    baseDirPath,
    '$digest.${_extensionForMime(picture.mimetype)}',
  );
  final cachedFile = File(path);
  if (cachedFile.existsSync()) return path;

  cachedFile.writeAsBytesSync(bytes, flush: true);
  return path;
}

/// Runs [_cacheSync] in a short-lived isolate.
///
/// Kept top-level so the sent closure captures only the two path strings
/// instead of the enclosing [ArtworkCache] (whose lazy directory resolver may
/// close over non-sendable provider state).
Future<String?> _cacheInIsolate(String audioPath, String basePath) {
  return Isolate.run(() => _cacheSync(audioPath, basePath));
}

/// Prefers the front cover, falling back to the first embedded picture.
Picture _pickCover(List<Picture> pictures) {
  for (final picture in pictures) {
    if (picture.pictureType == PictureType.coverFront) return picture;
  }
  return pictures.first;
}

String _extensionForMime(String mimeType) {
  final normalized = mimeType.toLowerCase();
  if (normalized.contains('png')) return 'png';
  if (normalized.contains('webp')) return 'webp';
  if (normalized.contains('gif')) return 'gif';
  if (normalized.contains('bmp')) return 'bmp';
  if (normalized.contains('tiff')) return 'tiff';
  if (normalized.contains('jpeg') || normalized.contains('jpg')) return 'jpg';
  return 'bin';
}
