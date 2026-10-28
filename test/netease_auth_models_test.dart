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

import 'package:flind_player/core/auth/auth_exception.dart';
import 'package:flind_player/data/sources/netease/netease_auth_models.dart';

void main() {
  test('NeteaseQrStatus.fromCode maps the four poll states', () {
    expect(NeteaseQrStatus.fromCode(800), NeteaseQrStatus.expired);
    expect(NeteaseQrStatus.fromCode(801), NeteaseQrStatus.pending);
    expect(NeteaseQrStatus.fromCode(802), NeteaseQrStatus.scanned);
    expect(NeteaseQrStatus.fromCode(803), NeteaseQrStatus.success);
    expect(() => NeteaseQrStatus.fromCode(999), throwsFormatException);
  });

  test('NeteaseQrGenerate parses the unikey', () {
    final data = NeteaseQrGenerate.fromJson(<String, dynamic>{
      'code': 200,
      'unikey': 'abc',
    });

    expect(data.unikey, 'abc');
  });

  test('NeteaseQrGenerate rejects a response without a key', () {
    expect(
      () => NeteaseQrGenerate.fromJson(<String, dynamic>{'code': 200}),
      throwsA(isA<AuthException>()),
    );
  });

  test('NeteaseQrPoll carries status and cookies', () {
    final poll = NeteaseQrPoll.fromJson(
      <String, dynamic>{'code': 803, 'message': 'ok'},
      cookies: const <String, String>{'MUSIC_U': 'token', '__csrf': 'csrf'},
    );

    expect(poll.status, NeteaseQrStatus.success);
    expect(poll.cookies['MUSIC_U'], 'token');
  });

  test('NeteaseProfile maps the account and upgrades an http avatar', () {
    final profile = NeteaseProfile.fromJson(<String, dynamic>{
      'profile': <String, dynamic>{
        'userId': 42,
        'nickname': 'tester',
        'avatarUrl': 'http://p1.music.126.net/avatar.jpg',
        'vipType': 11,
      },
    });

    expect(profile.account.sourceId, 'netease');
    expect(profile.account.userId, '42');
    expect(profile.account.displayName, 'tester');
    expect(profile.account.avatarUrl, 'https://p1.music.126.net/avatar.jpg');
    expect(profile.account.isVip, isTrue);
  });

  test('NeteaseProfile rejects a response without a profile', () {
    expect(
      () => NeteaseProfile.fromJson(<String, dynamic>{'code': 301}),
      throwsA(
        isA<AuthException>().having(
          (error) => error.kind,
          'kind',
          AuthFailure.expired,
        ),
      ),
    );
  });
}
