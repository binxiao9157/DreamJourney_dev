# P060: Round 4B1B：Identity/AuthZ 与 Credential Stop-Loss

Status: done
Parent: P056
Root: P000
Source Ticket: T052 (split)
Source Check: none
Package: problems/P000/children/P004/children/P052/children/P056/children/P060
Body: problems/P000/children/P004/children/P052/children/P056/children/P060/README.md
Ticket(s): T054

## Problem
后端已有 auth session rotation、route ownership registry 和局部跨账号 policy，但 production anonymous/shadow/system fallback、payload owner 和 Provider credential 响应仍构成 P0；需转为可部署的小闭环路线。

## Success Criteria
- 基于当前 backend/iOS client 证据形成 `WP-S0-02`、`WP-S0-03` 的 atomic Work Items，16 字段完整。
- 路线覆盖 strong challenge/verify、subject/binding/session、refresh reuse/revoke、principal middleware、route/resource AuthZ enforce 与 typed client cutover。
- 路线覆盖 credential inventory、artifact/header/log/backup scan、rotation、true short-term broker/backend proxy、response redaction 和旧 credential revoke。
- 每项包含 shadow→enforce、兼容 route/client、部署顺序和不能回退 shared/system token 的边界。
- 不复制 secret；G3/G4 未通过时保持 Provider能力 blocked。

## Subproblems
- none

## Results
- R050

## Latest Check
C051

## Bodies
- Problem: problems/P000/children/P004/children/P052/children/P056/children/P060/README.md
- Ticket T054: problems/P000/children/P004/children/P052/children/P056/children/P060/tickets/T054.md
- Result R050: problems/P000/children/P004/children/P052/children/P056/children/P060/results/R050.md
- Check C051: problems/P000/children/P004/children/P052/children/P056/children/P060/checks/C051.md

## Follow-ups
- none
