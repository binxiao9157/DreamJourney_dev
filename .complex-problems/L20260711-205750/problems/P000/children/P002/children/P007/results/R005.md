# Receipt Maintenance 组合回归与运维边界结果

## Summary

已把 receipt 转换、Postgres 维护、privacy compatibility、change-feed 幂等屏障和 duplicate replay 固化为一条后端组合 smoke，并补齐 reader-first、dry-run-first 的生产运维说明。独立审查发现的脏 compact 扫描阻断已通过 P008 修复。

## Done

- 新增 `run-backend-knowledge-receipt-maintenance-smoke.sh`，覆盖转换、Postgres、privacy、change-feed、mutation/governance/archive duplicate。
- Smoke 校验 CLI 暴露 `--apply`/keep-days/batch-size，且 argparse 使用 store_true、默认不会 apply。
- `verify_backend.sh` 显式运行 receipt maintenance smoke。
- 新增后端运维文档，说明备份、reader-first 部署、dry-run 审阅、低峰 apply、二次幂等、WAL/vacuum 观察和回滚边界。
- P008 修复 dirty compact、空 operation ID 与用户发现分页完整性。

## Verification

- Receipt maintenance 组合 smoke 34 项通过。
- 后端完整 verify：304 项测试、FastAPI/knowledge smokes、py_compile 与 diff check 全部通过。
- CLI help 和脚本静态默认 dry-run 断言通过。

## Gaps

- 真实 Postgres dry-run/apply、锁/MVCC/JSONB 与实际空间证据留给 P003 部署验收。
- 跨仓 iOS release gate 和非真机构建尚未开始。

## Artifacts

- `scripts/run-backend-knowledge-receipt-maintenance-smoke.sh`
- `scripts/verify_backend.sh`
- `docs/backend/2026-07-11-knowledge-operation-receipt-maintenance.md`
- P008 R004/C005
