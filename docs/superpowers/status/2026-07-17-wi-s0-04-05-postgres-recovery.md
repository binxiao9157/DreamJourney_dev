# WI-S0-04-05 Postgres 隔离恢复与 Replay Gate 证据

日期：2026-07-17

## 结论

`WI-S0-04-05` 的恢复工具、运行时流量围栏、iOS 恢复策略消费和真实 Postgres 隔离恢复均已实现并部署。真实 G2 演练产生 `cutoverDecision=NO_GO`，因此只关闭“工具与真实演练已执行”边界，不签发恢复切流 GO，也不宣称 Work Item 完成。

当前 NO_GO 原因：

1. 最新备份恢复后发现 361 条历史 owner orphan；
2. cutoff 后全库 command/outbox/deletion/provider replay bundle 尚不存在；
3. G3 设备与发布态恢复行为证据尚未提供。

## 实现与版本

- Backend：恢复基线 `main@e1922f2`；后续恢复审计增强 `main@dc50307` 已推送、部署并通过 `/ready`、migration verify 和隔离 Postgres smoke；
- iOS：`feature/prd-stitch-ui-adaptation@dde3081`，本地已提交，未自动推送；
- Backend 恢复入口：`scripts/db/run-recovery-deployed-smoke.sh`；
- Backend 运维说明：`docs/backend/2026-07-17-postgres-recovery-operations.md`；
- iOS 恢复模式：`normal/readOnly/signedOut/maintenance`，未知或非法状态 fail closed。

### 2026-07-21 审计覆盖增强

`dc50307` 将完整性 evidence 升级为 V3，消除固定 owner 表清单造成的新增表漏审风险：

- 动态发现所有 `public.*.user_id` 表；
- 审计所有 `owner_truth` 表相对 Vault 根的 scope；
- 审计所有 `async_effects` 子表相对 operation 根的 owner/vault/epoch 一致性；
- 将 value-free 的 `async_effects.worker_loss_observations` 显式列为豁免；
- V1/V2 integrity evidence 仅作历史可读，不能促成 GO。

部署后已运行一次性 disposable Postgres smoke：动态 public orphan、Owner Truth 缺失
Vault 和 async scope mismatch 三类 fixture 均被归因并输出 NO_GO；临时
`dj_recovery_audit_*` 数据库已由 smoke 清理。该增强不重新解释 2026-07-17 的历史
361 条 orphan，也不替代真实 backup restore/replay 的 G2 复演。

## G2 真实演练

- backup：`dj-20260716T191655Z-38f0df3c`；
- cutoff LSN：`0/4AC8258`；
- schema head：`0001`；
- 恢复目标：唯一 `dj_recovery_*` 隔离数据库；
- 生产目标硬拒绝：已由合同测试与 smoke 覆盖；
- observed RPO：32760 秒；
- observed RTO：5 秒；
- recovery evidence id：`5c16d3bdf2373f5e26b902a94a9a5e3ac40fe9023c175e4fac2b8fea92e3d8be`；
- integrity digest：`389feef974ede1b4a48b6a5a1a2ff48eaa874c9891142105bb26c0317f1c26ea`；
- replay digest：`1d429de7349dac72bc8cefb542c3ba8295400b00d3fb69cc292a9c1134745421`。

完整性结果：

| 检查 | 结果 |
| --- | --- |
| schema/migration head | 通过 |
| invalid payload hash | 0 |
| purged owner resurrection | 0 |
| owner orphan | 361，失败 |
| replay authority | `replayBundleMissing`，失败 |

owner orphan 分布：`archive_items=115`、`care_snapshots=54`、`digital_human_sessions=62`、`echo_delayed_replies=8`、`family_members=45`、`kb_snapshots=13`、`mailbox_letters=27`、`profiles=11`、`push_device_tokens=6`、`voice_profiles=20`。

### 2026-07-30 当前 schema 复演

在当前线上 schema head `0065` 下重新生成并校验了加密备份，随后恢复到新的
`dj_recovery_*` 隔离库。migration verify 的 `expectedHead=appliedHead=0065`，
manifest、restore、integrity、replay 和 recovery record 均已生成；生产库、生产流量和
recovery mode 没有变更。

本次恢复记录仍为 `cutoverDecision=NO_GO`：

- 当前快照发现 `367` 条 legacy direct-user owner orphan。该数量是新的恢复时间点观测，
  不能与 2026-07-17 的历史快照混作“数据修复已发生”或“回归”；
- integrity audit 继续明确 `ownerTruthIdentityRootUnverified` 和
  `asyncEffectsRootAuthorityUnverified`；
- replay 继续是 `replayBundleMissing`，没有可信 cutoff 后 replay producer/evidence。

同一隔离库已经运行只读 orphan quarantine inventory：覆盖 21 个带 `user_id` 的 public
表、无 unlocatable table、状态为 `quarantineRequired`。生成内容只有 HMAC 定位摘要和表级
计数，并固定 `automaticMutation=false`、`automaticOwnerClaim=false`、
`automaticDelete=false`；没有重绑 owner、删除记录、切换流量或输出原始标识。

因此本次只新增“当前 schema 的真实隔离恢复和可审计 NO_GO”证据，不关闭 replay、身份根、
authority root 或 G3/G4 缺口。后端部署证据见
`DreamJourneyBackend/docs/backend/2026-07-30-postgres-recovery-drill-no-go.md`。

## 安全边界

- 演练没有修改生产 DSN、生产数据库或负载均衡；
- 生产 `/config/runtime` 保持 `recovery.mode=normal`；
- 恢复数据库未对生产流量开放；
- 历史 `.env.backup*` 未删除或纳入提交；
- 恢复记录不包含数据库口令、Provider 凭据、用户正文或直接标识。

## Gate 状态

- G0：恢复合同、生产目标拒绝、V3 分域审计、证据绑定和 fail-closed smoke 通过；
- G2：真实隔离恢复已执行，结论 `NO_GO`；
- G3：缺失；
- Registry：继续保持保守 `PLANNED/STOP`，不自行晋升。

## 后续处置

1. `WI-S0-06-09` 先完成即时安全止损；
2. `WI-S0-02-*` 与 `WI-S0-01-*` 建立强身份、owner truth 和本地隔离后，制定历史 orphan reconciliation/quarantine；
3. Stage 1 async authority 建立 command/outbox/deletion/provider receipt 后生成可信 replay bundle；
4. 两类 blocker 清零后重新运行 G2，只有完整性与 replay 同时通过才可讨论切流 GO。
