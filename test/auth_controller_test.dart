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

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:flind_player/core/auth/auth_driver.dart';
import 'package:flind_player/core/auth/auth_exception.dart';
import 'package:flind_player/core/auth/auth_session.dart';
import 'package:flind_player/core/auth/auth_state.dart';
import 'package:flind_player/data/auth/auth_cookie_jar.dart';
import 'package:flind_player/data/auth/auth_session_store.dart';
import 'package:flind_player/data/providers/auth_providers.dart';

class _MemoryStore implements AuthSessionStore {
  final Map<String, AuthSession> values = <String, AuthSession>{};
  final Set<String> deleted = <String>{};

  @override
  Future<AuthSession?> read(String sourceId) async => values[sourceId];

  @override
  Future<void> write(AuthSession session) async {
    values[session.account.sourceId] = session;
  }

  @override
  Future<void> delete(String sourceId) async {
    values.remove(sourceId);
    deleted.add(sourceId);
  }
}

class _FakeDriver implements AuthDriver {
  _FakeDriver();

  static final AuthChallenge _challenge = AuthChallenge(
    id: 'key',
    method: AuthMethod.qrCode,
    expiresAt: DateTime.utc(2026, 10, 28, 12, 3),
    qrContent: 'https://example.com/qr',
  );

  AuthSession? session;
  AuthPollResult nextPoll = const AuthPollResult.pending();
  AuthException? validateError;
  bool signedOut = false;

  @override
  String get sourceId => 'bilibili';

  @override
  String get displayName => 'bilibili';

  @override
  Set<AuthMethod> get methods => const <AuthMethod>{AuthMethod.qrCode};

  @override
  Future<AuthChallenge> begin(AuthMethod method) async => _challenge;

  @override
  Future<AuthPollResult> poll(AuthChallenge challenge) async => nextPoll;

  @override
  Future<void> cancel(AuthChallenge challenge) async {}

  @override
  Future<AuthSession> validate(AuthSession session) async {
    final error = validateError;
    if (error != null) throw error;
    return session.copyWith(lastValidatedAt: DateTime.utc(2026, 10, 29));
  }

  @override
  Future<void> signOut(AuthSession session) async {
    signedOut = true;
  }
}

AuthSession _session({DateTime? expiresAt}) => AuthSession(
  account: const AuthAccount(
    sourceId: 'bilibili',
    userId: '42',
    displayName: 'tester',
  ),
  cookies: const <String, String>{'SESSDATA': 'secret'},
  signedInAt: DateTime.utc(2026, 10, 28),
  expiresAt: expiresAt,
);

void main() {
  late _MemoryStore store;
  late _FakeDriver driver;
  late AuthCookieJar jar;
  late ProviderContainer container;

  setUp(() {
    store = _MemoryStore();
    driver = _FakeDriver();
    jar = AuthCookieJar();
    container = ProviderContainer(
      overrides: [
        authSessionStoreProvider.overrideWithValue(store),
        authCookieJarProvider.overrideWithValue(jar),
        authDriversProvider.overrideWithValue(<AuthDriver>[driver]),
      ],
    );
  });

  tearDown(() => container.dispose());

  Future<AuthState> readState() =>
      container.read(authControllerProvider.future);

  test('build hydrates a stored session and its cookie jar', () async {
    store.values['bilibili'] = _session();

    final state = await readState();

    expect(state.sessionFor('bilibili')?.account.displayName, 'tester');
    expect(jar.cookieHeader('bilibili'), 'SESSDATA=secret');
  });

  test('build moves an expired session to expired and deletes it', () async {
    store.values['bilibili'] = _session(expiresAt: DateTime.utc(2026, 10, 1));

    final state = await readState();

    expect(state.sessionFor('bilibili'), isNull);
    expect(state.expiredAccounts['bilibili']?.displayName, 'tester');
    expect(store.values, isEmpty);
    expect(jar.cookieHeader('bilibili'), isNull);
  });

  test('startLogin and a successful poll persist the session', () async {
    await readState();
    final controller = container.read(authControllerProvider.notifier);

    await controller.startLogin('bilibili');
    expect(
      container
          .read(authControllerProvider)
          .value
          ?.flowFor('bilibili')
          ?.challenge
          ?.id,
      'key',
    );

    driver.nextPoll = AuthPollResult.success(_session());
    await controller.poll('bilibili');

    final state = container.read(authControllerProvider).value!;
    expect(state.sessionFor('bilibili')?.cookies['SESSDATA'], 'secret');
    expect(state.flowFor('bilibili'), isNull);
    expect(store.values['bilibili']?.account.userId, '42');
    expect(jar.cookieHeader('bilibili'), 'SESSDATA=secret');
  });

  test('a scanned poll updates the flow without signing in', () async {
    await readState();
    final controller = container.read(authControllerProvider.notifier);
    await controller.startLogin('bilibili');

    driver.nextPoll = const AuthPollResult.scanned();
    await controller.poll('bilibili');

    final flow = container
        .read(authControllerProvider)
        .value!
        .flowFor('bilibili');
    expect(flow?.status, AuthPollStatus.scanned);
    expect(store.values, isEmpty);
  });

  test('signOut clears storage, jar and state', () async {
    store.values['bilibili'] = _session();
    await readState();
    final controller = container.read(authControllerProvider.notifier);

    await controller.signOut('bilibili');

    final state = container.read(authControllerProvider).value!;
    expect(state.sessionFor('bilibili'), isNull);
    expect(store.values, isEmpty);
    expect(jar.cookieHeader('bilibili'), isNull);
    expect(driver.signedOut, isTrue);
  });

  test(
    'validate moves a rejected session to expired and clears secrets',
    () async {
      store.values['bilibili'] = _session();
      await readState();
      final controller = container.read(authControllerProvider.notifier);
      driver.validateError = const AuthException(
        AuthFailure.expired,
        'expired',
      );

      await controller.validate('bilibili');

      final state = container.read(authControllerProvider).value!;
      expect(state.sessionFor('bilibili'), isNull);
      expect(state.expiredAccounts['bilibili']?.displayName, 'tester');
      expect(store.values, isEmpty);
      expect(jar.cookieHeader('bilibili'), isNull);
    },
  );
}
