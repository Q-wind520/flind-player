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

import 'package:flind_player/l10n/app_localizations.dart';
import 'package:flind_player/shared/error_messages.dart';

/// Shows [error]'s user-facing message in a [SnackBar].
///
/// When [onRetry] is supplied the snack bar carries a retry action. If no
/// [ScaffoldMessenger] is in scope this is a no-op, so callers never have to
/// guard against a missing messenger.
void showErrorSnackBar(
  BuildContext context,
  Object error, {
  VoidCallback? onRetry,
}) {
  final messenger = ScaffoldMessenger.maybeOf(context);
  if (messenger == null) return;
  final l10n = AppLocalizations.of(context);
  messenger.showSnackBar(
    SnackBar(
      content: Text(describeError(l10n, error)),
      action: onRetry == null
          ? null
          : SnackBarAction(label: l10n.retry, onPressed: onRetry),
    ),
  );
}
