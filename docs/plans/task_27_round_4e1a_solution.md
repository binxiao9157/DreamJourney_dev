# 先修路线语义缺口与非规范引用，再生成追踪矩阵

## Problem Definition

追踪审计发现四类问题：Safety/Persona/Media缺单结果任务；5个FR未被精确引用；roadmap混入非canonical FR和范围表达；Voice误用拒绝AOS的DR-012，Finding边也有缺口。必须先修路线本体。

## Proposed Solution

1. 新增四个16字段Work Item：S0-06-09危机/AI披露、S1-01-11 Persona Authority、S1-01-12 SourceObject摄入、S1-02-11 media processor。
2. 更新计数：Stage0 50；Stage1 33；总Work Item 115；相关section/batch/checker同步。
3. 将`FR-DH/FR-MEDIA/FR-TIME/FR-FAM/FR-CARE`替换为canonical FR或显式`SCOPE-*`非FR标签；禁止范围/通配伪装精确追踪。
4. 从Voice/DH项移除语义错误`DR-012`，改用DR-004/013/014/037等真实决定；补FR-ACC-001、FR-SAFE-002和IAR-06/07、SOR-04精确边，清除非法BAR引用。
5. MEM-003/004不新增当前implementation WI，在后续矩阵标`DEFERRED_BY_GATE`并绑定Stage4价值/重入门。

## Acceptance Criteria

- 四项16字段完整，计数/checker全部同步。
- canonical FR精确集合不再出现额外`FR-*`，scope tag有显式前缀且不计FR。
- DR-012只用于`ENFORCES_REJECTION`的AOS边，不再作为Voice实施风险。
- 缺失FR/finding引用有真实WI或明确deferred gate，不强行映射。
- 全量Product V4 checks与diff gate通过。

## Verification Plan

- 提取roadmap全部精确FR/DR/finding IDs，与canonical集合做差集。
- 检查新增Work Item字段和Stage0/1 checker计数。
- 运行所有Product V4脚本和`git diff --check`。

## Risks

- Scope tag可能被误当正式需求；checker需只接受`SCOPE-*`且trace matrix解释非FR。
- 新增Media任务不能把Provider/真机门塞回Owner文字核心。

## Assumptions

- Stage4 MEM-003/004保持deferred，不因追踪完整性提前扩张产品范围。
