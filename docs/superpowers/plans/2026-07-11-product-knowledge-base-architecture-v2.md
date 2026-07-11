# 寻梦环游产品知识库架构与 PRD 设计 V2

日期：2026-07-11

状态：当前工程知识库设计的唯一权威口径（canonical）

适用仓库：

- iOS：`DreamJourney_dev` / `feature/prd-stitch-ui-adaptation`
- 后端：`DreamJourneyBackend` / `main`

## 1. 设计目标

知识库不是一个独立产品页面，而是贯穿 `记忆档案 -> 回响 -> 我的/家庭/关怀` 的内部能力层：

1. 保存用户本人或获得授权的家庭记忆事实。
2. 让 Echo 在当前问题下检索少量、可信、可解释的上下文。
3. 支持本人、家庭数字人和关怀场景之间的严格数据隔离。
4. 允许用户未来审阅、纠正和删除知识，同时保持多端同步一致。
5. 每次生成都能说明使用了什么、过滤了什么、为什么降级。

本方案不新增第四个 Tab。公开信息架构继续保持：

```text
记忆档案 | 回响 | 我的
```

- `记忆档案` 是可见的来源资产和管理入口。
- `回响` 是知识检索与生成的主要消费方。
- `我的/家庭` 管理身份、家庭关系、数字人人格、授权和关怀边界。
- KBLite/后端 KB 是内部知识层，不直接等于一个新的“知识库页面”。

## 2. 与当前 PRD 的契合点

| PRD 业务 | 知识库职责 | 当前发布边界 |
| --- | --- | --- |
| 文字/照片档案 | 保存来源引用、说明、分析状态和可用线索；媒体文件仍由 Archive 管理 | 公开 |
| 语音/视频档案 | 只消费已完成转写、用户说明或已验收分析结果 | 按现有 feature flag/发布矩阵 |
| 时间信件 | 草稿永不进入 Echo；封存后仍受 `openAt`、本人/收件人和家庭关系约束 | 已有业务合同 |
| Echo | 按当前 query 检索可信事实，构建 turn-scoped Context Packet | 公开 |
| 家庭数字人 | 只使用目标 persona 和有效家庭关系允许的数据 | 公开能力，权限继续收敛 |
| 声音复刻/数字人 runtime | 只作为生成执行状态和 trace，不作为事实知识 | 公开能力 |
| 心境/关怀 | 只使用聚合摘要、风险和趋势，不把私密对话正文暴露给家属 | 公开聚合边界 |
| 家庭邀请 | 邀请中或失败的关系不能成为可访问知识的依据 | 已有合同 |
| 账号注销 | 删除/恢复窗口必须同时覆盖知识快照、变更和来源引用 | 已有 soft-delete 合同，需后续生产验收 |

## 3. 当前实现基线

已经落地的能力：

- iOS `KBLiteGraph`：`people / places / events / facts` 四类实体，本地按用户隔离持久化。
- 后端优先 `/kb/extract`，不可用时使用 iOS 本地轻量提取。
- `/kb/mutations` Mutation V2：实体 upsert、tombstone、revision、幂等 operation ID。
- `/kb/snapshot` 和 `/kb/changes`：权威快照与 change feed。
- iOS per-user remote base、pending mutation 和确定性三方合并。
- `/context/build` Context V2：selected、filtered、ranking trace 与 generationContext。
- Echo 当前 turn 使用 `ChatRagText` 注入，超时使用本地 generationAllowed KBLite 降级。
- QA evidence 已能记录来源、hash、fallback、声音和数字人 runtime 摘要。
- Task 16 知识治理：后端权威 `confirm / reject / correct / deleteSource`、Archive 来源删除组合事务、iOS typed consumer、per-user outbox 和 generation gate。
- Task 17 操作完整性：后端权威 operation receipt/payload fingerprint、Archive 无级联删除幂等、结构化 409，以及 iOS poisoned mutation 恢复与 governance quarantine。
- `RUN_KNOWLEDGE_GOVERNANCE_GATE=1`：串联 iOS 治理/合并检查与后端 memory/fake Postgres 来源级联回归。

已经通过 Task 13-17 收敛的风险：

