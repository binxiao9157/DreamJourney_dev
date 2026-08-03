# Round 3C1A Legacy 数据目录与确定性 Backfill 方案

## Problem Definition

当前数据散落在后端 18 张表的 typed 列与 JSONB payload、Archive/KBLite 投影，以及 iOS 本地缓存中。必须逐项回答“迁什么、迁成什么、如何确定 ID/owner/vault、缺证据怎么办、如何重跑”，否则后续 migration wave 无法证明 Authority 一致。

## Proposed Solution

在 Product Spec 建立 `Legacy Data Migration Catalog`，每行至少包含：

- legacy store/table/column/path 与当前 authority/projection 身份；
- target V4 object 与模块 owner；
- migration class：`migrate / derive / project / quarantine / do-not-migrate / external-reconcile`；
- deterministic target ID 公式和 legacy locator；
- `ownerUserId / vaultId / subjectId / authorityEpoch` 推导规则；
- source/review/version/citation evidence 要求；
- canonical normalization/checksum；
- batch cursor/checkpoint、幂等冲突语义和重跑规则；
- invalid/ambiguous/quarantine 原因与人工裁决出口；
- 数据权利、retention 和删除传播；
- verification query/metric 与线上 `UNKNOWN` 输入。

Catalog 覆盖账号与 session、Archive/媒体、KBLite fact/graph、Memory/Echo、Context trace、TimeLetter/Inbox、Family/Care、Voice/DigitalHuman、Job/Provider receipt 等当前数据路径。确定性 ID 使用受版本控制的 namespace + canonical legacy locator，禁止内容 hash 单独充当 identity。旧 Archive/KBLite 内容只有具备来源与终态 review receipt 才可映射为 Confirmed MemoryVersion，否则映射为 Source/Candidate 或 quarantine。跨 owner/global-ID 冲突必须拒绝并隔离，不能沿用当前通用 upsert 转移 `user_id`。

同时定义 backfill runner 合同：稳定批次顺序、snapshot boundary、high-water mark、尾部追赶、每批事务、checkpoint only-after-commit、canonical checksum、dry-run diff、resume/replay、quarantine receipt 和最终 reconciliation report。

## Acceptance Criteria

- Catalog 至少覆盖当前 18 张后端表、iOS 关键本地 store 和 Round 3B 的 38 个目标逻辑对象，不能只列核心 happy path。
- 每行具备 legacy locator、target object、migration class、ID、owner/vault、evidence、checkpoint/checksum、quarantine 和 verification。
- 明确内容 hash 不等于 identity，ID namespace/version 可演进且重跑稳定。
- 缺 owner、source、terminal decision 或合法 visibility 的记录不会升级成 confirmed/recipient-visible 数据。
- 定义 snapshot + tail catch-up、每批事务、resume 和 replay，不以 offset-only 分页迁移可变数据。
- 跨 owner 冲突、重复/乱序版本、无效时间、孤儿媒体、未解析 JSONB、撤销 grant、Provider 未知状态均有确定处理。
- 至少 10 个 backfill 验收/故障场景。
- 增加 `product-v4-data-backfill-check.py`，校验 catalog 列、行数、migration class 和场景完整性。
- 当前证据矩阵将 catalog 标为 `DESIGNED / NOT_IMPLEMENTED`；线上 row count、冲突率、quarantine 比例保持 `UNKNOWN`。

## Verification Plan

- 对照后端 `PostgresStore`/schema SQL、iOS store 和 Product Spec 24 节逐项核对，无 legacy authority 或目标对象遗漏。
- 运行 backfill 静态门禁、data-contract、backend-evidence、docs 和 `git diff --check`。
- 独立 reviewer 重点攻击：ID 碰撞、owner 转移、confirmed 伪造、offset 漏数、checkpoint 提前、重跑重复和删除复活。
- 不执行线上查询或真实 backfill；实现阶段再采集 row count、size、skew、冲突和时间窗口。

## Risks

- iOS 本地缓存不一定全部能上传或归属到已认证账号，需要 `local-unclaimed` 隔离策略。
- 历史 KBLite fact 可能没有可追溯 Source，不能为了迁移率把它直接当真。
- 旧媒体路径可能已失效，只能迁 metadata 并标记 object missing。

## Assumptions

- Round 3B 的 38 个对象及 Authority 关系是目标基准。
- 迁移 runner 的具体语言/SQL 在实现任务决定，本轮冻结语义而非写生产迁移程序。
- 后端代码证据优先于历史文档，线上数据状态没有证据时标记 UNKNOWN。
