# Round 3B3 Job、Outbox、对象存储与 Provider 合同成功检查

## Summary

R023 满足 P030 的文档级目标。Job 状态机、事务 outbox、幂等与对账、对象存储生命周期、10 类 Provider Adapter、业务完成和 Provider 完成边界均已形成可执行合同，并由 15 个验收场景与静态门禁约束；当前代码未实现部分已明确保留给迁移和路线图轮次。

## Evidence

- Product Spec 第 26.0 至 26.10 节。
- Job/Provider static check：15 jobs、10 providers、15 acceptance scenarios。
- Product V4 docs check：36 requirements、21 conflicts、39 decisions、43 review responses、4 lifecycle banners。
- 独立 reviewer 对照当前后端，确认目标合同覆盖 worker/outbox、TimeLetter 原子性、静态腾讯凭据、Provider 删除、APNs 回执和真实对象存储缺口。

## Criteria Map

- Job、attempt、lease、retry、reconcile、dead-letter：26.1 至 26.3。
- Transactional outbox、consumer checkpoint、业务幂等键：26.2、26.3。
- 15 类确定性异步任务：26.4。
- 对象存储上传、隔离、验证、处理和删除生命周期：26.5。
- Provider Port、错误分类、receipt、退避和降级：26.6。
- 10 类 Provider Adapter：26.7。
- 业务完成与 Provider 完成边界：26.8。
- 当前到目标迁移输入和 15 个验收场景：26.9、26.10。

## Execution Map

- 先固定一致的 Job/Outbox 基础设施语义，再枚举产品域 Job 和对象存储状态，最后将外部能力映射为 Provider Adapter 与业务完成边界。
- reviewer 发现的当前高风险实现均映射到目标合同或后续 Round 3C 迁移任务，没有用文档设计掩盖未实现状态。

## Stress Test

- 相同业务命令重复投递只产生一个有效结果，Provider 重试复用稳定 `providerRequestId`。
- worker 崩溃后 lease 可回收并继续执行，未知结果进入 reconcile 而非直接重放。
- 未验证、隔离或删除中的媒体不能进入知识抽取和 Echo 上下文。
- 时间信件应用内投递成功不等于 APNs 送达；APNs 失败不会回滚业务 Inbox。
- 腾讯 session 本地 lease 不代表 Provider session 已释放；删除请求必须保留 Provider receipt。

## Residual Risk

- 目标 worker/outbox/schema 尚未实现，也未在 Postgres 并发环境验证。
- 外部 Provider 的真实 SLA、配额、删除和回执能力仍依赖部署环境与供应商验收。
- Round 3C 必须给出 expand/backfill/shadow/cutover/contract/rollback 的可逆迁移顺序。

## Result IDs

- R023
