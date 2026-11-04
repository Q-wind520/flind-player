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

import 'package:flind_player/core/models/playback_state.dart';
import 'package:flind_player/data/services/playback_volume_persistence_service.dart';

import 'support/fake_playback_controller.dart';
import 'support/fake_settings_repository.dart';

class _VolumeController extends FakePlaybackController {
  final _states = StreamController<PlaybackState>.broadcast(sync: true);
  PlaybackState _state = PlaybackState.idle.copyWith(volume: 1.0);

  @override
  Stream<PlaybackState> get state => _states.stream;

  @override
  PlaybackState get currentState => _state;

  @override
  Future<void> setVolume(double volume) async {
    final clamped = volume.clamp(0.01, 1.4).toDouble();
    _state = _state.copyWith(volume: clamped);
    _states.add(_state);
  }

  Future<void> close() => _states.close();
}

void main() {
  late _VolumeController controller;
  late FakeSettingsRepository settings;

  setUp(() {
    controller = _VolumeController();
    settings = FakeSettingsRepository();
  });

  tearDown(() async {
    await controller.close();
  });

  test('restore applies the persisted volume', () async {
    settings.volume = 0.42;
    final service = PlaybackVolumePersistenceService(
      playback: controller,
      settings: settings,
      debounce: const Duration(milliseconds: 5),
    );
    addTearDown(service.dispose);

    await service.restore();

    expect(controller.currentState.volume, 0.42);
  });

  test('persists volume changes after the debounce', () async {
    final service = PlaybackVolumePersistenceService(
      playback: controller,
      settings: settings,
      debounce: const Duration(milliseconds: 5),
    );
    addTearDown(service.dispose);
    await service.restore();
    service.start();

    await controller.setVolume(0.7);
    await Future<void>.delayed(const Duration(milliseconds: 30));

    expect(settings.volume, 0.7);
  });

  test('dispose flushes a pending change', () async {
    final service = PlaybackVolumePersistenceService(
      playback: controller,
      settings: settings,
      debounce: const Duration(seconds: 30),
    );
    await service.restore();
    service.start();

    await controller.setVolume(0.55);
    await service.dispose();

    expect(settings.volume, 0.55);
  });

  test('unchanged volume ticks do not rewrite the preference', () async {
    final service = PlaybackVolumePersistenceService(
      playback: controller,
      settings: settings,
      debounce: const Duration(milliseconds: 5),
    );
    addTearDown(service.dispose);
    await service.restore();
    service.start();

    await controller.setVolume(1.0);
    await controller.setVolume(1.0);
    await Future<void>.delayed(const Duration(milliseconds: 20));

    expect(settings.volumeWrites, 0);
  });
}
