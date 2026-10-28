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

import 'package:flind_player/core/auth/auth_exception.dart';
import 'package:flind_player/core/auth/auth_session.dart';

/// The four states of Bilibili's QR login poll.
enum BiliQrStatus {
  /// Waiting for the user to scan.
  pending,

  /// Scanned, waiting for the user to confirm on the phone.
  scanned,

  /// The QR code timed out.
  expired,

  /// Login succeeded.
  success;

  static BiliQrStatus fromCode(int code) => switch (code) {
    86101 => pending,
    86090 => scanned,
    86038 => expired,
    0 => success,
    _ => throw FormatException('Unknown Bilibili QR status: $code'),
  };
}

/// The `qrcode/generate` payload.
class BiliQrGenerate {
  const BiliQrGenerate({required this.url, required this.key});

  final Uri url;
  final String key;

  factory BiliQrGenerate.fromJson(Map<String, dynamic> json) {
    final url = json['url'] as String? ?? '';
    final key = json['qrcode_key'] as String? ?? '';
    if (url.isEmpty || key.isEmpty) {
      throw const BiliAuthException(
        'Bilibili QR response was missing its url or key',
      );
    }
    return BiliQrGenerate(url: Uri.parse(url), key: key);
  }
}

/// The `qrcode/poll` payload plus any cookies from the HTTP response.
class BiliQrPoll {
  const BiliQrPoll({
    required this.status,
    this.cookies = const <String, String>{},
    this.refreshToken,
    this.message = '',
    this.url,
  });

  final BiliQrStatus status;
  final Map<String, String> cookies;
  final String? refreshToken;
  final String message;

  /// Success redirect URL; it may carry the cookies as query parameters when
  /// the HTTP stack does not expose `Set-Cookie`.
  final String? url;

  factory BiliQrPoll.fromJson(
    Map<String, dynamic> json, {
    Map<String, String> cookies = const <String, String>{},
  }) {
    final code = (json['code'] as num?)?.toInt() ?? -1;
    return BiliQrPoll(
      status: BiliQrStatus.fromCode(code),
      cookies: cookies,
      refreshToken: json['refresh_token'] as String?,
      message: json['message'] as String? ?? '',
      url: json['url'] as String?,
    );
  }
}

/// The signed-in profile from `/x/web-interface/nav`.
class BiliNavAccount {
  const BiliNavAccount({required this.account});

  final AuthAccount account;

  String get userId => account.userId;
  String get displayName => account.displayName;
  String? get avatarUrl => account.avatarUrl;
  bool get isVip => account.isVip;
  String get sourceId => account.sourceId;

  factory BiliNavAccount.fromJson(Map<String, dynamic> json) {
    if (json['isLogin'] != true) {
      throw const BiliAuthException(
        'Bilibili session is no longer signed in',
        kind: AuthFailure.expired,
      );
    }

    final userId = json['mid'];
    final displayName = json['uname'] as String? ?? '';
    if (userId == null || displayName.isEmpty) {
      throw const BiliAuthException(
        'Bilibili nav response had no account identity',
        kind: AuthFailure.invalidCredentials,
      );
    }

    final face = json['face'] as String? ?? '';
    final vipStatus = (json['vipStatus'] as num?)?.toInt() ?? 0;
    final vipType = (json['vipType'] as num?)?.toInt() ?? 0;

    return BiliNavAccount(
      account: AuthAccount(
        sourceId: 'bilibili',
        userId: '$userId',
        displayName: displayName,
        avatarUrl: _httpsOrNull(face),
        isVip: vipStatus == 1 || vipType > 0,
      ),
    );
  }
}

String? _httpsOrNull(String raw) {
  if (raw.isEmpty) return null;
  final uri = Uri.tryParse(raw);
  if (uri == null) return null;
  if (uri.scheme == 'http') return uri.replace(scheme: 'https').toString();
  return raw;
}

/// A typed Bilibili authentication failure.
class BiliAuthException extends AuthException {
  const BiliAuthException(
    String message, {
    AuthFailure kind = AuthFailure.unknown,
  }) : super(kind, message);
}
