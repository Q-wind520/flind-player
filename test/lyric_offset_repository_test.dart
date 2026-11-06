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
import 'package:shared_preferences/shared_preferences.dart';

import 'package:flind_player/data/repositories/prefs_lyric_offset_repository.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

  test('stores and reads a per-track offset', () async {
    final repo = PrefsLyricOffsetRepository();
    expect(await repo.offsetFor('local:/a.flac'), Duration.zero);

    await repo.setOffset('local:/a.flac', const Duration(milliseconds: 300));
    expect(
      await repo.offsetFor('local:/a.flac'),
      const Duration(milliseconds: 300),
    );
    expect(await repo.offsetFor('local:/b.flac'), Duration.zero);
  });

  test('overwrites an existing offset', () async {
    final repo = PrefsLyricOffsetRepository();
    await repo.setOffset('x', const Duration(milliseconds: -200));
    await repo.setOffset('x', const Duration(milliseconds: 100));
    expect(await repo.offsetFor('x'), const Duration(milliseconds: 100));
  });
}
