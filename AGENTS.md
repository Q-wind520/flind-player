# AGENTS.md — Flind Player

## 文档约定

`docs/` 只放**当前仍然有效的参考文档**：架构、打包、Widget 树、音源与曲库设计、
已知延期项，以及 README / 图标工具依赖的品牌图。新增或更新参考文档时同步
[`CONTRIBUTING.md`](CONTRIBUTING.md) 的「文档索引」。

设计规格（spec）与实施计划（plan）是工作产物，**不要写进 `docs/`**：

- 进行中的工作：写到主 checkout 的 `.superpowers/specs/` 与 `.superpowers/plans/`
  （两者都在 `.gitignore` 中，不随仓库分发）。
- 已完成的工作：移到 `.superpowers/archive/`。仓库不再跟踪，历史记录留在 git 提交里。
- 在 worktree 中工作时，先运行
  `git rev-parse --path-format=absolute --git-common-dir` 找到主 checkout（取其父目录），
  把文档写到那里的 `.superpowers/`，这样 worktree 删除后文档不会丢。

## 代码约定

架构分层与测试门禁见 [`CONTRIBUTING.md`](CONTRIBUTING.md) 与
[`docs/architecture.md`](docs/architecture.md)：`features/` 只依赖 `core/` 接口，
不 import 具体实现、数据库或播放引擎。
