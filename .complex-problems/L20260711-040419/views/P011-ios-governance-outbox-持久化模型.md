# P011: iOS Governance Outbox 持久化模型

Status: done
Parent: P010
Root: P000
Source Ticket: T009 (split)
Source Check: none
Package: problems/P000/children/P003/children/P010/children/P011
Body: problems/P000/children/P003/children/P010/children/P011/README.md
Ticket(s): T010

## Problem
治理动作需要独立于单槽 graph pending mutation 的多项、按用户、可重启恢复存储。

## Success Criteria
- Codable item 包含 operation/user/expected identity/action/createdAt。
- Store 原子写入、有序读取、operation 去重、删除、按 user 隔离。
- 损坏文件不被误用，提供明确错误/清理策略。
- 临时目录 model smoke 覆盖 round-trip、隔离、去重、删除和损坏。

## Subproblems
- none

## Results
- R007

## Latest Check
C007

## Bodies
- Problem: problems/P000/children/P003/children/P010/children/P011/README.md
- Ticket T010: problems/P000/children/P003/children/P010/children/P011/tickets/T010.md
- Result R007: problems/P000/children/P003/children/P010/children/P011/results/R007.md
- Check C007: problems/P000/children/P003/children/P010/children/P011/checks/C007.md

## Follow-ups
- none
