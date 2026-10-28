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

import 'package:dio/dio.dart';

import 'package:flind_player/core/auth/auth_driver.dart';
import 'package:flind_player/core/auth/auth_exception.dart';
import 'package:flind_player/core/auth/auth_session.dart';
import 'package:flind_player/data/auth/auth_cookie_jar.dart';
import 'package:flind_player/data/auth/set_cookie_parser.dart';
import 'package:flind_player/data/sources/bilibili/bili_auth_models.dart';
import 'package:flind_player/data/sources/bilibili/bili_client.dart';
import 'package:flind_player/data/sources/bilibili/rate_limiter.dart';
import 'package:flind_player/data/sources/bilibili/risk_control.dart';

/// Bilibili's web QR login protocol.
///
/// The QR endpoints live on `passport.bilibili.com`; the profile endpoint is
/// the normal `api.bilibili.com` nav call. The driver writes the login cookies
/// into the shared [AuthCookieJar] before fetching the profile, so every
/// subsequent client request uses the account without extra wiring.
class BiliAuthDriver implements AuthDriver {
  BiliAuthDriver({
    required BiliClient client,
    required AuthCookieJar jar,
    RiskControl? riskControl,
    RateLimiter? rateLimiter,
  }) : _client = client, // ignore: prefer_initializing_formals
       _jar = jar, // ignore: prefer_initializing_formals
       _riskControl = riskControl, // ignore: prefer_initializing_formals
       _rateLimiter = rateLimiter; // ignore: prefer_initializing_formals

  static const String _generateUrl =
      'https://passport.bilibili.com/x/passport-login/web/qrcode/generate';
  static const String _pollUrl =
      'https://passport.bilibili.com/x/passport-login/web/qrcode/poll';
  static const Duration qrLifetime = Duration(seconds: 180);

  final BiliClient _client;
  final AuthCookieJar _jar;
  final RiskControl? _riskControl;
  final RateLimiter? _rateLimiter;
  bool _riskEnsured = false;

  @override
  String get sourceId => 'bilibili';

  @override
  String get displayName => 'bilibili';

  @override
  Set<AuthMethod> get methods => const <AuthMethod>{AuthMethod.qrCode};

  @override
  Future<AuthChallenge> begin(AuthMethod method) async {
    if (method != AuthMethod.qrCode) {
      throw const AuthException(
        AuthFailure.unknown,
        'Bilibili only supports QR login',
      );
    }
    try {
      await _ensureRiskCookie();
      final response = await _run(
        () => _client.getJsonWithResponse(_generateUrl),
      );
      final data = response.json['data'];
      if (data is! Map) {
        throw const AuthException(
          AuthFailure.invalidCredentials,
          'Bilibili QR response had no data',
        );
      }
      final generated = BiliQrGenerate.fromJson(
        Map<String, dynamic>.from(data),
      );
      return AuthChallenge(
        id: generated.key,
        method: AuthMethod.qrCode,
        qrContent: generated.url.toString(),
        expiresAt: DateTime.now().add(qrLifetime),
      );
    } on AuthException {
      rethrow;
    } catch (error) {
      throw _mapError(error, 'Could not start Bilibili login');
    }
  }

  @override
  Future<AuthPollResult> poll(AuthChallenge challenge) async {
    try {
      await _ensureRiskCookie();
      final response = await _run(
        () => _client.getJsonWithResponse(
          _pollUrl,
          query: <String, dynamic>{'qrcode_key': challenge.id},
        ),
      );
      final data = response.json['data'];
      if (data is! Map) {
        throw const AuthException(
          AuthFailure.invalidCredentials,
          'Bilibili QR poll had no data',
        );
      }
      final poll = BiliQrPoll.fromJson(
        Map<String, dynamic>.from(data),
        cookies: parseSetCookieHeaders(response.setCookies),
      );

      switch (poll.status) {
        case BiliQrStatus.pending:
          return const AuthPollResult.pending();
        case BiliQrStatus.scanned:
          return const AuthPollResult.scanned();
        case BiliQrStatus.expired:
          return const AuthPollResult.expired();
        case BiliQrStatus.success:
          return await _finishLogin(poll);
      }
    } on AuthException {
      rethrow;
    } catch (error) {
      throw _mapError(error, 'Bilibili login poll failed');
    }
  }

