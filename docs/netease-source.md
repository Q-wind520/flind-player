# 网易云音乐音源适配器设计

> 关联：[`architecture.md`](architecture.md) §5、§6、§7
> 关联：[`spec-netease-source-2026-10-01.md`](spec-netease-source-2026-10-01.md)（设计规格，状态：已实现）
> 调研日期：2026-10-01（`weapi` / `eapi` 为非公开协议，行为随风控与客户端版本变化）

---

## 1. 目标与范围

将网易云音乐作为 Flind Player 的**第二个在线音源**（匿名），与 Bilibili 并列于在线源注册表，供搜索、播放与歌词使用。

- **MVP（已实现）**：匿名搜索、歌曲详情、匿名流解析、同步歌词（原文 + 翻译双语）
- **不做（非目标）**：
  - **登录**：不实现扫码/手机登录，不持久化 `MUSIC_U`，因此拿不到更高音质与 VIP 曲目
  - **歌单 / 收藏 / 每日推荐**：不实现 `RemotePlaylistSource`
  - **无损 / Hi-Res**：匿名仅请求 `level=standard`
  - **逐字歌词**：`klyric`（卡拉 OK 逐字）与 `romalrc`（罗马音）不解析，仅整行时间轴 + 翻译
  - **歌词磁盘缓存**：仅会话内内存缓存（Riverpod 按 `Track` 缓存）

> ⚠️ **协议风险提示**：`weapi` / `eapi` 是网易云 Web/Android 客户端的私有协议，**无公开文档、无稳定性承诺**。网易云可随时调整加密（如新增 `NMTID` 校验）或加风控。适配器完全隔离在 `MusicSource` / `StreamResolver` / `LyricsProvider` 接口之后，且音源可远程禁用（见 §6），最坏情况是下架该源。

---

## 2. 端点清单

全部为**匿名**：不携带任何凭证 / 登录 Cookie（如 `MUSIC_U`），无登录态——但协议要求的匿名 `Cookie` 头仍会发送（见 §4）。全部为 `POST`，响应为明文 JSON（不请求 `e_r=1` 加密返回），成功时主体 `code == 200`。

| 用途 | 协议 | 主机 / 路径 | 请求体 |
|---|---|---|---|
| 搜索 | weapi | `music.163.com/weapi/search/get?csrf_token=` | `{s, type: 1, limit: 30, offset: (page-1)*30, total: true, csrf_token: ''}` |
| 歌曲详情 | weapi | `music.163.com/weapi/v3/song/detail?csrf_token=` | `{c: jsonEncode([{id: songId}])}` |
| 流地址 | eapi | `interface3.music.163.com/eapi/song/enhance/player/url/v1` | `{ids: "[songId]", level: "standard", encodeType: "flac"}` |
| 歌词 | weapi | `music.163.com/weapi/song/lyric?csrf_token=` | `{id, lv: -1, tv: -1, rv: -1, kv: -1, csrf_token: ''}` |

- 搜索分页固定 `limit: 30`（`NeteaseApi.searchPageSize`），`offset` 按页递增。
- **搜索为何不用 cloudsearch**：`/weapi/cloudsearch/get/web`（及 `eapi`/明文 GET 变体）会被服务端以 `code: 50000005` 拒绝；`/weapi/search/get` 可用但不含封面字段。故搜索走 `search/get` 拿到 id，再用 `/weapi/v3/song/detail` 批量富化为规范字段（`ar`/`al.picUrl`/`dt`）；详情富化返回空时回退到 `search/get` 原始行（此时无封面）。
- 歌词响应字段：`lrc.lyric`（原文）、`tlyric.lyric`（翻译）、`romalrc.lyric`（罗马音，不用）、`klyric.lyric`（逐字，不用）。
- 流地址 `data[]` 为空或 `url` 为 `null` 视为不可播放（见 §5）。
- 网易云返回的 `http://...music.126.net/...` 流地址会被升级为 `https`（同一 URL、同一鉴权 query，CDN 支持；避免 Android 默认拦截明文 http）。

---

## 3. `weapi` / `eapi` 协议与固定常量

实现集中在 `lib/data/sources/netease/netease_crypto.dart`，**纯函数、无 I/O**，可离线单测。固定常量为网易云 Web/PC 客户端的公开常量：

