# P071: Round 4E1A：补齐 Safety、Persona 与 Media 路线缺口

Status: done
Parent: P069
Root: P000
Source Ticket: T068 (split)
Source Check: none
Package: problems/P000/children/P004/children/P055/children/P069/children/P071
Body: problems/P000/children/P004/children/P055/children/P069/children/P071/README.md
Ticket(s): T069

## Problem
FR追踪发现`FR-SAFE-001`没有结构化危机/AI披露工作项，`FR-ACC-002`被宽泛挂在CreateSource却没有Persona Authority，`FR-SRC-001/002`虽声明Stage2后置却没有SourceObject摄入和processor原子项。直接做矩阵会产生虚假覆盖。

## Success Criteria
- 新增`WI-S0-06-09` AI披露/危机安全策略与同步响应门。
- 新增`WI-S1-01-11` Owner Persona Authority，和Voice/DH runtime/persona display分离。
- 新增`WI-S1-01-12` SourceObject真实摄入/对象引用合同，mock/local-only不冒充uploaded。
- 新增`WI-S1-02-11` media processor job/result/retry/delete传播，模型结果只生成Candidate。
- 每项16字段完整，更新Stage0/1计数、批次、checker和状态，不改变Owner text最小核心或Optional门。

## Subproblems
- P073: Round 4E1A1：补齐危机响应与 AI 披露路线
- P074: Round 4E1A2：补齐 Persona 与真实媒体 Authority 路线
- P075: Round 4E1A3：收敛 canonical 引用、计数与跨包追踪边

## Results
- R068

## Latest Check
C071

## Bodies
- Problem: problems/P000/children/P004/children/P055/children/P069/children/P071/README.md
- Ticket T069: problems/P000/children/P004/children/P055/children/P069/children/P071/tickets/T069.md
- Result R068: problems/P000/children/P004/children/P055/children/P069/children/P071/results/R068.md
- Check C071: problems/P000/children/P004/children/P055/children/P069/children/P071/checks/C071.md

## Follow-ups
- none
