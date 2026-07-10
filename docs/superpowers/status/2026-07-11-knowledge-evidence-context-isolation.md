# 知识证据完整性与 Context 隔离实现状态

日期：2026-07-11

任务：Task 14 / `L20260711-022449-15`

Canonical 设计：

`docs/superpowers/plans/2026-07-11-product-knowledge-base-architecture-v2.md`

## 本轮目标

在不改公开 UI、不引入向量数据库、不做真机验证的前提下，关闭知识主链路的三项 P0 风险：

1. AI/assistant 回复被再次抽取为用户事实。
2. low/medium 或错误 persona 的知识进入 Echo。
3. 时间信件、care viewer 和 family persona 降级越过访问边界。

## 后端实现

### `/kb/extract` Evidence Policy V2

新增 additive 请求合同：

```json
{
  "extractionSchemaVersion": 2,
  "sourcePolicy": "userEvidenceOnly",
  "turns": [
    {"index": 0, "role": "user", "text": "..."},
    {"index": 1, "role": "assistant", "text": "..."}
  ]
}
```

- 校验连续零起点 index、`user/assistant` role、非空文本、最大 200 turns、单轮 4,000 字和总计 30,000 字。
- provider prompt 明确 assistant 只能帮助理解，不能作为事实证据。
- `people / places / events / facts` 每个实体必须引用至少一个有效 user turn。
- 缺少来源、非法索引、越界索引、引用 assistant 的实体 fail closed。
- response 增加不含正文的 `evidencePolicy` 计数与过滤 reason。
- v1 transcript 保持兼容；新 iOS 调用固定使用 v2。

### Context P0 Policy

- KBLite fact 只有 `privacyMetadata.scope=generationAllowed` 且 `confidence=high/confirmed` 才进入 selected/generation context。
- low/medium、缺失 confidence 或其他 privacy scope 保留在存储中，但进入 `filteredContext`，不会发送给生成服务。
- KBLite 尚无 persona metadata，因此 family persona 暂不消费 viewer 的 personal KBLite；待 P1 schema 完成后再按目标 persona 开放。
- 时间信件增加：草稿、非收件人、收件人未到期、本人未到期四类门禁。
- 指定 family viewer 时只读取 viewer-specific care snapshot，不能用 owner care 代替。
- family persona 没有明确 viewer 时不注入 owner care。

## iOS 实现

### 证据上送与精提取水位

- Backend client 上送 indexed structured turns、`userEvidenceOnly` 和 v2 schema。
- 为旧后端保留 transcript，但 transcript 只包含 user turn，不包含 assistant 回复。
- `KBLiteGraph` 兼容增加 optional `lastBackendExtractionSessionId/lastBackendExtractionAt`。
- 本地轻量提取不再推进后端精提取水位；首次、间隔三次会话或超过 24 小时会再次触发后端精提取。

### 本地生成门禁

新增 `KnowledgeGenerationPolicy`：

- entity 必须是 `generationAllowed`。
- fact 同时必须是 `high/confirmed`。
- 查询直接命中的 fact 和人物关联 fact 使用同一门禁。

### Persona-bound Echo Context

新增 `EchoKnowledgeContextPolicy`：

- turn gate 固定 expected `userId/personaScope/digitalHumanId`。
- Context response 优先解析 `contextPacket.persona`，兼容旧顶层字段；身份不一致不提交生成。
- family canonical ID 优先使用 `FamilyMember.digitalHumanId`，再降级 `ownerId`。
- local KBLite fallback 只允许 personal/self。
- family 的 timeout、backend 未配置、请求失败、旧合同缺失和 identity mismatch 全部禁止读取 viewer 私有 KBLite。
- 合法空上下文会明确关闭 gate，不留下 timeout/retry。

## QA 入口

后端：

```bash
cd /Users/yxj/Documents/Codex/Video/DreamJourneyBackend
scripts/verify_backend.sh
scripts/run-backend-knowledge-evidence-smoke.sh
scripts/run-echo-context-builder-v2-smoke.sh
```

iOS：

```bash
cd /Users/yxj/Documents/Codex/Video/DreamJourney_dev
Scripts/QA/prd-stitch-ui/run-knowledge-context-policy-model-smoke.sh
swift Scripts/QA/prd-stitch-ui/knowledge-evidence-context-policy-check.swift .
swift Scripts/QA/prd-stitch-ui/knowledge-pipeline-check.swift .
Scripts/QA/prd-stitch-ui/run-knowledge-three-way-merge-model-smoke.sh
RUN_ID=20260711-knowledge-evidence-context-final \
  Scripts/QA/prd-stitch-ui/run-release-regression.sh
```

Release regression 已把新增 model/static policy 设为默认门禁，不需要 launch arg 或外部 key。

## 验证结果

- 后端：204 项 unittest、py_compile、FastAPI、knowledge delta、Mutation V2、evidence smoke 通过。
- Context：low confidence、family personal fact、时间信件 recipient/openAt、care viewer 负向单测与 Context V2 smoke 通过。
- iOS：policy model、knowledge static、three-way merge model、generic Simulator Debug build 通过。
- 完整 release regression 通过：`tmp/visual-qa/prd-stitch-ui/release-regression/20260711-knowledge-evidence-context-final/report.md`。
- generic iPhoneOS Debug build 通过，使用本机固定覆盖 `2BTR77V3R8 / com.yxj.dreamjourney.app`：`tmp/visual-qa/prd-stitch-ui/iphoneos-generic-build/20260711-knowledge-evidence-context-final/report.md`。

## 明确剩余边界

### P1

- 提取结果规范化为服务端 `mutationProposal`，完成稳定 ID、去重、来源与 privacy 继承。
- 知识实体增加 `ownerUserId/personaScope/digitalHumanId/evidenceStatus` 兼容字段，再允许 family persona 使用 KBLite。
- Archive 图片分析、音频转写、视频分析和 timeLetter source lifecycle 接入统一 ingestion/retraction ledger。
- operation ID payload hash、change feed 分页、水位和 compaction。
- 本地知识文件保护、语义缓存按用户隔离、Widget privacy scope、生产日志/trace 正文治理。

### P2

- 建立离线检索评测集；达到设计阈值后再评估 pgvector/rerank。
- PRD 明确后在档案/人格设置中提供知识来源审阅、确认、纠正和删除；不新增第四个 Tab。

### 外部验收

- 真实 DeepSeek 提取质量、部署态 Postgres 和真机 Echo 语义仍需后续验收；不影响本轮非真机合同完成。
