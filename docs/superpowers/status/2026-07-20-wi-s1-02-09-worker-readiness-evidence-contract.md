# WI-S1-02-09 Worker Readiness 与 Evidence 合同

日期：2026-07-20

## 本次 G0 子闭环

本次完成 `WI-S1-02-09` 的第二个 G0 子闭环：为默认关闭的 Async Effect worker 建立值无关的 readiness/backlog 证据模型，避免把“未运行”“跳过”“观测失败”错误记为 worker 已就绪。

后端提交：

```text
main@97f5ca6 feat(v4): add async effect readiness evidence
```

新增 `app/async_effects/readiness_evidence.py` 并接入 `AsyncEffectWorkerRuntime`：

1. 证据摘要只包含 runtime/worker 开关、可运行 handler 数、eligible backlog 计数、job type 计数、最老等待秒数和 hash-only worker 标识；不包含 job/operation ID、owner/vault、payload、正文、媒体或 Provider 响应。
2. `ready` 仅在 runtime 允许、存储可观测、没有采集错误且存在可运行 handler 时成立；当前没有注册 handler，因此即使 feature flag 打开仍为 `blocked/asyncEffectNoRunnableHandlers`。
3. 存储不支持返回 `skipped`，backlog 采集异常返回 `unknown`，超出短 TTL 的旧观察返回 `expired`；这三种状态都不可升格为 ready。
4. `shadow_once` 仍只读 preview，不 claim、入队、持久化、重放或调用 Provider；`run_once` 仍不会启动业务 handler。
5. 新 Gate 已接入 `scripts/verify_backend.sh`，确保后续回归不会把这些负状态误判为可执行 worker。

## 已验证

```bash
PYTHON_BIN=.venv/bin/python scripts/run-backend-async-effect-readiness-evidence-contract-gate.sh
PYTHON_BIN=.venv/bin/python scripts/verify_backend.sh
git diff --check
```

结果：

- 专用 readiness/evidence G0 gate `10` 项通过，覆盖 ready backlog 摘要的值无关性、无 handler 的 blocked、store unsupported 的 skipped、采集异常的 unknown、证据 expiry，以及既有 worker 不 claim 的边界。
- dead-letter、lease repository、worker、effect contracts 聚焦组合测试 `26` 项通过。
- 全量后端回归 `817` 项通过；所有既有 FastAPI、Provider、业务消息、知识库、备份 smoke 继续通过。

## 后端部署证据

后端已推送并部署：

```text
origin/main@97f5ca6
server /opt/services/dreamjourney/DreamJourneyBackend@97f5ca6
```

部署仅重建并重启 `api` 容器，未修改 `.env`、`.env.backup*` 或业务数据。`/ready` 返回 database、schema、auth、incident 均为 `ready`。通过服务器 checkout 的只读 tests volume 在一次性容器中重跑：

```bash
scripts/run-backend-async-effect-readiness-evidence-contract-gate.sh
```

线上结果为 `10` 项通过。该证据仅证明部署代码能表达 readiness/evidence 合同，不代表生产 worker、dead-letter 持久化、Provider 对账或自动重放已经启用。

## Gate 边界

| Gate | 状态 | 说明 |
| --- | --- | --- |
| G0 | 部分通过 | dead-letter admission/replay 与 readiness/evidence 纯合同已验证；restore 后 replay、可审计 manifest 写入和完整 worker readiness 仍待收敛。 |
| G1 | 未开始 | iOS 尚未消费用户可披露的 pending/failed/retryable 摘要。 |
| G2 | 未开始 | 未持久化 admission/evidence，也没有 worker loss、rolling deploy 或 DB restore 演练。 |
| G3 | 未开始 | 未查询 Provider，unknown effect 仍禁止自动 replay。 |
| G4 | 未开始 | 无生产阈值、Operations 批准或人工运行手册验收。 |

## 下一子闭环

继续 `WI-S1-02-09-G0-RESTORE-REPLAY-AND-MANIFEST-CONTRACT`：先让 restore/replay 的授权与 stable key 证据可被独立表达，并固定 manifest 不能把 skipped、expired 或 unknown 当作通过；仍不接真实 worker 或 Provider。
