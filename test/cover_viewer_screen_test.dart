// Flind Player - cross-platform music player
// Copyright (C) 2026 top.qwind.app
//
// This program is free software: you can redistribute it and/or modify
// it under the terms of the GNU General Public License as published by
// the Free Software Foundation, version 3 of the License.

import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:flind_player/core/models/track.dart';
import 'package:flind_player/core/sources/source_track_id.dart';
import 'package:flind_player/data/providers/cover_providers.dart';
import 'package:flind_player/data/services/cover_original_resolver.dart';
import 'package:flind_player/data/services/cover_saver.dart';
import 'package:flind_player/features/player/cover_viewer_screen.dart';
import 'package:flind_player/l10n/app_localizations.dart';

import 'support/l10n.dart';

/// A valid 1×1 PNG so the viewer's `Image.memory` decodes without an error.
final _png = base64Decode(
  'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mNkYPhfDwAChwGA60e6kgAAAABJRU5ErkJggg==',
);

Track _track() => Track(
  source: 'local',
  sourceTrackId: const LocalTrackId('/music/a.mp3'),
  uri: 'local:/music/a.mp3',
  title: 'Title',
  coverUrl: 'https://x/y.png',
);

class _FakeSaver implements CoverSaver {
  _FakeSaver(this.result);
  final CoverSaveResult result;
  int calls = 0;
  @override
  Future<CoverSaveResult> save(CoverOriginal original) async {
    calls++;
    return result;
  }
}

Widget _app({
  required CoverOriginalResolver resolver,
  required CoverSaver saver,
}) => ProviderScope(
  overrides: [
    coverOriginalResolverProvider.overrideWithValue(resolver),
    coverSaverProvider.overrideWithValue(saver),
  ],
  child: localizedApp(CoverViewerScreen(track: _track())),
);

void main() {
  testWidgets('shows the original and saves it', (tester) async {
    final saver = _FakeSaver(CoverSaveResult.saved);
    await tester.pumpWidget(
      _app(
        resolver: CoverOriginalResolver(
          fetchRemote: (url) async => _png,
          readLocal: (path) async => _png,
        ),
        saver: saver,
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byType(Image), findsOneWidget);

    final l10n = lookupAppLocalizations(const Locale('zh'));
    await tester.tap(find.text(l10n.downloadCover));
    await tester.pumpAndSettle();

    expect(saver.calls, 1);
    expect(find.text(l10n.coverSaved), findsOneWidget);
  });

  testWidgets('shows an unavailable state and disables download', (
    tester,
  ) async {
    await tester.pumpWidget(
      _app(
        resolver: CoverOriginalResolver(
          fetchRemote: (url) async => null,
          readLocal: (path) async => null,
        ),
        saver: _FakeSaver(CoverSaveResult.saved),
      ),
    );
    await tester.pumpAndSettle();

    final l10n = lookupAppLocalizations(const Locale('zh'));
    expect(find.text(l10n.coverOriginalUnavailable), findsOneWidget);
    final button = tester.widget<TextButton>(
      find.widgetWithText(TextButton, l10n.downloadCover),
    );
    expect(button.onPressed, isNull);
  });
}
