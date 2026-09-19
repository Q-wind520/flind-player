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

import 'dart:typed_data';

import 'package:dio/dio.dart';

import 'package:flind_player/data/sources/bilibili/bili_client.dart';

/// Fetches remote cover images as raw bytes.
///
/// Bilibili's image CDN is fronted by a WAF that rejects requests without the
/// same `User-Agent` / `Referer` pair the API client sends, and it 403s any
/// request carrying a third-party `Origin`. This class centralises those rules
/// so every cover fetch behaves identically, and it treats a cover as purely
/// decorative: a fetch that fails for any reason simply yields `null` instead
/// of surfacing an error into the surrounding track load.
class CoverDownloader {
  /// Creates a downloader, optionally wrapping a caller-supplied [dio].
  ///
  /// A supplied [dio] is still given the mandatory CDN headers — and has any
  /// `Origin` stripped — so no caller can accidentally bypass the WAF rules
  /// that apply to every Bilibili image request.
  CoverDownloader({Dio? dio})
    : _dio =
          dio ??
          Dio(
            BaseOptions(
              connectTimeout: const Duration(seconds: 10),
              receiveTimeout: const Duration(seconds: 20),
              responseType: ResponseType.bytes,
              // The CDN signals failures with the status line, but a non-2xx
              // body must be inspected (and dropped) rather than thrown.
              validateStatus: (_) => true,
            ),
          ) {
    _dio.options.headers['User-Agent'] = kDesktopUserAgent;
    _dio.options.headers['Referer'] = kDesktopReferer;
    // A third-party origin is 403'd by the CDN's WAF, so never send one.
    _dio.options.headers.remove('Origin');
  }

  /// Upper bound on a single cover download, in bytes.
  ///
  /// Cover art is a few hundred kilobytes at most; anything larger is an error
  /// page or a hostile payload, so the cap keeps a bad response from consuming
  /// unbounded memory.
  static const int maxBytes = 8 * 1024 * 1024;

  final Dio _dio;

  /// Downloads [url] and returns its bytes, or `null` on any failure.
  ///
  /// Never throws: a timeout, a non-2xx status, a missing or oversized body,
  /// or an adapter-level error all collapse to `null` so a missing thumbnail
  /// can never break the caller.
  Future<Uint8List?> download(String url) async {
    final cancelToken = CancelToken();
    try {
      final response = await _dio.get<Uint8List>(
        url,
        options: Options(
          responseType: ResponseType.bytes,
          validateStatus: (_) => true,
        ),
        cancelToken: cancelToken,
        // Abort as soon as the body exceeds the cap, rather than buffering an
        // arbitrarily large hostile payload and rejecting it afterwards.
        onReceiveProgress: (received, total) {
          if (received > maxBytes) {
            cancelToken.cancel('cover exceeds the $maxBytes byte cap');
          }
        },
      );

      final status = response.statusCode ?? 0;
      if (status < 200 || status >= 300) return null;

      final declaredLength = _contentLength(response.headers);
      if (declaredLength != null && declaredLength > maxBytes) return null;

      final bytes = response.data;
      if (bytes == null || bytes.isEmpty || bytes.length > maxBytes) {
        return null;
      }
      return bytes;
    } catch (_) {
      return null;
    }
  }

  /// Reads `content-length` case-insensitively, or `null` when absent/opaque.
  static int? _contentLength(Headers headers) {
    for (final entry in headers.map.entries) {
      if (entry.key.toLowerCase() == Headers.contentLengthHeader) {
        if (entry.value.isEmpty) return null;
        return int.tryParse(entry.value.first.trim());
      }
    }
    return null;
  }
}
