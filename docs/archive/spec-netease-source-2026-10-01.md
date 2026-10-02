# 设计：网易云音乐音源（匿名搜索 + 播放 + 歌词）

- 日期：2026-10-01
- 状态：**已实现**（2026-10-01）· 2026-10-02 随 v1.0.0 归档
- 范围：新增网易云在线音源（weapi/eapi 加密、搜索、详情、匿名流解析、同步歌词）、在线源注册表、搜索界面多源切换、身份编解码收敛、歌词子系统
- 目标读者：实现者
- 关联：[`docs/architecture.md`](../architecture.md) §5/§6、[`docs/bilibili-source.md`](../bilibili-source.md)
- 计划：`docs/archive/plan-netease-source-2026-10-01.md`（本文批准后由 writing-plans 产出）

## 1. 背景

Flind Player 已有 `MusicSource` / `StreamResolver` / `SourceCapabilities` 抽象，在线源目前只有 Bilibili，本地源为 `local`；`CompositeStreamResolver` 已按 `Track.source` 路由，`data/sources/` 下已有 Bilibili 适配器的完整范式（client、限流、mapper、source）。搜索界面目前**硬编码只查 Bilibili**（`biliSearchResultsProvider`），`innerStreamResolverProvider` 也硬编码 `biliSource.id`。

歌词目前**只有静态占位**：`features/player/lyrics_view.dart` 的 `LyricsView` / `LyricsPreview` 恒显示「词莫见，敬聆听」，没有 `Lyric` 模型、没有 `LyricsProvider`、没有时间轴。

本次要新增「网易云音乐」作为第二个在线源，并落地真正的歌词能力。网易云没有公开 API，本设计采用与 Bilibili 同构的**原生直连**：在 Dart 内实现网易云的 `weapi` / `eapi` 私有协议加密，直接请求 `music.163.com`，不依赖任何自建服务。

## 2. 目标与非目标

### 目标
- 新增 `netease` 在线源：匿名搜索、歌曲详情、匿名 128k 流解析，接入统一曲库、缓存、封面管线。
- 新增**歌词子系统**：`Lyric` 时间轴模型、`LyricsProvider` 抽象、LRC 解析、网易云歌词获取（原文 + 翻译双语），播放页同步滚动并高亮当前行。
- 引入**在线源注册表**，使「多源」成为一等能力：搜索界面可切换源，`StreamResolver` / 歌词路由与「远程禁用」有统一落点。
- 收敛 `SourceTrackId` 的持久化映射，避免新增源时静默降级。

### 非目标
- **不做登录**：不实现二维码/手机登录，不持久化 `MUSIC_U`，不取更高音质（无损/Hi-Res）与 VIP 曲目。
- **不做歌单/收藏/每日推荐**：不实现 `RemotePlaylistSource`（Bilibili 收藏夹浏览不动）。
- **Bilibili / 本地歌词不做**：这两类源不实现 `LyricsProvider`，继续走现有占位。本地内嵌歌词、`.lrc` 同名文件不在本版。
- **不做逐字歌词**：`klyric` / yrc 卡拉 OK 逐字高亮、罗马音（`romalrc`）不做，仅整行时间轴 + 翻译。
- **不做歌词磁盘缓存**：本版仅会话内内存缓存（见 §15）。
- **不引入远程配置基础设施**：只留 `disabledSourceIdsProvider` 过滤钩子。
- 不做 Bilibili v2 Web 代理相关工作。

## 3. 已确认的语义决策

1. **MVP = 匿名搜索 + 播放**，不登录。
2. **搜索界面用源切换**（`SegmentedButton` / 标签），不做双源聚合。
3. **原生直连**，自实现 `weapi` / `eapi` 加密，不绑定自建 API 服务。
4. **采用在线源注册表**（Approach B），并迁移现有 Bilibili 搜索 provider 与 resolver 装配，不做平行双套。
5. **身份编解码收敛**为唯一共享实现（见 §8），不逐处复制。
6. **歌词做到「同步滚动 + 当前行高亮 + 双语」**：网易云歌词为唯一来源，双语指原文 + `tlyric` 翻译。
7. 网易云源**可远程禁用**，落点即注册表过滤；禁用后其歌词一并不可达。

