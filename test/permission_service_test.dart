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

import 'package:flutter_test/flutter_test.dart';

import 'package:flind_player/platform/permissions/permission_service.dart';

import 'support/l10n.dart';

/// In-memory [PermissionBackend] that never touches a platform channel.
class _FakePermissionBackend implements PermissionBackend {
  _FakePermissionBackend({
    this.requiresRuntimeRequest = true,
    this.granted = true,
    this.permanent = false,
    this.throws = false,
  });

  @override
  final bool requiresRuntimeRequest;
  final bool granted;
  final bool permanent;
  final bool throws;

  /// Every permission passed to [request], in call order.
  final List<AppPermission> requestCalls = <AppPermission>[];

  @override
  Future<bool> isGranted(AppPermission permission) async {
    if (throws) throw StateError('platform unavailable');
    return granted;
  }

  @override
  Future<bool> request(AppPermission permission) async {
    requestCalls.add(permission);
    if (throws) throw StateError('platform unavailable');
    return granted;
  }

  @override
  Future<bool> isPermanentlyDenied(AppPermission permission) async {
    if (throws) throw StateError('platform unavailable');
    return permanent;
  }
}

void main() {
  group('PermissionService: desktop is a no-op', () {
    test(
      'reports every permission granted without calling the backend',
      () async {
        final backend = _FakePermissionBackend(
          requiresRuntimeRequest: false,
          throws: true,
        );
        final service = PermissionService(backend: backend);

        final result = await service.request({
          AppPermission.audioLibrary,
          AppPermission.notifications,
        });

        expect(result, {
          AppPermission.audioLibrary: true,
          AppPermission.notifications: true,
        });
        expect(backend.requestCalls, isEmpty);
        expect(await service.isGranted(AppPermission.audioLibrary), isTrue);
        expect(
          await service.isPermanentlyDenied(AppPermission.notifications),
          isFalse,
        );
      },
    );
  });

  group('PermissionService: Android', () {
    test('a granted request reports true', () async {
      final backend = _FakePermissionBackend(granted: true);
      final service = PermissionService(backend: backend);

      final result = await service.request({AppPermission.audioLibrary});

      expect(result[AppPermission.audioLibrary], isTrue);
      expect(backend.requestCalls, [AppPermission.audioLibrary]);
    });

    test('a denied request reports false', () async {
      final backend = _FakePermissionBackend(granted: false);
      final service = PermissionService(backend: backend);

      final result = await service.request({AppPermission.notifications});

      expect(result[AppPermission.notifications], isFalse);
    });

    test('a platform exception is swallowed into false', () async {
      final backend = _FakePermissionBackend(throws: true);
      final service = PermissionService(backend: backend);

      final result = await service.request({AppPermission.audioLibrary});

      expect(result[AppPermission.audioLibrary], isFalse);
      expect(await service.isGranted(AppPermission.audioLibrary), isFalse);
    });

    test('a permanently denied permission is reported', () async {
      final backend = _FakePermissionBackend(granted: false, permanent: true);
      final service = PermissionService(backend: backend);

      expect(
        await service.isPermanentlyDenied(AppPermission.audioLibrary),
        isTrue,
      );
    });

    test('only the requested permissions are asked for', () async {
      final backend = _FakePermissionBackend();
      final service = PermissionService(backend: backend);

      final result = await service.request({AppPermission.notifications});

      expect(result.keys, [AppPermission.notifications]);
      expect(backend.requestCalls, [AppPermission.notifications]);
    });
  });

  group('PermissionCoordinator', () {
    test('requests the audio library once and caches a grant', () async {
      final backend = _FakePermissionBackend(granted: true);
      final coordinator = PermissionCoordinator(
        PermissionService(backend: backend),
      );

      expect(await coordinator.ensureAudioLibrary(), PermissionResult.granted);
      expect(await coordinator.ensureAudioLibrary(), PermissionResult.granted);
      expect(backend.requestCalls, [AppPermission.audioLibrary]);
    });

    test('reports a permanent denial', () async {
      final backend = _FakePermissionBackend(granted: false, permanent: true);
      final coordinator = PermissionCoordinator(
        PermissionService(backend: backend),
      );

      expect(
        await coordinator.ensureAudioLibrary(),
        PermissionResult.permanentlyDenied,
      );
    });

    test('reports a soft denial', () async {
      final backend = _FakePermissionBackend(granted: false);
      final coordinator = PermissionCoordinator(
        PermissionService(backend: backend),
      );

      expect(await coordinator.ensureAudioLibrary(), PermissionResult.denied);
    });

    test('requests notifications at most once after playback', () async {
      final backend = _FakePermissionBackend();
      final coordinator = PermissionCoordinator(
        PermissionService(backend: backend),
      );

      await coordinator.requestNotificationsAfterPlayback();
      await coordinator.requestNotificationsAfterPlayback();

      expect(backend.requestCalls, [AppPermission.notifications]);
    });
  });

  group('permissionDeniedMessage', () {
    final l10n = testL10n();

    test('soft denial asks for the permission', () {
      expect(
        permissionDeniedMessage(
          l10n,
          AppPermission.audioLibrary,
          permanentlyDenied: false,
        ),
        contains('访问本地音乐'),
      );
    });

    test('permanent denial points at system settings', () {
      expect(
        permissionDeniedMessage(
          l10n,
          AppPermission.notifications,
          permanentlyDenied: true,
        ),
        contains('系统设置'),
      );
    });
  });
}
