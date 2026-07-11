# 线上 Receipt Apply、幂等与关联 Smoke 验收

## Summary

P016 验收通过。历史 receipt 已完成最小化，幂等、身份保持、新 writer 和相邻知识维护合同均有线上 Postgres 证据。

## Evidence

- 首次 apply 更新 12 条且失败为 0。
- Before/after 聚合身份一致，result 占用减少 13012 字节。
- 第二次 dry-run/apply 和 post-smoke dry-run 均为零候选/零更新。
- 部署知识 smoke、privacy dry-run、change-feed dry-run 全部成功。

## Criteria Map

- Apply 状态与更新数：12 条候选全部更新，满足。
- Identity/hash 保持：count、byKind、identityHash 不变，满足。
- 存储不增加：15408 降至 2396 字节，满足。
- 二次幂等：candidate=0、updated=0，满足。
- 关联回归：三项 smoke/maintenance 均通过，满足。
- 脱敏报告与状态文档：已保存并更新，满足。

## Execution Map

- P015 dry-run 硬门后执行一次小 batch apply。
- Apply 后立即聚合验证，再执行两次幂等命令。
- 主链路 smoke 后额外复查新 receipt writer。

## Stress Test

- `keep-days=0` 扫描所有线上 receipt。
- 部署知识 smoke 在迁移后创建新 sync/mutation receipt，再验证全部 18 条均已 compact。
- Privacy maintenance 同时扫描 snapshot、change 和 receipt，确认 compact V2 不产生无效记录。

## Residual Risk

- 大规模数据下可能需要 `created_at` 索引，但当前真实扫描无超时且数据量很小。索引应由后续容量证据驱动。

## Result IDs

- `T016` 对应执行结果。
