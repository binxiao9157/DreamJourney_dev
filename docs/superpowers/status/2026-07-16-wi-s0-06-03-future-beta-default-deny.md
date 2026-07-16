# WI-S0-06-03 Future/Beta 默认关闭基线

日期：2026-07-16
Work Item：`WI-S0-06-03`
状态：`IMPLEMENTED / G0_VERIFIED`
Decision：`CONTINUE_TO_WI-S0-06-04`
Execution owner：`codex-goal:019ece6b-2c15-7521-b160-c42e95d1dd5a`
Authority lock：`RELEASE_POLICY`
Lease：`ACQUIRED_AND_RELEASED`
Gate：`G0=PASS / G1-G4=OPEN`

## 1. Closed Pilot 基线

iOS Release 本地默认集合固定为：

- `echoTextInput`
- `profileSettings`
- `legalCenter`
- `accountDeletion`

以下能力保留代码、模型、后端合同和 QA 壳层，但不再因旧 PRD、旧 `UserDefaults`、Provider 可用或历史真机证据而默认公开：

- Family / Family Space / Care；
- TimeLetter / Persona；
- Voice Clone / Digital Human；
- 音频、视频、远端档案和本地分析；
- 密码修改、医生联系、Echo 图片输入。

## 2. 实现

- `FeatureFlagService.currentStorageVersion` 升级到 `11`，清除旧版本持久化的高风险 true。
- Future/Beta feature 全部进入 `nonPersistentFeatures`；Release 构建不能通过 `set` 或 `enableForCurrentLaunch` 打开。
- 当前进程 override 只在 `DEBUG` 或 `UI_QA_SIMULATOR` 编译条件下生效。
- Family、Family Space、Voice Clone readiness 改为 `hiddenReady`。
- TimeLetter readiness 改为 `hiddenReady`，创建、封存、投递和 mailbox 合同继续保留。
- 腾讯数字人 launch argument 收口到 QA-only helper；Release 只读取默认关闭的 feature flag。
- 档案首页的“语音档案”卡片改为 gate 打开后才创建，避免隐藏媒体仍以分类入口误露。
- Release feature matrix 改为 V4 Closed Pilot 的 `public-core / hidden` 双层口径。

## 3. QA 与回归

新增 `future-beta-default-deny-check.swift`，并接入：

- `run-release-regression.sh`；
- `release-qa-package-check.swift`。

同步修正历史 QA 脚本，使其分别验证：

1. 功能实现仍存在；
2. readiness 和入口受 gate 保护；
3. feature 不在 Release 默认集合；
4. QA override 不形成持久化发布 Authority。

## 4. 验证结果

- Future/Beta default-deny guard：通过。
- Release feature matrix guard：通过。
- 受影响的 Archive/Profile/TimeLetter/Voice Clone/Digital Human guards：通过。
- Release QA package：通过。
- Backend local verify：通过。
- iOS 与 Backend `git diff --check`：通过。
- 可安装模拟器构建、安装和延迟回信通知 smoke：通过。
- 完整静态 release regression：通过。

报告：

`tmp/visual-qa/prd-stitch-ui/release-regression/20260716-wi-s0-06-03-static-final/report.md`

## 5. 后端和外部门

- 本项没有后端代码变化，不需要重新部署。
- 已部署后端 `a15123c` 的 `ReleasePolicySnapshot` 已对 Family、Care、TimeLetter、Voice Clone、Digital Human 和隐藏媒体返回 deny；本项让 iOS 本地基线与其一致。
- 产品、Privacy、Provider 和真机相关 `G1-G4` 保持开放，不能由本项自动关闭。

## 6. 下一项

下一 Work Item：`WI-S0-06-04`。

目标是让 UI route 与 backend command 使用同一 captured policy decision，并在真实 effect 前重验撤销；本项只完成 default-off，不提前宣称深链、旧页面或异步重试已被 command gate 覆盖。
