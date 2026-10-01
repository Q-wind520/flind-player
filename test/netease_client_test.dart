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

import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:flind_player/data/sources/netease/netease_client.dart';
import 'package:flind_player/data/sources/netease/netease_crypto.dart';

class _FakeAdapter implements HttpClientAdapter {
  _FakeAdapter(this.handler);
  final Future<ResponseBody> Function(RequestOptions options) handler;
  RequestOptions? lastRequest;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) {
    lastRequest = options;
    return handler(options);
  }

  @override
  void close({bool force = false}) {}
}

NeteaseClient _client(_FakeAdapter adapter) {
  final dio = Dio()..httpClientAdapter = adapter;
  return NeteaseClient(dio: dio);
}

ResponseBody _json(Map<String, dynamic> body) => ResponseBody.fromString(
  jsonEncode(body),
  200,
  headers: <String, List<String>>{
    Headers.contentTypeHeader: <String>['application/json'],
  },
);

void main() {
  test('weapi posts form params and sends the mandatory headers, no Origin', () async {
    final adapter = _FakeAdapter((_) async => _json(<String, dynamic>{'code': 200, 'result': <String, dynamic>{}}));

    await _client(adapter).postWeapi('/weapi/cloudsearch/get/web?csrf_token=', <String, dynamic>{'s': 'q'});

    final request = adapter.lastRequest!;
    expect(request.headers['Referer'], kNeteaseReferer);
    expect(request.headers.containsKey('Origin'), isFalse);
    expect(request.contentType ?? '', contains('form-urlencoded'));
    final data = request.data as Map;
    expect(data['params'], isA<String>());
    expect(data['encSecKey'], isA<String>());
  });

  test('eapi signs the /api path and sends the anonymous os=pc cookie', () async {
    final adapter = _FakeAdapter((_) async => _json(<String, dynamic>{'code': 200, 'data': <dynamic>[]}));

    await _client(adapter).postEapi('/song/enhance/player/url/v1', <String, dynamic>{'ids': '[1]'});

    final request = adapter.lastRequest!;
    expect(request.uri.host, 'interface3.music.163.com');
    expect(request.uri.path, '/eapi/song/enhance/player/url/v1');
    expect(request.headers['Referer'], kNeteaseReferer);
    expect(request.headers['Cookie'], contains('os=pc'));
    expect(request.headers['Cookie'], contains('deviceId='));
    expect(request.headers['Cookie'], contains('requestId='));
    expect(request.headers.containsKey('Origin'), isFalse);
    expect(request.contentType ?? '', contains('form-urlencoded'));

    final params = (request.data as Map)['params'] as String;
    final bytes = Uint8List.fromList(
      RegExp(r'.{2}').allMatches(params).map((m) => int.parse(m.group(0)!, radix: 16)).toList(),
    );
    expect(NeteaseCrypto.eapiDecrypt(bytes), contains('/api/song/enhance/player/url/v1'));
  });

  test('maps code -462 to a login-required error', () async {
    final adapter = _FakeAdapter((_) async => _json(<String, dynamic>{'code': -462, 'message': 'need login'}));

    expect(
      () => _client(adapter).postWeapi('/weapi/x', <String, dynamic>{}),
      throwsA(
        isA<NeteaseApiException>()
            .having((e) => e.code, 'code', -462)
            .having((e) => e.message, 'message', contains('login')),
      ),
    );
  });

  test('throws for a non-JSON body', () async {
    final adapter = _FakeAdapter((_) async => ResponseBody.fromString('nope', 200));
    expect(
      () => _client(adapter).postWeapi('/weapi/x', <String, dynamic>{}),
      throwsA(isA<NeteaseApiException>()),
    );
  });

  test('parses a numeric-string code and rejects an unreadable one', () async {
    final stringCode = _FakeAdapter((_) async => _json(<String, dynamic>{'code': '-462'}));
    await expectLater(
      () => _client(stringCode).postWeapi('/weapi/x', <String, dynamic>{}),
      throwsA(isA<NeteaseApiException>().having((e) => e.code, 'code', -462)),
    );

    final garbageCode = _FakeAdapter((_) async => _json(<String, dynamic>{'code': 'weird'}));
    await expectLater(
      () => _client(garbageCode).postWeapi('/weapi/x', <String, dynamic>{}),
      throwsA(isA<NeteaseApiException>().having((e) => e.code, 'code', -1)),
    );
  });
}
