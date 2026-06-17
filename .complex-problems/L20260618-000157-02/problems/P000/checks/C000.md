# Persona-scoped archive context check

## Summary

P0 数字人/persona owner 作用域任务已完成。Archive 本地存储、Archive 后端 fetch/sync payload、Echo archive prompt context 的源头现在都围绕 selected `DigitalHumanContext.ownerId` 工作，默认 self assistant 路径仍通过核心 smoke。

## Evidence

- `persona-scoped-archive-context-check.swift` 通过。
- `release-feature-matrix-check.swift` 通过。
- `submit-slice-inventory-check.swift` 通过。
- `git diff --check` 通过。
- iOS Debug Simulator build 日志包含 `** BUILD SUCCEEDED **`。
- Archive-to-Echo smoke result 为 `completed=true` 且 `containsArchiveContext=true`。

## Criteria Map

- 默认 self assistant 仍使用当前登录用户作为 owner：`DigitalHumanContext.defaultContext(userId:)` 设置 `viewerUserId` 和 `ownerId` 为当前 user id。
- family/other owner 可作用于 archive storage/backend/context：`MemoryArchiveRepository.currentArchiveOwnerId` 来自 `DigitalHumanContextStore.shared.current.ownerId`。
- Backend payload 包含 viewer 与 owner：`syncToBackend` 写入 `viewerUserId` 和 `ownerId`。
- Echo 不暴露内部模式名：本任务未改变 Echo UI 的 mode 展示面，release matrix 仍通过。
- 新 guard 证明源码合同：`persona-scoped-archive-context-check.swift` 通过。
- release gating 不变：`release-feature-matrix-check.swift` 通过。

## Execution Map

- 先写 RED guard，确认实现前失败在缺少 `viewerUserId`。
- 修改 `DigitalHumanContextStore.swift`。
- 修改 `MemoryArchiveRepository.swift`。
- 修复 guard 自身的 macOS 15 deprecation warning。
- 补充 P0 QA report。
- 运行构建与核心 smoke。

## Stress Test

- 核心 smoke 在默认 self assistant 路径下仍能 seed archive、进入 Echo、注入 archive context，证明 owner-scope 没有破坏当前 MVP 主链路。

## Residual Risk

- 真实 family/persona switcher UI 尚未公开实现，后续 P1 才会写入非默认 owner。
- 后端仍需验证 `viewerUserId`/`ownerId` 的鉴权与持久化合同。
- 真机麦克风、照片和语音 SDK 验收仍属后续 P0 readiness。

## Result IDs

- `R000`
