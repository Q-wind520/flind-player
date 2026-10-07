<div align="center">

<img src="docs/FlindPlayer.png" alt="Flind Player" width="128" />

# Flind Player

**跨平台音乐播放器 · 让 Bilibili 走进你的曲库**

在线音源（Bilibili / 网易云）与本地曲库在统一界面中无缝混合 —— 搜索即播、离线可听、全平台系统集成。

<br />

<img src="https://img.shields.io/badge/version-1.1.0-2ea44f" />
<img src="https://img.shields.io/badge/license-GPL--3.0-red" />
<img src="https://img.shields.io/badge/Flutter-3.47-02569B?logo=flutter&logoColor=white" />
<img src="https://img.shields.io/badge/platform-Android%20%7C%20Linux%20%7C%20Windows%20%7C%20macOS%20%7C%20iOS-purple" />
<img src="https://img.shields.io/badge/tests-850%20passing-brightgreen" />
<img src="https://img.shields.io/badge/Made%20with-Dart-0175C2?logo=dart&logoColor=white" />

</div>

<br />

Flind Player 是一款开源的跨平台音乐播放器：以 Bilibili 为主在线音源，另支持网易云音乐（匿名），并与本地音乐库在同一个界面中混合管理。桌面（Linux / Windows / macOS）与移动（Android / iOS）自适应，支持离线缓存、同步歌词与系统级媒体控制。

> ⚠️ 本项目仅供个人学习使用：不内置任何账号凭证，也不提供带凭证的公共代理。

## 📖 目录

