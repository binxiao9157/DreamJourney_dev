# Round 3B3 Job、Outbox、对象存储与 provider 合同方案

## Problem Definition

当前 TimeLetter、Echo、Voice 和 provider 调用缺统一事务、lease、重试与对账；媒体上传仍是 mock，部分 provider 静态 credential 下发客户端。需要定义足以恢复 worker crash、网络未知结果、重复回调和删除传播的最小异步合同，同时避免建设通用工作流平台。

## Proposed Solution

1. 定义 outbox_events、jobs、job_attempts、consumer_receipts/provider_receipts 的字段、状态机和事务边界。
2. 使用 Postgres `FOR UPDATE SKIP LOCKED`、lease/heartbeat/runAfter、stable dedupe/providerRequestId、backoff/dead-letter/reconciliation。
3. 定义私有对象存储 upload intent → upload → checksum/scan → commit → processing → delete receipt 生命周期。
4. 定义通用 provider port 和 error/capability/retention/delete/cost contract，再细化 OCR/ASR/LLM/Vision/TTS/Voice/DH/APNs。
5. 明确 TimeLetter、Echo delayed、DataRights、Voice/DH 的业务状态与 provider delivery 状态，不静默 fallback。
6. 所有 worker 使用 scoped WorkAuthorization；DataRights 额外使用 DataRightsAuthorization；secret/正文不进入 receipt/log。

## Acceptance Criteria

- Job/outbox 字段和状态机覆盖 claim、lease、heartbeat、retry、cancel、dead-letter、reconcile、receipt。
- 至少 8 类 job 有 owner module、输入、completion 和 fallback。
- 对象存储覆盖 signed URL、checksum、scan/quarantine、download、delete/orphan lifecycle。
- 至少 8 类 provider port 有输入/输出/capability/error/retention/delete/fallback。
- 时间信件/推送、Voice/DH、DataRights 的完成语义不混淆。
- 至少 10 个 crash/duplicate/timeout/security 验收场景。

## Verification Plan

1. 走查业务事务提交后 worker crash、provider 成功后 DB crash、lease expiry、duplicate callback。
2. 走查 upload 伪造 size/mime/checksum、malware、orphan、delete retry。
3. 走查 Voice sample、TTS、DH、APNs 无长期 secret 和错误 fallback。
4. 静态检查 job/provider/object/验收数量和必要安全字段。

## Risks

- 把 job engine 做成通用 DAG/Agent，超出当前确定性任务。
- provider 不支持幂等查询时错误重发造成重复成本或数据。
- receipt 复制 provider body/用户正文形成新的敏感数据面。

## Assumptions

- 近期使用 Postgres job/outbox，不引入 Redis/Kafka/Celery。
- 具体对象存储/provider 供应商由后续 ADR/合同选择，port 不预设商业厂商。
