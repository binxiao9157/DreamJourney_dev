# WI-S1-02-09 恢复后 Replay 与 Evidence Manifest 合同

日期：2026-07-20

## 本次 G0 子闭环

本次完成 `WI-S1-02-09` 的第三个 G0 子闭环，并使该 Work Item 的 G0 合同范围闭合：恢复后的 dead-letter replay 需要独立恢复授权，且 readiness 的 evidence manifest 计划不能把未运行或不可信观察标为通过。

后端提交：

```text
main@d6b7b45 feat(v4): fence restored dead letter replay
```

新增 `app/async_effects/recovery_evidence.py`，并扩展 readiness evidence：

1. `DeadLetterRestoreReplayContext` 将 restore checkpoint、owner/vault、authority epoch 与独立恢复授权收据绑定为纯合同坐标。
2. 恢复后 replay 先通过既有 owner-scoped dead-letter 授权，再验证 restore 的 owner/vault/epoch；恢复授权收据不得复用恢复前的 replay 收据。
3. 被授权的恢复 replay 保留原 `stableKey`、使用下一个 attempt，并生成与 dead-letter、restore checkpoint 绑定的确定性 replay ID；该模块不写数据库、不 claim、不开 worker、不调用 Provider。
4. `AsyncEffectReadinessManifestPlan` 将 `ready` 映射为 `passed`、`blocked` 映射为 `blocked`，而 `skipped`、`unknown`、`expired` 一律映射为 `notRun`。
5. manifest plan 只生成 value-free artifact hash；当前没有向通用 append-only evidence sink 写入 manifest，留待 G2 durable wiring。

## 已验证

```bash
PYTHON_BIN=.venv/bin/python scripts/run-backend-async-effect-recovery-evidence-contract-gate.sh
PYTHON_BIN=.venv/bin/python scripts/verify_backend.sh
git diff --check
```

结果：

- recovery/evidence G0 gate `9` 项通过，覆盖恢复后 fresh receipt、owner/vault/epoch fence、stable key/attempt/replay ID、以及 `skipped/unknown/expired -> notRun`、`ready -> passed` 映射。
- 全量后端回归 `820` 项通过；FastAPI、Provider、业务消息、dead-letter、readiness、知识库、备份等既有验证均通过。

## 后端部署证据

后端已推送并部署：

```text
origin/main@d6b7b45
server /opt/services/dreamjourney/DreamJourneyBackend@d6b7b45
```

部署仅重建并重启 `api` 容器，未修改 `.env`、`.env.backup*` 或业务数据。`/ready` 返回 database、schema、auth、incident 均为 `ready`。通过服务器 checkout 的只读 tests volume 重跑 recovery/evidence Gate，结果为 `9` 项通过。

## G0 完成定义核对

| G0 要求 | 状态 | 证据 |
| --- | --- | --- |
| poison payload | 已覆盖 | `payloadCorrectionRequired`，禁止盲重放。 |
| max attempts | 已覆盖 | terminal admission 与 owner-scoped replay。 |
| unauthorized replay | 已覆盖 | owner/vault/epoch/dead-letter state 全部 fail-closed。 |
| same stable key | 已覆盖 | replay/restore replay 都保留原 stable key。 |
| restore 后 replay | 已覆盖 | 需要 restore checkpoint 和独立恢复授权。 |
| unknown no-query | 已覆盖 | provider unknown 必须先 reconciliation，当前不调用 Provider。 |
| skipped/expired evidence | 已覆盖 | 统一映射为 `notRun`，不升格为 passed。 |

## Gate 边界

| Gate | 状态 | 说明 |
| --- | --- | --- |
| G0 | 已通过（合同范围） | 死信、授权/恢复重放、readiness 与 evidence mapping 的纯合同已验证。 |
| G1 | 未开始 | iOS 未消费用户可披露的 dead-letter/worker 摘要。 |
| G2 | 未开始 | 仍未持久化 admission/replay/manifest，也没有 worker loss、rolling deploy 或 DB restore 演练。 |
| G3 | 未开始 | Provider query/reconcile 仍未启用。 |
| G4 | 未开始 | 无 Operations 阈值、生产运行手册或人工验收。 |

## 下一子闭环

进入 `WI-S1-02-09-G2-DURABLE-DEAD-LETTER-REPLAY-AND-WORKER-LOSS`：先盘点现有 `async_effects.dead_letters` 与 job terminal guard 的约束，再选择最小 migration/repository 路径，保证不能因 restore 或 worker loss 重复业务结果。
