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
import 'package:flind_player/core/repositories/settings_repository.dart';
import 'package:flind_player/core/sources/music_source.dart';
import 'package:flind_player/core/sources/source_track_id.dart';
import 'package:flind_player/core/sources/stream_resolver.dart';
import 'package:flind_player/data/cache/audio_cache_store.dart';
import 'package:flind_player/data/cache/audio_downloader.dart';

/// Canonical `audio_cache.source_track_id` value for [track].
///
/// Mirrors the convention in `docs/local-library.md` §4.4: `bvid:cid` for
/// Bilibili and the absolute path for local files. The download manager and the
/// cache-first resolver must agree on this key or lookups would miss.
String cacheSourceTrackId(Track track) {
  final id = track.sourceTrackId;
  if (id is BiliTrackId) return '${id.bvid}:${id.cid}';
  if (id is LocalTrackId) return id.path;
  return id.toString();
}

/// Lifecycle of one queued download.
enum DownloadPhase { queued, downloading, done, failed, skipped }

/// A single progress update emitted by [DownloadManager].
@immutable
class DownloadProgress {
  const DownloadProgress({
    required this.source,
    required this.sourceTrackId,
    required this.title,
    required this.phase,
    this.received = 0,
    this.total = 0,
    this.error,
  });

  /// Source identifier, e.g. `bilibili`.
  final String source;

  /// Source-specific identity, e.g. `BV...:cid`.
  final String sourceTrackId;

  /// Human-readable track title, for progress UI.
  final String title;

  final DownloadPhase phase;

  /// Bytes downloaded so far.
  final int received;

  /// Total bytes when known, otherwise `0`.
  final int total;

  /// The failure that produced [DownloadPhase.failed], when applicable.
  final Object? error;

  @override
  String toString() =>
      'DownloadProgress($source:$sourceTrackId, $phase, '
      '$received/$total${error == null ? '' : ', error: $error'})';
}

/// One queued [cacheTrack] request.
class _QueuedDownload {
  _QueuedDownload({
    required this.track,
    required this.pinned,
    required this.knownInfo,
  });

  final Track track;
  final bool pinned;
  final StreamInfo? knownInfo;
  final Completer<void> completer = Completer<void>();
}

/// Serialises offline downloads and keeps the cache index in sync.
///
/// At most one download runs at a time (`docs/local-library.md` §4.7); extra
/// [cacheTrack] calls queue FIFO. Every outcome — including failures — is
/// reported as a [DownloadProgress] event, and [cacheTrack] never throws.
class DownloadManager {
  DownloadManager({
    required AudioCacheStore store,
    required AudioDownloader downloader,
    required StreamResolver resolver,
    required SettingsRepository settings,
  }) : _store = store, // ignore: prefer_initializing_formals
       _downloader = downloader, // ignore: prefer_initializing_formals
       _resolver = resolver, // ignore: prefer_initializing_formals
       _settings = settings; // ignore: prefer_initializing_formals

  final AudioCacheStore _store;
  final AudioDownloader _downloader;
  final StreamResolver _resolver;
  final SettingsRepository _settings;

  final StreamController<DownloadProgress> _progress =
      StreamController<DownloadProgress>.broadcast();

  final List<_QueuedDownload> _queue = <_QueuedDownload>[];

  bool _draining = false;
  bool _disposed = false;
  _QueuedDownload? _active;

  /// Broadcast stream of every progress change.
  Stream<DownloadProgress> get progress => _progress.stream;

  /// Whether a download is running or queued.
  bool get isBusy => _active != null || _queue.isNotEmpty;

  /// Resolves, downloads and indexes [track]'s audio file.
  ///
  /// [pinned] marks a manual download that LRU eviction must never remove.
  /// [knownInfo] skips the resolver when the caller already holds a fresh
  /// [StreamInfo] (the cache-first resolver does this on a playback miss).
  ///
  /// The returned future completes when this request has been processed; it
  /// never completes with an error. Failures surface as [DownloadPhase.failed]
  /// events.
  Future<void> cacheTrack(
    Track track, {
    bool pinned = false,
    StreamInfo? knownInfo,
  }) {
    if (_disposed) {
      return Future<void>.value();
    }
    final task = _QueuedDownload(
      track: track,
      pinned: pinned,
      knownInfo: knownInfo,
    );
    _queue.add(task);
    _emit(task, DownloadPhase.queued);
    unawaited(_drain());
    return task.completer.future;
  }

  /// Whether [track] is indexed and its file still exists on disk.
  Future<bool> isCached(Track track) async {
    try {
      final entry = await _store.lookup(
        track.source,
        cacheSourceTrackId(track),
      );
      if (entry == null) return false;
      return File(entry.filePath).existsSync();
    } catch (error) {
      debugPrint('DownloadManager: cache lookup failed: $error');
      return false;
    }
  }

  /// Closes the progress stream. In-flight work is abandoned; queued requests
  /// complete without emitting further events.
  Future<void> dispose() async {
    if (_disposed) return;
    _disposed = true;
    for (final task in _queue) {
      if (!task.completer.isCompleted) task.completer.complete();
    }
    _queue.clear();
    await _progress.close();
  }

  Future<void> _drain() async {
    if (_draining) return;
    _draining = true;
    try {
      while (_queue.isNotEmpty && !_disposed) {
        final task = _queue.removeAt(0);
        _active = task;
        try {
          await _run(task);
        } catch (error, stackTrace) {
          // Defensive: _run handles its own errors, but a caller must never
          // hang on an unexpected one.
          debugPrint(
            'DownloadManager: unexpected error for ${task.track.uri}: '
            '$error\n$stackTrace',
          );
          _emit(task, DownloadPhase.failed, error: error);
        } finally {
          _active = null;
          if (!task.completer.isCompleted) task.completer.complete();
        }
      }
    } finally {
      _draining = false;
    }
  }

