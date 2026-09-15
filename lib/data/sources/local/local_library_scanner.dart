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
import 'package:flind_player/data/sources/local/local_stream_resolver.dart';

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

/// Freshness key for a file already in the library.
///
/// The scanner compares a discovered file's size and mtime against this value
/// to decide whether the file must be re-parsed. Fields are nullable because
/// the backing columns are: a row written before schema v5 (or by a non-scan
/// import) has no fingerprint and therefore never matches, forcing one parse.
@immutable
class FileFingerprint {
  const FileFingerprint({this.sizeBytes, this.mtimeMs, this.scanRoot});

  /// Size of the file in bytes at the last scan, if known.
  final int? sizeBytes;

  /// Last-modified time in milliseconds since epoch at the last scan, if
  /// known.
  final int? mtimeMs;

  /// Scan root the track was discovered under, if known.
  final String? scanRoot;

  @override
  String toString() =>
      'FileFingerprint(sizeBytes: $sizeBytes, mtimeMs: $mtimeMs, '
      'scanRoot: $scanRoot)';
}

/// A discovered audio file together with its stat fingerprint and owning root.
///
/// Produced for *every* discovered file, whether it was parsed or skipped as
/// unchanged, so the sync layer can attribute and track it.
@immutable
class ScannedFile {
  const ScannedFile({
    required this.path,
    required this.uri,
    required this.root,
    required this.sizeBytes,
    required this.mtimeMs,
  });

  /// Absolute on-disk path.
  final String path;

  /// Canonical `local:<path>` uri.
  final String uri;

  /// Scan root this file was discovered under.
  final String root;

  /// Size of the file in bytes.
  final int sizeBytes;

  /// Last-modified time in milliseconds since epoch.
  final int mtimeMs;

  @override
  String toString() =>
      'ScannedFile(uri: $uri, root: $root, '
      'sizeBytes: $sizeBytes, mtimeMs: $mtimeMs)';
}

/// A freshly parsed track paired with the file it came from.
///
/// The pair lets the repository persist the track metadata and its
/// `(size, mtime, root)` fingerprint in one upsert.
@immutable
class ScannedTrack {
  const ScannedTrack({required this.track, required this.file});

  /// Parsed metadata.
  final Track track;

  /// The file the metadata was read from.
  final ScannedFile file;

  @override
  String toString() => 'ScannedTrack(track: ${track.uri}, file: ${file.uri})';
}

/// Outcome of a full scan.
@immutable
class ScanResult {
  const ScanResult({
    required this.scannedTracks,
    required this.discoveredFiles,
    required this.unreadable,
    required this.seenUris,
  });

  /// Tracks whose metadata was read during this scan.
  ///
  /// Files whose `(size, mtime)` matched [FileFingerprint] in the `known` map
  /// passed to `scan` are skipped, so they do not appear here.
  final List<ScannedTrack> scannedTracks;

  /// Every discovered file, including the ones skipped as unchanged.
  final List<ScannedFile> discoveredFiles;

  /// Files that matched an audio extension but produced no metadata (empty,
  /// truncated, permission-denied, or an unsupported container).
  final int unreadable;

  /// Every discovered `local:` uri, including files skipped because they were
  /// already known. This is the "seen" set for soft-delete bookkeeping.
  final Set<String> seenUris;

  /// Parsed tracks, in discovery order. Convenience view over
  /// [scannedTracks] for callers that do not need the file fingerprint.
  List<Track> get tracks => [
    for (final scanned in scannedTracks) scanned.track,
  ];

  /// Total files discovered by the scan.
  int get discovered => seenUris.length;

  /// Files whose metadata was read (successfully or not) during this scan.
  int get processed => scannedTracks.length + unreadable;

  @override
  String toString() =>
      'ScanResult(discovered: $discovered, tracks: ${scannedTracks.length}, '
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
  /// A discovered file is re-parsed unless [known] holds a [FileFingerprint]
  /// for its `local:` uri whose `sizeBytes` and `mtimeMs` both match the
  /// current stat (the incremental `(mtime, size)` check from
  /// docs/local-library.md §2.4, §6). Every discovered file is still reported
  /// in [ScanResult.discoveredFiles] and [ScanResult.seenUris] so the caller
  /// can attribute roots and keep present files out of the soft-delete sweep.
  ///
  /// The `stat` used for the freshness key is taken in the discovery walk with
  /// `FileSystemEntity.stat()`: it is a single non-blocking syscall per
  /// candidate, and the fingerprint is needed for skipped files too, so
  /// deferring it into the extraction isolates would require a second pass.
  Future<ScanResult> scan({
    required List<String> roots,
    void Function(ScanProgress progress)? onProgress,
    Map<String, FileFingerprint>? known,
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

    final toParse = <ScannedFile>[];
    final discoveredFiles = <ScannedFile>[];
    final seenUris = <String>{};
    final knownMap = known ?? const <String, FileFingerprint>{};

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
          final uri = LocalStreamResolver.uriForPath(path);
          if (!seenUris.add(uri)) continue;

          final FileStat stat;
          try {
            stat = await entity.stat();
          } on FileSystemException catch (error) {
            // Vanished between listing and stat: leave it in `seenUris` so a
            // race does not soft-delete it this round; it will be swept next
            // scan if it is really gone.
            debugPrint('LocalLibraryScanner: cannot stat $path: $error');
            continue;
          }

          final file = ScannedFile(
            path: path,
            uri: uri,
            root: root,
            sizeBytes: stat.size,
            mtimeMs: stat.modified.millisecondsSinceEpoch,
          );
          discoveredFiles.add(file);

          final fingerprint = knownMap[uri];
          final unchanged =
              fingerprint != null &&
              fingerprint.sizeBytes == file.sizeBytes &&
              fingerprint.mtimeMs == file.mtimeMs;
          if (!unchanged) {
            toParse.add(file);
          }
          report(discovered: seenUris.length, processed: 0, currentFile: path);
        }
      } on FileSystemException catch (error) {
        // An unreadable directory/subtree must never abort the whole scan.
        debugPrint('LocalLibraryScanner: cannot list $root: $error');
      }
    }

    report(discovered: seenUris.length, processed: 0, force: true);

    final scannedTracks = <ScannedTrack>[];
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
          final results = await _extractChunk(reader, [
            for (final file in chunk) file.path,
          ]);

          // No await between reading `results` and updating the counters, so
          // these mutations are atomic with respect to the other workers.
          for (var i = 0; i < results.length; i++) {
            final track = results[i];
            if (track == null) {
              unreadable++;
            } else {
              scannedTracks.add(ScannedTrack(track: track, file: chunk[i]));
            }
          }
          processed += results.length;
          report(
            discovered: seenUris.length,
            processed: processed,
            currentFile: chunk.last.path,
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
      scannedTracks: scannedTracks,
      discoveredFiles: discoveredFiles,
      unreadable: unreadable,
      seenUris: seenUris,
    );
  }

  /// Splits [files] into `parallelism * _chunksPerWorker`-ish chunks, each
  /// processed sequentially inside one isolate.
  List<List<T>> _chunk<T>(List<T> files) {
    final targetChunks = math.min(
      files.length,
      _parallelism * _chunksPerWorker,
    );
    final chunkSize = (files.length / targetChunks).ceil();
    final chunks = <List<T>>[];
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
