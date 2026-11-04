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

import 'package:shared_preferences/shared_preferences.dart';

import 'package:flind_player/core/repositories/lyric_offset_repository.dart';

/// Shared-preferences-backed lyric offsets.
///
/// Offsets are per-track preferences, not user library data, so they stay out
/// of SQLite; the key is namespaced by the canonical track URI.
class PrefsLyricOffsetRepository implements LyricOffsetRepository {
  static String _key(String trackUri) => 'lyric_offset_$trackUri';

  @override
  Future<Duration> offsetFor(String trackUri) async {
    final prefs = await SharedPreferences.getInstance();
    return Duration(milliseconds: prefs.getInt(_key(trackUri)) ?? 0);
  }

  @override
  Future<void> setOffset(String trackUri, Duration offset) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_key(trackUri), offset.inMilliseconds);
  }
}
