# WI-S1-01-06 MemoryVersion Projection Foundation

日期：2026-07-19

## 当前状态

- Work Item：`WI-S1-01-06`
- Authority lock：`OWNER_TRUTH`
- 执行结果：`SCOPED_G0_G2_PROJECTION_EVIDENCE_PRESENT / KBLITE_READ_ENVELOPE_DEPLOYED / G1_G3_G4_OPEN`
- 范围：只实现确认态 `MemoryVersion` 的 owner-only、默认关闭、可重复重建 Projection 基础；不切换 KBLite、Context Packet、Echo 或公开 UI。

## 已实现

### 后端

- 新增 `owner_truth.memory_projection_checkpoints` 与
  `owner_truth.memory_projection_entries`，按 `vaultId + authorityEpoch`
  分区保存兼容快照。
- 只从 current/active 的 `MemoryVersion` 和 active Source 构建；缺
  checkpoint、Source 撤销、MemoryVersion 变化或 epoch 不匹配时返回
  `rebuilding` 空结果，拒绝复用旧快照。
- Projection 只保存 confirmed content、`contentHash` 与 citation；不复制
  Candidate 原始提案、DecisionReceipt、review rationale。
- 新增仅 QA 可见的 read/rebuild 路由，需 feature env、QA header 和 Owner
  user session；响应仅返回摘要，不返回正文。
- 线上首轮 Postgres smoke 发现 `0016` trigger 的
  `schema_version` 变量映射错误；已通过 append-only `0017` 迁移修复，不改
  写已应用 migration 的 checksum。

### iOS

- 初始 Projection foundation 没有修改 iOS runtime、Archive、KBLite、Context
  Packet 或 Echo UI。
- 后续 bounded read-envelope 子闭环新增了 QA-only typed parser 和独立的
  `OwnerTruthKBLiteCompatibilityStore`；它不读取/写入 legacy KBLite，也没有公开
  入口。详见 `2026-07-19-wi-s1-01-06-kblite-compatibility-read-envelope.md`。

## 验证证据

### G0

1. 后端 focused Projection/migration/API 测试 16 项通过。
2. 后端 `./scripts/verify_backend.sh` 通过：679 个单测，以及 credential、FastAPI、knowledge、backup 等 smoke。
3. `git diff --check`、Python compile 与 shell syntax 检查通过。

### G2

1. Backend `1109a64 feat(v4): add owner truth memory projection` 已推送。
2. Backend `9ac88e3 fix(v4): repair memory projection trigger mapping` 已推送；服务器已应用 migration `0017`。
3. Backend `f1f37c5 test(v4): align route authentication smoke inventory` 已推送并部署；随后 `162afb0 feat(v4): add owner truth compatibility read envelope` 已推送并部署，服务器当前 head 为 `162afb0`。
4. 服务器 Owner Truth Postgres smoke 通过，包含 deterministic rebuild、corrected content、Source revocation fail-closed、stale epoch 与 payload leakage 拒绝。
5. 服务器 route-authentication smoke 首轮通过，`routeCount=82`；线上 `/ready` 为 ready。
6. `162afb0` 部署后再次运行隔离 Owner Truth Postgres smoke，通过 read-envelope 的 standard-fact content hash、non-ready discard、敏感字段过滤与 legacy isolation 验证。
7. `162afb0` 部署后 route-authentication Postgres smoke 通过，`routeCount=91`，并确认匿名用户、机器 principal 与用户 principal 的路由边界仍然 fail closed。
8. 部署后 API、Postgres 和 Redis 均为 healthy，`/ready` 返回 database、schema、auth、incident 全部 ready。

## 明确未做

- 未把 KBLite 改为 Projection reader，也未删除其 legacy writer。
- 未让 `/context/build` 或 Echo 读取该 Projection，未返回 typed Citation。
- 未实现 rights event/outbox 驱动的自动重建。
- 未开放公开 API、UI 或 iOS feature flag。
- 未把 `WI-S1-01-06` 标记为 Registry 完成；它仍需要 G1 与后续子闭环。

## 下一项

read-envelope 的 G2 部署与 smoke 已完成。下一步进入 `WI-S1-01-07` 的 Owner QA Context
与 typed Citation 子闭环；保持 legacy KBLite 不能成为 confirmed-fact Authority。

## 2026-07-29：Legacy KBLite Gap Prompt Fence

`9672ec1 fix(v4): fence legacy KBLite gap prompts` 完成了一个局部 G0 边界修复。

- `DialogEngineManager` 不再把 `KBLiteGapDetector` 基于旧图谱推测出的“知识缺口”和
  建议问题直接注入 Echo prompt。
- 旧图谱的兼容读取、会话摘要和 Archive 既有路径没有迁移；本轮不声称 legacy KBLite
  已成为 Owner Truth Projection，也不改变公开 Echo 视觉或导航。
- 主动追问必须等待 Owner Truth 的 policy-checked recommendation flow；该 flow 仍默认
  关闭，且不因本次修改公开。
