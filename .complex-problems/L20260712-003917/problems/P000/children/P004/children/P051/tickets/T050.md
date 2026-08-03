# 建立路线图权威骨架、阶段门与依赖 DAG

## Problem Definition

Round 4 的五个子问题将共同编辑同一份路线图。必须先固定文档权威、状态词典、验收门、package 目录和依赖 DAG，否则后续 Stage 0、Owner Core 与 Optional lane 会使用不同优先级和完成语义。

## Proposed Solution

1. 创建固定路线图文件，声明 Product Spec/Evidence/Decision/Review Response 的引用关系，以及路线图只负责工程顺序、不自动批准产品决定的边界。
2. 定义 package、work item、gate、evidence、release increment、external blocker 的状态词典和字段模板。
3. 精确登记 13 个 package 的名称、CR、priority、stage/lane、依赖、当前成熟度和主要退出门。
4. 绘制 package 级无环 DAG，标出 Stage 0 安全关键路径、Owner Truth Loop 路径、Optional lane 和贯穿式 `WP-MIG-01`。
5. 定义纯代码、模拟器、真实 Postgres/部署、Provider、真机/产品/法律五类验收门，明确哪些门可由自动化关闭。
6. 定义 Stage 0、Stage 1、Stage 2/3 与 Voice Beta 的进入/退出、stop-the-line、rollback/forward-fix 和 release increment。
7. 为后续子问题预留 package 详情和全量追踪章节，但不填伪造任务或工期。

## Acceptance Criteria

- 路线图文件存在并可独立阅读，含权威、状态、任务模板、package inventory、DAG、critical path、stage gates 和 release increments。
- 13 个 package ID 精确、唯一、无遗漏；CR-01..CR-12 映射完整。
- 依赖无环，Stage 0 前置、Owner core 与 Optional lane 边界清晰。
- Owner 文字核心在 Publication、Voice/DH、Family/Care/TimeLetter 全部关闭时仍有可发布 increment。
- 验收门明确区分自动化、真实环境、Provider、真机和产品/法律批准。
- 未填具体 package work item 的位置显式标为后续子问题所有，不用 TODO 冒充完成。

## Verification Plan

1. 对照 Round 3 Review Response 的 13 个 package 和 12 个 CR。
2. 人工拓扑排序 DAG，验证无环和所有依赖指向已登记 package。
3. 对照 Product Spec Stage 0/1/3、Voice Beta 和 C00-C11，确认路线没有提前关闭外部门。
4. 运行现有 Product V4 docs/architecture/link checks 与 `git diff --check`。

## Risks

- 骨架过度规定后续任务粒度；只固定可审计字段和依赖，不固定无证据工期。
- `WP-MIG-01` 被画成所有包的硬前置会阻塞 additive/shadow 开发；仅在 cutover/contract 前形成硬门。
- Optional lane 被错误放入 Owner critical path；DAG 必须明确 default-off 分支。

## Assumptions

- P052–P055 将在同一文件补充具体工作包和追踪验收。
- 本票不修改生产代码、不部署、不跑真机。
