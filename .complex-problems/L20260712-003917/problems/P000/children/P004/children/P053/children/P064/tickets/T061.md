# 收敛 Stage 1 状态、跨包执行顺序与防回归检查

## Problem Definition

`WP-S1-01/02/03`已各有十个完整Work Item，但路线图header和第6节仍写Round4C待合入，且三个包只有各自批次，没有跨包选择规则。必须修正文档状态并建立机器门，防止重复开发、跨包乱序或把PLANNED误报实现。

## Proposed Solution

1. 更新header和第6节，明确Round4C已合入30项/480字段，Round4D–4E仍待完成。
2. 在第17节增加Stage1跨包批次：foundation、Owner decision、Projection/QA、Runtime/effects、migration/cutover。
3. 增加确定性下一任务和stop-the-line：一次只切一个Authority/Runtime owner；先测试/typed contract/shadow，再cohort；Optional关闭不阻断Owner text。
4. 新增`product-v4-stage1-roadmap-check.py`，验证三包、30个唯一ID、16字段、状态口径、批次、下一任务、stop rules和Optional隔离。
5. 运行专用检查、全部Product V4检查和`git diff --check`。

## Acceptance Criteria

- 文档不再同时声称Stage1待合入和已存在。
- 30项/480字段、三包当前`STOP/PLANNED`与Round4C完成可以同时被机器验证。
- 跨包依赖不会让S1-03切业务Authority或让S1-02 receipt拥有业务状态。
- 首个可执行Stage1任务可由规则唯一选择，但Stage0未满足时只允许fake/schema/shadow。
- 全部静态检查通过且不修改生产代码。

## Verification Plan

- 专用脚本正向运行，并人工检查其范围只读取路线图第15–17节及header。
- 运行17个既有Product V4脚本，确认追加章节未造成计数假阳性。
- 运行`git diff --check`并核对Git状态只含文档/QA/ledger。

## Risks

- “Round4C完成”可能被误读为功能实现；header和表格必须同时保留`PLANNED/STOP`与文档阶段说明。
- 跨包顺序若过度串行会阻止test/composition并行；区分start dependency与exit dependency。

## Assumptions

- 不修改13个canonical package、不改变Stage0首任务规则。
- Round4D/4E/5继续负责Optional/Migration、全量追踪和最终复审。
