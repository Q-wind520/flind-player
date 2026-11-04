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

import 'package:flind_player/app/theme/app_icons.dart';
import 'package:flind_player/core/models/track_sort.dart';
import 'package:flind_player/features/library/library_sort_provider.dart';
import 'package:flind_player/features/library/track_sorting.dart';
import 'package:flind_player/l10n/app_localizations.dart';

/// A header menu that switches the library sort order.
class LibrarySortMenuButton extends ConsumerWidget {
  const LibrarySortMenuButton({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final current =
        ref.watch(librarySortProvider).value ?? TrackSort.recentlyAdded;

    return PopupMenuButton<TrackSort>(
      key: const Key('library_sort_menu'),
      tooltip: l10n.menuSort,
      icon: const Icon(AppIcons.sort),
      onSelected: (sort) =>
          ref.read(librarySortProvider.notifier).setSort(sort),
      itemBuilder: (context) => [
        for (final sort in TrackSort.values)
          PopupMenuItem<TrackSort>(
            value: sort,
            child: Row(
              children: [
                SizedBox(
                  width: 24,
                  child: sort == current
                      ? const Icon(AppIcons.check, size: 18)
                      : null,
                ),
                Text(librarySortLabel(l10n, sort)),
              ],
            ),
          ),
      ],
    );
  }
}
