# Bilibili 音源适配器设计

> 关联：[`architecture.md`](architecture.md) §6、§8
> 调研日期：2026-09-10（所有端点行为均为当日实测；风控策略随 IP/地区/账号变化）

---

## 1. 目标与范围

将 Bilibili 作为 Flind Player 的**主要在线音源**：从视频流中解析出音频轨并作为音乐播放。

- MVP：搜索、视频详情（含分P）、音频流解析、公开收藏夹
- v1.1：QR 登录、私有收藏夹、历史记录
- **不做**：视频画面播放、弹幕、评论

> ⚠️ **重要法律提示**：社区 API 文档仓库 `SocialSisterYi/bilibili-API-collect`（20.2k stars）已于 **2026-01-28 收到哔哩哔哩律师函，2026-01-30 永久关停并删除文档**。此前 PiliPala（2025-07 侵权通知后停更）、BBDown（2026-05 归档）、Nemo2011/bilibili-api（2026-07 归档）均受波及。本项目必须按个人使用姿态设计，并保证该音源可被远程禁用。

---

## 2. 端点清单

### 2.1 MVP

| 用途 | 端点 | 鉴权 |
|---|---|---|
| 视频详情 + 分P | `GET https://api.bilibili.com/x/web-interface/view?bvid=BV...` | UA + Referer |
| 分P 列表（轻量） | `GET /x/player/pagelist?bvid=BV...` | UA + Referer |
| 音频流 | `GET https://api.bilibili.com/x/player/wbi/playurl` | + WBI（VIP 音质需 SESSDATA） |
| 视频搜索 | `GET /x/web-interface/wbi/search/type?search_type=video&keyword=&page=` | + WBI + buvid3 |
| 用户搜索 | 同上，`search_type=bili_user` | + WBI + buvid3 |
| 风控指纹 | `GET https://api.bilibili.com/x/frontend/finger/spi` | UA |
| WBI 密钥 | `GET https://api.bilibili.com/x/web-interface/nav` | UA（未登录也可取到 key） |

### 2.2 v1.1

| 用途 | 端点 | 鉴权 |
|---|---|---|
| QR 登录-生成 | `GET https://passport.bilibili.com/x/passport-login/web/qrcode/generate` | — |
| QR 登录-轮询 | `GET .../qrcode/poll?qrcode_key=` | — |
| Cookie 刷新 | `GET .../cookie/info` → `POST .../cookie/refresh` → `POST .../confirm/refresh` | Cookie |
| 公开/私有收藏夹 | `GET /x/v3/fav/resource/list?media_id=&pn=&ps=20&platform=web` | Cookie（私有） |
| 收藏夹列表 | `GET /x/v3/fav/folder/created/list-all?up_mid=` | Cookie |
| 历史记录 | `GET /x/web-interface/history/cursor?ps=30&type=video` | SESSDATA |

### 2.3 备选

| 用途 | 端点 | 说明 |
|---|---|---|
| Bilibili 音频区（au） | `GET /audio/music-service-c/web/url?sid=&quality=2` | 原生音乐平台，`cdns[]` 为 m4a；quality 2=192K，3=无损 |

---

## 3. WBI 签名

搜索与 playurl 必需。密钥**每日轮换**，需缓存并定期刷新。

**算法：**

1. `GET /x/web-interface/nav` → `data.wbi_img.img_url` / `sub_url`，取文件名（不含扩展名）得 `img_key` / `sub_key`。未登录时 `code:-101` 但 key 仍返回。
2. `mixin_key = reorder(img_key + sub_key, MIXIN_KEY_ENC_TAB)[:32]`

   ```dart
   const mixinKeyEncTab = <int>[
     46, 47, 18,  2, 53,  8, 23, 32, 15, 50, 10, 31, 58,  3, 45, 35, 27, 43,
      5, 49, 33,  9, 42, 19, 29, 28, 14, 39, 12, 38, 41, 13, 37, 48,  7, 16,
     24, 55, 40, 61, 26, 17,  0,  1, 60, 51, 30,  4, 22, 25, 54, 21, 56, 59,
      6, 63, 57, 62, 11, 36, 20, 34, 44, 52,
   ];
   // mixin_key = mixinKeyEncTab.map((i) => (img_key + sub_key)[i]).join().substring(0, 32)
   ```

