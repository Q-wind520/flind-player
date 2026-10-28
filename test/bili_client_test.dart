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

import 'package:flind_player/data/auth/auth_cookie_jar.dart';
import 'package:flind_player/data/sources/bilibili/bili_client.dart';

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

ResponseBody _json() => ResponseBody.fromString(
  jsonEncode(<String, dynamic>{'code': 0, 'data': <String, dynamic>{}}),
  200,
  headers: <String, List<String>>{
    Headers.contentTypeHeader: <String>['application/json'],
  },
);

BiliClient _client(_FakeAdapter adapter, {AuthCookieJar? jar}) {
  final dio = Dio()..httpClientAdapter = adapter;
  return BiliClient(dio: dio, cookieJar: jar);
}

void main() {
  test('API requests merge risk-control and signed-in cookies', () async {
    final adapter = _FakeAdapter((_) async => _json());
    final jar = AuthCookieJar()
      ..replace('bilibili', const <String, String>{'SESSDATA': 'secret'});
    final client = _client(adapter, jar: jar)..setCookieHeader('buvid3=device');

    await client.getJson('/x/web-interface/nav');

    final cookie = adapter.lastRequest!.headers['Cookie']! as String;
    expect(cookie, contains('buvid3=device'));
    expect(cookie, contains('SESSDATA=secret'));
  });

  test('subtitle CDN requests never carry Bilibili credentials', () async {
    final adapter = _FakeAdapter((_) async => _json());
    final jar = AuthCookieJar()
      ..replace('bilibili', const <String, String>{'SESSDATA': 'secret'});
    final client = _client(adapter, jar: jar)..setCookieHeader('buvid3=device');

    await client.getJson('https://aisubtitle.hdslb.com/bfs/subtitle/a.json');

    expect(adapter.lastRequest!.headers.containsKey('Cookie'), isFalse);
  });

  test('passport requests keep the login cookie', () async {
    final adapter = _FakeAdapter((_) async => _json());
    final jar = AuthCookieJar()
      ..replace('bilibili', const <String, String>{'SESSDATA': 'secret'});
    final client = _client(adapter, jar: jar);

    await client.getJson(
      'https://passport.bilibili.com/x/passport-login/web/qrcode/poll',
    );

    expect(
      adapter.lastRequest!.headers['Cookie'] as String,
      contains('SESSDATA=secret'),
    );
  });
}
