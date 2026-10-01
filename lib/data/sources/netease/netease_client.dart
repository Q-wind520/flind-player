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

import 'package:flind_player/data/sources/bilibili/bili_client.dart';
import 'package:flind_player/data/sources/netease/netease_crypto.dart';

/// The `Referer` every NetEase API and CDN request must carry.
const String kNeteaseReferer = 'https://music.163.com';

/// Anonymous client cookies required by the `eapi` endpoints.
const String _anonCookie =
    'os=pc; appver=8.0.0; versioncode=140; mobilename=undefined; '
    'buildver=1623435496; resolution=1920x1080; __csrf=; channel=undefined';

/// Thrown when the API answers HTTP 200 with a non-200 JSON `code`.
class NeteaseApiException implements Exception {
  final int code;
  final String message;

  const NeteaseApiException(this.code, this.message);

  factory NeteaseApiException.fromCode(int code, [String? serverMessage]) {
    if (code == -462) {
      return const NeteaseApiException(-462, 'NetEase login required (-462)');
    }
    final message = (serverMessage == null || serverMessage.isEmpty)
        ? 'NetEase API error'
        : serverMessage;
    return NeteaseApiException(code, '$message (code: $code)');
  }

  @override
  String toString() => 'NeteaseApiException($code): $message';
}

/// Thin Dio wrapper around `music.163.com` (`weapi`) and
/// `interface3.music.163.com` (`eapi`).
class NeteaseClient {
  static const String weapiBaseUrl = 'https://music.163.com';
  static const String eapiBaseUrl = 'https://interface3.music.163.com';

  final String userAgent;
  final Dio _dio;

  NeteaseClient({Dio? dio, this.userAgent = kDesktopUserAgent})
    : _dio = dio ?? Dio() {
    _dio.options
      ..baseUrl = weapiBaseUrl
      ..connectTimeout = const Duration(seconds: 10)
      ..receiveTimeout = const Duration(seconds: 15)
      ..sendTimeout = const Duration(seconds: 10)
      ..validateStatus = ((_) => true)
      ..headers['User-Agent'] = userAgent
      ..headers['Referer'] = kNeteaseReferer
      ..headers['Accept'] = 'application/json, text/plain, */*'
      ..headers['Accept-Language'] = 'zh-CN,zh;q=0.9,en;q=0.8'
      ..headers.remove('Origin');
  }

  Future<Map<String, dynamic>> postWeapi(
    String path,
    Map<String, dynamic> body,
  ) async {
    final signed = NeteaseCrypto.weapi(body);
    final response = await _dio.post<Object?>(
      path,
      data: <String, dynamic>{
        'params': signed.params,
        'encSecKey': signed.encSecKey,
      },
      options: Options(contentType: Headers.formUrlEncodedContentType),
    );
    return _decode(response, path);
  }

  Future<Map<String, dynamic>> postEapi(
    String apiPath,
    Map<String, dynamic> body,
  ) async {
    final params = NeteaseCrypto.eapi(
      '/api$apiPath',
      body,
      const <String, String>{'os': 'pc'},
    );
    final response = await _dio.post<Object?>(
      '$eapiBaseUrl/eapi$apiPath',
      data: <String, dynamic>{'params': params},
      options: Options(
        contentType: Headers.formUrlEncodedContentType,
        headers: <String, String>{'Cookie': _anonCookie},
      ),
    );
    return _decode(response, apiPath);
  }

  Map<String, dynamic> _decode(Response<Object?> response, String path) {
    final data = response.data;
    if (data is! Map) {
      throw NeteaseApiException(
        -1,
        'Unexpected non-JSON response for $path (HTTP ${response.statusCode})',
      );
    }
    final json = Map<String, dynamic>.from(data);
    final code = (json['code'] as num?)?.toInt() ?? 200;
    if (code != 200) {
      throw NeteaseApiException.fromCode(
        code,
        json['message'] as String? ?? json['msg'] as String?,
      );
    }
    return json;
  }
}