- provider 实体必须引用有效用户 turn；assistant-only、无来源和越界来源不再进入知识 proposal。
- 后端精提取水位与总 session count 分离，family persona 禁止回退到 viewer 个人 KBLite。
- Context 响应提交前校验 user/persona/digital-human identity，low/medium fact 不进入生成文本。
- 时间信件收件人、care viewer、家庭 persona 和跨用户边界具备负向回归。
- 用户治理动作由后端 snapshot 生成 Mutation V2；旧 user/persona 回调不能直接覆盖当前图谱。
- 同一用户的 operation ID 已绑定稳定 kind/payload 指纹；新请求不能用同一 ID 静默替换 graph、mutation、governance action 或 Archive item。
- iOS 不会永久重放 payload-conflict pending；治理动作最多自动旋转一次，二次冲突进入持久化 quarantine 且不阻塞后续队列。

当前剩余 P1 边界：

- 公开知识审阅/确认/纠正入口尚未由 PRD 和 Stitch 决定，当前只提供稳定 service API。
- 新 Archive 来源使用 `memoryArchiveItem + archiveItem.id`；历史 `archiveImageAnalysis + session-*` 来源需要显式迁移，不会被新删除级联自动命中。
- operation receipt 已完成本地/fake Postgres 实现；真实 Postgres migration/deployed smoke、change feed compaction 仍是后续生产化工作。

现有旧文档 `docs/knowledge-base-design*.md` 只作为历史思路参考。以下旧方向不再作为当前实施依据：

- 新增知识库 Tab。
- 立即引入独立向量数据库。
- 把媒体文件复制进知识图谱。
- 让客户端直接持有并调用 LLM provider key。

## 4. 领域边界

### 4.1 来源资产 Source Asset

Archive 是来源事实的主记录，负责：

- 文字、照片、语音、视频、时间信件原始记录。
- `ownerUserId`、上传者管理权限、`personaScope`、`digitalHumanId`。
- 上传、转写、分析和同步状态。
- 媒体 URL、缩略图、文件大小等资产字段。

知识库只保存 `sourceRefs`，不复制媒体文件，不接管 Archive 生命周期。

### 4.2 知识实体 Knowledge Entity

当前继续使用四类稳定实体：

- `person`：人物、关系、别名、特征。
- `place`：具有记忆意义的地点。
- `event`：人物、地点、时间和描述组成的事件。
- `fact`：可独立引用和验证的陈述。

P1 在兼容字段上增量加入：

```text
evidenceStatus: candidate | observed | confirmed | rejected | superseded
confidence: low | medium | high | confirmed
ownerUserId
personaScope: personal | family
digitalHumanId?
sourceRefs[]
sourceTurnIndices[]
createdAt / updatedAt
```

不在本轮直接重写 `KBLiteGraph` schema；先用兼容字段和生成门禁推进。

### 4.3 运行状态 Runtime State

以下内容只进入 trace，不进入事实知识：

- `voiceProfileId`、声音样本状态、provider log ID。
- 腾讯数字人 session、asset、audio owner、fallback reason。
- ASR/TTS 当前状态、网络错误和配额状态。

## 5. 写入管线

```text
用户证据/档案来源
  -> 来源合法性和权限检查
  -> 结构化候选提取
  -> source/evidence 验证
  -> 规范化、去重、稳定 ID
  -> mutation proposal
  -> 本地合并/用户确认策略
  -> Mutation V2
  -> revisioned snapshot + change feed
```

### 5.1 对话提取规则

P0 固定规则：

1. 只有 `role=user` 的原始话语可作为知识证据。
2. AI/助手回复可以帮助理解上下文，但不能作为事实来源。
3. provider 返回的每个实体必须引用至少一个有效用户 turn index。
4. 没有来源、只引用 assistant turn、越界 index 的实体必须丢弃。
5. 低/中置信事实可以保留为候选，但不能进入生成上下文。
6. 日志只记录数量、索引、hash 和过滤原因，不记录对话正文。

兼容策略：

- `/kb/extract` 支持新的 structured turns 合同。
- 旧 `transcript` 请求继续可读，但标记为 legacy，不能获得比新合同更宽的权限。
- iOS 本地 fallback 继续只扫描用户话语。

### 5.2 档案来源规则

- 用户手写说明可直接成为候选证据。
- 图像/视频分析失败时不得生成空人物、地点和场景事实。
- 音频只使用已完成转写或用户说明。
- 视频只使用已验收分析结果或用户说明。
- 时间信件草稿不进入知识库；封存内容仍受 `openAt` 与收件人策略控制。
- 后端 AI 分析属于辅助结果，必须保留来源和状态，不能冒充用户确认事实。

