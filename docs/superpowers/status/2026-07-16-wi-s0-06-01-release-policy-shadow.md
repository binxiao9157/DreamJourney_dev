# WI-S0-06-01 Typed Server ReleasePolicySnapshot

日期：2026-07-16
Work Item：`WI-S0-06-01`
状态：`IMPLEMENTED_SHADOW / DEPLOYED`
Decision：`CONTINUE_TO_WI-S0-06-02`
Execution owner：`codex-goal:019ece6b-2c15-7521-b160-c42e95d1dd5a`
Authority lock：`RELEASE_POLICY`
Lease：`ACQUIRED_AND_RELEASED`
Gate：`G0=PASS`

## 1. 范围

本项只建立服务器权威 ReleasePolicy 的 typed shadow 合同，不改变现有公开 UI、三 Tab、`FeatureFlagService` 或 command 行为。真正的 account/app-version cache、offline/expired deny 和 UI route enforcement 由 `WI-S0-06-02..04` 继续完成。

后端新增：

- `ReleasePolicySnapshot`：`schemaVersion/policyVersion/policyRevision/issuedAt/expiresAt/minClient/emergencyRevision/audience/cohort/source/shadowMode/snapshotDecision/features`。
- 每个 feature 明确返回 `enabled/releaseVisible/audience/cohort/requiredGates/reason`。
- `GET /v2/release-policy`，匿名可读取、`no-store`、无 credential 字段。
- Unknown feature、低版本客户端、emergency revoke 和 client-known revision 高于 server 时均 fail closed。
- `/config/runtime.releasePolicy` 只暴露 value-free endpoint/版本/TTL 描述，不把 runtime capability 当成 release allow。

iOS 新增：

- `BackendReleasePolicySnapshot` 与 `BackendReleasePolicyFeatureDecision` typed consumer。
- 严格 schema/date/source/feature 解析；合同异常不产生 allow。
- 过期或未知 feature 返回本地 deny decision。
- `fetchReleasePolicy(...)` 只做 shadow 读取，不接管 `FeatureFlagService`。

## 2. 部署证据

- Backend commit：`a15123c`。
- Remote：`origin/main@a15123c`。
- Server：`/opt/services/dreamjourney/DreamJourneyBackend@a15123c`。
- 容器：只 rebuild/recreate `api`；Postgres、Redis 保持运行。
- Health：`https://dreamjourney-api.liftora.cn/health` 返回 `status=ok`、`environment=production`、`store=postgres`。
- Deployed ReleasePolicy smoke：typed shadow、Closed Pilot allowlist、unknown deny、revision downgrade 409、value-free/no-store 全部通过。
- Deployed route ownership smoke：`routeCount=59`、`unclassifiedCount=0`、owner/system deny 通过。

## 3. 验证

- Backend：`319` 项 unittest 通过。
- Backend：credential boundary、FastAPI、knowledge delta/V2/evidence/receipt maintenance smoke 通过。
- Backend：本地 HTTP ReleasePolicy smoke 通过。
- iOS：`release-policy-shadow-contract-check.swift` 通过。
- iOS：Debug generic Simulator build 通过。
- Release regression：`20260716-090001-release-regression` 通过；模拟器业务 smoke 按本 Work Item 范围关闭，静态 guards 与标准构建均运行。
- Deployed gate regression：`20260716-090555-release-regression` 通过，显式执行线上 `RUN_BACKEND_RELEASE_POLICY_SMOKE=1`。
- 两仓库 `git diff --check` 通过。

## 4. 边界与下一项

- `shadowMode=true` 只用于记录差异，不能开启任何功能。
- 当前 feature allowlist 不代表 Product MVP、Voice、Digital Human、Care 或 TimeLetter 已获发布批准。
- 未知、过期、低版本、emergency revoked 的最终 iOS cache/evaluator 行为仍由 `WI-S0-06-02` 实现。
- 下一 Work Item：`WI-S0-06-02`，Authority `RELEASE_POLICY`，目标为 account/app-version scoped TTL cache 与 offline deny。
