# P011: Round 2B：领域模型、数据权威与权限状态机

Status: done
Parent: P002
Root: P000
Source Ticket: T006 (split)
Source Check: none
Package: problems/P000/children/P002/children/P011
Body: problems/P000/children/P002/children/P011/README.md
Ticket(s): T008

## Problem
Archive、Memory、Knowledge、Persona、Publication、Voice 和 Digital Human 在历史文档与代码中存在概念重叠；敏感性、使用同意、可见性和发布状态也被混在单一字段或 UI 里。需要定义产品级统一词典、权威归属、角色权限和关键生命周期，防止后续继续新增平行 Domain 或发生隐私越权。

## Success Criteria
- 定义 Owner、Visitor、Operator、Admin 和未来 Family Contributor 的最小权限矩阵。
- 定义 Source、Memory Candidate、Canonical Memory/Version、Knowledge Projection、Persona、Conversation、Publication、Visitor Session、Voice Profile、Digital Human Runtime 的唯一含义和数据权威。
- 明确私人域、发布域和运行时域的隔离与允许的数据流。
- 定义 Source、Candidate、Canonical Memory、Publication、Voice Profile 的状态机、禁止转换、删除与撤回传播规则。
- 将 sensitivity、usage consent、visibility、publication state 拆成独立维度并给出 fail-closed 默认值。
- 规定未确认 Candidate、失败分析、草稿/未到期 TimeLetter、未接受 Family 邀请和 runtime 状态不得成为公开事实。
- 该问题属于 T006，因为统一产品定义必须建立在可执行、可授权和可审计的领域边界上。

## Subproblems
- P014: Round 2B1：角色、领域权威与数据流
- P015: Round 2B2：生命周期、四维隐私与变更传播

## Results
- R008

## Latest Check
C008

## Bodies
- Problem: problems/P000/children/P002/children/P011/README.md
- Ticket T008: problems/P000/children/P002/children/P011/tickets/T008.md
- Result R008: problems/P000/children/P002/children/P011/results/R008.md
- Check C008: problems/P000/children/P002/children/P011/checks/C008.md

## Follow-ups
- none
