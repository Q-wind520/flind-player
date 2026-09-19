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

import 'package:flutter_test/flutter_test.dart';

import 'package:flind_player/core/models/playback_queue.dart';
import 'package:flind_player/core/models/playback_state.dart';
import 'package:flind_player/core/models/repeat_mode.dart';
import 'package:flind_player/core/services/playback_controller.dart';
import 'package:flind_player/platform/tray/tray_service.dart';

import 'support/l10n.dart';

/// A [PlaybackController] that records transport calls; no engine is built.
class _FakePlaybackController implements PlaybackController {
  final StreamController<PlaybackState> _states =
      StreamController<PlaybackState>.broadcast();

  final PlaybackState _current = PlaybackState.idle;
  final PlaybackQueue _queue = PlaybackQueue.empty;

  int togglePlayPauseCalls = 0;
  int playCalls = 0;
  int pauseCalls = 0;
  int nextCalls = 0;
  int previousCalls = 0;

  int get totalCalls =>
      togglePlayPauseCalls + playCalls + pauseCalls + nextCalls + previousCalls;

  @override
  Stream<PlaybackState> get state => _states.stream;

  @override
  PlaybackState get currentState => _current;

  @override
  PlaybackQueue get queue => _queue;

  @override
  Future<void> togglePlayPause() async {
    togglePlayPauseCalls++;
  }

  @override
  Future<void> play() async {
    playCalls++;
  }

  @override
  Future<void> pause() async {
    pauseCalls++;
  }

  @override
  Future<void> next() async {
    nextCalls++;
  }

  @override
  Future<void> previous() async {
    previousCalls++;
  }

  @override
  Future<void> playQueue(
    PlaybackQueue queue, {
    int index = 0,
    bool autoPlay = true,
  }) async {}

  @override
  Future<void> updateTrackCover(
    String uri, {
    String? coverPath,
    String? coverUrl,
  }) async {}

  @override
  Future<void> seek(Duration position) async {}

  @override
  Future<void> setRepeatMode(RepeatMode mode) async {}

  @override
  Future<void> setShuffle(bool enabled) async {}

  @override
  Future<void> dispose() async {
    await _states.close();
  }
}

void main() {
  group('trayPlayPauseLabel', () {
    test('shows 暂停 while playing', () {
      expect(trayPlayPauseLabel(testL10n(), true), '暂停');
    });

    test('shows 播放 while paused', () {
      expect(trayPlayPauseLabel(testL10n(), false), '播放');
    });
  });

  group('trayMenuActionForKey', () {
    test('maps the window toggle using visibility', () {
      expect(
        trayMenuActionForKey(trayMenuKeyWindowToggle, isWindowVisible: false),
        TrayMenuAction.showWindow,
      );
      expect(
        trayMenuActionForKey(trayMenuKeyWindowToggle, isWindowVisible: true),
        TrayMenuAction.hideWindow,
      );
    });

    test('maps the transport and quit entries', () {
      expect(
        trayMenuActionForKey(trayMenuKeyPlayPause, isWindowVisible: false),
        TrayMenuAction.togglePlayPause,
      );
      expect(
        trayMenuActionForKey(trayMenuKeyPrevious, isWindowVisible: false),
        TrayMenuAction.previous,
      );
      expect(
        trayMenuActionForKey(trayMenuKeyNext, isWindowVisible: false),
        TrayMenuAction.next,
      );
      expect(
        trayMenuActionForKey(trayMenuKeyQuit, isWindowVisible: false),
        TrayMenuAction.quit,
      );
    });

    test('returns null for an unknown key', () {
      expect(trayMenuActionForKey('nope', isWindowVisible: false), isNull);
    });
  });

  group('handleTrayMenuAction', () {
    late _FakePlaybackController controller;
    late int showCalls;
    late int hideCalls;
    late int quitCalls;

    setUp(() {
      controller = _FakePlaybackController();
      showCalls = 0;
      hideCalls = 0;
      quitCalls = 0;
    });

    tearDown(() async {
      await controller.dispose();
    });

    Future<void> dispatch(TrayMenuAction action) {
      return handleTrayMenuAction(
        action,
        controller,
        showWindow: () => showCalls++,
        hideWindow: () => hideCalls++,
        quit: () => quitCalls++,
      );
    }

    test('togglePlayPause delegates to the controller', () async {
      await dispatch(TrayMenuAction.togglePlayPause);

      expect(controller.togglePlayPauseCalls, 1);
      expect(controller.totalCalls, 1);
      expect(showCalls, 0);
      expect(hideCalls, 0);
      expect(quitCalls, 0);
    });

    test('previous delegates to the controller', () async {
      await dispatch(TrayMenuAction.previous);

      expect(controller.previousCalls, 1);
      expect(controller.totalCalls, 1);
      expect(quitCalls, 0);
    });

    test('next delegates to the controller', () async {
      await dispatch(TrayMenuAction.next);

      expect(controller.nextCalls, 1);
      expect(controller.totalCalls, 1);
      expect(quitCalls, 0);
    });

    test('showWindow calls the show callback only', () async {
      await dispatch(TrayMenuAction.showWindow);

      expect(showCalls, 1);
      expect(hideCalls, 0);
      expect(controller.totalCalls, 0);
      expect(quitCalls, 0);
    });

    test('hideWindow calls the hide callback only', () async {
      await dispatch(TrayMenuAction.hideWindow);

      expect(hideCalls, 1);
      expect(showCalls, 0);
      expect(controller.totalCalls, 0);
      expect(quitCalls, 0);
    });

    test(
      'quit calls the quit callback once and touches no controller',
      () async {
        await dispatch(TrayMenuAction.quit);

        expect(quitCalls, 1);
        expect(controller.totalCalls, 0);
        expect(showCalls, 0);
        expect(hideCalls, 0);
      },
    );
  });
}
