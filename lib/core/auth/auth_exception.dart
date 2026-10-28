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

/// Why an authentication flow could not continue.
enum AuthFailure {
  /// Transport failed; the session may still be valid.
  network,

  /// The server rejected the stored credential.
  expired,

  /// The user closed the flow or it timed out.
  cancelled,

  /// The source's risk control rejected the request.
  riskControl,

  /// The source answered but the payload cannot be a session.
  invalidCredentials,

  /// The platform keychain is unavailable.
  storage,

  /// Anything not covered above.
  unknown,
}

/// A user-facing, source-independent authentication failure.
///
/// Messages are safe to show: they never contain cookies, tokens or response
/// bodies.
class AuthException implements Exception {
  const AuthException(this.kind, this.message);

  final AuthFailure kind;
  final String message;

  bool get isExpired => kind == AuthFailure.expired;

  @override
  String toString() => 'AuthException($kind): $message';
}
