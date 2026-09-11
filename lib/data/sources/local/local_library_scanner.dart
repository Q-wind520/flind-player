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
import 'dart:isolate';
import 'dart:math' as math;

import 'package:audio_metadata_reader/audio_metadata_reader.dart';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;

import 'package:flind_player/core/models/track.dart';
import 'package:flind_player/data/sources/local/local_metadata_reader.dart';

/// A throttled progress snapshot emitted while a scan runs.
///
/// [discovered] is the number of files matching the audio extensions found so
/// far; [processed] is how many metadata reads have finished. [currentFile] is
/// the most recently touched path, or `null` before discovery starts.
@immutable
class ScanProgress {
  const ScanProgress({
    required this.discovered,
    required this.processed,
    this.currentFile,
    this.done = false,
  });

  /// Files matching the supported audio extensions.
  final int discovered;

  /// Metadata reads that have finished (readable or not).
  final int processed;

  /// Most recently discovered or processed file, for display.
  final String? currentFile;

  /// Whether the scan has finished.
  final bool done;

  @override
  String toString() =>
      'ScanProgress(discovered: $discovered, processed: $processed, '
      'done: $done, currentFile: $currentFile)';
}

/// Outcome of a full scan.
@immutable
class ScanResult {
  const ScanResult({
    required this.tracks,
    required this.unreadable,
    required this.seenUris,
  });

  /// Tracks whose metadata was read successfully.
  ///
  /// Files already known to the library (passed as `knownUris` to `scan`) are
  /// skipped, so they are not re-parsed and do not appear here.
  final List<Track> tracks;

  /// Files that matched an audio extension but produced no metadata (empty,
  /// truncated, permission-denied, or an unsupported container).
  final int unreadable;

  /// Every discovered `local:` uri, including files skipped because they were
  /// already known. This is the "seen" set for soft-delete bookkeeping.
  final Set<String> seenUris;

  /// Total files discovered by the scan.
  int get discovered => seenUris.length;

  /// Files whose metadata was read (successfully or not) during this scan.
  int get processed => tracks.length + unreadable;

  @override
  String toString() =>
      'ScanResult(discovered: $discovered, tracks: ${tracks.length}, '
      'unreadable: $unreadable)';
}

/// Walks local directories and extracts track metadata in parallel.
///
/// The scan is split into two phases — discovery (I/O bound) and extraction
/// (CPU/parsing bound) — so a future incremental pass can hook into the
/// discovery seam without touching the extraction pool.
///
/// Metadata extraction runs in short-lived isolates spawned with [Isolate.run].
/// [LocalMetadataReader] is pure Dart, so it is safe to construct and use off
/// the UI isolate.
class LocalLibraryScanner {
  /// Creates a scanner backed by [reader].
  ///
  /// [parallelism] caps the number of concurrent extraction isolates; it
  /// defaults to `max(1, Platform.numberOfProcessors - 1)` so one core stays
  /// available for the UI (docs/local-library.md §6).
  LocalLibraryScanner({required LocalMetadataReader reader, int? parallelism})
    : _reader = reader, // ignore: prefer_initializing_formals
      _parallelism = math.max(
        1,
        parallelism ?? (Platform.numberOfProcessors - 1),
      );

  final LocalMetadataReader _reader;
  final int _parallelism;

  /// Minimum wall-clock gap between progress events (~10 Hz, docs §6).
  static const Duration _progressInterval = Duration(milliseconds: 100);

  /// Number of chunks kept in flight relative to [parallelism].
  ///
  /// Splitting into a few chunks per worker keeps progress meaningful without
  /// paying for one isolate per file on large libraries.
  static const int _chunksPerWorker = 4;

