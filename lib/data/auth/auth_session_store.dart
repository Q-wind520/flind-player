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

import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import 'package:flind_player/core/auth/auth_session.dart';

/// Persistence boundary for signed-in sessions.
///
/// One session per source. Implementations must treat [AuthSession.cookies] as
/// a bearer credential and may never write it to plain preferences.
abstract interface class AuthSessionStore {
  Future<AuthSession?> read(String sourceId);
  Future<void> write(AuthSession session);
  Future<void> delete(String sourceId);
}

/// [AuthSessionStore] backed by the platform keychain.
///
/// Values are versioned JSON under `flind.auth.<sourceId>`; a corrupt or
/// older-version value is treated as signed out instead of blocking startup.
class SecureAuthSessionStore implements AuthSessionStore {
  SecureAuthSessionStore({
    FlutterSecureStorage? storage,
    this.keyPrefix = 'flind.auth.',
  }) : _storage =
           storage ??
           const FlutterSecureStorage(
             aOptions: AndroidOptions(),
             iOptions: IOSOptions(
               accessibility: KeychainAccessibility.first_unlock_this_device,
             ),
             mOptions: MacOsOptions(
               accessibility: KeychainAccessibility.first_unlock_this_device,
             ),
           );

  static const int _version = 1;

  final FlutterSecureStorage _storage;
  final String keyPrefix;

  String _keyFor(String sourceId) => '$keyPrefix$sourceId';

  @override
  Future<AuthSession?> read(String sourceId) async {
    final key = _keyFor(sourceId);
    String? raw;
    try {
      raw = await _storage.read(key: key);
    } catch (error) {
      debugPrint('AuthSessionStore: read failed for $sourceId: $error');
      return null;
    }
    if (raw == null || raw.isEmpty) return null;

    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map) return null;
      final envelope = Map<String, dynamic>.from(decoded);
      if ((envelope['v'] as num?)?.toInt() != _version) return null;
      final session = envelope['session'];
      if (session is! Map) return null;
      return AuthSession.fromJson(Map<String, dynamic>.from(session));
    } catch (_) {
      // A corrupt value is indistinguishable from a signed-out source; drop it
      // and let the user sign in again rather than blocking startup.
      await delete(sourceId);
      return null;
    }
  }

  @override
  Future<void> write(AuthSession session) async {
    final raw = jsonEncode(<String, dynamic>{
      'v': _version,
      'session': session.toJson(),
    });
    await _storage.write(key: _keyFor(session.account.sourceId), value: raw);
  }

  @override
  Future<void> delete(String sourceId) async {
    try {
      await _storage.delete(key: _keyFor(sourceId));
    } catch (error) {
      debugPrint('AuthSessionStore: delete failed for $sourceId: $error');
    }
  }
}
