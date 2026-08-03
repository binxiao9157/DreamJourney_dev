# DreamJourney V4 Round 5A 工程独立复审

基线：Round5A-Engineering-Agent｜2026-07-12｜iOS `8a1922b`｜backend `4c0538b`

## Summary

本轮独立工程复审识别出2项P0、5项P1和1项P2。P0集中在后端匿名fail-open和iOS共享system credential；P1集中在本地账号隔离、数字人credential、TimeLetter事务一致性、数据库迁移可执行性和Owner Truth尚未实施；P2涉及Round 4生成器尚未进入已提交基线。本报告只记录发现，不在本轮修改生产代码或权威成果物。

## Findings

### R5A-ENG-001

- Severity：`P0`
- 结论：后端未配置系统 token 时匿名请求可直接进入业务路由，身份与 owner AuthZ 未形成 fail-closed 边界。
- 证据：证据矩阵 §7.1、§7.5；`/Users/yxj/Documents/Codex/Video/DreamJourneyBackend/app/main.py:365-389`、`app/core/config.py:32-35`。
- 影响：匿名访问可能读取或写入账号数据；跨账号隔离依赖调用方自报 `userId`。
- 最小修正：生产缺少/非法配置立即启动失败；所有非公开路由统一要求 user principal；system principal 仅允许显式 system route。
- Suggested Owner：Backend Security/Auth。
- 验证方式：无凭证、无效凭证、跨账号访问全路由均返回 401/403；启动配置负例测试。
- 分类：实现阻断。

### R5A-ENG-002

- Severity：`P0`
- 结论：iOS 客户端仍支持携带共享 backend API token，并可将其作为 Bearer system credential。
- 证据：证据矩阵 §6.1；`/Users/yxj/Documents/Codex/Video/DreamJourney_dev/DreamJourney/Sources/Services/DreamJourneyBackendClient.swift:3835-3846`、`DreamJourney/Config/Backend.example.xcconfig:5-8`。
- 影响：客户端泄露即获得系统权限，绕过 owner-scoped AuthZ。
- 最小修正：移除客户端 token 注入和 Bearer fallback；仅使用用户 session 或后端 broker。
- Suggested Owner：iOS Platform + Backend Security。
- 验证方式：Release `.app/.ipa` secret scan、抓包、system-token header negative test。
- 分类：实现阻断。

### R5A-ENG-003

- Severity：`P1`
- 结论：多个本地业务状态仍是全局存储，账号切换/登出不能保证隔离。
- 证据：Roadmap §7 `WI-S0-01-06/08`、证据矩阵 §6.3；`MemoryRepository.swift:15-16,20-31,50-64` 使用全局 `dj.persistedMemories`，`EchoDelayedReplyStore.swift:20-39` 使用单一 key，`UserManager.swift:166-177` 登出未清理二者。
- 影响：新账号可能看到旧账号 Memory 或 delayed reply；违反 Account Lease 与本地 Owner isolation。
- 最小修正：所有 store 按 owner/session generation 分区；统一由 AccountLifecycleCoordinator 执行 switch/logout/delete 清理。
- Suggested Owner：iOS Account/Storage。
- 验证方式：双账号切换、冷启动、登出、删除、并发 refresh 的 XCTest/升级矩阵。
- 分类：实现阻断。

### R5A-ENG-004

- Severity：`P1`
- 结论：数字人 session response 仍向客户端下发配置级 appkey/accesstoken，本地 expiry 不是 Provider credential 失效。
- 证据：Roadmap §10 `WI-S0-03-05`；证据矩阵 §7.9；`/Users/yxj/Documents/Codex/Video/DreamJourneyBackend/app/main.py:188-204`。
- 影响：会话凭据泄露后可脱离产品 lease 使用；无法满足 per-session revoke/close 语义。
- 最小修正：改为 Provider per-session credential 或后端中介；response 不含长期 appkey/token；Provider receipt 与 close/reconcile 分离。
- Suggested Owner：Backend Provider Integration。
- 验证方式：抓包、TTL/replay/close/app-kill/账号切换测试；Release artifact 中长期凭据为 0。
- 分类：实现阻断。

### R5A-ENG-005

