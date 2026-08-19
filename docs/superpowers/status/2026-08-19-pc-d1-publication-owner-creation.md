# PC-D1 Publication Owner 创建与撤回子闭环状态

日期：2026-08-19
状态：`INTERNAL_READY`
Work Item：`PC-D1`

## 本轮完成

1. Backend `5153db2` 支持有序 `memoryVersionIds/items`、item 公开标题/正文、快照 hash 和披露字段。
2. migration `0102` 已部署，服务器运行版本为 `5153db2`。
3. iOS `f40d13c2` 增加 Publication Draft/Confirm typed client，并用 AccountLease 阻断账户切换后的旧响应。
4. iOS `7b2620a4` 增加普通 Owner 创建入口：正式记忆多选、顺序编辑、公开正文编辑、隐私与 AI 披露、预览和二次确认。
5. 第三方复核未完成时确认失败关闭，不把敏感或未确认内容直接发布。

## 验证证据

- 后端定向合同、PostgreSQL publication smoke、`/ready` 和 232 条路由认证通过。
- iOS `PublicationDraftAccessTests`、`PublicationManagementAccessTests`、`PublicationLifecycleAccessTests` 通过。
- publication default-off shell gate 和 `git diff --check` 通过。
- generic iPhoneOS build 通过：`tmp/visual-qa/prd-stitch-ui/iphoneos-generic-build/20260819-pc-d1-owner-publication-ui/report.md`。
- 模拟器 UIQA 通过：`tmp/visual-qa/product-v4/owner-truth-formal-memory-smoke/20260819-pc-d1-publication-flow/`。
- 关键截图：`03-publication-composer.png`、`04-publication-preview.png`。

## 未完成边界

PC-D1 不能标记为完整完成，剩余任务按顺序为：

1. PublicationVersion 版本审计和从既有版本创建新 Draft/Version 的修改链路。
2. ShareGrant 创建、查看和撤销管理。
3. 发布与 Visitor 的法律、安全、数据地域和真实流量审批。

“暂停”当前后端语义用于冲突阻断，不等同于可恢复的产品暂停；在恢复合同明确前不向普通用户暴露可逆暂停操作。

## 撤回子闭环补充

iOS `fb8f615d` 已把现有 lifecycle 合同从 QA-only 展示推进到普通 Owner 发布管理：

1. 仅当服务端策略允许、Publication 为 `confirmed/active` 且具备 authority epoch 时显示撤回入口。
2. 执行前展示破坏性二次确认，说明受邀访问立即停止、公开索引继续清理以及外部副本无法收回。
3. 弹窗持有发起时的 AccountLease；账户切换后的旧确认在 request/commit 边界失败关闭。
4. 继续复用幂等 command ID、撤回回执、Grant 撤销状态和失败重试，不引入第二套 lifecycle 实现。
5. QA transport 和三 launch-argument smoke 继续保留，但普通产品流量使用 ordinary route。

验证：

- `PublicationManagementAccessTests` 与 `PublicationLifecycleAccessTests` 共 8 项通过。
- publication default-off shell gate 与 lifecycle scope gate 通过。
- UIQA 完整验证确认框、撤回、Grant 撤销和回执：`tmp/visual-qa/product-v4/publication-owner-withdrawal/uiqa/20260819-pc-d1-owner-withdrawal/`。
- generic iPhoneOS build 通过：`tmp/visual-qa/product-v4/publication-owner-withdrawal/iphoneos-generic-build/20260819-pc-d1-owner-withdrawal/report.md`。

## 下一交接点

继续 PC-D1 的 PublicationVersion 版本审计和基于既有发布创建新 Draft/Version。不得原地修改不可变版本；ShareGrant 管理在该子闭环后推进，不修改已对齐的三 Tab 或全屏 Echo 视觉。
