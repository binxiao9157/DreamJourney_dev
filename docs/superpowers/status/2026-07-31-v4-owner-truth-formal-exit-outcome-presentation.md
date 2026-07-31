# V4 M0-A 正式结束后的回顾展示闭环

日期：2026-07-31

## 本轮范围

补齐“正式结束一次自然叙述后，Owner 能查看本次受限回顾”的跨合同回归。既有正式结束、隐藏待确认批次和默认关闭的回顾读取接口均已存在；本轮证明它们可以安全衔接，并修复新会话尚未物化 Owner Truth 投影时被误判为无权限的问题。

本轮不新增公开入口，不改变 Echo 全屏视觉，不公开 Candidate、Source、MemoryVersion 或叙述正文。

## 修复后的行为

- 已验证为本人 Owner 的正式会话，在尚无任何 Source/MemoryVersion 物化时，可以读取 value-minimized 回顾结果。
- 该结果为 `state=rebuilding`：已确认记忆数与可继续线索数均为 `0`，但保留当前会话已安全校验的 `pendingReviewBatchCount`。
- 自然输入的 `echoTextInput` 策略不能继承读取回顾的权限；必须单独满足 `ownerTruthInterviewOutcome` 策略。
- 若 Owner Truth vault 已存在但投影读取仍被拒绝，则继续 fail-closed 返回拒绝，不能伪装成“整理中”。
- 回顾响应不含 session/thread/review-batch/source/candidate/memory/provider/policy 标识，也不含私有叙述内容。

## 实现

- 后端在 `OwnerTruthInterviewSessionOutcomeReadService` 中区分“已完成会话归属校验但尚未物化 vault”和“已有 vault 的投影访问拒绝”。
- 重建态展示继续保留当前会话的待确认批次数；该数来自同一请求中已做 Owner/Vault/Authority 校验的会话批次，而非陈旧投影。
- 新增单测覆盖：未物化 vault 的中性回顾、已物化 vault 的拒绝保持 fail-closed、正式结束后的独立策略隔离和 value-minimized 响应。
- 已部署 smoke 增加正式结束后回顾读取、策略隔离及私有字段排除断言。

## 验证

- 后端相关单测：37 项通过。
- Owner Truth interview end G0 gate：98 项通过。
- Python 编译与 `git diff --check` 通过。
- iOS 既有默认关闭回顾 UIQA smoke 通过；未请求后端、未写入持久化数据、未改变公开路由。
- UIQA 截图：
  `tmp/visual-qa/product-v4/owner-truth-interview-outcome-presentation-smoke/20260731-193128/01-owner-truth-interview-outcome-presentation.png`

## 部署验收

- 后端提交：`main@e7dccd6`，已推送并部署。
- 线上 `/ready` 为 ready；数据库、schema、auth 与 incident 探针均通过。
- API 容器内运行：
  `DREAMJOURNEY_DEPLOYED_CONTAINER_SMOKE=1 BACKEND_BASE_URL=https://dreamjourney-api.liftora.cn bash scripts/run-backend-owner-truth-interview-natural-input-deployed-smoke.sh`
  通过。
- smoke 使用临时数据库，验证正式结束、隐藏 `sessionExit` 待确认批次、独立回顾策略、未物化投影的 `rebuilding` 回顾、幂等与私有字段过滤；`productionBusinessDataMutated=false`。

## 未声明完成

- 未将回顾入口默认公开，也未将 Candidate 审核或 MemoryVersion 激活公开发布。
- 未执行真实 Provider、数字人、语音、APNs 或真机验收。

