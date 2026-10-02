# 网易云音乐音源 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 新增网易云（`netease`）在线源（匿名搜索 + 128k 播放 + 同步双语歌词），并把「多在线源」提升为一等能力。

**Architecture:** 沿用 Bilibili 的 `MusicSource`/`StreamResolver` 适配器范式，在 `data/sources/netease/` 内自实现 `weapi`/`eapi` 加密与端点；用一个 `onlineSourcesProvider` 注册表同时派生搜索、流解析与歌词路由，搜索界面按源分段切换；`SourceTrackId` 的持久化编解码收敛为唯一实现。

**Tech Stack:** Flutter / Dart 3、Riverpod、Dio、`crypto`（md5）、`pointycastle`（AES-128-CBC/ECB + PKCS7）、`BigInt.modPow`（原始 RSA）。

**Spec:** `docs/archive/spec-netease-source-2026-10-01.md`

> 状态：**已实现并发布（v1.0.0），2026-10-02 归档。**

## Global Constraints

- **不做登录**；不持久化 `MUSIC_U`；不取无损/Hi-Res；不做歌单/收藏/每日推荐。
- **不做歌词磁盘缓存**（仅 Riverpod 会话内内存）；不做逐字（`klyric`）与罗马音（`romalrc`）。
- **所有请求绝不发 `Origin`**。网易云固定 `Referer: https://music.163.com`，Bilibili 维持 `https://www.bilibili.com/`。
- AES 只用 `pointycastle`；RSA 只用 `dart:core` 的 `BigInt.modPow`；不引入其它加密依赖。
- 新建 Dart 文件带现有 GPL-3.0 文件头（复制任一现有文件的第 1–14 行）。
- 源隔离：`features/`、播放、缓存不得 import 具体 `NeteaseSource`/`NeteaseClient`，只经接口与 provider。
- l10n 改 `lib/l10n/app_en.arb` 与 `app_zh.arb` 后运行 `flutter gen-l10n`。
- 每条任务结束跑 `flutter analyze`（0 error）与相关 `flutter test <path>`。

## Review Focus

- **VIP/无版权/地区限制**：匿名 `songUrl` 返回 `url=null` → UI 显示「不可播放」，绝不崩溃或误播。
- **跨会话身份**：`netease:` 曲目从 DB 或队列 JSON 快照恢复后仍是 `NeteaseTrackId`（不退化成 `LocalTrackId`），且能解析流。
- **LRC 变体**：`[mm:ss.xx]` 与 `[mm:ss.xxx]`、一行多标签、`[offset:±ms]`、翻译时间戳、纯音乐占位。
- **搜索切源**：空/空白查询不请求；切源显示对应源结果；被禁用源不出现在标签中。
- **加密精确性**：非 ASCII JSON、PKCS7 整块/空串边界、RSA 左补零到 128 字节。

---

### Task 1: 身份与编解码收敛

**Files:**
- Modify: `lib/core/sources/source_track_id.dart`
- Create: `lib/data/codec/source_track_id_codec.dart`
- Modify: `lib/data/codec/track_codec.dart:96-138`
- Modify: `lib/data/repositories/drift_music_library_repository.dart:451-478`
- Modify: `lib/data/repositories/drift_playlist_repository.dart:298-315`
- Modify: `lib/data/cache/cache_keys.dart:23-28`
- Test: `test/source_track_id_codec_test.dart`（新建）、`test/track_codec_test.dart`（补用例）

**Interfaces:**
- Produces:
  - `final class NeteaseTrackId extends SourceTrackId { final int songId; const NeteaseTrackId({required int songId}); }`
  - `String encodeSourceTrackId(SourceTrackId id)`
  - `SourceTrackId decodeSourceTrackId(String source, String raw, String uri)`
  - `Map<String, dynamic> encodeSourceTrackIdJson(SourceTrackId id)`
  - `SourceTrackId decodeSourceTrackIdJson(Object? value)`

- [ ] **Step 1: 加 `NeteaseTrackId`**

在 `lib/core/sources/source_track_id.dart` 末尾（`BiliTrackId` 之后）追加：

```dart
/// Identity of a NetEase Cloud Music track.
final class NeteaseTrackId extends SourceTrackId {
  /// NetEase song id; unique within the `netease` source.
  final int songId;

  const NeteaseTrackId({required this.songId});

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is NeteaseTrackId && other.songId == songId;

  @override
  int get hashCode => Object.hash(runtimeType, songId);

  @override
  String toString() => 'NeteaseTrackId($songId)';
}
```

- [ ] **Step 2: 新建共享 codec**

Create `lib/data/codec/source_track_id_codec.dart`：

```dart
// Flind Player - cross-platform music player
// Copyright (C) 2026 top.qwind.app
// ...（复制现有 GPL 头 14 行）...

import 'package:flind_player/core/sources/source_track_id.dart';

/// Canonical persistence mapping for [SourceTrackId].
///
/// Single source of truth shared by the drift repositories and the JSON track
/// codec. Add a new source here once; the drift `if`-chains can no longer
/// silently degrade an unknown source to `LocalTrackId`.
String encodeSourceTrackId(SourceTrackId id) => switch (id) {
  LocalTrackId(:final path) => path,
  BiliTrackId(:final bvid, :final cid) => '$bvid:$cid',
  NeteaseTrackId(:final songId) => '$songId',
};

/// Rebuilds the id from the persisted `source` + `source_track_id` columns.
///
/// An unknown source or a malformed value falls back to a local identity keyed
/// by the canonical [uri] so the row stays usable.
SourceTrackId decodeSourceTrackId(String source, String raw, String uri) {
  if (source == 'local') return LocalTrackId(raw);
  if (source == 'bilibili') {
    final separator = raw.lastIndexOf(':');
    if (separator > 0) {
      final cid = int.tryParse(raw.substring(separator + 1));
      if (cid != null) {
        return BiliTrackId(bvid: raw.substring(0, separator), cid: cid);
      }
    }
  }
  if (source == 'netease') {
    final songId = int.tryParse(raw);
    if (songId != null) return NeteaseTrackId(songId: songId);
  }
  return LocalTrackId(uri);
}

Map<String, dynamic> encodeSourceTrackIdJson(SourceTrackId id) => switch (id) {
  LocalTrackId(:final path) => <String, dynamic>{'kind': 'local', 'path': path},
  BiliTrackId(:final bvid, :final cid) => <String, dynamic>{
    'kind': 'bili',
    'bvid': bvid,
    'cid': cid,
  },
  NeteaseTrackId(:final songId) => <String, dynamic>{
    'kind': 'netease',
    'songId': songId,
  },
};

SourceTrackId decodeSourceTrackIdJson(Object? value) {
  if (value is! Map) {
    throw FormatException('Track.sourceTrackId must be an object, got: $value');
  }
  switch (value['kind']) {
    case 'local':
      final path = value['path'];
      if (path is! String) {
        throw FormatException(
          'Local SourceTrackId.path must be a string, got: $path',
        );
      }
      return LocalTrackId(path);
    case 'bili':
      final bvid = value['bvid'];
      final cid = value['cid'];
      if (bvid is! String || cid is! int) {
        throw FormatException(
          'Bili SourceTrackId requires a string bvid and int cid, '
          'got: bvid=$bvid, cid=$cid',
        );
      }
      return BiliTrackId(bvid: bvid, cid: cid);
    case 'netease':
      final songId = value['songId'];
      if (songId is! int) {
        throw FormatException(
          'Netease SourceTrackId requires an int songId, got: $songId',
        );
      }
      return NeteaseTrackId(songId: songId);
    default:
      throw FormatException('Unknown SourceTrackId kind: ${value['kind']}');
  }
}
```

- [ ] **Step 3: 写失败测试**

Create `test/source_track_id_codec_test.dart`：

```dart
// ...（GPL 头）...

import 'package:flutter_test/flutter_test.dart';

import 'package:flind_player/core/sources/source_track_id.dart';
import 'package:flind_player/data/codec/source_track_id_codec.dart';

void main() {
  group('encodeSourceTrackId / decodeSourceTrackId', () {
    test('round-trips a netease id through the source column', () {
      expect(encodeSourceTrackId(const NeteaseTrackId(songId: 123)), '123');
      expect(
        decodeSourceTrackId('netease', '123', 'netease:123'),
        const NeteaseTrackId(songId: 123),
      );
    });

    test('round-trips bilibili and local ids', () {
      expect(encodeSourceTrackId(const BiliTrackId(bvid: 'BV1', cid: 2)), 'BV1:2');
      expect(
        decodeSourceTrackId('bilibili', 'BV1:2', 'bilibili:BV1:2'),
        const BiliTrackId(bvid: 'BV1', cid: 2),
      );
      expect(encodeSourceTrackId(const LocalTrackId('/m/a.mp3')), '/m/a.mp3');
      expect(
        decodeSourceTrackId('local', '/m/a.mp3', 'local:/m/a.mp3'),
        const LocalTrackId('/m/a.mp3'),
      );
    });

    test('falls back to a uri-keyed local id for an unknown source', () {
      expect(
        decodeSourceTrackId('spotify', 'x', 'spotify:1'),
        const LocalTrackId('spotify:1'),
      );
      expect(
        decodeSourceTrackId('netease', 'not-a-number', 'netease:x'),
        const LocalTrackId('netease:x'),
      );
    });
  });

  group('JSON codec', () {
    test('encodes netease as a tagged object and round-trips', () {
      final json = encodeSourceTrackIdJson(const NeteaseTrackId(songId: 7));
      expect(json, <String, dynamic>{'kind': 'netease', 'songId': 7});
      expect(
        decodeSourceTrackIdJson(json),
        const NeteaseTrackId(songId: 7),
      );
    });

    test('throws for an unknown kind', () {
      expect(
        () => decodeSourceTrackIdJson(<String, dynamic>{'kind': 'mystery'}),
        throwsFormatException,
      );
    });
  });
}
```

- [ ] **Step 4: 运行测试确认失败**

Run: `flutter test test/source_track_id_codec_test.dart`
Expected: 编译失败（`NeteaseTrackId` / `encodeSourceTrackId` 未定义或未实现）。

- [ ] **Step 5: 迁移三处调用方**

`lib/data/codec/track_codec.dart`：
- 加 `import 'package:flind_player/data/codec/source_track_id_codec.dart';`，删除 `import 'package:flind_player/core/sources/source_track_id.dart';`。
- 第 35 行 `_encodeSourceTrackId(track.sourceTrackId)` → `encodeSourceTrackIdJson(track.sourceTrackId)`。
- 第 61 行 `_decodeSourceTrackId(json['sourceTrackId'])` → `decodeSourceTrackIdJson(json['sourceTrackId'])`。
- 删除私有 `_encodeSourceTrackId`（96–108）与 `_decodeSourceTrackId`（110–138）。

`lib/data/repositories/drift_music_library_repository.dart`：
- 加 `import 'package:flind_player/data/codec/source_track_id_codec.dart';`。
- 第 425 行 `_encodeSourceTrackId(track.sourceTrackId)` → `encodeSourceTrackId(track.sourceTrackId)`。
- 第 393 行 `_decodeSourceTrackId(source, sourceTrackId, uri)` → `decodeSourceTrackId(source, sourceTrackId, uri)`。
- 删除私有 `_encodeSourceTrackId`（451）与 `_decodeSourceTrackId`（464–478）。

`lib/data/repositories/drift_playlist_repository.dart`：
- 加同样的 import。
- 第 284 行 `_decodeSourceTrackId(source, sourceTrackId, uri)` → `decodeSourceTrackId(source, sourceTrackId, uri)`。
- 删除私有 `_decodeSourceTrackId`（298–315）。

