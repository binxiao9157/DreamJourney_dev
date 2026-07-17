# WI-S0-02-04 Server-Derived Owner 与 Resource AuthZ

日期：2026-07-18
Work Item：`WI-S0-02-04`
状态：`INTERNAL_READY / BACKEND_DEPLOYED / G2_POSTGRES_CROSS_VAULT_VERIFIED / IOS_LOCAL_COMMITTED`
Execution owner：`codex-goal:019ece6b-2c15-7521-b160-c42e95d1dd5a`
Authority lock：`IDENTITY_AUTHZ`

## 目标

- owner、vault 和资源访问关系由 authenticated principal、path resource lookup 与数据库 canonical row 派生。
- payload 中的 `userId`、`ownerUserId`、`uploadedByUserId`、`uploaderUserId` 和嵌套 owner claim 只能用于 mismatch 校验，不能转移 Authority。
- 同 ID 跨 vault、列表/详情/删除、Mailbox source owner 与 recipient owner 必须使用各自资源语义。
- iOS 登录切换、token refresh 和回响对象切换后，旧异步结果不得写入新账户或新 persona 的本地存储。

## 已实现合同

### 后端

- resource resolver 从 principal 与数据库 canonical row 派生 owner，不接受 payload owner 覆盖。
- Archive、Mailbox、Care、Family、Knowledge、TimeLetter 等资源统一执行 path/body/nested claim mismatch 拒绝。
- generic upsert 不允许修改已存在资源 owner；资源版本冲突和同 ID 跨 vault 均 fail closed。
- migration `0004` 按 resource kind 解析 legacy owner claim：Mailbox 的 `ownerUserId` 继续表示来源时间信件 owner，不被误当成收件箱资源 owner。
- 无唯一合法 owner 证据的历史 Archive 行进入 quarantine，并生成 value-free incident；不猜测 owner、不恢复越权访问。

### iOS

- `BackendAccountLease` 只捕获账户/session lineage，不保存 token；同 session 或同 token family 的更高 v2 session version 才允许交付结果。
- 每个 `.userRequired` 请求在发网、runtime recovery、401 refresh、后台 response 和主线程 delivery 前重新校验 lease。
- 账户切换、新登录 token family、旧 session version 和 legacy v1 非精确 successor 均拒绝旧回调。
- `ArchiveStorageLease` 捕获 account、archive owner、persona scope、digital human id 和 storage key；同账户切换回响对象后，旧 Archive list/detail/sync 回调不再写入当前 persona。
- logout 先失效 Echo owner scope，再在当前账户仍可解析时捕获 lease 并发起服务端 revoke，最后清除本地用户状态。
- Archive -> Echo UIQA 使用编译期限定的 simulator mock DialogEngine，不以共享凭据或无 session 网络请求绕过生产认证。

## 版本与部署

- 后端实现：`2cf01cb feat(WI-S0-02-04): enforce canonical resource ownership`。
- 后端 migration 修复：`5b2d4b9 fix(WI-S0-02-04): scope legacy owner claims by resource`。
- `origin/main`、服务器工作树和运行容器均部署 `5b2d4b9`。
- iOS 实现：`119e6ef feat(WI-S0-02-04): reject stale account callbacks`。
- iOS QA 守卫兼容：`e691905 test: align regression guards with typed request formatting`。
- iOS 提交仅保留在本地 `feature/prd-stitch-ui-adaptation`，未自动推送。

## G2 数据与线上证据

- 后端 memory store 全量测试：`478` tests passed。
- migration Postgres smoke 通过：合法 legacy Mailbox source owner 保留；Archive owner conflict quarantine；owner mutation 拒绝。
- 生产迁移前只读扫描：Archive `117` 行，其中 `8` 条冲突；Mailbox `31` 行，`0` 条冲突；其他受管资源无冲突。
- migration `0004` 已显式 apply/verify；迁移后 Archive active `109`、quarantined `8`、incident `8`，Mailbox active `31`。
- 线上 `/ready`：database、schema、auth 均为 ready。
- 线上 resource authorization smoke 通过：cross-vault analysis/delete 拒绝、canonical owner 持久化、owner immutable、Mailbox owner transfer 拒绝、nested owner claim 拒绝、principal-derived owner、resource collision、stale version 拒绝。

## iOS 验证证据

- AccountLease/ArchiveStorageLease model 与静态守卫通过。
- 123 个 release Swift guards 批量扫描：`TOTAL_FAIL=0`。
- 完整 release regression 通过：
  - `tmp/visual-qa/prd-stitch-ui/release-regression/20260717-wi-s0-02-04-account-lease-release-pass/report.md`
- Archive -> Echo simulator smoke：`availableItemCount=1`、`containsArchiveContext=true`：
  - `tmp/visual-qa/prd-stitch-ui/release-regression/20260717-wi-s0-02-04-account-lease-release-pass/archive-to-echo-smoke/20260717-wi-s0-02-04-account-lease-release-pass/archive-to-echo-smoke-result.json`
  - `tmp/visual-qa/prd-stitch-ui/release-regression/20260717-wi-s0-02-04-account-lease-release-pass/archive-to-echo-smoke/20260717-wi-s0-02-04-account-lease-release-pass/01-archive-to-echo-completed.png`
- 延迟回信持久化和 pending notification smoke 通过：
  - `tmp/visual-qa/prd-stitch-ui/release-regression/20260717-wi-s0-02-04-account-lease-release-pass/echo-delayed-reply-notification-smoke/20260717-wi-s0-02-04-account-lease-release-pass/echo-delayed-reply-notification-smoke-result.json`
- generic iPhoneOS 构建通过，Bundle ID 为 `com.yxj.dreamjourney.app`：
  - `tmp/visual-qa/prd-stitch-ui/iphoneos-generic-build/20260717-wi-s0-02-04-account-lease-final/report.md`
- `git diff --check` 通过；本项不要求、也未运行真机验收。

## 退出结论

- `G0`：满足本 Work Item 的代码、负例 corpus、migration 和客户端 late-callback 范围。
- `G2`：满足本 Work Item 范围。真实 Postgres migration、cross-vault deployed smoke、readiness 和历史冲突 terminal quarantine 均有证据。
- Registry 继续保持保守 `PLANNED/STOP`，本证据只更新 current handoff，不将静态 Registry 自行改写为完成。
- 本项不实现 Family/Publication 产品授权；relationship 与独立 AccessGrant 的生命周期由 `WI-S0-02-05` 继续完成。

## 下一步

进入 `WI-S0-02-05`：Family/Care/TimeLetter 的跨 owner 访问必须绑定 verified subject 和独立 AccessGrant；先实现默认隐藏的 typed relationship/grant 安全合同与每次读取重验。G4 未满足前不开放相关产品入口。
