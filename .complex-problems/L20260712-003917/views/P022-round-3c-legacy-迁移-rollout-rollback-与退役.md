# P022: Round 3C：Legacy 迁移、rollout、rollback 与退役

Status: done
Parent: P003
Root: P000
Source Ticket: T017 (split)
Source Check: none
Package: problems/P000/children/P003/children/P022
Body: problems/P000/children/P003/children/P022/README.md
Ticket(s): T027

## Problem
Archive/KBLite/JSONB/本地会话已有真实与 mock 数据，不能全部升级或丢弃；新旧客户端和 provider callback 也会并存，需要 per-owner 可回滚切换而非永久双写。

## Success Criteria
- 定义 inventory、legacy status mapping、quarantine、migration receipt 和数据质量报告。
- 新 authority 单写，outbox 生成兼容 Projection；shadow 双读不形成双 authority。
- per-owner authorityEpoch、cohort、feature/release policy、kill switch 和 rollback 条件明确。
- 旧客户端兼容、最低版本、API deprecation 和 Projection 退役条件明确。
- 账号删除/RightsRequest/第三方异议同时覆盖 legacy quarantine。
- 每阶段有 precheck、迁移、验证、观察、rollback、exit criteria 和不可逆点。
- 该问题属于 T017，因为安全迁移决定架构能否在当前工程落地。

## Subproblems
- P031: Round 3C1 数据 Schema、Backfill 与 Authority 切换
- P032: Round 3C2 iOS、API 与 AuthZ 双轨 Rollout
- P033: Round 3C3 Job、对象存储与 Provider 副作用迁移
- P034: Round 3C4 组合 Cutover、Rollback 与 Legacy 退役 Runbook

## Results
- R039

## Latest Check
C040

## Bodies
- Problem: problems/P000/children/P003/children/P022/README.md
- Ticket T027: problems/P000/children/P003/children/P022/tickets/T027.md
- Result R039: problems/P000/children/P003/children/P022/results/R039.md
- Check C040: problems/P000/children/P003/children/P022/checks/C040.md

## Follow-ups
- none
