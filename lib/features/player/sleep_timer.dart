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
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:flind_player/data/providers/playback_providers.dart';

/// How a running sleep timer decides when to stop playback.
enum SleepTimerMode {
  /// No timer armed.
  off,

  /// Stops playback once [SleepTimerState.remaining] reaches zero.
  duration,

  /// Stops playback when the current track gives way to the next one.
  endOfTrack,
}

/// Immutable snapshot of the sleep timer.
@immutable
class SleepTimerState {
  const SleepTimerState({this.mode = SleepTimerMode.off, this.remaining});

  /// Which stop condition is armed.
  final SleepTimerMode mode;

  /// Time left for [SleepTimerMode.duration]; `null` otherwise.
  final Duration? remaining;

  /// Whether a stop condition is armed.
  bool get isActive => mode != SleepTimerMode.off;

  /// Whether the timer fires on a track change rather than a countdown.
  bool get isEndOfTrack => mode == SleepTimerMode.endOfTrack;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is SleepTimerState &&
          other.mode == mode &&
          other.remaining == remaining;

  @override
  int get hashCode => Object.hash(mode, remaining);

  @override
  String toString() => 'SleepTimerState(mode: $mode, remaining: $remaining)';
}

/// Arms, ticks down, and fires the player's sleep timer.
///
/// The timer is intentionally ephemeral: it lives for the current session so a
/// quick "stop after this album" does not silently survive a restart. When it
/// fires it pauses the controller; it never resumes playback.
class SleepTimerNotifier extends Notifier<SleepTimerState> {
  Timer? _ticker;

  @override
  SleepTimerState build() {
    ref.onDispose(_stopTicker);
    // End-of-track mode fires on the first track change after it is armed.
    ref.listen(playbackStateProvider, (previous, next) {
      if (state.mode != SleepTimerMode.endOfTrack) {
        return;
      }
      final before = previous?.value?.currentTrack?.uri;
      final after = next.value?.currentTrack?.uri;
      if (before != null && after != null && before != after) {
        _fire();
      }
    });
    return const SleepTimerState();
  }

  /// Stops playback after [duration] elapses.
  void start(Duration duration) {
    if (duration <= Duration.zero) {
      cancel();
      return;
    }
    _stopTicker();
    final endAt = DateTime.now().add(duration);
    state = SleepTimerState(
      mode: SleepTimerMode.duration,
      remaining: duration,
    );
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      final left = endAt.difference(DateTime.now());
      if (left <= Duration.zero) {
        _fire();
      } else {
        state = SleepTimerState(
          mode: SleepTimerMode.duration,
          remaining: left,
        );
      }
    });
  }

  /// Stops playback when the current track finishes.
  void startEndOfTrack() {
    _stopTicker();
    state = const SleepTimerState(mode: SleepTimerMode.endOfTrack);
  }

  /// Disarms the timer without touching playback.
  void cancel() {
    _stopTicker();
    if (state.mode == SleepTimerMode.off) {
      return;
    }
    state = const SleepTimerState();
  }

  void _fire() {
    _stopTicker();
    state = const SleepTimerState();
    unawaited(ref.read(playbackControllerProvider).pause());
  }

  void _stopTicker() {
    _ticker?.cancel();
    _ticker = null;
  }
}

/// The player's sleep timer, shared by the MiniSettings button and its panel.
final sleepTimerProvider = NotifierProvider<SleepTimerNotifier, SleepTimerState>(
  SleepTimerNotifier.new,
);
