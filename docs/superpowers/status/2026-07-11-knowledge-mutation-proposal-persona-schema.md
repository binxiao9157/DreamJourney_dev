# 知识 Mutation Proposal 与 Persona 归属实施状态

日期：2026-07-11

对应任务：`docs/plans/task_15_p1-knowledge-mutation-proposal-persona-schema.md`

Canonical 设计：`docs/superpowers/plans/2026-07-11-product-knowledge-base-architecture-v2.md`

## 结论

Task 15 已完成非真机范围实现。知识提取不再由 iOS 直接把 provider 结果随机 UUID 化；后端会基于权威 snapshot 生成不落库的 `mutationProposal`，iOS 在确认 user/persona/digital-human identity 仍一致后优先合并。personal 旧知识保持兼容，family 只读取目标 `digitalHumanId` 的显式 family 知识。

## 后端实现

### `/kb/extract` additive proposal

v2 response 保留：

- `extraction`
- `evidencePolicy`

并新增：

- `mutationProposal.proposalSchemaVersion=1`
- `mutationSchemaVersion=2`
- `baseRevision`
- `ownerUserId/personaScope/digitalHumanId`
- `upserts.people/places/events/facts`
- `tombstones=[]`
- `proposalPolicy` 无正文计数摘要

proposal builder 负责：

- Unicode NFKC、casefold、空白折叠自然键。
- 优先复用 snapshot legacy/匹配 persona ID。
- 未命中时生成 owner/persona/type/natural-key 绑定的 SHA-256 ID。
- 净化并合并 `privacyMetadata/sourceRefs`。
- 写入 `sourceSessionIds/sourceTurnIndices/evidenceStatus`。
- 把人物、地点、事件、事实的名称关系解析为有效实体 ID。
- 保留 `rejected/superseded`，重复提取不会自动复活被否定知识。

接口本身不修改 snapshot、revision 或 change feed；最终提交仍由现有 Mutation V2 和三方合并负责。

### Context persona policy

- personal：兼容缺 persona metadata 的旧事实；显式 metadata 必须匹配当前 user/personal/self。
- family：必须 `ownerUserId + personaScope=family + digitalHumanId` 全匹配，缺字段拒绝。
- `observed/confirmed` 可进入生成；`candidate/rejected/superseded` 不进入。
- privacy scope 与 high/confirmed confidence 门禁继续生效。
- `memory.kbFacts`、selected candidates 和 generationContext 使用同一 eligible fact 集合。

## iOS 实现

- KBLite 四类实体 additive 增加 optional owner/persona/evidence/source-turn 字段，旧 JSON 继续可读。
- 新增 proposal/upserts/policy/envelope Codable 模型。
- `extractKnowledgeEnvelope` 发送 canonical persona identity；服务端无 proposal 时兼容 legacy，声明但损坏的 proposal 会被拒绝。
- ConversationMemory 在异步提取前冻结 `KBPersonaIdentity`。
- completion 同时校验用户 generation 与当前 persona；角色已切换时丢弃旧结果。
- proposal-first merge 先建立 proposal ID 到本地 legacy ID 的映射，再重映射所有关系，避免重复实体和悬空引用。
- existing summary、quick extraction 和 local generation fallback 使用同一 persona policy。
- Echo 复用 KBLite canonical resolver；family local fallback 继续禁止。
- invalid proposal 不推进后端精提取水位。

## QA 入口

日常本地模型/静态检查：

```bash
Scripts/QA/prd-stitch-ui/run-knowledge-proposal-model-smoke.sh
Scripts/QA/prd-stitch-ui/run-knowledge-context-policy-model-smoke.sh
Scripts/QA/prd-stitch-ui/run-knowledge-three-way-merge-model-smoke.sh
Scripts/QA/prd-stitch-ui/run-knowledge-proposal-persona-policy-check.sh
```

后端专项：

```bash
cd /Users/yxj/Documents/Codex/Video/DreamJourneyBackend
scripts/run-backend-knowledge-proposal-persona-smoke.sh
```

Release regression 可选组合门：

```bash
RUN_KNOWLEDGE_PROPOSAL_PERSONA_GATE=1 \
RUN_STANDARD_BUILD=1 \
RUN_SIMULATOR_SMOKE=0 \
Scripts/QA/prd-stitch-ui/run-release-regression.sh
```

该 gate 只使用本地 memory backend，不依赖线上服务。日常 release regression 无论开关都会运行 iOS proposal model 与 source guard。

## 验证边界

最终自动化证据：

- 后端：213 项 unittest、py_compile、FastAPI、knowledge delta、Mutation V2、evidence 与 proposal/persona smoke 通过。
- Release regression：`tmp/visual-qa/prd-stitch-ui/release-regression/20260711-knowledge-proposal-persona-final3/report.md`。
- Generic iPhoneOS：`tmp/visual-qa/prd-stitch-ui/iphoneos-generic-build/20260711-knowledge-proposal-persona-final/report.md`，bundle ID 使用本机 `com.yxj.dreamjourney.app` guard。
- Release regression 内模拟器 delayed-reply notification smoke 通过；没有把模拟器证据声明为真机验收。

- 不做真机验证，符合本轮目标。
- 不改变公开 Stitch UI。
- 不推送、不部署，除非后续明确要求。
- 后端需要部署后，线上 `/kb/extract` 才会返回 proposal，family persona Context 才会使用新的实体级合同；旧 iOS/旧后端仍保留兼容路径。

## 提交版本

- 后端：`5fd14a1 feat: add persona-scoped knowledge proposals`
- iOS：`07ff13b feat: consume persona-scoped knowledge proposals`
- 本状态文档及 Closure Ledger 由后续独立文档提交收敛。
- 两个功能提交均仅存在于本地分支；本轮未推送、未部署。

## 后续任务

1. 用户确认、拒绝、纠正和来源删除级联。
2. canonical `digitalHumanId` 历史数据迁移与家庭候选治理。
3. operation payload hash、change feed 分页/compaction 和 Postgres 并发生产化。
4. KBLite/base/pending 文件保护、Widget 摘要 allowlist 和登出日志/trace 清理。