## 6. 读取与 Context 策略

读取不等于“把整库发送给模型”。每轮 Echo 只组装一个有上限、可解释的 Context Packet：

```text
query + target persona + verified principal
  -> owner/family/time-letter/care policy
  -> candidate retrieval
  -> evidence/confidence filter
  -> ranking + cap
  -> selected / filtered / rankingTrace
  -> generationContext.text
```

### 6.1 P0 生成门禁

允许进入生成文本：

- privacy scope 为 `generationAllowed`。
- 当前用户/家庭 viewer 对来源有权限。
- `fact.confidence` 为 `high` 或 `confirmed`。
- 档案存在用户说明，或分析状态为可用且有非空线索。
- 时间信件已到期且 viewer 是本人或有效收件人。

必须过滤：

- `localOnly`、缺少授权 metadata 的旧数据。
- `low / medium` 事实。
- assistant-only 或无有效来源的提取结果。
- 图像分析失败产生的空线索。
- 草稿或未到期时间信件。
- 写给其他收件人的时间信件。
- 邀请中、失败或失效家庭关系。
- 非目标 `digitalHumanId/personaScope` 的家庭知识。
- voice/digital-human runtime 状态。

本地 fallback 额外遵守：

- 只有 personal/self persona 可以使用当前登录用户 KBLite fallback。
- family persona 请求超时或失败时不得回退到 viewer 的个人 KBLite；应发送空知识上下文并记录 `family_local_fallback_forbidden`。
- 后端响应的 `userId / personaScope / digitalHumanId` 与当前 turn gate 不一致时不得提交给生成 SDK。

过滤必须写入固定 reason，例如：

```text
kb_fact_low_confidence
kb_fact_missing_user_evidence
time_letter_not_due
time_letter_recipient_mismatch
persona_scope_mismatch
family_relationship_inactive
```

### 6.2 排序与容量

当前阶段继续使用规则排序，不立即引入向量数据库：

- query 关键词相关性。
- 来源新鲜度。
- 证据强度和用户确认状态。
- persona 匹配。
- 来源类型权重。

保持 generation text 上限 12,000 字符。达到以下任一条件后再评估 `pgvector + rerank`：

- 单用户可同步事实 P95 超过 1,000 条。
- 规则检索离线 Recall@10 连续低于 0.75。
- Context 构建 P95 超过 300ms，且瓶颈确认为候选检索。

## 7. 身份、家庭与隐私模型

知识访问必须由 verified principal 决定，客户端传入的 `userId/viewerId` 不能单独作为授权依据。

每条可同步知识最终应能回答：

- 谁拥有：`ownerUserId`。
- 属于哪个人格：`personaScope / digitalHumanId`。
- 来自哪里：`sourceRefs / sourceTurnIndices`。
- 能否离开设备：`privacyMetadata.scope`。
- 谁可读取：owner、已接受家庭关系、已到期时间信件收件人等。
- 当前证据状态：candidate/observed/confirmed/rejected/superseded。

关怀数据只向允许的家庭关系提供聚合摘要；不得把用户私密对话原文转为家属可见知识。

知识实体不具备授予权限的能力：

- 对话中提到的 `KBPerson` 只能成为人物候选，不能自动变成 `active + accepted` 家庭成员。
- Family relationship 必须来自手机号邀请、接受状态和后端授权合同。
- 示例/seed 家庭成员只能在 QA launch arg 或测试数据中存在，不能作为生产默认授权数据。
- 同一家庭角色的 Archive、Context 和 Echo 必须使用同一个 canonical `digitalHumanId`。

## 8. 同步、一致性与删除

当前 Mutation V2 + 三方合并继续作为同步基线：

- `operationId` 幂等。
- `baseRevision` 冲突返回 409。
- upsert 与 tombstone 原子提交。
- 本地 `localOnly` 永不上传，也不被远端删除。
- 同一实体双方修改目前确定性 local-wins，并写 QA conflict summary。

Task 16 已完成：

- `confirm` 保留实体与来源，标记 `confirmed`。
- `reject` 保留审计历史，标记 `rejected`，Context 继续过滤。
- `correct` 将旧实体标记 `superseded`，创建稳定 ID 的 `confirmed` replacement，禁止原地改写。
- `deleteSource` 精确匹配 `(kind,id)`，移除对应 source ref，并把直接引用实体标记 `superseded`。
- Archive 删除与知识来源撤销在 memory/Postgres 中使用同一组合事务；sealed 时间信件仍禁止删除。
- iOS 治理动作先进入 per-user outbox，再与普通 graph sync 共用串行 coordinator；409 用同 operation ID 重试。

