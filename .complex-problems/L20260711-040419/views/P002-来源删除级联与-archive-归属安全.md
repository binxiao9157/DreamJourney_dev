# P002: 来源删除级联与 Archive 归属安全

Status: done
Parent: P000
Root: P000
Source Ticket: T000 (split)
Source Check: none
Package: problems/P000/children/P002
Body: problems/P000/children/P002/README.md
Ticket(s): T002

## Problem
当前 Archive 删除与知识 snapshot 无联动，删除来源后关联知识仍可能进入 Echo；Postgres `archive_items.id` 全局冲突更新还可能改变 owner。需要先阻断跨 owner 接管，并让来源删除以知识安全优先的方式级联失效。

## Success Criteria
- 相同 archive ID 不允许跨 owner 覆盖，冲突返回稳定业务错误而非 500。
- deleteSource action 扫描 owner snapshot 四类实体，按 `(kind,id)` 精确匹配。
- 所有匹配实体移除该 source ref、标记 superseded 并保留审计历史。
- Archive 删除路径触发来源级联；失败边界有明确测试，不出现“来源已删除但知识仍可生成”。
- Postgres 并发/回滚或安全优先顺序通过测试，sealed timeLetter 约束不退化。

## Subproblems
- P005: Archive ID 跨 Owner 冲突保护
- P006: Archive 删除与知识撤销组合事务

## Results
- R005

## Latest Check
C005

## Bodies
- Problem: problems/P000/children/P002/README.md
- Ticket T002: problems/P000/children/P002/tickets/T002.md
- Result R005: problems/P000/children/P002/results/R005.md
- Check C005: problems/P000/children/P002/checks/C005.md

## Follow-ups
- none
