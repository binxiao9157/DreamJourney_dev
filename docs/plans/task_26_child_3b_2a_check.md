# Reader-first 部署验收

## Summary

P013 已成功。线上运行目标 reader 提交，服务与既有 knowledge 主链路正常，且未提前执行 receipt apply。

## Evidence

- 服务器 rev-parse 为 `4c0538b`。
- Compose 状态 API/Redis Up、Postgres healthy。
- Health 200/store=postgres，runtime kbSync=true。
- Deployed smoke 同时证明 V2、幂等、冲突、分页和 generation context。

## Criteria Map

- 目标提交：满足。
- 服务健康：满足。
- Runtime/knowledge smoke：满足。
- 未执行 apply：满足。
- 私密配置未输出到提交/报告：满足。

## Execution Map

- R009 记录部署与 smoke 结果。

## Stress Test

- Deployed smoke 使用真实 Postgres 创建两次 revision、同 operation retry、异 payload conflict 和分页中追加 revision，覆盖 reader/writer 关键兼容性。

## Residual Risk

- Receipt maintenance SQL/JSONB apply 尚待 P014。

## Result IDs

- R009
