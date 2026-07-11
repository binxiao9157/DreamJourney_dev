# 实现 iOS 知识 snapshot 单次恢复

## Problem Definition

后端 change feed 历史压缩后会返回结构化 410；iOS 当前只会将其视为普通失败，没有 snapshot GET 和安全恢复路径，409 后从 revision 0 重拉也会反复失败。

## Proposed Solution

新增严格 `KnowledgeSnapshotResponse` 模型与客户端 GET；Coordinator 仅识别 `410 knowledgeChangeFeedCompacted`，在同一 user/generation/pull-session 下最多执行一次 snapshot fallback。恢复继续复用现有三方合并、CAS、base 原子落盘和 pending push；失败不改变本地基线。

## Acceptance Criteria

- snapshot user/revision/graph/updatedAt 严格解析。
- 仅结构化 compacted 410 触发一次 fallback。
- target 漂移、分页格式错误和普通网络错误不误触发。
- 用户切换/旧回调/fallback 失败不落盘。
- snapshot 成功后继续 push 本地变化。
- model/static smoke 与 iOS 非真机构建通过。

## Verification Plan

先扩展 Swift model smoke 和 coordinator static check，再实现模型、client 和 coordinator；运行知识 pagination gate、release static regression 与构建。

## Risks

- fallback 回调可能与用户切换或本地写并发，必须复用 generation/session/CAS。
- 旧后端 404/405 fallback 语义不能被改变。

## Assumptions

- 后端 410 detail.code 固定为 `knowledgeChangeFeedCompacted`。
- `/kb/snapshot/{user}` 返回当前完整权威 graph。
