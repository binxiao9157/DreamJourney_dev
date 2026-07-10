# P007: Ownership 版本提交部署与线上证据

Status: done
Parent: P003
Root: P000
Source Ticket: T005 (split)
Source Check: none
Package: problems/P000/children/P003/children/P007
Body: problems/P000/children/P003/children/P007/README.md
Ticket(s): T007

## Problem
实现必须以可追踪提交部署到线上 Postgres，并验证真实中间件、路由、timer 与 delegated 合同，不可只停留在 memory 测试。

## Success Criteria
- 后端与 iOS 分别提交并推送当前分支，无无关文件进入提交。
- 服务器只重建 API，Postgres/Redis 保持运行。
- 线上 health=200、store=postgres、global mode=shadow、routeCount=54、unclassified=0。
- auth、cross-account 与 route ownership deployed smoke 全部通过并保存脱敏报告。
- 服务端时间信件 timer 仍 active。

## Subproblems
- none

## Results
- R005

## Latest Check
C005

## Bodies
- Problem: problems/P000/children/P003/children/P007/README.md
- Ticket T007: problems/P000/children/P003/children/P007/tickets/T007.md
- Result R005: problems/P000/children/P003/children/P007/results/R005.md
- Check C005: problems/P000/children/P003/children/P007/checks/C005.md

## Follow-ups
- none
