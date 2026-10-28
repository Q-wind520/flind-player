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

import 'package:flind_player/core/auth/auth_session.dart';
import 'package:flind_player/data/auth/auth_cookie_jar.dart';
import 'package:flind_player/data/auth/set_cookie_parser.dart';

void main() {
  group('AuthSession', () {
    final account = AuthAccount(
      sourceId: 'bilibili',
      userId: '42',
      displayName: 'tester',
      avatarUrl: 'https://example.com/avatar.jpg',
      isVip: true,
    );
    final signedInAt = DateTime.utc(2026, 10, 28, 12);
    final expiresAt = DateTime.utc(2027, 4, 28, 12);

    test('JSON round-trip preserves account, cookies and expiry', () {
      final session = AuthSession(
        account: account,
        cookies: const <String, String>{
          'SESSDATA': 'secret',
          'bili_jct': 'csrf',
        },
        refreshToken: 'refresh',
        signedInAt: signedInAt,
        expiresAt: expiresAt,
        lastValidatedAt: signedInAt,
      );

      final decoded = AuthSession.fromJson(session.toJson());

      expect(decoded.account.sourceId, 'bilibili');
      expect(decoded.account.userId, '42');
      expect(decoded.account.displayName, 'tester');
      expect(decoded.account.avatarUrl, 'https://example.com/avatar.jpg');
      expect(decoded.account.isVip, isTrue);
      expect(decoded.cookies, session.cookies);
      expect(decoded.refreshToken, 'refresh');
      expect(decoded.signedInAt, signedInAt);
      expect(decoded.expiresAt, expiresAt);
      expect(decoded.lastValidatedAt, signedInAt);
    });

    test('isExpiredAt is true only after expiresAt', () {
      final session = AuthSession(
        account: account,
        cookies: const <String, String>{},
        signedInAt: signedInAt,
        expiresAt: expiresAt,
      );

      expect(
        session.isExpiredAt(expiresAt.subtract(const Duration(seconds: 1))),
        isFalse,
      );
      expect(session.isExpiredAt(expiresAt), isTrue);
    });

    test('a session without expiresAt never expires by time', () {
      final session = AuthSession(
        account: account,
        cookies: const <String, String>{},
        signedInAt: signedInAt,
      );

      expect(session.isExpiredAt(DateTime.utc(2100)), isFalse);
    });
  });

  group('parseSetCookieHeaders', () {
    test('keeps cookie pairs and drops attributes', () {
      final cookies = parseSetCookieHeaders(const <String>[
        'SESSDATA=abc123; Path=/; Domain=.bilibili.com; HttpOnly; Secure; Max-Age=15552000',
        'bili_jct=csrf; Path=/',
      ]);

      expect(cookies, <String, String>{
        'SESSDATA': 'abc123',
        'bili_jct': 'csrf',
      });
    });

    test('last value wins for a repeated cookie name', () {
      final cookies = parseSetCookieHeaders(const <String>[
        'SESSDATA=old; Path=/',
        'SESSDATA=new; Path=/',
      ]);

      expect(cookies['SESSDATA'], 'new');
    });

    test(
      'splits a comma-joined Set-Cookie header without breaking Expires',
      () {
        final cookies = parseSetCookieHeaders(const <String>[
          'SESSDATA=abc; Expires=Wed, 21 Oct 2026 07:28:00 GMT; Path=/, '
              'bili_jct=csrf; Path=/',
        ]);

        expect(cookies, <String, String>{
          'SESSDATA': 'abc',
          'bili_jct': 'csrf',
        });
      },
    );

    test('ignores malformed and empty headers', () {
      final cookies = parseSetCookieHeaders(const <String>[
        '',
        'novalue',
        'empty=; Path=/',
        '=nameless',
      ]);

      expect(cookies, isEmpty);
    });
  });

  group('parseCookieHeader', () {
    test('parses a plain Cookie header and keeps empty values', () {
      final cookies = parseCookieHeader(
        'MUSIC_U=token; __csrf=csrf; deviceId=',
      );

      expect(cookies, <String, String>{
        'MUSIC_U': 'token',
        '__csrf': 'csrf',
        'deviceId': '',
      });
    });
  });

  group('AuthCookieJar', () {
    test(
      'replace exposes a merged Cookie header and merge keeps old names',
      () {
        final jar = AuthCookieJar();

        jar.replace('bilibili', const <String, String>{
          'SESSDATA': 'secret',
          'bili_jct': 'csrf',
        });
        expect(jar.cookieHeader('bilibili'), 'SESSDATA=secret; bili_jct=csrf');

        jar.merge('bilibili', const <String, String>{'bili_jct': 'new'});
        expect(jar.cookiesFor('bilibili'), <String, String>{
          'SESSDATA': 'secret',
          'bili_jct': 'new',
        });
      },
    );

    test('clear removes only the given source', () {
      final jar = AuthCookieJar()
        ..replace('bilibili', const <String, String>{'a': '1'})
        ..replace('netease', const <String, String>{'b': '2'});

      jar.clear('bilibili');

      expect(jar.cookieHeader('bilibili'), isNull);
      expect(jar.cookieHeader('netease'), 'b=2');
    });
  });
}
