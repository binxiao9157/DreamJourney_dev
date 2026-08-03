# P012: Round 2C：产品决策登记册与底稿生命周期

Status: done
Parent: P002
Root: P000
Source Ticket: T006 (split)
Source Check: none
Package: problems/P000/children/P002/children/P012
Body: problems/P000/children/P002/children/P012/README.md
Ticket(s): T011

## Problem
Round 1 已识别 21 项跨文档冲突，其中既有可由安全原则直接收敛的默认值，也有必须由产品、合规、商业或供应商确认的决策。若不建立结构化登记册，推荐方案会被误当成已确认决定，旧 PRD、Blueprint 和分析文档也会继续与 V4 争夺权威。

## Success Criteria
- 建立 `DreamJourney_V4_产品决策登记册_V1.0.md`，覆盖 C-01 至 C-21 且编号可追踪。
- 每项决策包含状态、类型、证据、选项、推荐、影响、默认安全策略、责任角色和进入开发的截止门。
- 明确区分 `已确认`、`推荐待确认`、`外部依赖`、`延期` 和 `拒绝`，不使用含糊的“已讨论”。
- 对身份、导出/删除、Publication/Visitor、声音授权、Family/Care/TimeLetter、数据地域、供应商与成本给出独立决策项。
- 为 PRD、V3 Blueprint、iOS 分析和 Hermes/AOS 分析定义工作底稿/历史参考/由 V4 取代的生命周期与变更说明规则。
- 可安全默认的项目采用 fail-closed；重大商业和合规选择不由工程隐式决定。
- 该问题属于 T006，因为冲突与未决项必须在 Product Spec 集成前显式收敛。

## Subproblems
- P016: Round 2C1：产品决策登记册
- P017: Round 2C2：底稿生命周期与决策静态检查

## Results
- R011

## Latest Check
C011

## Bodies
- Problem: problems/P000/children/P002/children/P012/README.md
- Ticket T011: problems/P000/children/P002/children/P012/tickets/T011.md
- Result R011: problems/P000/children/P002/children/P012/results/R011.md
- Check C011: problems/P000/children/P002/children/P012/checks/C011.md

## Follow-ups
- none
