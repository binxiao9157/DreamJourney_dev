# Round 4A 路线图控制模型、阶段与依赖 DAG 结果

## Summary

已创建 V4 可执行路线图的权威骨架，固定状态词典、任务合同、五类验收门、13 个稳定工作包、package 级依赖 DAG、critical path、Stage/Voice/Migration increment 和后续子问题所有权。当前骨架不包含伪造工期，也不把 package 表解释为可直接实施的原子任务。

## Done

- 建立路线图权威和冲突处理规则，区分 Product Spec、Evidence、Decision、Review Response 与工程顺序。
- 定义 `PLANNED` 至 `RETIRED` 状态和 16 项 Work Item 必填合同。
- 定义 G0 非真机、G1 模拟器、G2 Postgres/部署、G3 Provider、G4 真机/产品/法律五类门。
- 精确登记 13 个 package、12 个 canonical risk、priority/lane、start/exit dependencies 与主要退出门。
- 建立无环 Mermaid DAG、Owner critical path、可并行条件和 `WP-MIG-01` 非第二 Authority 规则。
- 定义 R0–R5、RV0/RV1、RC release increments 和各 Stage 进入/退出/stop-the-line 条件。
- 明确 Round 4B–4E 的章节所有权，未填部分不冒充完成。

## Verification

- Roadmap control check：13 package、28 条实线依赖、13 个 DAG 节点，无环。
- 路线图 4 个相对文档链接均存在。
- Architecture review check：22 finding、12 risk、13 package，通过。
- Architecture invariant check：13 sections、6 iOS layers、12 backend modules、36 FR、41 DR，通过。
- Product V4 links check 与 `git diff --check` 通过。

## Boundary

- Stage 0、Owner Core、Optional/Migration 的 atomic work items 尚由 P052–P054 负责。
- FR/DR/finding/CR 全量追踪和正式 roadmap checker 尚由 P055 负责。
- 路线图仍为 Working Draft，不证明生产实施或外部门完成。

## Artifact

- `docs/superpowers/plans/2026-07-12-dreamjourney-v4-executable-development-roadmap.md`
