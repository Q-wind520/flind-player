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
import 'dart:math';

import 'package:flind_player/data/sources/bilibili/bili_client.dart';

/// Injectable delay primitive.
///
/// Defaults to [Future.delayed]; tests substitute a recorder so no real time
/// passes.
typedef Sleeper = Future<void> Function(Duration duration);

/// Serializes and paces Bilibili requests.
///
/// * **Single-flight** — at most one action is in flight at a time; callers are
///   queued behind each other.
/// * **Minimum interval** — every action after the first waits a jittered
///   `minInterval..maxInterval` before running (default 1–3 s, matching the
///   search pacing in `docs/bilibili-source.md` §6).
/// * **Exponential backoff** — retryable [BiliApiException] codes (`-352`,
///   `-412`, `-509`, `-799`) are retried after `2s → 4s → 8s` (capped), never
///   immediately.
///
/// Other sources can reuse this limiter by injecting their own `isRetryable`
/// predicate, which replaces the Bilibili code check entirely.
class RateLimiter {
  /// Codes that trigger exponential backoff instead of surfacing immediately.
  static const Set<int> defaultRetryableCodes = <int>{-352, -412, -509, -799};

  /// Base delay of the first backoff step.
  final Duration backoffBase;

  /// Upper bound for a single backoff step.
  final Duration maxBackoff;

  /// Lower bound of the inter-request jittered interval.
  final Duration minInterval;

  /// Upper bound of the inter-request jittered interval.
  final Duration maxInterval;

  /// Maximum number of retries after the initial attempt.
  final int maxRetries;

  /// Codes that trigger a retry.
  final Set<int> retryableCodes;

  final Sleeper _sleep;
  final Random _random;
  final bool Function(Object error)? _customIsRetryable;

  Future<void> _tail = Future<void>.value();
  int _requestCount = 0;

  RateLimiter({
    this.minInterval = const Duration(seconds: 1),
    this.maxInterval = const Duration(seconds: 3),
    this.backoffBase = const Duration(seconds: 2),
    this.maxBackoff = const Duration(seconds: 8),
    this.maxRetries = 3,
    this.retryableCodes = defaultRetryableCodes,
    Sleeper? sleeper,
    Random? random,
    bool Function(Object error)? isRetryable,
  }) : _sleep = sleeper ?? Future<void>.delayed,
       _random = random ?? Random(),
       _customIsRetryable = isRetryable;

  /// Runs [action] under the limiter, returning its result.
  ///
  /// Calls are queued: a new action does not start until every earlier action
  /// has finished (including its retries).
  Future<T> run<T>(Future<T> Function() action) {
    final completer = Completer<void>();
    final previous = _tail;
    _tail = completer.future;
    return previous
        .then((_) => _execute(action))
        .whenComplete(() => completer.complete());
  }

  Future<T> _execute<T>(Future<T> Function() action) async {
    if (_requestCount > 0 && minInterval > Duration.zero) {
      await _sleep(_jitteredInterval());
    }
    _requestCount++;

    var attempt = 0;
    while (true) {
      try {
        return await action();
      } catch (error) {
        if (!_isRetryable(error) || attempt >= maxRetries) {
          rethrow;
        }
        await _sleep(_backoffFor(attempt));
        attempt++;
      }
    }
  }

  /// Whether [error] is transient and worth retrying under backoff.
  ///
  /// A custom [isRetryable] predicate (when supplied) fully replaces the
  /// default Bilibili rule so other sources can define their own retryables.
  bool _isRetryable(Object error) {
    final custom = _customIsRetryable;
    if (custom != null) return custom(error);
    return error is BiliApiException && retryableCodes.contains(error.code);
  }

  Duration _jitteredInterval() {
    final minMs = minInterval.inMilliseconds;
    final maxMs = max(minMs, maxInterval.inMilliseconds);
    final span = maxMs - minMs;
    return Duration(
      milliseconds: minMs + (span == 0 ? 0 : _random.nextInt(span + 1)),
    );
  }

  Duration _backoffFor(int attempt) {
    final ms = backoffBase.inMilliseconds * (1 << attempt);
    return Duration(milliseconds: min(ms, maxBackoff.inMilliseconds));
  }
}
