// Flind Player - cross-platform music player
// Copyright (C) 2026 top.qwind.app
//
// This program is free software: you can redistribute it and/or modify
// it under the terms of the GNU General Public License as published by
// the Free Software Foundation, version 3 of the License.

import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:flind_player/app/theme/app_icons.dart';
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

/// A saver that stays pending until [complete] is called.
class _BlockingSaver implements CoverSaver {
  final Completer<CoverSaveResult> _completer = Completer<CoverSaveResult>();
  int calls = 0;
  @override
  Future<CoverSaveResult> save(CoverOriginal original) {
    calls++;
    return _completer.future;
  }

  void complete() => _completer.complete(CoverSaveResult.saved);
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

  testWidgets('the viewer chrome is legible on the dark scrim', (tester) async {
    await tester.pumpWidget(
      _app(
        resolver: CoverOriginalResolver(
          fetchRemote: (url) async => _png,
          readLocal: (path) async => _png,
        ),
        saver: _FakeSaver(CoverSaveResult.saved),
      ),
    );
    await tester.pumpAndSettle();

    final close = tester.widget<IconButton>(
      find.widgetWithIcon(IconButton, AppIcons.close),
    );
    expect(close.color, Colors.white);
  });

  testWidgets('ignores repeated taps while a save is in flight', (tester) async {
    final saver = _BlockingSaver();
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

    final l10n = lookupAppLocalizations(const Locale('zh'));
    await tester.tap(find.text(l10n.downloadCover));
    await tester.pump();
    await tester.tap(find.text(l10n.downloadCover), warnIfMissed: false);
    await tester.pump();

    expect(saver.calls, 1);

    saver.complete();
    await tester.pumpAndSettle();
  });

  testWidgets('stays silent when a save is cancelled', (tester) async {
    final saver = _FakeSaver(CoverSaveResult.cancelled);
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

    final l10n = lookupAppLocalizations(const Locale('zh'));
    await tester.tap(find.text(l10n.downloadCover));
    await tester.pumpAndSettle();

    expect(saver.calls, 1);
    expect(find.byType(SnackBar), findsNothing);
  });

  testWidgets('reports a failure when a save fails', (tester) async {
    await tester.pumpWidget(
      _app(
        resolver: CoverOriginalResolver(
          fetchRemote: (url) async => _png,
          readLocal: (path) async => _png,
        ),
        saver: _FakeSaver(CoverSaveResult.failed),
      ),
    );
    await tester.pumpAndSettle();

    final l10n = lookupAppLocalizations(const Locale('zh'));
    await tester.tap(find.text(l10n.downloadCover));
    await tester.pumpAndSettle();

    expect(find.text(l10n.coverSaveFailed), findsOneWidget);
  });
}
