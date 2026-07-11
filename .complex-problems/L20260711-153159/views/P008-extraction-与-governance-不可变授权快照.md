# P008: Extraction 与 Governance 不可变授权快照

Status: done
Parent: P006
Root: P000
Source Ticket: T006 (split)
Source Check: none
Package: problems/P000/children/P005/children/P006/children/P008
Body: problems/P000/children/P005/children/P006/children/P008/README.md
Ticket(s): T008

## Problem
知识提取和治理后台回调仍可能重新解析当前 FamilyRepository/context，在账号或角色切换期间产生竞态。

## Success Criteria
- 异步提取开始前捕获 persona identity、用户 generation 与 family authorization generation。
- 完成回调只比较不可变 token，不在后台线程读取 FamilyRepository。
- governance 启动和成功处理使用 queue-owned authorization snapshot 验证 expected identity。
- stale callback 被丢弃且不修改图谱/base/outbox。

## Subproblems
- P010: 对齐既有知识发布门与不可变授权快照合同

## Results
- R006

## Latest Check
C008

## Bodies
- Problem: problems/P000/children/P005/children/P006/children/P008/README.md
- Ticket T008: problems/P000/children/P005/children/P006/children/P008/tickets/T008.md
- Result R006: problems/P000/children/P005/children/P006/children/P008/results/R006.md
- Check C006: problems/P000/children/P005/children/P006/children/P008/checks/C006.md
- Check C008: problems/P000/children/P005/children/P006/children/P008/checks/C008.md

## Follow-ups
- P010: 对齐既有知识发布门与不可变授权快照合同
