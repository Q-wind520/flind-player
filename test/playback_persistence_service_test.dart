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

import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:flind_player/core/models/playback_queue.dart';
import 'package:flind_player/core/models/playback_state.dart';
import 'package:flind_player/core/models/repeat_mode.dart';
import 'package:flind_player/core/models/track.dart';
import 'package:flind_player/core/repositories/playback_snapshot_repository.dart';
import 'package:flind_player/core/services/playback_controller.dart';
import 'package:flind_player/core/sources/source_track_id.dart';
import 'package:flind_player/data/database/app_database.dart';
import 'package:flind_player/data/repositories/drift_playback_snapshot_repository.dart';
import 'package:flind_player/data/services/playback_persistence_service.dart';

/// Polls until [condition] is true, failing after [timeout].
Future<void> _waitFor(
  bool Function() condition, {
  Duration timeout = const Duration(seconds: 5),
}) async {
  final deadline = DateTime.now().add(timeout);
  while (!condition()) {
    if (DateTime.now().isAfter(deadline)) {
      fail('Timed out waiting for condition');
    }
    await Future<void>.delayed(const Duration(milliseconds: 5));
  }
}

/// A [PlaybackController] whose state is driven by the test.
///
/// `playQueue` models the real engine's load-then-autoplay so the service's
/// "restore paused" behaviour is actually exercised.
class _FakePlaybackController implements PlaybackController {
  final StreamController<PlaybackState> _states =
      StreamController<PlaybackState>.broadcast();

  PlaybackState _current = PlaybackState.idle;
  PlaybackQueue _queue = PlaybackQueue.empty;

  int playCalls = 0;
  int pauseCalls = 0;
  int playQueueCalls = 0;
  int? lastPlayQueueIndex;
  bool? lastAutoPlay;
  Duration? lastSeek;
  RepeatMode? lastRepeatMode;
  bool? lastShuffle;

  @override
  Stream<PlaybackState> get state => _states.stream;

  @override
  PlaybackState get currentState => _current;

  @override
  PlaybackQueue get queue => _queue;

  void setQueue(PlaybackQueue queue) => _queue = queue;

  void emit(PlaybackState state) {
    _current = state;
    _states.add(state);
  }

  @override
  Future<void> playQueue(
    PlaybackQueue queue, {
    int index = 0,
    bool autoPlay = true,
  }) async {
    playQueueCalls++;
    lastPlayQueueIndex = index;
    lastAutoPlay = autoPlay;
    _queue = queue.copyWith(currentIndex: index);
    _current = PlaybackState(
      isPlaying: autoPlay,
      isBuffering: false,
      isCompleted: false,
      position: Duration.zero,
      currentTrack: _queue.currentTrack,
      repeatMode: _current.repeatMode,
      shuffleEnabled: _current.shuffleEnabled,
    );
  }

  @override
  Future<void> play() async {
    playCalls++;
  }

  @override
  Future<void> pause() async {
    pauseCalls++;
    _current = _current.copyWith(isPlaying: false);
  }

  @override
  Future<void> togglePlayPause() async {}

  @override
  Future<void> next() async {}

  @override
  Future<void> previous() async {}

  @override
  Future<void> seek(Duration position) async {
    lastSeek = position;
  }

  @override
  Future<void> setRepeatMode(RepeatMode mode) async {
    lastRepeatMode = mode;
  }

  @override
  Future<void> setShuffle(bool enabled) async {
    lastShuffle = enabled;
  }

  @override
  Future<void> dispose() async {
    await _states.close();
  }
}

/// Wraps a repository, counting and recording writes.
class _RecordingSnapshotRepository implements PlaybackSnapshotRepository {
  _RecordingSnapshotRepository(this._inner);

  final PlaybackSnapshotRepository _inner;

  int saveCalls = 0;
  int clearCalls = 0;
  PlaybackSnapshot? lastSaved;

  @override
  Future<PlaybackSnapshot?> load() => _inner.load();

