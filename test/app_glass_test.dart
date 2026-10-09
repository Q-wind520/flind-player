// Flind Player - cross-platform music player
// Copyright (C) 2026 top.qwind.app
//
// This program is free software: you can redistribute it and/or modify
// it under the terms of the GNU General Public License as published by
// the Free Software Foundation, version 3 of the License.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:flind_player/app/theme/app_tokens.dart';

void main() {
  test('blur sigma is the documented moderate value', () {
    expect(AppGlass.blurSigma, 14);
  });

  test('the tint is translucent and heavier in light than dark', () {
    final light = ColorScheme.fromSeed(seedColor: const Color(0xFF1BA784));
    final dark = ColorScheme.fromSeed(
      seedColor: const Color(0xFF1BA784),
      brightness: Brightness.dark,
    );
    expect(AppGlass.tintOn(light).a, closeTo(0.72, 0.001));
    expect(AppGlass.tintOn(dark).a, closeTo(0.62, 0.001));
  });

  test('the top edge is a hairline on the top side only', () {
    final scheme = ColorScheme.fromSeed(seedColor: const Color(0xFF1BA784));
    final border = AppGlass.topEdgeOn(scheme);
    expect(border.top.width, 1);
    expect(border.bottom, BorderSide.none);
    expect(border.left, BorderSide.none);
    expect(border.right, BorderSide.none);
  });

  test('the shared shadow is a soft downward shadow', () {
    expect(AppGlass.shadow, hasLength(1));
    final shadow = AppGlass.shadow.single;
    expect(shadow.blurRadius, 18);
    expect(shadow.offset, const Offset(0, 6));
  });
}
