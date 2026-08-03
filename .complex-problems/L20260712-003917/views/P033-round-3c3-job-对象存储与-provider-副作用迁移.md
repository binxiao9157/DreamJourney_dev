# P033: Round 3C3 Job、对象存储与 Provider 副作用迁移

Status: done
Parent: P022
Root: P000
Source Ticket: T027 (split)
Source Check: none
Package: problems/P000/children/P003/children/P022/children/P033
Body: problems/P000/children/P003/children/P022/children/P033/README.md
Ticket(s): T034

## Problem
当前长任务、时间信件 dispatch、媒体上传和 Provider 调用仍以同步路由、宿主机 timer、mock storage、本地 lease 或弱 receipt 为主。目标引入 worker/outbox、私有对象存储、Provider Adapter、reconcile/dead-letter。需要迁移这些副作用而不重复投递、训练、合成、推送或删除，也不能把 Provider 未知结果误判成成功。

## Success Criteria
- 定义 worker/outbox/job schema expand、历史任务导入、timer 双跑禁止和 worker cutover 顺序。
- 定义 TimeLetter/Inbox/APNs 从非原子流程迁到事务 outbox 与幂等 consumer 的步骤。
- 定义媒体从 mock/local/base64 到私有对象存储的 intent、verify、quarantine、orphan cleanup 和 delete receipt 迁移。
- 为 10 类 Provider Adapter 定义 credential rotation、请求幂等、callback binding、unknown-result reconcile 和删除补偿。
- 数智人 local lease、声音 profile ready、APNs queued 等状态不得在迁移中冒充 Provider/业务完成。
- 至少覆盖 worker 崩溃、重复 callback、Provider timeout unknown、对象孤儿、重复通知、训练槽位泄漏和删除部分完成等验收场景。
- 定义旧 timer、mock provider、静态 credential 和直接客户端 Provider 访问的退役证据。
- 增加可自动检查的文档门禁。

## Subproblems
- P039: Round 3C3A Job、Outbox 与 Legacy Timer 迁移
- P040: Round 3C3B 对象存储与媒体迁移
- P041: Round 3C3C Provider Effect、Credential 与 Exit 迁移

## Results
- R035

## Latest Check
C036

## Bodies
- Problem: problems/P000/children/P003/children/P022/children/P033/README.md
- Ticket T034: problems/P000/children/P003/children/P022/children/P033/tickets/T034.md
- Result R035: problems/P000/children/P003/children/P022/children/P033/results/R035.md
- Check C036: problems/P000/children/P003/children/P022/children/P033/checks/C036.md

## Follow-ups
- none
