# WI-S1-01-06 MemoryVersion Projection Foundation

日期：2026-07-19

## 当前状态

- Work Item：`WI-S1-01-06`
- Authority lock：`OWNER_TRUTH`
- 执行结果：`SCOPED_G0_G2_PROJECTION_EVIDENCE_PRESENT / KBLITE_READ_ENVELOPE_DEPLOYED / G1_G3_G4_OPEN`
- 范围：只实现确认态 `MemoryVersion` 的 owner-only、默认关闭、可重复重建 Projection 基础；不切换 KBLite、Context Packet、Echo 或公开 UI。

## 已实现

### 后端

- 新增 `owner_truth.memory_projection_checkpoints` 与
  `owner_truth.memory_projection_entries`，按 `vaultId + authorityEpoch`
  分区保存兼容快照。
- 只从 current/active 的 `MemoryVersion` 和 active Source 构建；缺
  checkpoint、Source 撤销、MemoryVersion 变化或 epoch 不匹配时返回
  `rebuilding` 空结果，拒绝复用旧快照。
- Projection 只保存 confirmed content、`contentHash` 与 citation；不复制
  Candidate 原始提案、DecisionReceipt、review rationale。
- 新增仅 QA 可见的 read/rebuild 路由，需 feature env、QA header 和 Owner
  user session；响应仅返回摘要，不返回正文。
- 线上首轮 Postgres smoke 发现 `0016` trigger 的
  `schema_version` 变量映射错误；已通过 append-only `0017` 迁移修复，不改
  写已应用 migration 的 checksum。

### iOS

- 初始 Projection foundation 没有修改 iOS runtime、Archive、KBLite、Context
  Packet 或 Echo UI。
- 后续 bounded read-envelope 子闭环新增了 QA-only typed parser 和独立的
  `OwnerTruthKBLiteCompatibilityStore`；它不读取/写入 legacy KBLite，也没有公开
  入口。详见 `2026-07-19-wi-s1-01-06-kblite-compatibility-read-envelope.md`。

## 验证证据

### G0

1. 后端 focused Projection/migration/API 测试 16 项通过。
2. 后端 `./scripts/verify_backend.sh` 通过：679 个单测，以及 credential、FastAPI、knowledge、backup 等 smoke。
3. `git diff --check`、Python compile 与 shell syntax 检查通过。

### G2

1. Backend `1109a64 feat(v4): add owner truth memory projection` 已推送。
2. Backend `9ac88e3 fix(v4): repair memory projection trigger mapping` 已推送；服务器已应用 migration `0017`。
3. Backend `f1f37c5 test(v4): align route authentication smoke inventory` 已推送并部署；随后 `162afb0 feat(v4): add owner truth compatibility read envelope` 已推送并部署，服务器当前 head 为 `162afb0`。
4. 服务器 Owner Truth Postgres smoke 通过，包含 deterministic rebuild、corrected content、Source revocation fail-closed、stale epoch 与 payload leakage 拒绝。
5. 服务器 route-authentication smoke 首轮通过，`routeCount=82`；线上 `/ready` 为 ready。
6. `162afb0` 部署后再次运行隔离 Owner Truth Postgres smoke，通过 read-envelope 的 standard-fact content hash、non-ready discard、敏感字段过滤与 legacy isolation 验证。
7. `162afb0` 部署后 route-authentication Postgres smoke 通过，`routeCount=91`，并确认匿名用户、机器 principal 与用户 principal 的路由边界仍然 fail closed。
8. 部署后 API、Postgres 和 Redis 均为 healthy，`/ready` 返回 database、schema、auth、incident 全部 ready。

## 明确未做

- 未把 KBLite 改为 Projection reader，也未删除其 legacy writer。
- 未让 `/context/build` 或 Echo 读取该 Projection，未返回 typed Citation。
- 未实现 rights event/outbox 驱动的自动重建。
- 未开放公开 API、UI 或 iOS feature flag。
- 未把 `WI-S1-01-06` 标记为 Registry 完成；它仍需要 G1 与后续子闭环。

## 下一项

read-envelope 的 G2 部署与 smoke 已完成。下一步进入 `WI-S1-01-07` 的 Owner QA Context
与 typed Citation 子闭环；保持 legacy KBLite 不能成为 confirmed-fact Authority。