## 4. 目标架构与不变量

- 网易云适配器**只**通过 `MusicSource` / `StreamResolver` / `LyricsProvider` 接口被外界使用；UI、播放、缓存不得直接依赖 `NeteaseSource` / `NeteaseClient`，与 Bilibili 的隔离纪律一致（便于远程禁用）。
- 在线源的**唯一注册入口**是 `onlineSourcesProvider`；搜索、流解析、歌词都从它派生，不再出现按源硬编码。
- 加密与 LRC 解析都是**纯函数**，与网络、DTO 分离，可离线单测。
- 匿名能力边界明确：拿不到流地址时视为**不可播放**，拿不到歌词时回落占位，绝不猜测、不回退到其它源。
- 歌词**缺失≠错误**：网络失败或无歌词一律呈现现有占位，不阻塞播放、不弹错误。

## 5. 加密与请求协议

固定常量（集中定义、附来源注释）：

| 名称 | 值 |
|---|---|
| `presetKey`（weapi 第一层） | `0CoJUm6Qyw8W8jud` |
| `iv` | `0102030405060708` |
| `eapiKey` | `e82ckenh8dichen8` |
| RSA 指数 `e` | `0x10001` |
| RSA 模数 `n` | `00e0b509f6259df8642dbc35662901477df22677ec152b5ff68ace615bb7b725152b3ab17a876aea8a5aa76d2e417629ec4ee341f56135fccf695280104e0312ecbda92557c93870114af6c9d05c4f7f0c3685b7a46bee255932575cce10b424d813cfe4875d3e82047b97ddef52741d546b8e289dc6935b3ece0462db0a22b8e7`（网易云固定 1024-bit 公钥模数） |
| weapi base62 字母表 | `abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789` |

### 5.1 weapi（搜索、详情、歌词）

```
secretKey = 16 个随机 base62 字符
params    = base64( AES-128-CBC( base64( AES-128-CBC( json, presetKey, iv ) ), secretKey, iv ) )
encSecKey = hex( (112 个 0x00 ⧺ reverse(secretKey)) ^ e mod n )     # RSA_NO_PADDING 原始运算
```

- 两层 AES 均为 **PKCS7** 填充。
- RSA 用 `dart:core` 的 `BigInt.modPow` 完成（无需 RSA 库）；输入按 128 字节、左补零。
- 请求：`POST`，`Content-Type: application/x-www-form-urlencoded`，body `params=…&encSecKey=…`。

### 5.2 eapi（流地址）

```
text   = json(body ⧺ {header: cookies})            # 紧凑分隔符 (',', ':')
digest = md5( "nobody" + path + "use" + text + "md5forencrypt" )
params = UPPERHEX( AES-128-ECB( path + "-36cd479b6b5-" + text + "-36cd479b6b5-" + digest, eapiKey ) )
```

- 请求：`POST`，`Content-Type: application/x-www-form-urlencoded`，body `params=…`。
- `path` 为带 `/api` 前缀的 API 路径，如 `/api/song/enhance/player/url/v1`。
- `cookies` 为匿名占位集（见 §6.2），合并进加密体与 `Cookie` 头。

### 5.3 可测性

`NeteaseCrypto.weapi(map, {Uint8List? secretKey})` 暴露可注入的 `secretKey`：测试传入固定值即可断言 `encSecKey` 的已知向量并解密 `params`；生产默认 `Random.secure()`。`eapi` 提供对称的 `decrypt` 便于往返测试。

## 6. HTTP 客户端与端点

### 6.1 端点清单（MVP）

| 用途 | 方法 | 主机 / 路径 | 请求体 |
|---|---|---|---|
| 搜索 | weapi POST | `music.163.com/weapi/search/get?csrf_token=` | `{s: query, type: 1, limit: 30, offset: (page-1)*30, total: true, csrf_token: ''}` |
| 歌曲详情 | weapi POST | `music.163.com/weapi/v3/song/detail?csrf_token=` | `{c: jsonEncode([{id: songId}])}` |
| 流地址 | eapi POST | `interface3.music.163.com/eapi/song/enhance/player/url/v1` | `{ids: "[songId]", level: "standard", encodeType: "flac"}` |
| 歌词 | weapi POST | `music.163.com/weapi/song/lyric?csrf_token=` | `{id: songId, lv: -1, tv: -1, rv: -1, kv: -1, csrf_token: ''}` |

