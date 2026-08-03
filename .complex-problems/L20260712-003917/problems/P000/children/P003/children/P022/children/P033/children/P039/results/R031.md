# Round 3C3A Job、Outbox 与 Legacy Timer 迁移结果

## Summary

已形成从同步 route、queue-like JSON、iOS timer 和宿主机 systemd 迁移到事务 Outbox、租约 Worker、幂等 Consumer 和 one-active Scheduler 的可执行合同。旧 `ready/delivered/active/timeout` 状态缺 receipt 时只进入 reconcile/manual review，不会被自动补发、重训或重复删除。

## Done

- Product Spec 新增第 31 节和当前异步部署事实边界。
- 定义 scheduler lease、job family cutover 和 shadow consumer receipt。
- 编制 J01–J15 legacy→target Job 迁移目录。
- 定义 legacy command outbox shadow→active consumer→module completion transaction。
- 固定 TimeLetter/Inbox/APNs 与 Echo Answer/Inbox 原子/分离语义。
- 编制 Q00–Q10 inventory、schema、shadow、lease、job family、scheduler cutover和retirement waves。
- 定义 pre/post cutover pause/failover/reconcile，不恢复旧 direct-effect timer。
- 增加 18 个 crash、双 scheduler、重复、legacy backlog和rollback场景。
- Evidence Matrix新增7.6；新增 `product-v4-job-outbox-migration-check.py`。
- API rollout门禁截到第31节，防止后续ID污染。

## Verification

- Job/Outbox migration check：15 jobs、11 waves、18 scenarios，PASS。
- Round 3B Job/Provider check：15 jobs、10 providers、15 scenarios，PASS。
- API/AuthZ rollout、Evidence Matrix 和Product V4 docs checks通过。
- `git diff --check` 在结果记录前通过。

## Known Gaps

- 未实现/部署 outbox、worker、scheduler lease、shadow consumer或dead-letter。
- 未SSH核对服务器systemd/cron/container，当前scheduler唯一性与backlog未知。
- 未跑真实Postgres crash/claim/lease/duplicate effect smoke。
- Object Storage与Provider effect迁移仍由3C3B/3C3C完成。

## Artifacts

- `docs/product/DreamJourney_V4_产品定义与目标架构_Product_Spec_V4.0.md`
- `docs/product/DreamJourney_V4_当前实现证据矩阵_V1.0.md`
- `Scripts/QA/product-v4/product-v4-job-outbox-migration-check.py`
- `docs/plans/task_27_round_3c3a_solution.md`
- `docs/plans/task_27_round_3c3a_result.md`
