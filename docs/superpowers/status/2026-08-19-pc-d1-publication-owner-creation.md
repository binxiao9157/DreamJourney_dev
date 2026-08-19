# PC-D1 Publication Owner 创建、撤回与版本审计子闭环状态

日期：2026-08-19
状态：`COMPLETE_WITH_EXTERNAL_GATES`
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

## 当时未完成边界（本轮已关闭代码项）

初始交接时 PC-D1 尚有以下两项：

1. ShareGrant 创建、查看和撤销管理：已由后文记录的 `9a6d85b / 0464e31a` 关闭。
2. 发布与 Visitor 的法律、安全、数据地域和真实流量审批：继续作为外部 Gate 保留，不计为代码闭环完成。

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

继续 PC-D1 的 ShareGrant 创建、查看和撤销管理，不修改已对齐的三 Tab 或全屏 Echo 视觉。

## 版本审计子闭环补充

Backend `9092957` 与 iOS `29464d7d` 已完成 Owner PublicationVersion 审计：

1. 新增 ordinary/internal Owner-only `GET .../publications/{publicationId}/versions`，按版本号倒序返回不可变公开快照。
2. 返回内容仅含公开标题、公开正文、AI 披露、快照 hash、确认时间和 Projection 状态；不含 private memory/source、Grant 凭据或 Visitor 身份。
3. Postgres 查询同时校验 vault、owner subject 和 authority epoch；跨 Owner 请求失败关闭。
4. iOS 使用 schema-checked typed model、AccountLease request/commit fence 和普通发布管理入口，不持久化版本审计结果，也不将其注入 Echo。
5. UIQA 自动点击“查看版本记录”，并验证当前版本及公开快照实际渲染。

验证：

- 后端 38 项 Publication/route-auth 定向测试通过，部署态路由清单为 234。
- 部署态临时 PostgreSQL smoke 通过 Owner 版本审计、跨 Owner 隔离、Visitor CAS、撤权和 Projection block。
- iOS 11 项 Publication 定向 XCTest、publication shell static gate 和 `git diff --check` 通过。
- UIQA：`tmp/visual-qa/product-v4/publication-version-audit/uiqa/20260819-pc-d1-version-audit/`。
- generic iPhoneOS build：`tmp/visual-qa/product-v4/publication-version-audit/iphoneos-generic-build/20260819-pc-d1-version-audit/report.md`。
- production readiness、schema head `0102`、路由认证和服务重建验证通过。

## 不可变版本修订子闭环补充

Backend `3c9b9a3`、部署热修 `6272bb6`、路由清单提交 `459a5dd` 与 iOS `bae9e9a4` 已完成普通 Owner 版本修订：

1. Owner 只能基于当前唯一 active PublicationVersion 创建修订 Draft；请求携带预期版本 ID/版本号和公开副本文字，不携带 private MemoryVersion/Source 标识。
2. 服务端从不可变基线版本解析固定 item 集合和顺序，重新验证当前 Owner、Authority Epoch、MemoryVersion current 状态、内容 hash 和第三方复核边界。
3. 二次确认在同一事务内生成递增版本，将旧 Projection 标为 `superseded`，再建立唯一的新 `active` Projection；旧版本内容保持不可变和可审计。
4. 并发或陈旧修订失败关闭；同一确认命令在对应版本被后续替代后仍返回原始幂等回执。
5. iOS 复用已有公开副本编辑、预览和二次确认流程，锁定 item 顺序，并继续使用 AccountLease request/commit fence 阻断账户切换后的旧响应。

验证：

- 后端 96 项 Publication、route-auth、runtime 和 Session 定向测试通过。
- 部署态临时 PostgreSQL smoke 验证 version 1 -> version 2、旧版本保留、唯一 active Projection、陈旧 Draft 拒绝和旧确认幂等重放。
- iOS 12 项 Publication 定向 XCTest与静态 scope gate 通过。
- UIQA 通过：`tmp/visual-qa/product-v4/publication-revision/uiqa/20260819-pc-d1-publication-revision/`。
- 关键截图：`tmp/visual-qa/product-v4/publication-revision/uiqa/20260819-pc-d1-publication-revision/01-publication-management-m2.png`。
- generic iPhoneOS build 通过：`tmp/visual-qa/product-v4/publication-revision/iphoneos-generic-build/20260819-pc-d1-publication-revision/report.md`；Bundle ID 为 `com.yxj.dreamjourney.app`，Team 为 `2BTR77V3R8`。
- Backend `459a5dd` 已部署，schema head 为 `0103`，线上 `/ready`、236 条路由认证、迁移前 `0102` 与迁移后 `0103` 验证备份均通过。
- 部署时同步重建既有异步 Worker，消除了旧镜像因数据库 head 已到 `0102` 而报 `migrationHeadAhead` 的重启状态；部署后相关 Worker 均为 running。

## ShareGrant Owner 管理闭环补充

Backend `9a6d85b`、migration `0104` 与 iOS `0464e31a` 已关闭普通 Owner 的注册账户授权管理代码闭环：

1. 正式请求仅接受已注册账户的手机号或 `user_` 账户 ID，不开放匿名链接，也不接受客户端指定内部调用限额或接收人主体 ID。
2. 服务端解析并验证接收账户，拒绝未知、已删除、已停用和本人账户；数据库只保存接收人主体 hash 与脱敏展示标签，不保存原始手机号或账户 ID。
3. Grant 绑定 Publication、不可变 PublicationVersion、接收人、有效期和撤销状态；撤销后已有 VisitorSession 立即失效。
4. iOS 提供创建邀请、脱敏授权列表和二次确认撤销；产品界面不显示内部安全调用余量，签发凭证只在当次响应内生成临时深链并用于系统分享。
5. AccountLease 在请求和提交边界均校验，账户切换后的旧授权响应不会进入当前 UI。

验证：

- 后端 154 项 Publication 测试、19 项路由认证测试与 Python compileall 通过。
- iOS 12 项 Publication XCTest与静态 scope gate 通过。
- UIQA：`tmp/visual-qa/prd-stitch-ui/publication-management-m2-smoke/20260819-214129/`，邀请、授权列表、撤销和修订入口均实际渲染。
- generic iPhoneOS build：`tmp/visual-qa/prd-stitch-ui/iphoneos-generic-build/20260819-pc-d1-share-grant/report.md`，Bundle ID `com.yxj.dreamjourney.app`，Team `2BTR77V3R8`。
- Backend `9a6d85b` 已部署，schema head 为 `0104`；线上 `/ready`、部署态 readiness、临时 PostgreSQL Publication/ShareGrant/Visitor smoke 和 236 条路由认证均通过，迁移前后备份成功。

## 当前交接点

PC-D1 代码闭环完成，外部发布审批仍保持默认关闭。下一项为 PC-D2：让受邀注册账户通过正式入口建立 VisitorSession、读取 PublicProjection、执行文字/实时语音查询，并在撤权、过期、暂停或跨 Vault 时立即失败关闭。
