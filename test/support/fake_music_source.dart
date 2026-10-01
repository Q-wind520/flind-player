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

import 'package:flutter_test/flutter_test.dart';

import 'package:flind_player/core/models/track.dart';
import 'package:flind_player/core/sources/music_source.dart';
import 'package:flind_player/core/sources/online_source.dart';
import 'package:flind_player/core/sources/source_track_id.dart';

/// A [MusicSource] stub for widget tests; search is configurable, the rest
/// throws if reached.
class FakeMusicSource implements MusicSource {
  FakeMusicSource(this.id, {this.results = const <Track>[]});

  @override
  final String id;
  final List<Track> results;

  @override
  SourceCapabilities get capabilities =>
      const SourceCapabilities(<SourceCapability>{SourceCapability.search});

  @override
  Future<List<Track>> search(String query, {int page = 1}) async => results;

  @override
  Future<Track> fetchTrack(SourceTrackId id) => throw UnimplementedError();

  @override
  Future<StreamInfo> resolveStream(Track track) => throw UnimplementedError();
}

/// The two-source registry used by search widget tests.
List<SourceDescriptor> fakeSourceRegistry() => <SourceDescriptor>[
  SourceDescriptor(id: 'bilibili', source: FakeMusicSource('bilibili')),
  SourceDescriptor(id: 'netease', source: FakeMusicSource('netease')),
];
