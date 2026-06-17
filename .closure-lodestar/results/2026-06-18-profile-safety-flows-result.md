# P1 Profile 安全流程壳与 Care 可见性执行结果

## Summary

已完成 P001：Profile 风险入口仍保持隐藏，但隐藏态下从普通占位升级为安全壳；`心境追踪` 可见性也集中到明确 helper，默认 self 视觉不变，family `.star` persona 可显示 care dashboard。

## Done

- 新增 `ProfileViewController.shouldShowCareDashboard(context:)`。
- `buildContent()` 与 `loadCareSnapshot()` 改为使用 care visibility helper。
- 默认 self assistant 继续显示 care dashboard，保持当前 Stitch/profile 视觉。
- 非 self family persona 仅在 `.star` 模式下显示 care dashboard。
- `注销账户` hidden action 改为 `showAccountDeletionConfirmation()`：
  - destructive confirmation shell。
  - 明确当前不会执行删除。
  - destructive action disabled。
  - 不调用 logout/local delete/backend delete。
- `立即通话` hidden action 改为 `showDoctorContactSafetyNotice()`：
  - 非紧急。
  - 不是医疗诊断。
  - 紧急情况指向当地急救服务。
  - 真实联系契约未接入。
- 新增 `profile-safety-flow-check.swift`。
- 更新 release matrix、PRD gap map、状态文档和 group4 guard。

## Verification

- RED: `swift tmp/visual-qa/prd-stitch-ui/profile-safety-flow-check.swift /Users/yxj/Documents/Codex/Video/DreamJourney_dev` 在实现前失败，失败点为缺少 `shouldShowCareDashboard(context:)`。
- GREEN: `swift tmp/visual-qa/prd-stitch-ui/profile-safety-flow-check.swift /Users/yxj/Documents/Codex/Video/DreamJourney_dev` 通过。
- GREEN: `swift tmp/visual-qa/prd-stitch-ui/profile-family-persona-switcher-check.swift /Users/yxj/Documents/Codex/Video/DreamJourney_dev` 通过。
- GREEN: `swift tmp/visual-qa/prd-stitch-ui/group4-profile-care-check.swift /Users/yxj/Documents/Codex/Video/DreamJourney_dev` 通过。
- GREEN: `swift tmp/visual-qa/prd-stitch-ui/release-feature-matrix-check.swift /Users/yxj/Documents/Codex/Video/DreamJourney_dev` 通过。
- GREEN: `swift tmp/visual-qa/prd-stitch-ui/submit-slice-inventory-check.swift /Users/yxj/Documents/Codex/Video/DreamJourney_dev` 通过。
- GREEN: `git diff --check` 通过。
- GREEN: `xcodebuild -workspace DreamJourney.xcworkspace -scheme DreamJourney -configuration Debug -sdk iphonesimulator -destination 'generic/platform=iOS Simulator' -derivedDataPath tmp/visual-qa/prd-stitch-ui/profile-safety-flows/20260618-current/DerivedData CODE_SIGNING_ALLOWED=NO build` 通过。

## Known Gaps

- 账号注销真实删除流程仍未实现，需产品/法务/后端确认后才能开放。
- 医生联系真实通话/升级流程仍未实现，需产品/后端/紧急情况策略确认。
- Full sunlight/star/silent mode management 仍待后续任务推进。
- 构建日志仍有已知第三方 warning，非本任务新增。

## Artifacts

- Guard: `tmp/visual-qa/prd-stitch-ui/profile-safety-flow-check.swift`
- Status doc: `docs/superpowers/status/2026-06-18-profile-safety-flows.md`
- Build log: `tmp/visual-qa/prd-stitch-ui/profile-safety-flows/20260618-current/build-debug.log`
