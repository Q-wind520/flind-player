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

import 'package:flind_player/core/auth/auth_session.dart';

/// How a source obtains a session.
enum AuthMethod {
  /// Scan a QR code with the source's mobile app.
  qrCode,

  /// OAuth device flow: show a URL + code, poll for a token.
  oauthDevice,

  /// OAuth browser redirect flow.
  oauthBrowser,
}

/// Progress of a challenge poll.
enum AuthPollStatus { pending, scanned, success, expired }

/// One active login attempt.
class AuthChallenge {
  const AuthChallenge({
    required this.id,
    required this.method,
    required this.expiresAt,
    this.qrContent,
    this.verificationUri,
    this.userCode,
  });

  /// Opaque driver-owned identifier (QR key, device code, ...).
  final String id;
  final AuthMethod method;
  final DateTime expiresAt;

  /// Payload to render as a QR code, when [method] is [AuthMethod.qrCode].
  final String? qrContent;

  /// Human-facing verification URL, when [method] is [AuthMethod.oauthDevice].
  final Uri? verificationUri;

  /// Short code the user enters at [verificationUri].
  final String? userCode;
}

/// Result of polling [AuthChallenge].
class AuthPollResult {
  const AuthPollResult({required this.status, this.session});

  const AuthPollResult.pending() : this(status: AuthPollStatus.pending);
  const AuthPollResult.scanned() : this(status: AuthPollStatus.scanned);
  const AuthPollResult.expired() : this(status: AuthPollStatus.expired);

  const AuthPollResult.success(AuthSession session)
    : this(status: AuthPollStatus.success, session: session);

  final AuthPollStatus status;
  final AuthSession? session;
}

/// Source-specific login protocol.
///
/// Implementations own the platform quirks (QR endpoint, cookie names, profile
/// endpoint). They must never persist credentials themselves: the controller
/// stores [AuthSession] in the keychain and hydrates the cookie jar.
abstract interface class AuthDriver {
  /// Source id, e.g. `bilibili`.
  String get sourceId;

  /// Human name shown in the account list.
  String get displayName;

  /// Methods this driver can start.
  Set<AuthMethod> get methods;

  Future<AuthChallenge> begin(AuthMethod method);

  Future<AuthPollResult> poll(AuthChallenge challenge);

  /// Stops background work for [challenge]; safe to call after completion.
  Future<void> cancel(AuthChallenge challenge);

  /// Re-fetches the profile with [session]'s credential.
  ///
  /// Throws an expired [AuthException] when the server rejects it.
  Future<AuthSession> validate(AuthSession session);

  /// Best-effort remote logout. Local deletion is the caller's job.
  Future<void> signOut(AuthSession session);
}
