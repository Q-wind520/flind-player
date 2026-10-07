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
import 'package:flutter_test/flutter_test.dart';

import 'package:flind_player/app/theme/app_tokens.dart';
import 'package:flind_player/core/models/track.dart';
import 'package:flind_player/core/sources/source_track_id.dart';
import 'package:flind_player/features/library/widgets/track_list_items.dart';

import 'support/l10n.dart';

void main() {
  testWidgets('TrackCover rounds to the shared medium radius', (tester) async {
    final track = Track(
      source: 'local',
      sourceTrackId: const LocalTrackId('/music/a.mp3'),
      uri: 'local:/music/a.mp3',
      title: 'A',
    );

    await tester.pumpWidget(
      localizedApp(Scaffold(body: TrackCover(track: track, size: 48))),
    );

    final clip = tester.widget<ClipRRect>(find.byType(ClipRRect));
    expect(clip.borderRadius, BorderRadius.circular(AppRadius.md));
  });
}
