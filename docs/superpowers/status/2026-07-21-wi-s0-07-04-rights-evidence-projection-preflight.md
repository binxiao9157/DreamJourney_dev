# WI-S0-07-04 数据权利证据投影预检

## 本轮范围

本记录对应 `WI-S0-07-04` 的内部预检，不代表该 Work Item、Provider
清理、备份清理或任何隐私/法律外部 Gate 已完成。

后端 `main@b2d3abd` 新增只读的权利证据投影：

- `GET /ops/data-rights/requests/{request_id}/evidence` 仅允许 machine
  principal 的 `rightsEvidence:observe` scope 调用，不进入公开 API 文档。
- 投影只消费既有 rights request、execution、receipt 与 access-revocation
  outbox；不会写入这些权威记录，也不建立第二删除状态机。
- `accessRevocation` 与 `physicalCleanup` 独立呈现。账号撤权不能推导出
  Provider、对象或备份物理清理已经完成。
- module / object / provider / backup 四层按已观察到的证据输出
  `pending`、`partial`、`unsupported`、`completed` 或 `unknown`，缺少终态
  receipt 一律为 `unknown`。
- 报告为脱敏、`no-store` 的运维视图；请求主体、手机号、命令、证明和
  原始 payload 不会出现在响应中。

## 已验证证据

- 后端全量 `scripts/verify_backend.sh`：`1004` tests passed，相关 smoke 与
  `git diff --check` 通过。
- 后端提交并推送：`b2d3abd feat(WI-S0-07): add rights evidence projection`。
- 服务器已快进到该提交并重建 API 容器；公网
  `GET /ready` 返回 `status=ready`。
- 在部署 API 容器内运行临时 Postgres smoke：
  `backend-account-deletion-rights-deployed-smoke.py` 通过，确认
  `rightsEvidenceProjectionVerified=true`、不修改生产业务数据、临时数据库
  已清理。

## 仍然开放的 Gate

1. `WI-S0-05-05` 的真实对象存储、Provider 与备份保留清理尚未形成可验证
   的生产证据。
2. 本投影目前是 shadow/read-only；仍需人工样本对账后才能作为 R1/R3 Gate
   输入。
3. `G3` Provider 证据与 `G4` Privacy/Legal 的披露、SLA 决策仍未完成。

因此本 Work Item 的当前状态应理解为：`G0/G2 scoped evidence present`，
不是全量完成或发布放行。
