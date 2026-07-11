# P001: 建立默认拒绝的家庭关系 authority 模型

Status: done
Parent: P000
Root: P000
Source Ticket: T000 (split)
Source Check: none
Package: problems/P000/children/P001
Body: problems/P000/children/P001/README.md
Ticket(s): T001

## Problem
`FamilyMember` 缺少关系 owner/source，initializer 与 legacy decode 又默认 active/accepted，调用方无法区分后端已接受邀请、知识候选、QA fixture 和旧本地对象。

## Success Criteria
- 定义可 Codable 的 authority source 与纯 `FamilyRelationshipAuthorizationPolicy`。
- FamilyMember 记录 owner/source，legacy/default/缺字段 fail closed。
- 仅 owner 精确匹配的 backend invitation active+accepted 被生产策略授权。
- QA fixture 只有显式 QA 策略才可用，公开策略始终拒绝。
- 纯模型 smoke 覆盖 owner/source/status/legacy/QA 组合。

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
