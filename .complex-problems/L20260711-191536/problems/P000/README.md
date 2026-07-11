# Task 24：P1 知识变更历史保留与快照恢复

## Problem

Close the Lodestar task represented by `/Users/yxj/Documents/Codex/Video/DreamJourney_dev/docs/plans/task_24_p1-knowledge-change-retention-snapshot-fallback.md` using recursive problem, ticket, result, and check state.

Task context:

# Task 24：P1 知识变更历史保留与快照恢复

## 目标

让知识同步在长期运行、历史变更压缩和分页期间压缩的情况下仍可恢复，避免客户端因 revision gap 永久停止同步，同时不改变公开 UI。

## 范围

### 后端

- 新增每用户 `minimumSinceRevision` 持久化水位。
- `/kb/changes/{user_id}` 在请求水位早于保留边界时返回明确的 `410 knowledgeChangeFeedCompacted`。
- 保持现有 200 legacy/paginated 成功合同兼容。
- 提供默认 dry-run 的 Postgres 压缩维护脚本；显式 apply 才删除历史。
- 压缩只处理 change feed，不删除 operation receipts。
- snapshot、保留水位和分页读取必须在同一用户锁/事务视图中完成。

### iOS

- 增加严格的知识 snapshot 响应模型和 GET 客户端。
- 只对明确的 change-feed compacted 错误执行一次 snapshot fallback。
- fallback 仍受 user、generation、pull session 和现有 CAS/三方合并保护。
- snapshot 成功后继续推送本地待同步变化；失败时不推进 base/pending。

### QA 与交付

- 后端覆盖保留边界、410、dry-run/apply、幂等和回滚。
- iOS model smoke 覆盖 snapshot 解析和单次 fallback 决策。
- 更新知识部署文档和 release gate。
- 运行后端测试、iOS 静态/模型检查、`git diff --check`、模拟器与 generic iPhoneOS 构建。
- 后端提交推送并部署后运行线上 Postgres smoke；不做真机验证。

## 合同

当 `sinceRevision < minimumSinceRevision`：

```json
{
  "detail": {
    "code": "knowledgeChangeFeedCompacted",
    "message": "requested revision is no longer retained",
    "userId": "user-id",
    "sinceRevision": 10,
    "minimumSinceRevision": 80,
    "currentRevision": 120,
    "snapshotRevision": 120
  }
}
```

HTTP 状态为 `410`。客户端随后调用既有 `GET /kb/snapshot/{user_id}` 获取权威 graph。

## 保留策略

- 默认 dry-run。
- 保留“最近 N 个 revision”与“最近 D 天”中更宽的集合。
- apply 时按用户获得知识写锁，删除与水位推进同事务提交。
- 不自动压缩 receipts；其 TTL/清理策略另立任务。

## 非目标

- 不改变 Echo 公开 UI。
- 不做知识正文导出或后台管理 UI。
- 不做 operation receipt TTL。
- 不做真机验证。

## 完成标准

- 历史压缩不再产生服务端 500 或 iOS 永久 revision gap。
- iOS 可从权威 snapshot 恢复并保留本地未同步修改。
- dry-run 不写库；apply 可重复执行且不会倒退水位。
- 本地与线上 Postgres 验收通过，文档、脚本、提交和部署证据完整。


## Success Criteria

- Recursive ledger reaches next_action=none.
- Relevant implementation and verification evidence is recorded.
- A compact status checkpoint is synced back to Lodestar progress.md.
