# 封面查看与下载（A）设计

- 日期：2026-10-09
- 状态：待评审
- 前置：无（独立于「手势与动画（B）」）

## 1. 背景与目标

播放页封面目前只可观看，无法查看原图或下载。本轮为 **PlayerScreen 的封面**加入：

- **右键（桌面）/ 长按（触摸）封面** → 打开**全屏「原图查看器」**：可缩放/平移浏览**全分辨率原图**。
- 查看器内一个**统一按钮「下载封面图」**：桌面端保存为本地文件，移动端存入系统相册。

### 关键事实（已勘察）

- **在线封面 URL 已是原图**：NetEase / B 站的 `coverUrl` 入库时已剥掉尺寸后缀（`?param=` / `@672w_378h_1c`），拉取即为全分辨率原图。
- **本地封面缓存也是原图**：`ArtworkCache` 将内嵌图**按原样**存盘（“original quality is preserved”）；此前所说的 512px 只是显示解码尺寸，非缓存文件本身。
- 因此**无需重新解析音频**，原图两条路径都直接可得。

## 2. 范围

### 2.1 本轮做

1. PlayerScreen 封面新增 右键/长按 手势 → 打开查看器。
2. 原图解析：在线抓 `coverUrl`，本地读 `coverPath`，均可回退、可空。
3. 新增全屏 `CoverViewerScreen`（缩放/平移、关闭、加载/错误态）。
4. 保存接缝 `CoverSaver`：移动端存相册（`gal`）、桌面端保存到本地文件（`file_picker`）。
5. 统一按钮「下载封面图」+ 结果提示（SnackBar）。

### 2.2 本轮不做

- 列表封面、迷你条封面的查看/下载入口。
- 相册在桌面端的模拟（桌面端无相册）。
- 第三方图片查看器包。
- 手势与动画（属于子项目 B）。

## 3. 设计

### 3.1 入口

- `_PlayerCover`（`lib/features/player/player_screen.dart`）外包 `GestureDetector`：
  - `onSecondaryTap` → 桌面右键；
  - `onLongPress` → 触摸长按；
  - 两者都用淡入路由推入 `CoverViewerScreen(track)`。
- 封面当前无点击行为，新增手势不冲突。

### 3.2 原图解析 `CoverOriginalResolver`

```dart
class CoverOriginal {
  final Uint8List bytes;
  final String mimeType;         // 由来源推断，如 image/jpeg
  final String suggestedName;    // 如 "Artist - Title.jpg"（已清洗非法字符）
}

abstract class CoverOriginalResolver {
  Future<CoverOriginal?> resolve(Track track);
}
```

解析顺序：

1. `track.coverUrl` 非空 → 用现有 HTTP 客户端 + `coverHeadersFor(uri)` 下载其字节（原图）；MIME 取响应头或按扩展推断。
2. 否则 `track.coverPath` 非空 → 直接读取该文件字节（本地原图 / 在线最佳可用）；MIME 按扩展推断。
3. 都无 → 返回 `null`。

- 结果只在内存缓存（按 `track.uri`），不落盘。
- HTTP 客户端可注入，便于测试。

### 3.3 查看器 `CoverViewerScreen`

- 新增全屏路由 `CoverViewerScreen({required Track track})`：
  - 背景：深色 scrim（`Colors.black` 或 `scheme.scrim`）。
  - `InteractiveViewer`（`minScale ≤ 1`，`maxScale` 放大），支持双击缩放、捏合/滚轮缩放、平移。
  - 关闭：点图片外空白、系统返回键、桌面 Esc；转场为淡入/淡出。
  - 顶部操作条：左「关闭」，右「下载封面图」按钮（原图未就绪时禁用）。
- 状态机：
  - **加载中**：居中进度指示；
  - **成功**：显示原图；
  - **失败 / `null`**：提示「无法获取原图」，并回退显示当前封面（`CoverImage`）或占位；下载按钮禁用。

### 3.4 保存接缝 `CoverSaver`

```dart
enum CoverSaveResult { saved, cancelled, failed }

abstract class CoverSaver {
  Future<CoverSaveResult> save(CoverOriginal original);
}
```

按平台选择实现（`Provider` 注入，测试可替换）：

- **移动端（Android / iOS）** → `AlbumCoverSaver`：用 `gal` 请求权限并 `putImageBytes`，存入相册。
- **桌面端（Linux / Windows / macOS）** → `FileCoverSaver`：用 `FilePicker.saveFile(fileName: original.suggestedName)` 取路径后写入字节。

反馈：`saved` → SnackBar「已保存」；`cancelled` → 静默；`failed` → SnackBar「保存失败」。

### 3.5 依赖

- **新增 `gal`**（仅移动端相册；桌面端不触发）。
- 复用现有 `file_picker`、HTTP 客户端、`coverHeadersFor`。

### 3.6 交互与边界

- 原图未就绪（加载中）时点击「下载封面图」无效（按钮禁用）。
- 保存过程中重复点击应被忽略或串行化。
- 关闭查看器时，若下载仍在进行，应可取消（丢弃结果，不写盘/不入相册）。

## 4. 架构与影响

- **新增**：`lib/features/player/cover_viewer_screen.dart`（查看器）、`CoverOriginalResolver` 相关文件、`CoverSaver` 相关文件。
- **修改**：`lib/features/player/player_screen.dart`（封面手势入口）、`pubspec.yaml`（`gal`）、本地化文案（按钮/提示）。
- 无数据层改动。

## 5. 错误处理

- 网络失败 / 404 / 本地文件缺失 → 解析返回 `null` 或抛错并被查看器捕获 → 回退显示 + 禁用下载。
- 相册权限被拒 → `failed` 并提示（不崩溃）。
- 保存写盘失败 → `failed` 并提示。

## 6. 测试策略

- **`CoverOriginalResolver`**：注入假 fetcher / 临时文件 → 在线命中原图、本地命中原图、都无 → `null`、网络失败 → `null`。
- **`CoverSaver` 平台分流**：给定平台 → 选中 `AlbumCoverSaver` / `FileCoverSaver`；`coverSaverProvider` 可被覆盖。
- **保存逻辑**：用假 `CoverSaver` 断言按钮触发调用与结果提示。
- **`CoverViewerScreen`**：加载中→成功显示图片；失败/`null`→回退提示且按钮禁用。
- **入口**：对 `_PlayerCover` 长按 / 右键 → 打开 `CoverViewerScreen`。
- **回归**：`flutter analyze` 干净 + 全量测试绿。

## 7. 验收标准

- `flutter analyze` 无问题；全量测试通过。
- PlayerScreen 封面上右键/长按可打开全屏原图查看器，可缩放/平移浏览全分辨率原图。
- 「下载封面图」：桌面端弹出保存对话框并成功写出图片文件；移动端写入系统相册。
- 原图不可用时，查看器优雅回退并禁用下载。
- 列表封面、迷你条封面行为不变。

## 8. 风险与取舍

- **在线原图可能较大**：需展示进度并允许取消；失败回退。
- **`gal` 在 Linux 不可用/不可测**：桌面端不触发相册路径，移动端相册逻辑以接口隔离、桌面仅做单元级验证。
- **`file_picker.saveFile` 在各桌面平台行为略有差异**：以系统对话框为准，失败要提示。
- **封面手势与 Hero/后续 B 手势**：查看器使用独立路由，不复用播放页封面 Hero，避免与 B 的手势相互影响。

## 9. 后续

- 手势与动画（子项目 B）。
- 接入更多来源时的「原图 URL 推导」（若将来某来源的 `coverUrl` 带尺寸参数）。
