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

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:flind_player/core/auth/auth_driver.dart';
import 'package:flind_player/core/auth/auth_session.dart';
import 'package:flind_player/data/auth/auth_cookie_jar.dart';
import 'package:flind_player/data/auth/auth_session_store.dart';
import 'package:flind_player/data/providers/auth_providers.dart';
import 'package:flind_player/features/settings/account_section.dart';

import 'support/l10n.dart';

class _MemoryStore implements AuthSessionStore {
  final Map<String, AuthSession> values = <String, AuthSession>{};

  @override
  Future<AuthSession?> read(String sourceId) async => values[sourceId];

  @override
  Future<void> write(AuthSession session) async {
    values[session.account.sourceId] = session;
  }

  @override
  Future<void> delete(String sourceId) async {
    values.remove(sourceId);
  }
}

class _FakeDriver implements AuthDriver {
  _FakeDriver();

  @override
  String get sourceId => 'bilibili';

  @override
  String get displayName => 'bilibili';

  @override
  Set<AuthMethod> get methods => const <AuthMethod>{AuthMethod.qrCode};

  @override
  Future<AuthChallenge> begin(AuthMethod method) async => AuthChallenge(
    id: 'key',
    method: AuthMethod.qrCode,
    qrContent: 'https://example.com/qr',
    expiresAt: DateTime.now().add(const Duration(minutes: 3)),
  );

  @override
  Future<AuthPollResult> poll(AuthChallenge challenge) async =>
      const AuthPollResult.pending();

  @override
  Future<void> cancel(AuthChallenge challenge) async {}

  @override
  Future<AuthSession> validate(AuthSession session) async => session;

  @override
  Future<void> signOut(AuthSession session) async {}
}

Widget _app(Widget child, {AuthSession? session, _MemoryStore? store}) {
  final resolvedStore = store ?? _MemoryStore();
  if (session != null) resolvedStore.values['bilibili'] = session;
  return ProviderScope(
    overrides: [
      authSessionStoreProvider.overrideWithValue(resolvedStore),
      authCookieJarProvider.overrideWithValue(AuthCookieJar()),
      authDriversProvider.overrideWithValue(<AuthDriver>[_FakeDriver()]),
    ],
    child: localizedApp(Scaffold(body: child)),
  );
}

AuthSession _session() => AuthSession(
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
  testWidgets('signed-out row opens the QR sheet', (tester) async {
    await tester.pumpWidget(_app(const AccountSection()));
    await tester.pumpAndSettle();

    expect(find.text('bilibili'), findsOneWidget);
    expect(find.text('未登录'), findsOneWidget);

    await tester.tap(find.text('bilibili'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    expect(find.text('登录 bilibili'), findsOneWidget);
    expect(find.text('等待扫码'), findsOneWidget);

    // Dispose the sheet so its one-second ticker does not leak into the next
    // test.
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
  });

  testWidgets('a stored session shows the nickname and VIP badge', (
    tester,
  ) async {
    await tester.pumpWidget(_app(const AccountSection(), session: _session()));
    await tester.pumpAndSettle();

    expect(find.text('tester'), findsOneWidget);
    expect(find.text('VIP'), findsOneWidget);
  });

  testWidgets('tapping a signed-in row shows UID and logout', (tester) async {
    await tester.pumpWidget(_app(const AccountSection(), session: _session()));
    await tester.pumpAndSettle();

    await tester.tap(find.text('bilibili'));
    await tester.pumpAndSettle();

    expect(find.text('UID 42'), findsOneWidget);
    expect(find.text('退出登录'), findsOneWidget);
  });

  testWidgets('signing out clears the stored session', (tester) async {
    final store = _MemoryStore();
    await tester.pumpWidget(
      _app(const AccountSection(), session: _session(), store: store),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('bilibili'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('退出登录'));
    await tester.pumpAndSettle();
    expect(find.text('退出登录？'), findsOneWidget);

    await tester.tap(find.widgetWithText(FilledButton, '退出登录'));
    await tester.pumpAndSettle();

    expect(store.values, isEmpty);
    expect(find.text('未登录'), findsOneWidget);
  });
}
