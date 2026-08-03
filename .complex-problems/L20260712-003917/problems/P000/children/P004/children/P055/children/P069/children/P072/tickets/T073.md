# 建立可生成、可复核的V4双向追踪矩阵

## Problem Definition

canonical ID已经干净，但当前信息分散在Product Spec、证据矩阵、决策登记册、独立评审和路线图中。仅搜索ID无法回答一个需求为何实施/延迟/拒绝、一个Work Item反向服务哪些目标、外部门和证据是否允许状态升级。

## Proposed Solution

新增正式路线追踪矩阵，以FR、DR、Finding、CR、Package、Work Item和TraceEdge七类注册表表达双向关系；为每类定义关系类型、状态上限、owner角色、gate/evidence边界。矩阵的115个Work Item从canonical roadmap结构化抽取，人工维护少量FR primary/deferred、DR治理关系和finding/package下钻；新增checker验证集合、反向边、父子关系、finding→CR→package→WI、开放决定状态与外部门上限。

## Acceptance Criteria

- 文档覆盖36 FR、41 DR、22 finding、12 CR、13 package、115 WI且无重复/孤儿。
- 每个FR终止于`PRIMARY_WI`、`DEFERRED_BY_GATE`或`REJECTED_BY_DR`，并有反向WI边。
- 每个DR具有实施/阻塞/外部门/无需工作/拒绝关系，状态与登记册一致。
- 每个finding恰一CR；响应声明的finding/package对至少有一个包内WI下钻。
- 每个WI恰一父package，引用ID均合法，状态上限不越过open/failed/expired G2–G4。
- checker含负向self-test，能拒绝孤儿、反向边缺失、状态越权、非法ID和关系不一致。

## Verification Plan

运行矩阵生成/检查、双向集合比较和negative self-test；运行全部Product V4检查及`git diff --check`；由独立agent审查至少FR、DR和finding链各一轮。

## Risks

- 115行人工复制容易漂移，需以生成器/机器注册表减少重复手工真相。
- 生成结果不能把路线计划状态升级成工程实现状态，状态必须来自证据矩阵与外部门。

## Assumptions

- 路线图仍是Work Item范围/顺序权威，追踪矩阵只组织关系，不重新定义产品目标。
- 当前没有FR可标`PROD_VERIFIED`；外部门缺失时最高`INTERNAL_READY/EXTERNAL_BLOCKED`。
