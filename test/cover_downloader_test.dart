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
import 'package:flutter_test/flutter_test.dart';

import 'package:flind_player/data/cache/cover_downloader.dart';
import 'package:flind_player/data/sources/bilibili/bili_client.dart';

/// Minimal [HttpClientAdapter] that delegates to [handler] and records the
/// last [RequestOptions] so tests can assert the outbound headers.
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

CoverDownloader _downloaderWith(_FakeAdapter adapter) {
  final dio = Dio()..httpClientAdapter = adapter;
  return CoverDownloader(dio: dio);
}

void main() {
  test('returns the bytes from a 200 response', () async {
    final payload = Uint8List.fromList(
      List<int>.generate(2048, (index) => index % 256),
    );
    final adapter = _FakeAdapter(
      (_) async => ResponseBody.fromBytes(
        payload,
        200,
        headers: <String, List<String>>{
          Headers.contentLengthHeader: <String>['${payload.length}'],
        },
      ),
    );

    final bytes = await _downloaderWith(adapter)
        .download('https://i0.hdslb.com/bfs/archive/cover.jpg');

    expect(bytes, payload);
  });

  test('sends the mandatory Referer and User-Agent, and no Origin', () async {
    final adapter = _FakeAdapter(
      (_) async => ResponseBody.fromBytes(const <int>[1], 200),
    );

    await _downloaderWith(adapter)
        .download('https://i0.hdslb.com/bfs/archive/cover.jpg');

    final headers = adapter.lastRequest!.headers;
    expect(headers['User-Agent'], kDesktopUserAgent);
    expect(headers['Referer'], kDesktopReferer);
    expect(headers.containsKey('Origin'), isFalse);
  });

  test('returns null for a non-2xx status', () async {
    final adapter = _FakeAdapter(
      (_) async => ResponseBody.fromBytes(const <int>[1, 2, 3], 404),
    );

    final bytes = await _downloaderWith(adapter)
        .download('https://i0.hdslb.com/bfs/archive/missing.jpg');

    expect(bytes, isNull);
  });

  test('returns null when content-length exceeds maxBytes', () async {
    final payload = Uint8List.fromList(const <int>[1, 2, 3, 4]);
    final adapter = _FakeAdapter(
      (_) async => ResponseBody.fromBytes(
        payload,
        200,
        headers: <String, List<String>>{
          Headers.contentLengthHeader: <String>[
            '${CoverDownloader.maxBytes + 1}',
          ],
        },
      ),
    );

    final bytes = await _downloaderWith(adapter)
        .download('https://i0.hdslb.com/bfs/archive/huge.jpg');

    expect(bytes, isNull);
  });

  test('returns null for an empty body', () async {
    final adapter = _FakeAdapter(
      (_) async => ResponseBody.fromBytes(const <int>[], 200),
    );

    final bytes = await _downloaderWith(adapter)
        .download('https://i0.hdslb.com/bfs/archive/empty.jpg');

    expect(bytes, isNull);
  });

  test('returns null when the adapter throws', () async {
    final adapter = _FakeAdapter((_) async => throw Exception('network down'));

    final bytes = await _downloaderWith(adapter)
        .download('https://i0.hdslb.com/bfs/archive/cover.jpg');

    expect(bytes, isNull);
  });
}
