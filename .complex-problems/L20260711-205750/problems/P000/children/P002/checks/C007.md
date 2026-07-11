# Postgres Receipt Dry-run/Apply 维护验收

## Summary

P002 全部子问题已关闭，维护路径满足默认只读、用户级锁/事务、失败隔离、幂等和隐私最小化要求，可进入跨仓与线上验收。

## Evidence

- 四个子问题均有 success check。
- 304 项后端全量测试和 34 项组合 smoke 通过。
- 独立审查发现的 dirty compact/空 ID/用户分页问题已修复并新增回归。
- 运维文档明确 real Postgres dry-run 是 apply 前硬门。

## Criteria Map

- Dry-run-first Store/CLI：满足。
- 用户 advisory lock 与独立事务：满足。
- 单用户失败隔离和幂等：满足。
- Compact 后无正文且 bytes 下降报告：满足。
- Fake Postgres 覆盖 dry-run/apply/timeout/rollback/idempotency：满足。
- Privacy/change-feed/replay 组合兼容：满足。

## Execution Map

- R006 汇总 P005/P006/P007/P008 结果。

## Stress Test

- Dirty compact、空 operation ID、整数分页边界、锁超时、更新异常和二次 apply 全部覆盖。

## Residual Risk

- 真实 PostgreSQL 专有行为与实际物理空间必须在 P003 部署验收中证明。

## Result IDs

- R006
