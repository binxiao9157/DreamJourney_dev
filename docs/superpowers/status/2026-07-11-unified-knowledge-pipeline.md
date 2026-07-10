# 统一知识库主链路实现状态

## 版本基线

- iOS 仓库：`DreamJourney_dev`
- iOS 分支：`feature/prd-stitch-ui-adaptation`
- iOS 实施前基线：`024bcae`
- 后端仓库：`DreamJourneyBackend`
- 后端分支：`main`
- 后端实施前基线：`275a4c2`
- 递归任务：`L20260710-231102-12`

后端提交 `00df327 feat: add revisioned knowledge context pipeline` 已于 2026-07-11 部署到服务器。公网健康检查返回 `store=postgres`，线上 iOS 已具备使用新 revision/change-feed/generationContext 合同的后端条件。

## 已完成架构

### 1. 用户隔离与本地知识图谱

- KBLite 内存图谱显式绑定 `loadedUserId`，登录、登出和进程内切换用户都会重载对应文件。
- 登出态使用独立空图谱，不持久化，也不会沿用上一用户数据。
- 旧 `kb_graph.json` 只迁移一次，避免复制给后续登录用户。
- 用户切换使用 generation 防护，旧用户仍在返回的知识提取结果会被丢弃。
- 同步 generation 会在切换内存图谱前同步失效；change feed 应用时再次校验 `loadedUserId`，旧用户回调不能写入新用户文件。
- 新提取实体带 `privacyMetadata` 和来源引用；旧数据缺少授权元数据时默认不进入后端生成上下文。

### 2. 后端优先知识提取

- 正常联网提取统一调用 `POST /kb/extract`。
- iOS 不再从 KBLite 主链路直接调用客户端 DeepSeek key。
- 后端未配置、请求失败或频率控制时，使用明确的本地轻量规则降级。
- 提取完成、登录切换和 App 回到前台都会触发同步协调器。

### 3. Revision、幂等 mutation 与 change feed

新增后端合同：

- `POST /kb/mutations`
  - 输入：`userId`、`operationId`、`baseRevision`、`graph`
  - 同一 `operationId` 重试不会重复写入。
  - revision 冲突返回 `409 knowledgeRevisionConflict`。
- `GET /kb/changes/{userId}?sinceRevision=N`
  - 返回当前 revision 和 N 之后的变更。
- `GET /kb/snapshot/{userId}`
  - 兼容增加 `revision`、`updatedAt`。
- `POST /kb/sync`
  - 继续保留并兼容增加 `revision`、`applied`、`compatibilityNoOp`。
  - 首次旧客户端同步可建立 revision 1；已有 revision 后，无 `baseRevision` 的旧请求返回安全 no-op，不覆盖较新的图谱。
  - 新客户端可传 `baseRevision`、`operationId`，冲突仍返回 409。

Postgres knowledge mutation 使用请求独占连接、用户级 advisory transaction lock、snapshot row lock 和唯一 operation ID，避免并发请求共享事务或生成重复 revision；异常会在该请求连接内 rollback，完成后关闭连接。iOS 保存 revision、graph fingerprint 和 pending operation ID；响应丢失后会复用同一 operation ID。

兼容策略：

- 新 mutation/change-feed 返回 404 或 405 时，iOS 自动回退旧 `/kb/sync`。
- 409 时先全量拉取 change feed，合并后只重试一次。
- change feed 只应用最新完整快照，解析或用户校验失败时不会推进本地 revision。
- 本机没有未同步修改时，最新远端快照只对可同步实体为权威值；`localOnly` 和旧版无授权元数据实体始终留在本机。本机有修改时按实体 ID 保留本机值并吸收远端新增项，再基于新 revision 提交。
- 当前 v1 mutation 仍传完整图谱快照，change feed 是 revision 化快照流，不是实体级 patch。

### 4. Context Packet 生成合同

`POST /context/build` 在现有 Context V2 结构上兼容新增：

```json
{
  "generationContext": {
    "version": "echo-generation-context-v1",
    "text": "...",
    "sourceRefs": [],
    "sourceCounts": {},
    "contentHash": "sha256:...",
    "maxChars": 12000,
    "truncated": false
  }
}
```

生成文本只来自最终通过 policy/ranking 的：

- 档案条目
- KBLite facts
- persona signals
- care summary

以下内容不会进入生成文本：

- 图像分析失败且没有有效线索的空内容
- 时间信件草稿
- 未到 `openAt` 且收件人无权查看的时间信件
- 邀请中、失败或无有效家庭关系的数据
- 未授权 privacy scope
- voice profile 和 digital-human runtime 状态

文本限制为 12,000 字符，重复请求的文本与哈希稳定，空上下文也有固定合同。

### 5. Context Packet 驱动真实 Echo