  Future<void> _run(_QueuedDownload task) async {
    final track = task.track;

    final settings = await _settings.cacheSettings();
    if (!settings.enabled) {
      _emit(task, DownloadPhase.skipped);
      return;
    }

    CachedAudio? cachedEntry;
    try {
      cachedEntry = await _store.lookup(
        track.source,
        cacheSourceTrackId(track),
      );
    } catch (error) {
      debugPrint('DownloadManager: cache lookup failed: $error');
    }
    if (cachedEntry != null && File(cachedEntry.filePath).existsSync()) {
      // Already on disk. A pin request must still be honoured: the entry may
      // have been written by the play-through cache (pinned: false), and
      // pinning is what exempts it from LRU eviction.
      if (task.pinned && !cachedEntry.pinned) {
        await _store.setPinned(cachedEntry.id, true);
        _emit(task, DownloadPhase.done);
      } else {
        _emit(task, DownloadPhase.skipped);
      }
      return;
    }

    StreamInfo? info = task.knownInfo;
    if (info == null) {
      try {
        info = await _resolver.resolve(track);
      } catch (error) {
        _emit(task, DownloadPhase.failed, error: error);
        return;
      }
    }

    // Content-Length is only known once the download response arrives, so the
    // pre-flight check uses the best available estimate (0 when unknown).
    // `ensureSpace` still evicts non-pinned LRU entries whenever the cache is
    // already over the configured limit, and never touches pinned rows.
    final eviction = await _store.ensureSpace(_estimateBytes(info));
    if (!eviction.hasSpace) {
      _emit(
        task,
        DownloadPhase.failed,
        error: StateError('缓存空间不足：手动下载已占用全部缓存额度'),
      );
      return;
    }

    final extension = _extensionFor(info.url, track.source);
    final target = _store.fileFor(
      source: track.source,
      sourceTrackId: cacheSourceTrackId(track),
      extension: extension,
    );

    _emit(task, DownloadPhase.downloading, total: _estimateBytes(info));

    final int bytes;
    try {
      bytes = await _downloadWithExpiryRetry(
        track: track,
        info: info,
        target: target,
        onProgress: (received, total) => _emit(
          task,
          DownloadPhase.downloading,
          received: received,
          total: total ?? 0,
        ),
      );
    } on StreamExpiredException catch (error) {
      _emit(task, DownloadPhase.failed, error: error);
      return;
    } catch (error) {
      _emit(task, DownloadPhase.failed, error: error);
      return;
    }

    // The real byte count is only known now. Re-check with it so a single
    // oversized file cannot push the cache past its limit: evict LRU entries
    // first, and when pinned entries already fill the budget, drop the
    // download instead of indexing it.
    final postEviction = await _store.ensureSpace(bytes);
    if (!postEviction.hasSpace) {
      try {
        if (target.existsSync()) {
          target.deleteSync();
        }
      } catch (error) {
        debugPrint('DownloadManager: failed to delete oversized file: $error');
      }
      _emit(
        task,
        DownloadPhase.failed,
        error: StateError('缓存空间不足：单曲 $bytes 字节超出可用额度'),
      );
      return;
    }

    try {
      await _store.insert(
        source: track.source,
        sourceTrackId: cacheSourceTrackId(track),
        filePath: target.path,
        bytes: bytes,
        qualityId: info.qualityId,
        pinned: task.pinned,
      );
    } catch (error) {
      _emit(task, DownloadPhase.failed, error: error);
      return;
    }

    _emit(task, DownloadPhase.done, received: bytes, total: bytes);
  }

  /// Downloads [info]'s URL, re-resolving once when the URL has expired.
  Future<int> _downloadWithExpiryRetry({
    required Track track,
    required StreamInfo info,
    required File target,
    required void Function(int received, int? total) onProgress,
  }) async {
    try {
      return await _downloader.download(
        url: info.url,
        headers: info.headers,
        target: target,
        onProgress: onProgress,
      );
    } on StreamExpiredException {
      // The cached URL expired (~120 min, docs/bilibili-source.md §7.3):
      // resolve a fresh one exactly once and retry.
      final fresh = await _resolver.resolve(track);
      return _downloader.download(
        url: fresh.url,
        headers: fresh.headers,
        target: target,
        onProgress: onProgress,
      );
    }
  }

  /// Best-effort incoming size. [StreamInfo] carries no length, so this is `0`
  /// and the post-download total is recorded instead.
  int _estimateBytes(StreamInfo info) => 0;

  /// Derives the cached file extension from the URL path.
  ///
  /// Bilibili serves DASH audio as `.m4s`/`.m4a`; when the path has no usable
  /// suffix the source default applies (`.m4a` for Bilibili, `.mp3`
  /// otherwise).
  String _extensionFor(Uri url, String source) {
    final path = url.path;
    final dot = path.lastIndexOf('.');
    if (dot >= 0 && dot < path.length - 1) {
      final extension = path.substring(dot + 1).toLowerCase();
      if (extension.length <= 5 && _safeExtension.hasMatch(extension)) {
        return '.$extension';
      }
    }
    return source == 'bilibili' ? '.m4a' : '.mp3';
  }

  static final RegExp _safeExtension = RegExp(r'^[a-z0-9]+$');

  void _emit(
    _QueuedDownload task,
    DownloadPhase phase, {
    int received = 0,
    int total = 0,
    Object? error,
  }) {
    if (_disposed || _progress.isClosed) return;
    _progress.add(
      DownloadProgress(
        source: task.track.source,
        sourceTrackId: cacheSourceTrackId(task.track),
        title: task.track.title,
        phase: phase,
        received: received,
        total: total,
        error: error,
      ),
    );
  }
}