Task 17 已完成：

- 新增独立 `kb_operation_receipts`，保存 operation kind、schema、canonical payload hash 和无正文结果摘要。
- 指纹不包含 `baseRevision`，因此相同业务 payload 在 revision conflict 后仍可幂等重放；不同 payload/schema/kind 返回 `knowledgeOperationPayloadConflict`。
- Receipt 与 snapshot、change feed、Archive 删除在 Postgres 同一事务中提交；无知识级联的 Archive 删除也有稳定 receipt。
- 历史 `kb_changes` 无法还原原始 payload，继续兼容重放但返回 `operationPayloadVerified=false`，不伪造历史 hash。
- Backend client 保留结构化 `code/operationId/detail`；普通 pending 丢弃 poisoned ID 后刷新重建，governance 首次冲突旋转、第二次隔离。

后续同步生产化：

- 在部署 Postgres 上执行 additive receipt schema 并跑 operation conflict/deletion smoke。
- change feed 增加分页、水位和保留/compaction。
- 为历史 Archive 分析来源建立 canonical sourceRef 迁移工具和迁移证据。

## 9. API 演进

### 9.1 P0 `/kb/extract` additive v2

```json
{
  "userId": "user-id",
  "extractionSchemaVersion": 2,
  "sourcePolicy": "userEvidenceOnly",
  "sessionId": 12,
  "turns": [
    {"index": 0, "role": "user", "text": "我父亲年轻时在南京工作"},
    {"index": 1, "role": "assistant", "text": "那一定留下了很多回忆"}
  ],
  "existingSummary": "...",
  "privacyMetadata": {"scope": "generationAllowed", "sourceRefs": []}
}
```

响应在现有 `extraction` 之外增加无正文的策略摘要：

```json
{
  "evidencePolicy": {
    "version": 1,
    "sourcePolicy": "userEvidenceOnly",
    "userTurnCount": 1,
    "acceptedEntityCount": 1,
    "filteredEntityCount": 0,
    "filteredReasons": {}
  }
}
```

### 9.2 后续 proposal 合同

P1 让提取返回 `mutationProposal`，服务端基于当前 snapshot 完成稳定 ID、去重、来源和授权继承；提取接口本身不直接持久化。iOS/治理策略确认后再调用 Mutation V2。

### 9.3 Task 16 治理合同

```text
POST /kb/governance/actions
```

- 请求固定 `governanceSchemaVersion=1`、`userId`、`operationId`、`baseRevision` 和 typed action。
- 只有 owner principal 可以发起；family action 必须保持 canonical `personaScope/digitalHumanId`。
- 服务端基于当前 snapshot 生成 Mutation V2，客户端不得拼接权威实体。
- 响应返回权威 graph/revision、幂等标志和不含知识正文的 summary。
- Archive 删除复用 `deleteSource(memoryArchiveItem, archiveItem.id)`，零命中时仍可删除档案但不推进知识 revision。

### 9.4 Task 17 operation receipt 合同

- 指纹由后端对 `operationKind + schemaVersion + normalizedPayload` 做 canonical SHA-256；客户端不上传 hash。
- `baseRevision` 不进入指纹，仍单独承担并发前提校验。
- 相同 kind/hash 返回首次权威结果并标记 `duplicate=true`、`operationPayloadVerified=true`。
- 同 ID 不同语义返回 409 `knowledgeOperationPayloadConflict`，detail 只含 code 和 operation ID。
- Legacy change 没有可信原始 payload，兼容返回但 `operationPayloadVerified=false`。
- Receipt、日志和 QA 不记录知识正文；API 不返回 payload hash。

## 10. 可观测性与 QA

每轮知识处理和 Echo Context 应记录：

- user/persona 仅记录不可逆摘要或 QA 环境受控 ID。
- extraction schema/source policy。
- user turn 数、accepted/filtered 数和 reason counts。
- snapshot/change revision、operation ID hash、冲突摘要。
- selected/filtered/ranking counts、source counts、latency、content hash。
- fallback 原因，不记录知识正文。

