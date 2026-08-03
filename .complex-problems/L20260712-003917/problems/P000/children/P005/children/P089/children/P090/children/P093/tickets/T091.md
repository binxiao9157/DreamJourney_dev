# 用双状态模型处置23条发现并生成验收清单

## Problem Definition

审查发现包含当前实现风险、路线未实施、产品未决和外部门，不能用单一closed状态。需要让文档处置可闭环，同时保持底层阻断真实开放。

## Proposed Solution

新增第五成果物，逐条登记23个ID的cluster/severity/disposition/documentStatus/underlyingStatus/authority/gate/verification；建立五类P0 release stop、13 Package验收摘要、G0-G4证据、不可逆动作与未授权事项。将`ACCEPTED`定义为“意见已进入Authority/Gate”，不等于实现完成；只有V1范围Authority冲突可标`FIXED`。

## Acceptance Criteria

- 23个ID完整唯一，P0=7/P1=15/P2=1。
- 7个P0的documentStatus均闭环，underlyingStatus全部保持开放/阻断。
- P1/P2均有Owner/Gate/下一证据，无静默忽略。
- 第五成果物标记Round5B完成、Round5C待审，并互链四份Authority。
- 现有所有Product V4检查与diff gate通过。

## Verification Plan

用rg/脚本比较三份报告与disposition表ID、severity；检查禁止状态；运行全部现有checker和diff。

## Risks

避免把多视角重叠行删除；每个raw ID必须保留。避免在验收清单复制115项正文。

## Assumptions

本轮不修改生产代码，不关闭G2-G4。
