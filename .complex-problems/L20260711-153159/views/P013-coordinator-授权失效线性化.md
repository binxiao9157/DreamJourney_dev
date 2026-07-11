# P013: Coordinator 授权失效线性化

Status: done
Parent: P011
Root: P000
Source Ticket: T011 (split)
Source Check: none
Package: problems/P000/children/P005/children/P006/children/P011/children/P013
Body: problems/P000/children/P005/children/P006/children/P011/children/P013/README.md
Ticket(s): T013

## Problem
persona/family invalidation 仅异步排入 serial queue，已排队的旧 callback 可能先通过旧 generation 并修改 graph/base/outbox。

## Success Criteria
- coordinator 拥有线程安全 authorization epoch，并在账号、角色、family refresh 开始时立即轮换。
- 每个 queue-owned sync generation 绑定当前 epoch，`isCurrent` 同时验证二者。
- invalidation 在返回前同步更新 queue 状态，且 queue 内调用不会自锁。
- 模型/静态 gate 覆盖 callback-before-invalidate 时序并通过。

## Subproblems
- none

## Results
- R011

## Latest Check
C012

## Bodies
- Problem: problems/P000/children/P005/children/P006/children/P011/children/P013/README.md
- Ticket T013: problems/P000/children/P005/children/P006/children/P011/children/P013/tickets/T013.md
- Result R011: problems/P000/children/P005/children/P006/children/P011/children/P013/results/R011.md
- Check C012: problems/P000/children/P005/children/P006/children/P011/children/P013/checks/C012.md

## Follow-ups
- none