`lib/data/cache/cache_keys.dart` 第 26 行后加：

```dart
  if (id is NeteaseTrackId) return id.songId.toString();
```

- [ ] **Step 6: 补 track_codec 测试并运行**

在 `test/track_codec_test.dart` 的 `encodeTrack / decodeTrack` group 内加：

```dart
    test('round-trips a netease track and tags its sourceTrackId', () {
      const track = Track(
        id: 9,
        source: 'netease',
        sourceTrackId: NeteaseTrackId(songId: 550136151),
        uri: 'netease:550136151',
        title: 'It\'s Ok',
        artist: 'Artist',
        album: 'Album',
      );

      final json = encodeTrack(track);
      expect(json['sourceTrackId'], {'kind': 'netease', 'songId': 550136151});
      expect(decodeTrack(json), track);
      expect(decodeTrack(json).sourceTrackId, const NeteaseTrackId(songId: 550136151));
    });
```

Run: `flutter test test/source_track_id_codec_test.dart test/track_codec_test.dart test/drift_music_library_repository_test.dart test/playlist_repository_test.dart`
Expected: PASS。

- [ ] **Step 7: Commit**

```bash
git add lib/core/sources/source_track_id.dart lib/data/codec/source_track_id_codec.dart \
  lib/data/codec/track_codec.dart lib/data/repositories/drift_music_library_repository.dart \
  lib/data/repositories/drift_playlist_repository.dart lib/data/cache/cache_keys.dart \
  test/source_track_id_codec_test.dart test/track_codec_test.dart
git commit -m "feat(netease): add NeteaseTrackId and converge SourceTrackId codecs"
```

---

### Task 2: 歌词内核（模型 + LRC 解析 + 接口）

**Files:**
- Create: `lib/core/models/lyric.dart`
- Create: `lib/core/services/lyrics_provider.dart`
- Create: `lib/core/services/lrc_parser.dart`
- Test: `test/lrc_parser_test.dart`

**Interfaces:**
- Produces:
  - `class LyricLine { final Duration timestamp; final String text; final String? translation; const LyricLine({required this.timestamp, required this.text, this.translation}); }`
  - `class Lyric { final List<LyricLine> lines; const Lyric(List<LyricLine> lines); int? indexAt(Duration position); }`
  - `abstract interface class LyricsProvider { Future<Lyric?> lyricsFor(Track track); }`
  - `Lyric? parseLrc(String? original, {String? translation})`

- [ ] **Step 1: 写失败测试**

Create `test/lrc_parser_test.dart`：

```dart
// ...（GPL 头）...

import 'package:flutter_test/flutter_test.dart';

import 'package:flind_player/core/services/lrc_parser.dart';

void main() {
  test('parses multiple timestamps on one line and sorts them', () {
    final lyric = parseLrc('[00:01.00][00:05.00]Hello\n[00:03.5]World')!;
    expect(lyric.lines.map((l) => l.text), <String>['Hello', 'World', 'Hello']);
    expect(lyric.lines.map((l) => l.timestamp), <Duration>[
      const Duration(seconds: 1),
      const Duration(milliseconds: 3500),
      const Duration(seconds: 5),
    ]);
  });

  test('parses hundredths and thousandths fractions', () {
    final lyric = parseLrc('[00:00.05]A\n[00:00.005]B')!;
    expect(lyric.lines[0].timestamp, const Duration(milliseconds: 50));
    expect(lyric.lines[1].timestamp, const Duration(milliseconds: 5));
  });

  test('applies [offset:±ms] and ignores metadata tags', () {
    final lyric = parseLrc('[ti:T]\n[ar:A]\n[offset:500]\n[00:01.00]Hi')!;
    expect(lyric.lines, hasLength(1));
    expect(lyric.lines.single.timestamp, const Duration(milliseconds: 1500));
  });

  test('merges translation by exact timestamp', () {
    final lyric = parseLrc(
      '[00:01.00]原文\n[00:02.00]Second',
      translation: '[00:01.00]translated',
    )!;
    expect(lyric.lines[0].translation, 'translated');
    expect(lyric.lines[1].translation, isNull);
  });

  test('returns null for the pure-music placeholder', () {
    expect(parseLrc('[99:00.00]纯音乐，请欣赏\n'), isNull);
  });

  test('returns null for null or blank input', () {
    expect(parseLrc(null), isNull);
    expect(parseLrc(''), isNull);
    expect(parseLrc('[00:01.00]\n'), isNull);
  });

  group('Lyric.indexAt', () {
    final lyric = Lyric(const <LyricLine>[
      LyricLine(timestamp: Duration(seconds: 1), text: 'a'),
      LyricLine(timestamp: Duration(seconds: 3), text: 'b'),
    ]);

    test('returns 0 before the first line', () {
      expect(lyric.indexAt(Duration.zero), 0);
    });

    test('returns the last line at or before the position', () {
      expect(lyric.indexAt(const Duration(seconds: 2)), 0);
      expect(lyric.indexAt(const Duration(seconds: 3)), 1);
      expect(lyric.indexAt(const Duration(seconds: 9)), 1);
    });

    test('returns null for an empty lyric', () {
      expect(const Lyric(<LyricLine>[]).indexAt(Duration.zero), isNull);
    });
  });
}
```

- [ ] **Step 2: 运行确认失败**

Run: `flutter test test/lrc_parser_test.dart`
Expected: FAIL（`lyric.dart` / `lrc_parser.dart` 不存在）。

- [ ] **Step 3: 实现模型与接口**

Create `lib/core/models/lyric.dart`：

```dart
// ...（GPL 头）...

import 'package:flutter/foundation.dart';

/// One timed lyric line, optionally carrying its translation.
@immutable
class LyricLine {
  final Duration timestamp;
  final String text;
  final String? translation;

  const LyricLine({
    required this.timestamp,
    required this.text,
    this.translation,
  });

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is LyricLine &&
          other.timestamp == timestamp &&
          other.text == text &&
          other.translation == translation;

  @override
  int get hashCode => Object.hash(timestamp, text, translation);
}

/// A track's lyrics as an ascending time line.
@immutable
class Lyric {
  /// Lines sorted by [LyricLine.timestamp].
  final List<LyricLine> lines;

  const Lyric(this.lines);

  /// Index of the last line whose timestamp is `<= position`.
  ///
  /// Returns `0` when [position] precedes the first line and `null` when
  /// [lines] is empty. Binary search.
  int? indexAt(Duration position) {
    if (lines.isEmpty) return null;
    var low = 0;
    var high = lines.length - 1;
    var result = 0;
    while (low <= high) {
      final mid = (low + high) >> 1;
      if (lines[mid].timestamp <= position) {
        result = mid;
        low = mid + 1;
      } else {
        high = mid - 1;
      }
    }
    return result;
  }
}
```

Create `lib/core/services/lyrics_provider.dart`：

```dart
// ...（GPL 头）...

import 'package:flind_player/core/models/lyric.dart';
import 'package:flind_player/core/models/track.dart';

/// Fetches lyrics for a track from one online source.
///
/// Implementations return `null` when the source has no lyrics for the track;
/// a missing lyric is not an error.
abstract interface class LyricsProvider {
  Future<Lyric?> lyricsFor(Track track);
}
```

Create `lib/core/services/lrc_parser.dart`：

```dart
// ...（GPL 头）...

import 'package:flind_player/core/models/lyric.dart';

final RegExp _timeTag = RegExp(r'\[(\d{1,3}):(\d{1,2})(?:[.:](\d{1,3}))?\]');
final RegExp _offsetTag = RegExp(r'\[offset:([+-]?\d+)\]', caseSensitive: false);
const String _pureMusicMarker = '纯音乐，请欣赏';

/// Parses an LRC document into a [Lyric], merging an optional translation.
///
/// Returns `null` when [original] is absent/blank, contains no timed line, or
/// is only the pure-music placeholder. Supports `[mm:ss]`, `[mm:ss.xx]`,
/// `[mm:ss.xxx]`, several tags per line, and `[offset:±ms]`.
Lyric? parseLrc(String? original, {String? translation}) {
  if (original == null) return null;
  final entries = _parseTimed(original);
  if (entries.isEmpty) return null;
  if (entries.every((e) => e.value == _pureMusicMarker)) return null;

  final translations = <int, String>{};
  if (translation != null) {
    for (final entry in _parseTimed(translation)) {
      final text = entry.value;
      if (text.isNotEmpty) translations[entry.key] = text;
    }
  }

  final lines = entries
      .map(
        (e) => LyricLine(
          timestamp: Duration(milliseconds: e.key),
          text: e.value,
          translation: translations[e.key],
        ),
      )
      .toList(growable: false);
  return Lyric(lines);
}

List<MapEntry<int, String>> _parseTimed(String raw) {
  final offsetMs = _offsetOf(raw);
  final entries = <MapEntry<int, String>>[];
  for (final line in raw.split('\n')) {
    final matches = _timeTag.allMatches(line).toList(growable: false);
    if (matches.isEmpty) continue;
    final text = line.substring(matches.last.end).trim();
    if (text.isEmpty) continue;
    for (final match in matches) {
      final minutes = int.parse(match.group(1)!);
      final seconds = int.parse(match.group(2)!);
      final millis = _fractionToMs(match.group(3));
      final total = minutes * 60000 + seconds * 1000 + millis + offsetMs;
      entries.add(MapEntry(total < 0 ? 0 : total, text));
    }
  }
  entries.sort((a, b) => a.key.compareTo(b.key));
  return entries;
}

int _offsetOf(String raw) {
  final match = _offsetTag.firstMatch(raw);
  return match == null ? 0 : int.tryParse(match.group(1)!) ?? 0;
}

int _fractionToMs(String? fraction) {
  if (fraction == null) return 0;
  final value = int.parse(fraction);
  return switch (fraction.length) {
    1 => value * 100,
    2 => value * 10,
    _ => value,
  };
}
```

- [ ] **Step 4: 运行测试确认通过**

Run: `flutter test test/lrc_parser_test.dart`
Expected: PASS。

- [ ] **Step 5: Commit**

```bash
git add lib/core/models/lyric.dart lib/core/services/lyrics_provider.dart lib/core/services/lrc_parser.dart test/lrc_parser_test.dart
git commit -m "feat(lyrics): add Lyric model, LyricsProvider and LRC parser"
```

---

### Task 3: 加密内核（weapi / eapi）

**Files:**
- Modify: `pubspec.yaml`（加 `pointycastle`）
- Create: `lib/data/sources/netease/netease_crypto.dart`
- Test: `test/netease_crypto_test.dart`

**Interfaces:**
- Produces:
  - `NeteaseCrypto.weapi(Map<String, dynamic> object, {Uint8List? secretKey}) -> ({String params, String encSecKey})`
  - `NeteaseCrypto.eapi(String path, Map<String, dynamic> body, Map<String, String> header) -> String`
  - `NeteaseCrypto.eapiDecrypt(Uint8List cipher) -> String`
  - `NeteaseCrypto.eapiKey`

- [ ] **Step 1: 加依赖**

`pubspec.yaml` 的 `dependencies` 中按字母序插入：

```yaml
  pointycastle: ^4.0.0
```

Run: `flutter pub get`
Expected: 解析成功。

- [ ] **Step 2: 写失败测试（含实采向量）**

Create `test/netease_crypto_test.dart`：

```dart
// ...（GPL 头）...

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
  });
}
```

- [ ] **Step 3: 运行确认失败**

Run: `flutter test test/netease_crypto_test.dart`
Expected: FAIL（`netease_crypto.dart` 不存在）。

