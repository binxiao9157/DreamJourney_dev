# P031: Round 3C1 数据 Schema、Backfill 与 Authority 切换

Status: done
Parent: P022
Root: P000
Source Ticket: T027 (split)
Source Check: none
Package: problems/P000/children/P003/children/P022/children/P031
Body: problems/P000/children/P003/children/P022/children/P031/README.md
Ticket(s): T028

## Problem
当前 Postgres 依赖启动时建表、广泛 JSONB 和弱 owner/版本约束，V4 目标则要求 typed authority、跨 vault 约束、不可变 MemoryVersion、DecisionReceipt、Session、Citation、Outbox/Job 等新对象。需要定义不破坏旧客户端和现有数据的 expand/backfill/verify/authority cutover/contract 顺序，并处理不可映射历史数据。

## Success Criteria
- 给出版本化 schema migration 基线和 expand-only 规则，禁止 API 启动隐式修改生产 schema。
- 为核心对象定义 legacy source、目标对象、确定性 ID、owner/vault 映射、checkpoint、checksum、重跑和 quarantine 规则。
- 迁移期间持续验证跨 vault、terminal decision、active version、不可变 version、时间字段和唯一约束。
- 明确单 Authority 写入与 projection/outbox 策略，禁止无事务保证的业务裸双写。
- 定义数据 cutover、read fallback、contract schema 和备份恢复/rollback 边界。
- 至少覆盖 backfill 中断、重复记录、owner 冲突、无法解析 JSONB、时间字段错误和 schema migration 失败等验收场景。
- 增加可自动检查的文档门禁，并保持当前实现状态标注为未迁移。

## Subproblems
- P035: Round 3C1A Legacy 数据目录与确定性 Backfill
- P036: Round 3C1B 数据 Migration Waves、Authority Cutover 与 Rollback

## Results
- R027

## Latest Check
C027

## Bodies
- Problem: problems/P000/children/P003/children/P022/children/P031/README.md
- Ticket T028: problems/P000/children/P003/children/P022/children/P031/tickets/T028.md
- Result R027: problems/P000/children/P003/children/P022/children/P031/results/R027.md
- Check C027: problems/P000/children/P003/children/P022/children/P031/checks/C027.md

## Follow-ups
- none
