# 后端知识 Mutation V2 成功检查

## Summary

结果已满足 P001 的全部合同与验证标准；线上部署不属于该子问题的完成条件，不阻断本地实现闭环。

## Evidence

- `R000` 记录了 v2 合同、双存储实现、兼容策略和完整验证结果。
- `./scripts/verify_backend.sh` 实际执行 195 项单测，并通过 FastAPI、v1 delta、v2 tombstone smoke。

## Criteria Map

- v2 类型、ID、scope、时间及空 mutation 校验：由 core service tests 与 v2 smoke 覆盖。
- 原子 revision、重复 operationId、stale base 409：由 InMemory/Postgres 测试覆盖。
- nullable mutation metadata 与历史 v1 兼容：由 Postgres migration/query 和跨 schema replay 测试覆盖。
- 权威 graph、mutation 摘要和 change feed：由 API 测试及 v2 smoke 覆盖。
- 统一后端验证：全部通过。

## Execution Map

- 存储无关规则集中在 `knowledge_store.py`。
- InMemory 和 Postgres 各自在持有写锁/事务后检查幂等与 revision，再应用 v2 delta。
- 路由保持 v1 graph 入口，并对 v2 返回 additive metadata。

## Stress Test

- 验证同一 ID 跨实体类型不会误删。
- 验证 tombstone 与同 revision upsert 冲突时 upsert 胜出。
- 验证同 operationId 跨 v1/v2 重放仍返回首次持久化合同。
- 验证空 mutation、无时区删除时间与 `localOnly` 上行均被拒绝且不推进 revision。

## Residual Risk

- 尚未部署并跑线上 Postgres smoke；该风险由后续交付问题 P003 处理，不影响 P001 代码合同判定。

## Result IDs

- R000
