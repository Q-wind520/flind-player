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

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:flind_player/core/auth/auth_driver.dart';
import 'package:flind_player/core/auth/auth_exception.dart';
import 'package:flind_player/core/auth/auth_policy.dart';
import 'package:flind_player/core/auth/auth_session.dart';
import 'package:flind_player/core/auth/auth_state.dart';
import 'package:flind_player/data/providers/auth_core_providers.dart';
import 'package:flind_player/data/providers/bilibili_providers.dart';
import 'package:flind_player/data/providers/netease_providers.dart';
import 'package:flind_player/data/providers/online_source_providers.dart';
import 'package:flind_player/data/sources/bilibili/bili_auth_driver.dart';
import 'package:flind_player/data/sources/netease/netease_auth_driver.dart';

export 'package:flind_player/data/providers/auth_core_providers.dart';

/// Per-source feature gates that depend on a session.
final authSourcePoliciesProvider = Provider<Map<String, AuthSourcePolicy>>(
  (ref) => const <String, AuthSourcePolicy>{
    'bilibili': AuthSourcePolicy(
      lyricsRequireLogin: true,
      highQualityRequiresLogin: true,
    ),
    'netease': AuthSourcePolicy(highQualityRequiresLogin: true),
  },
);

/// Every implemented login protocol.
///
/// Adding a source means adding its driver here; the account UI and the
/// controller never branch on a platform id.
final authDriversProvider = Provider<List<AuthDriver>>((ref) {
  // Flutter Web cannot set the headers Bilibili's passport expects and the
  // source itself is deferred, so account login is native-only.
  if (kIsWeb) return const <AuthDriver>[];
  final jar = ref.watch(authCookieJarProvider);
  final disabled = ref.watch(disabledSourceIdsProvider);
  return <AuthDriver>[
    if (!disabled.contains('bilibili'))
      BiliAuthDriver(
        client: ref.watch(biliClientProvider),
        jar: jar,
        riskControl: ref.watch(riskControlProvider),
        rateLimiter: ref.watch(biliRateLimiterProvider),
      ),
    if (!disabled.contains('netease'))
      NeteaseAuthDriver(client: ref.watch(neteaseClientProvider), jar: jar),
  ];
});

/// The app-wide account state.
final authControllerProvider = AsyncNotifierProvider<AuthController, AuthState>(
  AuthController.new,
);

/// The signed-in session for [sourceId], if any.
final authSessionProvider = Provider.family<AuthSession?, String>((
  ref,
  sourceId,
) {
  return ref.watch(authControllerProvider).value?.sessionFor(sourceId);
});

/// The account to display for [sourceId], including an expired one.
final authAccountProvider = Provider.family<AuthAccount?, String>((
  ref,
  sourceId,
) {
  return ref.watch(authControllerProvider).value?.accountFor(sourceId);
});

/// Active login attempt for [sourceId].
final authFlowProvider = Provider.family<AuthFlowState?, String>((
  ref,
  sourceId,
) {
  return ref.watch(authControllerProvider).value?.flowFor(sourceId);
});

/// Owns the signed-in sessions and the single active login flow per source.
class AuthController extends AsyncNotifier<AuthState> {
  @override
  Future<AuthState> build() async {
    final drivers = ref.watch(authDriversProvider);
    final store = ref.watch(authSessionStoreProvider);
    final jar = ref.watch(authCookieJarProvider);

    final sessions = <String, AuthSession>{};
    final expired = <String, AuthAccount>{};
    for (final driver in drivers) {
      final stored = await store.read(driver.sourceId);
      if (stored == null) continue;
      if (stored.account.sourceId != driver.sourceId) {
        await store.delete(driver.sourceId);
        jar.clear(driver.sourceId);
        continue;
      }
      if (stored.isExpiredAt(DateTime.now())) {
        expired[driver.sourceId] = stored.account;
        await store.delete(driver.sourceId);
        jar.clear(driver.sourceId);
        continue;
      }
      sessions[driver.sourceId] = stored;
      jar.replace(driver.sourceId, stored.cookies);
    }
    return AuthState(sessions: sessions, expiredAccounts: expired);
  }

