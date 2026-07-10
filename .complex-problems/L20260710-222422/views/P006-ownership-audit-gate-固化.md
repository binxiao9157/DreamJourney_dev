# P006: Ownership Audit Gate 固化

Status: done
Parent: P003
Root: P000
Source Ticket: T005 (split)
Source Check: none
Package: problems/P000/children/P003/children/P006
Body: problems/P000/children/P003/children/P006/README.md
Ticket(s): T006

## Problem
缺少跨后端注册表、principal-bound 中间件、iOS system 调度边界和部署 HTTP 行为的一键检查。

## Success Criteria
- 新增静态 audit check，校验 54 路由、0 未分类、principal-bound block 和 iOS 无生产 dispatch。
- 新增 deployed route ownership HTTP smoke，报告不含 token、手机号或原始 user id。
- release regression 提供可选开关运行 deployed smoke，默认不影响公开 MVP gate。
- 相关后端测试、Swift QA 和 iOS generic build 通过。

## Subproblems
- none

## Results
- R004

## Latest Check
C004

## Bodies
- Problem: problems/P000/children/P003/children/P006/README.md
- Ticket T006: problems/P000/children/P003/children/P006/tickets/T006.md
- Result R004: problems/P000/children/P003/children/P006/results/R004.md
- Check C004: problems/P000/children/P003/children/P006/checks/C004.md

## Follow-ups
- none
