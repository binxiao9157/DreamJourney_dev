# WI-S0-01-03 Refresh Session/Generation CAS 证据

## 结论

- 状态：`VERIFIED / G0_G2_POSTGRES_DEPLOYED / IOS_LOCAL_COMMITTED`
- iOS 实现提交：`f175858 feat(WI-S0-01-03): bind refresh to account generation`
- 后端实现提交：`e879ead feat(WI-S0-01-03): harden refresh lineage CAS`
- 后端 QA 修正提交：`e1125eb`、`af8a482`、`a57b380`
- 服务器部署：`main@a57b380`
- iOS 分支按长期目标要求未推送；本项没有新增公开入口或改变现有 UI。

## 实现合同

1. iOS refresh attempt 在发起时捕获不可变 `AccountSessionRefreshLease`：
   - `subjectId / vaultId`
   - `sessionId / tokenFamilyId / sessionVersion`
   - `generation / generationId`
2. 并发 401 对相同 session 与 generation 使用 single-flight；不同 generation 不合并。
3. refresh 响应仅在以下条件同时成立时写入 Keychain：
   - 原 lease 仍属于当前 active/activating actor。
   - subject、vault 和 token family 未变化。
   - session id 已旋转。
   - `sessionVersion == capturedVersion + 1`。
   - Keychain 当前值仍匹配原 session CAS identity。
4. Keychain replace 与 actor lineage adoption 在 `AccountSessionActor` 串行边界内提交；切号、登出、暂停或旧响应不能覆盖新账号。
5. terminal refresh 错误只清理匹配 lease 的 session，并旋转 actor generation；不影响后来登录的账号。
6. refresh 收到 recovery policy 时只更新 runtime authority/epoch，不在网络回调中绕过 actor 清理认证会话；原业务请求通过现有 private-access suspend 通知统一进入 actor 生命周期。
7. 后端 public session 返回 `subjectId` 与 refresh `parentSessionId`。iOS 校验 subject、parent、family 和精确版本递增。
8. Postgres rotation 对 session 和 token family 都执行 owner/family/expected-version CAS；reuse 仍原子吊销整个 token family。

## 验证

### iOS G0

以下检查均通过：

- `Scripts/QA/product-v4/run-account-session-refresh-cas-gate.sh`
- `Scripts/QA/product-v4/run-token-family-client-model-smoke.sh`
- `Scripts/QA/product-v4/run-account-session-actor-gate.sh`
- `Scripts/QA/product-v4/run-account-store-inventory-gate.sh`
- `product-v4-ios-typed-auth-cutover-check.py`
- `product-v4-ios-account-store-rollout-check.py`
- `git diff --check`

模型覆盖：成功旋转、旧响应、登出竞态、A 切 B、错误 family、跳版本和 terminal reuse 清理。

### iOS 构建

- Debug generic iOS Simulator：通过。
  - `/tmp/DreamJourney-WI-S0-01-03-debug.log`
- Release generic iPhoneOS，`CODE_SIGNING_ALLOWED=NO`：通过。
  - `/tmp/DreamJourney-WI-S0-01-03-release.log`
- 本项三个 Swift 文件没有新增 warning；日志中仅保留既有 Pods、腾讯/地图二进制和旧 UI API warning。

### 后端 G0

- `scripts/run-backend-auth-refresh-contract-gate.sh`：通过。
- `tests.test_auth_sessions + tests.test_postgres_store`：`91 tests / OK`。
- `python3 -m compileall -q app scripts tests`：通过。
- `git diff --check`：通过。

### 后端 G2

- 服务器：`/opt/services/dreamjourney/DreamJourneyBackend@a57b380`
- 数据库：Postgres。
- `/ready`：`auth/database/schema = ready`。
- 容器内一次性 QA session 经真实 HTTP `/auth/refresh` 验证：
  - `contractVersion=2`
  - `sessionVersion=2`
  - 旧 refresh 重放：`refresh_token_reuse_detected`
  - 后继 access 在 family revoke 后被拒绝
- 生产已关闭 legacy phone login；部署 smoke 在容器内通过既有 `AuthSessionService` 生成一次性 QA session，不开放调试 API、不输出 token，也不放宽生产身份策略。

## 边界

- 本项证明 refresh lineage、generation CAS、Postgres rotation/reuse 合同和线上部署，不证明短信 OTP Provider 或外部隐私/安全评审。
- 逐业务 surface 的 request/commit/UI/timer/provider lease checkpoint 不属于本项，进入 `WI-S0-01-04`。
- Registry 继续保持保守计划视图；实现证据只写入 current handoff。

## 下一项

`WI-S0-01-04 AccountLease checkpoints`：为异步 request、store commit、UI application、timer 与 provider runtime effect 建立统一 owner/generation/authority checkpoint，阻止切号、登出、后台恢复和晚到回调提交旧账号数据或 UI。
