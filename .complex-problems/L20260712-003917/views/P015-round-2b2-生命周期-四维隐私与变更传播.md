# P015: Round 2B2：生命周期、四维隐私与变更传播

Status: done
Parent: P011
Root: P000
Source Ticket: T008 (split)
Source Check: none
Package: problems/P000/children/P002/children/P011/children/P015
Body: problems/P000/children/P002/children/P011/children/P015/README.md
Ticket(s): T010

## Problem
现有状态字段混合了业务生命周期、分析结果、上传状态、授权、可见性和 provider 状态，删除/纠正/撤回也没有统一传播语义。需要为关键对象建立可执行状态机和正交隐私维度。

## Success Criteria
- Source、Candidate、Confirmed Memory Record/Version、Publication、Voice Profile 各有状态、允许转换、禁止转换、幂等和并发要求。
- sensitivity、usage consent、visibility、publication state 四维定义、默认值和授权下降规则清晰。
- 未确认、失败、草稿、未到期、邀请未接受和 runtime 状态不能成为已确认或公开事实。
- Source 删除、记录纠正、Publication 撤回、声音授权撤回和第三方异议的传播范围与 SLA 类型明确。
- 删除边界区分在线数据、对象、索引、缓存、会话引用、日志、备份与供应商资产，不承诺不可证明的立即彻底删除。
- 该问题属于 T008，因为它负责把统一领域模型变成可验证的生命周期与安全策略。

## Subproblems
- none

## Results
- R007

## Latest Check
C007

## Bodies
- Problem: problems/P000/children/P002/children/P011/children/P015/README.md
- Ticket T010: problems/P000/children/P002/children/P011/children/P015/tickets/T010.md
- Result R007: problems/P000/children/P002/children/P011/children/P015/results/R007.md
- Check C007: problems/P000/children/P002/children/P011/children/P015/checks/C007.md

## Follow-ups
- none
