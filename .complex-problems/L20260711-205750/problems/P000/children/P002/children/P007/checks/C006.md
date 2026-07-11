# Receipt Maintenance 组合回归验收

## Summary

P007 已完成。组合 smoke、默认 dry-run 静态合同、后端全量回归和运维边界均有直接证据；P008 的阻断问题已关闭。

## Evidence

- 一键 smoke 同时运行 receipt、privacy、change-feed 和四类 operation replay 测试。
- `verify_backend.sh` 直接调用组合 smoke。
- 运维文档明确禁止 reader-first 前 apply，并给出 dry-run/apply/幂等/失败处理顺序。
- 304 项后端全量回归和 34 项组合 smoke 通过。

## Criteria Map

- 组合覆盖：满足。
- Verify 接入：满足。
- CLI 默认 dry-run：满足。
- 运维说明：满足。
- 不依赖真实 Postgres且无正文输出：满足。
- 全量验证：满足。

## Execution Map

- R005 完成 smoke、verify 接入和文档。
- P008 R004/C005 关闭独立审查阻断。

## Stress Test

- Dirty compact、空 ID、多页用户、锁超时、用户回滚、二次 apply 均在组合测试覆盖。

## Residual Risk

- 真实 Postgres 仅能由 P003 部署后验证；文档已将其设为 apply 前硬门。

## Result IDs

- R005
