# P002: 后端 Context P0 生成与访问门禁

Status: done
Parent: P000
Root: P000
Source Ticket: T000 (split)
Source Check: none
Package: problems/P000/children/P002
Body: problems/P000/children/P002/README.md
Ticket(s): T002

## Problem
Context Packet 可以选择 low/medium KBLite fact，时间信件跨收件人和 care viewer 仍缺少完整负向回归，可能把不可信或无权内容送入 Echo。

## Success Criteria
- KBLite fact 只有 high/confirmed 能进入 generationContext，其他候选写入固定 filtered reason。
- 写给其他收件人、未到期时间信件和无效家庭 viewer 不进入 Context。
- personal/family care 访问使用已验证的 viewer/persona policy，不因客户端 viewer 参数 fail-open。
- Context V2 单测和 smoke 覆盖选择、过滤 reason、hash 稳定及旧合同兼容。

## Subproblems
- none

## Results
- R001

## Latest Check
C001

## Bodies
- Problem: problems/P000/children/P002/README.md
- Ticket T002: problems/P000/children/P002/tickets/T002.md
- Result R001: problems/P000/children/P002/results/R001.md
- Check C001: problems/P000/children/P002/checks/C001.md

## Follow-ups
- none
