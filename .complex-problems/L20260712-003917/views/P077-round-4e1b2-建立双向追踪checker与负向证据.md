# P077: Round 4E1B2：建立双向追踪Checker与负向证据

Status: done
Parent: P072
Root: P000
Source Ticket: T073 (split)
Source Check: none
Package: problems/P000/children/P004/children/P055/children/P069/children/P072/children/P077
Body: problems/P000/children/P004/children/P055/children/P069/children/P072/children/P077/README.md
Ticket(s): T075

## Problem
生成一份看似完整的矩阵仍可能包含孤儿、错误反向边、状态越权或finding/package下钻缺失。需要独立checker从权威文档和roadmap重新计算集合与关系，不能只相信生成器输出。

## Success Criteria
- 新增`product-v4-traceability-check.py`，独立解析矩阵和权威源。
- 验证36/41/22/12/13/115集合、WI父子、FR双向边、DR关系/状态、finding→CR→package→WI和gate/status上限。
- 验证open/failed/expired G2–G4不得升级为VERIFIED，当前无PROD_VERIFIED FR。
- 内置负向self-test至少覆盖孤儿WI、缺反向边、非法ID、finding下钻缺失、decision状态漂移和状态越权。
- 全部Product V4检查与`git diff --check`通过，并有独立agent复审结论。

## Subproblems
- P078: 修复 Gate 语义解析并重新生成可验证追踪矩阵

## Results
- R070

## Latest Check
C075

## Bodies
- Problem: problems/P000/children/P004/children/P055/children/P069/children/P072/children/P077/README.md
- Ticket T075: problems/P000/children/P004/children/P055/children/P069/children/P072/children/P077/tickets/T075.md
- Result R070: problems/P000/children/P004/children/P055/children/P069/children/P072/children/P077/results/R070.md
- Check C073: problems/P000/children/P004/children/P055/children/P069/children/P072/children/P077/checks/C073.md
- Check C075: problems/P000/children/P004/children/P055/children/P069/children/P072/children/P077/checks/C075.md

## Follow-ups
- P078: 修复 Gate 语义解析并重新生成可验证追踪矩阵
