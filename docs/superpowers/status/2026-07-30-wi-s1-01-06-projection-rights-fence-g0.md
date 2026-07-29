# WI-S1-01-06 Owner Truth Projection Rights Fence G0

日期：2026-07-30
状态：`LOCAL_G0_VERIFIED / DEFAULT_OFF_INGRESS / DEPLOYED_POSTGRES_SMOKE_PENDING`

## 本轮范围

后端提交 `DreamJourneyBackend/main@3c21462` 为 Owner Truth 的已确认 Projection 增加 Vault 级 rights revision fence。它解决的是独立权利事件变化后，旧 Projection 仍可被读到的失效缺口。

- rights event 仅记录 `revision`、`active/revoked`、事件哈希和命令哈希，不记录权利正文或档案内容。
- 旧 rights revision 的 Projection checkpoint 会返回 `rebuilding`，必须重新构建后才可读取。
- `revoked` 会使 Projection 读取和重建 fail closed；Context Shadow 为空，KBLite compatibility cache 要求丢弃。
- 私有 SearchDocument 从当前 Projection 派生，因此同样不会读取已失效的条目。

## 没有发生的事情

- 没有新增公开 HTTP 路由、公开 UI、Provider 调用、跨账号读取或 Echo 产品切换。
- 没有接通真实 consent/data-rights ingress，也没有写入真实同意材料。
- 没有部署 migration `0061`，也没有把本地 G0 证据误写为 Postgres 或生产完成。

## 验证证据

在 `/Users/yxj/Documents/Codex/Video/DreamJourneyBackend` 执行：

```bash
PYTHON_BIN=.venv/bin/python scripts/run-backend-owner-truth-projection-rights-fence-gate.sh
PYTHON_BIN=.venv/bin/python scripts/verify_backend.sh
git diff --check
```

结果：rights revision/revoke focused tests `4/4`、Owner Truth/Context/KBLite/worker 回归 `36/36` 和完整 `verify_backend.sh` 均通过。

## 后续 Gate

1. 在隔离 Postgres 部署 migration `0061` 并运行 trigger smoke。
2. 由单独获授权的 consent/data-rights ingress 写入 rights event；未完成前仍保持默认关闭。
3. 不得基于此提交宣布真实权利系统、跨账号访问或公开 Context/Echo 已上线。
