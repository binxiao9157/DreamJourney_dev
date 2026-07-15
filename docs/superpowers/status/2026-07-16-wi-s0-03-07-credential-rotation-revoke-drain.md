# WI-S0-03-07 Credential Rotation / Revoke / Drain 记录

日期：2026-07-16
Work Item：`WI-S0-03-07`
状态：`EXTERNAL_BLOCKED`
Decision：`STOP_PENDING_OWNER_ROTATION_RECEIPTS`
Execution owner：`codex-goal:019ece6b-2c15-7521-b160-c42e95d1dd5a`
Authority lock：`CREDENTIAL_CONTROL`
Lease：`HELD`

## 1. 依赖与 Gate

- `WI-S0-03-01/02/03/04/05/06` 已完成内部 containment 或关闭路径。
- Registry 要求 `G0`，当前结论为 `G0=MISSING`。
- Provider 控制台真实 rotation/revoke 和资产 Owner 确认尚未发生，不能用源码删除、服务重启或 mock 代替。
- 本项不得在缺少旧版本撤销回执时标记为 `VERIFIED`，也不得越过 Gate 进入下一 Slice。

## 2. 本轮无值基线

- scanner report：`tmp/visual-qa/prd-stitch-ui/credential-inventory/20260716-wi-s0-03-07-baseline/credential-inventory.json`。
- SHA-256：`f5624b036bbb19a53d0bcf1454881e6f2567df03f910c296f7078cd308e3995e`。
- 唯一候选 `284`，唯一阻断候选 `156`，阻断 observation `644`。
- `GENERIC_SECRET` 仍有 `233` 条 observation 待 `SECURITY_TRIAGE_OWNER` 分类。
- 报告与本文不包含 credential 原值、Authorization header、Provider response 正文或完整私有配置。

## 3. 已完成的内部 containment

- response credential boundary：Backend `1be115a`、iOS `a15ba2b`。
- mobile credential injection 退役：iOS `1aa7146`。
- QA credential artifact 路径退役：iOS `8860fe9`。
- realtime direct mobile 关闭：Backend `2fafa50`、iOS `55a791a`。
- digital-human direct mobile 关闭：Backend `d23b940`、iOS `551590c`。
- 数字人旧 lease drain：Backend `7839583` 已推送和部署；启动时幂等清理超过 `expiresAt` 的 active lease。

## 4. Drain 部署证据

- 部署前 Postgres：`active + elapsed=1`、`expired=5`、`released=56`。
- 部署后 Postgres：`active=0`、`expired=6`、`released=56`。
- 线上 credential response deployed smoke 继续通过，数字人和 realtime response 仍为 value-free blocked contract。
- drain 只更新超时 lease 状态，不删除记录，不接触 Provider credential 原值。

## 5. 外部 Owner 待办

以下 credential family 均已写入无值 receipt，但真实 rotation/revoke 状态仍为 `OWNER_ACTION_REQUIRED`：

- `BACKEND_SHARED_TOKEN`
- `BEARER_TOKEN`
- `DEEPSEEK_API_KEY`
- `TENCENT_CLOUD_SECRET_KEY`
- `TENCENT_DIGITAL_HUMAN_ACCESS_TOKEN`
- `VOLCENGINE_ACCESS_TOKEN`
- `VOLCENGINE_APP_TOKEN`
- `VOLCENGINE_SECRET_KEY`

每个 family 都必须由对应资产 Owner 在受控控制台完成新版本启用、旧版本撤销，并只回填无值 `providerEvidenceIds`。在此之前 receipt 保持 `EXTERNAL_OWNER_ACTION_REQUIRED / STOP`。

## 6. 验证与完成边界

- Backend：311 项单测、Postgres store targeted tests、FastAPI smoke、credential response boundary smoke 通过。
- Backend：`7839583 security(WI-S0-03-07): drain expired digital-human leases` 已推送、部署，线上 Postgres drain 通过。
- value-free receipt：`docs/superpowers/status/2026-07-16-wi-s0-03-07-credential-rotation-receipt.json`。
- iOS control-plane commit：本文所在提交。
- receipt truthfulness gate 会拒绝 credential 原值字段，也会拒绝在无 Provider evidence 时把 G0 或 release decision 标成通过。
- 当前只完成可逆 containment 与 drain；真实 rotation/revoke 需要资产 Owner 操作，因而 Work Item 保持 `EXTERNAL_BLOCKED`。
