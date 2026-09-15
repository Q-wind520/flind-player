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

import 'package:flutter_test/flutter_test.dart';

import 'package:flind_player/data/sources/bilibili/bili_client.dart';
import 'package:flind_player/shared/error_messages.dart';

import 'support/l10n.dart';

void main() {
  final l10n = testL10n();

  group('describeError: Bilibili codes', () {
    test('-412 / -509 / -799 map to the rate-limit hint', () {
      for (final code in const [-412, -509, -799]) {
        expect(
          describeError(l10n, BiliApiException.fromCode(code)),
          '请求过于频繁，请稍后再试',
          reason: 'code $code',
        );
      }
    });

    test('-352 maps to the risk-control hint', () {
      expect(describeError(l10n, BiliApiException.fromCode(-352)), '触发风控，请稍后再试');
    });

    test('-101 maps to the login hint', () {
      expect(describeError(l10n, BiliApiException.fromCode(-101)), '需要登录');
    });

    test('an unknown code is included in a readable sentence', () {
      final message = describeError(l10n, const BiliApiException(-999, 'boom'));
      expect(message, contains('-999'));
      expect(message, isNot(contains('boom')));
    });
  });

  group('describeError: network failures', () {
    test('SocketException maps to the network hint', () {
      expect(describeError(l10n, const SocketException('failed')), '网络连接失败，请检查网络');
    });

    test('HttpException maps to the network hint', () {
      expect(describeError(l10n, HttpException('failed')), '网络连接失败，请检查网络');
    });

    test('TimeoutException maps to the network hint', () {
      expect(describeError(l10n, TimeoutException('failed')), '网络连接失败，请检查网络');
    });
  });

  group('describeError: other errors', () {
    test('FormatException maps to the data-format hint', () {
      expect(describeError(l10n, const FormatException('bad json')), '数据格式异常');
    });

    test('UnsupportedError returns its own message', () {
      expect(describeError(l10n, UnsupportedError('no engine')), 'no engine');
    });

    test('StateError returns its own message', () {
      expect(describeError(l10n, StateError('扫描目录不可读')), '扫描目录不可读');
    });

    test('an empty StateError falls back to the generic message', () {
      expect(describeError(l10n, StateError('')), '操作失败，请重试');
    });
  });

  group('describeError: fallback', () {
    test('an unknown error never leaks its raw text', () {
      final message = describeError(l10n, Exception('secret stack detail'));
      expect(message, '操作失败，请重试');
      expect(message, isNot(contains('secret')));
    });
  });
}
