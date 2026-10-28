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

import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;

/// Keeps Flind Player to one process per user and lets a later launch reach
/// the instance that is already running.
///
/// A desktop session owns several per-user singletons — the drift database,
/// the cache directories, the audio output and the tray icon — so a second
/// process opening them concurrently corrupts state and fights the first one
/// for all of them.
///
/// The protocol is two files in [directory] (the application support
/// directory, which is per user):
///
/// * the lock file, held with an exclusive OS lock for the life of the
///   process. The kernel drops the lock when the process dies, so a crashed
///   run can never leave a stale lock behind;
/// * the request file, written by a launch that could not take the lock and
///   consumed by the running instance, which surfaces its window in response.
///
/// Watching is driven by a [Timer.periodic] poll because `dart:io` offers no
/// portable way to wait on a file change across platforms.
///
/// Every operation fails open: an unusable directory, a filesystem that
/// cannot lock, or an unexpected platform error lets the app start instead of
/// refusing to run. See `main.dart` for the wiring.
class SingleInstanceGuard {
  /// Creates a guard that keeps its files in [directory].
  ///
  /// [pollInterval] is how often the running instance looks for an activation
  /// request; tests shorten it.
  SingleInstanceGuard({
    required this.directory,
    this.pollInterval = const Duration(milliseconds: 500),
  });

  /// The directory holding the lock and request files.
  final Directory directory;

  /// How often a running instance looks for an activation request.
  final Duration pollInterval;

  /// The name of the file whose OS lock identifies the running instance.
  static const String lockFileName = 'single_instance.lock';

  /// The name of the file a blocked launch uses to request activation.
  static const String requestFileName = 'single_instance.activate';

  RandomAccessFile? _lock;
  Timer? _timer;
  bool _polling = false;

  /// The file whose OS lock marks this process as the running instance.
  File get lockFile => File(p.join(directory.path, lockFileName));

  /// The file a blocked launch writes to ask the running instance to surface.
  File get requestFile => File(p.join(directory.path, requestFileName));

  /// Takes the instance lock.
  ///
  /// Returns `true` when this process may run: either it now holds the lock,
  /// or the lock could not be used at all. Returns `false` only when another
  /// live process holds it.
  Future<bool> tryAcquire() async {
    if (_lock != null) {
      return true;
    }
    RandomAccessFile file;
    try {
      await directory.create(recursive: true);
      file = await lockFile.open(mode: FileMode.append);
    } catch (error, stackTrace) {
      debugPrint(
        'SingleInstanceGuard: cannot open the lock file: $error\n$stackTrace',
      );
      return true;
    }
    try {
      await file.lock(FileLock.exclusive);
    } catch (error, stackTrace) {
      await _close(file);
      debugPrint(
        'SingleInstanceGuard: another instance holds the lock: '
        '$error\n$stackTrace',
      );
      return false;
    }
    _lock = file;
    return true;
  }

  /// Leaves an activation request for the instance that holds the lock.
  Future<void> requestActivation() async {
    try {
      await directory.create(recursive: true);
      await requestFile.writeAsString(
        '${DateTime.now().microsecondsSinceEpoch}',
        flush: true,
      );
    } catch (error, stackTrace) {
      debugPrint(
        'SingleInstanceGuard: cannot request activation: $error\n$stackTrace',
      );
    }
  }

  /// Calls [onActivate] whenever a later launch asks this instance to surface.
  ///
  /// Calling this more than once keeps the first watcher.
  void watch(Future<void> Function() onActivate) {
    if (_timer != null) {
      return;
    }
    _timer = Timer.periodic(pollInterval, (_) => unawaited(_poll(onActivate)));
  }

  /// Stops watching and releases the lock.
  Future<void> dispose() async {
    _timer?.cancel();
    _timer = null;
    final lock = _lock;
    _lock = null;
    if (lock != null) {
      await _close(lock);
    }
  }

  Future<void> _poll(Future<void> Function() onActivate) async {
    if (_polling) {
      return;
    }
    _polling = true;
    try {
      if (await _consumeRequest()) {
        await onActivate();
      }
    } catch (error, stackTrace) {
      debugPrint('SingleInstanceGuard: activation failed: $error\n$stackTrace');
    } finally {
      _polling = false;
    }
  }

  Future<bool> _consumeRequest() async {
    try {
      if (!await requestFile.exists()) {
        return false;
      }
      await requestFile.delete();
      return true;
    } on FileSystemException catch (error) {
      debugPrint('SingleInstanceGuard: cannot consume the request: $error');
      return false;
    }
  }

  Future<void> _close(RandomAccessFile file) async {
    try {
      await file.close();
    } catch (error) {
      debugPrint('SingleInstanceGuard: cannot close the lock file: $error');
    }
  }
}
