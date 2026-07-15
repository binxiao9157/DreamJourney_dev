# DreamJourney V4 Round 3 后端/数据/异步独立架构评审

版本：V1.0  
日期：2026-07-12  
状态：独立只读评审输入；尚未经过主控 disposition  
后端基线：`DreamJourneyBackend main@4c0538b`  
范围：Product Spec 23-28/30-34、Evidence Matrix 第 7 节和指定后端源码/测试；未修改工作区

## 1. 结论摘要

- `BLOCKER`：1 项（BAR-01）。
- `HIGH`：6 项（BAR-02 至 BAR-07）。
- 核心判断：V4 的 fail-closed AuthZ、request UoW、typed authority、outbox、object/provider receipt 和 forward-only migration 方向正确；当前后端仍只适合受控 legacy/contract/shadow 阶段，不具备 V4 authority cutover、rights retirement 或 schema contract 证据。
- 本报告是独立异议来源；Round 3D4 必须逐项响应。

## 2. Findings

### BAR-01 — BLOCKER：认证与跨 Vault AuthZ fail-open

- **分类**：实现缺口。
- **代码/测试证据**：
  - `/Users/yxj/Documents/Codex/Video/DreamJourneyBackend/app/main.py:365-450`
  - `/Users/yxj/Documents/Codex/Video/DreamJourneyBackend/app/services/authorization_policy.py:51-59,308-315`
  - `/Users/yxj/Documents/Codex/Video/DreamJourneyBackend/tests/test_authorization_policy.py:179-189`
- **Spec**：23、25、30；Evidence Matrix 7.1/7.5。
- **问题/影响**：缺少 bearer 且 `BACKEND_API_TOKEN` 为空时，业务请求可继续以 anonymous principal 进入 route；策略异常或未分类 route 仍有 fallback；system token 路径可绕过普通 owner policy。路由登记完整不等于对象 AuthZ 安全。
- **建议**：生产缺认证配置时拒绝启动或除 health 外全部拒绝；未分类/异常/payload 无法解析一律 deny；system principal 只允许显式 service capability，不能充当客户端 owner。

### BAR-02 — HIGH：共享连接、启动 DDL 与 readiness

- **分类**：实现缺口。
- **代码/测试证据**：
  - `/Users/yxj/Documents/Codex/Video/DreamJourneyBackend/app/services/postgres_store.py:47-292,3283-3324`
  - `/Users/yxj/Documents/Codex/Video/DreamJourneyBackend/app/services/store_factory.py:6-17`
  - `/Users/yxj/Documents/Codex/Video/DreamJourneyBackend/app/main.py:459-471`
  - `/Users/yxj/Documents/Codex/Video/DreamJourneyBackend/tests/test_postgres_store.py:1676-1710`
- **Spec**：23.6、24.1、27、28；Evidence Matrix 7.2/7.4。
- **问题/影响**：普通读写缓存单一 psycopg connection，读事务未证明 request-scoped close；启动直接 `CREATE/ALTER IF NOT EXISTS`，无 migration head/checksum/rollback；health 未证明 DB/schema readiness。
- **建议**：连接池按 request/job checkout，一个 command 一个事务；使用独立 versioned migrator；startup 只校验 schema head；增加 DB/schema/auth `/ready`。

### BAR-03 — HIGH：payload owner 可转移跨 Vault 资源

- **分类**：实现缺口。
- **代码证据**：
  - `/Users/yxj/Documents/Codex/Video/DreamJourneyBackend/app/services/postgres_store.py:2317-2334,2587-2603,2670-2685,3256-3270`
  - `/Users/yxj/Documents/Codex/Video/DreamJourneyBackend/app/services/route_ownership.py:35-43`
- **Spec**：24.1-24.3、25；Evidence Matrix 7.1。
- **问题/影响**：generic memory/mailbox/echo/push 路径的 `ON CONFLICT (id)` 可更新 `user_id`，把同 ID 行转给另一 owner。Route registry 绑定 payload `userId` 不能替代 DB `(vault_id,id)` 约束；宽字典允许未知字段/状态进入 JSONB。
- **建议**：服务端随机 ID、`UNIQUE(vault_id,id)`、复合 FK 与 owner-bound conflict rejection；冲突不覆盖 owner；typed schema、版本、allowlist、大小限制。

### BAR-04 — HIGH：TimeLetter/Inbox/Conversation effect 非原子

- **分类**：实现缺口。
- **代码/测试证据**：
  - `/Users/yxj/Documents/Codex/Video/DreamJourneyBackend/app/services/time_letters.py:181-200`
  - `/Users/yxj/Documents/Codex/Video/DreamJourneyBackend/app/services/postgres_store.py:2522-2585`
  - `/Users/yxj/Documents/Codex/Video/DreamJourneyBackend/app/main.py:2340-2360`
  - `/Users/yxj/Documents/Codex/Video/DreamJourneyBackend/tests/test_postgres_store.py:570-590`
