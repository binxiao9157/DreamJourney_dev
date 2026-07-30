# WI-S1-02-09 Async Effect Readiness Manifest 持久化

日期：2026-07-30

## 本次小闭环

后端 `main@16f9aa6` 新增内部适配器，将既有默认关闭的 Async Effect
worker readiness 观察写入现有 append-only `evidence_events` 的
`evidenceManifest` 记录。

实现复用既有 `EvidenceManifestService` 与 `PostgresStore`，没有新表、迁移、
公开 API 或业务消息入口。

适配器只写入 machine-only、value-free 元数据：观察状态、状态码、时间窗口、
schema 版本和 SHA-256 artifact hash。不会写入 job/operation ID、owner/vault、
业务 payload、Provider 请求/响应、credential 或媒体内容。

## 状态与幂等边界

| readiness 观察 | manifest 状态 |
| --- | --- |
| `ready` | `passed` |
| `blocked` | `blocked` |
| `skipped` / `unknown` / `expired` | `notRun` |

- 同一个有效观察通过稳定 manifest ID 和现有 evidence event ID 去重；重复写入返回
  `deduplicated`。
- 观察到期后会形成独立的 `notRun` manifest，不能覆盖或提升此前的 `passed`。
- sink 不可用时直接失败，不伪造写入回执。
- 该路径不会启动 worker、claim/replay job、重入队或调用 Provider。

## 新增验证资产

后端新增：

```text
app/async_effects/readiness_manifest_projection.py
tests/test_async_effect_readiness_manifest_projection.py
scripts/run-backend-async-effect-readiness-manifest-gate.sh
scripts/backend-async-effect-readiness-manifest-postgres-smoke.py
scripts/run-backend-async-effect-readiness-manifest-postgres-smoke.sh
```

临时 Postgres smoke 默认不运行，需显式启用：

```bash
RUN_ASYNC_EFFECT_READINESS_MANIFEST_POSTGRES_SMOKE=1 \
PYTHON_BIN=.venv/bin/python \
scripts/run-backend-async-effect-readiness-manifest-gate.sh
```

该 smoke 使用 `DATABASE_URL` 创建并删除 disposable database，只验证
manifest 写入、重开读取、去重和过期；不写生产业务数据。

生产 API 镜像不会包含 `tests/` 目录，因此部署环境使用单独的 runner：

```bash
bash scripts/run-backend-async-effect-readiness-manifest-postgres-smoke.sh
```

该 runner 只执行 disposable Postgres smoke，不会运行单元测试、启动 worker、
claim/replay job 或调用 Provider。

## 本轮验证

```text
scripts/run-backend-async-effect-readiness-manifest-gate.sh
  15 tests passed

scripts/verify_backend.sh
  1,579 tests passed
  existing FastAPI smoke / contract gates / git diff --check passed
```

部署后端 `main@42e8dff` 后，在 API 容器中执行：

```bash
bash scripts/run-backend-async-effect-readiness-manifest-postgres-smoke.sh
```

结果：通过。该命令创建并清理独立临时数据库，确认 readiness manifest
append、去重、重开读取、artifact 校验和过期清理均可用；不读取或修改生产业务
数据，也不触发 worker、replay 或 Provider 调用。

## Gate 状态

| Gate | 状态 | 说明 |
| --- | --- | --- |
| G0 | 本地通过 | value-free 映射、去重、负状态不提升和 sink 失败边界均有测试。 |
| G2 | 范围内通过 | 后端 `main@42e8dff` 已部署，API 容器中的 disposable Postgres smoke 已验证持久化、重开读取、去重和过期行为。 |
| G3 | 不适用/保持关闭 | 不查询 Provider、不 replay、不启动 worker。 |

## 下一步

继续既定的消息持久化 shadow 小切片：在保留 legacy mailbox 的前提下，为
cross-account business message 明确资源身份与 inbox 身份的 durable projection
边界；不得新增第二个公开消息中心或改变现有 iOS 列表可见性。
