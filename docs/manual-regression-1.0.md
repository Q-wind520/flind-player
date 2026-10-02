# Flind Player 1.0 手工回归基线

> 状态：基线已建立（2026-10-02），执行结果待维护者逐项勾选
> 对应设计：`docs/spec-1.0-hardening-2026-10-02.md` · 计划：`docs/plan-1.0-hardening-2026-10-02.md`

`integration_test/` **不在 CI 门禁内**，需在真机 / 桌面上手动执行。以下为发布前必跑项。

## 自动化冒烟

- [ ] `flutter test integration_test`（记录通过数；目录下共 8 个文件、11 个用例）。

覆盖：`bilibili_smoke_test`、`netease_smoke_test`、`playback_smoke_test`、`persistence_smoke_test`、
`offline_cache_smoke_test`、`library_sync_smoke_test`、`cover_rendering_smoke_test`、`mpris_smoke_test`。
其中 Bilibili / 网易云用例依赖网络，离线环境会失败——属环境限制，非回归。

## 手工场景

- [ ] **缓存极限淘汰**：把缓存上限调到最小，播放/下载若干曲目，确认 LRU 生效、pinned 不被淘汰、无崩溃。
- [ ] **流过期自愈**：播放 Bilibili 曲目至 token 失效（或模拟 403），确认自动刷新并回到原进度。
- [ ] **断网启动**：断网启动，已缓存曲目可播放；未缓存曲目给出可理解的失败而非崩溃。
- [ ] **覆盖升级数据保留**：在**同一签名**内升级，确认曲库索引、收藏、队列、离线缓存保留。
- [ ] **清空离线缓存失败路径**：模拟删除失败，确认显示「清空离线缓存失败。」而非「已释放」（M5）。
- [ ] **离线列表可读性**：确认列表与删除确认框显示歌名而非裸 `sourceTrackId`（M6）。
- [ ] **删除确认弹窗**：四条删除动作（删单条 / 清空离线 / 清空缓存 / 删扫描根）文案一致、可取消（M7）。
- [ ] **旧层 2 目录清理**：从旧版本升级启动后，确认旧的 `cover_cache/` 目录被删除（M8）。

## 平台矩阵

- [ ] Linux 桌面、Android 真机、Windows 桌面各跑一遍主流程。
- [ ] macOS / iOS 至少各确认一次构建产物可启动（未签名，见 README 说明）。
