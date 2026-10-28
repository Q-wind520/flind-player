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

import 'package:flind_player/core/models/lyric.dart';
import 'package:flind_player/core/models/playback_state.dart';
import 'package:flind_player/core/models/track.dart';
import 'package:flind_player/core/services/lyrics_provider.dart';
import 'package:flind_player/core/sources/music_source.dart';
import 'package:flind_player/core/sources/online_source.dart';
import 'package:flind_player/core/sources/source_track_id.dart';
import 'package:flind_player/data/providers/auth_providers.dart';
import 'package:flind_player/data/providers/lyrics_providers.dart';
import 'package:flind_player/data/providers/online_source_providers.dart';
import 'package:flind_player/data/providers/playback_providers.dart';
import 'package:flind_player/features/player/lyrics_view.dart';

import 'support/l10n.dart';

class _BiliLyricsSource implements MusicSource, LyricsProvider {
  @override
  String get id => 'bilibili';

  @override
  SourceCapabilities get capabilities => const SourceCapabilities(
    <SourceCapability>{SourceCapability.login, SourceCapability.search},
  );

  @override
  Future<Lyric?> lyricsFor(Track track) async => null;

  @override
  Future<List<Track>> search(String query, {int page = 1}) async =>
      const <Track>[];

  @override
  Future<Track> fetchTrack(SourceTrackId id) => throw UnimplementedError();

  @override
  Future<StreamInfo> resolveStream(Track track) => throw UnimplementedError();
}

const _track = Track(
  source: 'bilibili',
  sourceTrackId: BiliTrackId(bvid: 'BV1', cid: 10),
  uri: 'bilibili:BV1:10',
  title: 'T',
);

void main() {
  testWidgets('a gated Bilibili lyric offers the login action', (tester) async {
    final source = _BiliLyricsSource();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          onlineSourcesProvider.overrideWithValue(<SourceDescriptor>[
            SourceDescriptor(id: 'bilibili', source: source),
          ]),
          authSessionProvider.overrideWith((ref, sourceId) => null),
          trackLyricsProvider.overrideWith((ref, track) async => null),
          playbackStateProvider.overrideWith(
            (ref) => Stream.value(
              const PlaybackState(
                isPlaying: false,
                isBuffering: false,
                isCompleted: false,
                position: Duration.zero,
                currentTrack: _track,
              ),
            ),
          ),
        ],
        child: localizedApp(const Scaffold(body: LyricsView())),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('登录后可获取该视频的字幕'), findsOneWidget);
    expect(find.text('登录 B站 后获取字幕'), findsOneWidget);
  });
}