响应均为明文 JSON（不请求 `e_r=1` 加密返回）。成功时主体 `code == 200`。歌词响应字段：`lrc.lyric`（原文）、`tlyric.lyric`（翻译）、`romalrc.lyric`（罗马音，本版不使用）、`klyric.lyric`（逐字，本版不使用）。

### 6.2 请求头与匿名 Cookie

- 复用 `kDesktopUserAgent`；强制 `Referer: https://music.163.com`、`Accept-Language: zh-CN,zh;q=0.9,en;q=0.8`。
- **绝不发 `Origin`**（与 Bilibili 客户端一致）。
- 匿名 eapi 必须带 `Cookie: os=pc`，并补空占位 `appver`、`deviceId`、`versioncode`、`mobilename`、`buildver`、`resolution`、`__csrf`、`channel`、`requestId`（参照 `yt-dlp` 的匿名样本），否则可能被降级/拒绝。
- `validateStatus: (_) => true`；非 JSON 或 `code != 200` 抛 `NeteaseApiException`（类型化，仿 `BiliApiException`，含 `code`/`message`），`-462` 归为「需登录」。

### 6.3 Dio

新建 `NeteaseClient`，`BaseOptions` 超时与 Bilibili 对齐（connect 10s / receive 15s / send 10s）。weapi 与 eapi 用两个方法 `postWeapi(path, map)` / `postEapi(apiPath, map)`，各自拼接 host。

## 7. 模块划分

```
core/models/
  lyric.dart                               # 新：Lyric + LyricLine
core/services/
  lyrics_provider.dart                     # 新：LyricsProvider 抽象
  lrc_parser.dart                          # 新：LRC → Lyric（纯函数）
core/sources/
  source_track_id.dart                     # + NeteaseTrackId
  online_source.dart                       # 新：SourceDescriptor
data/codec/
  source_track_id_codec.dart               # 新：唯一 id ↔ 持久化映射（§8.3）
data/sources/netease/
  netease_crypto.dart                      # weapi / eapi / decrypt（纯函数）
  netease_client.dart                      # Dio + 错误映射
  netease_api.dart                         # search/get + song detail 富化 / song url v1 / lyric
  netease_models.dart                      # DTO（含 lyric DTO）
  netease_mappers.dart                     # DTO → Track
  netease_source.dart                      # MusicSource + StreamResolver + LyricsProvider
data/providers/
  netease_providers.dart                   # client / api / source
  online_source_providers.dart             # 注册表 + 泛化搜索 + 禁用集
  lyrics_providers.dart                    # 歌词路由 + 当前曲目歌词
```

新增依赖：**`pointycastle`**（仅 AES-128-CBC/ECB + PKCS7）。RSA 用 `BigInt.modPow`，md5/base64 用现有 `crypto` / `dart:convert`。

## 8. 身份、持久化与缓存键

### 8.1 `NeteaseTrackId`

```dart
final class NeteaseTrackId extends SourceTrackId {
  final int songId;   // 网易云歌曲 id，songId 在源内唯一
}
```

`uri = 'netease:<songId>'`；`source = 'netease'`。

### 8.2 编解码收敛（关键）

`SourceTrackId` 当前在三处编解码，其中 `data/codec/track_codec.dart` 是穷尽 `switch`（新增子类会编译报错），而 `drift_music_library_repository.dart` 与 `drift_playlist_repository.dart` 是 `if` 链，**新增源会静默 fallback 成 `LocalTrackId`**，属于隐性数据损坏。

据此抽出唯一实现 `data/codec/source_track_id_codec.dart`：

```dart
String encodeSourceTrackId(SourceTrackId id);                 // DB 列
SourceTrackId decodeSourceTrackId(String source, String raw, String uri);
Map<String, dynamic> encodeSourceTrackIdJson(SourceTrackId id);   // JSON（标签对象）
SourceTrackId decodeSourceTrackIdJson(Object? value);
```

