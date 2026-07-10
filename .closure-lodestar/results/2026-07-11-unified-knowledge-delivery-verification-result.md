# 统一知识管线跨仓库验证与交付结果

## Summary

已完成统一知识管线的跨仓库非真机验收、部署态 smoke 固化和状态文档收敛。后端 revision/change-feed/generation 合同与 iOS 用户隔离、同步、提取、Echo turn-scoped RAG 均纳入可重复回归门。

## Done

- 后端新增本地 knowledge delta smoke 和部署态 knowledge pipeline smoke；`verify_backend.sh` 纳入脚本编译与基础知识合同验证。
- iOS 新增 `knowledge-pipeline-check.swift`，并接入 release QA package。
- release regression 新增 `RUN_BACKEND_KNOWLEDGE_PIPELINE_SMOKE=1` 可选部署态门，不影响默认公开 MVP 回归。
- Archive payload 补齐 generationAllowed 隐私元数据与 source reference，使 Archive -> Echo 后端上下文链路可通过权限过滤。
- 更新 Task 12、实现计划索引和统一知识管线状态文档，记录兼容边界、部署命令和后续风险。

## Verification

- 后端 `scripts/verify_backend.sh`：182 tests、py_compile、FastAPI smoke、voice contract、knowledge delta smoke、diff check 全部通过。
- 部署态 knowledge smoke 在本地 FastAPI 等价环境通过：登录、revision sync、幂等 mutation、change feed、generation context/hash、409 conflict。
- iOS `RUN_IPHONEOS_GENERIC_BUILD=1 Scripts/QA/prd-stitch-ui/run-release-regression.sh` 通过。
- iOS 回归包含模拟器 Debug、generic iPhoneOS、Archive -> Echo smoke 与延迟回信通知 smoke。
- Archive -> Echo 结果为 `containsArchiveContext=true`；延迟回信通知 pending request 合同通过。
- 两仓库 `git diff --check` 通过。

## Artifacts

- `tmp/visual-qa/prd-stitch-ui/release-regression/20260711-002316-release-regression/report.md`
- `tmp/visual-qa/prd-stitch-ui/release-regression/20260711-002316-release-regression/archive-to-echo-smoke/20260711-002316-release-regression/01-archive-to-echo-completed.png`
- `docs/superpowers/status/2026-07-11-unified-knowledge-pipeline.md`
- 后端 `docs/backend/2026-07-11-unified-knowledge-contract-deployment.md`

## Known Gaps

- 线上部署态 smoke 尚需在服务器更新后使用真实 Postgres/token 再执行。
- 火山 Dialog ChatRagText 语义吸收仍需真机验收。
- change feed 分页、保留/压缩和向量检索属于 P1/P2，不在本轮范围。
