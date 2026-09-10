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

import 'package:flutter_test/flutter_test.dart';

import 'package:flind_player/data/sources/bilibili/bili_client.dart';
import 'package:flind_player/data/sources/bilibili/rate_limiter.dart';

void main() {
  group('RateLimiter single-flight', () {
    test('never runs two actions concurrently', () async {
      final delays = <Duration>[];
      final limiter = RateLimiter(
        minInterval: Duration.zero,
        maxInterval: Duration.zero,
        sleeper: (d) async => delays.add(d),
      );

      var active = 0;
      var maxActive = 0;
      final gate = Completer<void>();

      Future<String> action() async {
        active++;
        maxActive = max(maxActive, active);
        if (active == 1) await gate.future;
        active--;
        return 'done';
      }

      final first = limiter.run(action);
      final second = limiter.run(action);
      await Future<void>.delayed(Duration.zero);

      expect(active, 1, reason: 'the second action must wait for the first');
      expect(maxActive, 1);

      gate.complete();
      final results = await Future.wait(<Future<String>>[first, second]);

      expect(results, <String>['done', 'done']);
      expect(maxActive, 1);
      expect(active, 0);
    });
  });

  group('RateLimiter minimum interval', () {
    test('skips the interval for the first request only', () async {
      final delays = <Duration>[];
      final limiter = RateLimiter(
        minInterval: const Duration(seconds: 2),
        maxInterval: const Duration(seconds: 2),
        sleeper: (d) async => delays.add(d),
      );

      await limiter.run(() async => 1);
      await limiter.run(() async => 2);
      await limiter.run(() async => 3);

      expect(delays, <Duration>[
        const Duration(seconds: 2),
        const Duration(seconds: 2),
      ]);
    });

    test('keeps jitter within [minInterval, maxInterval]', () async {
      final delays = <Duration>[];
      final limiter = RateLimiter(
        minInterval: const Duration(seconds: 1),
        maxInterval: const Duration(seconds: 3),
        sleeper: (d) async => delays.add(d),
        random: Random(7),
      );

      for (var i = 0; i < 20; i++) {
        await limiter.run(() async => i);
      }

      expect(delays, hasLength(19));
      for (final delay in delays) {
        expect(delay >= const Duration(seconds: 1), isTrue);
        expect(delay <= const Duration(seconds: 3), isTrue);
      }
    });
  });

  group('RateLimiter backoff', () {
    test('retries -352 with 2s then 4s, then succeeds', () async {
      final delays = <Duration>[];
      final limiter = RateLimiter(
        minInterval: Duration.zero,
        maxInterval: Duration.zero,
        sleeper: (d) async => delays.add(d),
      );

      var calls = 0;
      final result = await limiter.run(() async {
        calls++;
        if (calls < 3) {
          throw const BiliApiException(-352, 'risk control');
        }
        return 'ok';
      });

      expect(result, 'ok');
      expect(calls, 3);
      expect(delays, <Duration>[
        const Duration(seconds: 2),
        const Duration(seconds: 4),
      ]);
    });

    test('caps the backoff at maxBackoff', () async {
      final delays = <Duration>[];
      final limiter = RateLimiter(
        minInterval: Duration.zero,
        maxInterval: Duration.zero,
        maxBackoff: const Duration(seconds: 8),
        maxRetries: 4,
        sleeper: (d) async => delays.add(d),
      );

      await expectLater(
        limiter.run<void>(() async {
          throw const BiliApiException(-412, 'ip blocked');
        }),
        throwsA(isA<BiliApiException>()),
      );

      expect(delays, <Duration>[
        const Duration(seconds: 2),
        const Duration(seconds: 4),
        const Duration(seconds: 8),
        const Duration(seconds: 8),
      ]);
    });

    test('does not retry non-retryable codes', () async {
      final delays = <Duration>[];
      final limiter = RateLimiter(
        minInterval: Duration.zero,
        maxInterval: Duration.zero,
        sleeper: (d) async => delays.add(d),
      );

      var calls = 0;
      await expectLater(
        limiter.run<void>(() async {
          calls++;
          throw const BiliApiException(-101, 'not logged in');
        }),
        throwsA(isA<BiliApiException>().having((e) => e.code, 'code', -101)),
      );

      expect(calls, 1);
      expect(delays, isEmpty);
    });

    test('stops retrying once maxRetries is reached', () async {
      final delays = <Duration>[];
      final limiter = RateLimiter(
        minInterval: Duration.zero,
        maxInterval: Duration.zero,
        maxRetries: 2,
        sleeper: (d) async => delays.add(d),
      );

      var calls = 0;
      await expectLater(
        limiter.run<void>(() async {
          calls++;
          throw const BiliApiException(-352, 'risk control');
        }),
        throwsA(isA<BiliApiException>()),
      );

      expect(calls, 3, reason: 'initial attempt + 2 retries');
      expect(delays, <Duration>[
        const Duration(seconds: 2),
        const Duration(seconds: 4),
      ]);
    });
  });
}
