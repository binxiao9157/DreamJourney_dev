# WI-S1-01-01 Owner Truth 核心 Schema 与约束

日期：2026-07-19

## 当前状态

- Work Item：`WI-S1-01-01`
- Authority lock：`OWNER_TRUTH`
- 执行结果：`VERIFIED / G0_G2_SCOPED_EVIDENCE_PRESENT / BACKEND_DEPLOYED / IOS_LOCAL_COMMITTED`
- 范围：只建立 Owner Truth 的增量数据主干与 typed contract；不切换公开 UI、不启用 Archive/KBLite 的权威写入，也不改变现有公开 MVP 行为。

## 已实现

### 后端

- 在独立 `owner_truth` schema 中新增 `vaults`、`sources`、`source_links`、`extraction_results`、`memory_candidates`、`decision_receipts`、`memories`、`memory_versions`、`memory_relations` 与 `correction_links`。
- 新增 `0011_owner_truth_core` additive migration；旧 `public.memories` 不迁移、不删除、不改为新主干。
- 固化 V1 ontology：`experience`、`knowledge`、`emotion`。
- 约束 vault owner 与 `authority_epoch`，候选终态不可逆，DecisionReceipt 需与候选终态一致且只能追加。
- 通过约束触发器保证单一 current MemoryVersion，并拒绝 relation cycle、跨 vault 关系和被引用 Source 的删除。
- Release flag `ownerTruthV1Read=false`、`ownerTruthV1Write=false`，本项部署后仍保持 write-disabled。

### iOS

- 新增 Owner Truth 的 typed ID、枚举、Source/Candidate/Decision/MemoryVersion contract 与只读 repository port。
- 新增候选决策的合法状态转换 contract；未接入 Archive、KBLite、Echo UI 或任何公开写路径。
- 将相关纯模型测试加入现有 SwiftPM/Xcode XCTest 承载面。

## 验证证据

### G0

1. 后端 `scripts/verify_backend.sh` 通过：599 tests passed，并包含 Owner Truth domain/migration contract 覆盖。
2. iOS `Scripts/QA/product-v4/run-owner-truth-schema-contract-gate.sh` 通过。
3. iOS `DJ_SWIFT_TEST_SCRATCH_PATH=.build/owner-truth-xctest Scripts/QA/product-v4/run-ios-test-foundation-gate.sh` 通过：SwiftPM XCTest 与 iPhoneOS generic `build-for-testing` 均通过。
4. 两仓库 `git diff --check` 通过。

### G2

1. 后端提交 `af13e44 feat(v4): add owner truth core schema` 已推送并部署。
2. 服务器执行 `migrate_db.py --apply --build-id af13e44` 后，迁移 head 为 `0011`。
3. 服务器执行 `scripts/run-backend-owner-truth-postgres-smoke.sh` 通过，确认：
   - Owner Truth 使用独立 namespace。
   - 单一 current version、终态决策不可变、receipt append-only。
   - relation cycle 被拒绝，Source 删除受限。
   - legacy `public.memories` 保持存在且未被本项改写。
4. 后续部署 `2529725 test(ops): align readiness smoke with incident component` 后，线上 `/ready` 与 deployed readiness smoke 均通过四个组件：`database/schema/auth/incident`。

## 提交与部署

- Backend：`af13e44`，已推送、部署；当前服务器后端 head：`2529725`。
- iOS：`cda3f28 feat(v4): add owner truth contracts`，仅本地提交，按当前执行约束不自动推送。

## 明确未做

- 未提供 `CreateSource` command 或 API route。
- 未让 Archive 通过 compatibility facade 写入 shadow。
- 未让 KBLite、Context Packet 或 Echo 读取 Owner Truth。
- 未启用 `ownerTruthV1Read` 或 `ownerTruthV1Write`。
- 未进行真机或 Provider 验收；这些不属于本 Work Item 的 Gate。

## 下一项

交接到 `WI-S1-01-02`：实现带 stable `commandId`、`expectedVersion` 与 receipt 的文字 `CreateSource`，并为 Archive 添加 write-disabled compatibility facade。继续保持本地照片诚实标记为 `local-only`，不得冒充已上传或已验证媒体。