  @override
  Future<void> save(PlaybackSnapshot snapshot) async {
    saveCalls++;
    lastSaved = snapshot;
    await _inner.save(snapshot);
  }

  @override
  Future<void> clear() async {
    clearCalls++;
    await _inner.clear();
  }
}

/// A repository whose every operation fails, to prove failures are swallowed.
class _FailingSnapshotRepository implements PlaybackSnapshotRepository {
  @override
  Future<PlaybackSnapshot?> load() async => throw StateError('load boom');

  @override
  Future<void> save(PlaybackSnapshot snapshot) async =>
      throw StateError('save boom');

  @override
  Future<void> clear() async => throw StateError('clear boom');
}

Track _track(String path) => Track(
  source: 'local',
  sourceTrackId: LocalTrackId(path),
  uri: 'local:$path',
  title: path,
);

PlaybackQueue _queue(List<Track> tracks, {int index = 0}) => PlaybackQueue(
  tracks: tracks,
  currentIndex: index,
  originalOrder: List<int>.generate(tracks.length, (i) => i),
);

PlaybackState _state({
  bool isPlaying = false,
  Duration position = Duration.zero,
  Track? currentTrack,
  RepeatMode repeatMode = RepeatMode.off,
  bool shuffleEnabled = false,
}) => PlaybackState(
  isPlaying: isPlaying,
  isBuffering: false,
  isCompleted: false,
  position: position,
  currentTrack: currentTrack,
  repeatMode: repeatMode,
  shuffleEnabled: shuffleEnabled,
);

