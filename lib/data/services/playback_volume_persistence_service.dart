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

import 'package:flutter/foundation.dart';

import 'package:flind_player/core/models/playback_state.dart';
import 'package:flind_player/core/repositories/settings_repository.dart';
import 'package:flind_player/core/services/playback_controller.dart';

/// Restores the output volume on launch and persists user changes.
///
/// Position ticks carry the same volume as the previous state, so writes are
/// skipped unless the value actually changed; a short debounce keeps a slider
/// drag from writing SharedPreferences on every tick.
class PlaybackVolumePersistenceService {
  PlaybackVolumePersistenceService({
    required PlaybackController playback,
    required PlaybackSettingsRepository settings,
    Duration debounce = const Duration(milliseconds: 300),
  }) : _playback = playback, // ignore: prefer_initializing_formals
       _settings = settings, // ignore: prefer_initializing_formals
       _debounce = debounce; // ignore: prefer_initializing_formals

  final PlaybackController _playback;
  final PlaybackSettingsRepository _settings;
  final Duration _debounce;

  StreamSubscription<PlaybackState>? _subscription;
  Timer? _pendingWrite;
  double? _lastVolume;
  bool _restoring = false;
  bool _disposed = false;

  /// Applies the persisted volume to the controller. Call once at startup
  /// before [start].
  Future<void> restore() async {
    if (_disposed) return;
    final stored = await _settings.playbackVolume();
    _restoring = true;
    try {
      await _playback.setVolume(stored);
      _lastVolume = stored;
    } catch (error, stackTrace) {
      debugPrint(
        'PlaybackVolumePersistenceService: restore failed: $error\n$stackTrace',
      );
    } finally {
      _restoring = false;
    }
  }

  /// Starts persisting volume changes. Idempotent.
  void start() {
    if (_disposed || _subscription != null) return;
    _subscription = _playback.state.listen(
      _onState,
      onError: (Object error, StackTrace stackTrace) {
        debugPrint(
          'PlaybackVolumePersistenceService: state error: $error\n$stackTrace',
        );
      },
    );
  }

  void _onState(PlaybackState state) {
    if (_disposed || _restoring) return;
    final volume = state.volume;
    if (_lastVolume != null && (volume - _lastVolume!).abs() < 0.001) {
      return;
    }
    _lastVolume = volume;
    _pendingWrite?.cancel();
    _pendingWrite = Timer(_debounce, () => _write(volume));
  }

  Future<void> _write(double volume) async {
    if (_disposed) return;
    try {
      await _settings.setPlaybackVolume(volume);
    } catch (error, stackTrace) {
      debugPrint(
        'PlaybackVolumePersistenceService: write failed: $error\n$stackTrace',
      );
    }
  }

  Future<void> dispose() async {
    if (_disposed) return;
    _disposed = true;
    final pending = _pendingWrite;
    final volume = _lastVolume;
    _pendingWrite = null;
    pending?.cancel();
    if (pending != null && volume != null) {
      try {
        await _settings.setPlaybackVolume(volume);
      } catch (error, stackTrace) {
        debugPrint(
          'PlaybackVolumePersistenceService: flush failed: $error\n$stackTrace',
        );
      }
    }
    await _subscription?.cancel();
    _subscription = null;
  }
}
