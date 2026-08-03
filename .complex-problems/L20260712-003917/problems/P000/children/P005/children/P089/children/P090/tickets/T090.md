# 建立双状态disposition、第五成果物初稿与机器检查

## Problem Definition

23条第一轮发现同时混合了“文档缺陷”和“工程路线尚未实施”。若只用单一closed/open状态，要么无法完成文档定稿，要么会把真实工程P0误报为修复。需要双状态处置并生成第五成果物。

## Proposed Solution

1. 为23条raw finding逐条登记：review severity、disposition、document review status、underlying implementation status、Authority Work Item/Gate、verification。
2. 文档层允许`FIXED/ACCEPTED/DECISION_REQUIRED/EXTERNAL_REQUIRED/REJECTED_WITH_REASON`；底层只允许真实的`OPEN_BLOCKER/PLANNED/EXTERNAL_BLOCKED/DECISION_OPEN/ARTIFACT_COMMIT_REQUIRED`，禁止无证据写COMPLETE。
3. 生成`DreamJourney_V4_评审与验收清单_V1.0.md`初稿，收敛P0 stop、P1/P2、不可逆动作、G0-G4、13 Package验收、发布/回滚/退出和未授权事项。
4. 新增`product-v4-review-disposition-check.py`，独立验证三份报告23个ID/计数、23条disposition、一致性、P0文档闭环但底层未过度声明、第五成果物固定数量和Round5C pending边界；加入负向self-test。
5. 运行全部现有Product V4检查、review checker和diff gate。

## Acceptance Criteria

- 23条发现一一处置，无遗漏、重复或silent severity change。
- 7个P0在文档层全部有处置，但实现层不得标完成；P1无无理由开放。
- 第五成果物存在并可供第二轮审查，状态明确为Round5B draft/Round5C pending。
- Review checker默认和至少四类负向fixture通过。
- 现有全部Product V4 checks与`git diff --check`通过。

## Verification Plan

解析三份报告的ID/severity和第五成果物disposition表；比较精确集合；注入缺ID、P0无disposition、P0实现COMPLETE、外部门误关、数量漂移等负例；运行全量门。

## Risks

第五成果物不能复制全部路线正文；只引用Work Item/Gate。`ACCEPTED`只代表审查意见被接受并映射到Authority，不代表代码修复。

## Assumptions

本轮不修改生产代码；所有实现类风险继续保持STOP/PLANNED/EXTERNAL_BLOCKED。
