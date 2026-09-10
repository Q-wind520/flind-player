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

import 'package:dio/dio.dart';

/// Realistic desktop Chrome user agent.
///
/// Must stay fresh (Bilibili risk control rejects stale or script-like UAs)
/// and must never contain substrings such as `curl` or `python`.
const String kDesktopUserAgent =
    'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 '
    '(KHTML, like Gecko) Chrome/138.0.0.0 Safari/537.36';

/// The `Referer` every Bilibili API and CDN request must carry.
///
/// The audio CDN rejects requests without it (see `docs/bilibili-source.md`
/// §7.5).
const String kDesktopReferer = 'https://www.bilibili.com/';

/// Thrown when Bilibili answers HTTP 200 with a non-zero JSON `code`.
class BiliApiException implements Exception {
  /// Bilibili business error code (`-352`, `-412`, `-101`, ...).
  final int code;

  /// Human-readable, caller-oriented description.
  final String message;

  const BiliApiException(this.code, this.message);

  /// Builds a [BiliApiException], replacing the server message with a distinct
  /// one for the well-known risk-control / rate-limit / auth codes.
  factory BiliApiException.fromCode(int code, [String? serverMessage]) {
    final known = switch (code) {
      -352 => 'Bilibili risk control triggered',
      -412 => 'Bilibili blocked this IP',
      -509 => 'Bilibili rate limit exceeded',
      -799 => 'Bilibili rate limit exceeded',
      -101 => 'Bilibili account not logged in',
      _ => null,
    };
    if (known != null) {
      return BiliApiException(code, '$known (code: $code)');
    }
    final message = (serverMessage == null || serverMessage.isEmpty)
        ? 'Bilibili API error'
        : serverMessage;
    return BiliApiException(code, '$message (code: $code)');
  }

  @override
  String toString() => 'BiliApiException($code): $message';
}

/// Thin Dio wrapper around `api.bilibili.com`.
///
/// Responsibilities:
/// * one shared [BaseOptions] with timeouts and `validateStatus: (_) => true`
///   (Bilibili returns HTTP 200 with the real status in the JSON body);
/// * the mandatory `User-Agent` / `Referer` headers on every request — and
///   **never** `Origin`, which the WAF 403s for third-party origins;
/// * attaching the risk-control `Cookie` header;
/// * turning a non-zero body `code` into a typed [BiliApiException].
class BiliClient {
  /// API host used as the Dio `baseUrl`.
  static const String baseUrl = 'https://api.bilibili.com';

  /// The user agent this client sends (reused by [BiliSource] for the CDN).
  final String userAgent;

  final Dio _dio;

  /// Creates a client, optionally wrapping a caller-supplied [dio].
  ///
  /// A supplied [dio] is still given the mandatory default headers so that no
  /// caller can accidentally bypass them.
  BiliClient({Dio? dio, this.userAgent = kDesktopUserAgent})
    : _dio =
          dio ??
          Dio(
            BaseOptions(
              baseUrl: baseUrl,
              connectTimeout: const Duration(seconds: 10),
              receiveTimeout: const Duration(seconds: 15),
              sendTimeout: const Duration(seconds: 10),
              // Bilibili reports errors in the JSON body, not the status line.
              validateStatus: (_) => true,
              headers: <String, String>{
                'User-Agent': userAgent,
                'Referer': kDesktopReferer,
                'Accept': 'application/json, text/plain, */*',
                'Accept-Language': 'zh-CN,zh;q=0.9,en;q=0.8',
              },
            ),
          ) {
    _dio.options.headers['User-Agent'] = userAgent;
    _dio.options.headers['Referer'] = kDesktopReferer;
    // Native clients must not send Origin: a third-party origin is 403'd.
    _dio.options.headers.remove('Origin');
  }

  /// Attaches the risk-control `Cookie` header (e.g. `buvid3=...; buvid4=...`).
  ///
  /// An empty header is ignored so the default header map stays untouched.
  void setCookieHeader(String cookieHeader) {
    if (cookieHeader.isEmpty) return;
    _dio.options.headers['Cookie'] = cookieHeader;
  }

  /// Performs a GET and returns the decoded JSON object.
  ///
  /// A non-zero `code` throws [BiliApiException] unless it is listed in
  /// [allowCodes] (e.g. `-101` for the anonymous `nav` key fetch).
  Future<Map<String, dynamic>> getJson(
    String path, {
    Map<String, dynamic>? query,
    Set<int> allowCodes = const <int>{},
    Map<String, dynamic>? headers,
  }) async {
    final response = await _dio.get<Object?>(
      path,
      queryParameters: query,
      options: headers == null ? null : Options(headers: headers),
    );

    final data = response.data;
    if (data is! Map) {
      throw BiliApiException(
        -1,
        'Unexpected non-JSON response for $path (HTTP ${response.statusCode})',
      );
    }

    final body = Map<String, dynamic>.from(data);
    final code = (body['code'] as num?)?.toInt() ?? 0;
    if (code != 0 && !allowCodes.contains(code)) {
      throw BiliApiException.fromCode(code, body['message'] as String?);
    }
    return body;
  }
}
