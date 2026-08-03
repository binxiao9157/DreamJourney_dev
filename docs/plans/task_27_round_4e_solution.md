# 用双向追踪矩阵与机器可判定路线门完成 Round 4

## Problem Definition

路线图已包含13个package和Stage0/1/Optional/Migration原子工作项，但还缺需求→决定→风险→评审→package→Work Item→证据的全量闭环，以及验证ID/字段/依赖/DAG/状态/next-action的总checker。没有这两项，文档仍可能遗漏需求、把开放决定误报关闭或让agent按人工感觉选任务。

## Proposed Solution

拆为两个闭环：

1. **Round4E1 Traceability**：建立唯一追踪矩阵，逐项覆盖36 FR、41 DR、22 finding、12 CR、13 package和全部Work Item；记录source/status/primary owner/dependencies/gates/evidence/next action，开放DR和外部门保持open/blocked。
2. **Round4E2 Roadmap Acceptance**：新增`product-v4-roadmap-check.py`，解析13 package和全部Work Item，验证16字段、唯一ID、priority/lane/gates、依赖引用/DAG、P0边界、Optional default-off、Owner core独立、MIG非第二Authority、状态与确定性next-action/evidence invalidation规则。
3. 更新路线图header/第6节为Round4完成但仍Working Draft待Round5；定义全局next selector、状态变更和replan trigger。
4. 运行所有Product V4 checks、links、roadmap checker和diff gate。

## Acceptance Criteria

- 每个FR/DR/finding/CR/package至少一个明确primary owner和有效Work Item/gate，且反向无孤儿Work Item。
- `RECOMMENDED_PENDING/EXTERNAL_REQUIRED/open`不会因路线存在变closed，G2–G4不会被静态证据关闭。
- roadmap checker能发现缺字段、重复/悬空ID、非法状态/priority/gate、依赖环、Optional进入P0核心或MIG第二Authority。
- next-action规则在相同状态/evidence下给出同一任务，并在incident/evidence过期/dependency变化时重新规划。
- 全部检查通过且无生产代码改动。

## Verification Plan

- 对照各权威文档提取精确集合和状态，机器检查数量、顺序、双向覆盖与开放状态。
- 为roadmap checker加入正向运行和关键负例逻辑，不靠关键词总数制造假阳性。
- 运行全量checks与diff，Round5再由独立审查验证产品/工程/安全可执行性。

## Risks

- 一个Work Item映射过多FR会掩盖责任；必须有primary requirement/risk且多对多只是secondary。
- 依赖有意分start/exit，简单字符串DAG可能误判；checker需解析明确引用并允许package级external gate。
- 追踪完成不等于实现完成，矩阵必须携带当前成熟度和外部门。

## Assumptions

- Round4E只改文档/QA，不实施路线。
- Round5负责最终独立复审与五份成果物定稿。
