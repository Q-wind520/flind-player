import 'package:flutter/material.dart';

import 'package:flind_player/app/l10n.dart';
import 'package:flind_player/l10n/app_localizations.dart';

/// The [AppLocalizations] for [locale] (Simplified Chinese by default).
AppLocalizations testL10n([Locale locale = const Locale('zh')]) =>
    lookupAppLocalizations(locale);

/// Wraps [child] in a [MaterialApp] wired to the app's localization delegates
/// so widgets that call `AppLocalizations.of(context)` work under test.
Widget localizedApp(Widget child, {Locale locale = const Locale('zh')}) =>
    MaterialApp(
      locale: locale,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: appSupportedLocales,
      home: child,
    );
