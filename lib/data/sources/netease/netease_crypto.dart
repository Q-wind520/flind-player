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
import 'dart:math';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:pointycastle/export.dart';

/// NetEase's `weapi` / `eapi` request signing.
///
/// Pure functions: no network, no I/O. The fixed keys are the well-known
/// web-client constants; the RSA step is the raw public-key operation
/// (`m^e mod n`) that NetEase expects.
abstract final class NeteaseCrypto {
  static const String _presetKey = '0CoJUm6Qyw8W8jud';
  static const String eapiKey = 'e82ckenh8dichen8';
  static const String _base62 =
      'abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789';

  static final List<int> _iv = utf8.encode('0102030405060708');
  static final BigInt _rsaModulus = BigInt.parse(
    '00e0b509f6259df8642dbc35662901477df22677ec152b5ff68ace615bb7b72515'
    '2b3ab17a876aea8a5aa76d2e417629ec4ee341f56135fccf695280104e0312ec'
    'bda92557c93870114af6c9d05c4f7f0c3685b7a46bee255932575cce10b424d'
    '813cfe4875d3e82047b97ddef52741d546b8e289dc6935b3ece0462db0a22b8e7',
    radix: 16,
  );
  static final BigInt _rsaExponent = BigInt.from(0x10001);

  /// Signs a `weapi` body with a `params` / `encSecKey` pair.
  ///
  /// [secretKey] is injectable for tests; production uses 16 random base62
  /// characters.
  static ({String params, String encSecKey}) weapi(
    Map<String, dynamic> object, {
    Uint8List? secretKey,
  }) {
    final key = secretKey ?? _randomSecretKey();
    final inner = _aesCbcEncrypt(utf8.encode(jsonEncode(object)), utf8.encode(_presetKey));
    final middle = utf8.encode(base64.encode(inner));
    final outer = _aesCbcEncrypt(middle, key);
    return (params: base64.encode(outer), encSecKey: _rsaEncrypt(key));
  }

  /// Signs an `eapi` body. [path] carries the `/api` prefix.
  static String eapi(
    String path,
    Map<String, dynamic> body,
    Map<String, String> header,
  ) {
    final text = jsonEncode(<String, dynamic>{...body, 'header': header});
    final digest = md5.convert(utf8.encode('nobody${path}use${text}md5forencrypt')).toString();
    final data = '$path-36cd479b6b5-$text-36cd479b6b5-$digest';
    final encrypted = _aesEcbEncrypt(utf8.encode(data), utf8.encode(eapiKey));
    return encrypted.map((b) => b.toRadixString(16).padLeft(2, '0')).join().toUpperCase();
  }

  /// Decrypts an `eapi` `params` payload (used for round-trip tests).
  static String eapiDecrypt(Uint8List cipher) {
    final padded = PaddedBlockCipherImpl(PKCS7Padding(), ECBBlockCipher(AESEngine()))
      ..init(
        false,
        PaddedBlockCipherParameters(KeyParameter(Uint8List.fromList(utf8.encode(eapiKey))), null),
      );
    return utf8.decode(padded.process(cipher));
  }

  static Uint8List _aesCbcEncrypt(List<int> data, List<int> key) {
    final cipher = PaddedBlockCipherImpl(PKCS7Padding(), CBCBlockCipher(AESEngine()))
      ..init(
        true,
        PaddedBlockCipherParameters(
          ParametersWithIV(
            KeyParameter(Uint8List.fromList(key)),
            Uint8List.fromList(_iv),
          ),
          null,
        ),
      );
    return cipher.process(Uint8List.fromList(data));
  }

  static Uint8List _aesEcbEncrypt(List<int> data, List<int> key) {
    final cipher = PaddedBlockCipherImpl(PKCS7Padding(), ECBBlockCipher(AESEngine()))
      ..init(
        true,
        PaddedBlockCipherParameters(KeyParameter(Uint8List.fromList(key)), null),
      );
    return cipher.process(Uint8List.fromList(data));
  }

  static String _rsaEncrypt(Uint8List secretKey) {
    var value = BigInt.zero;
    for (final byte in secretKey.reversed) {
      value = (value << 8) | BigInt.from(byte);
    }
    return value
        .modPow(_rsaExponent, _rsaModulus)
        .toRadixString(16)
        .padLeft(256, '0');
  }

  static Uint8List _randomSecretKey() {
    final random = Random.secure();
    return Uint8List.fromList(
      List<int>.generate(16, (_) => _base62.codeUnitAt(random.nextInt(62))),
    );
  }
}