3. `w_rid = md5(sorted_query_string_with_wts + mixin_key)`；请求追加 `w_rid` 与 `wts`（unix 秒）
   - 参数值需过滤 `!'()*` 字符
   - URL 编码对齐 JS `encodeURIComponent`（大写十六进制，`%20` 而非 `+`）

**Dart 参考实现（注意许可证）：**

| 项目 | 许可证 | 链接 |
|---|---|---|
| bobomusic `sign.dart` | Apache-2.0（保留原始声明） | https://github.com/Redstone-1/bobomusic/blob/0aac7bbecd52a373cf36e34118ff6fff4a9293b6/lib/origin_sdk/bili/sign.dart#L1-L37 |
| PiliPlus `wbi_sign.dart` | GPL-3.0，**与本项目兼容，可直接复用** | https://github.com/bggRGjQaUbCoE/PiliPlus/blob/cd096d3377f3a80d17c910d732b0762f6d8588d5/lib/utils/wbi_sign.dart |
| PiliPala `wbi_sign.dart` | GPL-3.0，已归档；可直接复用 | https://github.com/guozhigq/pilipala/blob/06f23f67ca61f22db42ebabd9b979b2c2f4fa808/lib/utils/wbi_sign.dart |

---

## 4. 鉴权

### 4.1 QR 登录流程

```
1. GET  .../qrcode/generate          → data.url（渲染二维码）, data.qrcode_key（32 字符，180s 有效）
2. 轮询 .../qrcode/poll?qrcode_key=  → 每 ~2s
     code 86101 = 未扫码
     code 86090 = 已扫码未确认
     code 86038 = 已过期
     code 0     = 成功
3. 成功后 Set-Cookie: SESSDATA, bili_jct, DedeUserID, DedeUserID__ckMd5 (+sid)
   且返回 data.refresh_token —— 全部持久化
```

- `SESSDATA`：`HttpOnly; Secure`，约 6 个月有效期，**是全账号 bearer token**。

### 4.2 Cookie 刷新（v1.1）

```
1. GET  .../cookie/info?csrf=<bili_jct>     → {refresh: bool, timestamp}
2. CorrespondPath = RSA-OAEP(timestamp)      ← 公钥需从 Bilibili wasm 提取
   GET  https://www.bilibili.com/correspond/1/{correspondPath} → refresh_csrf
3. POST .../cookie/refresh?refresh_token=&csrf=  → 新 cookies + 新 refresh_token（保留旧的）
4. POST .../confirm/refresh
```

MVP 可先不做：cookie 失效时引导重新 QR 登录。

### 4.3 凭证存储

- **必须** `flutter_secure_storage`（Android Keystore / iOS Keychain / Linux libsecret）
- 反面教材：bobomusic 用 SharedPreferences、bili-music 用明文 Hive —— 不要模仿
- 凭证**永不**上传服务器；不做托管用户凭证的公共代理

---

## 5. 风控与请求头

### 5.1 请求头

```
User-Agent: Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 ... Chrome/xxx
Referer:    https://www.bilibili.com/
Cookie:     SESSDATA=...; bili_jct=...; buvid3=...; buvid4=...; b_nut=...; bili_ticket=...
```

- UA 不得含 `curl` / `python` 等敏感子串，且需较新版本
- **原生客户端不要发 `Origin`**（第三方 Origin 会被 WAF 403）
- `csrf=<bili_jct>` 仅用于有副作用的 POST（删历史、收藏操作）

### 5.2 风控令牌

| 令牌 | 获取方式 | 作用 |
|---|---|---|
| `buvid3` / `buvid4` | `GET /x/frontend/finger/spi` → `b_3` / `b_4` | 设备身份，搜索文档要求携带 |
| `b_nut` | `GET https://www.bilibili.com/` 的 Set-Cookie | 防重放时间戳 |
| `bili_ticket` | `POST /bapis/bilibili.api.ticket.v1.Ticket/GenWebTicket?key_id=ec02&hexsign=HMAC_SHA256("XgwSnGZ1p","ts"+ts)&context[ts]=...` | 非必需，但可降低风控概率；TTL 3 天 |
| `v_voucher` / `gaia_vtoken` | 遇 `code:-352` 时走 `/x/gaia-vgate/v1/register` 验证码流程 | 风控恢复的最后手段 |

