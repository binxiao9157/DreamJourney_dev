# 依次完成处置与清单、第二轮盲审、最终定稿

## Problem Definition

第一轮23条发现已完成独立取证，但尚未disposition。需要先由主控修正Authority成果物和生成验收清单，再由新上下文做第二轮盲审，最后处置新增P0/P1并建立finalization checker。

## Proposed Solution

拆为三个有严格顺序的子问题：

1. Round5B逐条处置23个raw finding，修正文档但不伪造工程实现，生成第五成果物初稿并重跑Round4门。
2. Round5C由新独立审查者复核五份成果物和第一轮P0/P1处置，只输出新报告与`VERIFIED/CHALLENGED`反证。
3. Round5D处置第二轮P0/P1，统一状态为文档`REVIEWED_BASELINE`，新增finalization checker与负向self-test，运行最终全量门。

## Acceptance Criteria

- 三个阶段按顺序成功关闭，不允许在Round5B后直接跳过盲审定稿。
- 第一轮23条和第二轮全部发现都有稳定disposition与验证证据。
- 五份成果物存在、互链、边界一致，不把路线实现状态提升。
- 最终checker和全部现有checker通过。

## Verification Plan

分别在B/C/D记录基线hash和结果；最终核对两轮review ID集合、disposition覆盖、P0/P1开放状态、五份文件、链接、Trace/Registry freshness、secret scan和diff gate。

## Risks

后续文档修正可能改变Roadmap并使派生物stale；每次Roadmap更新后必须重生成。第二轮审查必须使用新agent且禁止读取第一轮原始报告，只读取disposition摘要与五份成果物。

## Assumptions

Round5B-D不修改生产代码；实现类发现通过STOP/Work Item/Gate处置，而不是声称已修复代码。
