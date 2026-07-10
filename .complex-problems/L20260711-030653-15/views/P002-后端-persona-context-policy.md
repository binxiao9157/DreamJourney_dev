# P002: 后端 Persona Context Policy

Status: done
Parent: P000
Root: P000
Source Ticket: T000 (split)
Source Check: none
Package: problems/P000/children/P002
Body: problems/P000/children/P002/README.md
Ticket(s): T002

## Problem
Context 当前只允许 personal self KB facts；缺少实体级 persona 过滤后，family facts 无法安全启用。

## Success Criteria
- personal/self 兼容缺少 metadata 的旧事实，但拒绝其他显式 persona。
- family 只允许 owner、family scope 和目标 digitalHumanId 全部匹配的事实。
- 负向测试覆盖 scope、digitalHumanId、owner 和 legacy family 越界。

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
