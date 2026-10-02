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

import 'package:flind_player/data/sources/bilibili/bili_client.dart'
    show kDesktopReferer, kDesktopUserAgent;

/// `Referer` the NetEase image CDN expects.
///
/// Mirrors NeriPlayer's per-host cover referer: `*.music.126.net` is fetched
/// with `https://music.163.com/`.
const String kMusic163Referer = 'https://music.163.com/';

/// `Referer` the Bilibili image CDN expects.
const String kBilibiliReferer = kDesktopReferer;

/// Returns the `Referer` a cover request to [uri] must carry, or `null`.
///
/// Some CDNs hotlink-protect their images behind a matching `Referer` and
/// reject the default `dart:io` User-Agent; both rules are centralised here so
/// every cover fetch (direct `Image.network`, aspect-ratio probe, or the
/// download-and-cache fallback) behaves identically.
String? coverRefererFor(Uri uri) {
  final host = uri.host.toLowerCase();
  if (_isHost(host, 'music.126.net')) return kMusic163Referer;
  if (_isHost(host, 'hdslb.com') || _isHost(host, 'biliimg.com')) {
    return kBilibiliReferer;
  }
  return null;
}

/// Headers every cover request to [uri] must carry: a browser `User-Agent`
/// (the NetEase CDN answers 403 to `dart:io`'s default) plus the host's
/// `Referer` when one is known.
Map<String, String> coverHeadersFor(Uri uri) {
  final referer = coverRefererFor(uri);
  return <String, String>{
    'User-Agent': kDesktopUserAgent,
    'Referer': ?referer,
  };
}

bool _isHost(String host, String domain) =>
    host == domain || host.endsWith('.$domain');
