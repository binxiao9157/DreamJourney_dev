# WI-S0-01-05 Archive/Media Owner Envelope 与 Legacy Quarantine

## 结论

本工作项将记忆档案元数据和本地媒体从全局/owner-only 路径迁移到 `subject + vault + archiveOwner` 隔离域。新写入不再使用 `legacy_unassigned`，来源不明、Owner 冲突、损坏或作用域不匹配的数据不得自动归给当前账号。

当前公开产品 UI 和 Stitch 视觉未改变；Legacy 恢复入口仍保持 hidden/QA，不把隔离数据暴露为正常档案。

## iOS 实现

### 档案元数据

- `ArchiveStorageScope` 由有效 `AccountLease` 和 `archiveOwnerId` 生成，不使用明文账号作为持久化 key。
- `ArchiveStoreEnvelope` 保存 `subject/vault/storeSchema/generation/legacyState/contentHash`。
- 读取、保存、远端合并、档案详情和异步回调均复核原始 lease 与当前 Persona Owner。
- `MemoryArchiveRepository.add` 仅在本地 envelope 持久化成功后才调度提醒和后端同步；失败会返回给 UI，媒体创建流程会清理本次新文件。
- 时间信件详情严格校验 `id + kind + owner`；跨 Owner 返回不得写入当前 Owner 的本地 envelope。

### 本地媒体

- 原始媒体写入 Application Support，缩略图写入 Caches。
- 文件名使用 UUID；metadata 保存相对路径、SHA-256、字节数和 scope digest。
- 解析时拒绝绝对路径、路径穿越、scope mismatch、大小变化、哈希变化和非普通文件。
- 每次读取重新验证当前 AccountLease 和已授权 Persona，权限撤销后旧 item 不能继续解析媒体。
- 单条删除、媒体替换和账号注销接入 scoped cleanup；普通退出登录不删除用户数据。

### Legacy 迁移

- `legacy_unassigned`、缺失 Owner、Owner 不匹配和损坏记录进入 quarantine，不自动认领或上传。
- 迁移使用 receipt 和 copy-on-write。当前账号自己的 legacy key 只迁移显式标记为本人 Owner 的记录；同 key 中 ownerless 记录仍进入 quarantine。
- 家庭/他人 Owner 的 legacy key 必须具备与 subject/vault/owner/locator/payload hash 一致的来源证据，才允许写入 V2 envelope。
- 来源账号不明确的 owner-only legacy key 不得由当前访问者删除。
- 旧绝对媒体路径只有位于允许的历史媒体目录、通过普通文件和内容校验后才可复制到 scoped store。

## 后端实现与部署

- `523a774 fix(WI-S0-01-05): enforce archive owner isolation`
- `32a081f test(WI-S0-01-05): honor principal-bound shadow rollout`
- 后端 `main`、`origin/main` 与生产部署均为 `32a081f`。
- `/archive/items` 的 Owner 由 authenticated principal 派生；payload 伪造 Owner 被拒绝。
- 同 ID 跨 Owner 写入不得转移所有权；冲突进入可审计 quarantine。
- 线上健康检查：`status=ok`、`store=postgres`。

## 验证证据

### 已通过

- Archive local storage model smoke。
- Archive media store model smoke。
- Archive storage/AccountLease/media capture 静态检查。
- Archive ownership visibility 和 scoped local path 检查。
- Archive media entries UIQA。
- Archive -> Echo media context UIQA：`availableItemCount=3`，语音转写、待分析视频说明和已封存时间信件进入上下文；草稿、绝对路径和无效分析线索未进入。
- iOS workspace generic simulator build。
- 后端单测、FastAPI smoke、真实 Postgres owner conflict/migration smoke。
- `git diff --check`。

Archive -> Echo UIQA 证据：

- `tmp/visual-qa/prd-stitch-ui/archive-media-entries-smoke/20260718-111333/archive-media-entries-smoke-result.json`
- `tmp/visual-qa/prd-stitch-ui/archive-media-entries-smoke/20260718-111333/01-archive-media-entries.png`
- `tmp/visual-qa/prd-stitch-ui/archive-media-echo-context-smoke/20260718-111408/archive-media-echo-context-smoke-result.json`
- `tmp/visual-qa/prd-stitch-ui/archive-media-echo-context-smoke/20260718-111408/01-archive-media-echo-context.png`

## 保留边界

- Legacy 显式 claim 的最终用户恢复交互尚未公开；当前策略是 fail closed，不影响正常新档案。
- 单条媒体删除失败目前只记录日志，尚未建立可持久化的 cleanup retry queue；此项进入统一 retention/lifecycle 工作，不作为已完成能力声明。
- `Documents/photos` 和临时 `TGSessionRecordings` 属于 Home/Conversation 旧路径，明确留给 `WI-S0-01-06`，不因 ArchiveMediaStore 完成而宣称全局媒体目录已退役。
- 后端删除后的 archive ID 目前没有永久 tombstone；未来可被另一个 Owner 重新使用，但现存记录不能跨 Owner 接管。
- G4 真机照片/录音/视频验收和外部 DR-035 安全复核仍保持开放，不能由模拟器结果替代。
- 本文只证明 `WI-S0-01-05` 的内部实现与 G0/G1/G2 证据，不宣称整个 V4 Stage 0 完成。
