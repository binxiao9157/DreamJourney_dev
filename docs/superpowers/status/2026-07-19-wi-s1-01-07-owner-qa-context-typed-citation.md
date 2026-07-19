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
G3_DEFERRED_UNTIL_QUERY_RETRIEVER_EXISTS`。

本轮没有修改公开 `/context/build`、公开 Echo UI、Archive/KBLite writer、数字人或
音色链路。生产用户无法通过此合同读取个人记忆正文。

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

后端本轮没有代码变化；服务器上的既有 QA contract 不需要重新部署。

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
- `G3`：当前 `ContextShadowService` 的 `projectionCitationOrder` 是确定性引用顺序，
  代码明确标注它不是相关性排序；工程尚不存在 query-driven retriever/ranker。因此不能用
  fixture 伪造“检索质量已验收”，也不能把该 Gate 误标为完成。待后续引入真正的 query
  retriever 后，再以独立的语料、失败分母、跨 Vault 拒绝与质量门完成本 Gate。
- `G4`：不适用于本轮内部 QA 合同；未来公开/隐私评审另行处理。

## 下一步

`WI-S1-01-07` 的当前内部 QA 合同不再继续伪造 G3 基线。将 G3 保持为
`DEFERRED_UNTIL_QUERY_RETRIEVER_EXISTS`，并转入不依赖它的 `WI-S1-01-08`：纠正必须
形成 Correction Candidate 和新的不可变 MemoryVersion，而不是原地修改 Archive 或
Projection。真实 Owner QA cohort 的线上观察、容量压测和未来 query retrieval 质量门仍
作为后续受控 Gate，且不得把 legacy/private JSON 当作 Authority。
