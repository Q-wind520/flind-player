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

import 'package:flind_player/data/cache/cover_headers.dart';
import 'package:flind_player/data/sources/bilibili/bili_client.dart'
    show kDesktopReferer, kDesktopUserAgent;

void main() {
  group('coverRefererFor', () {
    test('maps the NetEase image CDN to the music.163 referer', () {
      expect(
        coverRefererFor(Uri.parse('https://p1.music.126.net/a.jpg')),
        kMusic163Referer,
      );
      expect(
        coverRefererFor(Uri.parse('https://music.126.net/a.jpg')),
        kMusic163Referer,
      );
    });

    test('maps Bilibili CDNs to the bilibili referer', () {
      expect(
        coverRefererFor(Uri.parse('https://i0.hdslb.com/a.jpg')),
        kBilibiliReferer,
      );
      expect(
        coverRefererFor(Uri.parse('https://x.biliimg.com/a.jpg')),
        kBilibiliReferer,
      );
      expect(kBilibiliReferer, kDesktopReferer);
    });

    test('returns null for an unknown host', () {
      expect(coverRefererFor(Uri.parse('https://example.com/a.jpg')), isNull);
    });
  });

  group('coverHeadersFor', () {
    test('includes the browser UA and the NetEase referer', () {
      final headers = coverHeadersFor(
        Uri.parse('https://p4.music.126.net/a.jpg'),
      );
      expect(headers['User-Agent'], kDesktopUserAgent);
      expect(headers['Referer'], kMusic163Referer);
    });

    test('omits Referer for an unknown host', () {
      final headers = coverHeadersFor(Uri.parse('https://example.com/a.jpg'));
      expect(headers['User-Agent'], kDesktopUserAgent);
      expect(headers.containsKey('Referer'), isFalse);
    });
  });
}