- [功能特性](#-功能特性)
- [支持平台](#-支持平台)
- [下载与安装](#-下载与安装)
- [常见问题](#-常见问题)
- [参与开发](#-参与开发)
- [许可证](#-许可证)

## ✨ 功能特性

<table align="center">
  <tr>
    <td width="50%" valign="top">
      <h4>🎧 Bilibili 在线音源</h4>
      <p>WBI 签名 API 直连，防盗链 CDN 播放（自动注入 Referer / UA）；直播流过期（403）自动刷新并跳回原进度，边听边播不中断。被收录曲目可一键离线缓存。</p>
    </td>
    <td width="50%" valign="top">
      <h4>🎵 网易云音乐音源</h4>
      <p>匿名接入第二个在线音源：搜索、播放与歌词，与 Bilibili 在搜索页一键切换；不内置任何账号凭证。</p>
    </td>
  </tr>
  <tr>
    <td width="50%" valign="top">
      <h4>📚 统一曲库</h4>
      <p>在线与本地在同一个曲库中混合呈现，可搜索、排序、收藏。本地扫描基于 <code>audio_metadata_reader</code> 纯 Dart 解析，3392 首曲目不到 200ms。</p>
    </td>
    <td width="50%" valign="top">
      <h4>💾 离线缓存</h4>
      <p>Bilibili 音频缓存到本地，默认 <strong>1 GiB</strong> 可配置，LRU 自动淘汰；手动下载的曲目 <strong>pinned 固定</strong>，断网也能播放。</p>
    </td>
  </tr>
  <tr>
    <td width="50%" valign="top">
      <h4>🎤 同步歌词</h4>
      <p>整行时间轴高亮、自动滚动，支持原文 + 翻译双语显示；无歌词来源时优雅回落占位。</p>
    </td>
    <td width="50%" valign="top">
      <h4>🔁 队列与收藏</h4>
      <p>播放队列（含洗牌前顺序）自动持久化，重启后恢复（默认暂停，不打扰）；本地收藏 + 自建歌单（创建 / 改名 / 封面 / 简介 / 增删歌曲）+ 浏览 Bilibili 公开收藏夹。</p>
    </td>
  </tr>
  <tr>
    <td width="50%" valign="top">
      <h4>🔌 深度系统集成</h4>
      <p>Android 通知栏 / 锁屏媒体控制、Linux MPRIS²、macOS/iOS Now Playing 统一由 <code>audio_service</code> 承载；桌面端托盘 + 关闭到托盘。</p>
    </td>
    <td width="50%" valign="top">
      <h4>🖥️ 自适应 Material 3</h4>
      <p>窄屏底部导航、宽屏侧边导航自动切换；亮 / 暗 / 跟随系统主题；迷你播放条、播放模式（单曲 / 列表 / 随机）、睡眠定时。</p>
    </td>
  </tr>
</table>

## 🖥️ 支持平台

| 平台 | 优先级 | 说明 |
| -------- | -------- | ----- |
| Android | 主推 | 分架构 APK + AAB；本地曲库延后（1.1） |
| Linux | 主推 | deb / rpm / AppImage / tar.gz；deb/rpm 需要系统 `libmpv` |
| Windows | 次要 | `setup.exe` 安装器或免安装 zip，均已内置 mpv 与 VC++ 运行时 |
| macOS | 次要 | **未签名**预览（Apple Silicon / arm64，保留沙盒，仅加网络权限） |
| iOS | 次要 | **未签名**预览，需自行签名安装；暂不支持本地曲库 |
| Web | 延后 (v2) | CORS 全阻断，需代理 |

## ⬇️ 下载与安装

从 [Releases](https://github.com/Q-wind520/flind-player/releases) 选择对应产物：

| 系统 | 推荐产物 | 安装 |
| --- | --- | ----- |
| Debian / Ubuntu | `FlindPlayer-<tag>-linux-x64.deb` | `sudo apt install ./FlindPlayer-<tag>-linux-x64.deb` |
| Fedora / RHEL | `FlindPlayer-<tag>-linux-x64.rpm` | `sudo dnf install ./FlindPlayer-<tag>-linux-x64.rpm` |
| 任意 Linux | `FlindPlayer-<tag>-linux-x64.AppImage` | `chmod +x FlindPlayer-<tag>-linux-x64.AppImage && ./FlindPlayer-<tag>-linux-x64.AppImage` |
| Windows 10/11 x64 | `FlindPlayer-<tag>-windows-x64-setup.exe` | 双击运行（可选「仅我」安装，无需管理员） |
| Android（现代手机） | `FlindPlayer-<tag>-arm64-v8a.apk` | 直接安装（需允许安装未知来源） |
| Android（32 位老设备） | `FlindPlayer-<tag>-armeabi-v7a.apk` | 同上 |
| macOS（Apple Silicon） | `FlindPlayer-<tag>-macos-arm64.zip` | 解压后见下方「macOS 打不开」 |
| iOS | `FlindPlayer-<tag>-ios-unsigned.ipa` | 需自行签名安装 |

### 系统要求

- **Linux**：deb/rpm 需要系统提供 `libmpv.so.2`（Ubuntu 24.04+ / Debian 12+ / Fedora 39+ 一类）；AppImage 自带 libmpv/FFmpeg，但需要系统 GTK3 与 FUSE（若提示 `libfuse2` 缺失，用 `APPIMAGE_EXTRACT_AND_RUN=1 ./FlindPlayer-….AppImage` 运行）。
- **Windows**：Windows 10/11 x64；安装器已内置 mpv 与 VC++ 运行时。
- **Android**：Android 8+；不发布 x86_64（仅模拟器用）。
- **macOS / iOS**：未签名预览，详见常见问题。

### 数据与卸载

本地曲库索引、收藏、队列与离线缓存在应用数据目录中，卸载方式决定是否保留：

- Linux：`~/.local/share/top.qwind.app.flind_player/` —— 用 deb/rpm 卸载或删除 zip/AppImage **不会**删除这些数据。
- Windows：`%APPDATA%` 下的应用目录 —— 同理，删除程序目录不删除数据。
- Android：卸载应用会**清除**应用数据（曲库索引、收藏、队列、离线缓存）。

## ❓ 常见问题

<details>
<summary><b>我该下载哪个文件？</b></summary>

- Android 现代手机选 `arm64-v8a.apk`；很老的 32 位设备选 `armeabi-v7a.apk`。需要上架 Google Play 时可参考 `.aab`（普通用户用不上）。
- Linux 首选发行版安装包（deb / rpm），或免安装的 AppImage / tar.gz。
- Windows 用 `setup.exe`（可选「仅我」安装）或免安装 zip。
- macOS 用 `macos-arm64.zip`；iOS 用 `ios-unsigned.ipa`（需自签）。

</details>

<details>
<summary><b>需要登录账号吗？</b></summary>

不需要。两个在线音源均为**匿名**访问，不内置也不保存任何账号凭证（SESSDATA / MUSIC_U 等）。因此部分需要登录的内容（更高音质、个人收藏夹等）不可用，二维码登录计划在后续版本提供。

</details>

<details>
<summary><b>macOS 提示「已损坏」或「无法验证开发者」怎么办？</b></summary>

macOS / iOS 是**未签名预览版**。macOS 解压后先移除隔离属性再打开：

```bash
xattr -dr com.apple.quarantine "Flind Player.app"
```

iOS 的 `.ipa` 需要用 AltStore / Sideloadly 等工具，以你自己的证书签名后安装。

</details>

<details>
<summary><b>Windows 为什么没有系统媒体控制（SMTC）？</b></summary>

当前 Windows 端提供系统托盘与关闭到托盘，但未接入 SMTC 等 OS 级媒体控制（需要额外插件，计划在后续版本评估）。Android / Linux / Apple 平台的媒体控制不受影响。

</details>

<details>
<summary><b>Linux 上没有声音 / 提示缺少库？</b></summary>

deb / rpm 依赖系统的 `libmpv.so.2`，请安装发行版提供的 mpv 库（如 Debian/Ubuntu 的 `libmpv2`、Fedora 的 `mpv-libs`）。AppImage 自带播放库，但需要系统 GTK3 与 FUSE。

</details>

<details>
<summary><b>1.0 之前安装过预览版，怎么升级？</b></summary>

1.0 起使用正式签名，与 0.1–0.7 预览版的 debug 签名不兼容，**不能覆盖安装**：请先卸载旧预览版再安装 1.0。卸载不会删除 Linux/Windows 的本地数据，但 Android 上卸载会清除应用数据。此后的正式版本之间可直接覆盖升级。

</details>

<details>
<summary><b>这个项目合法吗？</b></summary>

本项目仅供个人学习与研究使用：不内置任何账号凭证，不提供带凭证的公共代理，在线音源可被远程禁用。请遵守各平台的服务条款，并自行承担使用风险。

</details>

## 🛠️ 参与开发

构建、签名发布、CI、测试基线、图标管线、代码结构与文档索引等开发者内容，统一放在 **[`CONTRIBUTING.md`](CONTRIBUTING.md)**。

快速起步：`flutter pub get && flutter run -d linux`（Linux 桌面需系统 `libmpv`，完整依赖见 CONTRIBUTING）。

## 📄 许可证

[**GNU General Public License v3.0**](LICENSE) — 强 copyleft，分发时必须同时提供完整对应源码（GPL-3.0 §6）。个人使用不受此约束。
