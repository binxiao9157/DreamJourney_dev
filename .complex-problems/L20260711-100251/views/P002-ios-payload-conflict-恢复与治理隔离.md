# P002: iOS payload conflict 恢复与治理隔离

Status: done
Parent: P000
Root: P000
Source Ticket: T000 (split)
Source Check: none
Package: problems/P000/children/P002
Body: problems/P000/children/P002/README.md
Ticket(s): T002

## Problem
iOS 只识别 revision conflict；payload conflict 会永久保留普通 pending 或治理 outbox 队首，同时 outbox 允许同 operation ID 覆盖为不同 action。

## Success Criteria
- Backend client 和 Coordinator 精确识别 payload conflict。
- 普通 mutation 清除 poisoned pending、保留本地 intent，并在刷新后用新 ID 重建。
- Governance 首次冲突旋转 ID，第二次进入 quarantine，隔离项不阻塞后续队列。
- Outbox operation ID 规范化、相同 payload 幂等、不同 payload 本地拒绝，Codable 兼容旧数据。
- model smoke、client/coordinator checks 与知识管线 gate 通过。

## Subproblems
- none

## Results
- R001

## Latest Check
C001

## Bodies
- Problem: problems/P000/children/P002/README.md
- Ticket T002: problems/P000/children/P002/tickets/T002.md
- Result R001: problems/P000/children/P002/results/R001.md
- Check C001: problems/P000/children/P002/checks/C001.md

## Follow-ups
- none
