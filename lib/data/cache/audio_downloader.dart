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

import 'package:dio/dio.dart';

/// The stream URL is no longer valid (HTTP 403/404) and the caller must
/// re-resolve it.
///
/// Bilibili CDN URLs expire after roughly 120 minutes
/// (`docs/bilibili-source.md` §7.3), so a download that starts with a stale URL
/// must be retried against a freshly resolved one.
class StreamExpiredException implements Exception {
  const StreamExpiredException(this.url);

  /// The expired URL the server rejected.
  final Uri url;

  @override
  String toString() => 'StreamExpiredException($url)';
}

/// A download failed after every retry was exhausted.
class DownloadFailedException implements Exception {
  const DownloadFailedException({required this.attempts, required this.cause});

  /// Number of attempts made before giving up.
  final int attempts;

  /// The last error that caused the failure.
  final Object cause;

  @override
  String toString() =>
      'DownloadFailedException(after $attempts attempts): $cause';
}

/// A transient failure worth retrying (network error or unexpected status).
class _RetryableException implements Exception {
  const _RetryableException(this.message);

  final String message;

  @override
  String toString() => 'RetryableDownloadFailure($message)';
}

/// Streams an HTTP(S) resource into a local file with Range resume.
///
/// Downloads are written to `<target>.part` and renamed onto [target] only once
/// the body has been fully consumed, so [target] never contains a truncated
/// file. A leftover `.part` from a failed attempt is reused on the next call:
/// the downloader asks for `Range: bytes=<existing>-` and appends the response.
/// Servers that ignore `Range` (answering `200`) cause a clean restart from
/// zero.
///
/// Transient failures are retried up to [maxAttempts] with exponential backoff
/// (1s, 2s, 4s, ...). HTTP 403/404 is treated as an expired stream URL and
/// surfaces as [StreamExpiredException] without any retry, because retrying a
/// dead URL cannot succeed.
class AudioDownloader {
  /// Creates a downloader.
  ///
  /// [dio] is injectable for testing; when omitted a bare [Dio] is created.
  /// [sleeper] replaces `Future.delayed` in tests so backoff waits are instant.
  AudioDownloader({
    Dio? dio,
    this.maxAttempts = 3,
    Future<void> Function(Duration)? sleeper,
  }) : _dio = dio ?? Dio(),
       _sleep = sleeper ?? Future<void>.delayed;

  final Dio _dio;

  /// Maximum number of attempts (including the first) before giving up.
  final int maxAttempts;

  final Future<void> Function(Duration) _sleep;

  /// Throttle window for progress callbacks (docs/local-library.md §6: ~10 Hz).
  static const Duration _progressInterval = Duration(milliseconds: 100);

  /// Downloads [url] (sending [headers]) into [target].
  ///
  /// [onProgress] receives `(receivedBytes, totalBytes)`; [totalBytes] is `null`
  /// when the server does not report a length. Progress is reported at most
  /// every [_progressInterval], plus one final event at completion.
  ///
  /// Returns the number of bytes in the completed file.
  ///
  /// Throws [StreamExpiredException] immediately on 403/404, or
  /// [DownloadFailedException] once [maxAttempts] transient failures occur.
  Future<int> download({
    required Uri url,
    required Map<String, String> headers,
    required File target,
    void Function(int received, int? total)? onProgress,
  }) async {
    await target.parent.create(recursive: true);
    final part = File('${target.path}.part');

    Object? lastError;
    for (var attempt = 1; attempt <= maxAttempts; attempt++) {
      try {
        return await _attempt(
          url: url,
          headers: headers,
          target: target,
          part: part,
          onProgress: onProgress,
        );
      } on StreamExpiredException {
        // A dead URL is not a transient failure: let the caller re-resolve.
        rethrow;
      } catch (error) {
        lastError = error;
        if (attempt >= maxAttempts) break;
        await _sleep(Duration(seconds: 1 << (attempt - 1)));
      }
    }

    throw DownloadFailedException(
      attempts: maxAttempts,
      cause: lastError ?? const _RetryableException('unknown error'),
    );
  }

  /// Performs a single download attempt, resuming from [part] when possible.
  Future<int> _attempt({
    required Uri url,
    required Map<String, String> headers,
    required File target,
    required File part,
    void Function(int received, int? total)? onProgress,
  }) async {
    final existing = part.existsSync() ? part.lengthSync() : 0;
    final requestHeaders = <String, dynamic>{...headers};
    if (existing > 0) {
      requestHeaders['Range'] = 'bytes=$existing-';
    }

    final response = await _dio.get<ResponseBody>(
      url.toString(),
      options: Options(
        responseType: ResponseType.stream,
        headers: requestHeaders,
        // Status handling is explicit so 403/404 can be told apart from
        // transient server errors.
        validateStatus: (_) => true,
      ),
    );

    final status = response.statusCode ?? 0;
    final body = response.data;

    if (status == 403 || status == 404) {
      await _drainQuietly(body);
      throw StreamExpiredException(url);
    }
    if (status == 416) {
      // The partial file no longer matches the resource; drop it so the next
      // attempt restarts cleanly instead of failing forever.
      await _drainQuietly(body);
      if (part.existsSync()) {
        part.deleteSync();
      }
      throw const _RetryableException('HTTP 416 Range Not Satisfiable');
    }
    if (status != 200 && status != 206) {
      await _drainQuietly(body);
      throw _RetryableException('HTTP $status');
    }
    if (body == null) {
      throw const _RetryableException('empty response body');
    }

    final resuming = status == 206 && existing > 0;
    final startOffset = resuming ? existing : 0;
    final remaining = _knownLength(body);
    final total = resuming
        ? _totalFromContentRange(response.headers.value('content-range')) ??
              (remaining == null ? null : startOffset + remaining)
        : remaining;

    final sink = part.openWrite(
      mode: resuming ? FileMode.writeOnlyAppend : FileMode.writeOnly,
    );
    var received = startOffset;
    var lastEmit = DateTime.fromMillisecondsSinceEpoch(0);

    try {
      await for (final chunk in body.stream) {
        sink.add(chunk);
        received += chunk.length;
        final now = DateTime.now();
        if (now.difference(lastEmit) >= _progressInterval) {
          lastEmit = now;
          onProgress?.call(received, total);
        }
      }
      await sink.flush();
      await sink.close();
    } catch (error) {
      await _closeQuietly(sink);
      rethrow;
    }

    if (target.existsSync()) {
      target.deleteSync();
    }
    final completed = await part.rename(target.path);

    onProgress?.call(received, total ?? received);
    return completed.lengthSync();
  }

  /// Content-Length as a non-negative `int`, or `null` when absent.
  int? _knownLength(ResponseBody body) {
    final length = body.contentLength;
    return length >= 0 ? length : null;
  }

  /// Extracts the resource size from a `Content-Range: bytes a-b/total` header.
  int? _totalFromContentRange(String? value) {
    if (value == null) return null;
    final slash = value.lastIndexOf('/');
    if (slash < 0) return null;
    final total = value.substring(slash + 1).trim();
    if (total.isEmpty || total == '*') return null;
    return int.tryParse(total);
  }

  /// Drains an error body so the underlying connection can be released.
  Future<void> _drainQuietly(ResponseBody? body) async {
    if (body == null) return;
    try {
      await body.stream.drain<void>();
    } catch (_) {
      // The body is being discarded anyway.
    }
  }

  Future<void> _closeQuietly(IOSink sink) async {
    try {
      await sink.close();
    } catch (_) {
      // Best effort on the failure path.
    }
  }
}
