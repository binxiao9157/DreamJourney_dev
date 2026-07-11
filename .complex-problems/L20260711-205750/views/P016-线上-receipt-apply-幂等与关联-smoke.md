# P016: 线上 Receipt Apply、幂等与关联 Smoke

Status: done
Parent: P014
Root: P000
Source Ticket: T014 (split)
Source Check: none
Package: problems/P000/children/P003/children/P010/children/P012/children/P014/children/P016
Body: problems/P000/children/P003/children/P010/children/P012/children/P014/children/P016/README.md
Ticket(s): T016

## Problem
Dry-run 通过后，需要小批最小化历史 result，证明 identity/hash 不变、二次运行幂等，并复验在线知识与其他维护合同。

## Success Criteria
- Apply status=ok、failed=0，updated 与 dry-run candidate 一致。
- 前后 count/byKind/identityHash 完全一致，result bytes 不增加。
- Second dry-run candidate=0，second apply updated=0。
- Deployed knowledge smoke、privacy maintenance dry-run和change-feed compaction dry-run通过。
- 脱敏报告保存，状态文档更新。

## Subproblems
- none

## Results
- R011

## Latest Check
C012

## Bodies
- Problem: problems/P000/children/P003/children/P010/children/P012/children/P014/children/P016/README.md
- Ticket T016: problems/P000/children/P003/children/P010/children/P012/children/P014/children/P016/tickets/T016.md
- Result R011: problems/P000/children/P003/children/P010/children/P012/children/P014/children/P016/results/R011.md
- Check C012: problems/P000/children/P003/children/P010/children/P012/children/P014/children/P016/checks/C012.md

## Follow-ups
- none
