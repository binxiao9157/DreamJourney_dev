# Round 2D2 独立复审响应与 Product Spec 验收方案

## Problem Definition

三类独立审查已产生具体异议，但若不建立响应表和最终复审，无法证明这些意见真正进入 Product Spec。现有静态脚本也未检查完整章节、待集成占位、review IDs 和绝对承诺上下文。

## Proposed Solution

1. 建立 Round 2 独立评审响应文档，给产品/范围、领域/权限和反方风险每项稳定 ID、严重度、响应状态、落点和残余决定。
2. 对接受或部分接受的异议检查 Product Spec/登记册是否真实修改；不能解决的进入 Decision ID。
3. 启动一个未参与编写的独立 reviewer，只读审查完整 Product Spec、矩阵和登记册，输出阻断/非阻断问题。
4. 修正 reviewer 发现的真实阻断，不为了“全绿”压低风险；无法修正的进入登记册。
5. 强化脚本检查必需章节、review response IDs、无待集成占位和受控过度承诺措辞。

## Acceptance Criteria

- 三类初始审查的高风险异议均有 response ID、处理和证据落点。
- 新独立 reviewer 无未处理的阻断项。
- Product Spec、矩阵和登记册没有自相矛盾的范围/指标/状态。
- 文档检查能发现缺章节、漏响应、待集成占位和新增绝对承诺。
- 全量静态检查与 `git diff --check` 通过。

## Verification Plan

1. 运行独立 reviewer 并保存结论摘要。
2. 比较 response ID 集合与检查脚本要求。
3. 搜索 Product Spec/登记册的冲突措辞和旧指标。
4. 运行 Product V4 docs/evidence checks 及 `git diff --check`。

## Risks

- 独立 reviewer 重复已有意见而不提供新价值。
- 过度承诺检查误报引用或禁止性说明。
- 响应表只标接受却没有正文落点。

## Assumptions

- Round 5 还会进行全成果物最终审查；本轮验收只证明 Product Spec 足以作为 Round 3 输入。
