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
import 'package:flind_player/l10n/app_localizations.dart';
import 'package:flind_player/shared/empty_state.dart';

/// Consistent loading / error / empty / data rendering for an [AsyncValue].
///
/// Pages still own the actual empty-state copy because only the page knows
/// what an empty result means. This widget owns the shared loading and error
/// chrome, including the retry affordance.
class AppAsyncView<T> extends StatelessWidget {
  const AppAsyncView({
    super.key,
    required this.value,
    required this.data,
    this.isEmpty,
    this.empty,
    this.loading,
    this.errorBuilder,
    this.onRetry,
    this.errorTitle,
  });

  final AsyncValue<T> value;
  final Widget Function(T data) data;
  final bool Function(T data)? isEmpty;
  final Widget? empty;
  final Widget? loading;
  final Widget Function(Object error, StackTrace stackTrace)? errorBuilder;
  final VoidCallback? onRetry;
  final String? errorTitle;

  @override
  Widget build(BuildContext context) {
    return value.when(
      loading: () => loading ?? const Center(child: CircularProgressIndicator()),
      error: (error, stackTrace) =>
          errorBuilder?.call(error, stackTrace) ?? AppErrorState(
            title: errorTitle,
            onRetry: onRetry,
          ),
      data: (value) {
        if (isEmpty?.call(value) == true && empty != null) {
          return empty!;
        }
        return data(value);
      },
    );
  }
}

/// The shared error panel: an error glyph, a short title, the optional detail,
/// and a retry button when [onRetry] is provided.
class AppErrorState extends StatelessWidget {
  const AppErrorState({
    super.key,
    required this.onRetry,
    this.title,
    this.detail,
  });

  final VoidCallback? onRetry;
  final String? title;
  final String? detail;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return EmptyState(
      icon: AppIcons.error,
      title: title ?? l10n.loadFailed,
      message: detail,
      action: onRetry == null
          ? null
          : FilledButton.tonalIcon(
              onPressed: onRetry,
              icon: const Icon(AppIcons.refresh, size: 18),
              label: Text(l10n.retry),
            ),
    );
  }
}