- [ ] **Step 4: 实现**

Create `lib/data/sources/netease/netease_crypto.dart`：

```dart
// ...（GPL 头）...

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
  static const BigInt _rsaExponent = BigInt.from(0x10001);

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
      ..init(false, KeyParameter(Uint8List.fromList(utf8.encode(eapiKey))));
    return utf8.decode(padded.process(cipher));
  }

  static Uint8List _aesCbcEncrypt(List<int> data, List<int> key) {
    final cipher = PaddedBlockCipherImpl(PKCS7Padding(), CBCBlockCipher(AESEngine()))
      ..init(
        true,
        ParametersWithIV(
          KeyParameter(Uint8List.fromList(key)),
          Uint8List.fromList(_iv),
        ),
      );
    return cipher.process(Uint8List.fromList(data));
  }

  static Uint8List _aesEcbEncrypt(List<int> data, List<int> key) {
    final cipher = PaddedBlockCipherImpl(PKCS7Padding(), ECBBlockCipher(AESEngine()))
      ..init(true, KeyParameter(Uint8List.fromList(key)));
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
```

- [ ] **Step 5: 运行测试确认通过**

Run: `flutter test test/netease_crypto_test.dart`
Expected: PASS（两组向量一致）。

- [ ] **Step 6: Commit**

```bash
git add pubspec.yaml pubspec.lock lib/data/sources/netease/netease_crypto.dart test/netease_crypto_test.dart
git commit -m "feat(netease): add weapi/eapi request signing"
```

---

### Task 4: 网易云 HTTP 客户端

**Files:**
- Create: `lib/data/sources/netease/netease_client.dart`
- Test: `test/netease_client_test.dart`

**Interfaces:**
- Consumes: `NeteaseCrypto.weapi` / `NeteaseCrypto.eapi`（Task 3）
- Produces:
  - `const String kNeteaseReferer = 'https://music.163.com';`
  - `class NeteaseApiException implements Exception { final int code; final String message; const NeteaseApiException(int code, String message); factory NeteaseApiException.fromCode(int code, [String? serverMessage]); }`
  - `class NeteaseClient { NeteaseClient({Dio? dio, String userAgent}); Future<Map<String, dynamic>> postWeapi(String path, Map<String, dynamic> body); Future<Map<String, dynamic>> postEapi(String apiPath, Map<String, dynamic> body); }`

- [ ] **Step 1: 写失败测试**

Create `test/netease_client_test.dart`：

```dart
// ...（GPL 头）...

import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:flind_player/data/sources/netease/netease_client.dart';
import 'package:flind_player/data/sources/netease/netease_crypto.dart';

class _FakeAdapter implements HttpClientAdapter {
  _FakeAdapter(this.handler);
  final Future<ResponseBody> Function(RequestOptions options) handler;
  RequestOptions? lastRequest;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) {
    lastRequest = options;
    return handler(options);
  }

  @override
  void close({bool force = false}) {}
}

NeteaseClient _client(_FakeAdapter adapter) {
  final dio = Dio()..httpClientAdapter = adapter;
  return NeteaseClient(dio: dio);
}

ResponseBody _json(Map<String, dynamic> body) => ResponseBody.fromString(
  jsonEncode(body),
  200,
  headers: <String, List<String>>{
    Headers.contentTypeHeader: <String>['application/json'],
  },
);

void main() {
  test('weapi posts form params and sends the mandatory headers, no Origin', () async {
    final adapter = _FakeAdapter((_) async => _json(<String, dynamic>{'code': 200, 'result': <String, dynamic>{}}));

    await _client(adapter).postWeapi('/weapi/cloudsearch/get/web?csrf_token=', <String, dynamic>{'s': 'q'});

    final request = adapter.lastRequest!;
    expect(request.headers['Referer'], kNeteaseReferer);
    expect(request.headers.containsKey('Origin'), isFalse);
    final data = request.data as Map;
    expect(data['params'], isA<String>());
    expect(data['encSecKey'], isA<String>());
  });

  test('eapi signs the /api path and sends the anonymous os=pc cookie', () async {
    final adapter = _FakeAdapter((_) async => _json(<String, dynamic>{'code': 200, 'data': <dynamic>[]}));

    await _client(adapter).postEapi('/song/enhance/player/url/v1', <String, dynamic>{'ids': '[1]'});

    final request = adapter.lastRequest!;
    expect(request.uri.path, '/eapi/song/enhance/player/url/v1');
    expect(request.headers['Cookie'], contains('os=pc'));
    expect(request.headers.containsKey('Origin'), isFalse);

    final params = (request.data as Map)['params'] as String;
    final bytes = Uint8List.fromList(
      RegExp(r'.{2}').allMatches(params).map((m) => int.parse(m.group(0)!, radix: 16)).toList(),
    );
    expect(NeteaseCrypto.eapiDecrypt(bytes), contains('/api/song/enhance/player/url/v1'));
  });

  test('maps code -462 to a login-required error', () async {
    final adapter = _FakeAdapter((_) async => _json(<String, dynamic>{'code': -462, 'message': 'need login'}));

    expect(
      () => _client(adapter).postWeapi('/weapi/x', <String, dynamic>{}),
      throwsA(
        isA<NeteaseApiException>()
            .having((e) => e.code, 'code', -462)
            .having((e) => e.message, 'message', contains('login')),
      ),
    );
  });

  test('throws for a non-JSON body', () async {
    final adapter = _FakeAdapter((_) async => ResponseBody.fromString('nope', 200));
    expect(
      () => _client(adapter).postWeapi('/weapi/x', <String, dynamic>{}),
      throwsA(isA<NeteaseApiException>()),
    );
  });
}
```

- [ ] **Step 2: 运行确认失败**

Run: `flutter test test/netease_client_test.dart`
Expected: FAIL（`netease_client.dart` 不存在）。

- [ ] **Step 3: 实现**

Create `lib/data/sources/netease/netease_client.dart`：

```dart
// ...（GPL 头）...

import 'package:dio/dio.dart';

import 'package:flind_player/data/sources/bilibili/bili_client.dart';
import 'package:flind_player/data/sources/netease/netease_crypto.dart';

/// The `Referer` every NetEase API and CDN request must carry.
const String kNeteaseReferer = 'https://music.163.com';

/// Anonymous client cookies required by the `eapi` endpoints.
const String _anonCookie =
    'os=pc; appver=8.0.0; versioncode=140; mobilename=undefined; '
    'buildver=1623435496; resolution=1920x1080; __csrf=; channel=undefined';

/// Thrown when the API answers HTTP 200 with a non-200 JSON `code`.
class NeteaseApiException implements Exception {
  final int code;
  final String message;

  const NeteaseApiException(this.code, this.message);

  factory NeteaseApiException.fromCode(int code, [String? serverMessage]) {
    if (code == -462) {
      return const NeteaseApiException(-462, 'NetEase login required (-462)');
    }
    final message = (serverMessage == null || serverMessage.isEmpty)
        ? 'NetEase API error'
        : serverMessage;
    return NeteaseApiException(code, '$message (code: $code)');
  }

  @override
  String toString() => 'NeteaseApiException($code): $message';
}

/// Thin Dio wrapper around `music.163.com` (`weapi`) and
/// `interface3.music.163.com` (`eapi`).
class NeteaseClient {
  static const String weapiBaseUrl = 'https://music.163.com';
  static const String eapiBaseUrl = 'https://interface3.music.163.com';

  final String userAgent;
  final Dio _dio;

  NeteaseClient({Dio? dio, this.userAgent = kDesktopUserAgent})
    : _dio = dio ?? Dio() {
    _dio.options
      ..baseUrl = weapiBaseUrl
      ..connectTimeout = const Duration(seconds: 10)
      ..receiveTimeout = const Duration(seconds: 15)
      ..sendTimeout = const Duration(seconds: 10)
      ..validateStatus = (_) => true
      ..headers['User-Agent'] = userAgent
      ..headers['Referer'] = kNeteaseReferer
      ..headers['Accept'] = 'application/json, text/plain, */*'
      ..headers['Accept-Language'] = 'zh-CN,zh;q=0.9,en;q=0.8'
      ..headers.remove('Origin');
  }

  Future<Map<String, dynamic>> postWeapi(
    String path,
    Map<String, dynamic> body,
  ) async {
    final signed = NeteaseCrypto.weapi(body);
    final response = await _dio.post<Object?>(
      path,
      data: <String, dynamic>{
        'params': signed.params,
        'encSecKey': signed.encSecKey,
      },
      options: Options(contentType: Headers.formUrlEncodedContentType),
    );
    return _decode(response, path);
  }

  Future<Map<String, dynamic>> postEapi(
    String apiPath,
    Map<String, dynamic> body,
  ) async {
    final params = NeteaseCrypto.eapi(
      '/api$apiPath',
      body,
      const <String, String>{'os': 'pc'},
    );
    final response = await _dio.post<Object?>(
      '$eapiBaseUrl/eapi$apiPath',
      data: <String, dynamic>{'params': params},
      options: Options(
        contentType: Headers.formUrlEncodedContentType,
        headers: <String, String>{'Cookie': _anonCookie},
      ),
    );
    return _decode(response, apiPath);
  }

  Map<String, dynamic> _decode(Response<Object?> response, String path) {
    final data = response.data;
    if (data is! Map) {
      throw NeteaseApiException(
        -1,
        'Unexpected non-JSON response for $path (HTTP ${response.statusCode})',
      );
    }
    final json = Map<String, dynamic>.from(data);
    final code = (json['code'] as num?)?.toInt() ?? 200;
    if (code != 200) {
      throw NeteaseApiException.fromCode(
        code,
        json['message'] as String? ?? json['msg'] as String?,
      );
    }
    return json;
  }
}
```

- [ ] **Step 4: 运行测试确认通过**

Run: `flutter test test/netease_client_test.dart`
Expected: PASS。

- [ ] **Step 5: Commit**

```bash
git add lib/data/sources/netease/netease_client.dart test/netease_client_test.dart
git commit -m "feat(netease): add Dio client and typed API errors"
```

---

### Task 5: DTO 与端点 API

**Files:**
- Create: `lib/data/sources/netease/netease_models.dart`
- Create: `lib/data/sources/netease/netease_api.dart`
- Test: `test/netease_api_test.dart`

**Interfaces:**
- Consumes: `NeteaseClient`（Task 4）、`RateLimiter`（Task 7 泛化后仍兼容）
- Produces:
  - `class NeteaseSongDto { final int id; final String name; final List<String> artists; final String album; final int durationMs; final String? coverUrl; factory NeteaseSongDto.fromJson(Map<String, dynamic>); }`
  - `class NeteaseUrlDto { final String? url; final int? br; final String? level; final String? type; factory NeteaseUrlDto.fromJson(Map<String, dynamic>); }`
  - `class NeteaseLyricDto { final String? lrc; final String? translation; final String? roma; factory NeteaseLyricDto.fromJson(Map<String, dynamic>); }`
  - `class NeteaseApi { NeteaseApi({required NeteaseClient client, required RateLimiter rateLimiter}); static const int searchPageSize = 30; Future<List<NeteaseSongDto>> searchSongs(String query, {int page = 1}); Future<NeteaseSongDto?> songDetail(int songId); Future<NeteaseUrlDto?> songUrl(int songId); Future<NeteaseLyricDto> songLyric(int songId); }`

- [ ] **Step 1: 写失败测试**

Create `test/netease_api_test.dart`：