  AuthDriver? _driverFor(String sourceId) {
    for (final driver in ref.read(authDriversProvider)) {
      if (driver.sourceId == sourceId) return driver;
    }
    return null;
  }

  AuthState _state() {
    final current = state.value;
    if (current == null) {
      throw const AuthException(
        AuthFailure.unknown,
        'Account state is still loading',
      );
    }
    return current;
  }

  /// Starts a QR/OAuth flow for [sourceId].
  Future<void> startLogin(
    String sourceId, {
    AuthMethod method = AuthMethod.qrCode,
  }) async {
    final driver = _driverFor(sourceId);
    if (driver == null) {
      throw AuthException(
        AuthFailure.unknown,
        'No login driver registered for $sourceId',
      );
    }
    if (!driver.methods.contains(method)) {
      throw AuthException(
        AuthFailure.unknown,
        '$sourceId does not support $method',
      );
    }

    final current = _state();
    final previous = current.flows[sourceId];
    final previousChallenge = previous?.challenge;
    if (previousChallenge != null) {
      await driver.cancel(previousChallenge);
    }

    try {
      final challenge = await driver.begin(method);
      if (!ref.mounted) return;
      final flows = Map<String, AuthFlowState>.from(current.flows)
        ..[sourceId] = AuthFlowState(challenge: challenge);
      state = AsyncData(current.copyWith(flows: flows));
    } on AuthException catch (error) {
      _setFlowError(sourceId, error);
      rethrow;
    } catch (error) {
      final mapped = AuthException(AuthFailure.unknown, '$error');
      _setFlowError(sourceId, mapped);
      throw mapped;
    }
  }

  /// Polls the active challenge once. The UI owns the timer cadence.
  Future<void> poll(String sourceId) async {
    final current = state.value;
    if (current == null) return;
    final flow = current.flows[sourceId];
    final challenge = flow?.challenge;
    if (flow == null || challenge == null || flow.busy) return;

    _setFlow(sourceId, flow.copyWith(busy: true, error: null));

    try {
      final result = await ref
          .read(authDriversProvider)
          .firstWhere((driver) => driver.sourceId == sourceId)
          .poll(challenge);
      if (!ref.mounted) return;

      switch (result.status) {
        case AuthPollStatus.pending:
        case AuthPollStatus.scanned:
          _setFlow(sourceId, flow.copyWith(status: result.status, busy: false));
        case AuthPollStatus.expired:
          _setFlow(
            sourceId,
            flow.copyWith(status: AuthPollStatus.expired, busy: false),
          );
        case AuthPollStatus.success:
          final session = result.session;
          if (session == null) {
            throw const AuthException(
              AuthFailure.invalidCredentials,
              'Login succeeded without a session',
            );
          }
          await _adoptSession(session);
      }
    } on AuthException catch (error) {
      _setFlow(sourceId, flow.copyWith(busy: false, error: error));
    } catch (error) {
      _setFlow(
        sourceId,
        flow.copyWith(
          busy: false,
          error: AuthException(AuthFailure.unknown, '$error'),
        ),
      );
    }
  }

  Future<void> _adoptSession(AuthSession session) async {
    final sourceId = session.account.sourceId;
    try {
      await ref.read(authSessionStoreProvider).write(session);
    } catch (_) {
      ref.read(authCookieJarProvider).clear(sourceId);
      throw const AuthException(
        AuthFailure.storage,
        'Could not save the login securely',
      );
    }
    if (!ref.mounted) return;
    ref.read(authCookieJarProvider).replace(sourceId, session.cookies);

    final current = _state();
    final sessions = Map<String, AuthSession>.from(current.sessions)
      ..[sourceId] = session;
    final expired = Map<String, AuthAccount>.from(current.expiredAccounts)
      ..remove(sourceId);
    final flows = Map<String, AuthFlowState>.from(current.flows)
      ..remove(sourceId);
    state = AsyncData(
      current.copyWith(
        sessions: sessions,
        expiredAccounts: expired,
        flows: flows,
      ),
    );
  }

