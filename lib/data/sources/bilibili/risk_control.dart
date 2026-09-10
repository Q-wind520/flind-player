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

import 'package:flutter/foundation.dart';

import 'package:flind_player/data/sources/bilibili/bili_client.dart';

/// Fetches and caches the anonymous device fingerprint Bilibili expects.
///
/// Search results require `buvid3`/`buvid4` (see `docs/bilibili-source.md`
/// §5.2). Both are available without login from
/// `GET /x/frontend/finger/spi` and are cached for the process lifetime.
///
/// This class never throws: on any failure it degrades to an empty cookie
/// header and logs via [debugPrint], because the fingerprint is an
/// optimization, not a hard requirement.
class RiskControl {
  static const String _spiPath = '/x/frontend/finger/spi';

  final BiliClient _client;

  String? _cachedHeader;

  RiskControl({required BiliClient client})
    : _client = client; // ignore: prefer_initializing_formals

  /// Returns `buvid3=...; buvid4=...`, or an empty string when unavailable.
  Future<String> cookieHeader() async {
    final cached = _cachedHeader;
    if (cached != null) return cached;

    try {
      final json = await _client.getJson(_spiPath);
      final data = json['data'];
      final buvid3 = data is Map ? data['b_3'] as String? : null;
      final buvid4 = data is Map ? data['b_4'] as String? : null;

      if (buvid3 == null || buvid3.isEmpty) {
        debugPrint('RiskControl: spi response had no buvid3');
        return _cachedHeader = '';
      }

      final header = buvid4 == null || buvid4.isEmpty
          ? 'buvid3=$buvid3'
          : 'buvid3=$buvid3; buvid4=$buvid4';
      return _cachedHeader = header;
    } catch (error) {
      debugPrint('RiskControl: fingerprint fetch failed: $error');
      return _cachedHeader = '';
    }
  }
}