- 新增
  `Scripts/QA/product-v4/product-v4-legacy-kblite-gap-prompt-fence-check.py`，防止运行时
  重新接回 `KBLiteGapDetector.shared.buildGapContext()`。

本地验证：legacy KBLite gap prompt fence check、Owner Truth knowledge recommendation
plan client check、`git diff --check` 和 generic unsigned iPhoneOS Debug build 均通过。
这仅补充 `WI-S1-01-06` 的本地 G0 边界证据；Projection rebuild、Context/Echo 正式
cutover、G1/G3/G4 仍保持开放。

## Query-Ranked Context Shadow（QA-only）

Backend `8e2e3c6 feat(v4): add query-ranked context shadow` 与 iOS
`a2cdccc feat(v4): parse query-ranked context shadow` 完成了一项继续保持默认关闭的
G0 子闭环。

- `POST /v2/vaults/{vaultId}/context-shadow/build` 的 QA 合同新增显式
  `selectionMode`。默认仍为 `projectionCitationOrder`；只有 Owner QA 请求显式传入
  `deterministicTextFallback` 时，才读取现有私有 SearchDocument Projection 做确定性
  文本匹配。
- 匹配只能收窄已经通过 Context policy 的 current confirmed `MemoryVersion`。它不能把
  restricted、过期、跨 Vault 或未确认项提升为可见上下文。
- SearchDocument Projection 缺失、checkpoint/authority epoch 不一致时，返回
  `owner_truth_context_search_unavailable_no_personal_memory`，不会回退到 legacy KBLite
  或全量个人记忆；无匹配时返回
  `owner_truth_context_no_query_match_no_personal_memory`。
- Context hash 现在同时绑定 query hash、selection mode、authority、selected/filtered
  citations 和 fallback。Answer/Citation receipt 会回传同一 selection mode，确保收据
  不能引用与 Context build 不一致的选择计划。
- iOS 只解析两种受控 mode，并把 mode 放入 QA evidence readout；公开 Echo、公开
  `/context/build`、Archive/KBLite writer 和三 Tab 视觉均未改变。

本地验证：后端 Context Shadow、Answer Citation、FastAPI candidate-review API 和
SearchDocument read 测试共 22 项通过；Python compile、iOS Context/Citation static check、
`git diff --check` 与 generic unsigned iPhoneOS Debug build 通过。Postgres smoke 已加入
"query matches only confirmed eligible memory" 和相同 Context hash 的 Answer/Citation
断言，但本机未配置 `DATABASE_URL`，因此没有将本轮标记为部署或 G2 通过。

这不是语义检索或质量验收：当前算法仍是 deterministic text fallback，未接入向量、模型
或真实 Owner corpus。真实检索质量、线上 cohort、正式 Context/Echo cutover、G1/G2/G3/G4
继续保持开放。

## 2026-07-29：Live Echo Turn Context Shadow Observer（QA-only）

`e6549ac feat(v4): observe owner truth context per echo turn` 将既有的 typed
`/v2/vaults/{vaultId}/context-shadow/build` 合同接入真实 Echo turn 的 QA 观测，仍不改变
公开回复路径。

- 只有 `DJEnableOwnerTruthContextCitationQA` 开启、当前角色是本人、`AccountLease` 仍匹配且
  `KBPersonaIdentity.isPersonal` 时，才会发起 Shadow 请求；家人、跨 persona、未配置 backend
  或失效 lease 全部 fail closed。
- Shadow transport 只返回 value-free `OwnerTruthContextCitationTraceSummary`。iOS 只把其
  authority state、selection mode、selected/filtered/ranking/citation 数量、hash correlation
  记录到既有 QA panel 和 evidence bundle；不会传给 `DialogEngine`，不会替换 public Context
  Packet，也不会读取或替换 local KBLite fallback。
- Shadow lease 独立 generation-fence 管理。新 turn、context-build invalidation、角色/账户
  生命周期切换都会丢弃旧 callback 并清除旧 QA evidence，避免上一轮摘要写回下一轮。
- 新增
  `Scripts/QA/product-v4/product-v4-ios-owner-truth-context-turn-shadow-check.py` 与
  `run-ios-owner-truth-context-turn-shadow-gate.sh`，检查 self-owner scope、value-free transport、
  public reply isolation 和 stale-callback fence。

本地验证：新 static gate、既有 Context/Citation gate、Echo application coordinator gate、
current handoff gate、`git diff --check` 全部通过；`EchoApplicationCoordinatorTests` 9 项通过；
generic unsigned iPhoneOS Debug `build-for-testing` 通过。

本轮没有后端代码、数据库迁移、部署、线上 shadow cohort、公开 UI 或真机验证。它仅补充
`WI-S1-01-06` 的 G0 观测证据；Projection-to-Context 正式 cutover、KBLite retirement、G1/G2/G3/G4
仍保持开放。

