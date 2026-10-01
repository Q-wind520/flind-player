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

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:flind_player/data/sources/bilibili/rate_limiter.dart';
import 'package:flind_player/data/sources/netease/netease_api.dart';
import 'package:flind_player/data/sources/netease/netease_client.dart';
import 'package:flind_player/data/sources/netease/netease_source.dart';

/// Shared, configured Dio wrapper for `music.163.com`.
final neteaseClientProvider = Provider<NeteaseClient>((ref) => NeteaseClient());

/// Pacers NetEase requests (search, stream URL, lyrics).
///
/// NetEase is less hostile than Bilibili: a short jittered interval and retries
/// on transient failures; a login-required response is surfaced immediately.
final neteaseRateLimiterProvider = Provider<RateLimiter>((ref) {
  return RateLimiter(
    minInterval: const Duration(milliseconds: 300),
    maxInterval: const Duration(seconds: 1),
    isRetryable: (error) =>
        error is NeteaseApiException && error.code != -462 ||
        error is SocketException ||
        error is TimeoutException ||
        error is DioException,
  );
});

/// Typed NetEase endpoint client.
final neteaseApiProvider = Provider<NeteaseApi>(
  (ref) => NeteaseApi(
    client: ref.watch(neteaseClientProvider),
    rateLimiter: ref.watch(neteaseRateLimiterProvider),
  ),
);

/// NetEase as a searchable, streamable, lyrics-capable source.
final neteaseSourceProvider = Provider<NeteaseSource>(
  (ref) => NeteaseSource(api: ref.watch(neteaseApiProvider)),
);
