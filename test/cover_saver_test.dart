// Flind Player - cross-platform music player
// Copyright (C) 2026 top.qwind.app
//
// This program is free software: you can redistribute it and/or modify
// it under the terms of the GNU General Public License as published by
// the Free Software Foundation, version 3 of the License.

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:flind_player/data/providers/cover_providers.dart';
import 'package:flind_player/data/services/cover_saver.dart';

void main() {
  test('selects the album saver on mobile', () {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    try {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      expect(container.read(coverSaverProvider), isA<AlbumCoverSaver>());
    } finally {
      debugDefaultTargetPlatformOverride = null;
    }
  });

  test('selects the file saver on desktop', () {
    debugDefaultTargetPlatformOverride = TargetPlatform.linux;
    try {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      expect(container.read(coverSaverProvider), isA<FileCoverSaver>());
    } finally {
      debugDefaultTargetPlatformOverride = null;
    }
  });
}
