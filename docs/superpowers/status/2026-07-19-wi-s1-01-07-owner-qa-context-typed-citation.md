# WI-S1-01-07 Owner QA Context 与 Typed Citation

日期：2026-07-19

## 结论

`WI-S1-01-07` 完成了限定的 G0 合同闭环：iOS 可以在默认关闭的
Owner QA 模式下调用既有 Context Shadow 与 Answer Citation 接口，严格解析
Confirmed Memory / Projection 的无正文引用证据，并把摘要映射到现有 Echo QA
evidence 结构。

状态：`INTERNAL_READY / G0_TYPED_CONTRACT_VERIFIED /
G1_QA_TEXT_EVIDENCE_SIMULATOR_VERIFIED /
G2_SCOPED_DEPLOYED_POSTGRES_VERIFIED / IOS_LOCAL_COMMITTED /
G3_DEFERRED_UNTIL_QUERY_QUALITY_GATE_EXISTS`。

本轮没有修改公开 `/context/build`、公开 Echo UI、Archive/KBLite writer、数字人或
音色链路。生产用户无法通过此合同读取个人记忆正文。

### 2026-07-30 Context 当前性补强（本地 G0）

Context Shadow 构建和 Answer/Citation 写入之间可能存在短暂的来源撤回窗口。为避免
QA 证据把已变化的 Projection 当作新的当前引用，后端在写入前新增以下 fail-closed
复核：

- 仅当 Context 为 `ready` 时，重新读取 Owner-scoped Memory Projection。
- `state`、`authorityEpoch` 或 `checkpoint` 任一变化即拒绝写入，且不保留 Answer
  或 Citation 记录。
- Postgres 已有的 `owner_truth_answer_citations_validate_memory` trigger 继续作为同一
  事务内逐条 Citation 的最终并发防线；本次不改变其 schema、公开路由或默认开关。
- In-memory 语义实现同步遵守该边界，避免测试双实现与 Postgres 行为失真。

验证新增覆盖“Context 构建后 Source 被撤回”的负向场景：服务返回
`OwnerTruthAnswerCitationConflict`，answer ledger 保持为空。该补强目前仅完成本地 G0
验证，尚未部署；既有 G2 隔离 Postgres smoke 不应被用来声称这段新代码已线上验收。

### 2026-07-30 Citation Currentness Read 与 Answer Feedback（本地 G0）

后端 `main@17d7060` 增加了两条继续保持默认关闭的 Owner QA 合同：

- `GET /v2/vaults/{vaultId}/answers/{answerId}/citations`：只读既有 Answer receipt 的
  typed citation 与当前性。每条 citation 仅有 ID、版本、哈希和
  `current/citationNotCurrent/projectionUnavailable/...` 状态，不返回 query、answer、
  Projection 或 Memory 正文。
- `POST /v2/vaults/{vaultId}/answers/{answerId}/feedback`：写入一次性的
  `helpful: boolean` 无正文 receipt。同一 command 幂等、同一 Answer 不可覆盖；只有
  `helpful=true` 且所有 citation 在相同 authority epoch 下仍当前时，才会产生
  `metricEligible=true`。

无 citation 的回答仍可保留一条 `noCitations` 反馈，但永久不是指标信号；Projection
重建、Source 撤回或 rights 变化时，反馈同样不会变成指标。`0062` 还把 feedback
receipt 纳入 Owner Truth data-rights 导出和终端清理计数，导出的只有哈希、布尔值、计数和
时间，没有私密正文。

验证已通过：新增 focused G0 gate、FastAPI QA 默认隐藏/Owner 边界测试、路由认证与
ownership inventory、迁移合同、data-rights 测试以及完整
`scripts/verify_backend.sh`（1,531 项测试及既有 gates）。该变更尚未部署，不能把
本地验证写成 G2/Postgres 或公开 Owner QA 已验收。

## 实现

### 已有后端合同

后端已部署的以下 QA-only route 是本轮唯一依赖：

- `POST /v2/vaults/{vaultId}/context-shadow/build`
- `POST /v2/vaults/{vaultId}/answer-citation-receipts`

它们要求已认证 Owner 和 `X-DreamJourney-QA-Owner-Truth: 1`，默认关闭，且返回
MemoryVersion、Source、rank、过滤原因、hash、authority epoch 与 checkpoint；不返回
query、answer 或记忆正文。

### iOS

- 新增 Context Shadow、Citation、ranking、authority 与 receipt 的强类型解析。
- QA gate 为 `DJEnableOwnerTruthContextCitationQA`，release build 一律关闭。
- `DreamJourneyBackendClient` 只用 owner-authenticated `userRequired` 请求调用隐藏端点。
- 解析器拒绝 raw content key、legacy Context read、跨 Vault 引用、selected/filtered
重叠、hash/authority 不一致及无效 citation。
- 整数字段支持真实 `JSONSerialization` 的 `NSNumber`，但拒绝 Boolean、小数、溢出值。
- 新增无正文 `OwnerTruthContextCitationTraceSummary`，可映射到既有 Echo QA evidence，
不改变公开 Echo 上下文来源。
- G1 增加 `OwnerTruthContextCitationQAEvidenceReadout`：只导出 Context / policy /
  authority 摘要、计数和单向哈希后的 MemoryVersion 引用；不导出 query、answer、
  memory value、原始引用或 projection checkpoint。
