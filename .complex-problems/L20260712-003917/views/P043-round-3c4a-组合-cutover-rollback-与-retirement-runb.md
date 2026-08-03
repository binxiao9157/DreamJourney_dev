# P043: Round 3C4A 组合 Cutover、Rollback 与 Retirement Runbook

Status: done
Parent: P034
Root: P000
Source Ticket: T039 (split)
Source Check: none
Package: problems/P000/children/P003/children/P022/children/P034/children/P043
Body: problems/P000/children/P003/children/P022/children/P034/children/P043/README.md
Ticket(s): T040

## Problem
现有 W/I/P/Q/O/V 波次分别解决单域迁移，但没有统一编排其依赖、批准、观测、暂停和恢复。需要在不复制第二套 migration authority 的前提下，形成跨数据、客户端/API、worker、object 和 Provider 的组合执行 Runbook。

## Success Criteria
- 定义五类 rollback plane：UI exposure、client routing、API traffic、worker/provider、schema/data。
- 定义至少 10 个有序组合 wave，并映射到既有 W/I/P/Q/O/V 波次。
- 每个 wave 包含 prerequisites、change、owner、observability、threshold、cutover、rollback/compensation、max recovery time 和 exit evidence。
- 区分可回滚配置/流量与不可逆 MemoryVersion、Inbox delivery、Provider train/delete effect，后者只能补偿/对账。
- 定义统一 go/no-go record、自动 pause/no-go、rights-job 优先级、backup/restore 和 emergency stop。
- 退役 manifest 覆盖 schema、route、timer、credential、feature flag、legacy store 和 transition code。
- 至少 18 个跨域故障演练，覆盖代码/数据版本错位、旧客户端、unknown effect、partial delete、contract 后回滚和恢复超时。

## Subproblems
- none

## Results
- R036

## Latest Check
C037

## Bodies
- Problem: problems/P000/children/P003/children/P022/children/P034/children/P043/README.md
- Ticket T040: problems/P000/children/P003/children/P022/children/P034/children/P043/tickets/T040.md
- Result R036: problems/P000/children/P003/children/P022/children/P034/children/P043/results/R036.md
- Check C037: problems/P000/children/P003/children/P022/children/P034/children/P043/checks/C037.md

## Follow-ups
- none
