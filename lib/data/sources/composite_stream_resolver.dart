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
import 'package:flind_player/core/sources/music_source.dart';
import 'package:flind_player/core/sources/stream_resolver.dart';

/// Routes [Track]s to the [StreamResolver] registered for their source.
///
/// The `local` source is always served by [localResolver]; every other source
/// must have been registered in [sources] (keyed by `MusicSource.id`). An
/// unknown source is a programming error and throws [UnsupportedError].
class CompositeStreamResolver implements StreamResolver {
  /// Source id handled by [localResolver].
  static const String localSourceId = 'local';

  /// Resolver for local files.
  final StreamResolver localResolver;

  /// Resolvers keyed by source id (e.g. `{'bilibili': biliSource}`).
  final Map<String, StreamResolver> sources;

  const CompositeStreamResolver({
    required this.localResolver,
    this.sources = const <String, StreamResolver>{},
  });

  @override
  Future<StreamInfo> resolve(Track track) {
    if (track.source == localSourceId) {
      return localResolver.resolve(track);
    }
    final resolver = sources[track.source];
    if (resolver == null) {
      throw UnsupportedError(
        'No stream resolver registered for source "${track.source}"',
      );
    }
    return resolver.resolve(track);
  }
}
