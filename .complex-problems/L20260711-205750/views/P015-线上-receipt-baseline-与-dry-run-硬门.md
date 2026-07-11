# P015: 线上 Receipt Baseline 与 Dry-run 硬门

Status: done
Parent: P014
Root: P000
Source Ticket: T014 (split)
Source Check: none
Package: problems/P000/children/P003/children/P010/children/P012/children/P014/children/P015
Body: problems/P000/children/P003/children/P010/children/P012/children/P014/children/P015/README.md
Ticket(s): T015

## Problem
在任何 JSONB 更新前，需要获取不含正文的 receipt identity/hash 聚合基线，并证明 dry-run 无失败、kind 合法、报告不泄露隐私。

## Success Criteria
- 保存 count/byKind/identityHash/resultBytes baseline，不输出用户 ID或正文。
- keep-days=0 dry-run status=ok、failedUsers=0、failed=0。
- byKind 仅包含 kb.sync/kb.mutation/kb.governance/archive.delete。
- Dry-run 后 baseline count/hash 不变。
- 候选数和预计 bytes 结果明确，可据此决定 apply。

## Subproblems
- none

## Results
- R010

## Latest Check
C011

## Bodies
- Problem: problems/P000/children/P003/children/P010/children/P012/children/P014/children/P015/README.md
- Ticket T015: problems/P000/children/P003/children/P010/children/P012/children/P014/children/P015/tickets/T015.md
- Result R010: problems/P000/children/P003/children/P010/children/P012/children/P014/children/P015/results/R010.md
- Check C011: problems/P000/children/P003/children/P010/children/P012/children/P014/children/P015/checks/C011.md

## Follow-ups
- none
