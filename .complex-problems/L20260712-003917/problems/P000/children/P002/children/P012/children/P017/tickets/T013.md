# Round 2C2 底稿生命周期与决策静态检查方案

## Problem Definition

历史 PRD、Blueprint 和分析文档仍以独立正式文档的外观存在，协作者可能绕过 V4 使用旧优先级或未经代码审计的判断。决策登记册和 Product Spec 也缺少持续防回归检查。

## Proposed Solution

1. 在四份源文档标题后加入结构化 lifecycle banner，说明当前状态、可用范围、禁用范围、V4 权威和变更说明。
2. 当前先标记为 V4 工作输入/历史方向/静态分析，Round 5 定稿时再统一改为 `SUPERSEDED_BY_V4`，保留正文作为来源证据。
3. 新增 Product V4 文档检查脚本，核验 36 FR、21 conflict、32 decision、状态枚举、CONFIRMED 唯一性、核心标签和四份 banner。
4. 将 evidence matrix 现有检查继续作为独立事实检查，不合并到难以定位的大脚本。

## Acceptance Criteria

- 四份文档均说明不是最终执行依据并链接 Product Spec、矩阵和决策登记册。
- 历史正文关键标题仍存在，banner 明确属于 2026-07-12 Task 27 更新。
- 新脚本能够在缺 FR、冲突、决策字段或 banner 时失败。
- 当前文档全量检查和 `git diff --check` 通过。

## Verification Plan

1. 运行新脚本。
2. 运行现有 evidence matrix check。
3. 搜索四份文档 banner 与 V4 链接。
4. 运行 `git diff --check`。

## Risks

- 在 V4 尚未定稿时过早称旧文档完全作废。
- 静态检查只数 ID，不检查语义质量。
- banner 插入破坏原始版本可追溯性。

## Assumptions

- 原始附件仍可在会话附件或 Git 首次提交历史中追溯；本轮不删正文。
- Round 5 会把 lifecycle 从 working input 更新为最终 superseded 状态。
