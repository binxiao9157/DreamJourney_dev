# Round 2D1 Product Spec V4 内容补全方案

## Problem Definition

Product Spec 当前足以表达定位与领域边界，但还不能单独回答每个阶段具体交付什么、AI 如何取证和降级、哪些安全条件阻断发布、数据权利如何呈现，以及质量/成本/运营如何验收。

## Proposed Solution

1. 收紧用户/指标：成人中文 iPhone Owner、文字优先、单 Persona；北极星改为后续有来源问答中明确有帮助的可信记忆复用。
2. 建立按能力域的产品合同和 Definition of Done，链接 36 FR 的阶段映射。
3. 定义 AI 输入、Candidate、检索、引用、不确定性、纠正、身份披露、prompt injection 和高风险表达规则。
4. 定义隐私/安全/第三方、导出删除、provider、Voice/DH 的产品边界与外部门。
5. 定义功能/安全/可靠性/延迟/可访问性/成本/可观察性指标及“未测不宣称”的原则。
6. 定义 server/release policy、feature flag、kill switch、运营权限和当前工程复用/冻结范围。
7. 将所有开放问题链接到决策登记册，不在正文暗示已批准。

## Acceptance Criteria

- Product Spec 形成完整目录且无待集成占位。
- 36 FR 均能从阶段表进入相应产品合同或阶段门。
- AI 身份和危机场景规则明确且列为 Stage 0 阻断。
- 指标、术语和决策登记册一致。
- 质量目标区分 target、release gate、external acceptance，未测试能力不被写成已达成。

## Verification Plan

1. 检查必需章节和关键词。
2. 检查 FR、decision 和 external gate 引用。
3. 搜索待集成/TODO 和绝对承诺。
4. 运行 Product V4 checks 与 `git diff --check`。

## Risks

- 把架构实现细节提前冻结在产品规范。
- 用固定 SLO 数字冒充已有基线。
- 新增规则与现有代码事实冲突却未标缺口。

## Assumptions

- SLO 初始值可标为推荐 target，需种子数据和外部验收再确认。
- Round 3 会把产品合同翻译成模块、API、schema 和迁移计划。
