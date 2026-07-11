# 消除家庭刷新与治理失效的并发排序窗口

## Problem

同账号并发家庭 refresh 没有比较每次 refresh generation，旧响应可覆盖新结果；persona/family invalidation 异步排入 coordinator，已排队旧治理 callback 可能在失效块之前修改 graph/base/outbox。

## Success Criteria

- FamilyRepository 每次 refresh 捕获 freshness generation，回调只接受账号 generation、owner 和 refresh generation 全部匹配的最新响应。
- persona/context 与 family refresh invalidation 在 API 返回前已轮换 coordinator generation，旧 callback 即使已入队也不能通过写入 guard。
- 不在主线程与 coordinator queue 之间形成 sync 死锁。
- 模型/静态 smoke 覆盖 refresh A/B 乱序、旧成功、旧失败、callback-before-invalidate 和账号切换。
- Task 22 专项 gates、release QA、`git diff --check`、Simulator/generic iPhoneOS build 与最终 release regression 通过。
