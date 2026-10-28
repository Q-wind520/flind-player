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

import 'package:flind_player/data/auth/auth_cookie_jar.dart';

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

/// A decoded Bilibili JSON response plus the cookies it set.
class BiliJsonResponse {
  const BiliJsonResponse({required this.json, required this.setCookies});

  final Map<String, dynamic> json;
  final List<String> setCookies;
}

/// Thin Dio wrapper around `api.bilibili.com` and `passport.bilibili.com`.
///
/// Responsibilities:
/// * one shared [BaseOptions] with timeouts and `validateStatus: (_) => true`
///   (Bilibili returns HTTP 200 with the real status in the JSON body);
/// * the mandatory `User-Agent` / `Referer` headers on every request — and
///   **never** `Origin`, which the WAF 403s for third-party origins;
/// * merging anonymous risk-control cookies with the signed-in cookie jar;
/// * turning a non-zero body `code` into a typed [BiliApiException].
class BiliClient {
  /// API host used as the Dio `baseUrl`.
  static const String baseUrl = 'https://api.bilibili.com';

  /// The user agent this client sends (reused by [BiliSource] for the CDN).
  final String userAgent;

  final Dio _dio;
  final AuthCookieJar? _cookieJar;
  final String _sourceId;
  String _riskCookieHeader = '';

  /// Creates a client, optionally wrapping a caller-supplied [dio].
  ///
  /// A supplied [dio] is still given the mandatory default headers so that no
  /// caller can accidentally bypass them.
  BiliClient({
    Dio? dio,
    this.userAgent = kDesktopUserAgent,
    AuthCookieJar? cookieJar,
    String sourceId = 'bilibili',
  }) : _cookieJar = cookieJar, // ignore: prefer_initializing_formals
       _sourceId = sourceId, // ignore: prefer_initializing_formals
       _dio =
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

  /// Attaches the anonymous risk-control cookies (e.g. `buvid3=...`).
  ///
  /// The signed-in cookie jar, when present, is merged on top of these at
  /// request time, so logging in never drops the device fingerprint.
  void setCookieHeader(String cookieHeader) {
    _riskCookieHeader = cookieHeader;
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
    final response = await getJsonWithResponse(
      path,
      query: query,
      allowCodes: allowCodes,
      headers: headers,
    );
    return response.json;
  }

  /// Performs a GET and keeps the `Set-Cookie` headers for login flows.
  Future<BiliJsonResponse> getJsonWithResponse(
    String path, {
    Map<String, dynamic>? query,
    Set<int> allowCodes = const <int>{},
    Map<String, dynamic>? headers,
  }) async {
    final host = Uri.tryParse(path)?.host ?? '';
    final includeAuth =
        host.isEmpty ||
        host == 'bilibili.com' ||
        host.endsWith('.bilibili.com');
    final cookie = includeAuth ? _mergedCookieHeader() : null;
    final requestHeaders = <String, dynamic>{...?headers};
    if (cookie != null) requestHeaders['Cookie'] = cookie;
    final response = await _dio.get<Object?>(
      path,
      queryParameters: query,
      options: requestHeaders.isEmpty ? null : Options(headers: requestHeaders),
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

    return BiliJsonResponse(
      json: body,
      setCookies: response.headers.map['set-cookie'] ?? const <String>[],
    );
  }

  String? _mergedCookieHeader() {
    final cookies = <String, String>{};
    for (final part in _riskCookieHeader.split(';')) {
      final separator = part.indexOf('=');
      if (separator <= 0) continue;
      final name = part.substring(0, separator).trim();
      final value = part.substring(separator + 1).trim();
      if (name.isNotEmpty && value.isNotEmpty) cookies[name] = value;
    }
    final auth = _cookieJar?.cookiesFor(_sourceId);
    if (auth != null) cookies.addAll(auth);
    if (cookies.isEmpty) return null;
    return cookies.entries
        .map((entry) => '${entry.key}=${entry.value}')
        .join('; ');
  }
}
