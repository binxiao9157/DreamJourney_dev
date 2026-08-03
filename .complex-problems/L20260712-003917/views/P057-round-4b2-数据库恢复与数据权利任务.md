# P057: Round 4B2：数据库恢复与数据权利任务

Status: done
Parent: P052
Root: P000
Source Ticket: T051 (split)
Source Check: none
Package: problems/P000/children/P004/children/P052/children/P057
Body: problems/P000/children/P004/children/P052/children/P057/README.md
Ticket(s): T055

## Problem
`WP-S0-04/05` 当前同时受共享连接、启动 DDL、无真实 readiness/restore、soft delete 和 Provider/Object/Backup receipt 缺口影响；必须拆成先地基、后撤权与分层完成的可执行任务。

## Success Criteria
- 为两个 package 建立唯一 `WI-S0-04-*`、`WI-S0-05-*`，每项填写路线图 16 字段。
- DB 覆盖 connection pool/request-job UoW、versioned migrator、readiness、backup/isolated restore/receipt replay。
- Rights 覆盖强验证请求、access-first、状态机、module/object/provider/backup receipt、restore/retention 和不可逆披露。
- 明确 Stage 0 access-revoke/internal-ready 与 Stage 1 async/provider完整退出的边界，避免循环依赖。
- 每项引用当前 backend/iOS 路径或明确新增位置，包含 Postgres fault/concurrency/restore 和客户端披露验证。

## Subproblems
- none

## Results
- R052

## Latest Check
C053

## Bodies
- Problem: problems/P000/children/P004/children/P052/children/P057/README.md
- Ticket T055: problems/P000/children/P004/children/P052/children/P057/tickets/T055.md
- Result R052: problems/P000/children/P004/children/P052/children/P057/results/R052.md
- Check C053: problems/P000/children/P004/children/P052/children/P057/checks/C053.md

## Follow-ups
- none
