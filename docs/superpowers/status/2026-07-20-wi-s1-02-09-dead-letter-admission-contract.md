# WI-S1-02-09 Dead-Letter 接收与授权重放合同

日期：2026-07-20

## 本次 G0 子闭环

本次只完成 `WI-S1-02-09` 的首个 G0 子闭环：把异步 effect 的终态失败转换为可审计、无正文泄漏的 dead-letter admission，并为后续受控重放固定授权边界。

后端提交：

```text
main@18efea0 feat(v4): add dead letter replay contract
```

新增 `app/async_effects/dead_letter_effects.py`，其中：

1. 仅 `failed`、`unknown`、`blocked` 终态可进入 dead-letter；成功或非终态 job 会 fail-closed。
2. `poisonPayload`、`maxAttemptsExceeded`、`providerUnknown` 与 `manualInterventionRequired` 是明确的分类；`maxAttemptsExceeded` 要求 `attempt >= maxAttempts`，`providerUnknown` 必须来自 `unknown` 状态。
3. admission 的 ID 由 job 与 attempt 确定性生成，摘要只保留 owner/vault/operation/receipt/hash 等坐标，禁止携带原始 payload、媒体、正文或 Provider 响应。
4. replay 只接受 owner、vault、authority epoch 与 authorization receipt hash 均匹配的命令；它生成新的 replay attempt，但保留原业务 `stableKey`，不会直接 claim、入队、调用 Provider 或重放 rights 任务。
5. poison payload 必须先修正，provider unknown 必须先对账，manual intervention 必须人工处置；它们均不能盲目 replay。

本次把专用 gate 接入 `scripts/verify_backend.sh`，因此后续全量后端验证会持续检查该合同。

## 已验证

```bash
PYTHON_BIN=.venv/bin/python scripts/run-backend-async-effect-dead-letter-contract-gate.sh
PYTHON_BIN=.venv/bin/python scripts/verify_backend.sh
git diff --check
```

结果：

- 专用 dead-letter G0 gate `3` 项通过，覆盖 poison/max-attempt admission、value-free summary、同一 stable key 的 owner-authorized replay、attempt 递增、错误 actor/authority，以及 unknown/poison 禁止盲重放。
- 与现有 lease worker、Consumer Inbox、Provider effect 合同的聚焦组合测试 `21` 项通过。
- 全量后端回归 `812` 项通过；既有 credential boundary、Provider G0/G2、business message/notification、知识库、备份和 FastAPI smoke 均通过。

## 后端部署证据

后端已推送并部署：

```text
origin/main@18efea0
server /opt/services/dreamjourney/DreamJourneyBackend@18efea0
```

部署仅重建并重启 `api` 容器，未修改 `.env`、`.env.backup*` 或业务数据。`/ready` 返回 database、schema、auth、incident 均为 `ready`。生产镜像不携带 tests，因此使用服务器 checkout 的 `tests/` 作为只读 volume 运行：

```bash
scripts/run-backend-async-effect-dead-letter-contract-gate.sh
```

线上结果为 `3` 项通过。它证明已部署代码可加载并满足纯 G0 合同；不代表 worker 已启用、dead-letter 已持久化，或 Provider 已被查询/重放。

## Gate 边界

| Gate | 状态 | 说明 |
| --- | --- | --- |
| G0 | 部分通过 | admission、授权边界、stable key 与负例已验证；worker readiness、skipped/expired evidence、restore 后 replay 的完整可执行证据仍待实现。 |
| G1 | 未开始 | iOS 尚未消费用户可披露的 dead-letter 摘要。 |
| G2 | 未开始 | 尚未把本合同写入现有 `async_effects.dead_letters`，也没有 worker loss、rolling deploy 或 restore 演练。 |
| G3 | 未开始 | 未查询 Provider，不允许自动/盲目重放 unknown effect。 |
| G4 | 未开始 | 无真实生产运维批准、监控阈值或人工运行手册验收。 |

## 下一子闭环

继续 `WI-S1-02-09-G0-WORKER-READINESS-AND-EVIDENCE-CONTRACT`：先做 value-free readiness/backlog/oldest-age/evidence manifest 的纯合同，并显式区分 ready、skipped、expired、unknown；仍不启动真实 worker、不批量重放。
