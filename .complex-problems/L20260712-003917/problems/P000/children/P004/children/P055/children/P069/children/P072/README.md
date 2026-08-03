# Round 4E1B：建立V4双向追踪矩阵与Checker

## Problem

Work Item集合稳定后，需要把36 FR、41 DR、22 finding、12 CR、13 package与全部Work Item建立双向索引，并确保Deferred/Open/External状态不会被路线存在误关。

## Success Criteria

- 新增V4路线追踪矩阵，精确覆盖六类集合并给出primary owner/gate/current state/next action。
- Stage4 FR使用`DEFERRED_BY_GATE`并说明激活门，不伪造当前WI；其他FR有具体WI或明确外部门。
- 每个WI反向有FR/DR/finding/CR或显式架构/迁移必要性，无孤儿任务。
- 新增traceability checker验证数量、顺序、双向覆盖、引用存在、决策状态和G2–G4未误关。
- 全量Product V4 checks与diff gate通过。
