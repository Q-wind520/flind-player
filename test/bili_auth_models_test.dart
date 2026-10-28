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

import 'package:flutter_test/flutter_test.dart';

import 'package:flind_player/data/sources/bilibili/bili_auth_models.dart';

void main() {
  group('BiliQrStatus.fromCode', () {
    test('maps the four documented poll states', () {
      expect(BiliQrStatus.fromCode(86101), BiliQrStatus.pending);
      expect(BiliQrStatus.fromCode(86090), BiliQrStatus.scanned);
      expect(BiliQrStatus.fromCode(86038), BiliQrStatus.expired);
      expect(BiliQrStatus.fromCode(0), BiliQrStatus.success);
    });

    test('throws on an unknown state', () {
      expect(() => BiliQrStatus.fromCode(12345), throwsFormatException);
    });
  });

  test('BiliQrGenerate parses the QR url and key', () {
    final data = BiliQrGenerate.fromJson(<String, dynamic>{
      'url': 'https://account.bilibili.com/scan?qrcode_key=abc',
      'qrcode_key': 'abc',
    });

    expect(data.key, 'abc');
    expect(data.url.toString(), contains('qrcode_key=abc'));
  });

  test('BiliQrPoll reads status and cookies, and success carries token', () {
    final pending = BiliQrPoll.fromJson(<String, dynamic>{
      'code': 86101,
      'message': '',
    });
    expect(pending.status, BiliQrStatus.pending);
    expect(pending.cookies, isEmpty);

    final success = BiliQrPoll.fromJson(
      <String, dynamic>{
        'code': 0,
        'refresh_token': 'refresh',
        'timestamp': 123,
      },
      cookies: const <String, String>{'SESSDATA': 'secret'},
    );
    expect(success.status, BiliQrStatus.success);
    expect(success.cookies['SESSDATA'], 'secret');
    expect(success.refreshToken, 'refresh');
  });

  test('BiliNavAccount maps profile and upgrades an http avatar', () {
    final account = BiliNavAccount.fromJson(<String, dynamic>{
      'isLogin': true,
      'mid': 42,
      'uname': 'tester',
      'face': 'http://i0.hdslb.com/avatar.jpg',
      'vipStatus': 1,
      'vipType': 2,
    });

    expect(account.userId, '42');
    expect(account.displayName, 'tester');
    expect(account.avatarUrl, 'https://i0.hdslb.com/avatar.jpg');
    expect(account.isVip, isTrue);
    expect(account.sourceId, 'bilibili');
  });

  test('BiliNavAccount rejects a signed-out nav payload', () {
    expect(
      () => BiliNavAccount.fromJson(<String, dynamic>{'isLogin': false}),
      throwsA(isA<BiliAuthException>()),
    );
  });
}
