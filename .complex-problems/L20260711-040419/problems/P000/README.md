# Task 16：P1 知识治理与来源删除级联

## Problem

Close the Lodestar task represented by `/Users/yxj/Documents/Codex/Video/DreamJourney_dev/docs/plans/task_16_p1-knowledge-governance-source-cascade.md` using recursive problem, ticket, result, and check state.

Task context:

# Task 16：P1 知识治理与来源删除级联

## 目标

在不改变公开 Stitch UI、不做真机验证的前提下，把知识候选的用户确认、拒绝、纠正和来源删除做成显式、可审计、revision-bound 的后端权威动作，并让 iOS 能安全消费权威结果。任何治理动作都不得静默覆盖历史来源，也不得让已拒绝、已取代或来源已删除的知识继续进入 Echo。

## 产品边界

- 本轮完成治理数据层、后端合同、iOS consumer 和 QA；不提前决定公开审阅入口的位置与视觉。
- `confirm`：保留实体 ID 和原始来源，标记为用户确认。
- `reject`：保留实体及来源审计信息，标记为拒绝，不进入生成。
- `correct`：原实体标记为 `superseded`，创建新的 `confirmed` 实体并记录取代关系；禁止原地改写历史正文。
- `deleteSource`：匹配该来源的全部实体移除对应 source ref，并统一标记为 `superseded`；不物理删除审计历史。
- 所有动作只允许知识 owner 发起，受现有 bearer principal、base revision 和 operation ID 约束。
- family 知识沿用 canonical `digitalHumanId`，不得通过治理动作跨 persona 修改。

## 后端合同

新增 additive endpoint：

```text
POST /kb/governance/actions
```

请求包含：

```json
{
  "governanceSchemaVersion": 1,
  "userId": "owner-id",
  "operationId": "ios-governance-uuid",
  "baseRevision": 12,
  "action": {
    "kind": "confirm | reject | correct | deleteSource",
    "entityType": "facts",
    "entityId": "kb_fact_...",
    "correction": {},
    "sourceRef": {"kind": "memoryArchiveItem", "id": "archive-id"},
    "decidedAt": "ISO-8601"
  }
}
```

响应返回权威 graph/revision、Mutation V2 upserts 和不含知识正文的 governance summary。`correct` 的 replacement ID 由 owner、目标实体、operation ID 稳定生成。

## 实施范围

- [ ] 固定治理 action schema、合法状态转换、纠正字段 allowlist 和来源级联语义。
- [ ] 实现后端 governance builder、endpoint、owner 路由分类和 memory/Postgres 兼容。
- [ ] 覆盖 confirm/reject/correct/deleteSource、幂等、revision conflict、非法 persona/target/source 负向测试。
- [ ] iOS 增加治理 action/response/metadata 模型和 backend client。
- [ ] iOS 同步协调器串行提交治理动作、应用权威 snapshot，并防止用户/角色切换后的旧回调写入。
- [ ] Echo/Context 验证 rejected/superseded 继续被过滤，纠正实体可进入目标 persona Context。
- [ ] 增加跨仓库 smoke、release regression 可选 gate、设计/状态文档和 Ledger 证据。
- [ ] 运行后端全量验证、iOS 模型检查、Simulator/iPhoneOS generic build、`git diff --check`，分别提交两仓库。

## 不在范围

- 公开知识管理页面、确认弹窗或 Stitch 视觉改版。
- 自动恢复被删除来源的知识。
- 物理清除审计历史、change feed compaction、全局 operation payload hash。
- 真机、线上部署和 provider 质量验证。

## 成功标准

- 四类治理动作都由后端 snapshot 生成 Mutation V2，不由客户端拼接任意权威实体。
- correction 保留旧实体并创建 replacement；旧实体不再进入 Echo。
- 删除来源后，所有直接引用该 source ref 的实体均不可用于生成。
- owner、persona、revision、operation ID 和 timestamp 均被验证；跨账号请求被拒绝。
- iOS 能解析并应用权威 graph，旧用户/旧 persona 回调不可污染当前图谱。
- 旧 `/kb/mutations`、proposal、三方合并、evidence/Context 合同继续通过。
- 非真机 release regression 和通用 iPhoneOS 构建通过。



## Success Criteria

- 四类治理动作都由后端 snapshot 生成 Mutation V2，不由客户端拼接任意权威实体。
- correction 保留旧实体并创建 replacement；旧实体不再进入 Echo。
- 删除来源后，所有直接引用该 source ref 的实体均不可用于生成。
- owner、persona、revision、operation ID 和 timestamp 均被验证；跨账号请求被拒绝。
- iOS 能解析并应用权威 graph，旧用户/旧 persona 回调不可污染当前图谱。
- 旧 `/kb/mutations`、proposal、三方合并、evidence/Context 合同继续通过。
- 非真机 release regression 和通用 iPhoneOS 构建通过。
