# 真实 Postgres Receipt 验收检查

## Summary

P014 成功标准全部满足，线上 apply 由无失败 dry-run 硬门保护，并已证明身份保持和重复执行幂等。

## Evidence

- P015 结果 `R010`。
- P016 结果 `R011`。

## Criteria Map

- Dry-run 合法且脱敏：满足。
- 行数与 identity/hash 不变：满足。
- Apply 与二次幂等：满足。
- Duplicate/conflict 和相邻维护回归：满足。
- 异常停止边界：本次无异常，硬断言已生效。

## Execution Map

- 先关闭 P015，再允许执行 P016。
- Apply 后立即执行聚合与幂等复核。

## Stress Test

- `keep-days=0` 全量扫描；主链路新写 receipt 后再次确认全 compact。

## Residual Risk

- 数据量增长后需观察扫描性能，再决定索引。

## Result IDs

- `R010`
- `R011`
