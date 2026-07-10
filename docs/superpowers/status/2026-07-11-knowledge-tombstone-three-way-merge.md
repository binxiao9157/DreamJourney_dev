# 知识 Tombstone 与三方合并实现状态

## 版本

- iOS 分支：`feature/prd-stitch-ui-adaptation`
- iOS 提交：`e63a5ed feat: add knowledge tombstone merge`
- 后端分支：`main`
- 后端提交：`3fc5b2d feat: add knowledge mutation tombstones`
- 后端 QA 提交：`816993b test: cover deployed knowledge tombstones`
- iOS 状态文档提交：`8a1a94c docs: close knowledge tombstone rollout`
- 递归任务：`L20260711-005948`

以上提交已经推送。后端 `816993b` 已部署，公网健康检查为 Postgres；部署态 knowledge V2/tombstone smoke 和跨仓库 release gate 已通过。

## 已实现

### 后端 Mutation V2

`POST /kb/mutations` 保留 v1 `graph`，并新增：

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

- 只接受四类知识实体；upsert 必须有 ID 和可同步隐私 scope。
- `localOnly`、缺失 metadata、未知类型、空 mutation 和无时区删除时间均被拒绝。
- InMemory/Postgres 在锁或事务中校验 revision，再执行 tombstone 和 upsert。
- 相同 operationId 跨 v1/v2 重放时返回首次持久化结果，不重复推进 revision。
- `kb_changes` 兼容增加 nullable mutation JSONB；历史 v1 记录保持可读。

### iOS 三方合并

- 每个用户在 Application Support 独立保存远端 base（revision + graph）与 pending mutation。
- 以 `base / local / remote` 按实体类型和 ID 合并：
  - 只有本地变化：保留本地。
  - 只有远端变化：采用远端。
  - 双方相同变化：直接采用。
  - 双方冲突：确定性 local-wins，并仅记录类型/ID 的 QA 摘要。
- 本地删除生成 tombstone；重试复用相同 operationId、baseRevision、deletedAt 和 payload。
- `localOnly` 或缺失授权 metadata 的实体不上传、不生成远端删除，也不会被远端缺失覆盖。
- 首次从 v1 升级时吸收远端独有实体并建立 base，不把历史远端数据误判为删除。
- 明确识别旧后端的 404/405、schema 不支持或 `graph required` 错误后才降级 v1；普通 v2 校验错误不会静默 fallback。

## QA Gate

本地模型：

```bash
cd /Users/yxj/Documents/Codex/Video/DreamJourney_dev
Scripts/QA/prd-stitch-ui/run-knowledge-three-way-merge-model-smoke.sh
swift Scripts/QA/prd-stitch-ui/knowledge-pipeline-check.swift .
```

跨仓库 release gate：

```bash
RUN_KNOWLEDGE_V2_SYNC_GATE=1 \
BACKEND_BASE_URL=https://your-backend.example.com \
BACKEND_API_TOKEN='***' \
Scripts/QA/prd-stitch-ui/run-release-regression.sh
```

该开关始终运行 iOS 三方模型，并强制开启部署态 knowledge smoke；默认值为 `0`，不会要求日常本地回归连接外部环境。

## 本轮验证

- 后端 195 项 unittest、FastAPI、v1 delta、v2 tombstone smoke 通过。
- 部署形态脚本对本地 FastAPI 实际走通登录、v1 seed、v2 upsert/tombstone、重复 operation、change feed、legacy no-op、Context 和 409。
- `RUN_KNOWLEDGE_V2_SYNC_GATE=1` 的跨仓库 release regression 通过；报告：
  `/Users/yxj/Documents/Codex/Video/DreamJourney_dev/tmp/visual-qa/prd-stitch-ui/release-regression/20260711-014817-release-regression/report.md`
- iOS generic Simulator 与 generic iPhoneOS Debug build 均通过，命令行覆盖为本机 `2BTR77V3R8 / com.yxj.dreamjourney.app`。
- XcodeBuildMCP 无法把当前 iOS 26.5 模拟器映射为具体 destination；改用 generic Simulator 编译成功。该问题属于工具 destination 限制，不是工程编译失败。

## 剩余边界

- 线上 Postgres v2/tombstone smoke 已运行并通过；最新证据报告为 `tmp/visual-qa/prd-stitch-ui/release-regression/20260711-020906-release-regression/report.md`。
- 冲突仍是实体级 local-wins，不是字段级 CRDT；暂无公开冲突处理 UI。
- change feed 分页、保留周期和 compaction 未在本轮实现。
- 本轮不涉及真机、视觉 UI 或向量数据库。
