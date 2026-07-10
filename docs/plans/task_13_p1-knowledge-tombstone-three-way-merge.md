# P1 知识删除 Tombstone 与三方合并

## 背景

Task 12 已完成按用户隔离、revision、幂等 mutation、change feed 和 Echo query-scoped RAG，但 v1 仍以完整图谱快照同步。本地与远端同时修改时只能整体 local-wins，无法区分“本地删除”“远端删除”和“双方修改同一实体”，存在删除被恢复或远端更新被覆盖的风险。

## 固定合同

`POST /kb/mutations` 保持 v1 `graph` 请求兼容，并新增 v2：

```json
{
  "userId": "user-id",
  "operationId": "stable-operation-id",
  "baseRevision": 12,
  "mutationSchemaVersion": 2,
  "upserts": {
    "people": [],
    "places": [],
    "events": [],
    "facts": []
  },
  "tombstones": [
    {
      "entityType": "facts",
      "entityId": "fact-id",
      "deletedAt": "2026-07-11T00:00:00Z"
    }
  ]
}
```

- 实体类型只允许 `people / places / events / facts`。
- upsert 必须有非空 `id` 且 scope 可同步；local-only/无授权元数据不能上传。
- tombstone 只删除服务端同类型同 ID 实体，不影响客户端 local-only 数据。
- v2 响应兼容增加权威 `graph` 和 `mutation` 摘要；change feed 每条变更兼容增加 `mutation`。
- v1 客户端、`/kb/sync` 和完整快照 change feed 保持可读。

## 范围

- InMemory/Postgres 原子应用 upsert/tombstone，保持 operationId 幂等和 baseRevision 409。
- Postgres `kb_changes` 增加 nullable mutation JSONB，不迁移或重写历史变更。
- iOS 为每个用户持久化 `lastSyncedBase`（权威远端图谱 + revision）。
- iOS 按实体 ID 执行 base/local/remote 三方合并：单侧变化直接采用；双方同改先确定性 local-wins，并写 QA conflict summary。
- iOS 根据 base 与 local 生成 v2 upserts/tombstones；local-only/旧无元数据实体只保留本地。
- 旧后端不支持 v2 时安全降级 v1 完整 mutation，不改变公开 UI。
- 新增后端 smoke、iOS 静态/模型 gate 和 release regression 可选组合门。

## 不在范围

- 公开冲突解决 UI。
- 字段级 CRDT、向量数据库或实时协同编辑。
- change feed 分页、长期保留和 compaction。
- 真机或产品视觉调整。

## 步骤

- [x] 实现并测试后端 v2 upsert/tombstone 与 change metadata。
- [x] 实现并测试 iOS per-user base snapshot、三方合并和 delta 生成。
- [x] 固化 local-only、删除、同实体双改、重复 operation 和 stale revision 行为。
- [x] 增加部署态 smoke 与 release regression 可选 gate。
- [x] 运行后端全量测试、iOS 构建、关键 smoke 和 `git diff --check`。
- [x] 更新状态/部署文档，分别提交两仓库；未明确要求前不推送或部署。

## 成功标准

- 本地删除同步为 tombstone，其他客户端拉取后不会恢复该实体。
- 远端删除不会删除本机 local-only/旧无授权实体。
- 双方只改一侧时不丢更新；双方同改时行为确定且可在 QA trace 识别。
- malformed change feed 不推进 revision，用户切换旧回调仍被隔离。
- v1 与旧服务端降级合同继续通过现有 release regression。

## 递归 Ledger

- `L20260711-005948`
