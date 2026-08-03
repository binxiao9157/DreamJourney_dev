# Round 3B3 Job、Outbox、对象存储与 Provider 合同结果

## Summary

已形成适用于当前模块化单体目标架构的异步执行与外部 Provider 合同。方案以 Postgres 事务 outbox、可重试 Job、稳定业务幂等键和 Provider receipt 为核心，明确区分业务完成、外部调用完成与通知送达，避免把当前同步路由、宿主机定时脚本或 Provider 成功响应误判为产品闭环完成。

## Done

- 定义 `outbox_events`、`jobs`、`job_attempts`、consumer checkpoint、provider receipt 和 dead-letter 逻辑对象。
- 定义 `queued / claimed / running / retry_wait / reconciling / succeeded / failed / cancelled` Job 状态机及租约、重试、对账规则。
- 固定 at-least-once 交付语义，使用业务幂等键和稳定 `providerRequestId` 达成可验证幂等，不宣称 exactly-once。
- 定义 15 类确定性 Job，覆盖媒体处理、知识抽取、时间信件、通知、数据权利、声音复刻和数智人清理。
- 定义对象存储 `intent / uploaded / quarantined / verified / processing / deletion` 生命周期，禁止未验证对象直接进入知识库。
- 定义统一 Provider Port、错误分类、退避、熔断、超时、对账和敏感字段脱敏要求。
- 编制对象存储、恶意文件扫描、OCR、ASR、LLM、视觉分析、TTS、声音复刻、腾讯数智人和 APNs 共 10 类 Provider Adapter 合同。
- 明确时间信件应用内投递与 APNs、数智人本地 lease 与腾讯 session、音色 ready 与质量验收、删除请求与 Provider 删除回执之间的边界。
- 增加 15 个异步/Provider 验收场景和 `product-v4-jobs-provider-check.py`。
- 独立复审确认目标合同无 blocker；当前实现的 worker/outbox、原子投递、静态腾讯凭据、Provider 删除和真实对象存储缺口已纳入迁移输入。

## Verification

- Job/Provider check 通过：15 jobs、10 providers、15 acceptance scenarios。
- Product V4 docs check 通过：36 requirements、21 conflicts、39 decisions、43 review responses、4 lifecycle banners。
- `git diff --check` 在写入结果前通过；ledger 同步产生的末尾空行已清理。
- 本轮为目标合同设计与静态证据验证，未部署后端、未调用真实 Provider、未执行 Postgres 并发测试。

## Known Gaps

- 当前后端尚未实现独立 worker、事务 outbox、Job lease/reconcile 和 dead-letter 管理端点。
- 当前媒体仍以 mock object storage 为主，真实私有对象存储、恶意文件扫描和删除回执尚未生产验收。
- 时间信件 dispatch、Inbox 写入和通知 outbox 仍需在迁移轮次定义原子切换与回滚方式。
- 腾讯数智人、火山语音和 APNs 的 Provider 配额、延迟、回执与删除能力仍需外部环境验收。
- Round 3C 需要把目标合同拆成可逆 schema migration、shadow/backfill/cutover 和 rollback 步骤。

## Artifacts

- `docs/product/DreamJourney_V4_产品定义与目标架构_Product_Spec_V4.0.md`
- `docs/product/DreamJourney_V4_当前实现证据矩阵_V1.0.md`
- `Scripts/QA/product-v4/product-v4-jobs-provider-check.py`
- `docs/plans/task_27_round_3b3-jobs-provider-contracts.md`
- `docs/plans/task_27_round_3b3_solution.md`
- `docs/plans/task_27_round_3b3_result.md`
