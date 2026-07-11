# iOS 知识治理 Release QA 组合 Gate 结果

## Summary

已将知识治理基础设施纳入日常 release QA，并新增 `RUN_KNOWLEDGE_GOVERNANCE_GATE=1` 跨仓库组合开关。公开 UI 由独立 boundary guard 保护，完整 regression 已通过 Simulator workspace 与 generic iPhoneOS 非签名构建。

## Done

- 新增 `knowledge-governance-release-boundary-check.swift`，扫描公开 `Modules`/`App`，禁止调用 `performGovernance` 或暴露治理入口文案。
- 新增 `run-knowledge-governance-gate.sh`，组合 iOS governance/model/client/outbox/coordinator/merge/context 检查与后端 217-test runner。
- release regression 默认运行 governance model/client/coordinator/boundary 轻量 guard。
- 新增 `RUN_KNOWLEDGE_GOVERNANCE_GATE`，并写入 report configuration、scope 和 evidence。
- release QA package 声明全部新增资产并检查组合调用关系。
- 修正治理路由加入后 route ownership guard/deployed smoke 的路由总数 56 -> 57，并增加 `/kb/governance/actions` owner deny 覆盖。
- 修正时间信件生命周期 guard，使其识别新的共享 `archive_store` 和组合删除事务架构。

## Verification

- governance cross-repository gate 通过，iOS 八条检查和后端 217 tests 通过。
- release QA package check 通过。
- release regression `20260711-task16-knowledge-governance-v4` 通过。
- iOS Debug Simulator workspace build 通过。
- generic iPhoneOS 无签名 build 通过。
- backend verify 243 tests 通过。
- iOS/后端 `git diff --check` 在 regression 中通过；新增 report 文案修订后 QA package 与局部 diff check 再次通过。

## Known Gaps

- 未运行交互式模拟器 smoke、真机或部署态 Postgres，符合本问题非真机、本地 gate 范围。
- v4 report 生成时 route audit scope 文案仍写 56；脚本随后已改为 57，功能 guard 和 deployed smoke 均已按 57 通过。

## Artifacts

- `Scripts/QA/prd-stitch-ui/knowledge-governance-release-boundary-check.swift`
- `Scripts/QA/prd-stitch-ui/run-knowledge-governance-gate.sh`
- `Scripts/QA/prd-stitch-ui/run-release-regression.sh`
- `Scripts/QA/prd-stitch-ui/release-qa-package-check.swift`
- `tmp/visual-qa/prd-stitch-ui/release-regression/20260711-task16-knowledge-governance-v4/report.md`
- `tmp/visual-qa/prd-stitch-ui/release-regression/20260711-task16-knowledge-governance-v4/iphoneos-generic-build/20260711-task16-knowledge-governance-v4/report.md`
