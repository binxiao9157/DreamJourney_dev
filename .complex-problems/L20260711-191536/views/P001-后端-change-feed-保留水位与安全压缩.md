# P001: 后端 change-feed 保留水位与安全压缩

Status: done
Parent: P000
Root: P000
Source Ticket: T000 (split)
Source Check: none
Package: problems/P000/children/P001
Body: problems/P000/children/P001/README.md
Ticket(s): T001

## Problem
实现原子 change-page 读取、持久化保留水位、结构化 410 合同和 dry-run-first Postgres 压缩维护。

该问题属于父任务，因为没有可靠的服务端保留边界和原子读取，客户端无法区分真实故障与已压缩历史。

## Success Criteria
- memory/Postgres store 都能返回一致的当前 snapshot、水位和分页窗口。
- 请求早于水位时 legacy/paged API 均返回精确 410。
- apply 压缩只删除有 receipt 的安全历史，删除和水位同事务，dry-run/失败不写库。
- 后端专项测试与 smoke 通过。

## Subproblems
- none

## Results
- R000

## Latest Check
C000

## Bodies
- Problem: problems/P000/children/P001/README.md
- Ticket T001: problems/P000/children/P001/tickets/T001.md
- Result R000: problems/P000/children/P001/results/R000.md
- Check C000: problems/P000/children/P001/checks/C000.md

## Follow-ups
- none
