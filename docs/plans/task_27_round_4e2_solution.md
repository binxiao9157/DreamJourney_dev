# 建立路线执行注册表、确定性 Selector 与总验收 Checker

## Problem Definition

现有路线图已定义 13 Package 和 115 个 16 字段 Work Item，但依赖、Authority lock、当前执行状态和 Gate 仍主要存在于自然语言中。分散 checker 不能证明全量依赖无环、Optional 不进入 P0 核心、MIG 不拥有业务状态，也不能在相同状态与证据下确定性选择唯一下一项。

## Proposed Solution

将本问题拆为两个可独立验收的闭环：

1. **Roadmap execution metadata 与 selector**：在路线图新增机器可读的 Package/Work Item 执行注册表，明确 typed start/exit dependencies、priority/lane、authority lock、release class、current lifecycle/decision、execution owner、required gates/evidence state 和 stable selector rank；修正 MIG 只拥有 go/no-go evidence、不拥有业务 aggregate 的边界。定义 incident、evidence expiry、dependency/decision变化后的状态回退与重排算法，并更新 header/第6节为 Round 4 已完成、仍待 Round 5。
2. **总 checker 与负向证明**：新增 `product-v4-roadmap-check.py`，独立解析 roadmap 和执行注册表，验证 13/115/1840、ID/字段/枚举、依赖引用、DAG、Package/WI 父子、P0/Optional/Owner core/MIG 不变量、Gate 状态上限和 selector 唯一性；内存负向 fixture 覆盖缺字段、悬空依赖、依赖环、非法状态/priority/gate、Optional 混入 core、MIG 第二 Authority、双 next action 和 evidence 过期未重排。

## Acceptance Criteria

- 13 Package、115 Work Item、1840 字段和 typed execution registry 精确对齐，无重复、缺失或悬空引用。
- start/exit dependency、authority lock、release class、Gate/evidence 和 lifecycle/decision/owner 使用有限枚举，依赖图无环。
- P0 Owner text core 不依赖 Publication/Voice/DH；Optional 默认关闭；MIG 只能授权/记录迁移门，不成为业务状态 Authority。
- 相同 registry/evidence/incident 输入只能选出一个 next Work Item；当前基线唯一 next action 必须是允许的 stop-loss 或 `WI-MIG-01-01`，不得越过未关闭依赖。
- 证据过期、incident、open decision、外部门缺失会确定性降级/暂停并触发重排，G0/G1 不会关闭 G2-G4。
- 路线图状态明确 Round 4 工作项与静态验收完成，但仍是 Working Draft，待 Round 5 独立复审且不代表工程实现。
- 总 checker 自测、全部 Product V4 checks、链接检查和 `git diff --check` 通过。

## Verification Plan

先校验机器注册表与 115 Work Item/13 Package 精确集合，再构建依赖图做拓扑排序和 cycle fixture；对 priority/lane/status/gate/authority/release 枚举做正负检查；以固定 state/evidence fixture 连续运行 selector 比较输出；注入 incident、expired evidence、open G4、Optional default-on、MIG authority claim 等负例；最后运行全部 Product V4 脚本和 diff gate。

## Risks

- 115 行执行元数据若与正文重复维护会漂移；注册表只保留 selector/authority 所需 typed 字段，范围与验收正文仍以 16 字段 Work Item 为权威，并由总 checker 强制一一对应。
- 依赖存在 start/exit 两种语义，不能把外部门或 Package exit 当成所有 Work Item 的 start blocker。
- Selector 是计划执行器，不是自动授权器；`UNASSIGNED`、incident、外部门或 authority lock 缺失时只能输出 `NO_EXECUTABLE_ACTION` 或明确 stop-loss，不得自动启动实现。

## Assumptions

- Round 4E 只修改文档、生成物和 QA checker，不改 iOS/后端生产代码。
- 当前没有工程执行 Owner 或 evidence manifest，因此多数 Work Item 仍保持 `PLANNED/STOP/UNASSIGNED`；selector 只证明规则确定性。
- Round 5 负责独立复审五份最终成果物并决定是否从 Working Draft 转为审查完成状态。