---

## 6. 限流与错误码

| 错误码 | 含义 | 处理 |
|---|---|---|
| `-352` | 风控拦截（UA/WBI 异常） | 修正请求头/WBI；补 buvid3/4、bili_ticket、b_nut；反复出现走验证码 |
| `-412` | IP 被拦截 | 硬退避：**绝不立即重试**；IP 会被临时拉黑（分钟级） |
| `-509` | 请求过于频繁 | 退避 |
| `-799` | 请求过于频繁 | 退避 |
| `-101` | 未登录 | 历史/私有收藏夹的正常预期 |

**限流策略：**

- 同一主机**单飞**（单请求在途），不做并发
- 搜索类请求间隔 1–3s 抖动
- `-352` / `-412` 指数退避 2s → 4s → 8s
- 元数据激进缓存；流地址视为易失
- **无公开速率限制，按敌对环境设计**

---

## 7. 音频流解析

### 7.1 请求参数

| 参数 | 值 | 说明 |
|---|---|---|
| `bvid` / `avid` | 视频 ID | 二选一 |
| `cid` | 来自 `view.pages[].cid` | **必填**，每个分P 一个 cid |
| `fnval` | `4048` | 全部 DASH 能力（16=DASH；64=HDR；128=4K；256=Dolby；512=Dolby Vision；1024=8K；2048=AV1） |
| `fnver` | `0` | 常量 |
| `fourk` | `1` | 允许 4K |
| `qn` | 忽略 | DASH 格式下无效 |
| `platform` | `pc` | `pc`=DASH（CDN 防盗链）；`html5`=仅 MP4，防盗链较弱 |

### 7.2 音质码

| id | 含义 | 门槛（实测 + 文档） |
|---|---|---|
| 30216 | 64K | 匿名可用 |
| 30232 | 132K | 匿名可用 |
| 30280 | 192K | 实测匿名可用（3/3 视频）；社区报告有时需登录，受风控影响 |
| 30250 | Dolby Atmos | 大会员（匿名时 `dash.dolby.audio` 为 null） |
| 30251 | Hi-Res FLAC | 大会员（匿名时 `dash.flac` 为 null） |
| 30255 / 100010 等 | 空间音频等 | 可选 |

### 7.3 响应结构

```
data.dash.audio[]        → {id, baseUrl, backupUrl[], bandwidth, mimeType, codecs, size}
data.dash.dolby.audio[]  → Dolby（VIP）
data.dash.flac.audio     → Hi-Res FLAC（VIP，无则 null）
```

- 选择最高 `bandwidth`
- **必须保留 `backupUrl[]` 做 failover**
- `baseUrl` **120 分钟过期**，过期后 403 → 重新解析并 seek 回原位置

### 7.4 实测样本（2026-09-10，无 Cookie）

```
BV1GJ411x7h7  audio=[(30216,43962),(30232,102931),(30280,203786)]  dolby=null flac=null
BV1uv411q7Mv  audio=[(30216,67268),(30232,132803),(30280,315098)]  dolby=null flac=null
```

### 7.5 CDN 防盗链（实测）

| URL 类型 | 无 Referer | 带 `Referer: bilibili.com` |
|---|---|---|
| `upos-sz-mirrorcos.bilivideo.com`（backup） | 403 | 206 |
| `*.mcdn.bilivideo.cn`（baseUrl） | 206（当前宽松） | 206 |
| `upos-sz-estgoss.bilivideo.com`（html5 MP4） | 无 UA 403 / 有 UA 206 | 206 |

结论：防盗链**按 CDN 不同、且可能变化**，绝不硬编码单一 CDN；播放器必须支持自定义 HTTP 头。

### 7.6 视频封面

封面作为“音乐封面”抓取，与音频共用同一套请求头（`User-Agent` + `Referer`），
但走独立下载通道（不进 `RateLimiter` 的 API 限流）：

- **来源**：搜索 `data.result[].pic`、详情 `data.pic`、收藏夹 `data.medias[].cover`。
  DTO 已解析，`bili_mappers` 归一化后写入 `Track.coverUrl`；缺失时用
  `/x/web-interface/view?bvid=` 兜底。
