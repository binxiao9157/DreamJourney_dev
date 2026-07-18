# WI-S0-05-04 模块归属数据导出与终端清理回执

日期：2026-07-18

## 状态

- Work Item：`WI-S0-05-04`
- Authority lock：`RIGHTS_DELETION`
- Execution owner：`codex-goal:019ece6b-2c15-7521-b160-c42e95d1dd5a`
- 结果：`INTERNAL_READY / BACKEND_DEPLOYED / G0_G2_SCOPED_VERIFIED / G4_EXTERNAL_OPEN`
- G0：通过。Owner-scoped 导出、敏感字段裁剪、模块状态聚合和终端清理回执均有确定性测试。
- G2：通过。后端 `main@375e13d` 已部署；隔离 Postgres smoke 验证终端清理回执和外部边界。
- G4：保持 `EXTERNAL_OPEN`。本项不把 Provider、对象存储或备份保留的外部效果误报为已完成。

## 已交付范围

### 个人数据副本

- 新增 `POST /auth/data-export`，仅允许 active account 的 user-session 调用；路由纳入 typed ownership registry，部署后的路由数为 69，未分类数为 0。
- 返回两层稳定合同：
  - `humanReadable`：中文摘要和各模块状态；
  - `machineReadable`：对象、来源、版本化 schema、数量和状态清单。
- 覆盖账户摘要、profile、knowledge snapshot/change、memory、archive metadata、mailbox、Echo delayed reply、voice profile、family、care 等应用自有数据。
- 导出严格不包含原始手机号、访问令牌、密码、会话、设备 token、凭据、媒体二进制文件和第三方 Provider 数据。账户手机号只保留末四位。
- family relationship 当前只导出 owner-scoped projection，因此状态明确为 `partial`，原因为 `ownerScopedRelationshipProjection`；不会表述为跨主体关系的完整副本。

### 终端清理回执

- 账户达到终端 purge 时，应用在清理前记录本地模块资源数量的哈希化 scope，并为 profile、knowledge、memory、archive、mailbox、family、care、echo、notification、voice、digitalHuman、auth 分别写入 data-rights execution。
- 本地应用能在同一 purge transaction 中删除的数据标为 `completed`；Voice clone slot 仅能 retire 时标为 `partial`。
- 未配置的对象存储 adapter 记录为 `unsupported`；Voice Provider、Digital Human Provider、backup retention 和 immutable evidence 记录为 `pending`。这些状态不会生成“已删除”回执。
- Receipt 中仅保存 request/terminal-receipt/resource-scope 的 hash，不保存手机号、原始 user ID、对象 key、正文或媒体内容。
- 旧路径产生而没有 data-rights request 的历史 purge 保留 terminal account receipt，但不会伪造追溯模块回执。

## 明确不宣称完成的内容

1. 真实对象存储删除、Provider Voice/Digital Human 删除或关闭、备份物理清理尚无可用 adapter 与外部回执。
2. 当前是应用自有数据导出和终端清理状态合同；尚未实现跨模块异步 job/outbox 的独立重试执行器。
3. iOS 还没有公开的数据权利状态页或导出入口；本轮只提供安全的后端合同，避免在文案、格式和外部 retention 未冻结前误公开。
4. `WI-S0-05-05` 需要真实 Provider/object/backup 合同及 G3/G4，不因本项通过而解锁。

## 验证

本地：

```text
./scripts/verify_backend.sh
568 tests passed
credential boundary, FastAPI, knowledge, backup contract and diff checks passed

STORE_BACKEND=memory PYTHONPATH=. .venv/bin/python -m unittest \
  tests.test_data_rights_module_inventory \
  tests.test_account_deletion_state \
  tests.test_account_purge_api \
  tests.test_account_deletion_rights \
  tests.test_data_rights_contract \
  tests.test_data_rights_store \
  tests.test_route_ownership_registry \
  tests.test_route_authentication \
  tests.test_runtime_capabilities \
  tests.test_auth_sessions
80 tests passed

STORE_BACKEND=memory PYTHONPATH=. .venv/bin/python -m unittest \
  tests.test_postgres_store tests.test_db_migrator tests.test_core_services
228 tests passed
```

已部署容器内的隔离 Postgres smoke：

```text
status=passed
deployedContainer=true
deployedReadiness=true
temporaryDatabase=true
productionBusinessDataMutated=false
moduleCleanupReceiptsRecorded=true
externalCleanupBoundaryPreserved=true
terminalReceiptRedacted=true
terminalReceiptAppendOnly=true
```

部署后 route authentication smoke：

```text
status=passed
routeCount=69
publicRuntimeAllowed=true
anonymousUserRouteDenied=true
userRouteAllowed=true
machineBusinessRouteDenied=true
machineSystemRouteAllowed=true
```

## 提交与部署

- Backend commit：`375e13d feat(rights): add export and terminal cleanup receipts`
- Remote：已推送至 `origin/main`。
- Server：`/opt/services/dreamjourney/DreamJourneyBackend` 已 fast-forward 到 `375e13d`，API 镜像已 rebuild/recreate。
- Schema：无新 migration；`migrate_db.py --verify` 保持 `appliedHead=0009`、`status=ready`。

## 后续边界

`WI-S0-05-05` 是紧邻的 Provider/object/backup cleanup adapter，但其 G3/G4 前置条件尚未满足，应记录为 `EXTERNAL_BLOCKED`。继续执行时应选择不依赖该外部门的最高优先级 Work Item，不得以本地 slot、mock intent 或 pending receipt 宣称外部删除完成。