- DB：`local` → 路径；`bilibili` → `<bvid>:<cid>`；`netease` → `<songId>`。
- JSON：`{kind: 'local'|'bili'|'netease', …}`。
- 两个 drift repository 与 `track_codec.dart` 改为调用共享实现；`track_codec` 的 `decodeSourceTrackIdJson` 保留「未知 kind 抛 `FormatException`」的对外语义，两个 drift repository 保留「未知源回落 `LocalTrackId(uri)`」的既有降级语义。

### 8.3 缓存键

`cache_keys.dart` 的 `cacheSourceTrackId` 增加 `NeteaseTrackId => id.songId.toString()` 分支（与 `source` 列组合后唯一）。

## 9. 音源适配器行为

`class NeteaseSource implements MusicSource, StreamResolver, LyricsProvider`，`id = 'netease'`，`capabilities = {search, streamDirect}`（不含 `login`）。

- **`search(query, {page})`**：调用 weapi 搜索；映射 `result.songs[]` → `Track`：
  - `title = name`；`artist = ar.map(name).join(' / ')`；`album = al.name`；`duration = Duration(milliseconds: dt)`；
  - `coverUrl = 归一化(al.picUrl)`（去 `?param=` 尺寸后缀，供现有封面缓存管线处理）；
  - `sourceTrackId = NeteaseTrackId(songId: id)`；`uri = 'netease:<id>'`。
- **`fetchTrack(id)`**：weapi 详情，取 `songs[0]`；映射同上。
- **`resolveStream(track)`**：eapi 流地址；取 `data.first`：
  - `url != null` → `StreamInfo(url, headers: {Referer, User-Agent}, qualityId: level)`；不设 `expiresAt`（URL 长效；失效由缓存层现有的 403 自愈重解析处理）。
  - `url == null`（无版权 / 需登录 / 地区限制）→ 抛 `StateError('No stream available for netease:<id>')`，UI 复用现有错误提示，归为「不可播放」。
  - `data` 为空或 songId 类型不符 → `StateError` / `UnsupportedError`。
- **`lyricsFor(track)`**：weapi 歌词；取 `lrc.lyric` + `tlyric.lyric`，交 LRC 解析合并（§11）；无原文或纯音乐占位（`[99:00.00]纯音乐，请欣赏`）→ 返回 `null`（UI 占位）。

## 10. 在线源注册表与搜索界面

### 10.1 注册表

```dart
// core/sources/online_source.dart
class SourceDescriptor { final String id; final MusicSource source; }
```

```dart
// data/providers/online_source_providers.dart
final disabledSourceIdsProvider = Provider<Set<String>>((ref) => const <String>{});
final onlineSourcesProvider = Provider<List<SourceDescriptor>>((ref) {
  final disabled = ref.watch(disabledSourceIdsProvider);
  return <SourceDescriptor>[
    SourceDescriptor(id: biliSource.id, source: ref.watch(biliSourceProvider)),
    SourceDescriptor(id: neteaseSource.id, source: ref.watch(neteaseSourceProvider)),
  ].where((d) => !disabled.contains(d.id)).toList(growable: false);
});

final onlineSearchProvider =
    FutureProvider.family<List<Track>, (String sourceId, String query)>((ref, key) async {
  final query = key.$2.trim();
  if (query.isEmpty) return const <Track>[];
  final descriptor = ref.watch(onlineSourcesProvider).firstWhere((d) => d.id == key.$1);
  return descriptor.source.search(query);
}, retry: (_, _) => null);
```

- 记录类型 `(String, String)` 具值相等性，可直接做 family key。
- `retry: null` 沿用 Bilibili「失败立即暴露」策略。
- `disabledSourceIdsProvider` 是远程禁用的唯一钩子；MVP 返回空集。

### 10.2 装配

- `innerStreamResolverProvider` 改为从 `onlineSourcesProvider` 构建 `sources` map：`{ for (final d in …) if (d.source is StreamResolver) d.id: d.source as StreamResolver }`（`localResolver` 仍单独注入）。
- 歌词路由（§11.4）同样从 `onlineSourcesProvider` 派生，只收 `LyricsProvider`。
- `remotePlaylistSourceProvider`（Bilibili 收藏夹）不变。

