# Agent 模型指派策略

> 固化于 2026-09-26。适用于本项目中使用子智能体（subagent）协作的所有会话。

## 能力层级（由高到低）

| 层级 | 模型 ID | 说明 |
|---|---|---|
| 顶层 | `openrouter/~deepseek/deepseek-flash-latest` | 本项目最高能力模型；主智能体默认使用，由项目主人授予 |
| 次高 | `openrouter/xiaomi/mimo-v2.6-flash` | 付费，**1M 上下文**；大工作量时使用 |
| 次高（同能力免费版） | `opencode/mimo-v2.6-flash-free` | 与上者能力等同，$0；上下文较小时用 |
| 中 | `opencode/big-pickle` | $0；与 mimo-flash 基本同档，可互换；背后真实模型未知 |
| 最低 | `openrouter/openrouter/free` | $0 免费路由，能力未知；每日约 1000 次 |

能力共识：`deepseek-flash-latest > mimo-v2.6-flash ≈ big-pickle`。价格不等于能力，不据此推断强弱。

**ID 更正**：`openrouter/mimo-v2.6-flash` 的精确 ID 是 `openrouter/xiaomi/mimo-v2.6-flash`。

## 指派规则

1. **主智能体**负责中高风险 / 高难度问题；其模型能力由项目主人授予（默认顶层）。
2. **子智能体**负责中低风险 / 中低难度问题；按**难度等级 + 工作量**授予模型：
   - 中风险、集成、多文件、大工作量 → `openrouter/xiaomi/mimo-v2.6-flash`（需 1M 上下文时）或 `opencode/mimo-v2.6-flash-free`。
   - 机械转录（计划已含完整代码）、单文件小改 → `opencode/big-pickle`（可与 mimo-flash 互换）。
   - 文档 / 注释 / 极小改 → `openrouter/openrouter/free`。
3. **审阅者模型不得低于实现者**（否则漏检）。按 diff 大小在同一档或更高一档选择。
4. **最终整分支复审**允许使用顶层模型；项目主人是最终验收人。
5. **兜底**：任一子模型派发报错，回退到 `openrouter/~deepseek/deepseek-flash-latest`。
6. 同形小任务**批处理**为一次派发；低风险计划优先使用 **Native** 执行以减少派发次数。
7. 免费端点有每日调用上限，需据此控制派发量。

## 验证记录（2026-09-26）

- 子智能体通道 + 工具循环（写探针文件）四档全部通过：
  `openrouter/xiaomi/mimo-v2.6-flash`、`opencode/mimo-v2.6-flash-free`、`opencode/big-pickle`、`openrouter/openrouter/free`。
- 端到端 TDD 校准（`opencode/big-pickle`，scratch 目录）：RED `Method not found: 'add'` → GREEN `PASS`，独立复跑通过。
- 免费模型经确认可用（此前判为“不可用”是误判，实为所探模型恰在区域/账号排除名单内）。
