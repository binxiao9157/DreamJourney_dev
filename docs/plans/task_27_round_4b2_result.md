# Round 4B2 数据库恢复与数据权利结果

## Summary

已基于独立DB/Rights审计，将`WP-S0-04`和`WP-S0-05`细化为11个单结果Work Item。路线把共享连接、startup DDL、假health、无backup/restore、删除后session仍有效、purged可复活和外部删除误报分别放入独立任务。

## Done

- `WI-S0-04-01..05`：pool/UoW、migrator、live/ready、backup manifest、isolated restore/replay。
- `WI-S0-05-01..06`：Rights Authority、access-first、restore/purge/hold、module executors、external cleanup、iOS状态面。
- 每项含16字段和current/new路径、G0/G2/G3/G4、部署/回滚/DoD。
- 明确expand-first、无production down migration、access revoke不可回滚、物理删除只forward reconcile。
- 数据导出保持Decision gate，不因Rights schema存在自动公开。

## Verification

- 独立explorer核实当前backend/iOS路径，并执行304项memory单测；明确fake connection不能证明G2。
- Work Item检查：11个唯一ID、176字段，通过。
- Data contract、backfill、cutover、composite runbook检查通过。
- `git diff --check`通过。

## Boundary

- 当前只完成路线，不执行真实migration、backup、restore或delete。
- G2真实Postgres/restore、G3 provider/object、G4 Privacy/Legal/文案仍未验证。
- 完整Rights退出依赖后续`WP-S1-02`异步Authority。

## Artifact

- 路线图第11–12节。
