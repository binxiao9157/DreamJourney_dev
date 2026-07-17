# WI-S0-02-05 Delegated Grant 与 Relationship Lifecycle

日期：2026-07-18
Work Item：`WI-S0-02-05`
状态：`INTERNAL_READY / BACKEND_DEPLOYED / G2_POSTGRES_VERIFIED / IOS_LOCAL_COMMITTED / HIDDEN_DEFAULT_OFF / G4_EXTERNAL_BLOCKED`
Execution owner：`codex-goal:019ece6b-2c15-7521-b160-c42e95d1dd5a`
Authority lock：`IDENTITY_AUTHZ`

## 目标

- Family relationship 只表达已验证的家庭关系，不隐式授予 Care、TimeLetter 或 Persona 数据访问权。
- 跨 owner 读取必须绑定 verified subject、独立 AccessGrant、明确 purpose/resource/operation、有效期和版本。
- pause、resume、revoke、expiry、重复请求和并发请求必须具有稳定、可审计且 fail-closed 的行为。
- 新合同在 G4 产品、隐私和发布批准前保持服务端与 iOS 公开入口默认关闭。

## 已实现合同

### 后端

- 新增 `family_relationships`、`access_grants` 和 append-only `grant_events` migration `0005`。
- 受邀账号必须以匹配手机号的 authenticated principal 接受邀请；owner 不能替受邀人接受或把关系绑定到自己。
- 接受关系不会自动创建 grant；Care、TimeLetter 和 Family Persona 使用独立 purpose/resource scope。
- grant 支持显式创建、幂等重复、版本化撤销、有效期、关系 pause/resume/revoke 和 relationship/grant epoch。
- 关系 revoke 在同一事务中吊销全部 active grant；并发同 scope 创建由 advisory lock 和数据库唯一约束收敛。
- 每次实际跨 owner allow 写入 access receipt，并通过 value-free response header 暴露 grant/receipt 诊断 ID。
- 路由内防御复核和时间信件投递资格检查不重复写 access receipt。
- 客户端 `now` 只作为兼容参数，不能提前打开未到期时间信件。
- lifecycle/grant API 由 `DELEGATED_ACCESS_CONTRACT_API_ENABLED=false` 与 ReleasePolicy 双层默认关闭。
- 账号 purge 使用受限 `SECURITY DEFINER` 函数清理 append-only delegated access 数据，不开放通用删除能力。

### iOS

- 新增 typed `FamilyAccessGrant`、relationship status、relationship epoch 和 grant epoch 模型。
- `FamilyRelationshipAuthorizationPolicy` 明确区分 relationship accepted 与 persona grant active。
- Echo 家人角色和 persona context 只消费有效 `family.persona` grant；pending/paused/revoked/expired grant 均不可用。
- 时间信件收件人仍要求 accepted relationship，但不会误用 persona grant 作为收件资格。
- Family Repository 保留 typed grant/lifecycle 字段并拒绝旧 implicit-permission 语义。
- 公开 release 入口不暴露新的 grant 管理 UI；仅 QA 合同脚本可验证隐藏能力。

## 版本与部署

- 后端主体实现：`83c625e feat(WI-S0-02-05): enforce delegated grant lifecycle`。
- 后端 Postgres/smoke 修复：`4236782 fix(WI-S0-02-05): harden delegated Postgres smoke`。
- `origin/main`、服务器工作树和运行容器均为 `4236782`。
- iOS 实现：`71b2960 feat(WI-S0-02-05): consume delegated family grants`。
- iOS 提交仅保留在本地 `feature/prd-stitch-ui-adaptation`，未自动推送。

## 验证证据

### G0

- 后端全量：`507 tests passed`。
- credential response boundary、py_compile、FastAPI、Knowledge 和 Postgres backup contract smoke 均通过。
- iOS delegated family grant contract check 通过。
- iOS release QA package check 通过；缺失的历史视觉 evidence 被明确标为 skipped，不计为本项 PASS。
- iOS generic Simulator build：`BUILD SUCCEEDED`，日志 `/tmp/DreamJourney-WI-S0-02-05-build.log`。
- 两仓库 `git diff --check` 通过。

### G2

- 生产 migration dry-run 仅显示 `0005` pending；apply 后 `appliedHead=expectedHead=0005`；verify 为 `status=ready`。
- 线上 `/ready` 返回 200，database/schema/auth 全部 ready。
- 正式镜像内 Postgres delegated access smoke 返回 `status=passed`，覆盖：
  - accepted relationship 不隐式授权；
  - machine principal 无法访问用户 grant route；
  - grant purpose/resource/subject mismatch 拒绝；
  - duplicate accept/grant/revoke 幂等；
  - pause/resume/revoke/expiry 每次读取重验；
  - relationship revoke 级联吊销；
  - TimeLetter resource-specific grant；
  - mutation event 与 access receipt 持久化；
  - smoke 数据清理完成。
- 线上服务保持 `serverDefaultOffVerified=true`，完整合同只在独立 smoke 进程临时 observe，不改变运行服务发布策略。

## Gate 结论

- `G0`：满足本 Work Item 的 typed contract、负例、安全边界、iOS consumer 和构建范围。
- `G2`：满足 migration、真实 Postgres、并发/幂等、线上 readiness 和 deployed smoke 范围。
- `G4`：仍缺家庭委托授权产品文案、隐私/法律和正式发布批准，因此保持 `EXTERNAL_BLOCKED`，对应入口继续默认关闭。
- Registry 保持保守计划视图；本证据只更新 current handoff，不自行签发 Registry `VERIFIED`。

## 下一步

进入 `WI-S0-02-06`：完成 iOS typed-auth cutover 与旧客户端边界，禁止恢复移动端共享 token、离线私有登录或客户端派生 owner Authority。
