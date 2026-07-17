# WI-S0-02-02 Token Family 原子轮换与撤销

日期：2026-07-17
Work Item：`WI-S0-02-02`
状态：`INTERNAL_READY / BACKEND_DEPLOYED / G2_POSTGRES_VERIFIED / IOS_LOCAL_COMMITTED`
Execution owner：`codex-goal:019ece6b-2c15-7521-b160-c42e95d1dd5a`
Authority lock：`IDENTITY_AUTHZ`

## 目标

- refresh consume 与后继 token issue 在同一事务中原子完成。
- 同一个 refresh token 只能产生一个后继，reuse 会撤销该 family 的后代。
- 支持单 session、单 family 和全设备撤销。
- 账号删除、密码变更和风险事件后，旧 access/refresh token 不再可用。
- iOS 仅持久化 typed session lineage，不回退旧 shared/system token。

## 已实现合同

- 后端新增 token family、session lineage、family version、refresh hash 和 revoke event 持久化合同。
- refresh rotation 使用行锁和事务完成 consume、后继签发与 receipt 写入；并发 refresh 只有一个成功。
- reuse detection 会原子撤销当前 family 后代，且不会影响其他用户的 family。
- 单 session、family、all-devices、密码变更、账号删除均使用统一撤销服务。
- all-devices revoke 与账号 purge 采用稳定锁顺序，避免并发死锁和删除后晚到签发。
- purged account 为 terminal 状态，不能被迟到 refresh 或 issue 路径复活。
- opaque access/refresh token 只持久化 hash/fingerprint，不保存原文。
- migration `0003` 为 additive schema，并声明 `singleVersionCutover` 与 `requiresOldWorkerDrain=true`。
- legacy v1 refresh 不猜测 family lineage，要求重新认证。
- iOS `BackendAuthSessionStore` 使用 typed v2 session，同时保留 legacy decode 以清理旧状态。
- iOS 请求绑定 session/family/version，并用 CAS 接受同 family 的后继；terminal auth 错误会清理本地 session。
- 并发 401 refresh 归并为单次 refresh，不允许多个本地后继覆盖。
- `UserManager` 的退出和账号失效路径统一清理 typed auth session。

## 版本与部署

- 后端功能提交：`82a1f4e feat(WI-S0-02-02): add rotating token families`。
- 后端修复提交：`5dfbaa5 fix(WI-S0-02-02): purge schema-safe account rows`。
- iOS 实现提交：`d05e7cb feat(WI-S0-02-02): consume rotating auth sessions`。
- 后端提交已推送并部署；服务器、`origin/main` 与运行版本均为 `5dfbaa5`。
- Postgres migration head 已从 `0002` 升级并验证为 `0003`。
- iOS 提交仅保留在本地 `feature/prd-stitch-ui-adaptation` 分支，未自动推送。

## 部署与恢复证据

- 迁移前加密备份验证通过：`dj-20260717T100059Z-63b05e74`，schema head `0002`。
- 旧 Worker/API 已先停止并完成 drain，再执行严格 single-version cutover。
- migration `dry-run -> apply -> verify` 通过，实际应用 `0003`。
- 旧版本回滚镜像已保留为 `dreamjourneybackend-api:pre-wi-s0-02-02`。
- 迁移后加密备份验证通过：`dj-20260717T101037Z-c3a8c219`，schema head `0003`。
- `/ready` 最终返回 database/schema/auth ready。

## 验证

- 后端全量测试：`443/443` 通过。
- focused auth/store/migration、Python compile、shell syntax、migration metadata 和 `git diff --check` 通过。
- 真实 Postgres token-family smoke 通过：并发唯一后继、reuse 后代撤销、consume/issue rollback、cross-user isolation、all-device receipt、删除/签发竞态、all-device/purge 竞态、purged terminal、family version constraint、opaque token persistence 均为 `true/passed`。
- 线上 identity challenge smoke 复跑通过，生产 identity provider 继续 fail closed。
- iOS token-family model smoke、static check、identity boundary、credential response boundary 和 `git diff --check` 通过。
- iOS unsigned generic Simulator Debug build 通过。
- 独立复审发现的 purged terminal、锁顺序、all-device/purge race、multi-user purge 锁顺序和 expired-refresh commit 五项已修复；复审无剩余 P0/P1 阻断。
- 首轮线上 smoke 暴露旧通用 purge 对 `kb_snapshots` 错用 `RETURNING payload`；已改为 schema-safe `RETURNING user_id` 并增加回归测试，随后线上 smoke 全部通过。

## Gate 与未关闭边界

- 本 Work Item 所需 scoped G2 已由线上真实 Postgres 并发、故障与部署 smoke 关闭。
- Registry 仍保持保守 `PLANNED/STOP/DEPLOYED_UNVERIFIED`，不会由状态文档自动签发全局 `VERIFIED`。
- 真实短信/身份 Provider 的 G4 仍属于 `WI-S0-02-01`，不影响本项 token-family 合同。
- 业务 route principal、route matrix 与对象级 AuthZ 不属于本项；不得把 token 有效等同于资源授权。
- legacy v1 refresh 要求 re-auth，未实现猜测式 family 升级。

## 续接点

Authority lease 继续保持 `IDENTITY_AUTHZ`，进入 `WI-S0-02-03`：实现 typed Principal Middleware 与 58-route fail-closed matrix。先建立 route registry completeness 和 negative corpus，再按 route group canary enforce；生产环境中的 unknown route、anonymous business、unscoped system、audience/scope mismatch 和 evaluator exception 必须 deny/non-ready。后续 `WI-S0-02-04` 再实现 server-derived owner 与对象级 Resource AuthZ。
