# 用 canonical 集合和显式关系收敛路线引用

## Problem Definition

路线图存在伪 FR、范围/通配写法、Voice/DH 对 `DR-012` 的语义误用，以及缺失的 FR/finding 下钻边。若直接生成追踪矩阵，会把不存在的需求、被拒绝决定或文字范围误当实施覆盖。

## Proposed Solution

以 Product Spec 的36个FR、登记册41个DR、独立评审22个finding和12个CR为唯一ID集合：逐项替换路线中的非canonical `FR-*` 为精确ID或 `SCOPE-*`；从Voice/DH移除`DR-012`并保留其`ENFORCES_REJECTION`负向关系；补FR-ACC-001、FR-SAFE-002和IAR-06/IAR-07/SOR-04精确边；将FR-MEM-003/004写为`DEFERRED_BY_GATE`；增加canonical引用检查脚本并锁定总数115项/1840字段。

## Acceptance Criteria

- roadmap中所有`FR-*` token均属于36个canonical FR；范围标签只使用`SCOPE-*`。
- `DR-012`不再出现在Voice/DH实施项，只用于拒绝AOS组件的负向治理说明。
- FR-ACC-001、FR-SAFE-002、IAR-06、IAR-07、SOR-04有准确Work Item边。
- FR-MEM-003/004显式`DEFERRED_BY_GATE`且不伪造当前实现任务。
- 无`BAR-08`或其他非法finding；总计115 Work Item/1840字段与各专项checker一致。
- 新检查脚本能拒绝伪FR、非法finding、Voice中的DR-012、计数漂移和缺失关键边。

## Verification Plan

提取roadmap所有FR/DR/finding/CR/WI ID与权威集合做差集；运行新增canonical checker、全部Product V4 checks和`git diff --check`；使用临时变体证明关键负例能失败。

## Risks

- 机械替换可能改变产品语义，必须按每个Work Item实际结果选择精确FR或SCOPE，不以覆盖率强行挂需求。
- DR/FR未被实施不等于遗漏，Rejected/External/Deferred需用显式关系表达。

## Assumptions

- 当前不新增第37个FR或第14个Package。
- `FR-MEM-003/004`保持Stage4价值门，不提前进入implementation关键路径。
