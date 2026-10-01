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

import 'package:flind_player/core/models/track.dart';
import 'package:flind_player/core/sources/music_source.dart';
import 'package:flind_player/core/sources/online_source.dart';
import 'package:flind_player/core/sources/source_track_id.dart';
import 'package:flind_player/data/providers/online_source_providers.dart';

class _FakeSource implements MusicSource {
  _FakeSource(this.id, this.results);

  @override
  final String id;
  final List<Track> results;
  final List<String> queries = <String>[];

  @override
  SourceCapabilities get capabilities => const SourceCapabilities(<SourceCapability>{SourceCapability.search});

  @override
  Future<List<Track>> search(String query, {int page = 1}) async {
    queries.add(query);
    return results;
  }

  @override
  Future<Track> fetchTrack(SourceTrackId id) => throw UnimplementedError();

  @override
  Future<StreamInfo> resolveStream(Track track) => throw UnimplementedError();
}

void main() {
  test('routes to the requested source and skips blank queries', () async {
    final bili = _FakeSource('bilibili', const <Track>[]);
    final netease = _FakeSource('netease', const <Track>[
      Track(
        source: 'netease',
        sourceTrackId: NeteaseTrackId(songId: 1),
        uri: 'netease:1',
        title: 'N',
      ),
    ]);
    final container = ProviderContainer(
      overrides: [
        onlineSourcesProvider.overrideWithValue(<SourceDescriptor>[
          SourceDescriptor(id: 'bilibili', source: bili),
          SourceDescriptor(id: 'netease', source: netease),
        ]),
      ],
    );
    addTearDown(container.dispose);

    final results = await container.read(onlineSearchProvider(('netease', '  ')).future);
    expect(results, isEmpty);
    expect(netease.queries, isEmpty);
    expect(bili.queries, isEmpty);

    final routed = await container.read(onlineSearchProvider(('netease', 'q')).future);
    expect(routed.single.uri, 'netease:1');
    expect(netease.queries, <String>['q']);
    expect(bili.queries, isEmpty);
  });

  test('excludes disabled sources from the registry', () {
    final container = ProviderContainer(
      overrides: [
        disabledSourceIdsProvider.overrideWithValue(const <String>{'bilibili'}),
        onlineSourcesProvider.overrideWithValue(<SourceDescriptor>[
          SourceDescriptor(id: 'netease', source: _FakeSource('netease', const <Track>[])),
        ]),
      ],
    );
    addTearDown(container.dispose);
    expect(
      container.read(onlineSourcesProvider).map((d) => d.id),
      <String>['netease'],
    );
  });
}
