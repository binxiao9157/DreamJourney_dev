# Canonical Knowledge Source Identity 交付状态

## 本轮完成

- 对话文字新知识使用 `conversationTurn + session-{sessionId}:turn-{turnIndex}`。
- 对话内照片新知识使用 `conversationPhoto + photo-{stableAssetId}`，source ID 不包含本地绝对路径。
- 记忆档案馆来源继续使用 `memoryArchiveItem + archiveItem.id`。
- 后端 `/kb/extract` 只信任服务端校验后的 session/turn 证据，不接受客户端伪造 source refs。
- `/kb/source-ref-audit/{userId}` 只返回 revision、聚合计数和建议动作，不返回 graph、实体正文、source ID 或 title。
- iOS 接入严格 typed audit consumer；用户不匹配、计数不一致或未知 schema 会拒绝解析。
- 新增跨仓 gate，并默认接入 release regression。

## 历史边界

- `conversationSession` 和 `archiveImageAnalysis` 仍可读取，但标记为 legacy。
- 旧 `archiveImageAnalysis + session-*` 来源来自 `AIRecordingViewController` 的对话照片，不是 Archive item。
- 本轮不自动迁移、不删除历史来源，也不提供 apply migration API。
- 后续迁移必须能证明具体来源资产并单独获得产品/数据迁移批准。

## 验证入口

```bash
cd /Users/yxj/Documents/Codex/Video/DreamJourney_dev
BACKEND_ROOT=/Users/yxj/Documents/Codex/Video/DreamJourneyBackend \
  Scripts/QA/prd-stitch-ui/run-knowledge-source-identity-gate.sh
```

后端完整验证：

```bash
cd /Users/yxj/Documents/Codex/Video/DreamJourneyBackend
BACKEND_API_TOKEN= BACKEND_BASE_URL= ./scripts/verify_backend.sh
```

## 发布约束

- 不新增公开知识库页面，不改变 Stitch UI。
- 不把 request-level source refs 当作权威证据。
- 不将对话照片误归类为 `memoryArchiveItem`。
- 本轮非真机验收；线上只运行认证、只读、聚合审计 smoke。

## 提交与线上验收

- 后端功能提交：`f62e5a9 feat: canonicalize knowledge source identity`。
- 部署 smoke 修正：`20b8ce1`、`dd88f17`；服务器当前运行 `dd88f17`。
- 部署环境：`https://dreamjourney-api.liftora.cn`，health 为 `environment=production`、`store=postgres`。
- 线上只读 audit smoke：`schemaVersion=1`、`revision=1`、`canonicalSourceRefCount=1`、`recommendedAction=none`。
- 权限与隐私证据：`crossAccountDenied=true`、`aggregateOnly=true`、token 和用户标识均未输出。
- 服务器私密 `.env` 未被修改，历史 source refs 未迁移。
