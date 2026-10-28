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

import 'package:flind_player/core/auth/auth_driver.dart';
import 'package:flind_player/core/auth/auth_exception.dart';
import 'package:flind_player/data/auth/auth_cookie_jar.dart';
import 'package:flind_player/data/sources/bilibili/bili_auth_driver.dart';
import 'package:flind_player/data/sources/bilibili/bili_client.dart';

class _FakeBiliClient extends BiliClient {
  _FakeBiliClient();

  BiliJsonResponse? nextGenerate;
  BiliJsonResponse? nextPoll;
  BiliJsonResponse? nextNav;

  @override
  Future<BiliJsonResponse> getJsonWithResponse(
    String path, {
    Map<String, dynamic>? query,
    Set<int> allowCodes = const <int>{},
    Map<String, dynamic>? headers,
  }) async {
    if (path.contains('qrcode/generate')) {
      return nextGenerate!;
    }
    if (path.contains('qrcode/poll')) {
      return nextPoll!;
    }
    if (path.contains('/x/web-interface/nav')) {
      return nextNav!;
    }
    throw StateError('unexpected path: $path');
  }
}

BiliJsonResponse _response(
  Map<String, dynamic> data, {
  int code = 0,
  List<String> setCookies = const <String>[],
}) {
  return BiliJsonResponse(
    json: <String, dynamic>{'code': code, 'data': data},
    setCookies: setCookies,
  );
}

void main() {
  late _FakeBiliClient client;
  late AuthCookieJar jar;
  late BiliAuthDriver driver;

  setUp(() {
    client = _FakeBiliClient();
    jar = AuthCookieJar();
    driver = BiliAuthDriver(client: client, jar: jar);
  });

  test('begin returns a QR challenge with the generated key', () async {
    client.nextGenerate = _response(<String, dynamic>{
      'url': 'https://account.bilibili.com/scan?qrcode_key=key',
      'qrcode_key': 'key',
    });

    final challenge = await driver.begin(AuthMethod.qrCode);

    expect(challenge.id, 'key');
    expect(challenge.qrContent, contains('qrcode_key=key'));
  });

  test('poll maps pending, scanned and expired without a session', () async {
    client.nextPoll = _response(<String, dynamic>{'code': 86101});
    expect((await driver.poll(_challenge())).status, AuthPollStatus.pending);

    client.nextPoll = _response(<String, dynamic>{'code': 86090});
    expect((await driver.poll(_challenge())).status, AuthPollStatus.scanned);

    client.nextPoll = _response(<String, dynamic>{'code': 86038});
    expect((await driver.poll(_challenge())).status, AuthPollStatus.expired);
  });

  test('success reads login cookies and the nav profile', () async {
    client.nextPoll = _response(
      <String, dynamic>{'code': 0, 'refresh_token': 'refresh'},
      setCookies: const <String>[
        'SESSDATA=secret; Path=/; HttpOnly',
        'bili_jct=csrf; Path=/',
      ],
    );
    client.nextNav = _response(<String, dynamic>{
      'isLogin': true,
      'mid': 42,
      'uname': 'tester',
      'face': 'https://i0.hdslb.com/avatar.jpg',
      'vipStatus': 1,
    });

    final result = await driver.poll(_challenge());

    expect(result.status, AuthPollStatus.success);
    expect(result.session?.account.displayName, 'tester');
    expect(result.session?.account.isVip, isTrue);
    expect(result.session?.cookies['SESSDATA'], 'secret');
    expect(result.session?.refreshToken, 'refresh');
    expect(jar.cookieHeader('bilibili'), contains('SESSDATA=secret'));
  });

  test('success can read cookies from the cross-domain url', () async {
    client.nextPoll = _response(<String, dynamic>{
      'code': 0,
      'url':
          'https://passport.biligame.com/crossDomain?SESSDATA=url-secret'
          '&bili_jct=csrf',
    });
    client.nextNav = _response(<String, dynamic>{
      'isLogin': true,
      'mid': 42,
      'uname': 'tester',
    });

    final result = await driver.poll(_challenge());

    expect(result.status, AuthPollStatus.success);
    expect(result.session?.cookies['SESSDATA'], 'url-secret');
    expect(result.session?.cookies['bili_jct'], 'csrf');
  });

  test('success without SESSDATA is rejected and does not sign in', () async {
    client.nextPoll = _response(
      <String, dynamic>{'code': 0},
      setCookies: const <String>['bili_jct=csrf; Path=/'],
    );

    await expectLater(
      driver.poll(_challenge()),
      throwsA(
        isA<AuthException>().having(
          (error) => error.kind,
          'kind',
          AuthFailure.invalidCredentials,
        ),
      ),
    );
    expect(jar.cookieHeader('bilibili'), isNull);
  });
}

AuthChallenge _challenge() => AuthChallenge(
  id: 'key',
  method: AuthMethod.qrCode,
  expiresAt: DateTime.utc(2026, 10, 28, 12, 3),
);
