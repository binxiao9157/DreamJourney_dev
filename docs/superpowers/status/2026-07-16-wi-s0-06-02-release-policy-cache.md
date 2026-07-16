# WI-S0-06-02 TTL Policy Cache 与 Offline Deny

日期：2026-07-16
Work Item：`WI-S0-06-02`
状态：`IMPLEMENTED_SHADOW / G2_VERIFIED`
Decision：`CONTINUE_TO_WI-S0-06-03`
Execution owner：`codex-goal:019ece6b-2c15-7521-b160-c42e95d1dd5a`
Authority lock：`RELEASE_POLICY`
Lease：`ACQUIRED_AND_RELEASED`
Gate：`G0=PASS / G2=PASS`

## 1. 范围

本项在 `WI-S0-06-01` typed server snapshot 基础上增加 iOS shadow cache/evaluator，不改变公开 UI，不把旧 `FeatureFlagService` 值迁移成服务器授权，也不提前实施后续 command/route enforcement。

缓存 envelope 包含：

- `envelopeVersion/policySchemaVersion/policyVersion/policyRevision/emergencyRevision`；
- `accountOrAnonymousScope/appBuild`；
- `fetchedAt/expiresAt`；
- `payloadHash/payload`。

账号标识只保存 SHA-256 摘要，不保存原始 userId。认证账号以 `BackendAuthSessionStore.currentSession.userId` 为 scope 来源；无后端会话时使用独立 `anonymous` scope。App build 变化会形成新 scope，不沿用旧版本缓存。

## 2. Fail-closed 规则

- `fresh` 且 payload hash、schema、typed contract 全部有效：只允许 shadow evaluator 使用缓存。
- `missing/expired/clockSkew/corrupt/scopeMismatch/appBuildMismatch/unsupportedSchema/emergencyRevisionStale`：Future/Beta 和 Provider effect 均 `deny`。
- Owner 文字核心在缓存不可用时只允许 `readOnly`，不能产生外发或 Provider effect。
- 解析失败即 `cachedPolicyContractInvalid`，不能沿用旧 true。
- 旧全局持久化 feature flag 不会自动转换为 server allow。

## 3. 实现证据

- `ReleasePolicyStore.swift`：账号/build scope、TTL、payload integrity、clock skew、emergency revision 和风险降级。
- `DreamJourneyBackendClient.fetchReleasePolicy`：typed snapshot 成功后才写缓存。
- 请求发起时捕获 account/build scope；回调时账号已切换则丢弃旧响应，不把旧账号策略写入新账号。
- `DreamJourneyBackendClient.cachedReleasePolicyEvaluation`：返回 `state/accessMode/reason/version/revision/age/snapshot`，便于后续 gate 决策可解释。
- `release-policy-cache-model-smoke.swift`：覆盖账号切换、匿名隔离、App 升级、过期、时钟偏移、损坏、未知 schema、emergency revision 和按 scope 清理。
- `release-policy-cache-deployed-smoke.swift`：把线上 `/v2/release-policy` 响应写入真实 store 模型，验证 fresh、账号切换和 App 升级隔离。

## 4. 验证

- Cache model smoke：通过。
- Cache static contract guard：通过。
- Release QA package：通过。
- iOS Debug generic Simulator build：通过。
- 线上 deployed-to-cache smoke：通过，`policyVersion=release-policy-v1`、`revision=1`、`emergencyRevision=0`。
- 精简 release regression：通过，报告位于 `tmp/visual-qa/prd-stitch-ui/release-regression/20260716-wi-s0-06-02-final/report.md`。
- 相关文件 `git diff --check`：通过。

## 5. 边界与下一项

- 本项没有后端代码变化，服务器继续运行已部署的 `a15123c`。
- 本项没有接管 `FeatureFlagService`，不会改变现有公开三 Tab 或入口。
- `WI-S0-01-02` 后续引入正式 AccountSession scope 时，只替换 scope provider，不改变 cache envelope 合同。
- 下一 Work Item：`WI-S0-06-03`，建立 Future/Beta 默认关闭基线，清除 Release 默认开放的高风险功能。