- **归一化**：`normalizeCoverUrl` 处理 `//` 协议相对、`http://` 升级，并剥掉 CDN
  处理后缀（`@672w_378h_1c.webp`）后再缓存。图片 CDN 为 `*.hdslb.com`。
- **缓存**：见 [`local-library.md`](local-library.md) §3.1 与 §4，走**两层模型**——歌曲已在
  音频缓存中时封面写入**层 1 随行封面**（`cache/audio/...`，与该歌音频共享 `limitBytes`
  配额、随行同删）；歌曲未缓存时写入**层 2** `cache/cover/<sha1(字节)>.jpg`（独立固定
  256 MiB、每次启动整体清空）。内容寻址、LRU 让路。
- **多 P**：`pic` 为视频级，各分 P 共用同一封面。
- **合规**：整个抓取受 B 站音源启用开关约束；音源可远程禁用时封面同步禁用。

---

## 8. 参考项目

> 本项目采用 GPL-3.0（见 [`architecture.md`](architecture.md) §12）。下表中 GPL-3.0 项目的代码**许可兼容、可直接复用**；MIT / Apache-2.0 项目可复用，但须保留原始版权声明。

| 项目 | Stars | 许可证 | 用途 |
|---|---|---|---|
| [bili-music](https://github.com/AprDeci/bili-music) | 345 | MIT | **最接近的参考**：resolveAudioStream、音质偏好、flac、backupUrls、media_kit + audio_service |
| [bobomusic](https://github.com/Redstone-1/bobomusic) | 231 | Apache-2.0 | Dart 侧最小 playurl + WBI + bili_ticket 实现 |
| [bmsc](https://github.com/u2x1/bmsc) | 123 | Apache-2.0 | "Bilibili, but audio"；fav/search/history 常量 |
| [PiliPlus](https://github.com/bggRGjQaUbCoE/PiliPlus) | 18.2k | GPL-3.0 | 完整客户端；WBI/playurl 实现**可直接复用**（本项目同为 GPL-3.0） |
| [yt-dlp](https://github.com/yt-dlp/yt-dlp) | — | Unlicense | 提取逻辑最权威的维护者参考 |

---

## 9. Web 端（v2 推迟）

**实测 CORS 结论：**

| 请求 | 结果 |
|---|---|
| 无 `Origin` | 200 |
| `Origin: https://www.bilibili.com` | 200，ACAO 回显，Allow-Credentials: true |
| `Origin: https://flind.example.com`（即使带 bilibili Referer） | **403（openresty WAF）** |

→ Bilibili 边缘节点**阻断一切非 bilibili Origin**。Flutter Web 无法直连 API，且浏览器无法设置 Referer/User-Agent（禁止头）。**v2 方案**：仅 JSON 代理（无凭证），音频流可直连 CDN（`<audio>` 不需 CORS）。

---

## 10. 适配器组件划分

```
data/sources/bilibili/
├── bili_client.dart          # Dio + 拦截器（UA/Referer、WBI、限流、错误映射）
├── wbi_signer.dart           # nav 取 key + 重排 + md5 签名
├── bili_auth.dart            # QR 登录、cookie 保险库、刷新
├── risk_control.dart         # buvid3/4、b_nut、bili_ticket
├── rate_limiter.dart         # 单飞 + 抖动 + 指数退避
├── bili_source.dart          # implements MusicSource
└── mappers.dart              # view/fav/search → Track/Playlist
```

**能力开关**（`SourceCapabilities`）：

| 能力 | Android/Linux | Web (v2) |
|---|---|---|
| `canLogin` | 是 | 否 |
| `canSearch` | 是 | 代理后是 |
| `canStreamDirect` | 是 | 视 CDN 而定 |

---

## 11. 稳定性对策清单

1. 所有 HTTP 走**唯一**签名客户端，禁止旁路
2. WBI key 每日刷新；失败自动重取
3. 流地址缓存 `expiresAt`，403 自愈重解析
4. 音源整体可被 **feature flag 远程禁用**
5. 适配器完全隔离在 `MusicSource` 之后 —— 即便该音源下架，应用其余部分不受影响
6. 不做并发；退避策略集中实现
