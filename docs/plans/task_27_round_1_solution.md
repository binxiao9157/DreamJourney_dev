# 并行事实审计与需求覆盖矩阵

## Problem Definition

Round 1 必须同时处理异构产品资料、Hermes/AOS 不完整源码、iOS 大型工程和后端生产合同。单线阅读容易把文档主张当源码事实，也难以发现跨仓接口缺口。

## Proposed Solution

拆成四条可独立验证的证据线：资料来源与冲突、iOS 实现、后端实现、FR requirement 汇总。前三条只读审计并输出带路径证据的结论；第四条将结果合并为统一矩阵，逐项标注实现成熟度和下一动作。

## Acceptance Criteria

- 来源资料按 authoritative/supporting/speculative 分级。
- iOS 和后端能力均有真实文件、类型/路由和 QA 证据。
- 所有 `FR-*` 需求 ID 被机器提取并映射一次。
- 成熟度枚举固定，不能用“已支持”掩盖 mock、hidden、provider 未验收或真机未验收。
- 冲突和未知项显式保留，不猜测补齐。

## Verification Plan

多 agent 分工审计；主 agent 复核关键路径并使用 `rg` 提取 requirement ID、路由、feature flag 和 QA gate；最终运行覆盖脚本，检查 requirement 无遗漏、状态值合法、文档链接存在。

## Risks

- 历史状态文档数量大且可能过期，必须优先信任当前源码与最新部署证据。
- iOS 单文件较大，行号可能随代码变更漂移；矩阵同时记录符号名。

## Assumptions

- 本轮不修改业务代码，审计不会改变运行行为。
- 最新附件为评审输入，不自动覆盖用户之前明确确认的产品决策。
