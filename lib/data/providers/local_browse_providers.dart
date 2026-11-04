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

import 'package:flind_player/core/models/local_collection.dart';
import 'package:flind_player/core/models/track.dart';
import 'package:flind_player/core/repositories/local_browse_repository.dart';
import 'package:flind_player/data/providers/database_providers.dart';
import 'package:flind_player/data/repositories/drift_local_browse_repository.dart';

final localBrowseRepositoryProvider = Provider<LocalBrowseRepository>(
  (ref) => DriftLocalBrowseRepository(ref.watch(appDatabaseProvider)),
);

final localArtistsProvider = StreamProvider<List<LocalArtist>>(
  (ref) => ref.watch(localBrowseRepositoryProvider).watchArtists(),
);

final localAlbumsProvider = StreamProvider<List<LocalAlbum>>(
  (ref) => ref.watch(localBrowseRepositoryProvider).watchAlbums(),
);

final localArtistTracksProvider = FutureProvider.autoDispose
    .family<List<Track>, String>((ref, artist) {
      return ref.watch(localBrowseRepositoryProvider).tracksForArtist(artist);
    });

final localAlbumTracksProvider = FutureProvider.autoDispose
    .family<List<Track>, (String, String?)>((ref, key) {
      return ref
          .watch(localBrowseRepositoryProvider)
          .tracksForAlbum(key.$1, artist: key.$2);
    });
