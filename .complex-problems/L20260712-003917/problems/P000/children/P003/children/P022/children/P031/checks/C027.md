# Round 3C1 数据 Schema、Backfill 与 Authority 切换成功检查

## Summary

R027 满足 P031 的文档级目标。Round 3C1 同时回答了 legacy 数据如何确定性进入目标对象，以及目标 Authority 如何在不形成双事实源的前提下分 wave 切流、暂停、回滚和退役。

## Evidence

- R025/C025：第 27 节 catalog/backfill。
- R026/C026：第 28 节 wave/cutover/rollback。
- 30 个 catalog row、38 组 target coverage、12 waves、18+18 故障场景。
- DR-040 与两个独立静态门禁。

## Criteria Map

- Versioned schema/backfill/catalog：第 27 节。
- Authority cutover/single write/projection：28.1–28.4。
- Rollback/contract/retirement：28.5–28.7。
- 故障、UNKNOWN 和批准参数：27.8–27.9、28.8–28.9、DR-040。

## Execution Map

- 先把每个旧 locator 归类并生成可重跑 target/link；再追平旧 Authority；最后按 Vault CAS 提升 epoch，旧路径转 facade/projection。
- 任何阶段都没有允许 iOS 双发或 post-cutover legacy direct write。

## Stress Test

- owner/ID/history/time/backfill crash、tail gap、stale epoch、旧客户端、projection failure、schema contract 和 rights delete 均有明确阻断或补偿路径。

## Residual Risk

- 真实 schema migration、数据规模、锁、备份恢复、cohort 和 rollback 仍需路线图实施/外部证据。
- iOS/API/Auth 和 Provider 副作用必须继续完成 P032/P033/P034，不能仅凭数据迁移章开工切流。

## Result IDs

- R025
- R026
- R027
