# P001: 子问题：Compact Receipt 与安全重放合同

Status: done
Parent: P000
Root: P000
Source Ticket: T000 (split)
Source Check: none
Package: problems/P000/children/P001
Body: problems/P000/children/P001/README.md
Ticket(s): T001

## Problem
旧 receipt 保存完整 graph/mutation，且现有 replay 直接返回该 result。需要定义不含正文的 compact envelope，并在 mutation、governance、archive delete 重放时从当前 snapshot 重建 iOS 兼容响应。

## Success Criteria
- 共享 helper 生成无 graph/实体正文的 compact envelope。
- fingerprint 校验继续在重建前执行。
- compact mutation/governance/archive delete 重放不增加 revision、不重复副作用。
- governance summary 和 V2 空 mutation 合同可被现有 iOS 解析。
- in-memory/Postgres 单测覆盖同 payload、异 payload和无 snapshot 边界。

## Subproblems
- P004: 收敛 Compact Receipt 标记与最小 envelope

## Results
- R000

## Latest Check
C002

## Bodies
- Problem: problems/P000/children/P001/README.md
- Ticket T001: problems/P000/children/P001/tickets/T001.md
- Result R000: problems/P000/children/P001/results/R000.md
- Check C000: problems/P000/children/P001/checks/C000.md
- Check C002: problems/P000/children/P001/checks/C002.md

## Follow-ups
- P004: 收敛 Compact Receipt 标记与最小 envelope
