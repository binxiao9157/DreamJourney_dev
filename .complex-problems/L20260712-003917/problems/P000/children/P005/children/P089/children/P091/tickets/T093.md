# 用三个新上下文并行盲审五份成果物与Round5B处置

## Problem Definition

Round5B由主控处置第一轮发现，可能存在选择性接受、severity弱化、状态漂移或新引入矛盾。第二轮必须由未参与第一轮和处置的新agent在不读取Round5A原始报告的条件下反证。

## Proposed Solution

1. 冻结五份成果物、Trace/Registry、Round5B checker输出与双仓baseline。
2. 并行启用三个fresh agent：产品、工程、风险。只读取五份固定成果物、必要双仓证据和验收清单，不读取Round5A原始报告/索引或历史评审。
3. 每个agent输出独立报告：新发现ID为`R5C-PROD/ENG/RISK-*`；同时对分配的第一轮P0/P1 ID给出`VERIFIED/CHALLENGED`与证据。
4. 主控生成Wave2索引，确保第一轮22个P0/P1均至少一次复核；重复/冲突保留，不做最终处置。

## Acceptance Criteria

- 三个fresh agent、三份独立报告，读取范围和独立性明确。
- 22个第一轮P0/P1全部有VERIFIED/CHALLENGED，缺一不可。
- 新发现有稳定ID、severity、证据、影响、建议和验证；不凑数。
- 报告不修改Authority或生产代码，不包含secret。
- Wave2索引记录新发现计数、challenge和覆盖，不提前修改最终成果物。

## Verification Plan

比较验收清单P0/P1 ID集合与三份报告validation集合；验证精确覆盖、ID唯一、状态合法、证据可定位和diff gate。

## Risks

审查者读取验收清单会看到第一轮结论摘要，但不读取原始报告，避免直接复制论证。重叠复核允许，但必须覆盖全部22条。

## Assumptions

第二轮仍不执行生产代码变更或外部Gate。
