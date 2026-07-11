# P012: iOS Governance 串行提交与 Generation Gate

Status: done
Parent: P010
Root: P000
Source Ticket: T009 (split)
Source Check: none
Package: problems/P000/children/P003/children/P010/children/P012
Body: problems/P000/children/P003/children/P010/children/P012/README.md
Ticket(s): T011

## Problem
持久化动作仍需与普通知识同步共享网络 owner，并处理 revision conflict、服务端成功后的权威 graph、user/persona 切换。

## Success Criteria
- coordinator 提供 performGovernance，先写 outbox 再发请求。
- 普通 sync 与 governance 不并发；成功、失败、409 状态正确推进。
- 同 operation ID 重试，成功删除 outbox并保存 base。
- user/persona 旧 callback 不直接写当前图谱；服务端已成功时走 change feed 收敛。
- static/model smoke 和 Simulator build 通过。

## Subproblems
- none

## Results
- R008

## Latest Check
C008

## Bodies
- Problem: problems/P000/children/P003/children/P010/children/P012/README.md
- Ticket T011: problems/P000/children/P003/children/P010/children/P012/tickets/T011.md
- Result R008: problems/P000/children/P003/children/P010/children/P012/results/R008.md
- Check C008: problems/P000/children/P003/children/P010/children/P012/checks/C008.md

## Follow-ups
- none
