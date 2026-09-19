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

import 'package:flind_player/shared/cover_image.dart';

void main() {
  testWidgets('48 logical px at DPR 1.0 produces cacheWidth 48', (
    WidgetTester tester,
  ) async {
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      MediaQuery(
        data: const MediaQueryData(devicePixelRatio: 1.0),
        child: CoverImage(path: '/test/cover.jpg', size: 48),
      ),
    );

    final image = tester.widget<Image>(find.byType(Image));
    final provider = image.image;
    expect(provider, isA<ResizeImage>());
    expect((provider as ResizeImage).width, 48);
  });

  testWidgets('48 logical px at DPR 3.0 produces cacheWidth 144', (
    WidgetTester tester,
  ) async {
    tester.view.devicePixelRatio = 3.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      MediaQuery(
        data: const MediaQueryData(devicePixelRatio: 3.0),
        child: CoverImage(path: '/test/cover.jpg', size: 48),
      ),
    );

    final image = tester.widget<Image>(find.byType(Image));
    final provider = image.image;
    expect(provider, isA<ResizeImage>());
    expect((provider as ResizeImage).width, 144);
  });

  testWidgets('infinite size uses LayoutBuilder to derive cacheWidth', (
    WidgetTester tester,
  ) async {
    tester.view.devicePixelRatio = 2.0;
    tester.view.physicalSize = const Size(400, 400);
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Center(
            child: SizedBox(
              width: 200,
              height: 200,
              child: CoverImage(
                path: '/test/cover.jpg',
                size: double.infinity,
              ),
            ),
          ),
        ),
      ),
    );

    final image = tester.widget<Image>(find.byType(Image));
    final provider = image.image;
    expect(provider, isA<ResizeImage>());
    // 200 logical px * 2.0 DPR = 400 physical px
    expect((provider as ResizeImage).width, 400);
  });

  testWidgets('network url at DPR 1.0 produces cacheWidth 48', (
    WidgetTester tester,
  ) async {
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      MediaQuery(
        data: const MediaQueryData(devicePixelRatio: 1.0),
        child: CoverImage(url: 'https://example.com/cover.jpg', size: 48),
      ),
    );

    final image = tester.widget<Image>(find.byType(Image));
    final provider = image.image;
    expect(provider, isA<ResizeImage>());
    final resize = provider as ResizeImage;
    expect(resize.width, 48);
    expect(resize.imageProvider, isA<NetworkImage>());
    expect(
      (resize.imageProvider as NetworkImage).url,
      'https://example.com/cover.jpg',
    );
  });

  testWidgets('network url at DPR 3.0 produces cacheWidth 144', (
    WidgetTester tester,
  ) async {
    tester.view.devicePixelRatio = 3.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      MediaQuery(
        data: const MediaQueryData(devicePixelRatio: 3.0),
        child: CoverImage(url: 'https://example.com/cover.jpg', size: 48),
      ),
    );

    final image = tester.widget<Image>(find.byType(Image));
    final provider = image.image;
    expect(provider, isA<ResizeImage>());
    expect((provider as ResizeImage).width, 144);
  });

  testWidgets('path takes priority over url when both are provided', (
    WidgetTester tester,
  ) async {
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      MediaQuery(
        data: const MediaQueryData(devicePixelRatio: 1.0),
        child: CoverImage(
          path: '/test/cover.jpg',
          url: 'https://example.com/cover.jpg',
          size: 48,
        ),
      ),
    );

    final image = tester.widget<Image>(find.byType(Image));
    final resize = image.image as ResizeImage;
    expect(resize.imageProvider, isA<FileImage>());
  });

  testWidgets('no path and no url renders an empty placeholder', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      const MediaQuery(
        data: MediaQueryData(),
        child: CoverImage(size: 48),
      ),
    );

    expect(find.byType(Image), findsNothing);
    expect(find.byType(SizedBox), findsOneWidget);
    final placeholder = tester.widget<SizedBox>(find.byType(SizedBox));
    expect(placeholder.width, 0);
    expect(placeholder.height, 0);
  });

  testWidgets('no source uses the errorBuilder output when provided', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      Directionality(
        textDirection: TextDirection.ltr,
        child: MediaQuery(
          data: const MediaQueryData(),
          child: CoverImage(
            size: 48,
            errorBuilder: (context, error, stackTrace) => Text('$error'),
          ),
        ),
      ),
    );

    expect(find.text('No cover'), findsOneWidget);
    expect(find.byType(Image), findsNothing);
  });
}
