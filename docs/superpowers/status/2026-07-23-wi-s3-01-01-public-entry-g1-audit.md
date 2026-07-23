# WI-S3-01-01 发布/访客公开入口 G1 非准入审计

日期：2026-07-23
Work Item：`WI-S3-01-01`
Authority：`PUBLICATION`
范围：仅审计并固化当前 Release 的默认拒绝边界；不创建发布、访客、分享或公开索引能力。

## 已验证的当前边界

- Release 根导航仅挂载“记忆档案 / 回响 / 我的”三个 Tab，不挂载地图、知识库同步、家庭空间、发布或访客入口。
- Release smoke 对仅写入本地 profile 的冷启动停留在认证入口；私有主界面必须经过真实已验证的后端会话。
- `NotificationRuntimeRouteKind` 只允许回信、时间信件、家庭邀请、关怀和系统通知；通知/深链只选择中性 Tab，不直接打开资源。
- 历史 `MapFootprintViewController.guest` 和 `MemoryDetailViewController.guest` 仅由地图内部旧分支使用。当前档案页创建地图时固定为 `.host`。
- `MemoryRepository.getPublicByOwner` 只是本地 `isPrivate == false` 过滤，当前唯一业务调用点是历史地图 guest 分支；它不是 `PublicationVersion`、`ShareGrant` 或 `VisitorSession`。
- 旧 KBLite 本地分享包仅在 `UI_QA_SIMULATOR && targetEnvironment(simulator)` 下可用；正式构建固定关闭，知识库 UI 不展示“家族同步”。
- 后端没有 Publication、Visitor、Share、Guest 或 Public Index 内容路由；匿名 allowlist 只包含健康、认证、运行时配置和默认拒绝的 release-policy 元数据。

## 可重复 Gate

```bash
Scripts/QA/prd-stitch-ui/run-publication-visitor-public-entry-g1-check.sh
```

该 Gate 已接入 `run-public-release-scope-regression.sh`，因此公开发布范围回归会自动执行它。

Gate 会阻止以下回归：

- 在 Release Tab 或通知/深链类型中重新引入 `guest/public/share/visitor/publication` 入口。
- 在地图旧分支以外复用 `getPublicByOwner`。
- 在正式构建打开 KBLite 本地分享包或新增未经 Gate 的 `KBSyncViewController` 入口。

## 结论与未完成项

本证据只能说明当前系统不存在可达的公开发布/访客入口，即 `G1` 的**非准入审计**成立。它不代表 S3 的真实 G1/G4 已完成，也不能改变 Registry 中 `WI-S3-01-01` 的 `STOP` 状态。

真实 Publication/Visitor 仍必须在后续独立切片中实现并验收：不可变 `PublicationVersion`、独立 `ShareGrant`、成年 Visitor 会话、撤回/审计/离线拒绝、法务与隐私 Gate。不得复用 `isPrivate=false`、家庭关系或 KBLite 导出作为这些能力的授权依据。
