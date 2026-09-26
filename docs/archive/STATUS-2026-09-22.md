# Flind Player 当前状态

> 最后更新：2026-09-22 · 分支 `master`

---

## 当前阶段：0.2.x 预览

M0–M6 全部完成。CI 与发布流水线均已实测跑通。

**签名决定（已确认）**：0.2.x 继续使用 debug 签名，正式签名推迟到 1.0。
Release 说明中已加入「各版本不支持覆盖升级」的提示。

签名配置步骤见 `README.md` 的「签名发布（Android）」章节，不再在此重复。

---

## 本轮完成

### 1. 曲库重写（schema v8：单池 + 内置收藏歌单 + 自建歌单）

曲库数据模型升级到 schema v8：

- **单池**：`tracks` 表是唯一曲库池，`uri`（`bilibili:<bvid>:<cid>` / `local:<绝对路径>`）仍是规范键；
  `content_hash` 列**只建未填**，为后续去重 / 稳定标识预留。
- **收藏 = 内置歌单**：`playlists` 表 `kind='favorites'` 的行（id 固定 1，不可删除/改名）；
  旧 `favorites` 表移除，其数据在 v7→v8 迁移中并入 `playlist_tracks`（`favorited_at` → `added_at`）。
- **自建歌单**：创建 / 改名 / 封面 / 简介 / 增删歌曲；成员 = `uri` 引用 + 元数据快照，
  读取 LEFT JOIN 池并 COALESCE（池优先、快照回落），歌曲离开曲库后仍可存活；
  歌单封面读取时派生（自定义 → 最新成员封面 → 默认）。
- **三段式曲库页**：曲库页分成 全部 / 收藏 / 歌单 三段，收藏为置顶强调行；
  新增歌单详情页、歌单编辑器对话框、加入歌单选择器与统一的行内操作菜单。
- `FavoritesRepository` 7 方法接口保持不变，改为薄适配器（转发到内置收藏歌单），
  播放器爱心按钮与既有测试不受影响。

### 2. 封面按显示尺寸解码（内存降约 12 倍）

此前三处封面渲染（曲库列表/网格、迷你播放器、播放器页）都用裸的 `Image.file`
且未指定 `cacheWidth`，每张封面都按缓存文件的 512×512 全尺寸解码（约 1.05 MB），
而列表行只显示 48 逻辑像素。Flutter 的 `ImageCache` 默认上限 100 MiB，
大曲库滚动时会不断「逐出 + 重新解码」，造成内存压力与卡顿。

改为统一使用 `lib/shared/cover_image.dart` 的 `CoverImage`：

- 解码宽度 = 逻辑尺寸 × `devicePixelRatio`（物理像素）
- 只传 `cacheWidth`，不传 `cacheHeight`；宽高比由引擎保持
  （已用真实解码器验证：200×100 源 + `width: 100` → 解码为 100×50）
- 网格卡片的 `double.infinity` 场景用 `LayoutBuilder` 从约束推导，
  非有限约束回退到 512
- Flutter 默认 `allowUpscaling = false`，播放器页在 3x 屏请求 960px 时
  不会放大 512px 源，无回归

列表行单张内存：1.05 MB → 约 83 KB（48px @3x）。纯解码尺寸改动，布局与视觉
不变（网格卡的 `Stack` tight 约束下新旧都收敛到卡片宽度）。新增 3 个组件测试
断言 `ResizeImage.width == 逻辑尺寸 × DPR`。

### 3. APK 按架构拆分（体积降约 60%）

`release.yml` 只产出分架构 APK 与 AAB，**不再构建 / 发布通用包**。本地实测：

| 产物 | 体积 |
| --- | --- |
| `app-arm64-v8a-release.apk` | **30.7 MB** |
| `app-armeabi-v7a-release.apk` | **28.5 MB** |
| `app-x86_64-release.apk` | 32.2 MB |

发布时提供 arm64-v8a 与 armeabi-v7a 两种（x86_64 仅供模拟器，不发布）。

> 后续计划：pre 版尝试加入 Windows 安装包。

### 4. 加固密钥防泄漏

`git check-ignore` 确认 `android/.gitignore` 已覆盖 `key.properties`、
`**/*.jks`、`**/*.keystore`。根 `.gitignore` 追加 `*.jks` / `*.keystore` /
`key.properties` 作为防御层，避免密钥放在仓库根目录时被误提交。

### 5. 文档更新

- `README.md`：新增分架构构建说明、0.1.x 签名提示、图标流水线说明；
  修正已过期的 Status 段落（原写「Next milestone: M0」）与「图标占位」说明。

---

## 本轮之前的完成项

| 项 | 提交 |
| --- | --- |
| 图标流水线 + 全平台资产 | `cfdc0b2` |
| 修复托盘图标浅色面板不可见 | `cfdc0b2` |
| CI/release action 升级 + 加 AAB | `9995546` |

release 工作流曾用临时 tag `v0.0.0-citest` 端到端实测：三个 job 全通过，
产出 Linux 12.91 MB / APK 71.71 MB / AAB 68.62 MB，验证后已清理。

---

## 已搁置：多分P 视频播放（用户选择先不做）

**决定**：暂不实现，留待后续版本。以下记录问题与备选方案，便于将来接手。

**问题**：`favoriteResourceToTrack` 与 `searchItemToTrack` 都以 `biliUnknownCid = -1`
占位；`BiliSource.resolveStream` 拿到 `-1` 时调用 `videoInfo` 并**固定取第一页**。
因此多分P 视频只有 P1 可播，P2..Pn 无法访问。

**方案 A：分P 选择器**

点击多分P 条目时拉取一次 `videoInfo`，弹出选择器让用户选分P，并可「从该分P开始
连续播放全部」。

- 成本：1 次请求（按需）
- 需新增：选择器 UI + 播放流程分支
- 不增加收藏夹列表加载耗时

**方案 B：加载列表时自动展开**

加载收藏夹时对每个条目调用 `videoInfo`，把多分P 视频展开成多条 track。

- 成本：每页 20 个条目 = 20 次额外请求
- 风险：显著拖慢列表加载，并可能触发 Bilibili 风控（见 `docs/bilibili-source.md`）
- 优点：所有分P 直接可见可播

---

## 平台构建现状

| 平台 | 产物 |
| --- | --- |
| Android | 分架构 APK + AAB（debug 签名） |
| Linux | release bundle（需系统 libmpv） |
| Windows | release zip（内置 mpv） |
| macOS | **未签名** arm64 zip（Apple Silicon；保留沙盒，仅加网络权限；需去隔离） |
| iOS | **未签名** IPA（自签安装；本地曲库已隐藏） |

Apple 平台为非主推，**长期不做签名 / 公证 / TestFlight**；iOS 沙盒下无文件系统根，暂不提供本地曲库。

---

## 其他候选（未开始）

- Android 目录扫描：唯一代码 TODO；需真机验证，设备按约定保持未授权
- 无障碍：语义标签基本未做

---

## 已知延后

歌词（未排期）、QR 登录与个人收藏夹（v1.1）、Web 端（v2）、Apple 平台的签名 / 公证 / TestFlight（长期推迟）。

---

## 验证基线

`flutter analyze` 0 问题 · **581** 个单测/组件测试通过 · 6 个集成测试通过 ·
Linux/Android release 构建通过 · CI 与 release 工作流均实测跑通。