```dart
// ...（GPL 头）...

import 'package:flutter_test/flutter_test.dart';

import 'package:flind_player/data/sources/netease/netease_models.dart';

void main() {
  test('NeteaseSongDto reads cloudsearch fields', () {
    final dto = NeteaseSongDto.fromJson(<String, dynamic>{
      'id': 123,
      'name': 'Song',
      'ar': <dynamic>[
        <String, dynamic>{'name': 'A'},
        <String, dynamic>{'name': 'B'},
      ],
      'al': <String, dynamic>{'name': 'Album', 'picUrl': 'https://p1.music.126.net/a.jpg?param=300y300'},
      'dt': 215000,
    });

    expect(dto.id, 123);
    expect(dto.name, 'Song');
    expect(dto.artists, <String>['A', 'B']);
    expect(dto.album, 'Album');
    expect(dto.durationMs, 215000);
    expect(dto.coverUrl, 'https://p1.music.126.net/a.jpg?param=300y300');
  });

  test('NeteaseSongDto tolerates missing optional fields', () {
    final dto = NeteaseSongDto.fromJson(<String, dynamic>{'id': 1, 'name': 'N'});
    expect(dto.artists, isEmpty);
    expect(dto.album, '');
    expect(dto.durationMs, 0);
    expect(dto.coverUrl, isNull);
  });

  test('NeteaseUrlDto reads url/level', () {
    final dto = NeteaseUrlDto.fromJson(<String, dynamic>{
      'url': 'https://m8.music.126.net/x.mp3',
      'br': 128000,
      'level': 'standard',
      'type': 'mp3',
    });
    expect(dto.url, 'https://m8.music.126.net/x.mp3');
    expect(dto.level, 'standard');
  });

  test('NeteaseLyricDto reads lrc/tlyric/romalrc', () {
    final dto = NeteaseLyricDto.fromJson(<String, dynamic>{
      'lrc': <String, dynamic>{'lyric': '[00:01.00]a'},
      'tlyric': <String, dynamic>{'lyric': '[00:01.00]A'},
      'romalrc': <String, dynamic>{'lyric': '[00:01.00]a'},
    });
    expect(dto.lrc, '[00:01.00]a');
    expect(dto.translation, '[00:01.00]A');
    expect(dto.roma, '[00:01.00]a');
  });
}
```

- [ ] **Step 2: 运行确认失败**

Run: `flutter test test/netease_api_test.dart`
Expected: FAIL（`netease_models.dart` 不存在）。

- [ ] **Step 3: 实现 DTO**

Create `lib/data/sources/netease/netease_models.dart`：

```dart
// ...（GPL 头）...

/// One song from cloudsearch or `/weapi/v3/song/detail`.
class NeteaseSongDto {
  final int id;
  final String name;
  final List<String> artists;
  final String album;
  final int durationMs;
  final String? coverUrl;

  const NeteaseSongDto({
    required this.id,
    required this.name,
    required this.artists,
    required this.album,
    required this.durationMs,
    this.coverUrl,
  });

  factory NeteaseSongDto.fromJson(Map<String, dynamic> json) {
    final rawArtists = json['ar'];
    final artists = rawArtists is List
        ? rawArtists
              .whereType<Map>()
              .map((e) => e['name'] as String? ?? '')
              .where((name) => name.isNotEmpty)
              .toList(growable: false)
        : const <String>[];
    final album = json['al'];
    final cover = album is Map ? album['picUrl'] : null;
    return NeteaseSongDto(
      id: (json['id'] as num?)?.toInt() ?? 0,
      name: json['name'] as String? ?? '',
      artists: artists,
      album: album is Map ? album['name'] as String? ?? '' : '',
      durationMs: (json['dt'] as num?)?.toInt() ?? 0,
      coverUrl: (cover is String && cover.isNotEmpty) ? cover : null,
    );
  }
}

/// One entry from `/eapi/song/enhance/player/url/v1`.
class NeteaseUrlDto {
  final String? url;
  final int? br;
  final String? level;
  final String? type;

  const NeteaseUrlDto({this.url, this.br, this.level, this.type});

  factory NeteaseUrlDto.fromJson(Map<String, dynamic> json) => NeteaseUrlDto(
    url: (json['url'] as String?)?.isEmpty ?? true ? null : json['url'] as String,
    br: (json['br'] as num?)?.toInt(),
    level: json['level'] as String?,
    type: json['type'] as String?,
  );
}

/// The `/weapi/song/lyric` payload.
class NeteaseLyricDto {
  final String? lrc;
  final String? translation;
  final String? roma;

  const NeteaseLyricDto({this.lrc, this.translation, this.roma});

  factory NeteaseLyricDto.fromJson(Map<String, dynamic> json) {
    String? text(Object? node) {
      if (node is! Map) return null;
      final value = node['lyric'];
      return (value is String && value.isNotEmpty) ? value : null;
    }

    return NeteaseLyricDto(
      lrc: text(json['lrc']),
      translation: text(json['tlyric']),
      roma: text(json['romalrc']),
    );
  }
}
```

- [ ] **Step 4: 实现 API**

Create `lib/data/sources/netease/netease_api.dart`：

```dart
// ...（GPL 头）...

import 'dart:convert';

import 'package:flind_player/data/sources/bilibili/rate_limiter.dart';
import 'package:flind_player/data/sources/netease/netease_client.dart';
import 'package:flind_player/data/sources/netease/netease_models.dart';

/// Typed access to the NetEase endpoints the adapter needs.
class NeteaseApi {
  static const String _searchPath = '/weapi/cloudsearch/get/web?csrf_token=';
  static const String _detailPath = '/weapi/v3/song/detail?csrf_token=';
  static const String _urlPath = '/song/enhance/player/url/v1';
  static const String _lyricPath = '/weapi/song/lyric?csrf_token=';

  /// Page size used by the web cloud-search client.
  static const int searchPageSize = 30;

  final NeteaseClient _client;
  final RateLimiter _rateLimiter;

  NeteaseApi({required NeteaseClient client, required RateLimiter rateLimiter})
    : _client = client, // ignore: prefer_initializing_formals
      _rateLimiter = rateLimiter; // ignore: prefer_initializing_formals

  Future<List<NeteaseSongDto>> searchSongs(String query, {int page = 1}) async {
    final json = await _rateLimiter.run(
      () => _client.postWeapi(_searchPath, <String, dynamic>{
        's': query,
        'type': 1,
        'limit': searchPageSize,
        'offset': (page - 1) * searchPageSize,
        'total': true,
        'csrf_token': '',
      }),
    );
    final result = json['result'];
    final songs = result is Map ? result['songs'] : null;
    if (songs is! List) return const <NeteaseSongDto>[];
    return songs
        .whereType<Map>()
        .map((e) => NeteaseSongDto.fromJson(Map<String, dynamic>.from(e)))
        .where((song) => song.id > 0)
        .toList(growable: false);
  }

  Future<NeteaseSongDto?> songDetail(int songId) async {
    final json = await _rateLimiter.run(
      () => _client.postWeapi(_detailPath, <String, dynamic>{
        'c': jsonEncode(<dynamic>[
          <String, dynamic>{'id': songId},
        ]),
      }),
    );
    final songs = json['songs'];
    if (songs is! List || songs.isEmpty) return null;
    final first = songs.first;
    if (first is! Map) return null;
    return NeteaseSongDto.fromJson(Map<String, dynamic>.from(first));
  }

  Future<NeteaseUrlDto?> songUrl(int songId) async {
    final json = await _rateLimiter.run(
      () => _client.postEapi(_urlPath, <String, dynamic>{
        'ids': '[$songId]',
        'level': 'standard',
        'encodeType': 'flac',
      }),
    );
    final data = json['data'];
    if (data is! List || data.isEmpty) return null;
    final first = data.first;
    if (first is! Map) return null;
    return NeteaseUrlDto.fromJson(Map<String, dynamic>.from(first));
  }

  Future<NeteaseLyricDto> songLyric(int songId) async {
    final json = await _rateLimiter.run(
      () => _client.postWeapi(_lyricPath, <String, dynamic>{
        'id': songId,
        'lv': -1,
        'tv': -1,
        'rv': -1,
        'kv': -1,
        'csrf_token': '',
      }),
    );
    return NeteaseLyricDto.fromJson(json);
  }
}
```

- [ ] **Step 5: 运行测试确认通过**

Run: `flutter test test/netease_api_test.dart`
Expected: PASS。

- [ ] **Step 6: Commit**

```bash
git add lib/data/sources/netease/netease_models.dart lib/data/sources/netease/netease_api.dart test/netease_api_test.dart
git commit -m "feat(netease): add DTOs and typed endpoint API"
```

---

### Task 6: 映射与音源适配器

**Files:**
- Create: `lib/data/sources/netease/netease_mappers.dart`
- Create: `lib/data/sources/netease/netease_source.dart`
- Test: `test/netease_mappers_test.dart`、`test/netease_source_test.dart`

**Interfaces:**
- Consumes: `NeteaseApi`（Task 5）、`parseLrc`（Task 2）、`NeteaseTrackId`（Task 1）
- Produces:
  - `const String neteaseSourceId = 'netease';`
  - `Track neteaseSongToTrack(NeteaseSongDto song)`
  - `String? normalizeNeteaseCoverUrl(String? raw)`
  - `class NeteaseSource implements MusicSource, StreamResolver, LyricsProvider { NeteaseSource({required NeteaseApi api}); }`

- [ ] **Step 1: 写失败测试**

Create `test/netease_mappers_test.dart`：

```dart
// ...（GPL 头）...

import 'package:flutter_test/flutter_test.dart';

import 'package:flind_player/core/sources/source_track_id.dart';
import 'package:flind_player/data/sources/netease/netease_mappers.dart';
import 'package:flind_player/data/sources/netease/netease_models.dart';

void main() {
  test('maps a song DTO to a Track', () {
    final track = neteaseSongToTrack(
      const NeteaseSongDto(
        id: 123,
        name: 'Song',
        artists: <String>['A', 'B'],
        album: 'Album',
        durationMs: 215000,
        coverUrl: 'https://p1.music.126.net/a.jpg?param=300y300',
      ),
    );

    expect(track.source, 'netease');
    expect(track.uri, 'netease:123');
    expect(track.sourceTrackId, const NeteaseTrackId(songId: 123));
    expect(track.title, 'Song');
    expect(track.artist, 'A / B');
    expect(track.album, 'Album');
    expect(track.duration, const Duration(milliseconds: 215000));
    expect(track.coverUrl, 'https://p1.music.126.net/a.jpg');
  });

  test('empty artist/album/cover become null/absent', () {
    final track = neteaseSongToTrack(
      const NeteaseSongDto(id: 1, name: 'N', artists: <String>[], album: '', durationMs: 0),
    );
    expect(track.artist, isNull);
    expect(track.album, isNull);
    expect(track.duration, isNull);
    expect(track.coverUrl, isNull);
  });

  test('normalizeNeteaseCoverUrl upgrades and strips the size suffix', () {
    expect(normalizeNeteaseCoverUrl('//p1.music.126.net/a.jpg?param=1y1'), 'https://p1.music.126.net/a.jpg');
    expect(normalizeNeteaseCoverUrl('http://p1.music.126.net/a.jpg'), 'https://p1.music.126.net/a.jpg');
    expect(normalizeNeteaseCoverUrl(''), isNull);
    expect(normalizeNeteaseCoverUrl('/relative.jpg'), isNull);
  });
}
```

Create `test/netease_source_test.dart`（用 `implements NeteaseApi` 的手写 fake，保证不触网）：

