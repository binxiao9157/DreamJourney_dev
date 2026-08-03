# 定稿五份成果物并建立最终静态验收门

## Problem Definition

Round 5A/B/C 已完成两轮独立复审与处置，但五份固定成果物仍使用 Working Draft/Round 5B 状态，四份主文档无法反向定位验收清单，且没有一个终态 checker 同时验证两轮复审、处置完整性、派生物 fresh、链接与工程完成度不过度声明。

## Proposed Solution

1. 在 Product Spec、Evidence Matrix、Decision Register、Roadmap 顶部增加验收清单链接，统一为 `REVIEWED_BASELINE_PENDING_COMMIT`，同时保留已有 checker 依赖的历史状态短语。
2. 更新验收清单，登记 Round 5C 覆盖结果，处置 `R5C-PROD-001=FIXED`；保留 `R5A-ENG-008=ARTIFACT_COMMIT_REQUIRED`，明确五份文档定稿不表示 115 个 Work Item 实现或发布批准。
3. 新增独立 finalization checker 与负向 self-test，覆盖缺成果物、缺 review wave、P0/P1 未处置、外部门误关、计数/链接/Registry/Trace 漂移及实现过度声明。
4. 运行全量 Product V4 checker、生成器 self-test/check/确定性、链接、敏感信息和 `git diff --check`；形成 Round 5D 最终证据。

## Acceptance Criteria

- 五份固定成果物存在且互链到验收清单，版本/基线/状态口径一致。
- Round 5A 23 项全部有 disposition；Round 5C 22 项验证全部覆盖且 0 challenged；`R5C-PROD-001` 已修复。
- P0 文档处置无开放项；P1 均有处置、Owner/Gate 与未完成底层状态。
- `R5A-ENG-008` 在未提交前继续为 `ARTIFACT_COMMIT_REQUIRED`，不得宣称 clean checkout 已通过。
- finalization checker 默认与负向 self-test 通过，且覆盖至少 8 类指定漂移。
- 全量 Product V4 checks、双次生成确定性、敏感信息扫描、链接和 `git diff --check` 通过。
- 文档明确这是产品/架构/路线的 reviewed baseline，不是工程 115 WI 完成、G2-G4 关闭或发布批准。

## Verification Plan

- 解析五份文档头部状态、基线和验收清单链接。
- 对 Round 5A disposition、Round 5C validation 与新 finding 做精确 ID/计数比较。
- 对 Registry/Trace 运行生成器 check 和重复生成 hash 比较。
- 运行 `Scripts/QA/product-v4` 全部 checker 及 finalization negative fixtures。
- 运行链接、敏感信息和 `git diff --check`；最后运行 Closure Lodestar audit。

## Risks

- 现有 checker 依赖部分精确状态短语；定稿时必须兼容保留，避免无意义破坏。
- 当前工作树未提交，不能关闭 artifact clean-checkout 风险；最终状态必须诚实标为 pending commit。
- 终态 checker 只能证明文档和静态执行基线一致，不能替代真实工程、真机、Provider 或发布证据。

## Assumptions

- 本轮不提交、不推送、不修改生产代码或后端。
- iOS 基线保持 `feature/prd-stitch-ui-adaptation@8a1922b`，Backend 保持 `main@4c0538b`。
