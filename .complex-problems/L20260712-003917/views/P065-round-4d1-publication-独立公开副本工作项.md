# P065: Round 4D1：Publication 独立公开副本工作项

Status: done
Parent: P054
Root: P000
Source Ticket: T062 (split)
Source Check: none
Package: problems/P000/children/P004/children/P054/children/P065
Body: problems/P000/children/P004/children/P054/children/P065/README.md
Ticket(s): T063

## Problem
当前家庭、时间信件、分享或未来Visitor需求不能直接复用Owner私人Projection和owner API。需要把Publication定义为Owner显式动作产生的独立versioned snapshot、Public Index和grant生命周期，并保持默认关闭。

## Success Criteria
- 为`WP-S3-01`建立原子工作项，覆盖产品/隐私门、snapshot/version、grant/Visitor、Public Index、citation、withdraw/revoke/delete和运营证据。
- 私人Source/Memory/Projection不因query filter、`isPrivate`或family关系直接公开；公共读取不命中private store/index。
- 发布、更新、撤回与删除使用独立command/receipt/outbox和cohort；已访问事实不被普通rollback抹除。
- 明确current implementation、default-off、G0–G4与Owner text core独立性。

## Subproblems
- none

## Results
- R060

## Latest Check
C062

## Bodies
- Problem: problems/P000/children/P004/children/P054/children/P065/README.md
- Ticket T063: problems/P000/children/P004/children/P054/children/P065/tickets/T063.md
- Result R060: problems/P000/children/P004/children/P054/children/P065/results/R060.md
- Check C062: problems/P000/children/P004/children/P054/children/P065/checks/C062.md

## Follow-ups
- none