```dart
// ...（GPL 头）...

import 'package:flutter_test/flutter_test.dart';

import 'package:flind_player/core/models/track.dart';
import 'package:flind_player/core/sources/music_source.dart';
import 'package:flind_player/core/sources/source_track_id.dart';
import 'package:flind_player/data/sources/netease/netease_api.dart';
import 'package:flind_player/data/sources/netease/netease_models.dart';
import 'package:flind_player/data/sources/netease/netease_source.dart';

class _FakeApi implements NeteaseApi {
  _FakeApi({this.songs = const <NeteaseSongDto>[], this.url, this.lyric});

  final List<NeteaseSongDto> songs;
  final NeteaseUrlDto? url;
  final NeteaseLyricDto? lyric;

  @override
  Future<List<NeteaseSongDto>> searchSongs(String query, {int page = 1}) async => songs;

  @override
  Future<NeteaseSongDto?> songDetail(int songId) async => songs.isEmpty ? null : songs.first;

  @override
  Future<NeteaseUrlDto?> songUrl(int songId) async => url;

  @override
  Future<NeteaseLyricDto> songLyric(int songId) async =>
      lyric ?? const NeteaseLyricDto();
}

const _song = NeteaseSongDto(id: 42, name: 'T', artists: <String>['A'], album: 'Al', durationMs: 1000);

void main() {
  test('search maps songs to tracks', () async {
    final source = NeteaseSource(api: _FakeApi(songs: const <NeteaseSongDto>[_song]));
    final tracks = await source.search('q');
    expect(tracks, hasLength(1));
    expect(tracks.single.uri, 'netease:42');
  });

  test('resolveStream returns the URL and quality', () async {
    final source = NeteaseSource(
      api: _FakeApi(
        url: const NeteaseUrlDto(url: 'https://m8.music.126.net/x.mp3', level: 'standard'),
      ),
    );
    final info = await source.resolveStream(
      const Track(
        source: 'netease',
        sourceTrackId: NeteaseTrackId(songId: 42),
        uri: 'netease:42',
        title: 'T',
      ),
    );
    expect(info.url, Uri.parse('https://m8.music.126.net/x.mp3'));
    expect(info.qualityId, 'standard');
    expect(info.headers['Referer'], 'https://music.163.com');
  });

  test('resolveStream throws when the song has no stream (VIP/region)', () async {
    final source = NeteaseSource(api: _FakeApi(url: const NeteaseUrlDto()));
    expect(
      () => source.resolveStream(
        const Track(
          source: 'netease',
          sourceTrackId: NeteaseTrackId(songId: 42),
          uri: 'netease:42',
          title: 'T',
        ),
      ),
      throwsA(isA<StateError>()),
    );
  });

  test('lyricsFor parses original and translation', () async {
    final source = NeteaseSource(
      api: _FakeApi(
        lyric: const NeteaseLyricDto(
          lrc: '[00:01.00]原文',
          translation: '[00:01.00]translated',
        ),
      ),
    );
    final lyric = await source.lyricsFor(
      const Track(
        source: 'netease',
        sourceTrackId: NeteaseTrackId(songId: 42),
        uri: 'netease:42',
        title: 'T',
      ),
    );
    expect(lyric!.lines.single.text, '原文');
    expect(lyric.lines.single.translation, 'translated');
  });

  test('lyricsFor returns null for pure music', () async {
    final source = NeteaseSource(
      api: _FakeApi(lyric: const NeteaseLyricDto(lrc: '[99:00.00]纯音乐，请欣赏')),
    );
    expect(
      await source.lyricsFor(
        const Track(
          source: 'netease',
          sourceTrackId: NeteaseTrackId(songId: 42),
          uri: 'netease:42',
          title: 'T',
        ),
      ),
      isNull,
    );
  });

  test('capabilities advertise search and streamDirect only', () {
    final source = NeteaseSource(api: _FakeApi());
    expect(source.capabilities.supports(SourceCapability.search), isTrue);
    expect(source.capabilities.supports(SourceCapability.streamDirect), isTrue);
    expect(source.capabilities.supports(SourceCapability.login), isFalse);
  });
}
```

- [ ] **Step 2: 运行确认失败**

Run: `flutter test test/netease_mappers_test.dart test/netease_source_test.dart`
Expected: FAIL（文件不存在）。

- [ ] **Step 3: 实现映射**

Create `lib/data/sources/netease/netease_mappers.dart`：

```dart
// ...（GPL 头）...

import 'package:flind_player/core/models/track.dart';
import 'package:flind_player/core/sources/source_track_id.dart';
import 'package:flind_player/data/sources/netease/netease_models.dart';

/// Source id stamped onto every NetEase [Track].
const String neteaseSourceId = 'netease';

/// Maps a song DTO to a playable [Track].
Track neteaseSongToTrack(NeteaseSongDto song) => Track(
  source: neteaseSourceId,
  sourceTrackId: NeteaseTrackId(songId: song.id),
  uri: '$neteaseSourceId:${song.id}',
  title: song.name,
  artist: song.artists.isEmpty ? null : song.artists.join(' / '),
  album: song.album.isEmpty ? null : song.album,
  duration: song.durationMs > 0
      ? Duration(milliseconds: song.durationMs)
      : null,
  coverUrl: normalizeNeteaseCoverUrl(song.coverUrl),
);

/// Upgrades protocol-relative/`http://` cover URLs and drops the `?param=`
/// size suffix so the same image hashes to one cache entry.
String? normalizeNeteaseCoverUrl(String? raw) {
  if (raw == null) return null;
  var value = raw.trim();
  if (value.isEmpty) return null;
  if (value.startsWith('//')) {
    value = 'https:$value';
  } else if (value.startsWith('http://')) {
    value = 'https://${value.substring('http://'.length)}';
  }
  if (!value.startsWith('https://')) return null;
  final query = value.indexOf('?');
  return query >= 0 ? value.substring(0, query) : value;
}
```

- [ ] **Step 4: 实现适配器**

Create `lib/data/sources/netease/netease_source.dart`：

```dart
// ...（GPL 头）...

// DESIGN REQUIREMENT: the NetEase source must remain remotely disableable. It
// is reachable only through `MusicSource`/`StreamResolver`/`LyricsProvider`
// interfaces so a feature flag can drop it without touching the rest of the app.

import 'package:flind_player/core/models/lyric.dart';
import 'package:flind_player/core/models/track.dart';
import 'package:flind_player/core/services/lrc_parser.dart';
import 'package:flind_player/core/services/lyrics_provider.dart';
import 'package:flind_player/core/sources/music_source.dart';
import 'package:flind_player/core/sources/source_track_id.dart';
import 'package:flind_player/core/sources/stream_resolver.dart';
import 'package:flind_player/data/sources/netease/netease_api.dart';
import 'package:flind_player/data/sources/netease/netease_client.dart';
import 'package:flind_player/data/sources/netease/netease_mappers.dart';

/// NetEase Cloud Music as a [MusicSource], [StreamResolver] and [LyricsProvider].
class NeteaseSource implements MusicSource, StreamResolver, LyricsProvider {
  final NeteaseApi _api;

  NeteaseSource({required NeteaseApi api}) : _api = api;

  @override
  String get id => neteaseSourceId;

  @override
  SourceCapabilities get capabilities => const SourceCapabilities(
    <SourceCapability>{SourceCapability.search, SourceCapability.streamDirect},
  );

  @override
  Future<List<Track>> search(String query, {int page = 1}) async {
    final songs = await _api.searchSongs(query, page: page);
    return songs.map(neteaseSongToTrack).toList(growable: false);
  }

  @override
  Future<Track> fetchTrack(SourceTrackId id) async {
    if (id is! NeteaseTrackId) {
      throw ArgumentError.value(id, 'id', 'NeteaseSource only accepts NeteaseTrackId');
    }
    final song = await _api.songDetail(id.songId);
    if (song == null) {
      throw StateError('No NetEase song ${id.songId}');
    }
    return neteaseSongToTrack(song);
  }

  /// Alias so [NeteaseSource] can be registered in a `StreamResolver` map.
  @override
  Future<StreamInfo> resolve(Track track) => resolveStream(track);

  @override
  Future<StreamInfo> resolveStream(Track track) async {
    final id = track.sourceTrackId;
    if (id is! NeteaseTrackId) {
      throw UnsupportedError(
        'NeteaseSource cannot resolve a ${track.sourceTrackId.runtimeType} track',
      );
    }
    final dto = await _api.songUrl(id.songId);
    final url = dto?.url;
    if (url == null || url.isEmpty) {
      throw StateError('No stream available for ${track.uri}');
    }
    return StreamInfo(
      url: Uri.parse(url),
      headers: const <String, String>{
        'Referer': kNeteaseReferer,
      },
      qualityId: dto?.level ?? 'standard',
    );
  }

  @override
  Future<Lyric?> lyricsFor(Track track) async {
    final id = track.sourceTrackId;
    if (id is! NeteaseTrackId) return null;
    final dto = await _api.songLyric(id.songId);
    return parseLrc(dto.lrc, translation: dto.translation);
  }
}
```

> 注意：`StreamInfo.headers` 未带 `User-Agent`——播放器的 HTTP 栈会带默认 UA；如需与 Bilibili 一致可加 `'User-Agent': kDesktopUserAgent`，但会引入对 `bili_client.dart` 的依赖，MVP 保持最小。

- [ ] **Step 5: 运行测试确认通过**

Run: `flutter test test/netease_mappers_test.dart test/netease_source_test.dart`
Expected: PASS。

- [ ] **Step 6: Commit**

```bash
git add lib/data/sources/netease/netease_mappers.dart lib/data/sources/netease/netease_source.dart \
  test/netease_mappers_test.dart test/netease_source_test.dart
git commit -m "feat(netease): add mappers and NeteaseSource adapter"
```

---

### Task 7: 注册表、provider 装配、限流泛化、错误映射

**Files:**
- Create: `lib/core/sources/online_source.dart`
- Create: `lib/data/providers/netease_providers.dart`
- Create: `lib/data/providers/online_source_providers.dart`
- Create: `lib/data/providers/lyrics_providers.dart`
- Modify: `lib/data/sources/bilibili/rate_limiter.dart`
- Modify: `lib/data/providers/cache_providers.dart:66-72`
- Modify: `lib/shared/error_messages.dart`
- Modify: `lib/l10n/app_en.arb`、`lib/l10n/app_zh.arb`（+ 重新生成）
- Test: `test/rate_limiter_test.dart`（补用例）、`test/online_search_provider_test.dart`（新建）、`test/lyrics_providers_test.dart`（新建）、`test/error_messages_test.dart`（补用例）

**Interfaces:**
- Consumes: `BiliSource`、`NeteaseSource`、`LyricsProvider`、`RateLimiter`
- Produces:
  - `class SourceDescriptor { final String id; final MusicSource source; const SourceDescriptor({required String id, required MusicSource source}); }`
  - `disabledSourceIdsProvider`, `onlineSourcesProvider`, `onlineSearchProvider`
  - `neteaseClientProvider`, `neteaseRateLimiterProvider`, `neteaseApiProvider`, `neteaseSourceProvider`
  - `sourceSupportsLyricsProvider`, `trackLyricsProvider`
  - `RateLimiter({..., bool Function(Object)? isRetryable})`

- [ ] **Step 1: 泛化 `RateLimiter`（先写失败测试）**

在 `test/rate_limiter_test.dart` 末尾 `main()` 内加 group：

```dart
  group('RateLimiter custom retry predicate', () {
    test('retries when the injected predicate matches', () async {
      final delays = <Duration>[];
      final limiter = RateLimiter(
        minInterval: Duration.zero,
        maxInterval: Duration.zero,
        isRetryable: (error) => error is StateError,
        sleeper: (d) async => delays.add(d),
      );

      var calls = 0;
      final result = await limiter.run(() async {
        calls++;
        if (calls < 2) throw StateError('transient');
        return 'ok';
      });

      expect(result, 'ok');
      expect(calls, 2);
      expect(delays, <Duration>[const Duration(seconds: 2)]);
    });

    test('default behavior still retries bilibili codes', () async {
      final delays = <Duration>[];
      final limiter = RateLimiter(
        minInterval: Duration.zero,
        maxInterval: Duration.zero,
        sleeper: (d) async => delays.add(d),
      );

      var calls = 0;
      await limiter.run(() async {
        calls++;
        if (calls < 2) throw const BiliApiException(-509, 'rate');
        return 'ok';
      });

      expect(calls, 2);
      expect(delays, <Duration>[const Duration(seconds: 2)]);
    });
  });
