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
import 'package:flind_player/data/sources/netease/netease_auth_driver.dart';
import 'package:flind_player/data/sources/netease/netease_client.dart';

class _FakeNeteaseClient extends NeteaseClient {
  _FakeNeteaseClient();

  NeteaseJsonResponse? nextGenerate;
  NeteaseJsonResponse? nextPoll;
  Map<String, dynamic>? nextProfile;

  @override
  Future<NeteaseJsonResponse> getJsonWithResponse(
    String path, {
    Map<String, dynamic>? query,
    Set<int> allowCodes = const <int>{},
  }) async {
    if (path.contains('qrcode/unikey')) return nextGenerate!;
    if (path.contains('qrcode/client/login')) return nextPoll!;
    throw StateError('unexpected path: $path');
  }

  @override
  Future<Map<String, dynamic>> getJson(
    String path, {
    Map<String, dynamic>? query,
    Set<int> allowCodes = const <int>{},
  }) async {
    if (path.contains('nuser/account/get')) return nextProfile!;
    throw StateError('unexpected path: $path');
  }
}

NeteaseJsonResponse _response(
  Map<String, dynamic> json, {
  List<String> setCookies = const <String>[],
}) {
  return NeteaseJsonResponse(json: json, setCookies: setCookies);
}

AuthChallenge _challenge() => AuthChallenge(
  id: 'unikey',
  method: AuthMethod.qrCode,
  expiresAt: DateTime.utc(2026, 10, 28, 12, 3),
);

void main() {
  late _FakeNeteaseClient client;
  late AuthCookieJar jar;
  late NeteaseAuthDriver driver;

  setUp(() {
    client = _FakeNeteaseClient();
    jar = AuthCookieJar();
    driver = NeteaseAuthDriver(client: client, jar: jar);
  });

  test('begin returns a QR challenge for the unikey', () async {
    client.nextGenerate = _response(<String, dynamic>{
      'code': 200,
      'unikey': 'unikey',
    });

    final challenge = await driver.begin(AuthMethod.qrCode);

    expect(challenge.id, 'unikey');
    expect(challenge.qrContent, contains('codekey=unikey'));
  });

  test('poll maps pending, scanned and expired', () async {
    client.nextPoll = _response(<String, dynamic>{'code': 801});
    expect((await driver.poll(_challenge())).status, AuthPollStatus.pending);

    client.nextPoll = _response(<String, dynamic>{'code': 802});
    expect((await driver.poll(_challenge())).status, AuthPollStatus.scanned);

    client.nextPoll = _response(<String, dynamic>{'code': 800});
    expect((await driver.poll(_challenge())).status, AuthPollStatus.expired);
  });

  test('success reads MUSIC_U and the profile', () async {
    client.nextPoll = _response(<String, dynamic>{
      'code': 803,
      'cookie': 'MUSIC_U=token; __csrf=csrf',
    });
    client.nextProfile = <String, dynamic>{
      'code': 200,
      'profile': <String, dynamic>{
        'userId': 7,
        'nickname': 'listener',
        'avatarUrl': 'https://p1.music.126.net/a.jpg',
        'vipType': 11,
      },
    };

    final result = await driver.poll(_challenge());

    expect(result.status, AuthPollStatus.success);
    expect(result.session?.account.sourceId, 'netease');
    expect(result.session?.account.displayName, 'listener');
    expect(result.session?.account.isVip, isTrue);
    expect(result.session?.cookies['MUSIC_U'], 'token');
    expect(jar.cookieHeader('netease'), contains('MUSIC_U=token'));
  });

  test('success without MUSIC_U is rejected', () async {
    client.nextPoll = _response(<String, dynamic>{
      'code': 803,
      'cookie': '__csrf=csrf',
    });

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
    expect(jar.cookieHeader('netease'), isNull);
  });
}
