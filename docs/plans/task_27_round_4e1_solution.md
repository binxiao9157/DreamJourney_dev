# 建立双向追踪 Authority，并补齐追踪暴露的真实路线缺口

## Problem Definition

当前FR/DR/finding/CR分别在不同文档，Work Item虽有Risk字段但没有统一反向索引。初步审计已发现FR-SAFE-001、FR-SRC-001/002和FR-ACC-002没有单结果Work Item，不能用宽泛package映射掩盖。需要先补真实缺口，再建立机器可验证追踪。

## Proposed Solution

1. 新增`DreamJourney_V4_路线追踪矩阵_V1.0.md`，定义authority/status语义和六张表：36 FR、41 DR、22 finding、12 CR、13 package、Work Item reverse coverage。
2. 每个FR/DR/finding/CR指定primary package、Work Item或明确`DEFERRED_BY_GATE`、适用G0–G4、current maturity/evidence和唯一next action。
3. 对追踪暴露的真实缺口新增最小Work Item：Stage0危机/AI披露安全门、Stage2 SourceObject摄入、Stage2 processor、Stage1 Owner Persona Authority；更新相关计数/checker。
4. Stage4 semantic conflict/entity graph保留`DEFERRED_BY_GATE`，必须列产品价值/指标/决策门，不伪造当前工作项或实现。
5. 新增`product-v4-traceability-check.py`，精确验证集合、顺序、双向覆盖、无孤儿Work Item、状态和external gate不被路线关闭。

## Acceptance Criteria

- 36/41/22/12/13集合精确且无重复/缺失。
- 每个已计划FR有具体WI；明确后置FR使用`DEFERRED_BY_GATE`并有gate/next action，不被计实现完成。
- 每个WI的Risk字段至少引用FR/DR/finding/CR之一，或显式标`ARCH/MIG/OPS NECESSITY`并在矩阵有理由。
- `CONFIRMED/REJECTED`与`RECOMMENDED_PENDING/EXTERNAL_REQUIRED`状态保持权威来源一致。
- checker与全量Product V4检查通过。

## Verification Plan

- 从Evidence Matrix/Decision Register/Review Response/roadmap提取权威ID集合并双向比较。
- 对新增缺口工作项执行16字段检查，并更新Stage0/1计数和专用checker。
- 人工抽样P0、Optional、Deferred、external-required各类映射，随后运行trace checker和diff gate。

## Risks

- 追踪矩阵过度复制正文会漂移；只复制ID、状态、primary owner/gate/next action，详细定义链接回权威文档。
- 为了“覆盖”无限新增任务会扩大范围；只补已明确FR且当前阶段承诺的缺口，Stage4保留门。

## Assumptions

- Supporting traceability文档可作为五份最终成果物的索引附件，最终authority顺序仍由Product Spec/Decision/Evidence/Roadmap定义。
