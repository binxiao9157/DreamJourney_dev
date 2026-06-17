# P0 真机与后端验收就绪包执行结果

## Summary

已完成真机与后端验收就绪包：新增验收说明、静态 guard，并更新 PRD 缺口图，将当前状态明确为“验收就绪”，而不是“真实后端已验收”或“真机已验收”。

## Done

- 新增 `docs/superpowers/status/2026-06-18-device-backend-acceptance-readiness.md`，覆盖真机验收、后端验收、阻塞条件、配置方式、运行命令、预期产物和验收边界。
- 新增 `tmp/visual-qa/prd-stitch-ui/device-backend-readiness-check.swift`，检查验收文档、Info.plist 隐私权限、后端配置注入、真实 token 忽略规则、后端 smoke 和档案到回响 smoke。
- 更新 `docs/superpowers/status/2026-06-18-prd-continuation-gap-map.md`，补充 persona scoping 完成状态，并引用真机/后端验收就绪文档。
- 按当前真实 `run-archive-to-echo-smoke.sh` 调整 guard，检查 `DJRunArchiveToEchoSmoke` 自运行 harness，而不是旧的种子参数。

## Verification

- RED: `swift tmp/visual-qa/prd-stitch-ui/device-backend-readiness-check.swift /Users/yxj/Documents/Codex/Video/DreamJourney_dev` 在验收说明缺失时失败，失败点为 `Device/backend acceptance readiness doc should exist`。
- GREEN: `swift tmp/visual-qa/prd-stitch-ui/device-backend-readiness-check.swift /Users/yxj/Documents/Codex/Video/DreamJourney_dev` 通过。
- GREEN: `swift tmp/visual-qa/prd-stitch-ui/backend-build-config-check.swift /Users/yxj/Documents/Codex/Video/DreamJourney_dev` 通过。
- GREEN: `swift tmp/visual-qa/prd-stitch-ui/backend-env-smoke-check.swift /Users/yxj/Documents/Codex/Video/DreamJourney_dev` 通过。
- GREEN: `swift tmp/visual-qa/prd-stitch-ui/submit-slice-inventory-check.swift /Users/yxj/Documents/Codex/Video/DreamJourney_dev` 通过。
- GREEN: `git diff --check` 通过。
- GREEN: `xcodebuild -workspace DreamJourney.xcworkspace -scheme DreamJourney -configuration Debug -sdk iphonesimulator -destination 'generic/platform=iOS Simulator' -derivedDataPath tmp/visual-qa/prd-stitch-ui/device-backend-readiness/20260618-current/DerivedData CODE_SIGNING_ALLOWED=NO build` 通过。

## Known Gaps

- 真实后端 smoke 尚未执行，因为需要用户提供真实 `DREAMJOURNEY_BACKEND_BASE_URL` 和 `DREAMJOURNEY_BACKEND_API_TOKEN`。
- 真机验收尚未执行，因为需要用户提供真机、签名和设备操作。
- 构建日志中仍有 Pods/Kingfisher 的 Swift 6 空格 warning，非本任务新增，也不影响本轮构建通过。

## Artifacts

- 验收说明：`docs/superpowers/status/2026-06-18-device-backend-acceptance-readiness.md`
- 静态 guard：`tmp/visual-qa/prd-stitch-ui/device-backend-readiness-check.swift`
- PRD 缺口图：`docs/superpowers/status/2026-06-18-prd-continuation-gap-map.md`
- 构建日志：`tmp/visual-qa/prd-stitch-ui/device-backend-readiness/20260618-current/build-debug.log`
