# Round 3C1B 数据 Migration Waves、Authority Cutover 与 Rollback 成功检查

## Summary

R026 满足 P036 的文档级目标。数据迁移已经从 catalog 提升为有序 wave、epoch fencing、single-authority、shadow promotion、rollback 和 retirement 合同；各阶段没有把“关闭新功能”误写成“恢复旧数据 Authority”。

## Evidence

- Product Spec 第 28.0 至 28.9 节。
- W00–W11、M01–M08、R01–R05、D01–D07 目录。
- 18 个跨 wave/cutover/rollback 故障场景。
- DR-040 和 Evidence Matrix 7.4 明确未决参数与未实现状态。
- `product-v4-data-cutover-check.py` 及全部相关 V4 门禁通过。

## Criteria Map

- Migration state/cohort：28.1。
- AuthorityEpoch/single-authority：28.2。
- 逐 wave precondition/change/verify/rollback/exit：28.3。
- Canonical compare/promotion：28.4。
- Rollback 与不可逆事实：28.5。
- Legacy contract/retire：28.6。
- Go/no-go evidence 与批准：28.7、DR-040。
- 故障/未决参数：28.8、28.9。

## Execution Map

- 3C1A catalog 是 W04/W05 输入；W06/W07 只比较，不产生第二事实；W08 原子提升 epoch；W09 切 projection；W10/W11 才允许退旧路径。
- Post-cutover rollback 保留新 Authority 并切 compatibility read，避免 epoch 回退和双 Authority。

## Stress Test

- DDL/runner crash、tail gap、dry-run side effect、并发 cutover、stale callback、旧客户端无 commandId、projection 空、旧 direct write 和 post-contract 故障均有明确 no-go/恢复路径。
- owner/visibility/version mismatch 是零容忍 blocker，不因其他 Vault 通过而降低标准。

## Residual Risk

- 目标合同尚未由真实 migration/canary/restore drill 证明。
- 专项 3C1B reviewer 未返回；Round 3D 必须重新进行独立组合复审，不能复用该未完成状态。
- iOS/API/Auth 与 Provider 副作用细节仍由 P032/P033/P034 完成。

## Result IDs

- R026
