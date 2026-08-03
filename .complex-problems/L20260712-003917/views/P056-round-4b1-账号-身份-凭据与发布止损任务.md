# P056: Round 4B1：账号、身份、凭据与发布止损任务

Status: done
Parent: P052
Root: P000
Source Ticket: T051 (split)
Source Check: none
Package: problems/P000/children/P004/children/P052/children/P056
Body: problems/P000/children/P004/children/P052/children/P056/README.md
Ticket(s): T052

## Problem
`WP-S0-01/02/03/06` 共同决定客户端账号隔离、服务端身份/AuthZ、credential 边界和未验收功能是否 fail closed，但它们尚未成为有真实双仓路径和独立退出证据的 Work Item。

## Success Criteria
- 为四个 package 建立唯一 `WI-S0-01-*`、`WI-S0-02-*`、`WI-S0-03-*`、`WI-S0-06-*`，每项填写路线图 16 字段。
- Account 覆盖 AccountLease、generation、owner-scoped store inventory/envelope、legacy quarantine、A/B/logout/delete/cold start。
- Identity/AuthZ 覆盖 strong challenge、session rotation/revoke、server-derived principal、route/resource enforce 和 iOS typed auth迁移。
- Credential 覆盖 inventory、scan、rotation、broker/redaction、revoke，不复制 secret。
- Release Scope 覆盖 server policy、TTL/offline deny、public release hidden regression。
- 明确 G0/G1 可完成部分与 G2/G3/G4 外部门，并给出四包之间的 hard dependency和部署顺序。

## Subproblems
- P059: Round 4B1A：Account/Local Isolation 与 Release Scope
- P060: Round 4B1B：Identity/AuthZ 与 Credential Stop-Loss

## Results
- R051

## Latest Check
C052

## Bodies
- Problem: problems/P000/children/P004/children/P052/children/P056/README.md
- Ticket T052: problems/P000/children/P004/children/P052/children/P056/tickets/T052.md
- Result R051: problems/P000/children/P004/children/P052/children/P056/results/R051.md
- Check C052: problems/P000/children/P004/children/P052/children/P056/checks/C052.md

## Follow-ups
- none
