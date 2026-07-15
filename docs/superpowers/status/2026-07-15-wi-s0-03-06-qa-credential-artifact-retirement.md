# WI-S0-03-06 QA Credential Artifact Path 退役记录

日期：2026-07-15
Work Item：`WI-S0-03-06`
状态：`COMPLETE`
Decision：`GO_FOR_REVERSIBLE_G0_G1_AND_AUTHORIZED_G2_ARTIFACT_VALIDATION`
Execution owner：`codex-goal:019ece6b-2c15-7521-b160-c42e95d1dd5a`
Authority lock：`CREDENTIAL_CONTROL`
Lease：`RELEASED`

## 1. 依赖与执行 overlay

- `WI-S0-03-01` 已建立无值 credential inventory/scanner。
- `WI-S0-03-02` 已完成后端 response kill switch/no-store，并通过线上 G2。
- `WI-S0-03-03` 已移除正式 Xcode target、示例配置和本机忽略配置中的 mobile shared/provider credential 注入。
- Registry 静态记录仍为 `STOP / UNASSIGNED / G2 MISSING`；本项不手工修改生成 Registry，以本记录承载 owner、lease、证据和完成状态。

## 2. 当前小闭环

- 清理 `project.yml` 中会在工程重新生成后复活的 credential build setting。
- 清理模拟器/真机 QA 脚本中把 backend system token 或火山 Provider credential 写入 `.app` 的路径。
- 保留后端直连 smoke 的进程级系统 token；它只用于测试服务器 API，不得进入移动端 artifact。
- scoped broker 或用户 session fixture 不存在时，依赖旧 mobile injection 的 QA 必须明确 blocked，不得静默回退或伪造能力。
- 新增 source + generated project + script + Release artifact guard，并接入 release QA。

## 3. 禁止范围

- 不创建临时长期 token、伪 broker、伪 TTL/scope/audience/revoke。
- 不删除后端 `.env` 或 backend-only smoke 所需的 Provider/system credential。
- 不改变产品 UI、Echo 视觉、Provider 业务逻辑或无关模块。
- 不把工作区中的过程 ledger、任务草稿和其他未关联改动纳入提交。

## 4. 实施结果

- `project.yml` 已删除 backend shared token 与火山 Provider credential setting，重新生成工程不会复活旧路径。
- 共享模拟器安装器会拒绝带退役 credential key 的 xcconfig，并在安装前扫描 `.app`/`.appex` 的 Info.plist 与可执行文件。
- backend env、档案分析重试、关怀状态、声音复刻、腾讯 PCM mock、数字人 runtime stub 等 UIQA 构建不再注入 server compatibility token。
- 真机语音与档案音频 preflight 只接收非敏感 backend base URL 和本机签名配置，不再读取 `VoiceSDK.local.xcconfig` 或移动端 Provider credential。
- 关怀失败重试改用不可达后端验证，不再生成 invalid-token App。
- 数字人 runtime stub 已按当前 Stop Condition 收敛：scoped broker 不存在时验收 `scopedBrokerRequired`、`blockedUntilScopedBroker` 和 `textOnly` fallback，不再期望伪造 `backend-issued-mock` credential。
- `DialogEngineManager` 已移除具体火山 placeholder key-name 字符串，Release 二进制不再保留这些移动端 credential surface。
- 新增 `product-v4-qa-mobile-credential-artifact-check.py`，并接入 release regression 与 release QA package。

## 5. 验证证据

- 测试先行：新 guard 初次运行准确拦截 `project.yml` 的四个遗留 credential setting。
- Shell 语法检查：所有本项修改的 QA runner 通过 `bash -n`。
- Product V4 QA mobile credential artifact source guard：通过。
- Product V4 mobile credential path retirement guard：通过。
- Product V4 credential response boundary guard：通过。
- Release QA package check：通过。
- 数字人 broker-blocked runtime UIQA smoke：通过。
  - 目录：`tmp/visual-qa/prd-stitch-ui/digital-human-runtime-stub-smoke/WI-S0-03-06-runtime-stub-v2/`
  - 结果：`digital-human-runtime-stub-smoke-result.json`
  - 截图：`01-digital-human-runtime-stub.png`
- Release 静态回归：通过。
  - 报告：`tmp/visual-qa/prd-stitch-ui/release-regression/WI-S0-03-06-static-v5/report.md`
  - 命令记录：`tmp/visual-qa/prd-stitch-ui/release-regression/WI-S0-03-06-static-v5/commands.log`
- iPhoneOS Release generic build：通过。
  - App：`tmp/DerivedData/WI-S0-03-06/Build/Products/Release-iphoneos/DreamJourney.app`
  - 日志：`tmp/WI-S0-03-06-iphoneos-build.log`
- Release `.app` + Widget `.appex` credential key-name/Info.plist/binary scan：通过。
- Release `.app` 既有 mobile retirement 与 response boundary artifact guard：通过。
- `git diff --check`：通过。

## 6. Gate 与后续边界

- 本项没有后端代码变化，不需要推送、部署或线上 smoke；Backend `1be115a` 的 response kill switch 继续作为前置条件。
- G2 artifact validation 已由 Release `.app/.appex` 三重扫描满足。
- backend-only smoke 可继续在进程环境中使用 server compatibility token，但任何移动端 build setting、plist、binary 和 QA export 均不得包含它。
- scoped broker 尚未实现，realtime voice / digital human 继续保持 blocked；不以 mock credential 越过 Stop Condition。
- 下一连续 Slice：`WI-S0-03-04/05/07`，先从 `WI-S0-03-04` 评估正式 realtime voice broker/proxy 路径。
