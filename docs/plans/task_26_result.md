# Task 26 Knowledge Operation Receipt 保留与最小化结果

## Summary

Knowledge operation receipt 已从重复保存完整 graph/mutation 正文改为最小 compact envelope，同时保持 operation identity、payload fingerprint、duplicate/conflict 语义和四类操作重放合同。历史线上数据已完成安全压缩。

## Done

- P001 完成 compact writer、legacy/full 双读和安全重放。
- P002 完成历史转换、privacy 兼容、Postgres dry-run/apply 和运维 CLI。
- P003 完成跨仓 gate、release QA、提交部署和真实 Postgres 收口。

## Verification

- 后端 304 项全量测试及组合 smoke 通过。
- 默认 release regression、Simulator smoke 和 generic iPhoneOS build 通过。
- 线上 12 条 legacy receipt 已压缩，15 条身份保持；部署 smoke 后 18 条全部 compact。
- 线上二次 dry-run/apply 为零变更，知识主链路和相邻维护回归通过。

## Known Gaps

- `created_at` 索引仅在数据规模和查询计划证明需要时再增加。
- 无真机证据；Task 26 不依赖真机。

## Artifacts

- `docs/superpowers/status/2026-07-11-knowledge-operation-receipt-minimization.md`
- `docs/backend/2026-07-11-knowledge-operation-receipt-maintenance.md`
- `tmp/visual-qa/prd-stitch-ui/knowledge-receipt-postgres/20260711-task26/`
