# Round 3A1 iOS 目标分层与当前模块迁移成功检查

## Summary

结果 R016 满足 P024 的文档级目标：六层职责、feature 边界、authority 与本地状态边界、当前模块迁移矩阵、渐进抽取顺序和测试 seam 均已形成。该问题可判定成功；生产 Swift 迁移不属于本问题范围，仍需进入后续可执行路线图并由 Round 3D 独立架构评审复核整体一致性。

## Evidence

- Product Spec 第 22 节包含六层依赖图、允许依赖和禁止依赖。
- 第 22.3 节区分核心 feature、Beta 和 Future feature，禁止可选能力反向进入 Owner 核心。
- 第 22.4 节区分 authority、local draft、cache/projection 和 runtime state。
- 第 22.5 节映射 30 个当前 iOS 模块，超过至少 12 个的要求。
- 第 22.6、22.7 节分别给出渐进抽取顺序和测试 seam。
- Round 3A1 专项结构检查、Product V4 文档检查均通过。

## Criteria Map

- 六层职责与依赖：由第 22.1、22.2 节满足。
- 核心与 Beta/Future 边界：由第 22.3 节满足。
- authority 与本地状态边界：由第 22.4 节满足。
- 当前模块分类：由第 22.5 节 30 行迁移矩阵满足。
- 不改公开 UI 的迁移与验证：由第 22.6、22.7 节满足。
- 作为系统模块边界的一半：成果已作为 Round 3A 输入，待与 P025 后端边界汇总到 P020。

## Execution Map

- 本问题按 one_go 执行，只修改产品/架构成果物和 QA 文档检查，不移动生产 Swift 文件。
- 先定义目标层和 forbidden dependencies，再从当前代码模块建立迁移矩阵，最后给出按 seam 抽取的 Strangler 顺序。
- 结果 R016 记录完成项、验证和已知缺口，没有将文档产物误报为代码迁移完成。

## Stress Test

- 账号切换/登出：方案要求 account scope 由 AppShell 传入，用例与 repository 均显式携带 owner，禁止全局 UserDefaults 业务数据跨账号复用。
- provider 失败/数字人降级：provider SDK 与 AudioSession 被限制在 Runtime Adapter，Domain 和 Feature 只消费 typed capability/runtime state，普通 Echo 不依赖腾讯或火山 DTO。
- 旧 KBLite 与后端 authority 并存：KBLite 被定义为本地 projection/compatibility，不得成为新权威写入源；迁移可通过 shadow read 和 contract test 回滚。
- UI 回归：迁移顺序明确保留 UIKit、Coordinator 和现有 Stitch 视觉，只替换数据与状态 seam。

## Residual Risk

- 文档级 forbidden dependencies 尚未由 Swift module 或静态检查强制，需在实际迁移任务中逐步加入。
- 大型 ViewController/Client/Repository 的真实拆分仍可能暴露隐含耦合，必须按 feature 小步实施，禁止一次性重写。
- Round 3D 仍需独立审查 iOS 与后端目标架构的组合边界；发现 blocker/high 时应回开相关子问题。

## Result IDs

- R016