- Echo QA 面板只在 Debug/UIQA 且带 `DJEnableOwnerTruthContextCitationQA` 时出现该摘要；
  面板固定在话筒上方的可滚动容器中，Owner Truth 摘要优先显示，避免遮挡公开 Echo
  的话筒和底部导航。

## 验证

通过：

```bash
python3 Scripts/QA/product-v4/product-v4-ios-owner-truth-context-citation-check.py
Scripts/QA/product-v4/run-ios-owner-truth-context-citation-text-evidence-gate.sh
Scripts/QA/prd-stitch-ui/run-echo-qa-evidence-bundle-export-smoke.sh
git diff --check
```

验证覆盖：

- 合法 Projection citation 与 raw content / cross-vault 拒绝。
- Context hash、query hash、answer hash、authority epoch、checkpoint 的精确绑定。
- JSON 往返后的整数解析，以及 Boolean / 小数拒绝。
- 后端默认隐藏、Owner ownership、重建投影与 replay 边界。
- 无正文 QA readout 的哈希化、导出和首屏可读性；导出 JSON 不包含原始 MemoryVersion。
- SwiftPM 29 项测试、`generic/platform=iOS build-for-testing` 和模拟器 UIQA smoke 通过。

模拟器证据：

```text
tmp/visual-qa/prd-stitch-ui/echo-qa-evidence-bundle-export-smoke/20260719-233143/
```

其中 `01-echo-qa-evidence-bundle-export-smoke.png` 显示 QA 容器未遮挡话筒或底部导航；
`echo-qa-evidence-bundle.json` 包含 `owner-truth-context-citation-readout-v1` 和哈希引用，
不包含原始 MemoryVersion。

截至最初的 2026-07-19 交付，服务器上的既有 QA contract 无需重新部署。2026-07-30
新增 Context 当前性 guard 时，它最初只有本地 G0 证据；下节记录了随后完成的部署复演，
因此不能再把该历史描述理解为当前仍未部署。

### 2026-07-30 当前性 guard 部署复演

后端 `main@e4e4713` 已将 `0064/0065` 的 forward-only 修复部署到 API 容器，并在 disposable
Postgres smoke 中验证：Source Candidate 提取、Projection/SearchDocument 重建、当前 Citation
保护和 correction resolution 均通过。该 smoke 使用独立临时数据库，不向业务库写入测试
Owner、Memory、Answer 或 Citation。

因此本条 Context 当前性 guard 的 G2 状态已更新为**已部署且 scoped 验证**。这只证明
Owner Truth 默认关闭链路的 schema/service/transaction 约束；不打开公开 `/context/build`、
不宣称检索质量、Provider、真实 Owner cohort 或公开 Echo 已验收。

### G2 服务器隔离验证

- 服务器运行版本为 Backend `main@162afb0`；API、Postgres、Redis 均处于 running，
  `/ready` 返回 `ready`。
- 在 API 容器执行 `scripts/run-backend-owner-truth-postgres-smoke.sh` 通过。该脚本为
  Postgres 创建并删除独立临时库，未向业务库写入测试 Source、Candidate、Memory 或
  Answer；结果包含 `schemaHead=0023`，并确认 Context Shadow typed citation、
  value-free、fail-closed、Answer Citation 幂等/不可变等断言全部通过。
- 服务器运行时 `OWNER_TRUTH_CANDIDATE_REVIEW_QA_ENABLED=false`、Projection worker
  仍默认关闭。匿名外网请求在路由认证中间件即被 `401` 拒绝，因此没有为了验收而打开
  QA-only 路由或创建生产测试用户。

## 剩余 Gate

- `G1`：已完成 QA-only 文本 readout、导出和模拟器交互验证；公开 UI 保持不变。
- `G2`：已完成部署容器内的隔离 Postgres 合同 smoke；真实 Owner QA cohort 的线上
  观察、性能/容量阈值和 citation resolve 压测仍未执行，不能因此宣称公开 Context
  切流完成。
- `G3`：`projectionCitationOrder` 仍只是确定性引用顺序。后续新增的
  `deterministicTextFallback` 只在 QA Context Shadow 显式请求时读取当前
  SearchDocument Projection，并且只能收窄已获准的 confirmed MemoryVersion；它不是
  语义检索或质量认可。不能用 fixture 伪造“检索质量已验收”，也不能把该 Gate 误标为
  完成。后续仍需独立语料、失败分母、跨 Vault 拒绝与质量门。
- `G4`：不适用于本轮内部 QA 合同；未来公开/隐私评审另行处理。

## 下一步

`WI-S1-01-07` 的内部 QA 合同现已包含 citation currentness read 和无正文 feedback
receipt，但 G3 仍保持 `DEFERRED_UNTIL_QUERY_QUALITY_GATE_EXISTS`。它不是公开反馈、
训练数据入口或质量结论。后续只能在独立 cohort、检索质量分母、容量与隐私 Gate 存在后
再讨论指标聚合或公开化；不得把 legacy/private JSON 当作 Authority。
