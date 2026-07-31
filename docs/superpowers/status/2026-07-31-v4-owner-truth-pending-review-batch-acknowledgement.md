# V4 M0-A：正式访谈结束后的待整理确认

日期：2026-07-31

## 本轮范围

补齐 iOS 对已部署 Owner Truth 访谈待确认批次合同的正式消费。访谈结束后，产品不再把用户直接带到 Candidate 确认；用户必须先确认“进入整理”，随后才等待独立的 Candidate/记忆确认流程。

本轮沿用后端已部署的待确认批次与确认接口，未改动后端、数据库、公开 Echo 全屏界面或 Provider 调用。

## 行为边界

- 仅在正式产品呈现、当前 `AccountLease` 有效、自然输入策略允许、会话已正常结束且 continuation 为 `reviewPending` 时显示“确认进入整理”。
- 确认前，客户端只读取与当前 `threadID + sessionID` 完全匹配的一条待确认批次；缺失或多条匹配均 fail-closed，不发确认请求。
- 确认请求只携带不透明的会话、批次与乐观版本字段。确认成功后仅展示“这段分享正在整理”，不暴露 Source、Candidate、Memory、Provider 或叙述内容。
- 旧的“查看待确认记忆”直达 Candidate 确认入口已从自然输入结束态移除；Archive 的独立 Candidate 确认入口仍保持原有边界。
- 默认发布态仍受既有策略控制，QA 假客户端不发网络请求、不写入持久化数据。

## 客户端合同

- `GET /v2/vaults/{vaultId}/interview-review-batches/pending`
- `POST /v2/vaults/{vaultId}/interview-review-batches/{reviewBatchId}/acknowledgement`

响应严格限制为会话、批次、版本与整理状态；后端确认响应中的 Candidate 提案仍为 `notStarted`，Memory 激活为 `notApplicable`。

## 验证

- `OwnerTruthContractsTests`：146 项通过。
- 待确认批次确认静态检查通过。
- Candidate 确认展示边界静态检查通过。
- 自然输入产品表面模拟器 smoke 通过：结束访谈、确认整理、渲染“正在整理”状态；未启动后端网络或持久化写入。
- `git diff --check` 与 iOS 相关构建通过。

UIQA 截图：

`tmp/visual-qa/product-v4/owner-truth-interview-natural-input-product-surface-smoke/20260731-203553/01-owner-truth-interview-natural-input-product-surface.png`

## 部署说明

本轮没有后端源码变更，不需要重新部署。当前服务器已运行包含待确认批次确认合同的后端 `main@e7dccd6`；本轮仅补齐 iOS 消费端和本地回归证据。

## 下一边界

整理完成后的 Candidate 提案、Owner 确认和 MemoryVersion 激活保持独立、默认关闭的后续链路；不得由本轮“确认进入整理”直接跨越。