void main() {
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;

  late AppDatabase db;
  late _RecordingSnapshotRepository repository;
  late _FakePlaybackController controller;

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    repository = _RecordingSnapshotRepository(
      DriftPlaybackSnapshotRepository(db),
    );
    controller = _FakePlaybackController();
  });

  tearDown(() async {
    await controller.dispose();
    await db.close();
  });

  group('restore', () {
    test(
      'restores queue/index/position/repeat/shuffle without playing',
      () async {
        final queue = _queue([
          _track('/m/a.flac'),
          _track('/m/b.flac'),
          _track('/m/c.flac'),
        ], index: 1);
        final snapshot = PlaybackSnapshot(
          queue: queue,
          position: const Duration(seconds: 42),
          repeatMode: RepeatMode.all,
          shuffleEnabled: true,
        );
        await repository.save(snapshot);
        repository.saveCalls = 0;

        final service = PlaybackPersistenceService(
          playback: controller,
          repository: repository,
        );
        await service.restore();

        expect(controller.playQueueCalls, 1);
        expect(controller.lastPlayQueueIndex, 1);
        expect(controller.queue, queue);
        expect(controller.lastRepeatMode, RepeatMode.all);
        expect(controller.lastShuffle, isTrue);
        expect(controller.lastSeek, const Duration(seconds: 42));

        // Playback must be loaded WITHOUT producing sound: the controller is
        // asked for a silent load (autoPlay: false), never told to play, and no
        // pause workaround is needed.
        expect(controller.lastAutoPlay, isFalse);
        expect(controller.playCalls, 0);
        expect(controller.pauseCalls, 0);
        expect(controller.currentState.isPlaying, isFalse);

        await service.dispose();
      },
    );

    test('is a no-op when no snapshot was saved', () async {
      final service = PlaybackPersistenceService(
        playback: controller,
        repository: repository,
      );

      await service.restore();

      expect(controller.playQueueCalls, 0);
      expect(controller.pauseCalls, 0);
      await service.dispose();
    });
  });

  group('start', () {
    test('persists a track change immediately', () async {
      final service = PlaybackPersistenceService(
        playback: controller,
        repository: repository,
      );
      service.start();

      final queue = _queue([_track('/m/a.flac')]);
      controller.setQueue(queue);
      controller.emit(_state(currentTrack: queue.currentTrack));

      await _waitFor(() => repository.saveCalls == 1);
      expect(repository.lastSaved!.queue, queue);

      await service.dispose();
    });

    test(
      'persists play/pause, repeat and shuffle changes immediately',
      () async {
        final service = PlaybackPersistenceService(
          playback: controller,
          repository: repository,
        );
        service.start();

        final queue = _queue([_track('/m/a.flac')]);
        controller.setQueue(queue);
        controller.emit(_state(currentTrack: queue.currentTrack));
        await _waitFor(() => repository.saveCalls == 1);

        controller.emit(
          _state(isPlaying: true, currentTrack: queue.currentTrack),
        );
        await _waitFor(() => repository.saveCalls == 2);

        controller.emit(
          _state(currentTrack: queue.currentTrack, repeatMode: RepeatMode.all),
        );
        await _waitFor(() => repository.saveCalls == 3);

        controller.emit(
          _state(
            currentTrack: queue.currentTrack,
            repeatMode: RepeatMode.all,
            shuffleEnabled: true,
          ),
        );
        await _waitFor(() => repository.saveCalls == 4);
        expect(repository.lastSaved!.shuffleEnabled, isTrue);

        await service.dispose();
      },
    );

    test(
      'throttles rapid position-only ticks to one write per window',
      () async {
        var now = DateTime(2026, 1, 1);
        final service = PlaybackPersistenceService(
          playback: controller,
          repository: repository,
          throttle: const Duration(seconds: 5),
          clock: () => now,
        );
        service.start();

        final track = _track('/m/a.flac');
        final queue = _queue([track]);
        controller.setQueue(queue);
        controller.emit(_state(position: Duration.zero, currentTrack: track));
        await _waitFor(() => repository.saveCalls == 1);
        final baseline = repository.saveCalls;

        // Five rapid ticks within one window: only the first writes.
        for (var i = 1; i <= 5; i++) {
          controller.emit(
            _state(
              isPlaying: true,
              position: Duration(milliseconds: 200 * i),
              currentTrack: track,
            ),
          );
        }
        await Future<void>.delayed(const Duration(milliseconds: 20));
        expect(repository.saveCalls, baseline + 1);

        // Once the window elapses, the next tick writes again.
        now = now.add(const Duration(seconds: 6));
        controller.emit(
          _state(
            isPlaying: true,
            position: const Duration(milliseconds: 1400),
            currentTrack: track,
          ),
        );
        await _waitFor(() => repository.saveCalls == baseline + 2);

        await service.dispose();
      },
    );

    test('emptying the queue clears the snapshot', () async {
      final service = PlaybackPersistenceService(
        playback: controller,
        repository: repository,
      );
      service.start();

      final queue = _queue([_track('/m/a.flac')]);
      controller.setQueue(queue);
      controller.emit(_state(currentTrack: queue.currentTrack));
      await _waitFor(() => repository.saveCalls == 1);
      expect(await repository.load(), isNotNull);

      controller.setQueue(PlaybackQueue.empty);
      controller.emit(_state());

      await _waitFor(() => repository.clearCalls == 1);
      expect(await repository.load(), isNull);

      await service.dispose();
    });
  });

  group('failure isolation', () {
    test('repository failures never throw out of the service', () async {
      final failing = _FailingSnapshotRepository();
      final service = PlaybackPersistenceService(
        playback: controller,
        repository: failing,
      );

      // load() throws: restore must swallow it.
      await expectLater(service.restore(), completes);

      service.start();
      final track = _track('/m/a.flac');
      controller.setQueue(_queue([track]));
      controller.emit(_state(currentTrack: track));
      controller.emit(_state(isPlaying: true, currentTrack: track));

      // save() throws: the fire-and-forget write must be caught.
      await Future<void>.delayed(const Duration(milliseconds: 20));

      // clear() throws: emptying the queue must still be caught.
      controller.setQueue(PlaybackQueue.empty);
      controller.emit(_state());
      await Future<void>.delayed(const Duration(milliseconds: 20));

      await service.dispose();
    });
  });
}