  /// Discovers audio files under every existing path in [roots] and reads their
  /// metadata.
  ///
  /// Missing roots and unreadable files are skipped or counted, never thrown:
  /// one bad subtree must not abort the scan (docs/local-library.md §2.4).
  /// Progress is reported through [onProgress] at most every 100 ms, plus a
  /// final `done` event.
  ///
  /// Files whose `local:` uri is in [knownUris] are not re-parsed, so a rescan
  /// only reads newly added files. They are still returned in
  /// [ScanResult.seenUris] so the caller can keep them out of the soft-delete
  /// sweep. Content-change detection via `(mtime, size)` is a follow-up — the
  /// schema has no such columns yet.
  Future<ScanResult> scan({
    required List<String> roots,
    void Function(ScanProgress progress)? onProgress,
    Set<String> knownUris = const <String>{},
  }) async {
    var lastEmit = DateTime.fromMillisecondsSinceEpoch(0);

    void report({
      required int discovered,
      required int processed,
      String? currentFile,
      bool done = false,
      bool force = false,
    }) {
      if (onProgress == null) return;
      final now = DateTime.now();
      if (!force && now.difference(lastEmit) < _progressInterval) return;
      lastEmit = now;
      onProgress(
        ScanProgress(
          discovered: discovered,
          processed: processed,
          currentFile: currentFile,
          done: done,
        ),
      );
    }

    final toParse = <String>[];
    final seenUris = <String>{};

    // TODO(android-m2): Android does not use directory walking. It queries
    // MediaStore (docs/local-library.md §2.1) through a thin MediaStoreAdapter
    // and feeds the same candidate list into the extraction pool. Discovery is
    // deliberately isolated here so that platform seam can be added without
    // touching extraction.
    for (final root in roots) {
      final directory = Directory(root);
      if (!directory.existsSync()) {
        debugPrint('LocalLibraryScanner: skipping missing root: $root');
        continue;
      }

      try {
        await for (final entity in directory.list(
          recursive: true,
          followLinks: false,
        )) {
          if (entity is! File) continue;
          final path = entity.path;
          if (!_isAudioFile(path)) continue;
          final uri = 'local:$path';
          if (!seenUris.add(uri)) continue;
          if (knownUris.contains(uri)) continue;
          toParse.add(path);
          report(discovered: seenUris.length, processed: 0, currentFile: path);
        }
      } on FileSystemException catch (error) {
        // An unreadable directory/subtree must never abort the whole scan.
        debugPrint('LocalLibraryScanner: cannot list $root: $error');
      }
    }

    report(discovered: seenUris.length, processed: 0, force: true);

    final tracks = <Track>[];
    var unreadable = 0;
    var processed = 0;

    if (toParse.isNotEmpty) {
      final chunks = _chunk(toParse);
      final reader = _reader;
      var nextChunk = 0;

      Future<void> worker() async {
        while (true) {
          final index = nextChunk++;
          if (index >= chunks.length) return;
          final chunk = chunks[index];
          final results = await _extractChunk(reader, chunk);

          // No await between reading `results` and updating the counters, so
          // these mutations are atomic with respect to the other workers.
          for (final track in results) {
            if (track == null) {
              unreadable++;
            } else {
              tracks.add(track);
            }
          }
          processed += results.length;
          report(
            discovered: seenUris.length,
            processed: processed,
            currentFile: chunk.last,
            force: processed == toParse.length,
          );
        }
      }

      final workerCount = math.min(_parallelism, chunks.length);
      await Future.wait(List.generate(workerCount, (_) => worker()));
    }

    report(
      discovered: seenUris.length,
      processed: processed,
      done: true,
      force: true,
    );

    return ScanResult(
      tracks: tracks,
      unreadable: unreadable,
      seenUris: seenUris,
    );
  }

  /// Splits [files] into `parallelism * _chunksPerWorker`-ish chunks, each
  /// processed sequentially inside one isolate.
  List<List<String>> _chunk(List<String> files) {
    final targetChunks = math.min(
      files.length,
      _parallelism * _chunksPerWorker,
    );
    final chunkSize = (files.length / targetChunks).ceil();
    final chunks = <List<String>>[];
    for (var i = 0; i < files.length; i += chunkSize) {
      chunks.add(files.sublist(i, math.min(i + chunkSize, files.length)));
    }
    return chunks;
  }

  bool _isAudioFile(String path) {
    return supportedFileExtensions.contains(p.extension(path).toLowerCase());
  }
}

/// Reads [paths] in order, one [LocalMetadataReader.readTrack] per file.
///
/// Top-level so it can be sent to an isolate. Returns `null` per unreadable
/// file instead of throwing.
Future<List<Track?>> _readChunk(
  LocalMetadataReader reader,
  List<String> paths,
) async {
  final tracks = <Track?>[];
  for (final path in paths) {
    tracks.add(await reader.readTrack(path));
  }
  return tracks;
}

/// Runs [_readChunk] in a short-lived isolate.
///
/// Kept top-level so the sent closure captures only [reader] and [paths]. A
/// closure created inside `scan` would capture the surrounding context —
/// including the progress callback, and through it the repository and its
/// database handle — and `Isolate.run` would then reject that unsendable
/// object.
Future<List<Track?>> _extractChunk(
  LocalMetadataReader reader,
  List<String> paths,
) {
  return Isolate.run(() => _readChunk(reader, paths));
}
