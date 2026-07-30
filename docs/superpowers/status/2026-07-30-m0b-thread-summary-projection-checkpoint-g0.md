# M0-B Thread Summary Checkpoint 本地交接证据

日期：2026-07-30
范围：`WI-S1-01-06` 的 Phase 4 / Slice 4A 私有 Thread Summary checkpoint；仅限 Owner QA。

## 本轮完成

- 后端提交：`DreamJourneyBackend` `main@4aff97f`。
- 新增默认关闭的 `OWNER_TRUTH_THREAD_SUMMARY_PROJECTION_QA_ENABLED=false`。
- 新增仅 QA 可用的私有路由：
  - `POST /v2/vaults/{vault_id}/thread-summary-projections/rebuild`
  - `POST /v2/vaults/{vault_id}/thread-summary-projections/read`
- 路由还要求既有 candidate review、knowledge dimension confirmation、live Thread summary QA gate，以及 `X-DreamJourney-QA-Owner-Truth: 1`。普通用户、公开 API 文档和 Echo UI 均不可见。
- 使用与既有 live Thread summary read 完全相同的 source assembly；只接受当前 Owner-confirmed `MemoryVersion` anchor。source checkpoint、input digest、authority epoch、Vault active 状态或 continuation cue 变化时，读取结果返回 `rebuilding`，不能复用旧 checkpoint。
- 新增 additive migration `0069_owner_truth_thread_summary_projection_checkpoint`：只保存 Vault/epoch、opaque thread/session handle、confirmed `MemoryVersion` anchor、计数和 digest；不保存对话文本、Owner narrative、Source 内容、Candidate payload、模型标签或 provider 输出。
- rebuild 使用 Vault 级 advisory transaction lock；重复 rebuild 在源未变化时返回 `unchanged`。

## 本地验证

- focused Thread Summary checkpoint gate：24/24 通过。
- `PYTHON_BIN=.venv/bin/python scripts/verify_backend.sh`：1650 个单测及现有 gates 通过。
- FastAPI `/health`、`/live`、`/ready`、`/config/runtime` smoke 通过。
- `git diff --check` 与 staged diff check 通过。
- 覆盖：默认隐藏、Owner-only、空/自由字段拒绝、checkpoint rebuild/read、幂等、source 失效、存储篡改 fail-closed、路由认证 inventory、迁移合同。

## 尚未执行的边界

- 已提供 disposable Postgres smoke：
  `DreamJourneyBackend/scripts/run-backend-owner-truth-thread-summary-projection-postgres-smoke.sh`。
- 本机 shell 没有隔离的 `DATABASE_URL` / `TEST_DATABASE_URL`，因此没有运行。该脚本会创建并删除临时数据库，不能指向部署库或生产库。
- 本轮未推送、未部署、未开启 QA flag、未修改 iOS UI，也没有真机或 provider 验证声明。

## 后续执行条件

在部署前，由隔离 Postgres runner 显式提供管理员级测试 DSN 后运行：

```bash
RUN_OWNER_TRUTH_THREAD_SUMMARY_PROJECTION_POSTGRES_SMOKE=1 \
PYTHON_BIN=.venv/bin/python \
scripts/run-backend-owner-truth-thread-summary-projection-gate.sh
```

通过后才可将 migration `0069` 纳入下一次受控后端部署；仍保持 QA flag 默认关闭，且不构成公开 Thread/主题归并功能发布。
