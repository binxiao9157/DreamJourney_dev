# 知识治理与档案来源删除级联完成状态

日期：2026-07-11

## 结论

Task 16 已完成非真机代码闭环。当前工程具备后端权威知识治理、Archive 来源删除级联、iOS 强类型 consumer、跨重启 outbox、同步 generation gate 和可选跨仓库 release gate。公开产品 UI 未增加知识治理入口，现有 Stitch 页面不受影响。

## 产品语义

| 动作 | 权威结果 | Echo/Context 行为 |
| --- | --- | --- |
| `confirm` | 保留实体 ID、来源和正文，标记 `confirmed` | 满足权限与 privacy 后可进入 |
| `reject` | 保留审计历史，标记 `rejected` | 必须过滤 |
| `correct` | 原实体 `superseded`；创建稳定 ID 的 `confirmed` replacement | 只使用 replacement |
| `deleteSource` | 精确移除 `(kind,id)` source ref；直接引用实体 `superseded` | 原实体必须过滤 |

治理动作只允许 owner 发起，继续受 bearer principal、`baseRevision`、`operationId`、timestamp 和 canonical persona identity 约束。客户端不能自行构造权威实体。

## 后端实现

- 新增 `POST /kb/governance/actions`，固定 `governanceSchemaVersion=1`。
- `knowledge_governance.py` 负责 typed action、纠正 allowlist、稳定 replacement ID、legacy personal identity 升级和不含正文的 summary。
- Archive ID 不允许跨 owner 接管。
- `DELETE /archive/items/{userId}/{itemId}` 使用 `memoryArchiveItem + itemId` 触发来源级联。
- memory/Postgres 均通过 `delete_archive_item_with_kb_mutation` 在同一事务中完成知识 mutation、change feed 和档案删除。
- sealed 时间信件仍不可删除；无知识来源命中时只删除档案，不增加知识 revision。
- route ownership 业务路由总数更新为 57，治理 endpoint 归类为 `knowledgeOwner`。

## iOS 实现

- `KBLiteModels.swift` 增加治理 action/correction/source/summary/response/metadata 强类型模型。
- people/places/events/facts 均可往返保存 optional `governanceMetadata`。
- `DreamJourneyBackendClient.governKnowledge` 严格编码 schema v1 并校验响应 user/operation identity。
- `KnowledgeGovernanceOutboxStore` 按用户原子保存多项动作，支持去重、删除、损坏拒绝和跨重启恢复。
- `KnowledgeSyncCoordinator.performGovernance` 与普通 graph sync 共用单一 `isSyncing` owner。
- revision conflict 保留相同 operation ID，先刷新基线再重试；payload conflict 首次旋转 operation ID，二次冲突进入 quarantine；同 persona 成功后先应用权威 graph/base，再移除 outbox。
- user/persona 已变化时旧回调不直接写当前图谱，改走 change feed 收敛。

## QA 与运行方式

后端确定性 gate：

```bash
cd /Users/yxj/Documents/Codex/Video/DreamJourneyBackend
scripts/run-backend-knowledge-governance-source-cascade-smoke.sh
```

跨仓库 release gate：

```bash
cd /Users/yxj/Documents/Codex/Video/DreamJourney_dev
RUN_KNOWLEDGE_GOVERNANCE_GATE=1 \
RUN_SIMULATOR_SMOKE=0 \
RUN_ECHO_DELAYED_REPLY_NOTIFICATION_SMOKE=0 \
Scripts/QA/prd-stitch-ui/run-release-regression.sh
```

日常 release regression 默认执行治理 model/client/coordinator 和公开 UI boundary 轻量 guard；只有显式开关才运行后端 217-test 组合 gate。

验证结果：

- 后端治理组合：217 tests 通过。
- 后端全量 deterministic：243 tests 通过。
- iOS governance/outbox/merge/context smoke：通过。
- Simulator Debug workspace build：通过。
- generic iPhoneOS 无签名 build：通过。
- 证据：`tmp/visual-qa/prd-stitch-ui/release-regression/20260711-task16-knowledge-governance-v4/`。

## 发布边界与剩余工作

- 没有公开知识管理页面、确认弹窗或第四个 Tab。
- 后续公开治理体验必须先更新 PRD 和 Stitch，不得直接把 service API 暴露到现有页面。
- 新来源 canonical identity 为 `memoryArchiveItem + archiveItem.id`。
- 历史 `archiveImageAnalysis + session-*` 来源不会被新删除级联自动命中，需独立迁移和回归证据。
- 本轮未做真实 Postgres deployed smoke、线上部署、真机验证或 provider 质量验收。
- operation receipt/payload hash 已由 Task 17 完成；真实 Postgres 部署迁移、change feed 分页/compaction、物理审计清理仍是后续生产化任务。
