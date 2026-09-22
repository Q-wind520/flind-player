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
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:flind_player/app/app_scroll_behavior.dart';
import 'package:flind_player/app/l10n.dart';
import 'package:flind_player/app/language.dart';
import 'package:flind_player/app/theme/app_theme.dart';
import 'package:flind_player/app/theme_mode.dart';
import 'package:flind_player/core/models/app_language.dart';
import 'package:flind_player/core/models/app_theme_mode.dart';
import 'package:flind_player/data/providers/cover_providers.dart';
import 'package:flind_player/features/home/home_shell.dart';
import 'package:flind_player/l10n/app_localizations.dart';

/// Root application widget.
class FlindApp extends ConsumerWidget {
  const FlindApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Keep the queue cover-prefetch coordinator alive for the whole session.
    ref.watch(coverPrefetchCoordinatorProvider);

    final language =
        ref.watch(appLanguageProvider).value ?? AppLanguage.system;
    final themeMode =
        ref.watch(appThemeModeProvider).value ?? AppThemeMode.system;
    return MaterialApp(
      locale: localeForAppLanguage(language),
      onGenerateTitle: (context) => AppLocalizations.of(context).appName,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: appSupportedLocales,
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      themeMode: themeModeForAppThemeMode(themeMode),
      // Lets the mouse/trackpad drag scrollables (e.g. the library's section
      // pager) on desktop, where Flutter's default behaviour excludes them.
      scrollBehavior: const AppScrollBehavior(),
      debugShowCheckedModeBanner: false,
      home: const HomeShell(),
    );
  }
}
