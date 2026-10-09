// Flind Player - cross-platform music player
// Copyright (C) 2026 top.qwind.app
//
// This program is free software: you can redistribute it and/or modify
// it under the terms of the GNU General Public License as published by
// the Free Software Foundation, version 3 of the License.

import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';

import 'package:flind_player/core/models/track.dart';
import 'package:flind_player/core/sources/source_track_id.dart';
import 'package:flind_player/data/services/cover_original_resolver.dart';

final _jpeg = Uint8List.fromList(<int>[0xFF, 0xD8, 0xFF, 0xE0, 0, 0, 0, 0]);
final _png = Uint8List.fromList(<int>[0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A]);

Track _track({String? coverUrl, String? coverPath, String? artist}) => Track(
  source: 'local',
  sourceTrackId: const LocalTrackId('/music/a.mp3'),
  uri: 'local:/music/a.mp3',
  title: 'Title',
  artist: artist,
  coverUrl: coverUrl,
  coverPath: coverPath,
);

void main() {
  test('fetches the original from the remote url first', () async {
    final resolver = CoverOriginalResolver(
      fetchRemote: (url) async => _png,
      readLocal: (path) async => _jpeg,
    );

    final original = await resolver.resolve(
      _track(coverUrl: 'https://x/y.jpg', coverPath: '/c/a.jpg'),
    );

    expect(original, isNotNull);
    expect(original!.bytes, _png);
    expect(original.mimeType, 'image/png');
    expect(original.suggestedName, 'Title.png');
  });

  test('falls back to the local file when the remote fetch fails', () async {
    final resolver = CoverOriginalResolver(
      fetchRemote: (url) async => null,
      readLocal: (path) async => _jpeg,
    );

    final original = await resolver.resolve(
      _track(coverUrl: 'https://x/y.jpg', coverPath: '/c/a.jpg'),
    );

    expect(original, isNotNull);
    expect(original!.mimeType, 'image/jpeg');
  });

  test('returns null when there is no cover at all', () async {
    final resolver = CoverOriginalResolver(
      fetchRemote: (url) async => _jpeg,
      readLocal: (path) async => _jpeg,
    );

    expect(await resolver.resolve(_track()), isNull);
  });

  test('sniffs common image types and defaults to jpeg', () {
    expect(sniffImageMime(_png), 'image/png');
    expect(sniffImageMime(_jpeg), 'image/jpeg');
    expect(sniffImageMime(Uint8List.fromList(<int>[1, 2, 3])), 'image/jpeg');
  });

  test('builds a filesystem-safe suggested name', () {
    final name = suggestedCoverName(
      _track(artist: 'A/B:C*D'),
      'image/jpeg',
    );
    expect(name, 'A_B_C_D - Title.jpg');
  });
}
