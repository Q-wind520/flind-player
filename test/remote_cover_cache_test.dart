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

import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:flind_player/data/cache/remote_cover_cache.dart';

void main() {
  const url = 'https://p1.music.126.net/a.jpg';
  final bytes = Uint8List.fromList(<int>[1, 2, 3, 4]);

  RemoteCoverCache build({
    String? hit,
    Uint8List? downloadResult,
    bool isImage = true,
    List<String>? downloads,
    List<Map<String, Object?>>? stores,
  }) => RemoteCoverCache(
    lookupPath: (urlHash) async => hit,
    download: (u) async {
      downloads?.add(u);
      return downloadResult;
    },
    store:
        ({required String urlHash, required String contentHash, required bytes}) async {
          stores?.add(<String, Object?>{
            'urlHash': urlHash,
            'contentHash': contentHash,
            'bytes': bytes,
          });
          return '/cache/$contentHash.jpg';
        },
    isImage: (_) => isImage,
  );

  test('normalizes the URL before hashing', () async {
    final stores = <Map<String, Object?>>[];
    // protocol-relative input must hash the same as its https form
    await build(downloadResult: bytes, stores: stores).resolve(
      '//p1.music.126.net/a.jpg',
    );
    expect(
      stores.single['urlHash'],
      sha1.convert(utf8.encode(url)).toString(),
    );
  });

  test('serves a cache hit without downloading', () async {
    final downloads = <String>[];
    final result = await build(
      hit: '/cache/hit.jpg',
      downloads: downloads,
    ).resolve(url);
    expect(result, '/cache/hit.jpg');
    expect(downloads, isEmpty);
  });

  test('downloads, validates and stores on a miss', () async {
    final stores = <Map<String, Object?>>[];
    final result = await build(
      downloadResult: bytes,
      stores: stores,
    ).resolve(url);
    expect(result, isNotNull);
    expect(stores.single['bytes'], bytes);
    expect(
      stores.single['urlHash'],
      sha1.convert(utf8.encode(url)).toString(),
    );
    expect(
      stores.single['contentHash'],
      sha1.convert(bytes).toString(),
    );
  });

  test('rejects non-image bytes without storing', () async {
    final stores = <Map<String, Object?>>[];
    final result = await build(
      downloadResult: bytes,
      isImage: false,
      stores: stores,
    ).resolve(url);
    expect(result, isNull);
    expect(stores, isEmpty);
  });

  test('returns null when the download fails', () async {
    expect(await build(downloadResult: null).resolve(url), isNull);
  });

  test('de-duplicates concurrent resolves of the same URL', () async {
    var downloads = 0;
    final cache = RemoteCoverCache(
      lookupPath: (_) async => null,
      download: (_) async {
        downloads++;
        await Future<void>.delayed(const Duration(milliseconds: 10));
        return bytes;
      },
      store:
          ({required String urlHash, required String contentHash, required bytes}) async =>
              '/cache/$contentHash.jpg',
      isImage: (_) => true,
    );

    await Future.wait(<Future<String?>>[cache.resolve(url), cache.resolve(url)]);

    expect(downloads, 1);
  });

  test('returns null for a blank/unresolvable url', () async {
    expect(await build(downloadResult: bytes).resolve(''), isNull);
    expect(
      await build(downloadResult: bytes).resolve('ftp://example.com/a.jpg'),
      isNull,
    );
  });
}
