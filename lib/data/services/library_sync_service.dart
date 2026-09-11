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

// Named parameters cannot be private initializing formals, so the constructor
// assigns these private fields explicitly.
// ignore_for_file: prefer_initializing_formals

import 'dart:async';
import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';

import 'package:flind_player/core/models/track.dart';
import 'package:flind_player/core/repositories/music_library_repository.dart';
import 'package:flind_player/core/sources/source_track_id.dart';
import 'package:flind_player/data/sources/local/artwork_cache.dart';
import 'package:flind_player/data/sources/local/local_library_scanner.dart';

/// Prefix used by the canonical local track uri (`local:/abs/path`).
const String _localUriPrefix = 'local:';

/// Stage of a library sync.
enum LibrarySyncPhase { idle, scanning, saving, artwork, done, failed }

/// Immutable snapshot of a library sync, streamed by [LibrarySyncService].
@immutable
class LibrarySyncState {
  const LibrarySyncState({
    required this.phase,
    this.discovered = 0,
    this.processed = 0,
    this.saved = 0,
    this.coversCached = 0,
    this.markedMissing = 0,
    this.currentFile,
    this.error,
  });

  /// The resting state before any sync runs.
  static const LibrarySyncState idle = LibrarySyncState(
    phase: LibrarySyncPhase.idle,
  );

  final LibrarySyncPhase phase;

  /// Files matching the audio extensions found by the scan.
  final int discovered;

  /// Metadata reads finished.
  final int processed;

  /// Tracks written to the library.
  final int saved;

  /// Covers written during the artwork pass.
  final int coversCached;

  /// Rows newly marked missing (soft-deleted) by this sync.
  final int markedMissing;

  /// Most recently touched file, for display.
  final String? currentFile;

  /// The error that moved the sync to [LibrarySyncPhase.failed], if any.
  final Object? error;

  @override
  String toString() =>
      'LibrarySyncState(phase: $phase, discovered: $discovered, '
      'processed: $processed, saved: $saved, coversCached: $coversCached, '
      'markedMissing: $markedMissing, error: $error)';
}

/// Orchestrates a full local-library sync and publishes progress.
///
/// The pipeline mirrors docs/local-library.md §2.4:
/// scan -> batch upsert -> soft-delete unseen -> low-priority artwork pass.
/// A failed or empty scan is guarded so it can never wipe a good library.
class LibrarySyncService {
  /// Creates a sync service.
  ///
  /// Set [enableArtworkPass] to `false` to skip the (potentially slow) cover
  /// pass, e.g. in tests. [artworkBatchSize] bounds how many tracks are
  /// upserted per artwork batch.
  LibrarySyncService({
    required LocalLibraryScanner scanner,
    required MusicLibraryRepository repository,
    required ArtworkCache artworkCache,
    bool enableArtworkPass = true,
    int artworkBatchSize = 20,
  }) : _scanner = scanner,
       _repository = repository,
       _artworkCache = artworkCache,
       _enableArtworkPass = enableArtworkPass,
       _artworkBatchSize = math.max(1, artworkBatchSize);

  final LocalLibraryScanner _scanner;
  final MusicLibraryRepository _repository;
  final ArtworkCache _artworkCache;
  final bool _enableArtworkPass;
  final int _artworkBatchSize;

  final StreamController<LibrarySyncState> _controller =
      StreamController<LibrarySyncState>.broadcast();

  LibrarySyncState _current = LibrarySyncState.idle;
  bool _running = false;

  /// Progress stream. The current state is emitted first, then live updates.
  Stream<LibrarySyncState> get state async* {
    yield _current;
    yield* _controller.stream;
  }

  /// Whether a sync is currently running.
  bool get isRunning => _running;

  /// The most recently emitted state.
  LibrarySyncState get current => _current;

  /// Releases the progress stream.
  Future<void> dispose() => _controller.close();

