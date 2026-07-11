# P005: 实现 Widget schema v2 身份校验与最小展示

Status: done
Parent: P003
Root: P000
Source Ticket: T003 (split)
Source Check: none
Package: problems/P000/children/P003/children/P005
Body: problems/P000/children/P003/children/P005/README.md
Ticket(s): T004

## Problem
Widget provider 直接信任旧共享 JSON，并将事件 description 放进 timeline entry 和界面，无法拒绝旧 schema、跨账号或损坏快照。

## Success Criteria
- Shared model 与主 App schema v2 字段一致，并提供可纯测试的 snapshot acceptance policy。
- provider 只有在 schema 与 active owner digest 匹配时返回事件，其余情况为空。
- entry/view 不再携带或显示 description，placeholder 使用通用非真实内容。
- 事件内容标记 `.privacySensitive()`，不改 App 主页面视觉。
- 读取策略模型 smoke 覆盖匹配、缺 owner、错 owner、旧 schema 和损坏数据。

## Subproblems
- none

## Results
- R002

## Latest Check
C002

## Bodies
- Problem: problems/P000/children/P003/children/P005/README.md
- Ticket T004: problems/P000/children/P003/children/P005/tickets/T004.md
- Result R002: problems/P000/children/P003/children/P005/results/R002.md
- Check C002: problems/P000/children/P003/children/P005/checks/C002.md

## Follow-ups
- none
