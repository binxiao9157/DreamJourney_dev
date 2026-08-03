# P082: Round 4E2A2：Roadmap Selector、状态失效与 Round 4 Header

Status: done
Parent: P079
Root: P000
Source Ticket: T078 (split)
Source Check: none
Package: problems/P000/children/P004/children/P055/children/P070/children/P079/children/P082
Body: problems/P000/children/P004/children/P055/children/P070/children/P079/children/P082/README.md
Ticket(s): T080

## Problem
Execution Registry 只能提供 typed facts，Roadmap 仍需定义如何从这些 facts 产生唯一 planning/execution action，以及 incident、证据过期、依赖或决定变化时如何回退和重排；同时 Round 4E 状态需更新但不能误报工程完成。

## Success Criteria
- Roadmap 链接 Execution Registry 并定义字段权威边界和有限枚举语义。
- 定义候选过滤、priority/selectorBand/stableRank tie-break、`PLAN_ASSIGN_OWNER`、`EXECUTE`、`NO_EXECUTABLE_ACTION` 的确定性算法。
- 当前基线唯一输出 `PLAN_ASSIGN_OWNER:WI-S0-03-01`；`WI-MIG-01-01` 仅为次级只读 inventory 候选。
- 定义 incident、expired/failed/missing evidence、open decision、dependency/state/authority lock 变化时的降级、暂停、失效与 replan。
- 明确停止按钮式人工授权边界：`STOP/NO_GO/UNASSIGNED` 不得由 selector 自动升级。
- Header/第6节标记 Round 4 工作项与静态验收完成、仍待 Round 5，且不代表 iOS/后端实现。

## Subproblems
- none

## Results
- R075

## Latest Check
C079

## Bodies
- Problem: problems/P000/children/P004/children/P055/children/P070/children/P079/children/P082/README.md
- Ticket T080: problems/P000/children/P004/children/P055/children/P070/children/P079/children/P082/tickets/T080.md
- Result R075: problems/P000/children/P004/children/P055/children/P070/children/P079/children/P082/results/R075.md
- Check C079: problems/P000/children/P004/children/P055/children/P070/children/P079/children/P082/checks/C079.md

## Follow-ups
- none
