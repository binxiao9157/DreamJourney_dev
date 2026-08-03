# Round 3C3 Job、对象存储与 Provider 副作用迁移

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
