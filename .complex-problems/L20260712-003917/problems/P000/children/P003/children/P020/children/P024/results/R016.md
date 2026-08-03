# Round 3A1 iOS 目标分层与当前模块迁移结果

## Summary

已形成可渐进实施、可回滚且不改变现有 Stitch UI 的 iOS 目标分层方案。该方案把当前实现映射到明确边界，并为后续后端边界、数据合同和可执行路线图提供稳定输入，但不等同于生产代码迁移完成。

## Done

- 在 `DreamJourney_V4_产品定义与目标架构_Product_Spec_V4.0.md` 新增“iOS 目标分层与渐进迁移”章节。
- 明确六层目标结构及单向依赖：AppShell / Composition、Feature UI + ViewState + Intent、Application Use Cases、Domain Models + Policies + Ports、Infrastructure、Runtime Adapter。
- 明确禁止依赖：Domain 不依赖 UIKit、URLSession、UserDefaults、AVFoundation 或 provider SDK；Feature 不直接消费 transport DTO、存储实现或 provider callback。
- 区分 authority、local draft、cache/projection 与 runtime state，避免把 KBLite、provider session 或本地展示缓存提升为权威事实。
- 建立 Capture、Archive Review、Owner QA、Profile/Data Rights、Voice/Digital Human Beta、Family/Care/Time Letter Future 等 feature 边界。
- 将 30 个当前 iOS 模块映射到目标层，逐项记录现状职责、目标位置和渐进迁移动作。
- 给出不改 Stitch 视觉、不重写 UIKit 的 Strangler 顺序：先建立 typed contract、mapper、port 与 contract test，再逐 feature 抽取 use case 和 view state。
- 明确账号切换、登出清理、旧 KBLite、Echo runtime 与 provider SDK 的测试 seam 和回滚边界。

## Verification

- Round 3A1 结构检查通过：目标章节、六层、模块迁移矩阵、迁移顺序和测试 seam 均存在。
- 当前模块映射行数为 30，超过验收标准要求的 12 个。
- Product V4 文档检查通过：36 个需求、21 个冲突、39 个决策、43 条独立评审响应、4 个源文档生命周期标记。
- 本轮未修改生产 Swift 文件，因此不声称 iOS 分层迁移已经实施。

## Known Gaps

- 目标层仍需在实际迁移任务中通过 Swift target/module、编译依赖或静态规则逐步强制，当前是文档级约束。
- `DreamJourneyBackendClient`、`EchoViewController`、`MemoryArchiveRepository` 等大文件的拆分边界需按路线图逐项落地，不能一次性重构。
- 独立 iOS reviewer 的最终意见需在成功检查阶段纳入；若发现 blocker/high，必须先修正文档再关闭该问题。
- 本轮未运行 iOS 构建或模拟器测试，因为没有生产代码变化；最终 Round 5 仍需运行文档检查、`git diff --check` 和适用的工程验证。

## Artifacts

- `docs/product/DreamJourney_V4_产品定义与目标架构_Product_Spec_V4.0.md`
- `docs/plans/task_27_round_3a1-ios-boundaries.md`
- `docs/plans/task_27_round_3a1_solution.md`
- `docs/plans/task_27_round_3a1_result.md`
- `Scripts/QA/product-v4/product-v4-docs-check.py`
