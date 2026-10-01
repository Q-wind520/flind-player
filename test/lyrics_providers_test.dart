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

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:flind_player/core/models/lyric.dart';
import 'package:flind_player/core/models/track.dart';
import 'package:flind_player/core/services/lyrics_provider.dart';
import 'package:flind_player/core/sources/music_source.dart';
import 'package:flind_player/core/sources/online_source.dart';
import 'package:flind_player/core/sources/source_track_id.dart';
import 'package:flind_player/data/providers/lyrics_providers.dart';
import 'package:flind_player/data/providers/online_source_providers.dart';

class _LyricsSource implements MusicSource, LyricsProvider {
  _LyricsSource(this.id, this.result);

  @override
  final String id;
  final Lyric? result;

  @override
  SourceCapabilities get capabilities => const SourceCapabilities(<SourceCapability>{SourceCapability.search});

  @override
  Future<List<Track>> search(String query, {int page = 1}) async => const <Track>[];

  @override
  Future<Track> fetchTrack(SourceTrackId id) => throw UnimplementedError();

  @override
  Future<StreamInfo> resolveStream(Track track) => throw UnimplementedError();

  @override
  Future<Lyric?> lyricsFor(Track track) async => result;
}

class _ThrowingLyricsSource extends _LyricsSource {
  _ThrowingLyricsSource(String id) : super(id, null);

  @override
  Future<Lyric?> lyricsFor(Track track) async =>
      throw StateError('lyrics fetch failed');
}

class _PlainSource implements MusicSource {
  _PlainSource(this.id);
  @override
  final String id;
  @override
  SourceCapabilities get capabilities => const SourceCapabilities(<SourceCapability>{SourceCapability.search});
  @override
  Future<List<Track>> search(String query, {int page = 1}) async => const <Track>[];
  @override
  Future<Track> fetchTrack(SourceTrackId id) => throw UnimplementedError();
  @override
  Future<StreamInfo> resolveStream(Track track) => throw UnimplementedError();
}

const _track = Track(
  source: 'netease',
  sourceTrackId: NeteaseTrackId(songId: 1),
  uri: 'netease:1',
  title: 'T',
);

void main() {
  test('returns lyrics from the LyricsProvider source', () async {
    const lyric = Lyric(<LyricLine>[LyricLine(timestamp: Duration.zero, text: 'a')]);
    final container = ProviderContainer(
      overrides: [
        onlineSourcesProvider.overrideWithValue(<SourceDescriptor>[
          SourceDescriptor(id: 'bilibili', source: _PlainSource('bilibili')),
          SourceDescriptor(id: 'netease', source: _LyricsSource('netease', lyric)),
        ]),
      ],
    );
    addTearDown(container.dispose);

    expect(await container.read(trackLyricsProvider(_track).future), lyric);
  });

  test('resolves to null when no source provides lyrics', () async {
    final container = ProviderContainer(
      overrides: [
        onlineSourcesProvider.overrideWithValue(<SourceDescriptor>[
          SourceDescriptor(id: 'bilibili', source: _PlainSource('bilibili')),
        ]),
      ],
    );
    addTearDown(container.dispose);

    expect(await container.read(trackLyricsProvider(_track).future), isNull);
  });

  test('resolves to null when the lyrics provider throws', () async {
    final container = ProviderContainer(
      overrides: [
        onlineSourcesProvider.overrideWithValue(<SourceDescriptor>[
          SourceDescriptor(id: 'netease', source: _ThrowingLyricsSource('netease')),
        ]),
      ],
    );
    addTearDown(container.dispose);

    expect(await container.read(trackLyricsProvider(_track).future), isNull);
  });

  test('sourceSupportsLyricsProvider reflects the adapter capability', () {
    final container = ProviderContainer(
      overrides: [
        onlineSourcesProvider.overrideWithValue(<SourceDescriptor>[
          SourceDescriptor(id: 'bilibili', source: _PlainSource('bilibili')),
          SourceDescriptor(id: 'netease', source: _LyricsSource('netease', null)),
        ]),
      ],
    );
    addTearDown(container.dispose);

    expect(container.read(sourceSupportsLyricsProvider('netease')), isTrue);
    expect(container.read(sourceSupportsLyricsProvider('bilibili')), isFalse);
    expect(container.read(sourceSupportsLyricsProvider('unknown')), isFalse);
  });
}
