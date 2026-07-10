# P001: 后端 Mutation Proposal Builder

Status: done
Parent: P000
Root: P000
Source Ticket: T000 (split)
Source Check: none
Package: problems/P000/children/P001
Body: problems/P000/children/P001/README.md
Ticket(s): T001

## Problem
后端 extraction 尚未基于权威 snapshot 生成稳定、可审计且可直接提交 Mutation V2 的 proposal。

## Success Criteria
- 基于 owner/persona/entity natural key 生成稳定 ID，并优先复用 snapshot 现有 ID。
- 输出 revision-bound upserts、metadata、证据状态和已解析关系，且不直接持久化。
- 单元/API 测试覆盖幂等、legacy ID、关系解析和隐私净化。

## Subproblems
- none

## Results
- R000

## Latest Check
C000

## Bodies
- Problem: problems/P000/children/P001/README.md
- Ticket T001: problems/P000/children/P001/tickets/T001.md
- Result R000: problems/P000/children/P001/results/R000.md
- Check C000: problems/P000/children/P001/checks/C000.md

## Follow-ups
- none
