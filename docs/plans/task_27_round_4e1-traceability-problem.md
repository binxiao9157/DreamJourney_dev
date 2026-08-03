# Round 4E1：FR/DR/Finding/Risk/Package/Work Item 双向追踪

## Problem

五份V4成果物已有36 FR、41 DR、22独立评审finding、12 canonical risk、13 package和大量Work Item，但缺一个可机器验证的双向追踪Authority，无法证明无遗漏、无孤儿任务或开放决定未被误关。

## Success Criteria

- 新增唯一追踪矩阵，覆盖精确36 FR、41 DR、22 finding、12 CR、13 package和全部Work Item。
- 每行含source/current maturity/decision status/primary package/work items/gates/evidence/next action；多对多关系仍有primary owner。
- 所有Work Item反向至少映射一个FR/DR/finding/CR或明确架构/迁移必要性，禁止无需求重构。
- `RECOMMENDED_PENDING/EXTERNAL_REQUIRED/open`及G2–G4保持未关闭，路线存在不改变状态。
- 新增追踪checker验证集合、顺序、双向覆盖、状态和孤儿引用。
