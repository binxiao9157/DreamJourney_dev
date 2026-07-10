# P000: P1 知识删除 Tombstone 与三方合并

Status: done
Parent: none
Root: P000
Source Ticket: none (none)
Source Check: none
Package: problems/P000
Body: problems/P000/README.md
Ticket(s): T000

## Problem
Close the Lodestar task represented by `/Users/yxj/Documents/Codex/Video/DreamJourney_dev/docs/plans/task_13_p1-knowledge-tombstone-three-way-merge.md` using recursive problem, ticket, result, and check state.

Task context:

# P1 知识删除 Tombstone 与三方合并

## Success Criteria
- 本地删除同步为 tombstone，其他客户端拉取后不会恢复该实体。
- 远端删除不会删除本机 local-only/旧无授权实体。
- 双方只改一侧时不丢更新；双方同改时行为确定且可在 QA trace 识别。
- malformed change feed 不推进 revision，用户切换旧回调仍被隔离。
- v1 与旧服务端降级合同继续通过现有 release regression。

## Subproblems
- P001: 后端知识 Mutation V2 与 Tombstone
- P002: iOS 远端基线、三方合并与 Delta 生成
- P003: 知识 V2 跨仓库 QA 与交付收敛

## Results
- R003

## Latest Check
C003

## Bodies
- Problem: problems/P000/README.md
- Ticket T000: problems/P000/tickets/T000.md
- Result R003: problems/P000/results/R003.md
- Check C003: problems/P000/checks/C003.md

## Follow-ups
- none
