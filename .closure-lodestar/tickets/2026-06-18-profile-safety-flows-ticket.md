# P1 Profile 安全流程壳与 Care 可见性

## Problem Definition

Task 4 的隐藏态 family/persona switcher 已经完成，但 profile safety flows 仍有三个 P1 缺口：

- `注销账户` 在隐藏态下仍是普通占位 alert，没有 destructive confirmation shell 或合规边界说明。
- `立即通话` 在隐藏态下仍是普通占位 alert，没有非紧急、非医疗诊断、安全求助边界。
- `心境追踪` 仅按 `careDashboard` feature flag 显示，没有结合 selected persona/mode 做显式判断。

这些都是高风险入口，必须继续隐藏或安全降级，不能为了补 PRD 文案而公开未完成能力。

## Proposed Solution

- 保持默认 release flags 不变，继续隐藏 `accountDeletion`、`careDoctorContact`、`familyManagement`、`familySpace`。
- 在 `ProfileViewController` 中新增 `shouldShowCareDashboard(context:)`：
  - `careDashboard` 关闭时不显示。
  - 默认 self assistant 继续显示，保持当前 Stitch/profile 视觉。
  - family persona 仅在 `.star` 模式下显示，为后续星辰亲属心理支持闭环留出显式契约。
- 将 hidden `accountDeletion` action 改为 `showAccountDeletionConfirmation()`：
  - 使用 destructive confirmation shell。
  - 文案说明当前不会执行删除，需要完整合规流程。
  - 不调用删除 API、不清本地数据、不破坏兼容。
- 将 hidden `doctorCallTapped` 改为 `showDoctorContactSafetyNotice()`：
  - 文案说明非紧急、不是医疗诊断、真实联系契约未接入。
  - 紧急情况提示用户联系当地急救服务。
- 新增 `profile-safety-flow-check.swift` 覆盖上述合约，并更新状态文档。

## Acceptance Criteria

- 默认 release flags 仍只包含 `careDashboard`、`profileSettings`、`legalCenter`。
- `accountDeletion` 与 `careDoctorContact` 仍默认隐藏，仅 hidden branch 或 feature flag 可见。
- `showAccountDeletionConfirmation()` 存在，包含 destructive action 和“不执行删除/合规流程”边界，不调用 `logout()`、删除 UserDefaults 或后端删除接口。
- `showDoctorContactSafetyNotice()` 存在，包含“非紧急”“不是医疗诊断”“急救服务”“真实联系契约未接入”等安全文案。
- `shouldShowCareDashboard(context:)` 存在，并由 `buildContent()` 与 `loadCareSnapshot()` 使用。
- 默认 self assistant 仍可显示 care dashboard；family persona 通过 `.star` 显示 care dashboard。
- 新 guard、既有 Profile/release guard、提交清单、`git diff --check` 和 iOS Debug 构建通过。

## Verification Plan

- 先新增 `tmp/visual-qa/prd-stitch-ui/profile-safety-flow-check.swift` 并运行 RED。
- 实现 Profile safety flow shells 和 care visibility helper。
- 运行：
  - `swift tmp/visual-qa/prd-stitch-ui/profile-safety-flow-check.swift /Users/yxj/Documents/Codex/Video/DreamJourney_dev`
  - `swift tmp/visual-qa/prd-stitch-ui/profile-family-persona-switcher-check.swift /Users/yxj/Documents/Codex/Video/DreamJourney_dev`
  - `swift tmp/visual-qa/prd-stitch-ui/group4-profile-care-check.swift /Users/yxj/Documents/Codex/Video/DreamJourney_dev`
  - `swift tmp/visual-qa/prd-stitch-ui/release-feature-matrix-check.swift /Users/yxj/Documents/Codex/Video/DreamJourney_dev`
  - `swift tmp/visual-qa/prd-stitch-ui/submit-slice-inventory-check.swift /Users/yxj/Documents/Codex/Video/DreamJourney_dev`
  - `git diff --check`
- 跑 iOS Debug 模拟器构建。

## Risks

- 账号注销和医生联系都是高风险功能，必须保持“安全壳”而非真实执行。
- Care 可见性不能破坏默认 self/Profile Stitch 视觉，因此 self assistant 必须保留当前 care dashboard。
- Full family permissions、真实医生联系、真实账号删除仍需要产品/法务/后端确认。

## Assumptions

- `.star` 是 family persona 心理支持/care dashboard 的默认可见模式。
- 默认 self assistant 保留 `careDashboard` 是当前 UI/PRD 闭环的发布态需求。
- 本任务只实现可验证的安全边界，不引入数据删除、外呼或紧急服务集成。
