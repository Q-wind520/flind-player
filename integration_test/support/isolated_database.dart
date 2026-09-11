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

import 'package:drift/native.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';

import 'package:flind_player/data/database/app_database.dart';
import 'package:flind_player/data/providers/database_providers.dart';

/// Points the app at a throwaway database file for the duration of one test.
///
/// Without this, integration tests run against the user's real library
/// (`~/文档/flind_player.sqlite`), so a scan test leaves phantom tracks behind
/// once its temporary folder is deleted.
///
/// Call it ONCE inside a test and reuse the returned overrides for every
/// `ProviderContainer` that must share the same database (e.g. the two
/// "sessions" in the persistence test). The file is deleted on teardown.
List<Override> isolatedDatabaseOverrides() {
  final directory = Directory.systemTemp.createTempSync('flind_it_db');
  final file = File('${directory.path}/flind_player.sqlite');
  final database = AppDatabase(NativeDatabase(file));

  addTearDown(() async {
    await database.close();
    if (directory.existsSync()) {
      directory.deleteSync(recursive: true);
    }
  });

  return <Override>[
    // Deliberately NOT closed via ref.onDispose: tests may dispose one
    // container and open another against the same database (the persistence
    // test simulates a restart that way). The teardown above owns the close.
    appDatabaseProvider.overrideWith((ref) => database),
  ];
}
