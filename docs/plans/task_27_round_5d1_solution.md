# 统一五份成果物状态、互链与两轮评审处置

## Problem Definition

五份成果物已具备完整内容，但头部仍混用 Working Draft、Round 5B Draft 与历史阶段状态，四份主文档不能反向定位验收控制面，Round 5C 新发现没有进入最终处置，因此存在读者漏读验收状态和状态漂移风险。

## Proposed Solution

- 在 Product Spec、Evidence Matrix、Decision Register、Roadmap 头部增加验收清单链接和统一基线声明。
- 将五份文档统一标记为 `REVIEWED_BASELINE_PENDING_COMMIT`，同时保留现有 checker 依赖的阶段短语。
- 更新验收清单版本与状态，新增 Round 5C 处置和证据章节，修复 `R5C-PROD-001`。
- 明确保留 `R5A-ENG-008=ARTIFACT_COMMIT_REQUIRED`、115 WI 未实现、G2-G4/外部门/开放决定未关闭。

## Acceptance Criteria

- 五份成果物均存在且四份主文档直接链接验收清单。
- 五份文档均出现 `REVIEWED_BASELINE_PENDING_COMMIT` 和工程不过度声明边界。
- 验收清单记录 Wave 2 expected/covered/verified/challenged=`22/22/22/0`。
- `R5C-PROD-001=FIXED`；`R5A-ENG-008=ARTIFACT_COMMIT_REQUIRED`。
- 现有 Product V4 checker、链接检查和 `git diff --check` 通过。

## Verification Plan

用 `rg`/静态脚本检查五份头部状态、链接和两项 finding 状态；运行已有全部 Product V4 checker 与链接、diff gate。

## Risks

不能删除现有 checker 所依赖的历史状态短语；不能把 reviewed baseline 误写成产品批准、工程完成或 clean checkout 证据。

## Assumptions

本轮不提交，最终状态必须保留 `PENDING_COMMIT`。