- **Spec**：26、31、34.3；Evidence Matrix 7.6。
- **问题/影响**：TimeLetter 先提交 delivered，再逐条写 mailbox；进程在两者之间崩溃会产生 delivered-without-Inbox。Echo dispatch 也没有统一 job lease/outbox/dedupe/reconcile。
- **建议**：业务状态与 outbox 同事务；worker 使用 lease/generation、稳定 effect ID、重试/dead-letter；business receipt 与 APNs/Provider delivery receipt 分离。

### BAR-05 — HIGH：Source/Memory/Projection Authority 未分离

- **分类**：实现缺口。
- **代码证据**：
  - `/Users/yxj/Documents/Codex/Video/DreamJourneyBackend/app/services/postgres_store.py:59-116`
  - `/Users/yxj/Documents/Codex/Video/DreamJourneyBackend/app/services/context_packet.py:34-79,1205-1226`
  - `/Users/yxj/Documents/Codex/Video/DreamJourneyBackend/app/services/knowledge_store.py:336-389`
- **Spec**：23.7、24.3-24.6、30；Evidence Matrix 7.0。
- **问题/影响**：没有独立 Source、Candidate、DecisionReceipt、immutable MemoryVersion；memories、Archive、KBLite并存。Context 的不同 entity 类型未统一证明 vault/persona/evidence/purpose scope，可能把未授权 projection 注入生成。
- **建议**：Source→Candidate→Review→MemoryVersion→Projection 单向链路；Context 只查询 confirmed MemoryVersion/授权 Projection；KBLite 保持 projection，不作为事实 Authority。

### BAR-06 — HIGH：Object/Provider unknown 被压缩成可用信号

- **分类**：外部验收与实现缺口。
- **代码/测试证据**：
  - `/Users/yxj/Documents/Codex/Video/DreamJourneyBackend/app/main.py:497-507,1285-1293,2001-2006`
  - `/Users/yxj/Documents/Codex/Video/DreamJourneyBackend/app/services/voice_clone.py:249-301`
  - `/Users/yxj/Documents/Codex/Video/DreamJourneyBackend/tests/test_postgres_store.py:1134-1140`
- **Spec**：26.5-26.10、32、33、34.3；Evidence Matrix 7.7/7.8。
- **问题/影响**：upload intent 为 `mock_ready`；DH未配置时生成 mock asset；Voice unknown 被归为 pending；没有统一 configured/accepted/terminal/businessUsable/externalVerified/deletionState receipt。配置、本地 lease 或 HTTP 成功可能被误当业务完成。
- **建议**：真实 private object/checksum/signed URL/HEAD/scan/delete receipt；Provider unknown/partial 不升级；稳定 provider request ID/query/reconcile；Voice/DH/APNs 走独立 external acceptance lane。

### BAR-07 — HIGH：Rights/Delete/Restore 与 migration rollback 证据不足

- **分类**：实现缺口。
- **代码/测试证据**：
  - `/Users/yxj/Documents/Codex/Video/DreamJourneyBackend/app/services/postgres_store.py:411-447,2484-2518`
  - `/Users/yxj/Documents/Codex/Video/DreamJourneyBackend/app/services/archive_store.py:16-23`
  - `/Users/yxj/Documents/Codex/Video/DreamJourneyBackend/tests/test_postgres_store.py:924-953,1278-1285`
- **Spec**：24.7、27.7-27.9、28.5-28.7、34.2-34.7。
- **问题/影响**：账号主要是 soft delete/restore；Archive 物理删除正文但没有统一 rights module/object/provider deletion/export/restore/replay receipt。没有 migration runner、authority epoch、backup restore 或不可逆补偿，旧 Authority 不能安全回切。
- **建议**：分离 access revoke、logical invisibility、async purge、physical delete并逐模块 receipt；migration epoch/CAS、checkpoint、quarantine、forward-only rollback；post-cutover 只允许 mutation freeze、compatibility read、forward fix。

## 3. Crash/Concurrency/Rollback 压力测试

使用真实 Postgres，而不是只靠 FakeConnection：

1. 两个 worker 并发处理同一到期 TimeLetter，在 delivered commit 后、首条 mailbox insert 前 kill 一个 worker。
2. 两个不同 owner 同时提交相同 resource ID，覆盖 memory/mailbox/echo/voice slot/archive。
3. epoch 提升后 kill API；旧 timer 发送 epoch 0 callback；随后 backup restore + receipt replay。
4. 注入 DB disconnect、Provider timeout/重复 callback、object delete timeout。
5. 通过标准：无重复 Inbox/provider effect、无 delivered-without-outbox、跨 Vault 写入为零、stale epoch 全拒绝、unknown/partial 不升级、restore 后 owner/visibility/version/receipt hash 一致，且达到预批准 MRT-Cxx。

## 4. 残余风险

- 未验证真实 Postgres 并发和线上 schema/config。
- 未证明 worker/timer one-active、对象存储、Provider delete/callback、APNs arrival。
- 未掌握旧客户端分布、backup restore 和真机质量。
- 当前实现不应进入 V4 authority cutover、rights retirement 或 schema contract。
