# Round 3C2B Typed API、Identity/AuthZ 与 Capability Rollout 方案

## Problem Definition

当前 iOS `DreamJourneyBackendClient` 以宽字典和未版本化 route 为主，`automatic` auth 可同时附 user session 与 shared API token；无 session 时还可能把 shared token 当 Bearer。后端手机号登录不是强证明，ownership shadow/fallback 与 system principal 仍存在；客户端 404/405/部分 400 又会切 legacy mutation。需要设计不产生第二 Authority、不会因错误响应 fail-open 的 typed `/v2`、Identity/AuthZ 和 capability 双轨 rollout。

## Proposed Solution

在 Product Spec 增加跨 iOS/后端 rollout 章：

1. 定义 `EndpointDescriptor`：domain/method/path/contractVersion/authMode/ownerBinding/idempotency/authority/fallbackPolicy/capabilityKey。
2. auth mode 仅允许 `publicChallenge/userRequired/delegatedGrant/machineOnly/operatorBreakGlass`；生产用户业务请求不再存在 `automatic/sharedTokenFallback`。
3. 新增按 Identity/Source/Memory/Conversation/DataRights/Optional 域的 typed V2 client；`DreamJourneyBackendClient` 变 LegacyFacadeClient/transport adapter。
4. RoutePolicy snapshot 在发送前固定 `legacyPrimary/v2ReadShadow/v2Canary/v2Primary/v2Only`；404/403/409/5xx/timeout/unknown schema 不改变该策略、不触发 legacy mutation。
5. V2 read shadow 只比较 canonical response；command shadow 只做 AuthZ/schema/expectedVersion dry-run。真实 command 在 authority cutover 后单写 V2，旧 route 转同一 use case/receipt；无稳定 command ID 的旧客户端 `upgrade_required`。
6. 强身份和 session 与 3C2A Actor 对接：challenge/verify、neutral response、refresh rotation/reuse、session CAS、revoke/logout/delete。
7. AuthZ route inventory 从当前 58 routes 收敛到 typed policy；production 未登记/evaluator error/fallback deny。Mirror/shadow decision 不得扩大实际访问，敏感 route 在真实流量前直接 enforce。
8. Capability/ReleasePolicy snapshot 包含 contract/data authority/policy/epoch/cohort/min client/TTL/四维成熟度/blocked reason，签名或受认证传输；optional 默认关闭。
9. 分 P00–P10 waves：inventory/schema tests、client credential eradication、strong identity、user-required transport、critical AuthZ enforce、read shadow/canary、command dry-run/cutover、optional modules 和 legacy retirement。

## Acceptance Criteria

- 当前 shared token、weak identity、route fallback、宽 DTO、owner binding 和 capability fail-open 证据完整。
- EndpointDescriptor、五类 auth mode、typed domain clients、route policy 和错误 fallback 规则明确。
- 用户 release 包不含 system/provider secret；built artifact 有 secret scan gate。
- challenge/verify/session/refresh/revoke 与 AccountLease/authorityEpoch 有明确 CAS 和错误合同。
- AuthZ route coverage、production deny、cross-vault 404、delegated/machine/data-rights authorization rollout 可执行。
- read shadow 与 command dry-run 不产生第二业务事实或 Provider 副作用。
- capability snapshot 字段、TTL、cohort、minimum client、four-axis maturity、emergency revoke 和 stricter offline fallback 明确。
- 至少 10 个 rollout waves、15 个身份/路由/AuthZ/capability/旧客户端场景。
- Evidence Matrix 和静态门禁明确 `DESIGNED/NOT_IMPLEMENTED`。

## Verification Plan

- 静态门禁检查 auth modes、route modes、禁止 error-driven fallback、credential removal、capability fields、waves 和场景。
- 对照当前 58 route/36 target endpoint，证明 route group 有迁移/退役路径。
- 独立 reviewer 攻击 404 fallback、shared token、refresh/session mismatch、cross-owner body、capability expiry、old client command 和 AuthZ evaluator failure。
- 运行 Product V4 全部门禁与 `git diff --check`。
- 本轮不修改后端/iOS生产代码、不部署；强身份 provider、真实 enforce、artifact secret scan 和 canary 属路线图实施证据。

## Risks

- 首发强身份 provider、min client 和旧客户端窗口尚未确认。
- 当前 LocalConfig 为 ignored 本地文件，是否进入 Release/CI 必须用产物扫描而不是 Git 搜索证明。
- 旧 route 无 stable commandId 时无法在 cutover 后提供安全重试，只能升级阻断或只读。
- AuthZ shadow 不能作为允许真实访问的安全默认，可能导致 rollout 速度低于“先观察再执行”的常规做法。

## Assumptions

- Round 3B 第 25 节 API/AuthZ 和 Round 3C1 authorityEpoch 是目标合同。
- Round 3C2A AccountSessionActor/Lease 是 iOS 请求身份来源。
- Owner 文字核心优先，optional feature/provider 失败不阻断核心 API rollout。
