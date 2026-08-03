# P014: Round 2B1：角色、领域权威与数据流

Status: done
Parent: P011
Root: P000
Source Ticket: T008 (split)
Source Check: none
Package: problems/P000/children/P002/children/P011/children/P014
Body: problems/P000/children/P002/children/P011/children/P014/README.md
Ticket(s): T009

## Problem
当前多个 iOS/后端模型同时表达 Archive、Memory、Knowledge、Persona 和 runtime，且缺少统一的角色资源权限表。需要先确定概念含义、权威系统及私人域、发布域和运行时域的合法数据流。

## Success Criteria
- 定义 Owner、Visitor、Operator、Admin、未来 Family Contributor 与第三方 Data Subject 的权限/政策边界。
- 核心领域对象均有唯一产品含义、权威系统、可变性和派生关系。
- 私人域、发布域和 runtime 域的允许流向与禁止反向写入规则完整。
- 明确当前 iOS/后端模型中可保留、仅作投影、需迁移和禁止作为权威的部分。
- 权限矩阵覆盖读、写、审核、发布、撤回、导出、删除和 provider 操作并默认拒绝。
- 该问题属于 T008，因为状态机必须以领域权威和角色边界为前提。

## Subproblems
- none

## Results
- R006

## Latest Check
C006

## Bodies
- Problem: problems/P000/children/P002/children/P011/children/P014/README.md
- Ticket T009: problems/P000/children/P002/children/P011/children/P014/tickets/T009.md
- Result R006: problems/P000/children/P002/children/P011/children/P014/results/R006.md
- Check C006: problems/P000/children/P002/children/P011/children/P014/checks/C006.md

## Follow-ups
- none
