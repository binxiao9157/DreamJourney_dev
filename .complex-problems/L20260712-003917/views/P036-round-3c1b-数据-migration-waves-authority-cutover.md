# P036: Round 3C1B 数据 Migration Waves、Authority Cutover 与 Rollback

Status: done
Parent: P031
Root: P000
Source Ticket: T028 (split)
Source Check: none
Package: problems/P000/children/P003/children/P022/children/P031/children/P036
Body: problems/P000/children/P003/children/P022/children/P031/children/P036/README.md
Ticket(s): T030

## Problem
即使逐对象 backfill 合同正确，仍需要定义 schema expand、shadow compare、cohort authorityEpoch cutover、read fallback、post-cutover compensation 和最终 schema contract 的有序执行，否则旧客户端与新 Authority 会同时写入或在回滚时删除新事实。

## Success Criteria
- 定义独立 migration runner、head/checksum/lock、backup/restore、dry-run 和 API readiness 规则。
- 给出至少 10 个数据 migration wave，每个含前置条件、变更、验证、cutover、rollback 和退出证据。
- 明确 single authority + projection/outbox 为默认模式，dual-write 例外具有同事务/同 commandId/compare/kill switch。
- 定义 old/new canonical shadow mismatch 分类和 owner cohort cutover 阈值。
- 迁移期间持续验证跨 vault、terminal decision、active/immutable version、schedule timestamp 和唯一约束。
- 区分 pre-cutover read fallback、post-cutover compensation 与不可逆事实；schema contract 只能在旧写退役后执行。
- 至少 8 个 wave/cutover/rollback 故障场景可验证。
- 增加数据迁移静态门禁并同步证据矩阵。

## Subproblems
- none

## Results
- R026

## Latest Check
C026

## Bodies
- Problem: problems/P000/children/P003/children/P022/children/P031/children/P036/README.md
- Ticket T030: problems/P000/children/P003/children/P022/children/P031/children/P036/tickets/T030.md
- Result R026: problems/P000/children/P003/children/P022/children/P031/children/P036/results/R026.md
- Check C026: problems/P000/children/P003/children/P022/children/P031/children/P036/checks/C026.md

## Follow-ups
- none
