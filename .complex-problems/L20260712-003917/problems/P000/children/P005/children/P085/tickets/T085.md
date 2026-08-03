# 并行完成产品、工程与安全运维三份只读独立复审

## Problem Definition

五份V4成果物中的四份已形成，Round 4静态门已通过，但同一推导链可能形成共同盲点。第一轮必须以三个互不依赖的视角重新读取权威输入、当前双仓证据和成果物，并输出可定位发现。

## Proposed Solution

1. 冻结审查基线：iOS `8a1922b`、后端`4c0538b`、Round4 Trace/Registry哈希与四份当前成果物。
2. 并行分配三个只读审查任务，写入互不重叠的报告文件：
   - 产品/PRD：产品定位、核心闭环、角色、信息架构、36 FR、41 DR、范围和状态声明。
   - 工程/证据/路线：iOS/后端真实证据、架构边界、115 WI依赖、测试/部署/rollback和过度承诺。
   - 安全/隐私/运维/成本：Account/Authority、数据权利、不可逆动作、Provider退出、凭据、并发、成本、SLA与过度设计。
3. 每条发现使用`R5A-PROD-*`、`R5A-ENG-*`或`R5A-RISK-*`稳定ID，包含severity、evidence、impact、recommendation、suggested owner和verification。
4. 主控只校验报告格式和证据可定位性，生成只做去重映射、不改变原始severity或结论的Wave 1索引。

## Acceptance Criteria

- 三份报告由三个独立agent输出，原始内容保留。
- 每份报告都列出审查范围、已读基线、发现和“未发现但仍有残余风险”的部分。
- 所有P0/P1有精确文件/章节或代码证据，不接受泛化评价。
- Wave 1索引覆盖全部发现、重复关系与冲突关系，不提前做disposition。
- 报告不包含secret值，不修改权威成果物或生产代码。

## Verification Plan

- 检查三份报告的agent标识、时间、基线hash、ID前缀和必填字段。
- 随机抽取每份至少三条发现，验证文件/章节存在且证据支持结论。
- 检查ID唯一、severity合法、P0/P1无缺失evidence/impact/recommendation。
- 运行敏感模式扫描和`git diff --check`。

## Risks

- 三个agent可能重复同一问题；保留原始发现，在索引中标duplicate，不强行合并。
- 审查者可能把建议写成事实；报告必须按现有五类主张标签区分。
- 审查范围很大；优先输出P0/P1，P2只保留对最终一致性有价值的项。

## Assumptions

- 审查者只读，不直接修正文档。
- 第一轮报告是输入，不是最终Authority；处置由Round5B主控完成。
