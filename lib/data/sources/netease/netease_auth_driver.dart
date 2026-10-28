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
import 'package:flind_player/data/sources/netease/netease_auth_models.dart';
import 'package:flind_player/data/sources/netease/netease_client.dart';
import 'package:flind_player/data/sources/bilibili/rate_limiter.dart';

/// NetEase's web QR login protocol.
class NeteaseAuthDriver implements AuthDriver {
  NeteaseAuthDriver({
    required NeteaseClient client,
    required AuthCookieJar jar,
    RateLimiter? rateLimiter,
  }) : _client = client, // ignore: prefer_initializing_formals
       _jar = jar, // ignore: prefer_initializing_formals
       _rateLimiter = rateLimiter; // ignore: prefer_initializing_formals

  static const String _unikeyPath = '/api/login/qrcode/unikey';
  static const String _pollPath = '/api/login/qrcode/client/login';
  static const String _accountPath = '/api/nuser/account/get';
  static const Duration qrLifetime = Duration(seconds: 180);

  final NeteaseClient _client;
  final AuthCookieJar _jar;
  final RateLimiter? _rateLimiter;

  @override
  String get sourceId => 'netease';

  @override
  String get displayName => '网易云音乐';

  @override
  Set<AuthMethod> get methods => const <AuthMethod>{AuthMethod.qrCode};

  @override
  Future<AuthChallenge> begin(AuthMethod method) async {
    if (method != AuthMethod.qrCode) {
      throw const NeteaseAuthException('NetEase only supports QR login');
    }
    try {
      final response = await _run(
        () => _client.getJsonWithResponse(
          _unikeyPath,
          query: <String, dynamic>{'type': 1},
        ),
      );
      final generated = NeteaseQrGenerate.fromJson(response.json);
      return AuthChallenge(
        id: generated.unikey,
        method: AuthMethod.qrCode,
        qrContent: 'https://music.163.com/login?codekey=${generated.unikey}',
        expiresAt: DateTime.now().add(qrLifetime),
      );
    } on AuthException {
      rethrow;
    } catch (error) {
      throw _mapError(error, 'Could not start NetEase login');
    }
  }

  @override
  Future<AuthPollResult> poll(AuthChallenge challenge) async {
    try {
      final response = await _run(
        () => _client.getJsonWithResponse(
          _pollPath,
          query: <String, dynamic>{'key': challenge.id, 'type': 1},
          allowCodes: const <int>{800, 801, 802, 803},
        ),
      );
      final cookies = <String, String>{
        ...parseSetCookieHeaders(response.setCookies),
        ...parseCookieHeader(response.json['cookie'] as String? ?? ''),
      };
      final poll = NeteaseQrPoll.fromJson(response.json, cookies: cookies);

      switch (poll.status) {
        case NeteaseQrStatus.pending:
          return const AuthPollResult.pending();
        case NeteaseQrStatus.scanned:
          return const AuthPollResult.scanned();
        case NeteaseQrStatus.expired:
          return const AuthPollResult.expired();
        case NeteaseQrStatus.success:
          return await _finishLogin(poll);
      }
    } on AuthException {
      rethrow;
    } catch (error) {
      throw _mapError(error, 'NetEase login poll failed');
    }
  }

  Future<AuthPollResult> _finishLogin(NeteaseQrPoll poll) async {
    if ((poll.cookies['MUSIC_U'] ?? '').isEmpty) {
      throw const NeteaseAuthException(
        'NetEase did not return a MUSIC_U cookie',
        kind: AuthFailure.invalidCredentials,
      );
    }

    _jar.replace(sourceId, poll.cookies);
    try {
      final profile = await _fetchProfile();
      final now = DateTime.now();
      return AuthPollResult.success(
        AuthSession(
          account: profile.account,
          cookies: poll.cookies,
          signedInAt: now,
          lastValidatedAt: now,
        ),
      );
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
      final profile = await _fetchProfile();
      return session.copyWith(
        account: profile.account,
        lastValidatedAt: DateTime.now(),
      );
    } catch (error) {
      _jar.replace(sourceId, previous);
      throw _mapError(error, 'Could not validate the NetEase session');
    }
  }

  @override
  Future<void> signOut(AuthSession session) async {
    _jar.clear(sourceId);
  }

  Future<T> _run<T>(Future<T> Function() action) {
    final limiter = _rateLimiter;
    return limiter == null ? action() : limiter.run(action);
  }

  Future<NeteaseProfile> _fetchProfile() async {
    final response = await _run(() => _client.getJson(_accountPath));
    return NeteaseProfile.fromJson(response);
  }

  AuthException _mapError(Object error, String fallback) {
    if (error is AuthException) return error;
    if (error is NeteaseApiException) {
      return switch (error.code) {
        301 || -462 => const NeteaseAuthException(
          'NetEase login has expired',
          kind: AuthFailure.expired,
        ),
        _ => NeteaseAuthException(fallback),
      };
    }
    if (error is DioException) {
      return NeteaseAuthException(fallback, kind: AuthFailure.network);
    }
    return NeteaseAuthException(fallback);
  }
}
