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

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:flind_player/core/auth/auth_session.dart';
import 'package:flind_player/data/auth/auth_session_store.dart';

final _session = AuthSession(
  account: const AuthAccount(
    sourceId: 'bilibili',
    userId: '42',
    displayName: 'tester',
    isVip: true,
  ),
  cookies: const <String, String>{'SESSDATA': 'secret'},
  signedInAt: DateTime.utc(2026, 10, 28),
);

void main() {
  setUp(() {
    FlutterSecureStorage.setMockInitialValues(<String, String>{});
  });

  test('write then read returns the same session', () async {
    final store = SecureAuthSessionStore();

    await store.write(_session);
    final restored = await store.read('bilibili');

    expect(restored?.account.displayName, 'tester');
    expect(restored?.cookies, <String, String>{'SESSDATA': 'secret'});
  });

  test('delete removes the stored session', () async {
    final store = SecureAuthSessionStore();
    await store.write(_session);

    await store.delete('bilibili');

    expect(await store.read('bilibili'), isNull);
  });

  test('reading corrupt JSON returns null and does not throw', () async {
    FlutterSecureStorage.setMockInitialValues(<String, String>{
      'flind.auth.bilibili': 'not-json',
    });
    final store = SecureAuthSessionStore();

    expect(await store.read('bilibili'), isNull);
  });

  test('a session for another source is not returned', () async {
    final store = SecureAuthSessionStore();
    await store.write(_session);

    expect(await store.read('netease'), isNull);
  });
}
