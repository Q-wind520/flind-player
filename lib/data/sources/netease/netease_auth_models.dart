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

/// The four states of NetEase's QR login poll.
///
/// NetEase uses `800` expired, `801` waiting for scan, `802` scanned and
/// waiting for confirmation, `803` authorized. The positions differ from
/// Bilibili's 86xxx codes, which is why each driver owns its mapping.
enum NeteaseQrStatus {
  pending,
  scanned,
  expired,
  success;

  static NeteaseQrStatus fromCode(int code) => switch (code) {
    800 => expired,
    801 => pending,
    802 => scanned,
    803 => success,
    _ => throw FormatException('Unknown NetEase QR status: $code'),
  };
}

/// The `/api/login/qrcode/unikey` payload.
class NeteaseQrGenerate {
  const NeteaseQrGenerate({required this.unikey});

  final String unikey;

  factory NeteaseQrGenerate.fromJson(Map<String, dynamic> json) {
    final unikey = json['unikey'] as String? ?? '';
    if (unikey.isEmpty) {
      throw const NeteaseAuthException(
        'NetEase QR response was missing its unikey',
        kind: AuthFailure.invalidCredentials,
      );
    }
    return NeteaseQrGenerate(unikey: unikey);
  }
}

/// The `/api/login/qrcode/client/login` payload plus cookies.
class NeteaseQrPoll {
  const NeteaseQrPoll({
    required this.status,
    this.cookies = const <String, String>{},
    this.message = '',
  });

  final NeteaseQrStatus status;
  final Map<String, String> cookies;
  final String message;

  factory NeteaseQrPoll.fromJson(
    Map<String, dynamic> json, {
    Map<String, String> cookies = const <String, String>{},
  }) {
    final code = (json['code'] as num?)?.toInt() ?? -1;
    return NeteaseQrPoll(
      status: NeteaseQrStatus.fromCode(code),
      cookies: cookies,
      message: json['message'] as String? ?? '',
    );
  }
}

/// The signed-in profile from `/api/nuser/account/get`.
class NeteaseProfile {
  const NeteaseProfile({required this.account});

  final AuthAccount account;

  factory NeteaseProfile.fromJson(Map<String, dynamic> json) {
    final raw = json['profile'];
    if (raw is! Map) {
      throw const NeteaseAuthException(
        'NetEase account response had no profile',
        kind: AuthFailure.expired,
      );
    }
    final profile = Map<String, dynamic>.from(raw);
    final userId = profile['userId'];
    final nickname = profile['nickname'] as String? ?? '';
    if (userId == null) {
      throw const NeteaseAuthException(
        'NetEase profile had no user id',
        kind: AuthFailure.invalidCredentials,
      );
    }

    final avatar = profile['avatarUrl'] as String? ?? '';
    final vipType = (profile['vipType'] as num?)?.toInt() ?? 0;
    return NeteaseProfile(
      account: AuthAccount(
        sourceId: 'netease',
        userId: '$userId',
        displayName: nickname.isEmpty ? 'NetEase' : nickname,
        avatarUrl: _httpsOrNull(avatar),
        isVip: vipType > 0,
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

/// A typed NetEase authentication failure.
class NeteaseAuthException extends AuthException {
  const NeteaseAuthException(
    String message, {
    AuthFailure kind = AuthFailure.unknown,
  }) : super(kind, message);
}
