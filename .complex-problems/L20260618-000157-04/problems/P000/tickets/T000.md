# P1 隐藏态家人 Persona 切换闭环

## Problem Definition

P0 已经完成 selected persona 对档案存储、后端 payload 和回响上下文的作用域隔离，但 Profile 里的 `家人管理` 仍停留在隐藏占位/旧 FamilyCircle 路由：

- 默认发布态正确隐藏 `家人管理`。
- QA 或后续发布打开 `familyManagement` / `familySpace` 后，页面没有把 FamilyRepository 的家人成员写入 `DigitalHumanContextStore`。
- 因此 P0 的 persona-scoped 数据契约还缺少一个可用的 UI 入口，无法形成“选择家人数字人 -> 档案/回响切到该 persona”的闭环。

本任务不公开家庭空间，不实现邀请/权限/家庭协作全量功能，只做隐藏 flag 后的 persona 切换最小闭环。

## Proposed Solution

实现一个小范围、release-gated 的 persona switcher：

- 保持 `familyManagement`、`familySpace` 默认隐藏。
- 在 `familyManagement` 可见但 `familySpace` 未开启时，继续展示安全占位提示。
- 在 `familyManagement` 与 `familySpace` 均开启时，进入隐藏态 family/persona 页面。
- 页面提供“自己 AI 助手”与 `FamilyRepository.shared.getAll()` 成员列表。
- 点击自己写入 `DigitalHumanContext.defaultContext(userId:)`。
- 点击家人成员写入 `DigitalHumanContext(viewerUserId: currentUser.id, ownerId: member.id, displayName: member.name, relation: member.relation, mode: .star, isSelfAssistant: false)`。
- `ProfileViewController` 监听 `djDigitalHumanContextDidChange`，默认视觉保持 Stitch 对齐；当选中非 self persona 时，persona 卡片文案反映当前家人数字人。
- 补静态 guard 验证默认隐藏、隐藏态入口、context 写入、通知刷新与 FamilyRepository 数据使用。

## Acceptance Criteria

- 默认 release flags 不包含 `familyManagement`、`familySpace`、`accountDeletion`、`careDoctorContact`。
- `家人管理` 仍只能通过 `DJEnableProfileHiddenBranches` 或 feature flags 暴露。
- `familySpace` 未开启时，`家人管理` 仍展示未开放安全提示。
- `familySpace` 开启后，进入可选择 self/family persona 的隐藏态页面。
- 选择 self 会恢复默认 `AI 助手` context。
- 选择 family member 会写入 `DigitalHumanContextStore`，并带上 `viewerUserId`、`ownerId`、`displayName`、`relation`、`.star`、`isSelfAssistant = false`。
- Profile persona 卡片会响应 `djDigitalHumanContextDidChange`，但默认 self 状态不破坏当前 Stitch 视觉。
- 新增或更新 guard 文档/脚本覆盖以上合约。

## Verification Plan

- 先新增 `tmp/visual-qa/prd-stitch-ui/profile-family-persona-switcher-check.swift`，运行并确认在实现前失败。
- 实现隐藏态 persona switcher 和 Profile 刷新逻辑。
- 运行：
  - `swift tmp/visual-qa/prd-stitch-ui/profile-family-persona-switcher-check.swift /Users/yxj/Documents/Codex/Video/DreamJourney_dev`
  - `swift tmp/visual-qa/prd-stitch-ui/group4-profile-care-check.swift /Users/yxj/Documents/Codex/Video/DreamJourney_dev`
  - `swift tmp/visual-qa/prd-stitch-ui/release-feature-matrix-check.swift /Users/yxj/Documents/Codex/Video/DreamJourney_dev`
  - `swift tmp/visual-qa/prd-stitch-ui/submit-slice-inventory-check.swift /Users/yxj/Documents/Codex/Video/DreamJourney_dev`
  - `git diff --check`
- 跑 iOS Debug 模拟器构建。
- 如果 UI 变化较明显，再跑隐藏态模拟器烟测截图；默认发布态视觉不应变化。

## Risks

- 旧 `FamilyCircleViewController` 视觉与当前 Stitch 不完全一致，因此必须保持隐藏，不进入默认发布态。
- 家庭邀请、权限、成员管理、删除成员不在本任务范围，避免误公开半成品。
- 选择 family persona 后的真实后端数据仍依赖后端环境；本任务只保证本地 context 和 UI 路由。

## Assumptions

- `FamilyRepository.shared.getAll()` 可作为隐藏态 persona 列表的数据源。
- family persona 默认使用 `.star` 模式，后续星辰/阳光/静默完整业务状态再单独推进。
- 当前默认 self 视觉继续以 Stitch 画布为准，不为了显示 `AI 助手` 改掉默认 profile 首屏文案。
