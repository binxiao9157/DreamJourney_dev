# 固化 Round 4D 状态、跨 Lane 选择与机器防回归

## Problem Definition

32个Optional/Migration工作项已存在，但header/第6节仍旧，缺跨lane优先级和专用机器门。需要在不改变package实现状态的前提下收敛路线图口径。

## Proposed Solution

1. 更新header/第6节：Round4D文档完成，Round4E仍待；三包仍blocked/no-go。
2. 增加跨lane执行规则：先Voice/DH P0 containment与MIG C00/C01，Owner text优先；Publication/Voice/DH分别promotion。
3. 增加Round4D stop-the-line覆盖private/public、credential/consent/delete/ready/dual-send和migration phase fence。
4. 新增`product-v4-optional-migration-roadmap-check.py`验证三包、32项、512字段、状态与关键不变量。
5. 运行全量Product V4检查和diff gate。

## Acceptance Criteria

- 无Round4D待合入旧口径，且不把路线完成误写实现完成。
- 跨lane首要任务可确定为Voice/DH stop-loss或MIG C00/C01，而不是公开功能。
- checker能阻止private Projection公开、长期credential下发、假删除/ready、C10 removal和旧writer rollback。
- 全部检查通过，无生产代码改动。

## Verification Plan

- 运行新checker和所有Product V4脚本。
- 检查路线图header、第6节、第20后集成规则和Git diff。

## Risks

- Optional工作项多，完成路线可能被误读上线承诺；状态行必须保留blocked/no-go。

## Assumptions

- Round4E将提供全路线总checker与FR/DR追踪，本项只覆盖Round4D。