非真机组合 gate 至少覆盖：

1. assistant 话语不能生成持久知识。
2. 无有效 user turn index 的 provider 结果被过滤。
3. low/medium fact 不进入后端和 iOS 本地生成上下文。
4. 写给 A 的未到期/非 B 收件人时间信件不进入 B 的 Context。
5. 不同用户、不同 family persona、登出/切换旧回调不串数据。
6. tombstone、重试、409 和旧服务端降级仍通过。
7. confirm/reject/correct/deleteSource、Archive 组合删除、outbox 重启恢复和 user/persona 旧回调隔离仍通过。
8. 同 ID 不同 payload/schema/kind/item 返回 409；相同 payload 改 base revision 仍重放；poisoned pending 和 governance quarantine 不阻塞后续同步。

## 11. 分阶段实施计划

### P0：证据完整性与 Context 隔离

- 结构化 turns 与 `userEvidenceOnly` 提取合同。
- provider 提取结果来源校验。
- high/confirmed 生成置信度门禁。
- 独立记录最近一次后端精提取水位，修复提取节流长期退化问题。
- personal/self 才允许本地 KBLite fallback；family persona 禁止使用 viewer 私有知识降级。
- Context Packet identity 校验后才允许进入当前 turn。
- 时间信件收件人和 care viewer 隔离回归。
- 后端/iOS QA gate 与非真机构建。

### P1：提取 Proposal 与 Persona 知识归属

- `/kb/extract` 输出规范化 `mutationProposal`。
- 稳定 ID、实体消歧、来源与隐私继承。
- `ownerUserId/personaScope/digitalHumanId/evidenceStatus` 兼容字段。
- 家庭数字人检索只使用目标 persona 数据。
- 用户确认、拒绝、纠正、来源删除级联。
- Archive 上传、家庭角色选择和 Echo 请求统一 canonical `digitalHumanId`，移除 `family_default/member.id/ownerId` 多套标识。
- KBLite person 到 Family 的自动派生改为“未授权候选”或彻底移除；生产 seed 成员迁到 QA-only。
- timeLetter draft 的后端 payload 使用字段 allowlist；`metadataOnly` 不得携带正文、分析摘要或 transcript，删除草稿需同步撤销。

实施进度：Task 15 已完成 proposal、稳定 ID/关系/metadata、persona-scoped Context 和 iOS canonical identity 主链路。Task 16 已完成用户治理、Archive 来源删除级联、iOS durable outbox/coordinator 和组合 QA gate。Task 17 已完成 operation receipt/payload fingerprint、客户端冲突恢复与隔离。历史 canonical sourceRef 迁移、timeLetter 草稿字段收敛与公开治理体验继续作为后续 P1/P2。

### P1：同步生产化

- operation receipt 的真实 Postgres migration/deployed smoke 与运维观测。
- change feed 分页、水位和 compaction。
- Postgres 多账号并发与事务集成测试。
- 知识、档案、时间信件和关怀的 `asOf` 可观测水位。
- 本地 KB/base/pending 文件保护与备份策略；语义缓存按用户隔离并支持内容更新失效。
- Widget 只导出允许共享的摘要；生产日志和 Echo trace 不记录知识正文，trace 按用户隔离并在登出时清理。

### P2：检索质量与治理体验

- 离线检索评测集和 Recall/precision 基线。
- 达到阈值后再评估 pgvector/rerank。
- PRD 明确后，在档案/人格设置中提供来源审阅、纠正和删除；不新增 Tab。

## 12. 明确不做

- 本阶段不做真机验证。
- 不改变 Stitch 已对齐的公开 UI。
- 不新增知识库 Tab。
- 不把数字人/声音 provider 状态写成用户事实。
- 不在没有指标前引入独立向量数据库、CRDT 或新基础设施。
- 不默认公开尚未验收的语音/视频治理入口。

## 13. 完成标准

产品知识库可以进入下一阶段的前提：

1. 任何进入 Echo 的事实都有可追溯的用户或已授权档案来源。
2. 低置信、失败分析、未到期和无权内容不会进入生成文本。
3. iOS 本地 fallback 与后端 Context 使用同一安全策略。
4. 多用户、家庭 persona、收件人和关怀访问边界有自动化证据。
5. 同步、删除、冲突和旧版本兼容可以重复回归。
6. 后续方案只在本文件的阶段边界内增量推进；重大变更先更新本设计。
