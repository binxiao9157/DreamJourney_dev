# P1 知识 Mutation Proposal 与 Persona 归属

## Problem

Close the Lodestar task represented by `/Users/yxj/Documents/Codex/Video/DreamJourney_dev/docs/plans/task_15_p1-knowledge-mutation-proposal-persona-schema.md` using recursive problem, ticket, result, and check state.

Task context:

# P1 知识 Mutation Proposal 与 Persona 归属

## 背景

Task 12-14 已完成 revisioned knowledge pipeline、Mutation V2、tombstone、证据门禁和 Echo Context 隔离，但 `/kb/extract` 仍只返回 provider 形态的 `extraction`，iOS 继续使用随机 UUID 和本地名称匹配合并。重复提取可能产生不同 ID，关系字段尚未解析为实体 ID，也没有稳定持久化 `ownerUserId/personaScope/digitalHumanId/evidenceStatus`。

Canonical 设计：`docs/superpowers/plans/2026-07-11-product-knowledge-base-architecture-v2.md`。

## 固定合同

- `/kb/extract` v2 在保留 `extraction` 的同时 additive 返回 `mutationProposal`；提取接口本身不写库。
- proposal 由服务端基于权威 KB snapshot 构建，不信任客户端 `existingSummary` 作为去重依据。
- 实体自然键使用 Unicode NFKC、小写、空白折叠规范化；命中当前 snapshot 时复用已有 ID，否则生成 owner/persona/entity-type/natural-key 绑定的稳定 SHA-256 ID。
- proposal 固定包含 `proposalSchemaVersion=1`、`mutationSchemaVersion=2`、`baseRevision`、`ownerUserId`、`personaScope`、`digitalHumanId`、`upserts`、`tombstones=[]` 和无正文策略摘要。
- 所有 upsert 继承经过服务端净化的 `privacyMetadata/sourceRefs`，记录 `sourceSessionIds/sourceTurnIndices`，并写入 `evidenceStatus`。
- high/confirmed 提取事实为 `observed`；medium/low 为 `candidate`，候选仍不得进入 Echo generation context。
- `relatedPeople/participants/location/relatedEvents` 先在 snapshot 与本次 proposal 内解析为稳定实体 ID；解析不到时不伪造关联。
- iOS 优先消费 `mutationProposal`；旧服务端只有 `extraction` 时保留现有兼容合并。
- 合并回调必须绑定请求发起时的 user/persona/digital-human identity；用户或角色已切换时丢弃旧结果。
- 旧实体缺少 persona metadata 时仅作为 personal/self 兼容数据；family persona 只允许读取显式匹配的 family + digitalHumanId 实体。

## 范围

- 后端 proposal builder、稳定 ID、snapshot 去重、关系解析、来源/隐私/persona 继承和单元/API 测试。
- 后端 Context 对 persona-scoped KB facts 的筛选与 family 显式匹配读取。
- iOS proposal 响应模型、persona 元数据兼容字段、proposal 优先合并和旧 extraction 降级。
- iOS 会话结束时捕获 canonical persona identity，防止异步角色切换串写。
- 静态检查、后端 smoke、release regression、generic Simulator/iPhoneOS 构建。
- 分别提交 iOS/后端；未明确要求前不推送或部署。

## 不在范围

- 自动把知识人物提升为家庭授权成员。
- 用户确认/拒绝/纠正公开 UI 和来源删除级联。
- change feed pagination/compaction、payload hash、向量数据库。
- 真机、真实 provider 质量或公开 UI 验收。

## 步骤

- [ ] 固定 proposal/persona 合同并建立回归样例。
- [ ] 实现后端 proposal builder、稳定 ID、去重、关系和 metadata。
- [ ] 实现 Context persona fact policy 与负向回归。
- [ ] 实现 iOS proposal 解析、identity-bound 合并和旧合同兼容。
- [ ] 接入跨仓库 QA gate，运行非真机构建和回归。
- [ ] 更新状态文档、关闭 ledger、分别提交两仓库。

## 成功标准

- 相同 owner/persona/自然键重复提取产生相同 ID；已有 legacy UUID 会被复用。
- proposal 不直接写库，且可直接作为 Mutation V2 upserts 使用。
- 所有 proposal 实体可回答 owner、persona、来源、证据状态和隐私范围。
- 人物/地点/事件/事实关联只指向当前 snapshot 或本次 proposal 的有效 ID。
- 角色或用户切换后的旧异步结果不会写入当前知识库。
- personal 旧数据兼容；family Context 只消费目标 digitalHumanId 的显式 family facts。
- Task 12-14 的 revision/tombstone/evidence/Context 回归不退化。
- 后端全量验证、iOS release regression、generic Simulator/iPhoneOS 构建和 `git diff --check` 通过。



## Success Criteria

- 相同 owner/persona/自然键重复提取产生相同 ID；已有 legacy UUID 会被复用。
- proposal 不直接写库，且可直接作为 Mutation V2 upserts 使用。
- 所有 proposal 实体可回答 owner、persona、来源、证据状态和隐私范围。
- 人物/地点/事件/事实关联只指向当前 snapshot 或本次 proposal 的有效 ID。
- 角色或用户切换后的旧异步结果不会写入当前知识库。
- personal 旧数据兼容；family Context 只消费目标 digitalHumanId 的显式 family facts。
- Task 12-14 的 revision/tombstone/evidence/Context 回归不退化。
- 后端全量验证、iOS release regression、generic Simulator/iPhoneOS 构建和 `git diff --check` 通过。
