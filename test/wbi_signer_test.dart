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

import 'package:flind_player/data/sources/bilibili/wbi_signer.dart';

const String _imgKey = 'abcdefghijklmnopqrstuvwxyz012345';
const String _subKey = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ678901';

/// Independent copy of the reorder table from `docs/bilibili-source.md` §3.
const List<int> _expectedTab = <int>[
  46, 47, 18, 2, 53, 8, 23, 32, 15, 50, 10, 31, 58, 3, 45, 35, 27, 43, //
  5, 49, 33, 9, 42, 19, 29, 28, 14, 39, 12, 38, 41, 13, 37, 48, 7, 16,
  24, 55, 40, 61, 26, 17, 0, 1, 60, 51, 30, 4, 22, 25, 54, 21, 56, 59,
  6, 63, 57, 62, 11, 36, 20, 34, 44, 52,
];

WbiSigner _signer({DateTime? now}) => WbiSigner(
  fetchKeys: () async => (imgKey: _imgKey, subKey: _subKey),
  now: now == null ? null : () => now,
);

void main() {
  group('WbiSigner.mixinKey', () {
    test('reorders img_key+sub_key through the table and truncates to 32', () {
      final raw = '$_imgKey$_subKey';
      final expected = _expectedTab.map((i) => raw[i]).join().substring(0, 32);

      final key = WbiSigner.mixinKey(_imgKey, _subKey);

      expect(key.length, 32);
      expect(key, expected);
      // Fixed against an independent computation of the same table.
      expect(key, 'OPscVixApSk56dND1LfRBjKt32oHmGJn');
    });

    test('is stable for identical input', () {
      expect(
        WbiSigner.mixinKey(_imgKey, _subKey),
        WbiSigner.mixinKey(_imgKey, _subKey),
      );
    });

    test('permutes input characters as the table dictates', () {
      final raw = '$_imgKey$_subKey';
      for (var i = 0; i < 32; i++) {
        expect(
          WbiSigner.mixinKey(_imgKey, _subKey)[i],
          raw[_expectedTab[i]],
          reason: 'position $i must come from table index ${_expectedTab[i]}',
        );
      }
    });
  });

  group('WbiSigner.canonicalQuery', () {
    test('sorts keys and percent-encodes like encodeURIComponent', () {
      final query = WbiSigner.canonicalQuery(<String, dynamic>{
        'b': 'plain',
        'a': 'x y',
      });

      expect(query, 'a=x%20y&b=plain');
    });

    test('strips !\'()* from values', () {
      final query = WbiSigner.canonicalQuery(<String, dynamic>{
        'b': "a!'()*b",
        'a': 'ok',
      });

      expect(query, 'a=ok&b=ab');
    });

    test('encodes non-ASCII characters as uppercase hex', () {
      expect(
        WbiSigner.canonicalQuery(<String, dynamic>{'q': '曲'}),
        'q=%E6%9B%B2',
      );
    });
  });

  group('WbiSigner.sign', () {
    final fixedNow = DateTime.fromMillisecondsSinceEpoch(1700000000000);

    test('adds wts (unix seconds) and a 32-hex w_rid', () async {
      final signed = await _signer(now: fixedNow)
          .sign(<String, dynamic>{'keyword': 'test', 'search_type': 'video'});

      expect(signed['wts'], 1700000000);
      expect(signed['w_rid'], matches(RegExp(r'^[0-9a-f]{32}$')));
    });

    test('is deterministic for fixed inputs', () async {
      final signer = _signer(now: fixedNow);
      final first = await signer.sign(<String, dynamic>{'keyword': 'test'});
      final second = await signer.sign(<String, dynamic>{'keyword': 'test'});

      expect(first['w_rid'], second['w_rid']);
      expect(first['wts'], second['wts']);
    });

    test('does not mutate the input map', () async {
      final input = <String, dynamic>{'keyword': 'test'};
      await _signer(now: fixedNow).sign(input);

      expect(input.containsKey('wts'), isFalse);
      expect(input.containsKey('w_rid'), isFalse);
    });

    test('caches the fetched keys across calls', () async {
      var fetches = 0;
      final signer = WbiSigner(
        fetchKeys: () async {
          fetches++;
          return (imgKey: _imgKey, subKey: _subKey);
        },
        now: () => fixedNow,
      );

      await signer.sign(<String, dynamic>{'a': 1});
      await signer.sign(<String, dynamic>{'b': 2});

      expect(fetches, 1);
    });

    test('refetches keys once the cache ttl lapses', () async {
      var fetches = 0;
      var now = fixedNow;
      final signer = WbiSigner(
        fetchKeys: () async {
          fetches++;
          return (imgKey: _imgKey, subKey: _subKey);
        },
        now: () => now,
      );

      await signer.sign(<String, dynamic>{'a': 1});
      now = fixedNow.add(WbiSigner.cacheTtl + const Duration(minutes: 1));
      await signer.sign(<String, dynamic>{'a': 2});

      expect(fetches, 2);
    });
  });

  group('WbiSigner.parseNavKeys', () {
    test('extracts the file stems from img_url/sub_url', () {
      final keys = WbiSigner.parseNavKeys(<String, dynamic>{
        'code': -101,
        'data': <String, dynamic>{
          'wbi_img': <String, dynamic>{
            'img_url': 'https://i0.hdslb.com/bfs/wbi/abc123.png',
            'sub_url': 'https://i0.hdslb.com/bfs/wbi/def456.jpg',
          },
        },
      });

      expect(keys.imgKey, 'abc123');
      expect(keys.subKey, 'def456');
    });

    test('throws when the keys are absent', () {
      expect(
        () => WbiSigner.parseNavKeys(<String, dynamic>{'code': -101}),
        throwsA(isA<Exception>()),
      );
    });
  });
}