```

Run: `flutter test test/rate_limiter_test.dart`
Expected: FAIL（`isRetryable` 参数不存在）。

- [ ] **Step 2: 实现泛化**

`lib/data/sources/bilibili/rate_limiter.dart`：构造函数加 `bool Function(Object error)? isRetryable`，存字段；`_execute` 的 catch 改为通用：

```dart
  final bool Function(Object error)? _customIsRetryable;

  RateLimiter({
    this.minInterval = const Duration(seconds: 1),
    this.maxInterval = const Duration(seconds: 3),
    this.backoffBase = const Duration(seconds: 2),
    this.maxBackoff = const Duration(seconds: 8),
    this.maxRetries = 3,
    this.retryableCodes = defaultRetryableCodes,
    Sleeper? sleeper,
    Random? random,
    bool Function(Object error)? isRetryable,
  }) : _sleep = sleeper ?? Future<void>.delayed,
       _random = random ?? Random(),
       _customIsRetryable = isRetryable;
```

`_execute` 的 catch：

```dart
      try {
        return await action();
      } catch (error) {
        if (!_isRetryable(error) || attempt >= maxRetries) {
          rethrow;
        }
        await _sleep(_backoffFor(attempt));
        attempt++;
      }
```

新增：

```dart
  bool _isRetryable(Object error) {
    final custom = _customIsRetryable;
    if (custom != null) return custom(error);
    return error is BiliApiException && retryableCodes.contains(error.code);
  }
```

Run: `flutter test test/rate_limiter_test.dart`
Expected: PASS（旧用例与新增用例全绿）。

- [ ] **Step 3: 注册表与 provider**

Create `lib/core/sources/online_source.dart`：

```dart
// ...（GPL 头）...

import 'package:flind_player/core/sources/music_source.dart';

/// A registered online source: its stable [id] and the adapter itself.
class SourceDescriptor {
  final String id;
  final MusicSource source;

  const SourceDescriptor({required this.id, required this.source});
}
```

Create `lib/data/providers/netease_providers.dart`：

```dart
// ...（GPL 头）...

import 'dart:async';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:flind_player/data/sources/bilibili/rate_limiter.dart';
import 'package:flind_player/data/sources/netease/netease_api.dart';
import 'package:flind_player/data/sources/netease/netease_client.dart';
import 'package:flind_player/data/sources/netease/netease_source.dart';

/// Shared, configured Dio wrapper for `music.163.com`.
final neteaseClientProvider = Provider<NeteaseClient>((ref) => NeteaseClient());

/// Pacers NetEase requests (search, stream URL, lyrics).
///
/// NetEase is less hostile than Bilibili: a short jittered interval and retries
/// on transient failures; a login-required response is surfaced immediately.
final neteaseRateLimiterProvider = Provider<RateLimiter>((ref) {
  return RateLimiter(
    minInterval: const Duration(milliseconds: 300),
    maxInterval: const Duration(seconds: 1),
    isRetryable: (error) =>
        error is NeteaseApiException && error.code != -462 ||
        error is SocketException ||
        error is TimeoutException ||
        error is DioException,
  );
});

/// Typed NetEase endpoint client.
final neteaseApiProvider = Provider<NeteaseApi>(
  (ref) => NeteaseApi(
    client: ref.watch(neteaseClientProvider),
    rateLimiter: ref.watch(neteaseRateLimiterProvider),
  ),
);

/// NetEase as a searchable, streamable, lyrics-capable source.
final neteaseSourceProvider = Provider<NeteaseSource>(
  (ref) => NeteaseSource(api: ref.watch(neteaseApiProvider)),
);
```

Create `lib/data/providers/online_source_providers.dart`：

```dart
// ...（GPL 头）...

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:flind_player/core/models/track.dart';
import 'package:flind_player/core/sources/online_source.dart';
import 'package:flind_player/data/providers/bilibili_providers.dart';
import 'package:flind_player/data/providers/netease_providers.dart';

/// Source ids disabled at runtime (remote kill-switch hook).
///
/// MVP returns an empty set; a remote config could override it later.
final disabledSourceIdsProvider = Provider<Set<String>>(
  (ref) => const <String>{},
);

/// Ordered registry of enabled online sources.
final onlineSourcesProvider = Provider<List<SourceDescriptor>>((ref) {
  final disabled = ref.watch(disabledSourceIdsProvider);
  final bili = ref.watch(biliSourceProvider);
  final netease = ref.watch(neteaseSourceProvider);
  return <SourceDescriptor>[
    SourceDescriptor(id: bili.id, source: bili),
    SourceDescriptor(id: netease.id, source: netease),
  ].where((descriptor) => !disabled.contains(descriptor.id)).toList(growable: false);
});

/// Search results for one `(sourceId, query)` pair.
final onlineSearchProvider =
    FutureProvider.family<List<Track>, (String, String)>((ref, key) async {
  final query = key.$2.trim();
  if (query.isEmpty) return const <Track>[];
  SourceDescriptor? descriptor;
  for (final candidate in ref.watch(onlineSourcesProvider)) {
    if (candidate.id == key.$1) {
      descriptor = candidate;
      break;
    }
  }
  if (descriptor == null) return const <Track>[];
  return descriptor.source.search(query);
}, retry: (_, _) => null);
```

Create `lib/data/providers/lyrics_providers.dart`：

```dart
// ...（GPL 头）...

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:flind_player/core/models/lyric.dart';
import 'package:flind_player/core/models/track.dart';
import 'package:flind_player/core/services/lyrics_provider.dart';
import 'package:flind_player/data/providers/online_source_providers.dart';

/// Whether the source registered for [sourceId] can supply lyrics.
///
/// The lyrics UI uses this to choose between "this source has no lyrics
/// adapted" and "this track has no lyrics".
final sourceSupportsLyricsProvider = Provider.family<bool, String>((
  ref,
  sourceId,
) {
  for (final descriptor in ref.watch(onlineSourcesProvider)) {
    if (descriptor.id == sourceId) return descriptor.source is LyricsProvider;
  }
  return false;
});

/// Lyrics for one track, routed to the registered source matching
/// `track.source`. Missing lyrics (unsupported source, no lyric, or a network
/// failure) resolve to `null` so the UI shows its placeholder.
final trackLyricsProvider = FutureProvider.family<Lyric?, Track>((
  ref,
  track,
) async {
  LyricsProvider? provider;
  for (final descriptor in ref.watch(onlineSourcesProvider)) {
    if (descriptor.id == track.source && descriptor.source is LyricsProvider) {
      provider = descriptor.source as LyricsProvider;
      break;
    }
  }
  if (provider == null) return null;
  try {
    return await provider.lyricsFor(track);
  } catch (_) {
    return null;
  }
}, retry: (_, _) => null);
```

- [ ] **Step 4: 重新装配 resolver**

`lib/data/providers/cache_providers.dart` 第 66–72 行改为：

```dart
final innerStreamResolverProvider = Provider<StreamResolver>((ref) {
  final sources = <String, StreamResolver>{};
  for (final descriptor in ref.watch(onlineSourcesProvider)) {
    if (descriptor.source is StreamResolver) {
      sources[descriptor.id] = descriptor.source as StreamResolver;
    }
  }
  return CompositeStreamResolver(
    localResolver: const LocalStreamResolver(),
    sources: sources,
  );
});
```

把 `import 'package:flind_player/data/providers/bilibili_providers.dart';` 换成
`import 'package:flind_player/data/providers/online_source_providers.dart';`（若无其他引用）。

- [ ] **Step 5: 错误映射 + l10n**

`lib/shared/error_messages.dart` 在 `BiliApiException` 分支后加：

```dart
  if (error is NeteaseApiException) {
    return error.code == -462
        ? l10n.errLoginRequired
        : l10n.errNeteaseApi(error.code);
  }
```

加 import：`import 'package:flind_player/data/sources/netease/netease_client.dart';`

`lib/l10n/app_zh.arb` 加：

```json
  "sourceNetease": "网易云",
  "errNeteaseApi": "网易云接口错误（代码 {code}）",
  "@errNeteaseApi": {
    "placeholders": {
      "code": { "type": "int" }
    }
  },
  "searchSourcesTitle": "搜索在线音乐",
  "searchSourcesHint": "选择音源，输入关键词后回车即可搜索并播放",
  "lyricsNotFound": "暂无歌词",
```

`lib/l10n/app_en.arb` 加：

```json
  "sourceNetease": "NetEase Cloud Music",
  "errNeteaseApi": "NetEase API error (code {code})",
  "@errNeteaseApi": {
    "placeholders": {
      "code": { "type": "int" }
    }
  },
  "searchSourcesTitle": "Search online music",
  "searchSourcesHint": "Pick a source, type a keyword and press Enter to search and play",
  "lyricsNotFound": "No lyrics",
```

Run: `flutter gen-l10n`
Run: `flutter analyze`
Expected: 生成 `app_localizations*.dart` 且无 error。

- [ ] **Step 6: 写 provider 测试**

Create `test/online_search_provider_test.dart`：

```dart
// ...（GPL 头）...

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:flind_player/core/models/track.dart';
import 'package:flind_player/core/sources/music_source.dart';
import 'package:flind_player/core/sources/online_source.dart';
import 'package:flind_player/core/sources/source_track_id.dart';
import 'package:flind_player/data/providers/online_source_providers.dart';

class _FakeSource implements MusicSource {
  _FakeSource(this.id, this.results);

  @override
  final String id;
  final List<Track> results;
  final List<String> queries = <String>[];

  @override
  SourceCapabilities get capabilities => const SourceCapabilities(<SourceCapability>{SourceCapability.search});

  @override
  Future<List<Track>> search(String query, {int page = 1}) async {
    queries.add(query);
    return results;
  }

  @override
  Future<Track> fetchTrack(SourceTrackId id) => throw UnimplementedError();

  @override
  Future<StreamInfo> resolveStream(Track track) => throw UnimplementedError();
}

