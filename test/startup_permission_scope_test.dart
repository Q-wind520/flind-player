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

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:flind_player/platform/permissions/permission_providers.dart';
import 'package:flind_player/platform/permissions/permission_service.dart';

/// In-memory [PermissionBackend] that records every request and never touches a
/// platform channel.
class _RecordingPermissionBackend implements PermissionBackend {
  /// Every permission passed to [request], in call order.
  final List<AppPermission> requestCalls = <AppPermission>[];

  @override
  bool get requiresRuntimeRequest => true;

  @override
  Future<bool> isGranted(AppPermission permission) async => true;

  @override
  Future<bool> request(AppPermission permission) async {
    requestCalls.add(permission);
    return true;
  }

  @override
  Future<bool> isPermanentlyDenied(AppPermission permission) async => false;
}

Widget _scope(_RecordingPermissionBackend backend) {
  return ProviderScope(
    overrides: [
      permissionServiceProvider.overrideWithValue(
        PermissionService(backend: backend),
      ),
    ],
    child: const MaterialApp(
      home: StartupPermissionScope(child: Text('child')),
    ),
  );
}

void main() {
  testWidgets('asks for the audio-library permission once at launch', (
    tester,
  ) async {
    final backend = _RecordingPermissionBackend();

    await tester.pumpWidget(_scope(backend));
    await tester.pump();

    expect(backend.requestCalls, [AppPermission.audioLibrary]);
    expect(find.text('child'), findsOneWidget);
  });

  testWidgets('does not ask again when the scope rebuilds', (tester) async {
    final backend = _RecordingPermissionBackend();

    await tester.pumpWidget(_scope(backend));
    await tester.pump();
    await tester.pump();

    expect(backend.requestCalls, [AppPermission.audioLibrary]);
  });
}
