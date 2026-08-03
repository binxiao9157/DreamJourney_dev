# Round 3C1 数据 Schema、Backfill 与 Authority 切换方案

## Problem Definition

将当前由启动 SQL、宽 JSONB、全局 ID 和 legacy Archive/KBLite 路径承载的数据，安全迁移到 V4 typed authority。迁移必须允许旧客户端继续运行，不能通过无事务双写生成第二事实源，也不能因历史数据不完整而伪造 Candidate、DecisionReceipt 或 Confirmed MemoryVersion。

## Proposed Solution

在 Product Spec 新增数据迁移子章和逐对象 migration catalog：

1. **Baseline/Freeze**：固定当前 schema fingerprint、代码版本、数据分类、表级 row count/checksum、owner 冲突查询、备份恢复点和不可迁移样本抽样。
2. **Migration mechanism**：引入独立版本化 migration head/checksum/lock，API/worker 只检查 head，不再隐式建表；所有 DDL 先 expand、后 contract。
3. **Authority scaffold**：先新增 Vault/Subject、Source/SourceObject、Candidate、DecisionReceipt、MemoryVersion、Conversation/Answer/Citation、Session/Auth、Outbox/Job/Receipt 等 typed 表及复合 owner/vault 约束，不切流。
4. **Deterministic backfill**：为每类 legacy row 定义稳定 target ID、legacy locator、authorityEpoch、source snapshot、批次 checkpoint、canonical checksum 和幂等 upsert；无法证明 owner/时间/语义的记录进入 quarantine，不自动升级为 confirmed。
5. **Projection first**：新 Authority 单写，旧 Archive/KBLite/列表通过 projection/outbox 更新；迁移前旧写路径先生成可对账 event，不做跨 store 裸双写。
6. **Shadow read/compare**：对 old/new canonical projection 比较 count、ID、owner、version、content hash、citation 和 visibility，按 mismatch 类型分级；读取仍由旧路径返回。
7. **Authority cutover**：仅对完成 backfill、无 blocker mismatch、备份可恢复且新 command 幂等验证通过的 owner cohort 提升 authorityEpoch；新写进入 V4，旧 route 变 facade。
8. **Fallback/rollback**：切流前可回旧读；切流后新事实不回写删除，只允许关闭新入口、回旧 projection 读取或执行补偿。schema contract 必须等旧客户端和 legacy worker 退役后单独批准。
9. **Contract/retire**：满足 retention、零活跃旧写、quarantine 已裁决、数据权利传播和恢复演练后，才删除旧列/表/trigger；保留 migration/audit/receipt 证据。

同时为 Source、Candidate、MemoryVersion、Identity/Session、Conversation/Citation、TimeLetter/Inbox、Family/Care、Voice/DigitalHuman、Outbox/Job/Object/ProviderReceipt 编制迁移行，明确 `migrate / derive / quarantine / do-not-migrate` 策略。

## Acceptance Criteria

- Product Spec 包含数据迁移状态机、至少 10 个数据 wave 和逐对象 migration catalog。
- 所有核心对象都有 legacy locator、deterministic ID、owner/vault、authorityEpoch、checkpoint、checksum、quarantine 和重跑合同。
- 明确 API startup 不改生产 schema，migration 具有 head、checksum、lock、dry-run、backup/restore 和审计。
- legacy JSONB 不会直接变成 Confirmed MemoryVersion；缺 DecisionReceipt 的内容只能是 Source/Candidate 或 quarantine。
- 迁移期间跨 vault、terminal decision、active version、immutable version、schedule timestamp 和唯一约束持续可验证。
- single authority + projection/outbox 是默认写入模式；任何 dual-write 例外必须同事务、同 commandId、可对账且可关闭。
- 定义 shadow mismatch 分类、cohort cutover、read fallback、post-cutover compensation 和 schema contract 门。
- 至少 12 个数据迁移故障场景有预期结果。
- 新增 `product-v4-data-migration-check.py` 并通过全部 V4 文档门禁与 `git diff --check`。

## Verification Plan

- 静态检查 Product Spec 中 migration state、catalog row、wave、invariant 和 failure scenario 数量。
- 对照当前后端 schema/SQL 与 Round 3B 38 个对象，确认每个 legacy authority 都有迁移去向。
- 独立 reviewer 检查是否存在伪造确认、跨 owner、不可重跑、无 checkpoint、无 rollback 或过早 contract。
- 运行 data-contract、backend-evidence、docs 和 data-migration checks。
- 本轮不执行真实 DDL/backfill；线上 row count、数据分布、备份时间和批次容量标为 `UNKNOWN / IMPLEMENTATION INPUT`。

## Risks

- 历史 JSONB 可能缺 owner、时区、source 或 review 证据，迁移比例无法在离线代码审计中确认。
- 全局 legacy ID 可能在不同 owner 间冲突，必须在 cutover 前显式发现并隔离。
- 旧客户端持续写入会造成 backfill 尾部追赶，需与 Round 3C2 的版本门联动。
- 对象存储和 Provider receipt 的物理迁移由 Round 3C3 负责，本子任务只固定数据库引用和完整性边界。

## Assumptions

- Postgres 是唯一目标业务 Authority；对象二进制不写入业务 JSONB。
- 迁移工具与 API/worker 同代码仓库但独立命令执行。
- 目标 DDL 细节可以在实现任务调整，但本轮冻结迁移不变量、状态和批准门。
