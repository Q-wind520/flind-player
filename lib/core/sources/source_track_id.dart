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

/// Identity of a track within its source.
///
/// Never use a bare id (e.g. `bvid`) as identity: a Bilibili video may contain
/// multiple parts (cid), and local paths are not unique across sources.
sealed class SourceTrackId {
  const SourceTrackId();
}

/// Identity of a locally stored audio file.
final class LocalTrackId extends SourceTrackId {
  /// Absolute path to the audio file.
  final String path;

  const LocalTrackId(this.path);

  @override
  bool operator ==(Object other) =>
      identical(this, other) || other is LocalTrackId && other.path == path;

  @override
  int get hashCode => Object.hash(runtimeType, path);

  @override
  String toString() => 'LocalTrackId($path)';
}

/// Identity of a Bilibili audio track (a specific video part).
final class BiliTrackId extends SourceTrackId {
  /// Bilibili video id, e.g. `BV1GJ411x7h7`.
  final String bvid;

  /// Bilibili part (chapter) id.
  final int cid;

  const BiliTrackId({required this.bvid, required this.cid});

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is BiliTrackId && other.bvid == bvid && other.cid == cid;

  @override
  int get hashCode => Object.hash(runtimeType, bvid, cid);

  @override
  String toString() => 'BiliTrackId($bvid, cid: $cid)';
}
