# WI-S0-07-06 事件生命周期与 Stop-the-Line Fence

日期：2026-07-18

## 状态

- Work Item：`WI-S0-07-06`
- Authority lock：`OPERATIONS_EVIDENCE`
- Execution owner：`codex-goal:019ece6b-2c15-7521-b160-c42e95d1dd5a`
- 结果：`INTERNAL_READY / BACKEND_DEPLOYED / G0_G2_POSTGRES_INCIDENT_LIFECYCLE_VERIFIED / G3_G4_EXTERNAL_OPEN`
- G0：通过。事件开立、确认、fence、解决、重开、重放与错误状态转移均有确定性测试。
- G2：通过。后端 `main@5c42385` 已部署；真实 Postgres 线上 smoke 验证 machine-only route、append-only evidence、重放幂等、fence 和 resolve 生命周期。
- G3/G4：保持开放。该项不将真实 Provider、外部留存、隐私/法务或生产演练回执误报为已完成。

## 已交付范围

- 新增 append-only incident lifecycle：`open -> acknowledge -> fence -> resolve -> reopen`。
- 所有 lifecycle action 都写入现有 evidence sink；不新建可覆盖的 incident 状态表，不保存正文、原始请求标识或 secret。
- 事件状态从 evidence replay 得出；同一 `incidentId/action/commandId` 可安全重放，冲突重用被拒绝。
- critical incident 必须规划 fence actions；支持 `releasePolicy.<feature>`、`releasePolicy.all`、`provider.<code>`、`migration.goNoGo`、`credentialRotation.stop` 与 `readiness.degrade`。
- release policy 读取 incident fence 后 fail-closed：受影响 feature 返回 `503 incident_stop_the_line`；resolve 后恢复正常。
- `/ready` 汇总 incident readiness component，但 warning incident 不会错误拉低 readiness；critical fence 可显式反映为非 ready。
- 新增 machine-only 运维路由：open、readiness、查询、ack、fence、resolve、reopen。匿名和普通 user session 不可调用。
- incident response 只返回 allowlisted lifecycle metadata 与 evidence hash，不泄露原始 resolution evidence ID。
- Postgres 使用同一 transaction 的 advisory lock，避免同一 incident 被并发调度器重复推进。

## 验证

本地：

```text
STORE_BACKEND=memory PYTHONPATH=. .venv/bin/python -m unittest tests.test_incident_lifecycle -v
./scripts/verify_backend.sh
git diff --check
python -m compileall -q app tests
python -m py_compile scripts/*.py
bash -n scripts/run-backend-incident-lifecycle-deployed-smoke.sh
```

- focused lifecycle 测试、完整后端验证包、静态检查和 shell 校验均通过。
- 临时本地 HTTP smoke 验证：匿名 incident route 被拒绝、machine route 可用、warning incident 可 open/ack/fence/resolve、无原始 evidence ID 泄露。
- release gate 回归覆盖：critical incident fence `releasePolicy.echoTextInput` 时，`/echo/delayed-replies/dispatch-due` 被 `503` 阻止；resolve 后可恢复。

线上 Postgres：

```text
scripts/run-backend-incident-lifecycle-deployed-smoke.sh
status=passed
anonymousAccessDenied=true
evidenceLifecycle=appendOnly
incidentResolved=true
machineOnly=true
rawResolutionEvidenceLeaked=false
routeCount=76

scripts/run-backend-route-authentication-postgres-smoke.sh
status=passed
routeCount=76
anonymousUserRouteDenied=true
machineBusinessRouteDenied=true
machineSystemRouteAllowed=true
publicRuntimeAllowed=true
userRouteAllowed=true
userSystemRouteDenied=true
```

## 提交与部署

- Backend commit：`5c42385 feat(ops): add append-only incident lifecycle`
- Remote：已推送到 `origin/main`。
- Server：`/opt/services/dreamjourney/DreamJourneyBackend` 已 fast-forward 到 `5c42385`，容器已 rebuild/recreate。
- Schema：无需新增 migration；服务器 `migrate_db.py --verify` 保持 `appliedHead=0009`、`status=ready`。

## 未关闭边界

1. 当前 evidence retention、操作阈值、告警升级与 incident owner 值班制度仍需 Operations/Privacy 外部确认。
2. Provider、对象存储、备份与生产演练的真实外部回执不由本项替代。
3. 下一项 `WI-S0-07-07` 负责继续收敛 evidence 的字段 allowlist、伪脱敏与正文日志治理；在此之前不得将当前 metadata 约束表述为全局日志治理已完成。
