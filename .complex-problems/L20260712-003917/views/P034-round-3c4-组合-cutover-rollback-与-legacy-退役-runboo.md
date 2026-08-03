# P034: Round 3C4 组合 Cutover、Rollback 与 Legacy 退役 Runbook

Status: done
Parent: P022
Root: P000
Source Ticket: T027 (split)
Source Check: none
Package: problems/P000/children/P003/children/P022/children/P034
Body: problems/P000/children/P003/children/P022/children/P034/README.md
Ticket(s): T039

## Problem
前三个迁移子域即使各自正确，组合切流仍可能出现数据已经前进但代码回滚、旧客户端继续写、异步副作用未知、schema 已 contract 或 Provider 无法撤销等问题。需要形成一份统一 wave/runbook，定义批准门、观测、自动暂停、不可逆边界、补偿和最终退役证据。

## Success Criteria
- 将数据、iOS/API/Auth、Job/Object/Provider 组合为至少 8 个有顺序的 migration wave。
- 每个 wave 明确前置条件、变更、owner、观测指标、成功阈值、cutover、rollback/补偿、最大恢复时间和退出证据。
- 区分 UI exposure、client routing、API traffic、worker/provider、schema/data 五类 rollback。
- 明确已确认 MemoryVersion、已投递 Inbox、外部训练/删除等不可逆事实只能补偿/对账，不能通过数据库回滚抹除。
- 定义备份恢复、canary、mismatch/dead-letter/quarantine、数据权利、Provider receipt 和旧客户端比例的 release/retirement gate。
- 给出旧 schema、旧 route、旧 timer、旧 credential、旧 feature flag、legacy store 和过渡代码的逐项退役清单。
- 至少覆盖 15 个跨域故障演练和 go/no-go 决策记录格式。
- 增加总 migration/rollback 静态门禁，并更新证据矩阵与决策登记册。

## Subproblems
- P043: Round 3C4A 组合 Cutover、Rollback 与 Retirement Runbook
- P044: Round 3C4B Runbook Evidence、Decision 与静态门

## Results
- R038

## Latest Check
C039

## Bodies
- Problem: problems/P000/children/P003/children/P022/children/P034/README.md
- Ticket T039: problems/P000/children/P003/children/P022/children/P034/tickets/T039.md
- Result R038: problems/P000/children/P003/children/P022/children/P034/results/R038.md
- Check C039: problems/P000/children/P003/children/P022/children/P034/checks/C039.md

## Follow-ups
- none