void main() {
  test('routes to the requested source and skips blank queries', () async {
    final bili = _FakeSource('bilibili', const <Track>[]);
    final netease = _FakeSource('netease', const <Track>[
      Track(
        source: 'netease',
        sourceTrackId: NeteaseTrackId(songId: 1),
        uri: 'netease:1',
        title: 'N',
      ),
    ]);
    final container = ProviderContainer(
      overrides: [
        onlineSourcesProvider.overrideWithValue(<SourceDescriptor>[
          SourceDescriptor(id: 'bilibili', source: bili),
          SourceDescriptor(id: 'netease', source: netease),
        ]),
      ],
    );
    addTearDown(container.dispose);

    final results = await container.read(onlineSearchProvider(('netease', '  ')).future);
    expect(results, isEmpty);
    expect(netease.queries, isEmpty);
    expect(bili.queries, isEmpty);

    final routed = await container.read(onlineSearchProvider(('netease', 'q')).future);
    expect(routed.single.uri, 'netease:1');
    expect(netease.queries, <String>['q']);
    expect(bili.queries, isEmpty);
  });

  test('excludes disabled sources from the registry', () {
    final container = ProviderContainer(
      overrides: [
        disabledSourceIdsProvider.overrideWithValue(const <String>{'bilibili'}),
        onlineSourcesProvider.overrideWithValue(<SourceDescriptor>[
          SourceDescriptor(id: 'netease', source: _FakeSource('netease', const <Track>[])),
        ]),
      ],
    );
    addTearDown(container.dispose);
    expect(
      container.read(onlineSourcesProvider).map((d) => d.id),
      <String>['netease'],
    );
  });
}
```

Create `test/lyrics_providers_test.dart`：

```dart
// ...（GPL 头）...

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:flind_player/core/models/lyric.dart';
import 'package:flind_player/core/models/track.dart';
import 'package:flind_player/core/services/lyrics_provider.dart';
import 'package:flind_player/core/sources/music_source.dart';
import 'package:flind_player/core/sources/online_source.dart';
import 'package:flind_player/core/sources/source_track_id.dart';
import 'package:flind_player/data/providers/lyrics_providers.dart';
import 'package:flind_player/data/providers/online_source_providers.dart';

class _LyricsSource implements MusicSource, LyricsProvider {
  _LyricsSource(this.id, this.result);

  @override
  final String id;
  final Lyric? result;

  @override
  SourceCapabilities get capabilities => const SourceCapabilities(<SourceCapability>{SourceCapability.search});

  @override
  Future<List<Track>> search(String query, {int page = 1}) async => const <Track>[];

  @override
  Future<Track> fetchTrack(SourceTrackId id) => throw UnimplementedError();

  @override
  Future<StreamInfo> resolveStream(Track track) => throw UnimplementedError();

  @override
  Future<Lyric?> lyricsFor(Track track) async => result;
}

class _PlainSource implements MusicSource {
  _PlainSource(this.id);
  @override
  final String id;
  @override
  SourceCapabilities get capabilities => const SourceCapabilities(<SourceCapability>{SourceCapability.search});
  @override
  Future<List<Track>> search(String query, {int page = 1}) async => const <Track>[];
  @override
  Future<Track> fetchTrack(SourceTrackId id) => throw UnimplementedError();
  @override
  Future<StreamInfo> resolveStream(Track track) => throw UnimplementedError();
}

const _track = Track(
  source: 'netease',
  sourceTrackId: NeteaseTrackId(songId: 1),
  uri: 'netease:1',
  title: 'T',
);

void main() {
  test('returns lyrics from the LyricsProvider source', () async {
    const lyric = Lyric(<LyricLine>[LyricLine(timestamp: Duration.zero, text: 'a')]);
    final container = ProviderContainer(
      overrides: [
        onlineSourcesProvider.overrideWithValue(<SourceDescriptor>[
          SourceDescriptor(id: 'bilibili', source: _PlainSource('bilibili')),
          SourceDescriptor(id: 'netease', source: _LyricsSource('netease', lyric)),
        ]),
      ],
    );
    addTearDown(container.dispose);

    expect(await container.read(trackLyricsProvider(_track).future), lyric);
  });

  test('resolves to null when no source provides lyrics', () async {
    final container = ProviderContainer(
      overrides: [
        onlineSourcesProvider.overrideWithValue(<SourceDescriptor>[
          SourceDescriptor(id: 'bilibili', source: _PlainSource('bilibili')),
        ]),
      ],
    );
    addTearDown(container.dispose);

    expect(await container.read(trackLyricsProvider(_track).future), isNull);
  });
}
```

- [ ] **Step 7: 运行测试**

Run: `flutter test test/rate_limiter_test.dart test/online_search_provider_test.dart test/lyrics_providers_test.dart test/error_messages_test.dart`
Expected: PASS。

- [ ] **Step 8: Commit**

```bash
git add lib/core/sources/online_source.dart lib/data/providers/netease_providers.dart \
  lib/data/providers/online_source_providers.dart lib/data/providers/lyrics_providers.dart \
  lib/data/sources/bilibili/rate_limiter.dart lib/data/providers/cache_providers.dart \
  lib/shared/error_messages.dart lib/l10n/ test/rate_limiter_test.dart \
  test/online_search_provider_test.dart test/lyrics_providers_test.dart
git commit -m "feat(netease): registry, providers, lyrics routing and generalized rate limiter"
```

---

### Task 8: 搜索界面多源切换

**Files:**
- Delete: `lib/features/search/search_providers.dart`
- Modify: `lib/features/search/search_screen.dart`
- Create: `test/support/fake_music_source.dart`
- Modify: `test/search_screen_test.dart`、`test/home_shell_test.dart:244`、`test/responsive_layout_test.dart:372`

**Interfaces:**
- Consumes: `onlineSourcesProvider`、`onlineSearchProvider`、`SourceDescriptor`（Task 7）
- Produces: `SearchScreen` 内 `SegmentedButton<String>`；测试助手 `FakeMusicSource`

- [ ] **Step 1: 建测试助手**

Create `test/support/fake_music_source.dart`：

```dart
// ...（GPL 头）...

import 'package:flutter_test/flutter_test.dart';

import 'package:flind_player/core/models/track.dart';
import 'package:flind_player/core/sources/music_source.dart';
import 'package:flind_player/core/sources/online_source.dart';
import 'package:flind_player/core/sources/source_track_id.dart';

/// A [MusicSource] stub for widget tests; search is configurable, the rest
/// throws if reached.
class FakeMusicSource implements MusicSource {
  FakeMusicSource(this.id, {this.results = const <Track>[]});

  @override
  final String id;
  final List<Track> results;

  @override
  SourceCapabilities get capabilities =>
      const SourceCapabilities(<SourceCapability>{SourceCapability.search});

  @override
  Future<List<Track>> search(String query, {int page = 1}) async => results;

  @override
  Future<Track> fetchTrack(SourceTrackId id) => throw UnimplementedError();

  @override
  Future<StreamInfo> resolveStream(Track track) => throw UnimplementedError();
}

/// The two-source registry used by search widget tests.
List<SourceDescriptor> fakeSourceRegistry() => <SourceDescriptor>[
  SourceDescriptor(id: 'bilibili', source: FakeMusicSource('bilibili')),
  SourceDescriptor(id: 'netease', source: FakeMusicSource('netease')),
];
```

- [ ] **Step 2: 改 SearchScreen（先让测试红）**

`test/search_screen_test.dart`：删除 `import 'package:flind_player/features/search/search_providers.dart';` 与 `import 'package:flind_player/data/sources/bilibili/bili_client.dart';`，改 import：

```dart
import 'package:flind_player/data/providers/online_source_providers.dart';
import 'package:flind_player/data/sources/netease/netease_client.dart';
import 'support/fake_music_source.dart';
```

把 `_app` 的 override 从 `biliSearchResultsProvider.overrideWith(search)` 改为：

```dart
      onlineSourcesProvider.overrideWithValue(fakeSourceRegistry()),
      onlineSearchProvider.overrideWith(
        (ref, key) async => await search(ref, key.$2),
      ),
```

把 `_app` 的 `search` 形参改为 `(Ref ref, String query)` 保持不变（`search: (ref, query) async => ...` 无需改）。

把错误用例的 `BiliApiException` 换成 `NeteaseApiException`，并改期望文案：

```dart
  testWidgets('shows a login hint for a NetEase -462 error', (tester) async {
    await tester.pumpWidget(
      _app(
        search: (ref, query) =>
            Future<List<Track>>.error(const NeteaseApiException(-462, 'x')),
      ),
    );
    await _submitQuery(tester, '周杰伦');
    expect(find.text('请先登录'), findsOneWidget);
  });
```

把首屏文案断言 `expect(find.text('搜索 Bilibili 上的音乐'), findsOneWidget);` 改为 `expect(find.text('搜索在线音乐'), findsOneWidget);`，并新增切源用例：

```dart
  testWidgets('switches source and shows that source results', (tester) async {
    await tester.pumpWidget(
      _app(search: (ref, query) async => <Track>[_track('Only $query')]),
    );
    await _submitQuery(tester, 'A');
    expect(find.text('Only A'), findsOneWidget);

    await tester.tap(find.text('网易云'));
    await tester.pumpAndSettle();
    expect(find.text('Only A'), findsOneWidget, reason: 'cached per (source, query)');
  });
```

Run: `flutter test test/search_screen_test.dart`
Expected: FAIL（`onlineSearchProvider` / `SourceDescriptor` 尚未被界面使用或文案未改）。

- [ ] **Step 3: 实现 SearchScreen**

删除 `lib/features/search/search_providers.dart`（`rm`）。

`lib/features/search/search_screen.dart` 改为：
- import 调整为 `online_source_providers.dart`，删除 `search_providers.dart` import。
- `_SearchScreenState` 增 `String? _selectedSourceId;`。
- `build` 顶部取 `final sources = ref.watch(onlineSourcesProvider);`，计算：

```dart
    final sources = ref.watch(onlineSourcesProvider);
    final selectedId = sources.any((d) => d.id == _selectedSourceId)
        ? _selectedSourceId!
        : (sources.isEmpty ? '' : sources.first.id);
```

- 在搜索框 `Padding` 之后、`Expanded` 之前插入分段控件：

```dart
              if (sources.length > 1)
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                  child: SegmentedButton<String>(
                    showSelectedIcon: false,
                    segments: <ButtonSegment<String>>[
                      for (final descriptor in sources)
                        ButtonSegment<String>(
                          value: descriptor.id,
                          label: Text(_sourceLabel(l10n, descriptor.id)),
                        ),
                    ],
                    selected: <String>{selectedId},
                    onSelectionChanged: (selection) {
                      setState(() => _selectedSourceId = selection.first);
                    },
                  ),
                ),
              Expanded(child: _buildBody(selectedId)),
```

- `_buildBody` 改签名与 watch：

```dart
  Widget _buildBody(String sourceId) {
    if (_submittedQuery.isEmpty) return const _SearchHint();
    final resultsAsync =
        ref.watch(onlineSearchProvider((sourceId, _submittedQuery)));
    ...
      error: (error, stackTrace) => _SearchError(
        error: error,
        onRetry: () => ref.invalidate(
          onlineSearchProvider((sourceId, _submittedQuery)),
        ),
      ),
    ...
  }
```

- 文件底部加：

```dart
String _sourceLabel(AppLocalizations l10n, String id) => switch (id) {
  'bilibili' => l10n.sourceBilibili,
  'netease' => l10n.sourceNetease,
  _ => id,
};
```

- `_SearchHint` 的 `l10n.searchBiliTitle` → `l10n.searchSourcesTitle`，`l10n.searchBiliHint` → `l10n.searchSourcesHint`。

- [ ] **Step 4: 改其余两个测试`

`test/home_shell_test.dart`：删除 `biliSearchResultsProvider` import（如有），在 overrides 中把
`biliSearchResultsProvider.overrideWith((ref, query) async => <Track>[]),`
换成：

```dart
      onlineSourcesProvider.overrideWithValue(fakeSourceRegistry()),
      onlineSearchProvider.overrideWith((ref, key) async => <Track>[]),
```

并加 `import 'package:flind_player/data/providers/online_source_providers.dart';` 与 `import 'support/fake_music_source.dart';`。

`test/responsive_layout_test.dart`：同样把
`biliSearchResultsProvider.overrideWith((ref, query) async => tracks),`
换成：

