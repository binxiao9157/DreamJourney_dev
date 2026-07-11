# P003: Coordinator 分页集成与交付验收

Status: done
Parent: P000
Root: P000
Source Ticket: T000 (split)
Source Check: none
Package: problems/P000/children/P003
Body: problems/P000/children/P003/README.md
Ticket(s): T003

## Problem
正常 sync 和 409 refresh 各自发起一次性 change 请求；分页中没有 pull session/generation/终页提交边界，也没有长期组合门禁。

## Success Criteria
- 正常 sync/409 refresh 共用 paginated pull state machine。
- user/generation/pullSession 失效页被丢弃；终页前无 base/pending/KBLite/mutation/governance 副作用。
- 终页 CAS merge 有界重算后只 push 一次。
- QA/release/docs 更新，后端全量、跨仓 gate、Simulator/generic iPhoneOS build 通过。
- 两仓独立提交，不推送、不部署、不真机。

## Subproblems
- none

## Results
- R002

## Latest Check
C002

## Bodies
- Problem: problems/P000/children/P003/README.md
- Ticket T003: problems/P000/children/P003/tickets/T003.md
- Result R002: problems/P000/children/P003/results/R002.md
- Check C002: problems/P000/children/P003/checks/C002.md

## Follow-ups
- none