  /// Runs a full sync. A second call while one is running is a no-op.
  ///
  /// Never throws: failures are reported as [LibrarySyncPhase.failed] with the
  /// error attached.
  Future<void> sync() async {
    if (_running) return;
    _running = true;

    try {
      final roots = await _repository.scanRoots();
      if (roots.isEmpty) {
        _emit(const LibrarySyncState(phase: LibrarySyncPhase.done));
        return;
      }

      // Incremental pass: files whose stored `(size, mtime)` still match are
      // not re-parsed, so a rescan only reads new or changed files
      // (docs/local-library.md §2.4, §6).
      final known = await _repository.trackFingerprints('local');

      _emit(const LibrarySyncState(phase: LibrarySyncPhase.scanning));

      final result = await _scanner.scan(
        roots: roots,
        known: known,
        onProgress: (progress) {
          _emit(
            LibrarySyncState(
              phase: LibrarySyncPhase.scanning,
              discovered: progress.discovered,
              processed: progress.processed,
              currentFile: progress.currentFile,
            ),
          );
        },
      );

      // Guard (docs/local-library.md §2.4): zero discovered files means every
      // root was missing or unplugged. Marking everything missing here would
      // wipe a good library, so stop before touching the database.
      if (result.discovered == 0) {
        _emit(
          LibrarySyncState(
            phase: LibrarySyncPhase.done,
            discovered: result.discovered,
            processed: result.processed,
          ),
        );
        return;
      }

      _emit(
        LibrarySyncState(
          phase: LibrarySyncPhase.saving,
          discovered: result.discovered,
          processed: result.processed,
        ),
      );

      await _repository.upsertScannedTracks(result.scannedTracks);
      // Mark against every discovered uri — including files skipped as already
      // known — so a rescan never marks a still-present file missing.
      //
      // Files outside the scan roots (e.g. imported individually) are never
      // discovered, so add back every known local track whose file still exists
      // on disk. Only genuinely vanished files get soft-deleted.
      final presentUris = <String>{...result.seenUris};
      for (final uri in await _repository.trackUrisForSource('local')) {
        if (presentUris.contains(uri) || !uri.startsWith(_localUriPrefix)) {
          continue;
        }
        final path = uri.substring(_localUriPrefix.length);
        if (File(path).existsSync()) {
          presentUris.add(uri);
        }
      }

      // Scope the soft-delete sweep to roots that were actually present. A
      // configured root whose directory is gone (e.g. an unmounted drive) is
      // excluded so its tracks are left alone (docs/local-library.md §2.4
      // rule 3).
      final scannedRoots = <String>{
        for (final root in roots)
          if (Directory(root).existsSync()) root,
      };
      final markedMissing = await _repository.markMissingExcept(
        'local',
        presentUris,
        roots: scannedRoots,
      );

      _emit(
        LibrarySyncState(
          phase: _enableArtworkPass
              ? LibrarySyncPhase.artwork
              : LibrarySyncPhase.done,
          discovered: result.discovered,
          processed: result.processed,
          saved: result.tracks.length,
          markedMissing: markedMissing,
        ),
      );

      if (_enableArtworkPass) {
        await _cacheArtwork(
          result.tracks,
          discovered: result.discovered,
          processed: result.processed,
          markedMissing: markedMissing,
        );
        _emit(
          LibrarySyncState(
            phase: LibrarySyncPhase.done,
            discovered: result.discovered,
            processed: result.processed,
            saved: result.tracks.length,
            coversCached: _current.coversCached,
            markedMissing: markedMissing,
          ),
        );
      }
    } catch (error) {
      _emit(LibrarySyncState(phase: LibrarySyncPhase.failed, error: error));
    } finally {
      _running = false;
    }
  }

  /// Low-priority pass that extracts covers for tracks lacking one.
  Future<void> _cacheArtwork(
    List<Track> tracks, {
    required int discovered,
    required int processed,
    required int markedMissing,
  }) async {
    final withoutCover = tracks
        .where((track) => track.coverPath == null)
        .toList(growable: false);
    if (withoutCover.isEmpty) return;

    var coversCached = 0;
    for (var i = 0; i < withoutCover.length; i += _artworkBatchSize) {
      final end = math.min(i + _artworkBatchSize, withoutCover.length);
      final batch = withoutCover.sublist(i, end);

      final updated = <Track>[];
      for (final track in batch) {
        final path = _localPathOf(track);
        if (path == null) continue;
        final coverPath = await _artworkCache.cacheFromFile(path);
        if (coverPath == null) continue;
        updated.add(track.copyWith(coverPath: coverPath));
        coversCached++;
      }

      if (updated.isNotEmpty) {
        await _repository.upsertTracks(updated);
      }

      _emit(
        LibrarySyncState(
          phase: LibrarySyncPhase.artwork,
          discovered: discovered,
          processed: processed,
          saved: tracks.length,
          coversCached: coversCached,
          markedMissing: markedMissing,
          currentFile: batch.last.uri,
        ),
      );
    }
  }

  /// On-disk path for a `local` track, or `null` for other sources.
  String? _localPathOf(Track track) {
    const prefix = 'local:';
    if (track.uri.startsWith(prefix)) {
      final path = track.uri.substring(prefix.length);
      if (path.isNotEmpty) return path;
    }
    final id = track.sourceTrackId;
    if (id is LocalTrackId && id.path.isNotEmpty) {
      return id.path;
    }
    return null;
  }

  void _emit(LibrarySyncState state) {
    _current = state;
    if (!_controller.isClosed) {
      _controller.add(state);
    }
  }
}
