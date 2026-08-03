# Round 3C1B 数据 Migration Waves、Authority Cutover 与 Rollback 方案

## Problem Definition

Round 3C1A 已回答每类 legacy 数据如何识别与回填，但尚未回答何时可以建表、如何追平旧写、何时提升 `authorityEpoch`、新旧读写如何共存、出现 mismatch 后如何暂停/回退，以及何时能 contract 旧 schema。需要把 catalog 组织为可批准、可观测、可暂停且不删除新事实的 migration waves。

## Proposed Solution

在 Product Spec 新增数据 migration wave 章，定义全局 migration run 状态机与至少 11 个 wave：

1. `W0 freeze/inventory`：固定 commit/schema/config、修复 DB connection/UoW blocker、备份恢复演练、采集 3C1A UNKNOWN。
2. `W1 migrator bootstrap`：独立 runner、schema head/checksum/lock、readiness 和 startup DDL fail gate。
3. `W2 additive expand`：迁移控制表、identity/vault、Source/Memory/Conversation/receipt/outbox schema，使用低锁 DDL。
4. `W3 owner/identity bridge`：创建 claim-pending alias/vault，解决或隔离两代 owner ID。
5. `W4 snapshot backfill`：按 catalog 执行 initial backfill，不改变任何产品读取。
6. `W5 tail capture`：旧 Authority 写入同时产生 migration event/projection；追平 snapshot boundary 后变化。
7. `W6 shadow compare`：old response 与 new canonical projection 比较 identity/owner/state/hash/lineage/visibility，不改变用户结果。
8. `W7 command shadow`：新 command 只做 validate/dry-run/expectedVersion 计算，不产生第二业务事实。
9. `W8 cohort authority cutover`：按 vault cohort 原子提升 authorityEpoch；新 Authority 单写，legacy route 只作 facade/projection。
10. `W9 projection/read cutover`：KBLite/列表/Context 从新 event/projection 读取，旧 projection 只作受控 fallback。
11. `W10 legacy read-only/contract candidate`：禁止旧写，完成旧客户端窗口、数据权利与恢复验证。
12. `W11 schema contract/retire`：独立批准后删除旧列/表/trigger/代码，保留 migration/audit receipt。

每个 wave 编制前置条件、变更、owner、观测、自动暂停阈值、成功证据、rollback/compensation 和退出条件。迁移默认使用 **single authority + compatibility projection/outbox**，禁止 iOS 或 API 将同一 mutation 分别发送到旧/新 Authority。`authorityEpoch` 是 vault 级单调 fencing token；command、projection、cache 和 migration event 都必须携带并校验。

定义三段 rollback：pre-cutover 可关闭 shadow/backfill 并保持旧 Authority；cutover 后只能停新 command、关闭 exposure、切到由新 Authority 生成的兼容 projection，不能恢复 legacy 写权或删除新事实；schema contract 后只能使用 forward fix/restore-to-new-environment，不承诺旧二进制直接运行。

## Acceptance Criteria

- Product Spec 包含 migration run 状态机、至少 11 个 wave 及逐 wave 的 precondition/change/verify/pause/rollback/exit。
- 明确 DB connection/UoW、版本化 migration、backup/restore、lock timeout 和线上 inventory 是 W0 blocker。
- 定义 old/new canonical comparison 字段、mismatch 等级、zero-tolerance blocker 和连续验证窗口。
- 定义 deterministic vault cohort、authorityEpoch fencing、single authority 和 compatibility projection。
- 任何 dual-write 例外都限制在同一数据库事务/同一 commandId，且只是 authority + projection/outbox，不形成第二 Authority。
- pre-cutover、post-cutover、post-contract rollback 边界明确；已确认 MemoryVersion、Inbox 和 Provider effect 不被 rollback 删除。
- 旧客户端、旧 route、旧 projection 和旧 schema 的 contract/retirement gate 明确。
- 至少 12 个 wave/cutover/rollback 故障场景有预期结果。
- 增加 `product-v4-data-cutover-check.py`，并同步证据矩阵为 `DESIGNED / NOT_IMPLEMENTED`。

## Verification Plan

- 静态门禁检查 wave 数量、必需列、authorityEpoch、single-authority、mismatch、rollback 和 contract/retire 条款。
- 对照 3C1A catalog，证明每类数据都有进入 wave 和退出/隔离路径。
- 独立 reviewer 攻击：旧写追平丢失、双 Authority、epoch stale write、canary rollback、projection divergence、旧客户端写入和过早 schema contract。
- 运行所有 Product V4 门禁与 `git diff --check`。
- 本轮不执行真实 migration/canary；Postgres backup/restore、锁、性能和 RPO/RTO 仍标后续实施证据。

## Risks

- 当前没有线上客户端版本与数据规模，cohort 比例、窗口时长和非 blocker mismatch 预算只能先定义决策门，不能伪造数值。
- cutover 后若已有 V4-only write，就不存在“把 legacy 重新设为 Authority”的无损 rollback。
- 旧客户端长期存活会延迟 W10/W11，但不能因此让旧写绕过新 Authority。
- Provider/object 副作用的未知结果由 3C3 负责；本子任务只定义其数据库引用和 fencing 边界。

## Assumptions

- 3C1A catalog 和 Round 3B data/Job contracts 是输入基线。
- migration runner 与 API/worker 使用同仓库版本，但作为独立命令和权限主体运行。
- Round 3C2 将细化客户端/API/Auth rollout，3C4 将汇总全域 go/no-go 与退役 runbook。
