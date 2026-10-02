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