| 名称 | 值 |
|---|---|
| `presetKey`（weapi 第一层 AES key） | `0CoJUm6Qyw8W8jud` |
| `iv`（CBC 初始化向量） | `0102030405060708` |
| `eapiKey`（eapi AES key） | `e82ckenh8dichen8` |
| RSA 指数 `e` | `0x10001` |
| RSA 模数 `n` | `00e0b509f6259df8642dbc35662901477df22677ec152b5ff68ace615bb7b725152b3ab17a876aea8a5aa76d2e417629ec4ee341f56135fccf695280104e0312ecbda92557c93870114af6c9d05c4f7f0c3685b7a46bee255932575cce10b424d813cfe4875d3e82047b97ddef52741d546b8e289dc6935b3ece0462db0a22b8e7`（1024-bit 固定公钥模数） |
| weapi base62 字母表 | `abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789` |

### 3.1 weapi（搜索、详情、歌词）

```
secretKey = 16 个随机 base62 字符（生产用 Random.secure()）
params    = base64( AES-128-CBC( base64( AES-128-CBC( json, presetKey, iv ) ), secretKey, iv ) )
encSecKey = hex( reverse(secretKey) 左补零到 128 字节 后做 m^e mod n )   # RSA_NO_PADDING 原始运算
```

- 两层 AES 均为 **PKCS7** 填充（`pointycastle` 的 `PaddedBlockCipherImpl`）。
- **RSA 用 `dart:core` 的 `BigInt.modPow` 完成**，不需要任何 RSA 库；输入按 128 字节、左补零，输出补到 256 位 hex。
- 请求：`POST`，`Content-Type: application/x-www-form-urlencoded`，body `params=…&encSecKey=…`。
- `NeteaseCrypto.weapi(body, {Uint8List? secretKey})` 暴露可注入的 `secretKey`：测试传固定值即可断言已知向量并解密 `params`。

### 3.2 eapi（流地址）

```
text   = json(body + {header: {os: 'pc'}})         # 紧凑分隔符 (',', ':')
digest = md5( "nobody" + path + "use" + text + "md5forencrypt" )
params = UPPERHEX( AES-128-ECB( path + "-36cd479b6b5-" + text + "-36cd479b6b5-" + digest, eapiKey ) )
```

- `path` 带 `/api` 前缀，如 `/api/song/enhance/player/url/v1`。
- `header` **仅**为 `{'os': 'pc'}`——只进 AES 加密体；完整的匿名 Cookie 串（`_anonCookie`，见 §4）只作为 HTTP `Cookie` 头发送，**不进加密体**。两者是互不相同的两件事。
- 请求：`POST`，`Content-Type: application/x-www-form-urlencoded`，body `params=…`，发往 `interface3.music.163.com`。
- `NeteaseCrypto.eapiDecrypt` 提供对称解密，供往返测试。

---

## 4. 请求头与匿名 Cookie

`NeteaseClient`（Dio）统一装配，超时与 Bilibili 客户端对齐（connect 10s / receive 15s / send 10s），`validateStatus: (_) => true` 自行判码：

```
User-Agent:      kDesktopUserAgent（与 Bilibili 共享的桌面 UA，不得含 curl/python）
Referer:         https://music.163.com        （kNeteaseReferer，API 与 CDN 通用）
Accept:          application/json, text/plain, */*
Accept-Language: zh-CN,zh;q=0.9,en;q=0.8
Origin:          绝不发送（headers 显式 remove）
Cookie (eapi):   os=pc; appver=8.0.0; deviceId=; versioncode=140;
                 mobilename=undefined; buildver=…; resolution=1920x1080;
                 __csrf=; channel=undefined; requestId=
```

- **`os=pc` 是 eapi 的硬性要求**：匿名 eapi 必须带，另补占位 `appver` / `deviceId` / `versioncode` / `mobilename` / `buildver` / `resolution` / `__csrf` / `channel` / `requestId`（其中 `deviceId`、`requestId` 为空占位，参照 `yt-dlp` 匿名样本），否则可能被降级或拒绝。
- **禁 `Origin`**：与 Bilibili 客户端同一纪律——第三方 Origin 会被 WAF 拦截。
- 非 JSON 响应或 `code != 200` 抛 `NeteaseApiException`（类型化，含 `code` / `message`，`toString` 仿 `BiliApiException`）；`-462` 归为「需登录」，UI 走 `errLoginRequired`，其余走 `errNeteaseApi(code)`。

---

## 5. 能力边界

