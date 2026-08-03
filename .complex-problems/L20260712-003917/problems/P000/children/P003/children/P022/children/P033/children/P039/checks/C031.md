# Round 3C3A Job、Outbox 与 Legacy Timer 迁移成功检查

## Summary

R031 满足 P039 的文档级目标。15类Job均有legacy producer/bootstrap/cutover/retirement，业务事务、Outbox、Scheduler和Consumer职责分离，旧/new timer不会被允许同时直接产生effect。

## Evidence

- Product Spec 31.0–31.8。
- J01–J15、Q00–Q10、18 scenarios。
- Evidence Matrix 7.6与Job/Outbox migration门禁。

## Criteria Map

- Scheduler ownership：31.1。
- Job catalog/bootstrap：31.2。
- Transactional outbox/business completion：31.3。
- Waves/rollback/retire：31.4–31.5。
- Observability/faults/UNKNOWN：31.6–31.8。

## Execution Map

- 先inventory/UoW/outbox shadow，再scheduler shadow和低风险job，随后业务Inbox/rights/provider family，最后drain/retire legacy timer。

## Stress Test

- transaction crash、event duplicate、scheduler双活、lease过期、TimeLetter重复、legacy delivered缺Inbox、Provider unknown和retirement残留均有明确处理。

## Residual Risk

- 无生产worker/lease/并发/服务器scheduler证据；仅可作为路线图合同。
- Object/Provider迁移仍需P040/P041。

## Result IDs

- R031
