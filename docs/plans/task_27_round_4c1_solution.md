# 用十个迁移波次建立单一 Owner Truth Authority

## Problem Definition

现有 Archive、KBLite、Knowledge Governance、Context V2 和 Echo trace 提供了摄入、投影、提取与问答能力，但没有一条 Source → Candidate → Owner Decision → immutable MemoryVersion 的单一事实链。必须在保留现有 UI 和同步协议的同时，渐进引入新 Authority，并对所有 legacy 事实分级而不是批量升级。

## Proposed Solution

在路线图中为 `WP-S1-01` 建立十个连续 Work Item：

1. `WI-S1-01-01`：新增 Owner truth 核心 schema、状态约束、版本与 `authorityEpoch`。
2. `WI-S1-01-02`：建立文字 Source 创建 command、receipt 与 Archive compatibility facade。
3. `WI-S1-01-03`：把 extraction 结果持久化为只读证据，并生成原子 Candidate proposal。
4. `WI-S1-01-04`：建立 Candidate Inbox、Owner review transition 与 terminal DecisionReceipt。
5. `WI-S1-01-05`：建立 MemoryRecord、immutable MemoryVersion、current CAS 和 correction lineage。
6. `WI-S1-01-06`：由 Memory outbox 构建 KBLite/Knowledge compatibility Projection，禁止反向写 Authority。
7. `WI-S1-01-07`：Owner QA 只消费 active MemoryVersion/Projection port，并产生可解析 citation。
8. `WI-S1-01-08`：回答纠错定位 citation/version，创建 correction Candidate，不原地改图。
9. `WI-S1-01-09`：按证据等级迁移 Archive/KBLite/memories，执行 quarantine、shadow compare 与 backfill。
10. `WI-S1-01-10`：按 Owner `authorityEpoch` 做 cohort cutover、legacy writer retirement 与 Capture→Review→QA→Correction→Rights 集成门。

所有 Work Item 填满 16 个字段，明确 current/new file scope、Stage 0 依赖、API/event、迁移、release policy、部署、rollback、G0–G4 与非目标。SourceObject 真实上传、视觉/ASR Provider 和媒体质量属于 R4 后置项，不阻断文字核心。

## Acceptance Criteria

- 十个 ID 唯一、连续、无悬空依赖，且每项 16 字段完整。
- schema/API 使用 owner/vault、commandId、expectedVersion、authorityEpoch 与 receipt；同一时刻恰一 current MemoryVersion。
- Candidate 的 accepted/rejected/invalidated/expired 为终态；重新考虑或纠正创建新 Candidate/Version。
- KBLite、`kb_snapshots`、`kb_changes` 与现有 Context 只作为可重建 Projection/compatibility surface。
- failed analysis、observed、缺 Source/DecisionReceipt 的 legacy confirmed、草稿/未到期/未授权内容不进入 confirmed context。
- cohort cutover 后 legacy direct writer 不可恢复为 Authority；UI rollback 读取由新 Authority 生成的 compatibility Projection。
- Owner 文字核心在所有 Optional package 关闭时可完成并具有数据权利最小门。

## Verification Plan

1. 对照 Product Spec 11、15、29–34 及实现证据矩阵的 FR-CHAT/MEM/QA 条目。
2. 用当前 Archive/KBLite/Knowledge/Context 文件与 backend route/store 证据校准每项 scope。
3. 静态检查 10 个 ID、16 字段、依赖、Optional 隔离、迁移/rollback 和 gate。
4. 运行 Product V4 architecture/invariant/review/link checks 与 `git diff --check`。
5. Round 4E 再证明 FR/DR/finding 全量追踪，Round 5 独立复审第二 Authority 与过度设计风险。

## Risks

- 当前 `confirmed` 标记缺少 Owner decision receipt；自动映射会制造虚假记忆。
- 新旧 projection 双读容易被误解为双 Authority；所有新写只进 V4 aggregate，legacy 只兼容读/派生写。
- correction 与 delete 会影响 citation；必须保留不可变版本并以新版本、suspend 和传播事件处理。
- Stage 0 身份、DB 与本地隔离未退出前，Stage 1 最高只能完成设计、fake、shadow 或 `INTERNAL_READY`。

## Assumptions

- 本票据只编辑路线图与验证脚本，不修改生产代码。
- 第一轮 Owner core 只要求文字 Source；图片/音频/视频对象与真实 processor 在后续独立 cohort。
- Existing UI 通过 facade/ViewState 保持，Candidate Inbox 的最终公开信息架构仍受产品验收门约束。
