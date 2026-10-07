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

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:flind_player/core/models/app_theme_color.dart';
import 'package:flind_player/features/settings/theme_color_picker.dart';

import 'support/l10n.dart';

/// Hosts [showThemeColorPicker] behind a button and records its result.
Widget _host(AppThemeColor initial, void Function(AppThemeColor?) onResult) {
  return localizedApp(
    Builder(
      builder: (context) => Scaffold(
        body: Center(
          child: ElevatedButton(
            onPressed: () async =>
                onResult(await showThemeColorPicker(context, initial: initial)),
            child: const Text('open'),
          ),
        ),
      ),
    ),
  );
}

Future<void> _open(WidgetTester tester) async {
  await tester.tap(find.text('open'));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('confirming a recommended swatch returns that colour', (
    tester,
  ) async {
    AppThemeColor? result;
    await tester.pumpWidget(_host(AppThemeColor.defaults, (r) => result = r));
    await _open(tester);

    const purple = AppThemeColor(0xFF8B5CF6);
    await tester.tap(find.byKey(Key('theme-color-swatch-${purple.toHex()}')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('确定'));
    await tester.pumpAndSettle();

    expect(result, purple);
  });

  testWidgets('a typed hex colour is applied', (tester) async {
    AppThemeColor? result;
    await tester.pumpWidget(_host(AppThemeColor.defaults, (r) => result = r));
    await _open(tester);

    await tester.tap(find.byKey(const Key('theme-color-custom')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('theme-color-hex')), '#123456');
    await tester.pumpAndSettle();
    await tester.tap(find.text('确定'));
    await tester.pumpAndSettle();

    expect(result, const AppThemeColor(0xFF123456));
  });

  testWidgets('typing a hex keeps the RGB sliders in sync', (tester) async {
    await tester.pumpWidget(_host(AppThemeColor.defaults, (_) {}));
    await _open(tester);
    await tester.tap(find.byKey(const Key('theme-color-custom')));
    await tester.pumpAndSettle();

    await tester.enterText(find.byKey(const Key('theme-color-hex')), '#FF0000');
    await tester.pumpAndSettle();

    expect(
      tester
          .widget<Slider>(find.byKey(const Key('theme-color-slider-r')))
          .value,
      255,
    );
    expect(
      tester
          .widget<Slider>(find.byKey(const Key('theme-color-slider-g')))
          .value,
      0,
    );
    expect(
      tester
          .widget<Slider>(find.byKey(const Key('theme-color-slider-b')))
          .value,
      0,
    );
  });

  testWidgets('dragging a slider updates the hex field', (tester) async {
    await tester.pumpWidget(_host(AppThemeColor.defaults, (_) {}));
    await _open(tester);
    await tester.tap(find.byKey(const Key('theme-color-custom')));
    await tester.pumpAndSettle();

    await tester.enterText(find.byKey(const Key('theme-color-hex')), '#000000');
    await tester.pumpAndSettle();

    await tester.drag(
      find.byKey(const Key('theme-color-slider-g')),
      const Offset(500, 0),
    );
    await tester.pumpAndSettle();

    final field = tester.widget<TextField>(
      find.byKey(const Key('theme-color-hex')),
    );
    expect(field.controller!.text.toUpperCase(), isNot('#000000'));
    await tester.tap(find.text('确定'));
    await tester.pumpAndSettle();
  });
}
