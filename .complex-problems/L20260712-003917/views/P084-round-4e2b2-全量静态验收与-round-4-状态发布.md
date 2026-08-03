# P084: Round 4E2B2：全量静态验收与 Round 4 状态发布

Status: done
Parent: P080
Root: P000
Source Ticket: T081 (split)
Source Check: none
Package: problems/P000/children/P004/children/P055/children/P070/children/P080/children/P084
Body: problems/P000/children/P004/children/P055/children/P070/children/P080/children/P084/README.md
Ticket(s): T083

## Problem
总checker完成后，需要在独立步骤运行生成确定性、全部Product V4 checks和diff gate；只有全部通过才能把Header/Selector baseline从E2B pending更新为Round4静态验收通过、Round5待审。

## Success Criteria
- Registry和Trace Matrix连续生成hash一致且各自`--check`/独立checker通过。
- 全部`Scripts/QA/product-v4`非生成脚本与`git diff --check`通过。
- Header、Round4E表和selector baseline更新为`ROUND4_STATIC_ACCEPTANCE_PASSED_ROUND5_PENDING`，仍明确不代表工程实现/发布。
- 状态更新后重新生成registry并再次运行总checker和全量回归，避免发布状态导致source stale。
- 记录最终hash、检查数量和Round5剩余边界。

## Subproblems
- none

## Results
- R078

## Latest Check
C082

## Bodies
- Problem: problems/P000/children/P004/children/P055/children/P070/children/P080/children/P084/README.md
- Ticket T083: problems/P000/children/P004/children/P055/children/P070/children/P080/children/P084/tickets/T083.md
- Result R078: problems/P000/children/P004/children/P055/children/P070/children/P080/children/P084/results/R078.md
- Check C082: problems/P000/children/P004/children/P055/children/P070/children/P080/children/P084/checks/C082.md

## Follow-ups
- none
