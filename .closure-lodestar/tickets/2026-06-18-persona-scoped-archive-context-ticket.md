# P0 数字人上下文隔离档案与回响

## Problem Definition

PRD 要求切换到家人数字人或自己 AI 助手时，记忆档案页面、回响页面和后台专属档案数据库都调用对应的人。当前实现已有 `DigitalHumanContextStore`，但 `MemoryArchiveRepository` 的本地存储、上下文快照和后端 archive 请求仍按登录用户 `currentUserId` 绑定，存在未来家人切换后档案/回响数据串用的风险。

## Proposed Solution

先新增静态 guard `tmp/visual-qa/prd-stitch-ui/persona-scoped-archive-context-check.swift`，验证仓库必须使用 selected digital-human owner，而不是只用登录用户。确认 guard 在现状失败后，修改：

- `DigitalHumanContextStore.swift`：补充 viewer/user 归属、默认显示名、owner 选择通知和安全 fallback。
- `MemoryArchiveRepository.swift`：本地 storage key、context snapshot、backend list/post payload 改为 selected owner scope，并保留 `viewerUserId` 用于后端权限/审计。
- `EchoViewModel.swift`：继续从 repository 读取当前 owner 的 archive context，并在开始语音交互时刷新 selected context。

## Acceptance Criteria

- 默认 self assistant 仍使用当前登录用户作为 owner，兼容旧数据路径。
- 当 `DigitalHumanContextStore.current.ownerId` 指向家人/其他数字人时，archive storage key、context snapshot 和 backend archive path 使用该 owner。
- Backend archive payload 同时包含 `viewerUserId` 和 `ownerId`，避免后端只看到模糊 user id。
- Echo prompt context 间接受益于 repository owner scope，不需要暴露星辰/阳光模式名到回响 UI。
- 新增 guard 能证明上述源码合同。
- 现有 release gating 不变：family management 仍不公开，text/photo archive 默认仍公开，隐藏分支仍隐藏。

## Verification Plan

Red:

```bash
swift tmp/visual-qa/prd-stitch-ui/persona-scoped-archive-context-check.swift /Users/yxj/Documents/Codex/Video/DreamJourney_dev
```

Expected before implementation: fail because repository still uses only `currentUserId` for storage/backend archive scope.

Green:

```bash
swift tmp/visual-qa/prd-stitch-ui/persona-scoped-archive-context-check.swift /Users/yxj/Documents/Codex/Video/DreamJourney_dev
swift tmp/visual-qa/prd-stitch-ui/release-feature-matrix-check.swift /Users/yxj/Documents/Codex/Video/DreamJourney_dev
tmp/visual-qa/prd-stitch-ui/run-archive-to-echo-smoke.sh
git diff --check
```

Then run an iOS Debug simulator build before committing the P0 slice.

## Risks

- Backend endpoint names still use `userId`; this task will pass selected owner id through the existing path for compatibility and add explicit payload fields for backend evolution.
- Existing local data under the old self-user key is preserved only for default self assistant. Family/persona-specific data starts using the selected owner key.

## Assumptions

- Public family-management UI remains hidden until a later P1 task.
- Current selected owner is trusted local client state until a real backend family/persona authorization contract is available.
- This task does not implement account deletion, doctor contact, or public star/silent mode controls.