| 场景 | 表现 | 说明 |
|---|---|---|
| 匿名流 | **128k（`level=standard`）** | 不登录拿不到更高音质；`encodeType: flac` 只是请求参数，匿名实际返回标准档 |
| `url == null`（无版权 / 需登录 / 地区限制） | `resolveStream` 抛 `StateError('No stream available for netease:<id>')` | UI 复用现有错误提示，归为「**不可播放**」；绝不猜测、绝不回退到其它源 |
| `data` 为空 / songId 类型不符 | `StateError` / `UnsupportedError` | 同上 |
| 纯音乐（`[99:00.00]纯音乐，请欣赏`） | `lyricsFor` 返回 `null` | 歌词**缺失 ≠ 错误**：UI 呈现占位，不阻塞播放、不弹错误 |
| 该源无歌词（Bilibili / 本地） | `trackLyricsProvider` 无 `LyricsProvider` → `null` → 占位 | 占位文案按 `sourceSupportsLyricsProvider` 区分「暂无歌词」/「该音源暂未适配歌词」 |
| 流地址时效 | 不设 `expiresAt`（URL 长效） | 失效由缓存层现有的 403 自愈重解析处理 |

**限流**：复用泛化后的共享 `RateLimiter`（`minInterval 300ms` / `maxInterval 1s` 抖动），`isRetryable` 对 `NeteaseApiException`（`-462` 除外）、`SocketException`、`TimeoutException`、`DioException` 重试；搜索、详情、流、歌词四类请求全部经它排队（单飞 + 抖动间隔）。

---

## 6. 法务与稳定性姿态

1. **个人使用姿态**：与 Bilibili 音源同一法务立场——个人使用、不内置任何账号凭证、不做带凭证的公共代理（详见 [`bilibili-source.md`](bilibili-source.md) §1 的律师函时间线，社区 API 文档仓库已被关停）。
2. **不内置凭证**：本适配器**零登录态**，不接触用户账号；匿名 Cookie 仅为协议占位常量。
3. **可远程禁用**：`disabledSourceIdsProvider` 是唯一禁用钩子；禁用后其搜索、流解析、歌词**一并不可达**（注册表过滤，UI 不再显示该源）。MVP 返回空集，远程配置基础设施留待后续。
4. **协议易变**：`weapi` / `eapi` 非公开协议，随时可能调整。适配器完全隔离在 `MusicSource` / `StreamResolver` / `LyricsProvider` 之后，UI、播放、缓存不 import `NeteaseSource` / `NeteaseClient`；最坏情况是下架该源，应用其余部分不受影响。
5. **集中签名客户端**：所有 HTTP 走唯一 `NeteaseClient`，禁止旁路；加密与 LRC 解析为纯函数，改协议只动一个文件。

---

## 7. 适配器组件划分

```
lib/data/sources/netease/
├── netease_crypto.dart    # weapi / eapi / eapiDecrypt（纯函数，BigInt.modPow RSA）
├── netease_client.dart    # Dio + 请求头 + 匿名 Cookie + NeteaseApiException
├── netease_api.dart       # searchSongs / songDetail / songUrl / songLyric（经 RateLimiter）
├── netease_models.dart    # NeteaseSongDto / NeteaseUrlDto / NeteaseLyricDto
├── netease_mappers.dart   # DTO → Track + neteaseSourceId + 封面 URL 归一化
└── netease_source.dart    # implements MusicSource + StreamResolver + LyricsProvider

lib/data/providers/
├── netease_providers.dart         # client / RateLimiter / api / source 装配
├── online_source_providers.dart   # onlineSourcesProvider 注册表 + onlineSearchProvider + 禁用集
└── lyrics_providers.dart          # sourceSupportsLyricsProvider + trackLyricsProvider 路由

lib/core/
├── sources/source_track_id.dart   # + NeteaseTrackId（uri = 'netease:<songId>'）
├── sources/online_source.dart     # SourceDescriptor(id, source)
├── models/lyric.dart              # Lyric / LyricLine + indexAt 二分
├── services/lyrics_provider.dart  # LyricsProvider 抽象
└── services/lrc_parser.dart       # parseLrc(String?, {translation}) 纯函数
```

**能力开关**（`SourceCapabilities`）：`search` + `streamDirect`，**不含** `login`。

**身份与编解码**：`NeteaseTrackId(songId:)` → DB 列 `<songId>`、JSON `{kind: 'netease', songId}`、缓存键 `songId.toString()`；三处编解码已收敛到 `data/codec/source_track_id_codec.dart` 唯一实现。

**注册表**：`onlineSourcesProvider` 是在线源的**唯一注册入口**（当前 `bilibili` + `netease`，按禁用集过滤）；`SearchScreen` 据其生成 `SegmentedButton<String>` 切源，搜索经 `onlineSearchProvider((sourceId, query))` 按源路由，流解析与歌词路由同样从注册表派生。
