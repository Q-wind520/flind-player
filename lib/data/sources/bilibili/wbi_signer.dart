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

import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:flind_player/data/sources/bilibili/bili_client.dart';

/// Fetches the daily WBI keys (`img_key`, `sub_key`) from Bilibili.
///
/// Injected so tests never touch the network; production wires this to
/// `GET /x/web-interface/nav` (see `bilibili_providers.dart`).
typedef WbiKeyFetcher = Future<({String imgKey, String subKey})> Function();

/// Signs request parameters with Bilibili's WBI scheme.
///
/// Algorithm (see `docs/bilibili-source.md` §3):
/// 1. `mixin_key = reorder(img_key + sub_key, [mixinKeyEncTab])[:32]`
/// 2. `w_rid = md5(sorted_query_with_wts + mixin_key)`
/// 3. append `wts` (unix seconds) and `w_rid`
///
/// Values are stripped of `!'()*` and percent-encoded like JavaScript's
/// `encodeURIComponent` (`%20`, never `+`). The derived mixin key is cached for
/// [cacheTtl] because Bilibili rotates the raw keys daily.
class WbiSigner {
  /// Permutation applied to `img_key + sub_key` before truncation.
  ///
  /// Copied verbatim from `docs/bilibili-source.md` §3.
  static const List<int> mixinKeyEncTab = <int>[
    46,
    47,
    18,
    2,
    53,
    8,
    23,
    32,
    15,
    50,
    10,
    31,
    58,
    3,
    45,
    35,
    27,
    43,
    5,
    49,
    33,
    9,
    42,
    19,
    29,
    28,
    14,
    39,
    12,
    38,
    41,
    13,
    37,
    48,
    7,
    16,
    24,
    55,
    40,
    61,
    26,
    17,
    0,
    1,
    60,
    51,
    30,
    4,
    22,
    25,
    54,
    21,
    56,
    59,
    6,
    63,
    57,
    62,
    11,
    36,
    20,
    34,
    44,
    52,
  ];

  /// Characters Bilibili strips from every parameter value before signing.
  static final RegExp _filteredChars = RegExp(r"[!'()*]");

  /// How long a derived mixin key is trusted.
  static const Duration cacheTtl = Duration(hours: 12);

  final WbiKeyFetcher _fetchKeys;
  final DateTime Function() _now;

  String? _mixinKey;
  DateTime? _mixinKeyFetchedAt;

  WbiSigner({required WbiKeyFetcher fetchKeys, DateTime Function()? now})
    : _fetchKeys = fetchKeys, // ignore: prefer_initializing_formals
      _now = now ?? DateTime.now;

  /// Derives the 32-character mixin key from raw [imgKey] and [subKey].
  static String mixinKey(String imgKey, String subKey) {
    final raw = '$imgKey$subKey';
    final buffer = StringBuffer();
    for (final index in mixinKeyEncTab) {
      buffer.write(raw[index]);
    }
    return buffer.toString().substring(0, 32);
  }

  /// Builds the canonical, sorted query string that is hashed.
  ///
  /// Keys and values are percent-encoded like `encodeURIComponent`; values are
  /// first stripped of `!'()*`.
  static String canonicalQuery(Map<String, dynamic> params) {
    final entries = params.entries.toList()
      ..sort((a, b) => a.key.compareTo(b.key));
    return entries
        .map(
          (entry) =>
              '${Uri.encodeComponent(entry.key)}='
              '${Uri.encodeComponent(_stringValue(entry.value))}',
        )
        .join('&');
  }

  /// Parses `img_key` / `sub_key` out of a `nav` response body.
  ///
  /// Works without login: the response carries `code: -101` but still includes
  /// `data.wbi_img`.
  static ({String imgKey, String subKey}) parseNavKeys(
    Map<String, dynamic> json,
  ) {
    final data = json['data'];
    final wbi = data is Map ? data['wbi_img'] : null;
    final imgUrl = wbi is Map ? wbi['img_url'] as String? : null;
    final subUrl = wbi is Map ? wbi['sub_url'] as String? : null;
    if (imgUrl == null || subUrl == null) {
      throw const BiliApiException(-1, 'nav response did not contain WBI keys');
    }
    return (imgKey: _fileStem(imgUrl), subKey: _fileStem(subUrl));
  }

  /// Adds `wts` and `w_rid` to [params] and returns a new signed map.
  Future<Map<String, dynamic>> sign(Map<String, dynamic> params) async {
    final key = await _mixinKeyOrFetch();
    final signed = Map<String, dynamic>.from(params);
    signed['wts'] = _now().millisecondsSinceEpoch ~/ 1000;
    final query = canonicalQuery(signed);
    signed['w_rid'] = md5.convert(utf8.encode('$query$key')).toString();
    return signed;
  }

  Future<String> _mixinKeyOrFetch() async {
    final fetchedAt = _mixinKeyFetchedAt;
    final cached = _mixinKey;
    if (cached != null &&
        fetchedAt != null &&
        _now().difference(fetchedAt) < cacheTtl) {
      return cached;
    }
    final keys = await _fetchKeys();
    final key = mixinKey(keys.imgKey, keys.subKey);
    _mixinKey = key;
    _mixinKeyFetchedAt = _now();
    return key;
  }

  static String _stringValue(Object? value) {
    final text = value?.toString() ?? '';
    return text.replaceAll(_filteredChars, '');
  }

  static String _fileStem(String url) {
    final name = url.split('/').last;
    final dot = name.lastIndexOf('.');
    return dot >= 0 ? name.substring(0, dot) : name;
  }
}
