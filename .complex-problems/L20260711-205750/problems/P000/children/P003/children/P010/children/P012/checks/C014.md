# 后端部署与真实 Postgres Receipt 验收检查

## Summary

P012 成功标准全部满足，部署顺序、真实 SQL 行为、幂等和相邻合同均有生产证据。

## Evidence

- P013 结果 `R009`。
- P014 的 P015/P016 线上证据。

## Criteria Map

- 目标提交与健康检查：满足。
- Dry-run 硬门：满足。
- 小 batch apply 与二次幂等：满足。
- Duplicate/conflict/privacy/change-feed：满足。
- 状态文档和风险：满足。

## Execution Map

- Reader-first 部署后才运行数据库维护。
- Dry-run 成功后才执行 apply。

## Stress Test

- 部署 smoke 在迁移后写入新 receipt 并再次验证 compact writer。

## Residual Risk

- 仅剩非阻断容量监控项。

## Result IDs

- `R009`
- P014 汇总结果。
