# Round 3C1A Legacy 数据目录与确定性 Backfill 成功检查

## Summary

R025 满足 P035 的文档级目标。所有当前后端表、关键 iOS 本地状态和 V4 目标对象均有确定迁移分类、ID/owner/evidence/checkpoint/checksum/quarantine/verify 合同；不存在把 current projection、客户端声明或 Provider 状态静默升级为 V4 Authority 的缺口。

## Evidence

- Product Spec 第 27.0 至 27.9 节。
- 18 个 backend catalog row、12 个 iOS local row、38 个 target coverage row。
- 18 个 backfill 故障场景和 UNKNOWN inventory。
- 独立后端代码审查覆盖 DDL、owner、history compaction、ID/time、transaction 和 Source reference 风险。
- `product-v4-data-backfill-check.py` 与全部相关 V4 门禁通过。

## Criteria Map

- Legacy/target catalog：27.3、27.4、27.5。
- Deterministic ID、owner/vault、identity claim：27.2。
- Checkpoint/checksum/replay/tail/quarantine：27.1、27.6。
- 不伪造 confirmed/history/provider completion：27.0、27.3、27.5、27.6。
- Data rights/local cleanup：27.7。
- 故障与未知生产输入：27.8、27.9。

## Execution Map

- 先以当前代码证据建立 18 表和 iOS store inventory，再将每个 legacy locator 映射到 Round 3B 对象，最后定义 runner 与故障门。
- reviewer 发现的历史不可恢复、owner 转移、两代 user ID 和时间失真均改变了迁移合同，而非只记录为备注。

## Stress Test

- batch 在 commit/checkpoint 不同位置崩溃仍可幂等重跑。
- 同 ID 跨 owner、payload owner 错配和两代 user alias 均 quarantine，不转移数据。
- 无 Source/DecisionReceipt 的 legacy confirmed 只能成为 Candidate/quarantine。
- compaction gap 只标 current state + retained revisions，不合成版本。
- 未 claim identity、Provider unknown 和 object missing 均保持不可见/不可用。

## Residual Risk

- 文档合同尚无 production runner、真实 DDL、线上 inventory 或恢复演练证据。
- 数据 authority cutover 和 schema contract 不属于 P035，由 P036/后续 3C 子问题负责。

## Result IDs

- R025
