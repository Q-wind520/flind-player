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
import 'package:permission_handler/permission_handler.dart';

/// A runtime permission the app may need.
enum AppPermission {
  /// Read the user's local audio files.
  ///
  /// Android 13+ (API 33) gates this behind `READ_MEDIA_AUDIO`; older releases
  /// use the legacy `READ_EXTERNAL_STORAGE`.
  audioLibrary,

  /// Post the media playback notification (`POST_NOTIFICATIONS`, Android 13+).
  notifications,
}

/// The outcome of asking for one [AppPermission].
enum PermissionResult {
  granted,
  denied,

  /// The user rejected the prompt and the OS will no longer show it; the
  /// permission must be enabled from system settings.
  permanentlyDenied,
}

/// The raw platform permission operations.
///
/// Injectable so [PermissionService] and its callers can be tested without
/// touching a platform channel.
abstract interface class PermissionBackend {
  /// Whether the current platform gates these permissions at runtime.
  ///
  /// Desktop and web return `false`; [PermissionService] is then a no-op that
  /// reports everything as granted.
  bool get requiresRuntimeRequest;

  /// Whether [permission] is granted, without prompting.
  Future<bool> isGranted(AppPermission permission);

  /// Prompts for [permission] and reports whether it is now granted.
  Future<bool> request(AppPermission permission);

  /// Whether [permission] can no longer be requested and must be enabled from
  /// system settings.
  Future<bool> isPermanentlyDenied(AppPermission permission);
}

/// Requests the app's runtime permissions.
///
/// Everything is guarded: a platform failure is reported as "not granted"
/// instead of being thrown at the caller.
class PermissionService {
  PermissionService({this.backend = const PermissionHandlerBackend()});

  /// The platform operations this service delegates to.
  final PermissionBackend backend;

  /// Requests [permissions] and reports whether each one is now granted.
  ///
  /// A no-op returning `true` for every entry on desktop/web.
  Future<Map<AppPermission, bool>> request(
    Set<AppPermission> permissions,
  ) async {
    final result = <AppPermission, bool>{};
    for (final permission in permissions) {
      result[permission] = backend.requiresRuntimeRequest
          ? await _safe(() => backend.request(permission))
          : true;
    }
    return result;
  }

  /// Whether [permission] is currently granted, without prompting.
  Future<bool> isGranted(AppPermission permission) {
    if (!backend.requiresRuntimeRequest) return Future<bool>.value(true);
    return _safe(() => backend.isGranted(permission));
  }

  /// Whether [permission] was permanently denied.
  Future<bool> isPermanentlyDenied(AppPermission permission) {
    if (!backend.requiresRuntimeRequest) return Future<bool>.value(false);
    return _safe(() => backend.isPermanentlyDenied(permission));
  }

  Future<bool> _safe(Future<bool> Function() action) async {
    try {
      return await action();
    } catch (error, stackTrace) {
      debugPrint('PermissionService: request failed: $error\n$stackTrace');
      return false;
    }
  }
}

/// Decides *when* the app asks for permissions.
///
/// Screens call this instead of `permission_handler` directly, so the
/// "ask when first needed, once" policy lives in one documented place.
class PermissionCoordinator {
  PermissionCoordinator(this._service);

  final PermissionService _service;

  bool _audioLibraryGranted = false;
  bool _notificationsRequested = false;

  /// Asks for the audio-library permission the first time the user scans or
  /// imports local files. Once granted it is never requested again.
  Future<PermissionResult> ensureAudioLibrary() async {
    if (_audioLibraryGranted) return PermissionResult.granted;
    final result = await _request(AppPermission.audioLibrary);
    if (result == PermissionResult.granted) {
      _audioLibraryGranted = true;
    }
    return result;
  }

  /// Asks for the notification permission once, after the first successful
  /// playback start.
  Future<void> requestNotificationsAfterPlayback() async {
    if (_notificationsRequested) return;
    _notificationsRequested = true;
    await _service.request(const {AppPermission.notifications});
  }

  Future<PermissionResult> _request(AppPermission permission) async {
    final granted = (await _service.request({permission}))[permission] ?? false;
    if (granted) return PermissionResult.granted;
    final permanent = await _service.isPermanentlyDenied(permission);
    return permanent
        ? PermissionResult.permanentlyDenied
        : PermissionResult.denied;
  }
}

/// A user-facing Chinese message explaining a denied [permission].
String permissionDeniedMessage(
  AppPermission permission, {
  required bool permanentlyDenied,
}) {
  final label = switch (permission) {
    AppPermission.audioLibrary => '访问本地音乐',
    AppPermission.notifications => '发送播放通知',
  };
  return permanentlyDenied ? '$label权限已被拒绝，请在系统设置中开启' : '需要$label权限才能继续';
}

/// [PermissionBackend] backed by the real `permission_handler` plugin.
class PermissionHandlerBackend implements PermissionBackend {
  const PermissionHandlerBackend();

  @override
  bool get requiresRuntimeRequest =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

  @override
  Future<bool> isGranted(AppPermission permission) async {
    switch (permission) {
      case AppPermission.audioLibrary:
        if ((await Permission.audio.status).isGranted) return true;
        return (await Permission.storage.status).isGranted;
      case AppPermission.notifications:
        return (await Permission.notification.status).isGranted;
    }
  }

  @override
  Future<bool> request(AppPermission permission) async {
    switch (permission) {
      case AppPermission.audioLibrary:
        // Android 13+ (API 33+): the granular audio media permission.
        final audio = await Permission.audio.request();
        if (audio.isGranted) return true;
        // Below Android 13 `Permission.audio` is unknown and resolves to
        // denied without prompting, so fall back to legacy storage access.
        return (await Permission.storage.request()).isGranted;
      case AppPermission.notifications:
        return (await Permission.notification.request()).isGranted;
    }
  }

  @override
  Future<bool> isPermanentlyDenied(AppPermission permission) async {
    switch (permission) {
      case AppPermission.audioLibrary:
        if ((await Permission.audio.status).isPermanentlyDenied) return true;
        return (await Permission.storage.status).isPermanentlyDenied;
      case AppPermission.notifications:
        return (await Permission.notification.status).isPermanentlyDenied;
    }
  }
}