## 2026-07-29：Live Echo Shadow Query Correlation（QA-only）

`b58db69 fix(v4): correlate echo shadow context turns` 继续收紧上一项 live Echo Shadow
observer 的回合归属边界，避免迟到或错误关联的
QA Shadow 响应被保存、展示或导出为当前回响的上下文证据。

- `OwnerTruthContextCitationTraceSummary` 现在保留后端既有的 normalized query hash 和
  Unicode scalar length；不保存原始用户文本。
- `EchoApplicationCoordinator` 在交付成功结果前，按当前提交 query 的同一 hash/length
  重新计算指纹；任一字段不匹配、或旧响应缺少 length 时，均 fail closed 为
  `queryMismatch`，不会写入当前 turn 的 QA evidence。
- QA 面板与 evidence bundle 只导出 query hash 的二次 SHA-256 与 query length，因此可
  排查请求/响应关联，且不会暴露原始 query 或直接复用后端 correlation hash。
- 新字段均为 optional，已存储的旧 QA evidence bundle 可以继续解码；缺失关联字段的旧
  summary 不会被当作当前 live turn 的成功结果。
- 公开 `/context/build`、DialogEngine 输入、legacy KBLite fallback、业务写入、三 Tab UI、
  Provider、部署和真机路径均未改变。

本地验证：Owner Truth live Echo Shadow static gate、Context Citation static gate、focused
`EchoApplicationCoordinatorTests` 10 项、Owner Truth turn-shadow composite gate、generic
unsigned iPhoneOS Debug `build-for-testing`、Echo QA evidence-bundle simulator smoke 和
`git diff --check` 均通过。模拟器导出的 evidence bundle 已确认包含仅 QA 可见的
`queryHashDigest` 与 `queryLength`。

补充说明：Swift Package 全量 `swift test` 仍被既有 package test source 未包含
`AppLaunchPreparing` / `AppLaunchPreparer` / `AppComposition` 阻断；这与本轮文件无关，
不以该失败替代已通过的 Xcode focused test 与 smoke 证据。

该子闭环仍只构成 `WI-S1-01-06` 的 G0 观测正确性证据。它不构成 Projection-to-Context
正式 cutover、KBLite retirement、G1/G2/G3/G4 或公开能力完成声明。

## 2026-07-29：Live Echo Context V1/V4 Parity Observation（QA-only）

`e01725d test(v4): pair live echo context parity evidence` 将当前 self-owner Echo turn 的
legacy public Context V1 packet 与同一 turn 的 Owner Truth Context V4 Shadow summary 配对为
可导出的 QA 证据；它不改写公开回响使用的 Context 或回复输入。

- 只有 `DJEnableOwnerTruthContextCitationQA` 和
  `DJEnableOwnerTruthMigrationParityQA` 同时开启，并且当前角色、账户 lease、context
  generation、public response identity、query hash 和 scalar length 全部匹配时才会开始配对。
  家人、跨 persona、未配置 backend、过期 lease、旧 callback 或任一不匹配均 fail closed，
  清除未完成配对。
- iOS 在进入配对器前把 V1/V4 都缩减为 hash、长度、版本、source/selected/filtered/ranking
  数量、fallback 和 mismatch code；不会保留 `generationContextText`、用户原始 query、answer
  text、citation body 或把 Shadow transport 接到 `DialogEngine`。
- 配对结果固定为 `comparisonState=observedNonPromoting` 和
  `promotionDecision=notEvaluated`。它复用既有 migration comparator 记录差异，但不产生
  cutover 建议、写入、provider 调用或公开 UI 行为。
- Echo QA evidence bundle 升级到 v3，新增 optional 的 value-minimized parity readout；旧 bundle
  仍可解码。QA panel 只在两个 launch arg 均启用时展示 `ctxParity`，公开用户不会看到该区块。
- 新增
  `Scripts/QA/product-v4/product-v4-ios-owner-truth-live-context-parity-check.py`，并把它接入
  Owner Truth turn-shadow composite gate。证据导出 simulator smoke 同时校验 v3 manifest、双 gate、
  不晋升状态以及原始 parity query 不会序列化。

本地验证：live parity static check、既有 live Shadow check 与 migration parity check 通过；
`EchoApplicationCoordinatorTests` 13 项通过；Owner Truth turn-shadow composite gate、Echo QA
evidence-bundle simulator smoke、generic unsigned iPhoneOS Debug `build-for-testing` 和
`git diff --check` 均通过。烟测截图位于
`tmp/visual-qa/prd-stitch-ui/echo-qa-evidence-bundle-export-smoke/20260729-092859/`。

本轮没有后端变更、迁移、部署、线上 cohort、真机验证或公开 UI 调整。它依然只是
`WI-S1-01-06` 的本地 G0 对照观察证据；正式 Context/Echo cutover、检索质量、KBLite retirement、
G1/G2/G3/G4 和任何公开能力仍保持开放。
