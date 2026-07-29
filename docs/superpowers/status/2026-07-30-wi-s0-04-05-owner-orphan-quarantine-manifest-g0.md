# WI-S0-04-05 Owner Orphan Quarantine Manifest（G0）

日期：2026-07-30

## 本轮范围

针对既有隔离恢复演练中发现的 361 条历史 owner orphan，本轮新增一个只读、无直接标识的候选清单生成器。它用于把“存在 orphan”收敛为可人工审核的表级分布、HMAC 定位摘要和采样状态；它不是 owner reconciliation、数据修复、恢复切流或生产写入工具。

后端提交：

```text
main@0aabdee feat(v4): add recovery orphan quarantine manifest
```

## 新增实现

1. `app/db/recovery_owner_orphan_quarantine.py` 定义 value-free manifest：
   - 仅接受 `dj_recovery_*` 隔离目标；
   - 输出 `automaticMutation=false`、`automaticOwnerClaim=false`、`automaticDelete=false`；
   - 仅持久化 HMAC locator/owner digest、表级计数、采样状态和 blocker；
   - HMAC redaction key 不进入 manifest、日志或 stdout；
   - 没有稳定主键的 orphan 表被标记为 `unlocatable`，继续 fail closed。
2. `scripts/db/build_recovery_owner_orphan_quarantine_manifest.py`：
   - 先校验 DSN 声明目标，再连接后查询 `current_database()` 二次核验；
   - 在同一 `REPEATABLE READ + READ ONLY` 事务内动态发现 `public` 中带 `user_id` 的 base table；
   - 只在内存读取 `user_id` 和稳定主键；输出文件通过既有 atomic writer 固化为 `0600`；
   - 已存在输出目录不改权限；新建专用目录才设为 `0700`；
   - 返回 `0`（clear）、`2`（quarantineRequired）或 `1`（合同失败）。
3. 新增 `run-recovery-owner-orphan-quarantine-contract-gate.sh`，并接入全量 `scripts/verify_backend.sh`。
4. 后端恢复运维说明补充运行命令、redaction key 文件权限和“无自动处置”边界。

## 明确未做

- 没有对 361 条 orphan 执行认领、重绑、隔离、删除或 replay；
- 没有访问生产数据库、修改负载均衡、创建恢复库或执行真实 Postgres 演练；
- 没有生成可执行的 raw owner/primary-key 操作映射；
- 没有解决 `replayBundleMissing`、身份根、async root authority 或 G3 设备/发布态证据；
- 不宣称 WI-S0-04-05 已完成或允许切流。

未来若需人工处置，必须单独设计加密映射工件、审批、回滚和新的 G2 隔离演练，不能从本清单推导自动修复权限。

## 验证

```bash
PYTHONPATH=. .venv/bin/python -m unittest \
  tests.test_recovery_owner_orphan_quarantine -v
PYTHON_BIN=.venv/bin/python \
  scripts/run-recovery-owner-orphan-quarantine-contract-gate.sh
PYTHON_BIN=.venv/bin/python scripts/verify_backend.sh
git diff --check
```

结果：

- 8 项专用测试通过：value-free 输出、确定性排序、HMAC key、无主键 fail closed、隔离目标拒绝、实际连接库二次校验、既有目录权限不变、静态只读边界；
- 专用 G0 contract gate 通过；
- 全量 `scripts/verify_backend.sh` 通过，包含 FastAPI、既有 G0/G2 合同和静态 Gate；
- 执行了 DSN 目标不匹配的 dry-run，返回 `recoveryDsnTargetMismatch`，且未写 manifest；
- 未运行真实 PostgreSQL disposable/deployed smoke。

## Gate 状态

| Gate | 状态 | 说明 |
| --- | --- | --- |
| G0 | 已通过（本地） | 只读、目标双重校验、HMAC 脱敏和非变更合同已验证。 |
| G2 | 保持 NO_GO | 既有真实隔离恢复仍有 361 orphan 和 replay authority 缺口；本轮未复演。 |
| G3/G4 | 未开始 | 没有设备、发布态或生产切流验收。 |
