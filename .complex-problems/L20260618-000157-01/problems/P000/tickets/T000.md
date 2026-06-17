# PRD 缺口与优先级台账

## Problem Definition

当前分支已经完成一轮 Stitch UI 与 PRD MVP 适配，但最新 PRD 的剩余业务目标还没有被整理成持续开发用的 P0/P1/P2 台账。后续如果直接继续编码，容易重复处理已经完成的 UI/QA 问题，或者把家人管理、账号注销、医生通话等尚未具备产品合同的入口过早公开。

## Proposed Solution

完整读取最新 PRD、当前 `docs/superpowers` 状态文档、当前代码中的 Echo/Archive/Profile/Backend/FeatureFlag 实现，整理一份新的 PRD 功能执行台账。台账需要明确已完成能力、剩余缺口、P0/P1/P2 优先级、当前建议推进的小闭环，以及对应验证命令。台账保存到 `docs/superpowers/status/2026-06-18-prd-continuation-gap-map.md`，并成为后续自动选择任务的依据。

## Acceptance Criteria

- 台账覆盖 PRD 中的回响、记忆档案馆、设置管理、长辈关怀、生死转换机制。
- 台账区分已实现、待收敛、暂隐藏、需要真机/后端验收的能力。
- P0/P1/P2 的排序遵循用户给出的优先级：核心闭环、真实测试/真机验收、持久化/隐私/错误恢复、UI/交互、文档/证据。
- 台账明确下一步实施目标，且不得选择已经被现有 guard 证明完成的重复任务。
- 台账列出本阶段必须运行的验证脚本或构建命令。

## Verification Plan

运行 `swift tmp/visual-qa/prd-stitch-ui/submit-slice-inventory-check.swift /Users/yxj/Documents/Codex/Video/DreamJourney_dev`，确认新增台账文件被归类为 durable docs 或明确可提交文档。运行 `git diff --check`，确认文档无空白问题。

## Risks

- PRD 对“星辰/阳光/静默”模式的发布范围仍有产品取舍风险，台账只能先按“不公开内部模式名，但保留业务状态”处理。
- 真机和真实后端验收依赖设备、账号、key、服务地址，台账只能区分可自动验证与需要用户提供环境的项。

## Assumptions

- 当前分支提交 `0f64248` 是本轮持续推进的基线。
- Stitch UI 仍以当前画布和 `htmlCode` 为准，MCP screenshot 只作辅助。
- 未完成高风险功能继续通过 feature flag 或 UIQA launch argument 隐藏，直到产品合同和安全确认状态完成。
