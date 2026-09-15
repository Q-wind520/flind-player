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

import 'dart:async';
import 'dart:io';

import 'package:flind_player/data/cache/download_manager.dart';
import 'package:flind_player/data/sources/bilibili/bili_client.dart';
import 'package:flind_player/l10n/app_localizations.dart';

/// Maps an arbitrary [error] to a short, user-facing message in [l10n].
///
/// Bilibili codes follow `docs/bilibili-source.md` §6:
///
/// * `-412` / `-509` / `-799` are rate limits,
/// * `-352` is the risk-control block,
/// * `-101` means the request needs a logged-in account.
///
/// Never returns a raw stack trace: anything unrecognised falls back to a
/// generic message.
String describeError(AppLocalizations l10n, Object error) {
  if (error is BiliApiException) {
    return switch (error.code) {
      -412 || -509 || -799 => l10n.errRateLimited,
      -352 => l10n.errRiskControl,
      -101 => l10n.errLoginRequired,
      _ => l10n.errBiliApi(error.code),
    };
  }
  if (error is CacheCapacityException) {
    final bytes = error.bytes;
    return bytes == null
        ? l10n.errCacheFullManual
        : l10n.errCacheFullTrack(bytes);
  }
  if (error is SocketException ||
      error is HttpException ||
      error is TimeoutException) {
    return l10n.errNetwork;
  }
  if (error is FormatException) {
    return l10n.errDataFormat;
  }
  // StateError / UnsupportedError messages are written for developers but are
  // still the most useful text available for these programming-level faults.
  if (error is UnsupportedError) {
    final message = error.message;
    return (message == null || message.isEmpty) ? l10n.errGeneric : message;
  }
  if (error is StateError) {
    return error.message.isEmpty ? l10n.errGeneric : error.message;
  }
  return l10n.errGeneric;
}
