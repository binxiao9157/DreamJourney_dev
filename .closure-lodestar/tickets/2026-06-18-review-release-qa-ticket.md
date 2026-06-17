# Review And Release QA 收敛包

## Problem Definition

当前分支已经完成 P0/P1 多个闭环，但还需要一个 release QA 收敛包来回答：

- 当前 PRD 核心闭环是否仍通过。
- 默认发布态是否仍隐藏未完成/高风险功能。
- 真机/真实后端还缺哪些用户提供条件。
- 本分支有哪些提交、验证产物和剩余风险。

不能只依赖零散 build log 或口头说明；需要可复跑命令、机器检查和一份明确 handoff 文档。

## Proposed Solution

- 运行当前分支的 durable static guards：
  - release feature matrix
  - profile family persona switcher
  - profile safety flows
  - group4 profile/care
  - persona-scoped archive context
  - device/backend readiness
  - backend build/env smoke contract guards
  - submit slice inventory
- 运行核心闭环 simulator smoke：`run-archive-to-echo-smoke.sh`。
- 运行 `git diff --check` 和 iOS Debug build。
- 新增 release QA handoff 文档，记录：
  - 最新提交范围。
  - 已验证命令。
  - smoke 结果路径和截图路径。
  - 真机/后端待用户提供条件。
  - PRD/UI 仍未公开的功能边界。
- 如果某个检查失败，先修复当前分支问题；如果需要用户提供真实后端 token 或真机操作，则记录为阻塞边界，不伪装通过。

## Acceptance Criteria

- `run-archive-to-echo-smoke.sh` 通过，并产出 `archive-to-echo-smoke-result.json` 与截图。
- 所有本阶段相关 static guards 通过。
- `git diff --check` 通过。
- iOS Debug build 通过。
- 新增 `docs/superpowers/status/2026-06-18-release-qa-handoff.md`，列出验证命令、结果、产物路径、剩余风险和下一步。
- Task 5 ledger 达到 `next_action=none`。
- 不提交临时截图、build log、DerivedData 或 Stitch cache。

## Verification Plan

Run:

```bash
swift tmp/visual-qa/prd-stitch-ui/release-feature-matrix-check.swift /Users/yxj/Documents/Codex/Video/DreamJourney_dev
swift tmp/visual-qa/prd-stitch-ui/profile-family-persona-switcher-check.swift /Users/yxj/Documents/Codex/Video/DreamJourney_dev
swift tmp/visual-qa/prd-stitch-ui/profile-safety-flow-check.swift /Users/yxj/Documents/Codex/Video/DreamJourney_dev
swift tmp/visual-qa/prd-stitch-ui/group4-profile-care-check.swift /Users/yxj/Documents/Codex/Video/DreamJourney_dev
swift tmp/visual-qa/prd-stitch-ui/persona-scoped-archive-context-check.swift /Users/yxj/Documents/Codex/Video/DreamJourney_dev
swift tmp/visual-qa/prd-stitch-ui/device-backend-readiness-check.swift /Users/yxj/Documents/Codex/Video/DreamJourney_dev
swift tmp/visual-qa/prd-stitch-ui/backend-build-config-check.swift /Users/yxj/Documents/Codex/Video/DreamJourney_dev
swift tmp/visual-qa/prd-stitch-ui/backend-env-smoke-check.swift /Users/yxj/Documents/Codex/Video/DreamJourney_dev
swift tmp/visual-qa/prd-stitch-ui/submit-slice-inventory-check.swift /Users/yxj/Documents/Codex/Video/DreamJourney_dev
tmp/visual-qa/prd-stitch-ui/run-archive-to-echo-smoke.sh
git diff --check
xcodebuild -workspace DreamJourney.xcworkspace -scheme DreamJourney -configuration Debug -sdk iphonesimulator -destination 'generic/platform=iOS Simulator' CODE_SIGNING_ALLOWED=NO build
```

## Risks

- Simulator smoke may take time and may expose environment-specific simulator issues.
- Real backend smoke cannot run without user-provided backend URL/token.
- True-device acceptance cannot run without user device/signing.
- Existing third-party warnings may remain; they should be recorded if build succeeds.

## Assumptions

- Current PRD core loop remains `记忆档案 -> 回响 -> 心境/关怀` with incomplete branches hidden.
- Stitch visual source of truth remains current canvas + `htmlCode`; simulator screenshots are supporting evidence only.
- Generated QA artifacts stay local unless they are machine-readable result summaries intentionally committed.
