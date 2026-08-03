# 委托安全/隐私/运维/过度设计独立复审

## Problem Definition

需要第三个独立视角判断 V4 是否仍包含不安全默认、权利/删除死锁、供应商锁定、无法测量的 SLO、成本不可控或超出当前规模的复杂架构，并给出必须先做、可延后、应删除三类建议。

## Proposed Solution

委托独立 explorer 只读 Product Spec、Decision Register、Evidence Matrix 和少量安全/运维实现证据。报告使用 SOR-01...，按严重度、分类、证据、影响、建议输出，并额外标记 `MUST_NOW/DEFER/REMOVE_OR_SIMPLIFY/EXTERNAL_GATE`。

## Acceptance Criteria

- 覆盖 principal/grant/purpose、第三方/未成年人、Publication/Visitor、Voice/DH、Provider credential/retention/delete、rights、audit、incident、RPO/RTO/cost。
- 显式检查客户端长期密钥、私人过滤视图公开、system绕过、假删除、真实数据dual-send、指标无分母和大爆炸迁移。
- 至少引用 8 个文档/代码/配置证据和 5 个 Product Spec 章节。
- findings 有唯一ID、严重度、分类、优先动作、证据、影响、建议。
- 给出攻击/数据权利/供应商退出/灾难恢复压力测试和剩余外部决策；不修改文件。

## Verification Plan

主控核对报告覆盖、引用、行动分类与压力测试；findings 交给 3D4 disposition。

## Risks

- 评审可能把所有目标机制都视为过度设计；必须区分安全必要性与当前规模实施顺序。
- 合规结论不能由模型批准；只能标风险和需要 Privacy/Legal 的外部门。

## Assumptions

- 本评审不是法律意见，也不关闭任何 External decision。
- Agent 只读，不修改工作区。
