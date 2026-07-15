# WI-S0-03-02 Response Kill Switch 执行与验收记录

日期：2026-07-15
Work Item：`WI-S0-03-02`
状态：`COMPLETE`
Decision：`GO_FOR_REVERSIBLE_G0_G1_AND_AUTHORIZED_G2_DEPLOYMENT`
Execution owner：`codex-goal:019ece6b-2c15-7521-b160-c42e95d1dd5a`
Authority lock：`CREDENTIAL_CONTROL`
Lease：`RELEASED`

## 1. 依赖与授权

- `WI-S0-03-01` 已在 `ea910f0` 完成内部 scanner/Release gate，并保持资产 Owner、Provider 控制台和生产备份外部门阻断。
- 用户要求通过后自动进入本 Work Item，并授权后端变化按计划测试、提交、推送、部署和线上 smoke。
- Registry 静态基线仍显示 `STOP / UNASSIGNED / G2 MISSING`；本文件只记录当前长期任务的受限执行 overlay，不手改生成 Registry。

## 2. 允许范围

- 停止 `/digital-human/sessions` 返回腾讯长期 `appkey/accesstoken`。
- 停止 `/voice/realtime-token` 返回火山长期 `appToken/apiKey/appKey`。
- auth/provider/runtime response 增加 `Cache-Control: no-store` 等缓存边界。
- provider error、日志和 QA evidence 只保留 allowlisted metadata 或无值 hash。
- iOS 对 blocked capability 和旧 response 做安全降级，不恢复本地静态 credential fallback。

## 3. 禁止范围

- 不实现或伪造带 TTL/scope/audience/revoke 的 Provider broker credential。
- 不轮换、撤销、输出或提交任何真实 credential。
- 不因数字人或 realtime voice 被关闭而破坏 Owner 文字 Echo 核心。
- 不把本地单测提升为 Provider/真机完成证据。

## 4. Gate

内部实现必须通过 Backend 单测、API/header/error contract smoke、iOS static contract、Release artifact scanner、`git diff --check` 和适用构建。部署后必须补线上 G2 response/header smoke；Provider 控制台不属于本项。

## 5. 实现结果

### 5.1 Backend

- `/voice/realtime-token` 不再返回 `appToken/apiKey/appKey`，改为 `blockedStaticCredential` 的无值能力合同。
- `/digital-human/sessions` 不再返回腾讯 `appkey/accesstoken`，在真正 scoped credential broker 缺失时返回 `503 digital_human_credential_broker_unavailable`。
- `/config/runtime` 对 realtime voice 和 digital human 明确报告 `providerReady=false`、`releaseVisible=false` 和安全 fallback。
- auth、voice、digital-human、runtime、legacy TTS 和图像分析敏感响应统一增加 `Cache-Control: no-store` / `Pragma: no-cache`。
- Provider 原始 request/log/message 只以不可逆摘要或通用错误码出现在公开响应中。
- Backend 提交并推送：`1be115a security: block static credential responses`。

### 5.2 iOS

- 删除 shared backend token 和 provider 静态 credential 的运行时消费路径。
- `LocalConfig.plist` 构建注入改为明确 allowlist，只允许后端 Base URL，不再盲目合并 credential key。
- realtime voice / digital human 在 broker 缺失时显式降级为文字 Echo，不制造假 TTL，也不恢复本地静态凭据 fallback。
- voice synthesis QA 只解析 `providerLogIdHash/providerRequestIdHash`，不接收原始 Provider 引用。
- Release gate 增加 Product V4 credential response boundary 检查，并收敛旧版数字人/声音复刻 smoke 的静态凭据预期。

## 6. 验证证据

### 6.1 Backend G0/G1

- `scripts/verify_backend.sh`：通过。
- Backend unittest：`308` 项通过。
- Credential response boundary：`4` 项通过。
- FastAPI、voice clone contract、knowledge delta/v2/evidence/receipt maintenance smoke：通过。
- Backend `git diff --check`：通过。

### 6.2 iOS G0/G1

- 公开 release 静态回归：通过。
  - 报告：`tmp/visual-qa/prd-stitch-ui/release-regression/WI-S0-03-02-static/report.md`
  - 命令日志：`tmp/visual-qa/prd-stitch-ui/release-regression/WI-S0-03-02-static/commands.log`
- Release iPhoneOS generic build：通过。
  - DerivedData：`tmp/DerivedData/WI-S0-03-02`
  - 构建日志：`tmp/WI-S0-03-02-iphoneos-build.log`
- 精确 Release artifact boundary 检查：通过；包内不存在禁用 key label 或 LocalConfig secret value。
- 通用 WI-S0-03-01 scanner 对第三方二进制产生 `44` 个宽泛分类项；这些不是精确 credential 命中，不作为本项通过依据，原报告保留在：
  `tmp/visual-qa/prd-stitch-ui/credential-response-boundary/WI-S0-03-02/release-app-credential-inventory.json`。
- iOS `git diff --check`：通过。

### 6.3 线上 G2

- 服务器仓库 fast-forward 到 `1be115a`，只重建 `api`；Postgres、Redis 保持运行且 Postgres healthy。
- `BACKEND_BASE_URL=https://dreamjourney-api.liftora.cn scripts/run-backend-credential-response-deployed-smoke.sh`：通过。
- 数字人专项 deployed smoke：通过。
  - 报告：`tmp/visual-qa/prd-stitch-ui/backend-digital-human-session-smoke/WI-S0-03-02-deployed/report.md`
  - 结果：`tmp/visual-qa/prd-stitch-ui/backend-digital-human-session-smoke/WI-S0-03-02-deployed/backend-digital-human-session-smoke-result.json`
- 线上 Postgres 下 auth/runtime/realtime voice/digital-human 响应满足 `no-store + value-free + fail-closed`。

## 7. 完成定义与保留边界

- `WI-S0-03-02` 的 response kill switch、no-store 和公开日志 allowlist 已完成，G2 已验证。
- 未实现真正带 scope/TTL/audience/revoke 的 realtime voice / digital-human credential broker；依据计划停止条件，这两项移动端直连能力继续关闭。
- 本项没有把 Provider 控制台、密钥轮换或真机能力声明为完成；这些由后续 `WI-S0-03-04/05/07` 管理。
- 下一连续项：`WI-S0-03-03`，退役 mobile shared token 与旧 direct provider path；开始前重新取得 `CREDENTIAL_CONTROL` lease。
