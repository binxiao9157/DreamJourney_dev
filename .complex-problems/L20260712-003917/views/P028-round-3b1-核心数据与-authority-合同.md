# P028: Round 3B1：核心数据与 authority 合同

Status: done
Parent: P021
Root: P000
Source Ticket: T023 (split)
Source Check: none
Package: problems/P000/children/P003/children/P021/children/P028
Body: problems/P000/children/P003/children/P021/children/P028/README.md
Ticket(s): T024

## Problem
V4 领域词典尚未落为可实现的关系模型。需要定义 Subject/Persona/Source/Candidate/MemoryVersion/Conversation/Citation/DataRights 及可选域的数据所有权、ID、状态、证据、版本、时间和约束，避免继续依赖跨域 JSONB。

## Success Criteria
- 核心 aggregate/table 有主键、tenant/owner/persona、version/state、created/updated/deleted 和必要唯一/FK/check 约束。
- Source、Candidate、DecisionReceipt、Memory、MemoryVersion、Correction lineage 形成完整 authority 链。
- Conversation/Answer/Citation 能绑定 active MemoryVersion，不把模型输出当 Source。
- Consent/Grant/Work/Retention/DataRights/Audit 数据对象与业务数据分离。
- Publication/Visitor、Voice/DH、Family/Care/TimeLetter 使用独立可选表，不污染核心必填字段。
- 该问题属于 T023，因为它定义所有 API/Job 的持久化事实边界。

## Subproblems
- none

## Results
- R021

## Latest Check
C021

## Bodies
- Problem: problems/P000/children/P003/children/P021/children/P028/README.md
- Ticket T024: problems/P000/children/P003/children/P021/children/P028/tickets/T024.md
- Result R021: problems/P000/children/P003/children/P021/children/P028/results/R021.md
- Check C021: problems/P000/children/P003/children/P021/children/P028/checks/C021.md

## Follow-ups
- none
