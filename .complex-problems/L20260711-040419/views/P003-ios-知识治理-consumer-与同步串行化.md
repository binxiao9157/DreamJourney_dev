# P003: iOS 知识治理 Consumer 与同步串行化

Status: done
Parent: P000
Root: P000
Source Ticket: T000 (split)
Source Check: none
Package: problems/P000/children/P003
Body: problems/P000/children/P003/README.md
Ticket(s): T007

## Problem
iOS 尚无治理 action/response/metadata 模型，也不能通过现有同步协调器串行提交用户治理动作和应用权威 graph。直接本地改图会绕过服务端状态机，并与普通同步产生竞态。

## Success Criteria
- 定义 confirm/reject/correct/deleteSource action、response summary 和治理 metadata Codable 模型。
- Backend client 构造 schemaVersion=1 请求并解析权威响应。
- KnowledgeSyncCoordinator 串行治理与普通同步，使用 user/persona generation 丢弃旧回调。
- 权威 graph 应用后更新 remote base、清理不再有效的 pending mutation，并触发 KBLite 更新。
- 不新增公开 UI；提供可被后续产品页面调用的稳定 API 和错误状态。

## Subproblems
- P009: iOS 治理 Schema、Metadata 与 Backend Client
- P010: iOS Governance Outbox 与同步协调

## Results
- R010

## Latest Check
C010

## Bodies
- Problem: problems/P000/children/P003/README.md
- Ticket T007: problems/P000/children/P003/tickets/T007.md
- Result R010: problems/P000/children/P003/results/R010.md
- Check C010: problems/P000/children/P003/checks/C010.md

## Follow-ups
- none
