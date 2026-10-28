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

import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:flind_player/platform/single_instance/single_instance_guard.dart';

void main() {
  late Directory dir;

  setUp(() {
    dir = Directory.systemTemp.createTempSync('flind_single_instance');
  });

  tearDown(() {
    if (dir.existsSync()) {
      dir.deleteSync(recursive: true);
    }
  });

  SingleInstanceGuard guard() => SingleInstanceGuard(
    directory: dir,
    pollInterval: const Duration(milliseconds: 20),
  );

  test('a second launch asks the running instance to surface itself', () async {
    final primary = guard();
    addTearDown(primary.dispose);
    expect(await primary.tryAcquire(), isTrue);

    var activations = 0;
    primary.watch(() async => activations++);

    await guard().requestActivation();

    await Future<void>.delayed(const Duration(milliseconds: 200));
    expect(activations, 1);
  });

  test('a consumed request does not fire again on the next poll', () async {
    final primary = guard();
    addTearDown(primary.dispose);
    await primary.tryAcquire();

    var activations = 0;
    primary.watch(() async => activations++);

    await guard().requestActivation();
    await Future<void>.delayed(const Duration(milliseconds: 200));

    expect(activations, 1);
  });

  test('a later launch fires the callback again', () async {
    final primary = guard();
    addTearDown(primary.dispose);
    await primary.tryAcquire();

    var activations = 0;
    primary.watch(() async => activations++);

    await guard().requestActivation();
    await Future<void>.delayed(const Duration(milliseconds: 200));
    await guard().requestActivation();
    await Future<void>.delayed(const Duration(milliseconds: 200));

    expect(activations, 2);
  });

  test(
    'a second instance cannot take the lock away from the first',
    () async {
      final primary = guard();
      addTearDown(primary.dispose);
      expect(await primary.tryAcquire(), isTrue);

      final secondary = guard();
      addTearDown(secondary.dispose);
      expect(await secondary.tryAcquire(), isFalse);
    },
    skip: Platform.isWindows
        ? null
        : 'POSIX file locks belong to the process, not the file descriptor, '
              'so two guards inside one test process cannot exclude each '
              'other. The built app is launched twice to cover this.',
  );

  test('releasing the lock lets the next launch acquire it', () async {
    final primary = guard();
    await primary.tryAcquire();
    await primary.dispose();

    final next = guard();
    addTearDown(next.dispose);
    expect(await next.tryAcquire(), isTrue);
  });

  test('an unusable lock location lets the app start', () async {
    // A plain file where the guard expects its directory: nothing can be
    // locked, and refusing to start would strand the user.
    final blocked = File('${dir.path}/not-a-directory')..writeAsStringSync('x');

    final printed = <String>[];
    final previousDebugPrint = debugPrint;
    debugPrint = (String? message, {int? wrapWidth}) {
      if (message != null) {
        printed.add(message);
      }
    };
    addTearDown(() => debugPrint = previousDebugPrint);

    final guard = SingleInstanceGuard(
      directory: Directory(blocked.path),
      pollInterval: const Duration(milliseconds: 20),
    );
    addTearDown(guard.dispose);

    expect(await guard.tryAcquire(), isTrue);
    expect(printed, isNotEmpty);
  });
}