- Echo 最终 ASR 后按当前 query 调用 `/context/build`。
- 正常路径将 `generationContext.text` 通过火山 SDK `SEDirectiveEventChatRagText` 提交给当前 turn。
- 每轮只允许成功提交一次；0.9 秒未返回时，使用 `KBLiteManager.buildGenerationAllowedContextString(query: 当前文本)` 本地降级。
- 本地降级会同时校验当前登录用户与 KBLite owner，只包含显式 `privacyMetadata.scope=generationAllowed` 的实体和关联事实；旧版无元数据、local-only 或其他 scope 不会发送给生成 provider。
- SDK 未激活或拒绝 `ChatRagText` 时不会提前消费 turn gate，最多进行两次短重试；后端迟到结果仍可在 gate 有效时接管。
- 后端失败、未配置或旧服务器缺少 generationContext 时同样降级。
- lifecycle token、user ID、turn ID 和最新请求标识共同阻止旧回调污染新角色/新用户/新一轮。
- 延迟回信 turn 继续记录 Context trace，但不触发即时生成 RAG。
- Echo 使用 turn-scoped 模式后，生产 Dialog 启动 prompt 不再重复注入旧的无 query KBLite 摘要和档案摘要。
- 非 Echo 调用默认维持旧启动行为，不受影响。

## 隐私与权限边界

- `/kb/mutations`、`/kb/changes/{userId}` 已加入 route ownership registry，业务路由总数由 54 增至 56。
- iOS 只有当前 bearer session 的 user ID 与 KBLite owner 一致时才同步。
- Context Packet 继续使用现有 owner/family/time-letter policy；客户端不重新实现权限判断。
- 日志只记录来源数量、hash、trace ID、revision 和 fallback 原因，不打印知识正文或密钥。

## 验证入口

后端：

```bash
cd /Users/yxj/Documents/Codex/Video/DreamJourneyBackend
scripts/verify_backend.sh
scripts/run-backend-knowledge-delta-smoke.sh
scripts/run-echo-context-builder-v2-smoke.sh
BACKEND_BASE_URL=https://dreamjourney-api.liftora.cn \
BACKEND_API_TOKEN='***' \
scripts/run-backend-knowledge-deployed-smoke.sh
```

iOS 静态与 release gate：

```bash
cd /Users/yxj/Documents/Codex/Video/DreamJourney_dev
swift Scripts/QA/prd-stitch-ui/knowledge-pipeline-check.swift .
swift Scripts/QA/prd-stitch-ui/context-packet-v1-check.swift .
Scripts/QA/prd-stitch-ui/run-release-regression.sh
```

本轮已验证：

- 后端 188 项 unittest 通过，新增覆盖 Postgres mutation 独占连接、rollback/close，以及旧 `/kb/sync` 防覆盖合同。
- FastAPI smoke、knowledge delta smoke、Context V2 smoke 通过。
- 部署态 knowledge smoke 已在本地等价 FastAPI 环境通过，包含 legacy sync no-op 防覆盖断言。
- 部署态 knowledge smoke 已在 `https://dreamjourney-api.liftora.cn` 的真实 Postgres 环境通过：revision、幂等 mutation、change feed、generation hash、409 和 legacy sync no-op 均验证成功。
- generic iOS Simulator Debug build 通过。
- generic iPhoneOS Debug build 通过，Bundle ID 使用本机 `com.yxj.dreamjourney.app` 覆盖。

## 尚未完成的后续边界

### P0 真机 Echo 语义验收

- 真机确认火山 Dialog 在线服务在当前 query 窗口消费 `ChatRagText`，并用 Echo trace 对照回答是否引用预期线索。

### P1 冲突与删除语义

- 当前远端合并已按实体 ID 处理字段更新；本地 dirty 时采用本机值优先并吸收远端新增项，尚未提供用户可见的字段级冲突选择。
- clean client 可接受可同步实体的远端删除，同时保留 local-only 数据；本地与远端同时存在变更时，删除语义仍需实体 tombstone/三方基线才能无歧义合并。
- 当前 change feed 为完整图谱快照，尚未实现实体级 upsert/delete tombstone。
- `kb_changes` 需要后续分页、保留期限和 compaction 策略。

### P1 Postgres 全局连接治理

- 本轮已将 knowledge mutation 改为请求独占连接，解决本合同的并发事务问题。
- 旧 Store 的其他读写方法仍使用历史缓存连接；后续应独立评估连接池/每请求 lease，不能在本轮知识改造中无测试地全局重写。

### P1 检索质量

- 当前不引入独立向量数据库，后端 ranking 仍以现有 Context V2 候选规则为主。
- 后续数据规模和召回质量达到阈值后，再评估 pgvector、rerank 和摘要压缩；不应现在无依据引入新基础设施。

### P2 用户可见治理

- 尚无公开的知识来源审阅、纠错、删除和冲突处理 UI。
- 在 PRD 明确公开范围前，继续只通过 QA trace/evidence 审计，不新增公开入口。