### 10.3 搜索界面

- 删除 `biliSearchResultsProvider`；`SearchScreen` 从 `onlineSourcesProvider` 生成 `SegmentedButton<String>`，选中 `sourceId` 存于 `_SearchScreenState`（默认第一个源）。
- `_buildBody` watch `onlineSearchProvider((selectedSourceId, _submittedQuery))`。
- 「仅在提交时查询，绝不逐键查询」的行为保持不变。
- 标签由 UI 按 id 取 l10n：新增 `sourceBilibili`、`sourceNetease`；`_SearchHint` 文案改为源无关（或按当前源显示），不再写死 Bilibili。
- 切源时结果自动切换（切换 `sourceId` 即切换 family key，Riverpod 自动缓存各源上次结果）。

## 11. 歌词子系统

### 11.1 模型

```dart
// core/models/lyric.dart
@immutable
class LyricLine {
  final Duration timestamp;
  final String text;
  final String? translation;   // 有则双语
}

@immutable
class Lyric {
  final List<LyricLine> lines;         // 已按 timestamp 升序

  /// 最后一个 `timestamp <= position` 的行下标；`position` 早于首行时为 `0`，
  /// `lines` 为空时为 `null`。二分查找。
  int? indexAt(Duration position);
}
```

### 11.2 LRC 解析（纯函数）

`core/services/lrc_parser.dart`：

```dart
Lyric? parseLrc(String? original, {String? translation});
```

- 支持 `[mm:ss]`、`[mm:ss.xx]`、`[mm:ss.xxx]`，以及**一行多时间标签**（`[00:01.00][00:05.00]词`）。
- 识别并应用 `[offset:+/-毫秒]`；忽略 `[ti:]/[ar:]/[al:]/[by:]` 等元信息。
- 按时间戳升序；丢弃空白行；`original == null || 全空` → `null`。
- **翻译合并**：解析 `translation` 得到时间戳→文本映射，按键并入原文行；纯音乐占位整段视为无歌词 → `null`。

### 11.3 获取

- `NeteaseApi.fetchLyric(int songId)` → weapi `/weapi/song/lyric`；返回 DTO 暴露 `lrc` / `tlyric`。
- `NeteaseSource.lyricsFor(track)`：仅接受 `NeteaseTrackId`；组装 `parseLrc(lrc, translation: tlyric)`。

### 11.4 路由与 provider

```dart
// core/services/lyrics_provider.dart
abstract interface class LyricsProvider {
  Future<Lyric?> lyricsFor(Track track);
}
```

```dart
// data/providers/lyrics_providers.dart
/// 该源的适配器是否实现 LyricsProvider（决定占位文案）。
final sourceSupportsLyricsProvider = Provider.family<bool, String>((ref, sourceId) {
  for (final d in ref.watch(onlineSourcesProvider)) {
    if (d.id == sourceId) return d.source is LyricsProvider;
  }
  return false;
});

/// 按 track.source 路由到注册表中对应的 LyricsProvider。
final trackLyricsProvider = FutureProvider.family<Lyric?, Track>((ref, track) async {
  LyricsProvider? provider;
  for (final d in ref.watch(onlineSourcesProvider)) {
    if (d.id == track.source && d.source is LyricsProvider) {
      provider = d.source as LyricsProvider;
      break;
    }
  }
  if (provider == null) return null;
  try {
    return await provider.lyricsFor(track);
  } catch (_) {
    return null;   // 歌词缺失不弹错，回落占位
  }
}, retry: (_, _) => null);
```

- 以 `Track` 为 family key（`Track` 具值相等性；展示字段 `coverUrl` 已排除），按曲目缓存。
- 当前只有 `netease` 实现该接口；`bilibili` / `local` 无 provider → `null` → 占位。
- 路由按 `track.source` 精确匹配，避免「注册表里第一个 LyricsProvider」被错误用于不支持的源。

### 11.5 UI

