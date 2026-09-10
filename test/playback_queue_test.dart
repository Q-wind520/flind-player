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

import 'dart:math';

import 'package:flutter_test/flutter_test.dart';

import 'package:flind_player/core/models/playback_queue.dart';
import 'package:flind_player/core/models/repeat_mode.dart';
import 'package:flind_player/core/models/track.dart';
import 'package:flind_player/core/sources/source_track_id.dart';

Track _track(int n) => Track(
  source: 'local',
  sourceTrackId: LocalTrackId('/music/track_$n.mp3'),
  uri: 'local:/music/track_$n.mp3',
  title: 'Track $n',
);

PlaybackQueue _queue(int count, {int currentIndex = 0}) => PlaybackQueue(
  tracks: [for (var i = 0; i < count; i++) _track(i)],
  currentIndex: currentIndex,
  originalOrder: [for (var i = 0; i < count; i++) i],
);

void main() {
  group('PlaybackQueue basics', () {
    test('empty queue has no current track', () {
      expect(PlaybackQueue.empty.isEmpty, isTrue);
      expect(PlaybackQueue.empty.length, 0);
      expect(PlaybackQueue.empty.currentTrack, isNull);
    });

    test('identity order is the initial originalOrder', () {
      final queue = _queue(4);
      expect(queue.originalOrder, [0, 1, 2, 3]);
      expect(queue.currentTrack, _track(0));
      expect(queue.length, 4);
    });

    test('currentTrack is null when index is out of range', () {
      expect(_queue(2).copyWith(currentIndex: -1).currentTrack, isNull);
      expect(_queue(2).copyWith(currentIndex: 5).currentTrack, isNull);
    });
  });

  group('shuffled()', () {
    test('keeps the same current track', () {
      final queue = _queue(6, currentIndex: 3);
      final shuffled = queue.shuffled(Random(42));

      expect(shuffled.length, queue.length);
      expect(shuffled.currentTrack, queue.currentTrack);
      expect(shuffled.tracks[shuffled.currentIndex], queue.currentTrack);
    });

    test('preserves the track set and records a valid permutation', () {
      final queue = _queue(6, currentIndex: 3);
      final shuffled = queue.shuffled(Random(7));

      expect(shuffled.tracks.toSet(), queue.tracks.toSet());
      expect(shuffled.originalOrder.toSet(), {0, 1, 2, 3, 4, 5});
      expect(shuffled.originalOrder.length, 6);
    });

    test('handles queues of size 0 and 1', () {
      expect(PlaybackQueue.empty.shuffled(Random(1)), PlaybackQueue.empty);
      final single = _queue(1);
      expect(single.shuffled(Random(1)).tracks, single.tracks);
    });
  });

  group('unshuffled()', () {
    test('restores the original order and current index', () {
      final queue = _queue(6, currentIndex: 4);
      final restored = queue.shuffled(Random(99)).unshuffled();

      expect(restored.tracks, queue.tracks);
      expect(restored.currentIndex, queue.currentIndex);
      expect(restored.originalOrder, queue.originalOrder);
      expect(restored, queue);
    });

    test('is a no-op on an already-unshuffled queue', () {
      final queue = _queue(3, currentIndex: 1);
      expect(queue.unshuffled(), queue);
    });

    test('repeated shuffles still restore the original order', () {
      final queue = _queue(8, currentIndex: 5);
      final restored = queue
          .shuffled(Random(1))
          .shuffled(Random(2))
          .unshuffled();

      expect(restored.tracks, queue.tracks);
      expect(restored.currentIndex, queue.currentIndex);
    });
  });

  group('nextIndex()', () {
    final queue = _queue(3, currentIndex: 0);

    test('advances within the queue', () {
      expect(queue.nextIndex(repeatMode: RepeatMode.off), 1);
      expect(queue.nextIndex(repeatMode: RepeatMode.all), 1);
    });

    test('stops at the end when repeat is off', () {
      final last = queue.copyWith(currentIndex: 2);
      expect(last.nextIndex(repeatMode: RepeatMode.off), isNull);
    });

    test('wraps at the end when repeat is all', () {
      final last = queue.copyWith(currentIndex: 2);
      expect(last.nextIndex(repeatMode: RepeatMode.all), 0);
    });

    test('stays on the same index when repeat is one', () {
      expect(queue.nextIndex(repeatMode: RepeatMode.one), 0);
      expect(
        queue.copyWith(currentIndex: 2).nextIndex(repeatMode: RepeatMode.one),
        2,
      );
    });

    test('starts at index 0 when idle', () {
      expect(
        _queue(3, currentIndex: -1).nextIndex(repeatMode: RepeatMode.off),
        0,
      );
    });

    test('is null for an empty queue', () {
      expect(PlaybackQueue.empty.nextIndex(repeatMode: RepeatMode.all), isNull);
    });
  });

  group('previousIndex()', () {
    final queue = _queue(3, currentIndex: 2);

    test('moves back within the queue', () {
      expect(queue.previousIndex(repeatMode: RepeatMode.off), 1);
      expect(queue.previousIndex(repeatMode: RepeatMode.all), 1);
    });

    test('stops at the start when repeat is off', () {
      final first = queue.copyWith(currentIndex: 0);
      expect(first.previousIndex(repeatMode: RepeatMode.off), isNull);
    });

    test('wraps at the start when repeat is all', () {
      final first = queue.copyWith(currentIndex: 0);
      expect(first.previousIndex(repeatMode: RepeatMode.all), 2);
    });

    test('stays on the same index when repeat is one', () {
      expect(queue.previousIndex(repeatMode: RepeatMode.one), 2);
      expect(
        queue
            .copyWith(currentIndex: 0)
            .previousIndex(repeatMode: RepeatMode.one),
        0,
      );
    });

    test('is null for an empty queue', () {
      expect(
        PlaybackQueue.empty.previousIndex(repeatMode: RepeatMode.all),
        isNull,
      );
    });
  });
}