  /// Stops the active flow for [sourceId] and forgets it.
  Future<void> cancelLogin(String sourceId) async {
    if (!ref.mounted) return;
    final current = state.value;
    if (current == null) return;
    final flow = current.flows[sourceId];
    if (flow == null) return;
    final challenge = flow.challenge;
    if (challenge != null) {
      final driver = _driverFor(sourceId);
      await driver?.cancel(challenge);
      if (!ref.mounted) return;
    }
    final flows = Map<String, AuthFlowState>.from(current.flows)
      ..remove(sourceId);
    state = AsyncData(current.copyWith(flows: flows));
  }

  /// Validates a session against the source and refreshes its profile.
  Future<void> validate(String sourceId) async {
    final current = _state();
    final session = current.sessionFor(sourceId);
    if (session == null) return;

    final driver = _driverFor(sourceId);
    if (driver == null) return;

    try {
      final updated = await driver.validate(session);
      try {
        await ref.read(authSessionStoreProvider).write(updated);
      } catch (_) {
        throw const AuthException(
          AuthFailure.storage,
          'Could not refresh the saved login',
        );
      }
      if (!ref.mounted) return;
      ref.read(authCookieJarProvider).replace(sourceId, updated.cookies);

      final latest = _state();
      final sessions = Map<String, AuthSession>.from(latest.sessions)
        ..[sourceId] = updated;
      state = AsyncData(latest.copyWith(sessions: sessions));
    } on AuthException catch (error) {
      if (error.isExpired) {
        await _expire(sourceId, session);
        return;
      }
      if (!ref.mounted) return;
      rethrow;
    }
  }

  /// Re-validates sessions older than [maxAge] in the background.
  Future<void> validateStale({
    Duration maxAge = const Duration(hours: 24),
  }) async {
    final current = state.value;
    if (current == null) return;
    final cutoff = DateTime.now().subtract(maxAge);
    for (final session in current.sessions.values.toList(growable: false)) {
      final last = session.lastValidatedAt;
      if (last != null && last.isAfter(cutoff)) continue;
      try {
        await validate(session.account.sourceId);
      } on AuthException {
        // Network failures must not sign a still-valid session out.
      }
    }
  }

  /// Signs out locally and asks the driver to revoke remotely.
  Future<void> signOut(String sourceId) async {
    final current = _state();
    final session = current.sessionFor(sourceId);
    if (session != null) {
      try {
        await _driverFor(sourceId)?.signOut(session);
      } catch (_) {
        // Remote logout is best effort; local removal is authoritative.
      }
      if (!ref.mounted) return;
    }

    await ref.read(authSessionStoreProvider).delete(sourceId);
    if (!ref.mounted) return;
    ref.read(authCookieJarProvider).clear(sourceId);

    final latest = _state();
    final sessions = Map<String, AuthSession>.from(latest.sessions)
      ..remove(sourceId);
    final expired = Map<String, AuthAccount>.from(latest.expiredAccounts)
      ..remove(sourceId);
    final flows = Map<String, AuthFlowState>.from(latest.flows)
      ..remove(sourceId);
    state = AsyncData(
      latest.copyWith(
        sessions: sessions,
        expiredAccounts: expired,
        flows: flows,
      ),
    );
  }

  Future<void> _expire(String sourceId, AuthSession session) async {
    await ref.read(authSessionStoreProvider).delete(sourceId);
    if (!ref.mounted) return;
    ref.read(authCookieJarProvider).clear(sourceId);

    final current = _state();
    final sessions = Map<String, AuthSession>.from(current.sessions)
      ..remove(sourceId);
    final expired = Map<String, AuthAccount>.from(current.expiredAccounts)
      ..[sourceId] = session.account;
    state = AsyncData(
      current.copyWith(sessions: sessions, expiredAccounts: expired),
    );
  }

  void _setFlow(String sourceId, AuthFlowState flow) {
    if (!ref.mounted) return;
    final current = state.value;
    if (current == null) return;
    final flows = Map<String, AuthFlowState>.from(current.flows)
      ..[sourceId] = flow;
    state = AsyncData(current.copyWith(flows: flows));
  }

  void _setFlowError(String sourceId, AuthException error) {
    _setFlow(sourceId, AuthFlowState(error: error, busy: false));
  }
}
