# Persona-scoped archive context result

## Summary

已完成 P0 数字人/persona owner 作用域改造：当前选中的 `DigitalHumanContext.ownerId` 现在会驱动 archive 本地存储、archive 后端拉取、archive 后端同步 payload，并让 Echo 继续通过 repository snapshot 获取当前 owner 的档案上下文。

## Done

- 新增 `persona-scoped-archive-context-check.swift`，并按 TDD 先验证现状失败。
- `DigitalHumanContext` 增加 `viewerUserId`、`resolvedDisplayName`、`normalizedForCurrentViewer`。
- `DigitalHumanContextStore.current` 兼容旧 self context，同时允许当前登录 viewer 选择不同 owner。
- `DigitalHumanContextStore` 在 context 变更后发送 `djDigitalHumanContextDidChange`。
- `MemoryArchiveRepository` 增加 `currentArchiveOwnerId`，storage key 改为 selected owner scope。
- `refreshFromBackend` 使用 selected owner id。
- `syncToBackend` payload 同时带 `viewerUserId` 与 `ownerId`。
- 新增 P0 QA report。

## Verification

- RED: `persona-scoped-archive-context-check.swift` 在实现前失败，缺少 `viewerUserId`。
- GREEN: `swift tmp/visual-qa/prd-stitch-ui/persona-scoped-archive-context-check.swift /Users/yxj/Documents/Codex/Video/DreamJourney_dev` 通过。
- `swift tmp/visual-qa/prd-stitch-ui/release-feature-matrix-check.swift /Users/yxj/Documents/Codex/Video/DreamJourney_dev` 通过。
- `swift tmp/visual-qa/prd-stitch-ui/submit-slice-inventory-check.swift /Users/yxj/Documents/Codex/Video/DreamJourney_dev` 通过。
- `git diff --check` 通过。
- iOS Debug Simulator build 通过，日志：`tmp/visual-qa/prd-stitch-ui/persona-scoped-archive-context/20260618-current/build-debug.log`。
- Archive-to-Echo smoke 通过，结果：`tmp/visual-qa/prd-stitch-ui/archive-to-echo-smoke/20260618-001554/archive-to-echo-smoke-result.json`。

## Known Gaps

- 还没有公开 family/persona switcher UI；这是 P1 任务，当前只建立底层 owner-scope 合同。
- 真实后端仍需验证如何授权 `viewerUserId` 访问 `ownerId` 的 archive；当前 payload 已为该合同预留字段。
- 真机麦克风/照片/语音 SDK 验收仍在后续 P0 readiness 任务。

## Artifacts

- `tmp/visual-qa/prd-stitch-ui/persona-scoped-archive-context-check.swift`
- `tmp/visual-qa/prd-stitch-ui/persona-scoped-archive-context/20260618-current/report.md`
- `tmp/visual-qa/prd-stitch-ui/persona-scoped-archive-context/20260618-current/build-debug.log`
- `tmp/visual-qa/prd-stitch-ui/archive-to-echo-smoke/20260618-001554/archive-to-echo-smoke-result.json`