- `LyricsView` / `LyricsPreview` 改为 `ConsumerWidget`：
  - 从 `playbackStateProvider` 取 `currentTrack` 与 `position`，watch `trackLyricsProvider(currentTrack)`。
  - `Lyric == null` → 维持现有占位（`lyricsUnavailable` / `lyricsPlaceholderHint`）。
  - 有歌词 → 完整列表，当前行（`indexAt(position)`）高亮，**自动滚动居中**当前行；双语时翻译以次级样式显示在原文下方。
  - `LyricsPreview` 折叠态显示当前行（+翻译）。
- 位置更新频率沿用 `playbackStateProvider`；高亮用 `indexAt` 二分，无额外计时器。
- 新增 l10n：`lyricsLoading`（可选）；`lyricsPlaceholderHint` 语义收窄为「该音源未适配歌词」，网易云无歌词时使用新 `lyricsNotFound`（如「暂无歌词」）。

## 12. 错误处理、限流、远程禁用、法务

- **错误映射**：`error_messages.dart` 增加 `NeteaseApiException` 分支：`-462` → `errLoginRequired`，其余 → 新 l10n `errNeteaseApi(code)`。`NeteaseApiException.toString` 仿 `BiliApiException`。歌词失败不走该映射（§11.4 吞掉）。
- **限流**：泛化现有 `data/sources/bilibili/rate_limiter.dart` 的 `RateLimiter`，把硬编码的 `on BiliApiException` / `retryableCodes` 改为可注入的 `bool Function(Object) isRetryable`，默认值保持**现有 Bilibili 行为**（向后兼容，`rate_limiter_test.dart` 覆盖）。网易云复用同一套「单飞 + 抖动间隔」，参数 `minInterval 300ms / maxInterval 1s`，按超时与网络错误重试。理由：两源（含歌词请求）请求节奏需求同构，避免复制 limiter。
- **远程禁用**：仅 `disabledSourceIdsProvider` 钩子（§10.1），不建远程配置；禁用后搜索、流、歌词一并不可达。
- **法务**：新增 `docs/netease-source.md`，结构对齐 `bilibili-source.md`：端点、weapi/eapi 协议、匿名能力边界、ToS 个人使用姿态、不内置凭证、不做带凭证的公共代理、源可远程禁用。

## 13. 测试计划

### 单元
- `netease_crypto_test.dart`：eapi 加密↔解密往返；weapi 注入固定 `secretKey` → 断言 `encSecKey` 已知向量、`params` 解密回原文；PKCS7 边界（空/整块）。
- `lrc_parser_test.dart`：`mm:ss` / `.xx` / `.xxx`、一行多标签、`offset`、元信息忽略、空白行丢弃、翻译按时间戳合并、纯音乐占位 → `null`、无序输入排序、`indexAt` 边界。
- `netease_mappers_test.dart`：搜索/详情 DTO → `Track`（title/artist/album/duration/coverUrl）、封面归一化、`NeteaseTrackId`/`uri`。
- `netease_source_test.dart`：fake `NeteaseApi` → 搜索映射；`resolveStream` 的 URL、headers、qualityId；`url == null` → `StateError`；`data` 空 → `StateError`；`lyricsFor` 合并翻译、纯音乐 → `null`。
- `netease_client_test.dart`：注入 `HttpClientAdapter`（仿 `cover_downloader_test.dart`），断言 eapi 请求头含 `os=pc`/`Referer`/无 `Origin`，`code != 200` → `NeteaseApiException`。
- `online_search_provider_test.dart`：`onlineSearchProvider` 按 sourceId 路由；空 query 短路；禁用集的源不出现在注册表。
- `lyrics_providers_test.dart`：`trackLyricsProvider` 对 netease 返回 `Lyric`、对 bilibili/local 返回 `null`、provider 抛错时返回 `null`。
- `source_track_id_codec_test.dart`：三种 id 的 DB/JSON 往返；未知源回落；未知 JSON kind 抛错。
- 更新 `rate_limiter_test.dart` 覆盖注入 `isRetryable` 的默认与自定义行为。

