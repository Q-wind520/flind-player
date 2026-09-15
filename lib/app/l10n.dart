import 'package:flutter/widgets.dart';

import 'package:flind_player/l10n/app_localizations.dart';

/// Supported locales in fallback order: English, then Simplified Chinese.
const List<Locale> appSupportedLocales = <Locale>[Locale('en'), Locale('zh')];

/// Resolves [locale] to a supported one, falling back to English.
Locale resolveAppLocale(Locale locale) => switch (locale.languageCode) {
  'zh' => const Locale('zh'),
  _ => const Locale('en'),
};

/// The [AppLocalizations] for [locale], resolved against
/// [appSupportedLocales] so unsupported locales fall back to English.
AppLocalizations l10nForLocale(Locale locale) =>
    lookupAppLocalizations(resolveAppLocale(locale));
