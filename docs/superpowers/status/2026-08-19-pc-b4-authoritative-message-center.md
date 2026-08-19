# PC-B4 权威消息中心实现与验证

日期：2026-08-19
状态：`COMPLETE`
下一交接点：`PC-C1 首版图片/文档理解`

## 完成范围

- 后端以当前 Principal 为边界提供分页列表、未读数、单条已读、全部已读和删除已读合同。
- Candidate、正式记忆投影、导出、家庭邀请/贡献、授权撤销、账户安全、重试任务、关怀和系统通知进入普通消息中心。
- 时光信和延迟回复仍保持关闭，不被本次普通消息中心重新公开。
- iOS 增加 typed backend contract 和客户端方法，不使用本地兼容聚合作为公开权威来源。
- 记忆档案和回响增加系统铃铛；“我的”增加消息中心行，三个入口共用同一个未读状态源。
- 消息中心支持加载、空态、失败重试、分页、单条已读、全部已读和删除已读。
- 点击消息前重新校验账户 lease；账号切换、注销或 authority generation 变化时清空旧快照并丢弃旧回调。
- App 返回前台时由共享 Store 刷新；同账号刷新保留当前未读展示，避免铃铛短暂归零。

## 安全边界

- 后端消息只接受 `metadataOnly=true` 且 `requiresReauthorization=true` 的合同。
- timeLetter、echoReply 和未知 kind 在 typed parser 中失败关闭。
- 所有写命令使用 UUID commandId，并校验服务端回执中的 commandId 和幂等 outcome。
- 客户端不把消息摘要当作业务详情；路由后由目标页面重新鉴权和读取资源。
- QA 快照只在 `DEBUG` 或 `UI_QA_SIMULATOR` 编译条件存在，使用脱敏 fixture，不连接真实 Provider。

## 验证结果

- `bash Scripts/QA/product-v4/run-product-confirmed-message-center-gate.sh`：通过。
- `bash Scripts/QA/product-v4/run-message-notification-widget-account-lifecycle-gate.sh`：通过。
- `swift Scripts/QA/prd-stitch-ui/in-app-message-center-shell-check.swift <repo>`：通过。
- iOS Simulator Debug build，Bundle ID `com.yxj.dreamjourney.app`：通过。
- PC-B4 UIQA：标准字号、辅助功能大字号、iPhone 17e 紧凑机型均通过。
- Backend `fccbc28`：已部署，migration head `0100`，PostgreSQL Owner message smoke 通过。

## UIQA 证据

- `artifacts/product-confirmed/20260819-pc-b4-uiqa/message-center-standard.png`
- `artifacts/product-confirmed/20260819-pc-b4-uiqa/message-center-accessibility.png`
- `artifacts/product-confirmed/20260819-pc-b4-uiqa/message-center-compact.png`
- 同目录 `*-result.json` 记录 `messageCount=3`、`unreadCount=2`、`authority=backend` 和关闭 kind 排除结果。

## 剩余外部验收

- APNs 远程通知真正到达仍需开发者账户、有效 push 配置和真机证据。
- 该外部 Gate 不影响应用内消息中心闭环，也不应被误标为 APNs 已完成。
