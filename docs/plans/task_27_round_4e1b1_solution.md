# 由权威文档确定性生成完整追踪矩阵

## Problem Definition

手工复制36+41+22+12+13+115行会快速漂移，且容易把FR出现、DR开放或finding响应误写成完成。矩阵必须能由当前权威源重建，同时保留少量明确的primary/deferred/rejected关系。

## Proposed Solution

新增生成器：解析证据矩阵FR事实、决策登记册DR状态、评审响应finding/CR/package映射及roadmap package/WI字段；使用固定36项primary FR映射、DR缺引用fallback治理目标和package owner角色配置，生成一份包含六类注册表及115行WI反向索引的Markdown快照。重复运行应字节一致，任何finding/package无包内WI下钻立即失败。

## Acceptance Criteria

- 生成文档六类集合数量精确为36/41/22/12/13/115。
- 每个FR有primary/deferred关系、supporting WIs、当前成熟度/暴露/门，且无PROD_VERIFIED。
- 每个DR状态与登记册一致并有关系/目标；Rejected和External不伪装实施。
- 每个finding有恰一CR、声明package及至少一个包内WI下钻。
- 每个WI有父package、FR/DR/finding/CR反向引用、owner角色、lifecycle/decision/ceiling/gates。
- 生成器重复执行不产生diff。

## Verification Plan

运行生成器两次并比较hash/diff；检查各section行数、FR primary目标存在且引用该FR、finding/package下钻无空；运行canonical checker、全部Product V4 checks和diff gate。

## Risks

- 自动抽取会继承roadmap shorthand；生成器必须展开DR/finding/CR组合并由P077独立复算。
- owner角色不等于已分配执行人，必须保留`UNASSIGNED`。

## Assumptions

- 生成文档是可读快照，权威仍为Product Spec/证据矩阵/登记册/评审响应/roadmap。
- FR primary映射用于交付责任，不代表supporting WI可删除或已完成。
