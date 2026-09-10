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

import 'package:flind_player/core/models/track.dart';
import 'package:flind_player/core/sources/source_track_id.dart';

/// Optional capabilities a [MusicSource] may advertise.
enum SourceCapability { login, search, streamDirect }

/// The set of [SourceCapability] values a source supports.
class SourceCapabilities {
  final Set<SourceCapability> values;

  const SourceCapabilities(this.values);

  bool supports(SourceCapability c) => values.contains(c);

  @override
  String toString() => 'SourceCapabilities($values)';
}

/// A playable stream resolved from a [Track].
class StreamInfo {
  /// Primary stream URL.
  final Uri url;

  /// Failover URLs, tried in order when [url] is unreachable.
  final List<Uri> backupUrls;

  /// HTTP headers required to fetch the stream (e.g. Referer / User-Agent).
  final Map<String, String> headers;

  /// When the stream URL stops being valid, if known.
  final DateTime? expiresAt;

  /// Source-specific quality identifier (e.g. `30280`).
  final String qualityId;

  const StreamInfo({
    required this.url,
    this.backupUrls = const [],
    this.headers = const {},
    this.expiresAt,
    this.qualityId = 'unknown',
  });

  @override
  String toString() => 'StreamInfo($url, quality: $qualityId)';
}

/// A music provider (local library, Bilibili, ...).
abstract interface class MusicSource {
  /// Stable identifier, e.g. `local` or `bilibili`.
  String get id;

  /// Capabilities this source supports.
  SourceCapabilities get capabilities;

  /// Searches this source for [query], returning one page of tracks.
  Future<List<Track>> search(String query, {int page = 1});

  /// Fetches full metadata for a track identified by [id].
  Future<Track> fetchTrack(SourceTrackId id);

  /// Resolves a playable [StreamInfo] for [track].
  Future<StreamInfo> resolveStream(Track track);
}