```dart
      onlineSourcesProvider.overrideWithValue(fakeSourceRegistry()),
      onlineSearchProvider.overrideWith((ref, key) async => tracks),
```

并调整 import。

- [ ] **Step 5: 运行测试**

Run: `flutter test test/search_screen_test.dart test/home_shell_test.dart test/responsive_layout_test.dart`
Expected: PASS。

- [ ] **Step 6: Commit**

```bash
git add lib/features/search/ test/support/fake_music_source.dart test/search_screen_test.dart test/home_shell_test.dart test/responsive_layout_test.dart
git commit -m "feat(search): multi-source switch backed by the online source registry"
```

---

### Task 9: 歌词界面（同步滚动 + 高亮 + 双语）

**Files:**
- Modify: `lib/features/player/lyrics_view.dart`
- Modify: `test/mini_settings_test.dart`（如用到曲目，补 provider override）
- Create: `test/lyrics_view_test.dart`

**Interfaces:**
- Consumes: `trackLyricsProvider`（Task 7）、`playbackStateProvider`、`Lyric`/`LyricLine`（Task 2）
- Produces: 有歌词的 `LyricsView` / `LyricsPreview`；当前行 key `lyric-current`

- [ ] **Step 1: 写失败测试**

Create `test/lyrics_view_test.dart`：

```dart
// ...（GPL 头）...

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:flind_player/core/models/lyric.dart';
import 'package:flind_player/core/models/playback_state.dart';
import 'package:flind_player/core/models/track.dart';
import 'package:flind_player/core/sources/source_track_id.dart';
import 'package:flind_player/data/providers/lyrics_providers.dart';
import 'package:flind_player/data/providers/playback_providers.dart';
import 'package:flind_player/features/player/lyrics_view.dart';

import 'support/l10n.dart';

const _track = Track(
  source: 'netease',
  sourceTrackId: NeteaseTrackId(songId: 1),
  uri: 'netease:1',
  title: 'T',
);

const _lyric = Lyric(<LyricLine>[
  LyricLine(timestamp: Duration(seconds: 1), text: 'First', translation: '第一'),
  LyricLine(timestamp: Duration(seconds: 5), text: 'Second'),
]);

Widget _app({required Lyric? lyric, Duration position = const Duration(seconds: 2)}) {
  return ProviderScope(
    overrides: [
      trackLyricsProvider.overrideWith((ref, track) async => lyric),
      playbackStateProvider.overrideWith(
        (ref) => Stream.value(
          const PlaybackState(
            isPlaying: true,
            isBuffering: false,
            isCompleted: false,
            position: Duration(seconds: 2),
            currentTrack: _track,
          ).copyWith(position: position),
        ),
      ),
    ],
    child: localizedApp(const Scaffold(body: LyricsView())),
  );
}

void main() {
  testWidgets('highlight the current line and render its translation', (tester) async {
    await tester.pumpWidget(_app(lyric: _lyric, position: const Duration(seconds: 2)));
    await tester.pumpAndSettle();

    expect(find.text('First'), findsOneWidget);
    expect(find.text('第一'), findsOneWidget);
    final current = tester.widget<Container>(
      find.byKey(const ValueKey<String>('lyric-current')),
    );
    expect(current, isNotNull);
    expect(find.text('First'), findsOneWidget);
  });

  testWidgets('advances the highlight with the position', (tester) async {
    await tester.pumpWidget(_app(lyric: _lyric, position: const Duration(seconds: 6)));
    await tester.pumpAndSettle();
    expect(find.text('Second'), findsOneWidget);
  });

  testWidgets('shows the no-lyrics placeholder when the lyric is null', (tester) async {
    await tester.pumpWidget(_app(lyric: null));
    await tester.pumpAndSettle();
    expect(find.text('暂无歌词'), findsOneWidget);
  });
}
```

Run: `flutter test test/lyrics_view_test.dart`
Expected: FAIL（UI 仍为占位）。

- [ ] **Step 2: 实现 `LyricsView` / `LyricsPreview`**

重写 `lib/features/player/lyrics_view.dart`：`LyricsView` 改为 `ConsumerStatefulWidget`，`LyricsPreview` 改为 `ConsumerWidget`。核心：

```dart
class LyricsView extends ConsumerStatefulWidget {
  const LyricsView({super.key, this.onTap});
  final VoidCallback? onTap;
  @override
  ConsumerState<LyricsView> createState() => _LyricsViewState();
}

class _LyricsViewState extends ConsumerState<LyricsView> {
  static const double _lineExtent = 56;

  final ScrollController _controller = ScrollController();
  int? _lastIndex;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _scheduleScroll(int index) {
    if (_lastIndex == index) return;
    _lastIndex = index;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_controller.hasClients) return;
      final target = (index * _lineExtent) -
          (_controller.position.viewportDimension / 2) +
          (_lineExtent / 2);
      _controller.animateTo(
        target.clamp(0.0, _controller.position.maxScrollExtent),
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOut,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);
    final track = ref.watch(playbackStateProvider).value?.currentTrack;
    final position = ref.watch(playbackStateProvider).value?.position ?? Duration.zero;
    final lyric = track == null
        ? null
        : ref.watch(trackLyricsProvider(track)).value;

    if (track == null || lyric == null || lyric.lines.isEmpty) {
      return _LyricsPlaceholder(l10n: l10n, onTap: widget.onTap);
    }

    final currentIndex = lyric.indexAt(position) ?? 0;
    _scheduleScroll(currentIndex);

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: widget.onTap,
      child: ListView.builder(
        controller: _controller,
        itemCount: lyric.lines.length,
        itemBuilder: (context, index) {
          final line = lyric.lines[index];
          final isCurrent = index == currentIndex;
          return Container(
            key: isCurrent ? const ValueKey<String>('lyric-current') : null,
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  line.text,
                  style: theme.textTheme.titleMedium?.copyWith(
                    color: isCurrent
                        ? theme.colorScheme.primary
                        : theme.colorScheme.onSurfaceVariant,
                    fontWeight: isCurrent ? FontWeight.w600 : FontWeight.w400,
                  ),
                ),
                if (line.translation != null)
                  Text(
                    line.translation!,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
              ],
            ),
          );
        },
      ),
    );
  }
}
```

`LyricsPreview` 同理但只渲染当前行（`lyric.lines[lyric.indexAt(position) ?? 0]`），无歌词时保留原占位。

`_LyricsPlaceholder` 抽出原占位实现（图标 + `l10n.lyricsUnavailable`）；文案第二行：`track == null || !ref.watch(sourceSupportsLyricsProvider(track.source))` 时用 `l10n.lyricsPlaceholderHint`，否则用 `l10n.lyricsNotFound`（watch 需要 `track != null` 守卫）。

- [ ] **Step 3: 兼容既有播放页测试**

`test/mini_settings_test.dart` 的当前曲目是 `local` 源：`trackLyricsProvider` 在注册表中找不到 `local` 描述符（注册表只有 `bilibili`/`netease`），直接返回 `null`，**不触网**，因此无需新增 override。`player_transport_test` 的 `bilibili` 曲目同理（`BiliSource` 非 `LyricsProvider`）。若某个既有用例确实构造了 `netease` 曲目，再补 `trackLyricsProvider.overrideWith((ref, track) async => null)`。

Run: `flutter test test/lyrics_view_test.dart test/mini_settings_test.dart test/player_transport_test.dart`
Expected: PASS。

- [ ] **Step 4: Commit**

```bash
git add lib/features/player/lyrics_view.dart test/lyrics_view_test.dart test/mini_settings_test.dart
git commit -m "feat(lyrics): synced, highlighted, bilingual lyrics view"
```

---

### Task 10: 文档与全量回归

**Files:**
- Create: `docs/netease-source.md`
- Modify: `docs/architecture.md`（§5 目录树、§6.1、§7 说明）
- Modify: `docs/spec-netease-source-2026-10-01.md`（状态改为「已实现」）

- [ ] **Step 1: 写 `docs/netease-source.md`**

结构对齐 `docs/bilibili-source.md`，至少含：
- §1 目标与范围（匿名搜索/播放/歌词；非目标：登录/歌单/无损/逐字）。
- §2 端点清单（搜索 `weapi/cloudsearch/get/web`、详情 `weapi/v3/song/detail`、流 `eapi/song/enhance/player/url/v1`、歌词 `weapi/song/lyric`），标注匿名。
- §3 `weapi` / `eapi` 协议与固定常量（presetKey、iv、eapiKey、RSA modulus/e），说明 RSA 用 `BigInt.modPow`。
- §4 请求头与匿名 Cookie（`os=pc`、禁 `Origin`）。
- §5 能力边界（匿名 128k；`url=null` = 不可播放；纯音乐无歌词）。
- §6 法务与稳定性姿态（个人使用、不内置凭证、可远程禁用、协议易变）。

- [ ] **Step 2: 更新架构文档**

`docs/architecture.md` §5 目录树在 `sources/bilibili/` 下补 `netease/`；§6.1 的 `SourceTrackId` 片段补 `NeteaseTrackId` 与 `netease` source id；第 12 行「Bilibili 作为主要在线音源」补一句「另支持网易云（匿名）」。视需要更新 `docs/widget-tree.md` 中搜索/歌词条目。

- [ ] **Step 3: 标记 spec 状态**

`docs/spec-netease-source-2026-10-01.md` 头部 `- 状态：**待实现**` → `- 状态：**已实现**（2026-10-01）`。

- [ ] **Step 4: 全量回归**

Run: `flutter analyze`
Expected: 0 error（允许既有 warning，不得新增）。

Run: `flutter test`
Expected: 全绿。

- [ ] **Step 5: Commit**

```bash
git add docs/netease-source.md docs/architecture.md docs/spec-netease-source-2026-10-01.md
git commit -m "docs(netease): adapter design, architecture sync and spec status"
```

---

## Self-Review

**Spec coverage:**
- §5 加密 → Task 3；§6 端点/客户端 → Task 4/5；§7 模块 → Task 1–9；§8 身份/编解码/缓存键 → Task 1；§9 适配器 → Task 6；§10 注册表/搜索 → Task 7/8；§11 歌词 → Task 2/6/7/9；§12 错误/限流/禁用/法务 → Task 7/10；§13 测试 → 各任务；§14 风险 → 由测试与降级覆盖；§16 执行顺序 → 任务顺序一致。

**Placeholder scan:** 无 TBD/TODO；每个代码步骤含可运行代码。`docs/netease-source.md` 以「至少含」列出必含小节（内容为文档，非可执行步骤）。

**Type consistency:** `NeteaseTrackId(songId:)`、`parseLrc(String?, {translation})`、`Lyric.indexAt`、`LyricsProvider.lyricsFor`、`NeteaseCrypto.weapi/eapi/eapiDecrypt`、`NeteaseClient.postWeapi/postEapi`、`NeteaseApi.searchSongs/songDetail/songUrl/songLyric`、`NeteaseSongDto/NeteaseUrlDto/NeteaseLyricDto`、`SourceDescriptor(id:, source:)`、`onlineSearchProvider((sourceId, query))`、`trackLyricsProvider(Track)` 全程一致。

**Review Focus tests:** ①`netease_source_test` 的「no stream → StateError」+ `lyrics_view_test` 占位；②`source_track_id_codec_test` + `track_codec_test` 的 netease 往返；③`lrc_parser_test` 的变体与纯音乐；④`online_search_provider_test` 空查询/禁用 + `search_screen_test` 切源；⑤`netease_crypto_test` 实采向量 + 非 ASCII + `netease_client_test` 的请求体解密。
