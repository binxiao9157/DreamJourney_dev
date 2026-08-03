# 完成 22 项独立发现 Disposition 与目标修正

## Problem Definition

三份报告的 22 项发现高度重叠但视角不同。需要建立 canonical risk，把每个原始ID映射到真实目标/实现/外部门，不因重复而丢失证据，也不把文档已有规则误说成刚修复代码。

## Proposed Solution

1. 定义 CR-01..CR-n canonical risks，聚合 account isolation、identity/AuthZ、DB/migration、domain authority、async effect、object/provider/credential、rights/delete、publication/third-party、metrics/cost和complexity。
2. 建立 22 行 disposition 矩阵，字段固定为 ID/severity/disposition/canonicalRisk/reason/evidence/specOrDR/roadmapPackage/ownerGate。
3. 只在目标规范确有缺口时修改 Product Spec；已有明确规则则标 `ACCEPTED_IMPLEMENTATION_GAP`，进入稳定 `WP-S0-xx/WP-S1-xx` 路线包。
4. 将过度设计建议落实为阶段约束：Stage 0/1只做安全地基与Owner文字核心，Visitor/公开Voice/DH/复杂Family等延后。
5. 更新 Evidence Matrix Round 3D状态和 Product Spec文档控制状态；Decision Register沿用既有DR，除非出现无法表达的新产品决定。

## Acceptance Criteria

- 22项精确全集和完整字段。
- 至少10个canonical risks，重复来源均可追踪。
- 所有disposition属于允许集合且无开放状态。
- 每个实现缺口映射到稳定Roadmap Package ID，每个外部门映射DR/owner。
- Product Spec/Evidence/Decision修正与响应一致，不引入生产已完成声明。
- 明确哪些建议接受、部分接受、重复或有证据反驳。

## Verification Plan

人工逐项对照三份报告；统计ID/严重度/disposition/canonical risk/work package；检查每个BLOCKER/HIGH有落点；由P050编写独立checker。

## Risks

- Canonical risk过少会掩盖差异，过多会复制路线任务；以独立Authority/部署边界划分。
- 预先使用Roadmap ID必须在Round4解析，不得成为永久占位。
- 评审严重度不等于最终发布优先级，disposition需说明原因。

## Assumptions

- 本票不修改生产代码。
- Round4必须保留本票定义的Package ID或提供可追踪重命名。
- 外部/法律/产品决定保持未关闭。
