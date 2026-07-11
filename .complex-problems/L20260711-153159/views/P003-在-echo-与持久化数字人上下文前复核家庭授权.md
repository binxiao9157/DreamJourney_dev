# P003: 在 Echo 与持久化数字人上下文前复核家庭授权

Status: done
Parent: P000
Root: P000
Source Ticket: T000 (split)
Source Check: none
Package: problems/P000/children/P003
Body: problems/P000/children/P003/README.md
Ticket(s): T003

## Problem
relation 文本可把非 self context 推断为 personal，DigitalHumanContextStore 恢复和 Echo 请求又未统一验证当前 owner 的 accepted family member，可能开启错误 personal fallback 或发送未授权 family context。

## Success Criteria
- personal identity 只由显式 self 或 owner/viewer 精确一致决定，relation spoof 无效。
- 持久化 family context 恢复时验证当前 owner 的 accepted member，不通过则回退当前用户 self context。
- Echo family 请求前执行同一 accepted-member preflight；失败时不请求 family `/context/build`。
- pending/failed/revoked 和跨 owner member 均拒绝，accepted exact digitalHumanId 正常通过。
- 模型/静态 smoke 覆盖恢复、请求与 fallback。

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