- Severity：`P1`
- 结论：TimeLetter dispatch 先提交 delivered，再单独写 mailbox，存在“已投递但无 Inbox”丢失窗口。
- 证据：Roadmap §16 `WI-S1-02-05`；证据矩阵 §7.6；`time_letters.py:181-190`、`postgres_store.py:2522-2584,2587-2602`。
- 影响：worker 崩溃或第二次提交失败时业务状态与用户可见结果不一致；无法满足 delivered-without-Inbox=0。
- 最小修正：aggregate 状态、outbox/job、Inbox receipt 使用同一 Unit of Work；增加幂等键和 crash replay。
- Suggested Owner：Backend Worker/Operations。
- 验证方式：Postgres 并发 dispatch、commit 后崩溃、重复执行、Mailbox 唯一性 smoke。
- 分类：实现阻断。

### R5A-ENG-006

- Severity：`P1`
- 结论：迁移/回滚路线当前不可执行：代码仍依赖 startup `CREATE/ALTER IF NOT EXISTS`，缺少版本化 migrator、backup/isolated restore 与真实 rollback artifact。
- 证据：Roadmap §11 `WI-S0-04-02/05`、§23 `WI-MIG-01`；证据矩阵 §7.2-§7.4；`postgres_store.py:47-69`；Backend 中未发现 `app/db/migrator.py`、`scripts/migrate_db.py`、`scripts/db/backup_postgres.sh`。
- 影响：schema 变更无法审计、回退或证明 RPO/RTO；线上 cutover 依赖人工状态。
- 最小修正：先落地 versioned migration/head、backup manifest、isolated restore、pre/post-cutover rollback runbook，再允许新 authority 表上线。
- Suggested Owner：Backend DB/Operations。
- 验证方式：空库升级、旧库升级、失败注入、隔离恢复、R03/R05 rollback drill。
- 分类：路线不可执行。

### R5A-ENG-007

- Severity：`P1`
- 结论：Owner Truth/Source/Candidate/Canonical Memory 尚未实施，当前 KBLite snapshot/change/receipt 仍是实际持久化业务路径。
- 证据：Roadmap §15 `WI-S1-01-01/04/05/06`；证据矩阵 §7.4；`postgres_store.py:59-108`、`app/main.py` 的 `/kb/sync`、`/kb/mutations` 路径。
- 影响：无法证明 Source 到 Candidate、Owner decision、Immutable MemoryVersion 与 Projection 的权威链路；纠错/删除/引用追踪不能作为 V4 真相验收。
- 最小修正：新增 Source/Candidate/Canonical Memory/Version authority 与 outbox projection；KBLite 降级为兼容 Projection。
- Suggested Owner：Backend Data/Owner Truth。
- 验证方式：source deletion、candidate rejection、memory correction、stale projection replay、cross-account citation tests。
- 分类：路线尚未实施。

### R5A-ENG-008

- Severity：`P2`
- 结论：路线注册表虽有115个WI，但指定baseline无法独立重生成其machine registry。
- 证据：Roadmap §0明确生成器为`Scripts/QA/product-v4/generate-product-v4-execution-registry.py`；该路径不在iOS `8a1922b` tracked tree；注册表`DreamJourney_V4_路线执行注册表_V1.0.json:67-70,379-382`仅保留有限控制字段。
- 影响：source hash、115 WI依赖与状态的复现依赖未随baseline固化，审查/CI不能独立验证。
- 最小修正：将生成器及checker纳入受审baseline，或提供固定版本的可执行生成入口和artifact manifest。
- Suggested Owner：Roadmap/QA Governance。
- 验证方式：从干净checkout运行生成器，校验source hash、115 count、字节级registry一致。
- 分类：证据错误。

## 审查覆盖

已阅读指定5份iOS产品/路线/注册表文档；抽查两个baseline的tracked iOS/Backend源码、Auth/AuthZ、Owner/Projection、TimeLetter、媒体、Voice/Digital Human、Postgres schema、部署/QA脚本与路线路径。

## 未检查内容

历史独立评审、Round5报告、密钥/token/LocalConfig/.env值、线上服务器、真实Provider、真机、生产部署与未提交iOS工作树内容；未运行构建、测试或部署。

## 独立性声明

本审查仅基于指定baseline、指定文档及当前tracked源码/QA路径，未采纳历史评审结论作为证据。

## 计数

- P0：2
- P1：5
- P2：1
