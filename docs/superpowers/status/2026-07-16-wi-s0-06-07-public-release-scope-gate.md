# WI-S0-06-07 Public Release Scope Regression Gate

日期：2026-07-16
Work Item：`WI-S0-06-07`
状态：`IMPLEMENTED / G0-G1-G2_VERIFIED / G4_OPEN`
Execution owner：`codex-goal:019ece6b-2c15-7521-b160-c42e95d1dd5a`
Authority lock：`RELEASE_POLICY`
Lease：`RELEASED`

## 1. 目标

- 一键证明 Closed Pilot Owner 文字核心仍可用。
- 一键证明 Product MVP/Beta Extension 的默认入口、route、deep link 和 command 绕过数均为零。
- 覆盖 policy missing/offline、expired、emergency revoke 和 QA route-only 边界。
- 证据包只记录 build、policy、feature、route、command 计数与决定，不记录正文、手机号、凭据或请求 body。

## 2. 实施范围

- G0：typed policy model、Release feature matrix、Release iPhoneOS artifact。
- G1：无 QA compilation condition 的 Release simulator，合成 Owner 默认入口截图与四个隐藏 deep-link 负向探测。
- G2：部署环境 owner policy、unknown feature、伪造 QA audience、公开核心 command 和隐藏 command 负向 smoke。
- G4：保留真实设备回归，不作为本组合 Gate 的代码完成条件。

## 3. 入口

- 本地：`Scripts/QA/prd-stitch-ui/run-public-release-scope-regression.sh`
- 含线上 G2：`RUN_BACKEND_G2=1 BACKEND_BASE_URL=... BACKEND_API_TOKEN=... Scripts/QA/prd-stitch-ui/run-public-release-scope-regression.sh`
- Release handoff：`RELEASE_HANDOFF_MODE=1 Scripts/QA/prd-stitch-ui/run-release-regression.sh`

## 4. 完成结果

- `G0`：typed policy model、Release feature matrix、Release iPhoneOS artifact scan 全部通过。
- `G1`：使用 `Release + RELEASE_SCOPE_SIMULATOR` 构建可安装模拟器包；未启用 `DEBUG` 或 `UI_QA_SIMULATOR`。普通 Owner 默认入口截图仅展示普通 Echo 和三个公开 Tab，四个隐藏 deep link 均无法打开。
- `G2`：线上 `production/postgres` 通过公开核心 command、隐藏 command、unknown feature 和伪造 QA audience 负向 smoke；伪造 QA audience 仍按 Owner 处理，不能绕过发布策略。
- `G4`：真实设备 fresh install、upgrade、offline/expired 和交互回归保持开放，不由本次非真机闭环冒充完成。
- Product MVP/Beta 隐藏入口、route、command bypass 计数均为 `0`。
- 证据包只包含 build/policy/feature/route/command 决策和计数，不包含正文、手机号、凭据或请求 body。

## 5. 部署与证据

- 后端提交及部署版本：`1af76e9 test(WI-S0-06-07): add public release scope smoke`
- 线上健康状态：`production / postgres`
- 最终组合报告：`tmp/visual-qa/prd-stitch-ui/public-release-scope-regression/20260716-wi-s0-06-07-final/report.md`
- 脱敏证据包：`tmp/visual-qa/prd-stitch-ui/public-release-scope-regression/20260716-wi-s0-06-07-final/public-release-scope-evidence.json`
- 默认入口截图：`tmp/visual-qa/prd-stitch-ui/public-release-scope-regression/20260716-wi-s0-06-07-final/uiqa/01-owner-default-entry.png`
- Release iPhoneOS artifact 报告：`tmp/visual-qa/prd-stitch-ui/public-release-scope-regression/20260716-wi-s0-06-07-final/release-artifact/report.md`

## 6. 边界

- `RELEASE_SCOPE_SIMULATOR` 仅隔离无法在模拟器链接的 AMap/语音 Provider SDK，不启用 QA 路由、QA setter、QA launch arg 或隐藏业务功能。
- iOS 本地 Tencent asset override 继续仅允许 Debug/UIQA 当前进程使用，Release 包内不得持久化。
- `G4` 真机证据完成前，不得宣称真实设备发布验收完成。
