# Postgres Receipt Dry-run/Apply 维护结果

## Summary

历史 receipt 的纯转换、privacy compatibility、Postgres 分用户 dry-run/apply、组合 smoke 和运维边界均已完成；本地实现已达到部署前状态。

## Done

- P005：完成 legacy/full 到 canonical compact envelope 转换和 compact V2 privacy maintenance 兼容。
- P006：完成默认 dry-run CLI、分用户事务/advisory lock、timeout、分页、结构化报告和幂等 apply。
- P007：完成 receipt/privacy/change-feed/replay 组合 smoke、verify_backend 接入和生产运维说明。
- P008：修复 dirty compact 快速跳过、空 operation ID 漏扫和用户发现无界 fetchall。
- Receipt identity、kind/schema、payload hash 与 created_at 始终不修改，receipt 行不删除。

## Verification

- 后端全量 304 项测试通过。
- Receipt maintenance 组合 smoke 34 项通过。
- FastAPI/knowledge smokes、py_compile、CLI help 和 diff check 全部通过。

## Gaps

- 真实 Postgres dry-run/apply 与线上 duplicate/privacy/change-feed 验收由 P003 执行。
- 跨仓 iOS release gate 和非真机构建由 P003 执行。

## Artifacts

- P005 R002/C003
- P006 R003/C004
- P007 R005/C006
- P008 R004/C005