### Widget
- `lyrics_view_test.dart`：有歌词时按 position 高亮正确行、自动滚动；双语渲染；无歌词/未适配回落占位；`LyricsPreview` 显示当前行。
- 更新 `mini_settings_test.dart`（其依赖 `LyricsView`/`LyricsPreview` 的布局与展开折叠）以覆盖有歌词路径。

### 迁移 / 回归
- 更新 `search_screen_test.dart`、`home_shell_test.dart`、`responsive_layout_test.dart`（当前均 override `biliSearchResultsProvider`）为 override `onlineSourcesProvider` 注入 fake 源。
- 更新 `error_messages_test.dart` 覆盖 NetEase 分支。
- `composite_stream_resolver_test.dart` 增加 `netease` 路由用例。
- `drift_music_library_repository_test.dart` / `playlist_repository_test.dart` 增加 `netease` 行解码。

### 集成（可选、联网）
- `integration_test/netease_smoke_test.dart`：仿 `bilibili_smoke_test.dart`，实网搜索取一首、解析 128k 流、拉取歌词。

### 基线
- `flutter analyze` 0 error；`flutter test` 全绿。

## 14. 风险与已知

- **匿名可用性**：部分歌曲（VIP / 无版权 / 地区限制）匿名拿不到流地址，表现为「不可播放」；部分歌曲无歌词。这是匿名 MVP 的固有边界，非缺陷。
- **协议易变**：`weapi`/`eapi` 非公开协议，网易云可能调整（如新增 `NMTID` 校验、风控）。适配器隔离在接口后，且可远程禁用，最坏情况是下架该源。
- **歌词时间轴漂移**：高亮依赖 `playbackState.position` 的刷新频率与 seek 后的即时性；若位置流更新偏慢，滚动可能滞后。用 `indexAt` 二分 + 就近定位缓解，不引入独立计时器。
- **限流泛化**：改动共享 `RateLimiter` 有回归 Bilibili 的风险，用「默认可重试谓词保持旧行为 + 现有测试」兜底。
- **编码收敛**：抽出共享 codec 会触碰两个 drift repository 与 `track_codec.dart`，属必要的一次性整理，由两组往返测试保证等价。

## 15. 延期项

- 登录 / 扫码 / `MUSIC_U` 持久化、更高音质与 VIP 曲目。
- 个人歌单、每日推荐、收藏（`RemotePlaylistSource`）。
- Bilibili / 本地歌词（本地内嵌、同名 `.lrc`）。
- 逐字歌词（`klyric`）、罗马音（`romalrc`）。
- 歌词磁盘缓存（本版仅会话内内存）。
- 远程配置化的源禁用。
- 搜索分页 UI（当前 `search` 已支持 `page`，UI 仍只取第一页，与 Bilibili 现状一致）。

## 16. 建议执行顺序

1. **身份与编解码**：`NeteaseTrackId` + 抽出 `source_track_id_codec.dart` 并迁移三处 + `cache_keys.dart` 分支；跑现有测试保证等价。
2. **歌词内核**：`lyric.dart` + `lrc_parser.dart` + `lyrics_provider.dart` 抽象 + 单测（TDD）。
3. **加密**：`netease_crypto.dart` + 单测（TDD，先红后绿）。
4. **客户端与 API**：`netease_client.dart` / `netease_api.dart` / `netease_models.dart` + 单测。
5. **映射与适配器**：`netease_mappers.dart` / `netease_source.dart`（含 `lyricsFor`）+ 单测。
6. **注册表与装配**：`online_source.dart`、`online_source_providers.dart`、`lyrics_providers.dart`、`NeteaseClient` 错误映射、`RateLimiter` 泛化、`innerStreamResolverProvider` 改造。
7. **搜索界面**：`SearchScreen` 多源切换 + l10n + 现有测试迁移。
8. **歌词界面**：`LyricsView` / `LyricsPreview` 同步高亮 + l10n + widget 测试。
9. **文档与回归**：`docs/netease-source.md`、`flutter analyze` + `flutter test`。

> 子智能体派发遵循 [`docs/agent-model-policy.md`](agent-model-policy.md)：主智能体负责中高风险/高难度；子智能体按难度+工作量授模型，审阅者不低于实现者，同形小任务批处理，免费端点限量。
