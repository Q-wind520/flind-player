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

import 'package:flind_player/core/models/track.dart';
import 'package:flind_player/data/providers/database_providers.dart';
import 'package:flind_player/data/sources/local/local_file_importer.dart';
import 'package:flind_player/data/sources/local/local_metadata_reader.dart';

/// Reads embedded metadata from local audio files.
final localMetadataReaderProvider = Provider<LocalMetadataReader>(
  (ref) => LocalMetadataReader(),
);

/// Picks and imports local audio files.
final localFileImporterProvider = Provider<LocalFileImporter>(
  (ref) => LocalFileImporter(ref.watch(localMetadataReaderProvider)),
);

/// Reactive view of the whole library, newest database state included.
final libraryTracksProvider = StreamProvider<List<Track>>(
  (ref) => ref.watch(musicLibraryRepositoryProvider).watchTracks(),
);
