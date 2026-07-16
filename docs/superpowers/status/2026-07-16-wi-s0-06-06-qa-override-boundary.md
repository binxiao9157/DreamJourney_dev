# WI-S0-06-06 QA Override Debug-only 与非持久化

日期：2026-07-16
Work Item：`WI-S0-06-06`
状态：`IMPLEMENTED / G0_VERIFIED / G2_VERIFIED`
Execution owner：`codex-goal:019ece6b-2c15-7521-b160-c42e95d1dd5a`
Authority lock：`RELEASE_POLICY`
Lease：`RELEASED`

## 1. 目标与边界

- QA override 只允许在 Debug 或 `UI_QA_SIMULATOR` 当前进程生效。
- Release iPhoneOS 产物不得包含 QA launch argument、QA setter 或本地 Provider 素材 override。
- 生产后端不得接受客户端伪造的 `audience=qa` 来放宽发布策略。
- 不修改三 Tab、Stitch 视觉、公开入口或现有业务数据。

## 2. 已实现

- `FeatureFlagService.enableForCurrentLaunch` 仅在 Debug/UIQA 编译，临时 feature 只保存在进程内存。
- UIQA remote-fetch 启用改用进程级 setter，不再调用持久化 setter。
- Archive、Profile、Echo diagnostics、Tencent drive smoke 和本地素材 override 的 launch argument 均由编译条件隔离。
- 删除正式 `Info.plist` 中的 `DreamJourneyDigitalHumanAssetVirtualmanKey`；Debug/UIQA 临时素材通过 `DREAMJOURNEY_DIGITAL_HUMAN_ASSET_VIRTUALMAN_KEY` 进程环境变量提供，并仍需显式 QA launch argument。
- 新增 `run-release-qa-override-artifact-scan.sh`，构建 `Release + iphoneos` 后扫描可执行文件、符号和 `Info.plist`。
- Release handoff 强制运行产物扫描，不能通过关闭普通 generic build 绕过。
- 后端将 `qa` audience 限制为非生产环境的 system principal；生产请求统一降级为 owner。
- deployed command smoke 使用伪造 QA audience 调用 owner core，再验证隐藏 family command 仍为 deny/observeDeny。

## 3. 验证入口

- 静态边界：`swift Scripts/QA/prd-stitch-ui/qa-override-release-boundary-check.swift`
- Release 产物：`Scripts/QA/prd-stitch-ui/run-release-qa-override-artifact-scan.sh`
- Backend unit：`.venv/bin/python -m unittest tests.test_release_policy`
- Backend full：`./scripts/verify_backend.sh`
- Backend deployed：`scripts/run-backend-release-policy-command-deployed-smoke.sh`
- 一键 handoff：`RELEASE_HANDOFF_MODE=1 Scripts/QA/prd-stitch-ui/run-release-regression.sh`

## 4. 当前证据

- Backend full verify：335 tests，FastAPI、credential、knowledge smoke 全部通过。
- iOS 静态边界检查：通过。
- Release iPhoneOS build 与产物扫描：通过。
- 产物报告：`tmp/visual-qa/prd-stitch-ui/release-qa-override-artifact/20260716-wi-s0-06-06-release-artifact/report.md`。
- Release executable 不含 QA launch argument 和 `enableForCurrentLaunch` 符号。
- Release `Info.plist` 不含本地腾讯素材 override。
- Profile Family/Voice UIQA：通过；普通 flag 在 capability 未公开时 fail closed，hidden QA arg 仍可打开内部壳层。
- UIQA 报告与截图：`tmp/visual-qa/prd-stitch-ui/profile-family-persona-release-smoke/20260716-wi-s0-06-06-uiqa-rerun/`。
- Release regression：`tmp/visual-qa/prd-stitch-ui/release-regression/20260716-wi-s0-06-06-static-rerun/report.md`。
- Backend commit：`55d60bc security(WI-S0-06-06): isolate QA policy overrides`，已推送和部署。
- 线上 `/health`：`production/postgres`；deployed smoke：`forgedQA=owner core=allow hidden=observeDeny`。

## 5. Gate 状态

- G0：`PASS`。源码边界、Release artifact 与本地 backend contract 均已验证。
- G2：`PASS`。后端已部署到线上 Postgres 环境，伪造 QA audience 不能改变 owner core 或 hidden feature 判定。
- G3/G4：本 Work Item 无新增外部 Provider 或产品验收要求，不自行签署。

## 6. 后续

- `RELEASE_POLICY` lease 已释放；公开发布边界保持 fail closed。
- 下一 Work Item：`WI-S0-06-07 Public Release Scope Regression Gate`。
