# PC-D1 Publication Owner 创建子闭环状态

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

1. 普通 Owner 撤回前二次确认、撤回回执和失败重试。
2. PublicationVersion 版本审计和从既有版本创建新 Draft/Version 的修改链路。
3. ShareGrant 创建、查看和撤销管理。
4. 发布与 Visitor 的法律、安全、数据地域和真实流量审批。

“暂停”当前后端语义用于冲突阻断，不等同于可恢复的产品暂停；在恢复合同明确前不向普通用户暴露可逆暂停操作。

## 下一交接点

继续 PC-D1 的普通 Owner 撤回确认闭环。复用现有 lifecycle typed client 和服务端 ordinary route，不启用 QA-only transport，不修改已对齐的三 Tab 或全屏 Echo 视觉。
