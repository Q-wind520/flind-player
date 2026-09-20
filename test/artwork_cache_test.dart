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

import 'dart:io';
import 'dart:typed_data';

import 'package:audio_metadata_reader/audio_metadata_reader.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;

import 'package:flind_player/data/sources/local/artwork_cache.dart';

void main() {
  late Directory root;
  late Directory covers;
  late ArtworkCache cache;

  final fixture = File('test/fixtures/tone.mp3');

  setUp(() {
    root = Directory.systemTemp.createTempSync('flind_artwork');
    covers = Directory('${root.path}/covers')..createSync(recursive: true);
    cache = ArtworkCache(baseDir: covers);
  });

  tearDown(() {
    if (root.existsSync()) {
      root.deleteSync(recursive: true);
    }
  });

  /// A small red PNG used as the embedded front cover.
  Uint8List redPng() {
    final image = img.Image(width: 8, height: 8);
    img.fill(image, color: img.ColorRgb8(200, 30, 30));
    return Uint8List.fromList(img.encodePng(image));
  }

  /// Copies the tone fixture and embeds a small red PNG front cover.
  File withEmbeddedArt(String name) {
    final file = File('${root.path}/$name')..createSync(recursive: true);
    fixture.copySync(file.path);

    final png = redPng();
    updateMetadata(file, (metadata) {
      metadata.setPictures([Picture(png, 'image/png', PictureType.coverFront)]);
    });
    return file;
  }

  /// Copies the tone fixture without touching its (coverless) tags.
  File withoutArt(String name) {
    final file = File('${root.path}/$name')..createSync(recursive: true);
    fixture.copySync(file.path);
    return file;
  }

  test('caches embedded art verbatim and dedupes repeated calls', () async {
    final file = withEmbeddedArt('song.mp3');
    final expected = redPng();

    final first = await cache.cacheFromFile(file.path);
    final second = await cache.cacheFromFile(file.path);

    expect(first, isNotNull);
    expect(first, endsWith('.png'));
    expect(second, first);
    expect(File(first!).readAsBytesSync(), expected);
    expect(
      covers.listSync().whereType<File>(),
      hasLength(1),
      reason: 'the same picture must not be written twice',
    );
  });

  test(
    'stores a JPEG picture under a .jpg name with its original bytes',
    () async {
      final file = File('${root.path}/jpeg-song.mp3')
        ..createSync(recursive: true);
      fixture.copySync(file.path);

      final image = img.Image(width: 16, height: 16);
      img.fill(image, color: img.ColorRgb8(10, 200, 90));
      final jpeg = Uint8List.fromList(img.encodeJpg(image));
      updateMetadata(file, (metadata) {
        metadata.setPictures([
          Picture(jpeg, 'image/jpeg', PictureType.coverFront),
        ]);
      });

      final path = await cache.cacheFromFile(file.path);

      expect(path, isNotNull);
      expect(path, endsWith('.jpg'));
      expect(File(path!).readAsBytesSync(), jpeg);
    },
  );

  test('returns null when the file has no embedded art', () async {
    final file = withoutArt('plain.mp3');

    expect(await cache.cacheFromFile(file.path), isNull);
    expect(covers.listSync().whereType<File>(), isEmpty);
  });

  test('returns null for a missing file', () async {
    expect(await cache.cacheFromFile('${root.path}/nope.mp3'), isNull);
  });

  test(
    'sizeInBytes reports cached bytes and clear empties the cache',
    () async {
      final file = withEmbeddedArt('song.mp3');
      final path = await cache.cacheFromFile(file.path);

      expect(path, isNotNull);
      expect(await cache.sizeInBytes(), greaterThan(0));

      await cache.clear();

      expect(await cache.sizeInBytes(), 0);
      expect(File(path!).existsSync(), isFalse);
      expect(covers.existsSync(), isTrue);
    },
  );
}
