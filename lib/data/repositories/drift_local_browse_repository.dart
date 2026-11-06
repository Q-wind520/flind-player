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

import 'package:drift/drift.dart';

import 'package:flind_player/core/models/local_collection.dart';
import 'package:flind_player/core/models/track.dart';
import 'package:flind_player/core/repositories/local_browse_repository.dart';
import 'package:flind_player/data/database/app_database.dart';
import 'package:flind_player/data/repositories/track_row_mapping.dart';

/// Aggregates the local slice of the pool in Dart.
///
/// Grouping in Dart keeps the query portable and the cover/unknown-artist
/// fallbacks simple; a personal library is small enough (thousands, not
/// millions of rows) that this stays cheap.
class DriftLocalBrowseRepository implements LocalBrowseRepository {
  DriftLocalBrowseRepository(this._db);

  final AppDatabase _db;

  Selectable<TrackRow> _localQuery() {
    return _db.select(_db.tracks)
      ..where(
        (t) =>
            t.source.equals('local') &
            t.missingAt.isNull() &
            t.deletedAt.isNull(),
      )
      ..orderBy([
        (t) => OrderingTerm.asc(t.artist),
        (t) => OrderingTerm.asc(t.album),
        (t) => OrderingTerm.asc(t.title),
      ]);
  }

  @override
  Stream<List<LocalArtist>> watchArtists() {
    return _localQuery().watch().map((rows) {
      final tracks = rows.map(trackFromRow).toList(growable: false);
      return _groupArtists(tracks);
    });
  }

  @override
  Stream<List<LocalAlbum>> watchAlbums() {
    return _localQuery().watch().map((rows) {
      final tracks = rows.map(trackFromRow).toList(growable: false);
      return _groupAlbums(tracks);
    });
  }

  @override
  Future<List<Track>> tracksForArtist(String artist) async {
    final rows = await _localQuery().get();
    final needle = artist.trim().toLowerCase();
    return rows
        .map(trackFromRow)
        .where((track) => (track.artist ?? '').trim().toLowerCase() == needle)
        .toList(growable: false);
  }

  @override
  Future<List<Track>> tracksForAlbum(String title, {String? artist}) async {
    final rows = await _localQuery().get();
    final titleKey = title.trim().toLowerCase();
    final artistKey = artist?.trim().toLowerCase();
    return rows
        .map(trackFromRow)
        .where((track) {
          if ((track.album ?? '').trim().toLowerCase() != titleKey) {
            return false;
          }
          if (artistKey == null) return true;
          return (track.artist ?? '').trim().toLowerCase() == artistKey;
        })
        .toList(growable: false);
  }

  List<LocalArtist> _groupArtists(List<Track> tracks) {
    final byName = <String, List<Track>>{};
    for (final track in tracks) {
      final name = (track.artist ?? '').trim();
      byName.putIfAbsent(name, () => <Track>[]).add(track);
    }
    final artists = <LocalArtist>[
      for (final entry in byName.entries)
        LocalArtist(
          name: entry.key,
          trackCount: entry.value.length,
          coverPath: _firstCoverPath(entry.value),
          coverUrl: _firstCoverUrl(entry.value),
        ),
    ];
    artists.sort(
      (a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()),
    );
    return List<LocalArtist>.unmodifiable(artists);
  }

  List<LocalAlbum> _groupAlbums(List<Track> tracks) {
    final byKey = <String, List<Track>>{};
    for (final track in tracks) {
      final title = (track.album ?? '').trim();
      if (title.isEmpty) continue;
      final artist = (track.artist ?? '').trim();
      final key = '${title.toLowerCase()}\u0000${artist.toLowerCase()}';
      byKey.putIfAbsent(key, () => <Track>[]).add(track);
    }
    final albums = <LocalAlbum>[
      for (final entry in byKey.entries)
        LocalAlbum(
          title: (entry.value.first.album ?? '').trim(),
          artist: entry.value.first.artist?.trim(),
          year: entry.value
              .map((track) => track.year)
              .whereType<int>()
              .firstOrNull,
          trackCount: entry.value.length,
          coverPath: _firstCoverPath(entry.value),
          coverUrl: _firstCoverUrl(entry.value),
        ),
    ];
    albums.sort((a, b) {
      final byArtist = (a.artist ?? '').toLowerCase().compareTo(
        (b.artist ?? '').toLowerCase(),
      );
      if (byArtist != 0) return byArtist;
      return a.title.toLowerCase().compareTo(b.title.toLowerCase());
    });
    return List<LocalAlbum>.unmodifiable(albums);
  }

  String? _firstCoverPath(List<Track> tracks) {
    for (final track in tracks) {
      if (track.coverPath != null) return track.coverPath;
    }
    return null;
  }

  String? _firstCoverUrl(List<Track> tracks) {
    for (final track in tracks) {
      if (track.coverUrl != null) return track.coverUrl;
    }
    return null;
  }
}

extension _FirstOrNull<T> on Iterable<T> {
  T? get firstOrNull => isEmpty ? null : first;
}
