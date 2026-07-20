# WI-S1-02-07 Provider Effect Stable Request 与 Unknown Reconcile：G0 合同证据

日期：2026-07-20

## 本轮边界

本轮只完成 Provider effect 的 G0 盘点与纯合同层。后端新增的
`app/async_effects/provider_effects.py` 不会路由任何请求、不启动 worker、
不读取凭据、不发送 Provider 请求，也没有公开 API 或 iOS UI 变化。

目标是先固定未来迁移必须遵守的边界：同一业务 operation 对同一
provider/capability 只能绑定一个稳定请求；超时后必须进入 honest
`unknown` 并 query/reconcile，不能以新的请求静默重发。

后端代码提交：

```text
0b2ea04 feat(v4): add provider effect contract catalog
```

## Provider 调用盘点

目录为每个现有或明确预留的能力记录 source path、当前执行方式、请求 ID
策略、可否 query/reconcile 与迁移处置。当前共有 10 项：

| Provider effect | 当前执行 | 迁移处置 |
| --- | --- | --- |
| AMap 行政区查询 | 同步只读 | 保持同步只读 |
| APNs 投递 | 尚未实现 | 启用前先有 stable request |
| DeepSeek 图像分析 | text-only 不支持视觉 | 先选择获批 provider |
| DeepSeek KBLite 提取 | 同步直连 | 启用前先有 stable request |
| Echo 服务端模型生成 | 尚未实现 | 启用前先有 stable request |
| 对象存储媒体上传 | mock | 启用前先有 stable request |
| 腾讯数智人会话 | credential broker 阻断 | 先完成 broker |
| 火山旧 TTS | 同步直连 | 启用前先有 stable request |
| 火山复刻音色合成 | 同步直连 | 启用前先有 stable request |
| 火山复刻音色训练 | adapter-only | 启用前先有 stable request |

目录固定为 value-free metadata，不保存 prompt、媒体、请求正文、凭据或
真实 Provider request ID。

## 稳定请求与收据合同

`ProviderEffectIntent` 绑定已经接受的 `AsyncEffectIntent`、provider、
capability 与 `requestHash`，生成：

- `providerEffectKey`：operation stable key、provider、capability、purpose
  与合同版本的确定性哈希；
- `providerRequestId`：由 effect key 和 request hash 派生的确定性 UUID；
- `providerRequestIdHash`、`immutableFingerprint`：仅用于可导出的安全
  证据。

同一个 `providerEffectKey` 重新绑定不同 `requestHash` 会由
`assert_same_provider_request(...)` 抛出 `ProviderEffectConflict`。这不是
retry；调用方必须创建新的业务 operation。

`ProviderEffectReceipt` 只记录 state、attempt、reason code、是否存在
Provider receipt hash 及本地 observation hash。`ProviderEffectReconciliation`
只接受 prior state 为 `unknown` 的记录：

- query 得到 `completed` 或 `failed` 时生成对应的 value-free receipt；
- query 仍未知或 Provider 不支持 query 时保留 `unknown`，要求人工处置；
- `reissueAllowed` 恒为 `false`，不允许由 timeout/reconcile 自动再发一次
  高敏或计费请求。

## 与已部署 async kernel 的关系

迁移 `0013_async_effects_kernel` 已提供 `async_effects.provider_effects` 与
append-only `async_effects.provider_receipts` 表，但当前尚未有 repository
把本轮合同持久化。

该迁移把 `provider_effects.unknown` 列为不可逆终态。因此后续 G2 不能把
unknown 原地更新成 completed/failed；必须新增显式 reconciliation receipt
或 resolution projection，以保留“当时未知、之后查询到结果”的完整事实链。
本轮没有修改 schema、没有部署要求。

## 验证

聚焦 G0 gate：

```bash
cd /Users/yxj/Documents/Codex/Video/DreamJourneyBackend
PYTHON_BIN=.venv/bin/python scripts/run-backend-provider-effect-contract-gate.sh
```

结果：8 项定向测试通过，覆盖稳定 request ID、same key/different hash
拒绝、value-free summary、unknown query/reconcile、禁止自动 reissue、目录
排序/完整性/default-off。

完整后端验证：

```bash
PYTHON_BIN=.venv/bin/python scripts/verify_backend.sh
```

结果：793 项单测、凭据边界 smoke、FastAPI smoke、知识库与 Provider
redaction/cost smoke、备份合同、编译和 `git diff --check` 全部通过。

## 未声明完成

- 还没有把任一现有 DeepSeek、火山、腾讯、对象存储或 APNs 调用迁移到
  ProviderEffect port；
- 没有持久化 effect/receipt、回放、callback、query worker 或 dead-letter；
- 没有真实 Provider sandbox、成本/配额/区域/删除收据或真机验收；
- 任何 Provider capability 仍保持默认关闭，配置存在不等于能力 ready。

## 下一步

进入 `WI-S1-02-07` 的 G2 设计与最小持久化闭环：基于 `0013` 的现有表，
增加不破坏 unknown 终态保护的 reconciliation evidence/projection，并以
隔离 Postgres smoke 验证 crash/replay、same key/hash drift、late receipt 与
无自动重发。真实 Provider 仍不在该阶段启用。
