# WI-S0-03-03 Mobile Shared Token 与 Direct Provider Path 退役记录

日期：2026-07-15
Work Item：`WI-S0-03-03`
状态：`COMPLETE`
Decision：`GO_FOR_REVERSIBLE_G0_G1_AND_AUTHORIZED_G2_ARTIFACT_VALIDATION`
Execution owner：`codex-goal:019ece6b-2c15-7521-b160-c42e95d1dd5a`
Authority lock：`CREDENTIAL_CONTROL`
Lease：`RELEASED`

## 1. 依赖与执行 overlay

- `WI-S0-03-01` 已由 `ea910f0` 建立无值 credential inventory gate。
- `WI-S0-03-02` 已由 `a15ba2b` 完成 iOS response boundary，并由 Backend `1be115a` 完成部署和线上 G2。
- Registry 静态记录仍为 `STOP / UNASSIGNED / G2 MISSING`，且列出 `WI-S0-02-03/06` 依赖；本项不修改生成 Registry，只在既有 user auth session、ownership shadow/audit 基础上执行可逆的移动端 containment。
- 不在本项开启任何 Provider 能力；若后续 scoped broker 依赖未满足，移动端 realtime voice / digital human 保持 blocked。

## 2. 当前小闭环

- 删除 Xcode target 中 backend shared token 和火山静态 credential build setting。
- 删除示例、本地忽略配置中的移动端 shared/provider credential 注入指导和值。
- 删除 DialogEngine 的公开 direct token 注入入口，并收紧 credential-bearing SDK config 可见性。
- 保留 QA 进程环境中的系统 token，用于脚本直接访问后端；不得写入 App/Info.plist/xcconfig artifact。
- 新增 source/local-config/Release artifact 静态 guard，并接入 release QA。

## 3. 禁止范围

- 不发明 scoped credential broker 或伪造 TTL/scope/audience/revoke。
- 不删除后端 `.env` 中仅服务端使用的 Provider credential。
- 不在本项重写旧 QA deployed smoke；遗留 build-injection 脚本由 `WI-S0-03-06` 集中退役。
- 不改变产品 UI、Echo 视觉或与 credential containment 无关的业务模块。

## 4. 实施结果

- Xcode Debug/Release target 已移除 backend shared token 和火山 Provider credential build setting。
- `Backend.example.xcconfig` 与 `VoiceSDK.example.xcconfig` 已改为 broker-only 边界，不再指导把 shared/provider credential 注入 iOS。
- `DialogEngineManager` 已移除公开 `configure(token:)`，credential-bearing config 收紧为私有实现；broker 未开放时明确保持文字回响。
- 本机被 Git 忽略的 `LocalConfig.plist`、`Backend.local.xcconfig`、`VoiceSDK.local.xcconfig` 已按键名清理，未将任何值写入记录或提交。
- 新增 `product-v4-mobile-credential-path-retirement-check.py`，覆盖源码、工程设置、本地忽略配置和 Release `.app` 产物。
- 新 gate 已接入 `run-release-regression.sh` 和 release QA package 清单。

## 5. 验证证据

- Product V4 mobile credential retirement source/local guard：通过。
- Product V4 credential response boundary guard：通过。
- Backend voice runtime 与 iOS voice SDK readiness guard：通过。
- Release QA package guard：通过。
- Release 静态回归：通过。
  - 报告：`tmp/visual-qa/prd-stitch-ui/release-regression/WI-S0-03-03-static/report.md`
  - 命令记录：`tmp/visual-qa/prd-stitch-ui/release-regression/WI-S0-03-03-static/commands.log`
- iPhoneOS Release generic build：通过。
  - App：`tmp/DerivedData/WI-S0-03-03/Build/Products/Release-iphoneos/DreamJourney.app`
  - 日志：`tmp/WI-S0-03-03-iphoneos-build.log`
- Release `.app` mobile credential retirement artifact guard：通过。
- Release `.app` credential response boundary artifact guard：通过。
- `git diff --check`：通过。

## 6. Gate 与后续边界

- 本项没有后端代码变化，不需要再次部署；`WI-S0-03-02` 已部署的 Backend `1be115a` 继续作为 response kill switch 前置条件。
- G2 artifact validation 已由 Release `.app` 双重扫描满足。
- scoped broker 尚未实现，realtime voice / digital human credential path 继续保持 blocked，不回退到移动端静态密钥。
- 下一连续 Work Item：`WI-S0-03-06`，集中退役遗留 QA build-injection/direct credential path。
