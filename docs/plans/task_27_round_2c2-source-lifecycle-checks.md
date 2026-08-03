# Round 2C2：底稿生命周期与决策静态检查

## Problem

四份源 PRD/Blueprint/分析文档没有统一状态和 V4 引用，且登记册若无静态检查容易漏冲突、非法状态或被后续修改破坏。

## Success Criteria

- 四份底稿顶部均有 lifecycle banner、可用/不可用范围、V4 链接和变更说明。
- 保留历史正文，不把 banner 修订伪装成原始版本内容。
- 新增脚本核验 C-01..C-21、状态枚举、关键决策字段、36 FR 和四份 banner。
- Product Spec、证据矩阵、决策登记册和源文档相互链接。
- `git diff --check` 和文档静态检查通过。
- 该问题属于 T011，因为它负责让产品权威迁移可持续且可机械验证。
