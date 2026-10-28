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

import 'package:flind_player/core/auth/auth_driver.dart';
import 'package:flind_player/core/auth/auth_exception.dart';
import 'package:flind_player/core/auth/auth_session.dart';

/// UI state of one source's active login attempt.
@immutable
class AuthFlowState {
  const AuthFlowState({
    this.challenge,
    this.status = AuthPollStatus.pending,
    this.error,
    this.busy = false,
  });

  final AuthChallenge? challenge;
  final AuthPollStatus status;
  final AuthException? error;
  final bool busy;

  AuthFlowState copyWith({
    AuthChallenge? challenge,
    AuthPollStatus? status,
    AuthException? error,
    bool? busy,
  }) {
    return AuthFlowState(
      challenge: challenge ?? this.challenge,
      status: status ?? this.status,
      error: error,
      busy: busy ?? this.busy,
    );
  }
}

/// Signed-in sessions, expired accounts and active flows for every source.
@immutable
class AuthState {
  const AuthState({
    this.sessions = const <String, AuthSession>{},
    this.expiredAccounts = const <String, AuthAccount>{},
    this.flows = const <String, AuthFlowState>{},
  });

  final Map<String, AuthSession> sessions;

  /// Accounts whose credential the server rejected. Kept so the settings row
  /// can say "登录已过期" instead of silently looking signed out.
  final Map<String, AuthAccount> expiredAccounts;

  final Map<String, AuthFlowState> flows;

  AuthSession? sessionFor(String sourceId) => sessions[sourceId];

  AuthAccount? accountFor(String sourceId) =>
      sessions[sourceId]?.account ?? expiredAccounts[sourceId];

  bool isExpired(String sourceId) =>
      !sessions.containsKey(sourceId) && expiredAccounts.containsKey(sourceId);

  AuthFlowState? flowFor(String sourceId) => flows[sourceId];

  AuthState copyWith({
    Map<String, AuthSession>? sessions,
    Map<String, AuthAccount>? expiredAccounts,
    Map<String, AuthFlowState>? flows,
  }) {
    return AuthState(
      sessions: sessions ?? this.sessions,
      expiredAccounts: expiredAccounts ?? this.expiredAccounts,
      flows: flows ?? this.flows,
    );
  }
}
