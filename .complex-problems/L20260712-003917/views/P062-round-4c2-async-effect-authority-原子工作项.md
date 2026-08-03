# P062: Round 4C2：Async Effect Authority 原子工作项

Status: done
Parent: P053
Root: P000
Source Ticket: T057 (split)
Source Check: none
Package: problems/P000/children/P004/children/P053/children/P062
Body: problems/P000/children/P004/children/P053/children/P062/README.md
Ticket(s): T059

## Problem
当前时间信件、延迟回信、通知和 Provider 调用包含 timer、callback、重试与持久化多条路径。若只在业务代码中补重试，无法证明一次业务提交只产生一次可解释副作用，也无法处理 crash、duplicate、late callback 和 Provider unknown。

## Success Criteria
- 建立覆盖 Outbox/Job/lease、consumer Inbox、business completion receipt、dead-letter/replay/reconcile 的连续原子工作项。
- 覆盖 TimeLetter dispatch、Echo delayed reply、notification delivery 与至少一种 Provider effect；通知送达不得等同业务完成。
- 每项完整填写 16 个字段，明确 request/job UoW、stable idempotency key、attempt、unknown、authorityEpoch 和 operation evidence。
- 明确旧 timer/调度器的 shadow、drain、zero-use、retire 条件，禁止新旧 writer 同时成为 Authority。
- 给出 crash-before/after-commit、duplicate delivery、lease expiry、late callback、provider accepted-but-timeout 的 G0/G2 测试语料。
- Provider 外部门保持 G3，业务核心可在 Provider disabled/synthetic 时完成内部合同和失败披露。

## Subproblems
- none

## Results
- R056

## Latest Check
C057

## Bodies
- Problem: problems/P000/children/P004/children/P053/children/P062/README.md
- Ticket T059: problems/P000/children/P004/children/P053/children/P062/tickets/T059.md
- Result R056: problems/P000/children/P004/children/P053/children/P062/results/R056.md
- Check C057: problems/P000/children/P004/children/P053/children/P062/checks/C057.md

## Follow-ups
- none