  Future<AuthPollResult> _finishLogin(BiliQrPoll poll) async {
    final cookies = Map<String, String>.from(poll.cookies);
    if ((cookies['SESSDATA'] ?? '').isEmpty) {
      // The QR success payload can carry the cookies as query parameters in
      // `data.url` (cross-domain handoff). Use them when Set-Cookie was not
      // exposed by the HTTP stack.
      final url = Uri.tryParse(poll.url ?? '');
      if (url != null) {
        for (final name in const <String>[
          'SESSDATA',
          'bili_jct',
          'DedeUserID',
          'DedeUserID__ckMd5',
          'sid',
        ]) {
          final value = url.queryParameters[name];
          if (value != null && value.isNotEmpty) cookies[name] = value;
        }
      }
    }
    if ((cookies['SESSDATA'] ?? '').isEmpty) {
      throw const AuthException(
        AuthFailure.invalidCredentials,
        'Bilibili did not return a SESSDATA cookie',
      );
    }

    _jar.merge(sourceId, cookies);
    try {
      final account = await _fetchAccount();
      final now = DateTime.now();
      final session = AuthSession(
        account: account.account,
        cookies: cookies,
        refreshToken: poll.refreshToken,
        signedInAt: now,
        lastValidatedAt: now,
      );
      return AuthPollResult.success(session);
    } catch (_) {
      _jar.clear(sourceId);
      rethrow;
    }
  }

  @override
  Future<void> cancel(AuthChallenge challenge) async {
    // Polling is owned by the UI; there is nothing server-side to cancel.
  }

  @override
  Future<AuthSession> validate(AuthSession session) async {
    final previous = _jar.cookiesFor(sourceId);
    _jar.replace(sourceId, session.cookies);
    try {
      final account = await _fetchAccount();
      return session.copyWith(
        account: account.account,
        lastValidatedAt: DateTime.now(),
      );
    } catch (error) {
      _jar.replace(sourceId, previous);
      throw _mapError(error, 'Could not validate the Bilibili session');
    }
  }

  @override
  Future<void> signOut(AuthSession session) async {
    _jar.clear(sourceId);
  }

  Future<void> _ensureRiskCookie() async {
    if (_riskEnsured) return;
    _riskEnsured = true;
    final risk = _riskControl;
    if (risk == null) return;
    final header = await _run(risk.cookieHeader);
    if (header.isNotEmpty) _client.setCookieHeader(header);
  }

  Future<T> _run<T>(Future<T> Function() action) {
    final limiter = _rateLimiter;
    return limiter == null ? action() : limiter.run(action);
  }

  Future<BiliNavAccount> _fetchAccount() async {
    final response = await _run(() => _client.getJson('/x/web-interface/nav'));
    final data = response['data'];
    if (data is! Map) {
      throw const AuthException(
        AuthFailure.invalidCredentials,
        'Bilibili nav response had no data',
      );
    }
    return BiliNavAccount.fromJson(Map<String, dynamic>.from(data));
  }

  AuthException _mapError(Object error, String fallback) {
    if (error is AuthException) return error;
    if (error is BiliApiException) {
      return switch (error.code) {
        -101 => const AuthException(
          AuthFailure.expired,
          'Bilibili login has expired',
        ),
        -352 || -412 => AuthException(
          AuthFailure.riskControl,
          'Bilibili risk control rejected the login request',
        ),
        _ => AuthException(AuthFailure.unknown, fallback),
      };
    }
    if (error is DioException) {
      return AuthException(AuthFailure.network, fallback);
    }
    return AuthException(AuthFailure.unknown, fallback);
  }
}
