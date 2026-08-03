# 独立解析报告与清单并用负向变体证明失败能力

## Problem Definition

第五成果物和23条处置由主控编写，人工计数可能共因漏项。需要不导入其他Product V4 checker的独立脚本，从原始Markdown重新解析并判定。

## Proposed Solution

新增`Scripts/QA/product-v4/product-v4-review-disposition-check.py`：解析三份报告的finding ID/severity、索引cluster、清单disposition和Package表；验证23/7/15/1/13、合法枚举、精确ID、P0文档闭环且底层禁止完成、P1 Owner/Gate、Round5C pending与固定Authority计数。`--self-test`复制文本并注入至少五类失败。

## Acceptance Criteria

- 脚本不import生成器或既有checker，baseline零错误。
- 缺ID、P0未处置、P0底层完成、外部门误关、数量漂移至少五类fixture产生明确错误。
- 默认与self-test通过，全部Product V4 checks和diff gate通过。

## Verification Plan

运行`py_compile`、默认、`--self-test`、全部脚本和diff；人工检查parser按表头/section识别而不是关键词总数。

## Risks

Markdown parser不能只统计`R5A-*`字符串；必须解析Finding heading和Disposition table，并比较精确集合。

## Assumptions

脚本验证文档处置，不关闭底层工程Gate。
