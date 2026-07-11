# 跨仓库知识治理 QA 与交付收敛结果

## Summary

P013-P015 已共同完成 Task 16 的跨仓库 QA 和交付：后端 deterministic gate、iOS 日常/可选 release gate、两种通用构建、canonical/状态文档以及双仓本地提交均已收敛。

## Done

- R011：后端治理/source cascade runner，217 tests；后端 verify 243 tests。
- R012：iOS 公开 boundary、日常轻量 guard、`RUN_KNOWLEDGE_GOVERNANCE_GATE=1` 组合开关、Simulator 与 generic iPhoneOS 构建。
- R013：canonical/Task 16/状态文档、敏感信息与临时产物检查、后端 `3057ef9` 和 iOS `69306c1` 本地提交。
- 修复 route ownership 57 路由和时间信件组合删除架构对应的旧 QA 断言。

## Verification

- 子问题检查 C011、C012、C013 全部成功。
- release regression v4 成功；iOS/后端 diff check 在提交前通过。
- 未运行交互式模拟器、真机、线上部署或真实 Postgres，符合 Task 16 范围。

## Known Gaps

- 根 Closure Ledger 关闭后仍需提交最后的 ledger/docs-only 变更。
- 真实 Postgres deployed smoke 和公开治理 UI 是后续任务。

## Artifacts

- `scripts/run-backend-knowledge-governance-source-cascade-smoke.sh`
- `Scripts/QA/prd-stitch-ui/run-knowledge-governance-gate.sh`
- `docs/superpowers/status/2026-07-11-knowledge-governance-source-cascade.md`
- Backend `3057ef9`
- iOS `69306c1`
