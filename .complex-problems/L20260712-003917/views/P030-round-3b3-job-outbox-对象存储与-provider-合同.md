# P030: Round 3B3：Job、Outbox、对象存储与 provider 合同

Status: done
Parent: P021
Root: P000
Source Ticket: T023 (split)
Source Check: none
Package: problems/P000/children/P003/children/P021/children/P030
Body: problems/P000/children/P003/children/P021/children/P030/README.md
Ticket(s): T026

## Problem
当前 TimeLetter、Echo、Voice 和 provider 调用缺统一事务/重试/对账边界，媒体 upload 仍是 mock，静态 provider credential 可能下发客户端。需要定义可恢复且最小权限的异步和外部能力合同。

## Success Criteria
- Outbox/Job 有 event/job/dedupe/purpose/subject/resource/lease/heartbeat/attempt/backoff/dead-letter/receipt 字段和状态机。
- 业务状态与 outbox 同事务，worker crash/provider timeout/重复回调有可证明恢复路径。
- 对象存储覆盖 signed upload、checksum/scan、commit、download、retention、delete receipt 和 orphan reconciliation。
- OCR/ASR/LLM/Vision/TTS/Voice/DH/APNs provider port 有 capability、request、result、error、quota、cost、retention/delete 和 fallback 合同。
- provider secret 不进入 iOS、receipt 或日志；长期 client secret 供应商能力保持 blocked。
- optional job/provider 关闭时 Owner 文字核心正常。
- 该问题属于 T023，因为它负责所有异步副作用与外部处理边界。

## Subproblems
- none

## Results
- R023

## Latest Check
C023

## Bodies
- Problem: problems/P000/children/P003/children/P021/children/P030/README.md
- Ticket T026: problems/P000/children/P003/children/P021/children/P030/tickets/T026.md
- Result R023: problems/P000/children/P003/children/P021/children/P030/results/R023.md
- Check C023: problems/P000/children/P003/children/P021/children/P030/checks/C023.md

## Follow-ups
- none
