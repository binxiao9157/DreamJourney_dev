# PC-C2 正式记忆 Markdown 导出完成记录

日期：2026-08-19  
状态：`COMPLETE`

## 交付范围

- 后端新增 `formalMemoryMarkdown` ExportJob、Owner/Vault 权限边界、取消/重试、一次性下载凭据和 `0101` migration。
- Renderer 只读取 current 且带 DecisionReceipt 的正式 MemoryVersion，输出正文、类型、版本、时间和已确认 facets。
- Markdown 固定为 `text/markdown; charset=utf-8`、确定性 `.md` 文件名和 SHA-256 完整性合同。
- Source、Candidate、历史正文、媒体字节、凭据和内部审计不进入导出文件。
- iOS “我的”页面新增服务端策略管理的“导出正式记忆”入口；完整账户数据导出入口继续关闭。
- iOS 支持任务恢复、轮询、取消、重试、下载、Markdown 预览、系统分享、完整文件保护，以及分享、退出登录和账户生命周期清理。

## 版本与部署

| 工程 | 提交/状态 |
|---|---|
| Backend | `a3051d3` 功能实现；`99bece9`、`6e21f30` 部署态 smoke 修正 |
| iOS | `cc1b3174` |
| production-postgres | Backend `6e21f30`，migration head `0101`，`/ready=status=ready` |

## 验证证据

- 后端定向合同：122 tests passed。
- iOS 定向 XCTest：2 tests passed。
- `Scripts/QA/prd-stitch-ui/run-formal-memory-markdown-export-check.sh`：passed。
- arm64 iOS Simulator Debug build：`BUILD SUCCEEDED`。
- `git diff --check`：Backend 与 iOS 均通过。
- 部署态 `backend-data-export-jobs-postgres-smoke.py`：验证 current-only、Owner 隔离、正文/facets、Source/历史排除、hash 和取消，passed。
- 部署态 `backend-route-authentication-postgres-smoke.py`：232 routes、0 unclassified，passed。

全量后端 `unittest discover` 本轮未作为完成 Gate：其单进程运行会触发既有共享 PostgreSQL pool 已关闭的非隔离干扰。本项使用隔离定向套件、真实 migration 和部署态 disposable PostgreSQL smoke 关闭，不宣称全量 discover 通过。

## 产品边界

- 客户端不提供完整账户 ZIP/全量数据导出。
- 运维脱敏全量导出所需协议、审批和审计系统继续 `DEFERRED`，本项没有复用旧 ZIP Job 冒充完成。
- 本轮未修改 Stitch 三 Tab、全屏 Echo 或其他已对齐视觉；新入口沿用“我的”列表设计语言。

## 下一交接

进入 `PC-D1 Publication Owner App 闭环`：先盘点现有 Publication Draft/Version/PublicProjection 代码与 QA 壳层，再补普通 Owner 从正式记忆多选、公开正文编辑、预览、二次确认、版本管理到撤回的真实入口。
