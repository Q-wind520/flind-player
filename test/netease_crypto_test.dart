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
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';

import 'package:flind_player/data/sources/netease/netease_crypto.dart';

void main() {
  group('weapi', () {
    test('matches the captured vector for a fixed secret key', () {
      final result = NeteaseCrypto.weapi(
        <String, dynamic>{'s': 'test'},
        secretKey: Uint8List.fromList(utf8.encode('abcdefghijklmnop')),
      );

      expect(result.params, 'CuDFnRu6I3tkacNjPgyex3G+xd8IWN5B5wihjnGXoHg=');
      expect(
        result.encSecKey,
        'd15a1683c992095d0c234c19966605c5c5964911268bbeda8cb8d08d834913e5'
        '9d53b32358903a121b5fca784c1f5ae44951fd02524df58ecc98e52cc7cf8689'
        'b42c2e93ddf05b0592512d87f5960467e2f086c018849d76014d323500e30f13'
        'ef4cafbb0cf5a66731a3f1776c75ca35d0062dac70a3e33245afabcf47938487',
      );
      expect(result.encSecKey, hasLength(256));
    });

    test('uses a fresh 32-hex-per-byte RSA block of fixed width', () {
      final a = NeteaseCrypto.weapi(<String, dynamic>{'q': '曲'});
      final b = NeteaseCrypto.weapi(<String, dynamic>{'q': '曲'});
      expect(a.params, isNot(b.params), reason: 'random secret key per call');
      expect(a.encSecKey, hasLength(256));
    });
  });

  group('eapi', () {
    test('matches the captured vector', () {
      final params = NeteaseCrypto.eapi(
        '/api/test',
        <String, dynamic>{'a': 1},
        <String, String>{'os': 'pc'},
      );

      expect(
        params,
        '4DC723619A991588865191FD2F319BADC57385CFA2EFC657CB991A8ACDE9A1A3'
        '340DA74A86F2530D86400693765D21DECFB98636AD9B4C4C09DE4B2DE0353E10'
        'E1EEDCA79CE10C9C3E5B46539CDC4892B1A2E1B68819AB6CFAAE49F22221C561',
      );
    });

    test('decrypts back to the signed plaintext', () {
      final params = NeteaseCrypto.eapi(
        '/api/test',
        <String, dynamic>{'a': 1},
        <String, String>{'os': 'pc'},
      );
      final bytes = Uint8List.fromList(
        RegExp(r'.{2}').allMatches(params).map((m) => int.parse(m.group(0)!, radix: 16)).toList(),
      );

      final plain = NeteaseCrypto.eapiDecrypt(bytes);
      expect(plain, contains('/api/test-36cd479b6b5-'));
      expect(plain, contains('{"a":1,"header":{"os":"pc"}}'));
    });

    test('round-trips an empty body across a PKCS7 block boundary', () {
      final params = NeteaseCrypto.eapi('/api/test', <String, dynamic>{}, <String, String>{});
      final bytes = Uint8List.fromList(
        RegExp(r'.{2}').allMatches(params).map((m) => int.parse(m.group(0)!, radix: 16)).toList(),
      );

      final plain = NeteaseCrypto.eapiDecrypt(bytes);
      expect(plain, contains('/api/test-36cd479b6b5-{"header":{}}'));
    });
  });
}
