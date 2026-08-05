# P2-S4B：发布撤回的 iOS QA 失效闭环

日期：2026-08-06  
范围：P2-S4B，仅限 default-off 的 M2 closed-beta QA 路径。

## 已完成

1. 后端 owner publication 摘要新增 `lifecycleAuthorityEpoch`。该字段只用于撤回命令的乐观并发校验，不是账号凭据，也不包含访客、Provider 或私有记忆内容。
2. iOS 新增三重 QA 门：发布管理、Visitor 读取、生命周期命令必须同时携带各自的 Debug/UI-QA launch argument；Release 编译始终关闭。
3. QA 壳层只允许 owner 对 `confirmed + active` 的公开预览发起“撤回公开预览”。命令和重试 ID 只保存在页内内存，不写本地缓存。
4. 撤回成功后，页面重新读取发布和 grant 状态，明确显示“发布已撤回、预览已撤回、授权已撤回、剩余 0 次”，并保留诚实的回执说明：访问阻断已完成，公开索引清理待处理。
5. Visitor 读取遇到后端的 `publicationVisitorAccessUnavailable` 或 `publicationVisitorAccessDenied` 时，清除内存中的 scope、projection 和 session，向调用者返回“访问已撤销”，不保留旧公开副本。
6. 新增可重复模拟器 smoke 和静态 gate；默认公开 MVP 回归不自动执行该 QA-only 场景。

## 后端部署

- 后端已推送并部署：`main@909fe73`。
- `ac7ab7a` 提供 owner 摘要的 `lifecycleAuthorityEpoch`；`909fe73` 将该字段加入 disposable Postgres lifecycle smoke。
- API `/ready` 返回 `ready`；schema `expectedHead=0082`、`appliedHead=0082`、`pendingVersions=[]`。
- 服务器历史 `.env.backup*` 文件未读取、修改或删除。

## 验证证据

| 检查 | 结果 |
| --- | --- |
| 后端定向单测：publication management / lifecycle API / migration contract / propagation | 20 项通过 |
| 后端部署态 disposable Postgres lifecycle smoke | 通过：撤回、授权与 Visitor session 撤销、异议冻结、幂等回执、authority epoch 都已断言 |
| iOS 定向 XCTest：`PublicationManagementAccessTests` + `PublicationVisitorAccessTests` | 11 项通过 |
| `swift Scripts/QA/product-v4/publication-lifecycle-ios-scope-gate-check.swift .` | 通过 |
| `bash Scripts/QA/prd-stitch-ui/run-publication-lifecycle-m2-smoke.sh` | 通过 |
| `git diff --check` | 通过 |

模拟器截图：

`tmp/visual-qa/prd-stitch-ui/publication-lifecycle-m2-smoke/20260806-publication-lifecycle-m2-grant-revoked/01-publication-lifecycle-m2.png`

## 发布边界与未完成项

- 本轮不新增公开发布入口、第四 Tab、公开 URL 或深链；没有三重 QA 参数时撤回控件不存在。
- 这不是“外部删除已完成”：Public Index、缓存、腾讯数字人 session、Voice/对象存储等外部 effect 仍是 `pending/notApplicable` 的真实回执状态。
- 下一小项为 P2-S4C：把已持久化的撤回/争议回执接入异步传播 worker，逐域追踪外部清理的 `pending / partial / completed / unsupported`，并保持先拒绝访问、后执行 effect 的顺序。
