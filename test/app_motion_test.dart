// Flind Player - cross-platform music player
// Copyright (C) 2026 top.qwind.app
//
// This program is free software: you can redistribute it and/or modify
// it under the terms of the GNU General Public License as published by
// the Free Software Foundation, version 3 of the License.

import 'package:flutter/animation.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:flind_player/app/theme/app_tokens.dart';

void main() {
  test('motion durations follow the fast/standard/emphasized scale', () {
    expect(AppMotion.fast, const Duration(milliseconds: 150));
    expect(AppMotion.standard, const Duration(milliseconds: 250));
    expect(AppMotion.emphasized, const Duration(milliseconds: 400));
  });

  test('motion curves are the documented easing', () {
    expect(AppMotion.standardCurve, Curves.easeInOutCubic);
    expect(AppMotion.emphasizedCurve, Curves.easeOutCubic);
  });
}
