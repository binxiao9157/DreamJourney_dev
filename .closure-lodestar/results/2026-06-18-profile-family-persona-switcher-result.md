# P1 隐藏态家人 Persona 切换闭环执行结果

## Summary

已把隐藏态 `家人管理` 路由从占位推进为可用的 persona switcher。默认发布态仍不公开 family/persona 管理；只有显式开启 `familyManagement` 与 `familySpace` 后，才能进入选择 self/family 数字人的隐藏页面。

## Done

- `ProfileViewController` 监听 `.djDigitalHumanContextDidChange` 并重建内容。
- Profile persona card 默认 self 状态继续显示 Stitch 文案 `外面世界很美好` / `今天又是阳光灿烂的一天`，非 self persona 才显示家人数字人文案。
- `FamilyCircleViewController` 改为隐藏态 persona switcher：
  - 包含 `AI 助手` self option。
  - 使用 `FamilyRepository.shared.getAll()` 作为 family option。
  - 点击 self 写入 `DigitalHumanContext.defaultContext(userId:)`。
  - 点击 family member 写入 `DigitalHumanContextStore.shared.current`，包含 viewer、owner、displayName、relation、`.star` 和 `isSelfAssistant = false`。
- 新增 `profile-family-persona-switcher-check.swift` 静态 guard。
- 更新 release feature matrix、PRD gap map 和本轮状态文档。
- 更新提交清单分类，将 `DreamJourney/Sources/Modules/Family/` 纳入 profile/family/safety 分组。

## Verification

- RED: `swift tmp/visual-qa/prd-stitch-ui/profile-family-persona-switcher-check.swift /Users/yxj/Documents/Codex/Video/DreamJourney_dev` 在实现前失败，失败点为 Profile 未监听 `.djDigitalHumanContextDidChange`。
- GREEN: `swift tmp/visual-qa/prd-stitch-ui/profile-family-persona-switcher-check.swift /Users/yxj/Documents/Codex/Video/DreamJourney_dev` 通过。
- GREEN: `swift tmp/visual-qa/prd-stitch-ui/group4-profile-care-check.swift /Users/yxj/Documents/Codex/Video/DreamJourney_dev` 通过。
- GREEN: `swift tmp/visual-qa/prd-stitch-ui/release-feature-matrix-check.swift /Users/yxj/Documents/Codex/Video/DreamJourney_dev` 通过。
- GREEN: `swift tmp/visual-qa/prd-stitch-ui/submit-slice-inventory-check.swift /Users/yxj/Documents/Codex/Video/DreamJourney_dev` 通过。
- GREEN: `git diff --check` 通过。
- GREEN after one compile fix: `xcodebuild -workspace DreamJourney.xcworkspace -scheme DreamJourney -configuration Debug -sdk iphonesimulator -destination 'generic/platform=iOS Simulator' -derivedDataPath tmp/visual-qa/prd-stitch-ui/profile-family-persona-switcher/20260618-current/DerivedData CODE_SIGNING_ALLOWED=NO build` 通过。

## Known Gaps

- Public family management remains hidden and is not ready for release.
- Family invite, access control, member deletion, and backend family sync acceptance are not included.
- `.star` is the default family persona mode for now; full sunlight/star/silent mode management remains a later P1/P2 task.
- Build log still contains existing third-party/asset warnings unrelated to this slice.

## Artifacts

- Guard: `tmp/visual-qa/prd-stitch-ui/profile-family-persona-switcher-check.swift`
- Status doc: `docs/superpowers/status/2026-06-18-profile-family-persona-switcher.md`
- Build log: `tmp/visual-qa/prd-stitch-ui/profile-family-persona-switcher/20260618-current/build-debug.log`
