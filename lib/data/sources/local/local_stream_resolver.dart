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

import 'dart:io';

import 'package:flind_player/core/models/track.dart';
import 'package:flind_player/core/sources/music_source.dart';
import 'package:flind_player/core/sources/source_track_id.dart';
import 'package:flind_player/core/sources/stream_resolver.dart';

/// Resolves [Track]s from the `local` source to a `file:` [StreamInfo].
///
/// Local playback needs neither HTTP headers nor an expiry: the file is read
/// straight from disk.
class LocalStreamResolver implements StreamResolver {
  /// Source id this resolver accepts.
  static const String sourceId = 'local';

  /// Prefix used by canonical local track uris (`local:/abs/path`; on Windows
  /// `local:C:/abs/path`, always with forward slashes).
  static const String uriPrefix = 'local:';

  const LocalStreamResolver();

  /// Builds the canonical `local:` uri for an on-disk [path].
  ///
  /// On Windows, backslashes are normalized to forward slashes so that the
  /// same file reached through scan roots spelled with either separator
  /// (Dart's [Directory.list] echoes the root's own spelling) yields one
  /// stable uri — otherwise mixed `\`/`/` spellings break uri-based
  /// deduplication and lookups. POSIX paths are returned unchanged because a
  /// backslash is a legal filename character there.
  static String uriForPath(String path) =>
      'local:${Platform.isWindows ? path.replaceAll('\\', '/') : path}';

  @override
  Future<StreamInfo> resolve(Track track) async {
    if (track.source != sourceId) {
      throw UnsupportedError(
        'LocalStreamResolver cannot resolve ${track.source}',
      );
    }

    return StreamInfo(url: Uri.file(_pathOf(track)));
  }

  /// Extracts the on-disk path for [track].
  ///
  /// The canonical [Track.uri] is authoritative; [LocalTrackId.path] is used as
  /// a fallback when the uri does not carry a usable path.
  String _pathOf(Track track) {
    if (track.uri.startsWith(uriPrefix)) {
      final path = track.uri.substring(uriPrefix.length);
      if (path.isNotEmpty) {
        return path;
      }
    }

    final id = track.sourceTrackId;
    if (id is LocalTrackId && id.path.isNotEmpty) {
      return id.path;
    }

    throw ArgumentError.value(
      track.uri,
      'track.uri',
      'local track has no usable file path',
    );
  }
}
