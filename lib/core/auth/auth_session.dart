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

/// Public identity of a signed-in source account.
///
/// Never contains a credential: this is the part that may be shown in the
/// settings UI and persisted alongside the session.
@immutable
class AuthAccount {
  const AuthAccount({
    required this.sourceId,
    required this.userId,
    required this.displayName,
    this.avatarUrl,
    this.isVip = false,
  });

  /// Source this account belongs to, e.g. `bilibili`.
  final String sourceId;

  /// Source-specific user id.
  final String userId;

  /// Display name shown on the account row.
  final String displayName;

  /// Remote avatar URL, if the source exposes one.
  final String? avatarUrl;

  /// Whether the account currently carries the source's premium tier.
  final bool isVip;

  factory AuthAccount.fromJson(Map<String, dynamic> json) {
    return AuthAccount(
      sourceId: json['sourceId'] as String? ?? '',
      userId: json['userId'] as String? ?? '',
      displayName: json['displayName'] as String? ?? '',
      avatarUrl: json['avatarUrl'] as String?,
      isVip: json['isVip'] as bool? ?? false,
    );
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
    'sourceId': sourceId,
    'userId': userId,
    'displayName': displayName,
    if (avatarUrl != null) 'avatarUrl': avatarUrl,
    'isVip': isVip,
  };

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is AuthAccount &&
          other.sourceId == sourceId &&
          other.userId == userId &&
          other.displayName == displayName &&
          other.avatarUrl == avatarUrl &&
          other.isVip == isVip;

  @override
  int get hashCode =>
      Object.hash(sourceId, userId, displayName, avatarUrl, isVip);
}

/// A persisted signed-in session.
///
/// [cookies] is a bearer credential for cookie-based sources. It must only be
/// written to secure storage and must never be logged or rendered.
@immutable
class AuthSession {
  const AuthSession({
    required this.account,
    required this.cookies,
    required this.signedInAt,
    this.refreshToken,
    this.expiresAt,
    this.lastValidatedAt,
  });

  final AuthAccount account;
  final Map<String, String> cookies;
  final String? refreshToken;
  final DateTime signedInAt;
  final DateTime? expiresAt;
  final DateTime? lastValidatedAt;

  bool isExpiredAt(DateTime now) {
    final deadline = expiresAt;
    return deadline != null && !deadline.isAfter(now);
  }

  AuthSession copyWith({
    AuthAccount? account,
    Map<String, String>? cookies,
    String? refreshToken,
    DateTime? signedInAt,
    DateTime? expiresAt,
    DateTime? lastValidatedAt,
  }) {
    return AuthSession(
      account: account ?? this.account,
      cookies: cookies ?? this.cookies,
      refreshToken: refreshToken ?? this.refreshToken,
      signedInAt: signedInAt ?? this.signedInAt,
      expiresAt: expiresAt ?? this.expiresAt,
      lastValidatedAt: lastValidatedAt ?? this.lastValidatedAt,
    );
  }

  factory AuthSession.fromJson(Map<String, dynamic> json) {
    final rawCookies = json['cookies'];
    final cookies = <String, String>{};
    if (rawCookies is Map) {
      for (final entry in rawCookies.entries) {
        final key = entry.key;
        final value = entry.value;
        if (key is String && value is String && value.isNotEmpty) {
          cookies[key] = value;
        }
      }
    }

    final rawAccount = json['account'];
    return AuthSession(
      account: AuthAccount.fromJson(
        rawAccount is Map
            ? Map<String, dynamic>.from(rawAccount)
            : const <String, dynamic>{},
      ),
      cookies: cookies,
      refreshToken: json['refreshToken'] as String?,
      signedInAt:
          DateTime.tryParse(json['signedInAt'] as String? ?? '') ??
          DateTime.fromMillisecondsSinceEpoch(0, isUtc: true),
      expiresAt: DateTime.tryParse(json['expiresAt'] as String? ?? ''),
      lastValidatedAt: DateTime.tryParse(
        json['lastValidatedAt'] as String? ?? '',
      ),
    );
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
    'account': account.toJson(),
    'cookies': cookies,
    if (refreshToken != null) 'refreshToken': refreshToken,
    'signedInAt': signedInAt.toIso8601String(),
    if (expiresAt != null) 'expiresAt': expiresAt!.toIso8601String(),
    if (lastValidatedAt != null)
      'lastValidatedAt': lastValidatedAt!.toIso8601String(),
  };
}
