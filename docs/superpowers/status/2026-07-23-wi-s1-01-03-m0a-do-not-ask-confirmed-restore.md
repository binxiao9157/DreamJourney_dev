# WI-S1-01-03 M0A-28：禁问后的显式确认恢复

日期：2026-07-23
后端基线：`main@58ec52f`
iOS 基线：`feature/prd-stitch-ui-adaptation@2b24ec7`（本地提交，默认不推送）

## 问题与范围

终版 M0-A 访谈合同要求：用户主动重新提起已选择“不再问”的话题时，必须先获得恢复确认。
此前 `doNotAsk` 会把会话稳定地停在 `paused`，但没有受约束的恢复通道。

本轮只完成最小、可审计的恢复合同：

- 单独的 `restore-do-not-ask` 命令和路由，而不是向通用边界接口开放 `boundary=open`。
- 仅 Vault Owner、已捕获的 `echoTextInput` 发布策略和既有默认关闭条件下可调用。
- 只有当前状态恰为 `paused + doNotAsk` 才能恢复为 `active + open`；`cooldown`、`skipOnce`、结束或已变化的会话均拒绝。
- 请求必须携带字面 `confirmed=true`，并以 command ID 保证重放幂等。
- iOS 只在 Debug/UI_QA 的访谈边界面板显示“重新聊这个话题”；先显示确认弹窗，Release 不创建该控件，也不改变公开 Echo。

## 明确不包含

本轮**没有**实现自然语言主题归一、历史主题匹配或自动识别“用户重新提起的是哪一个禁问话题”。
正式产品入口要满足这一点，需要后续先定义受审计的 topic identity / classifier 合同；在该合同存在前，不能以模糊文本匹配自动解除 `doNotAsk`。

`cooldown` 的时长、到期行为和可配置策略也未在当前产品决策中定义，本轮未臆造该语义。

## 实现

后端新增受 owner-scoped 路由保护的：

`POST /v2/vaults/{vault_id}/interview-sessions/{session_id}/restore-do-not-ask`

其 in-memory 与 Postgres 仓储均在 session 版本围栏内完成 `paused/doNotAsk -> active/open`，并写入独立命令类型的 receipt。Postgres 更新带状态、边界和 row-version 条件，避免并发请求覆盖已变化的会话。

iOS 使用单独的 `OwnerTruthInterviewRestoreDoNotAskCommand` 和 AccountLease/generation 围栏；QA UI 只在 `doNotAsk` 回执存在时显示恢复动作，并在确认后检查返回回执为 `active/open`。

## 验证

本地已通过：

1. 后端回归：输入 API、pacing state、session orchestration、orchestration、route ownership 与 `0038` 迁移合同，共 38 项通过。
2. `py_compile`、部署 smoke 脚本 `bash -n` 和两仓 `git diff --check` 通过。
3. iOS 静态 QA：`owner-truth-interview-boundary-qa-surface-check.py` 通过，确认没有通用 `open` 写入，且确认弹窗和 typed 命令存在。
4. 模拟器 `run-owner-truth-interview-boundary-smoke.sh` 通过；结果含 `doNotAskRestoreCompleted=true`。

模拟器截图：

`tmp/visual-qa/product-v4/owner-truth-interview-boundary-smoke/20260723-030454/01-owner-truth-interview-boundary.png`

部署：

1. 后端已推送 `bc3f055` 与迁移修复 `58ec52f`，服务器 API 镜像已重建。
2. `scripts/migrate_db.py --apply --build-id 58ec52f` 仅应用 `0038`；后续 `--verify` 的 `appliedHead` 与 `expectedHead` 均为 `0038`。
3. `/ready` 返回 `status=ready`，数据库、schema、auth、incident 均为 ready。
4. 部署容器内 `scripts/run-backend-owner-truth-interview-natural-input-deployed-smoke.sh` 已通过，确认未确认恢复拒绝、`cooldown` 恢复拒绝、确认恢复和同 command ID 重放均正确；输出 `productionBusinessDataMutated=false`。

## Gate 结论

- 本轮为 `WI-S1-01-03` 的 scoped G0/G1/G2 增量证据，后端 `main@58ec52f` 已部署。
- M0-A 仍默认关闭；未开放公开 Echo UI，未启动 Provider、Candidate、Memory 或生产 Authority 切流。
- “自然语言重新提起禁问话题”的识别仍是未完成的后续产品/合同工作，不能因此标记 Slice 3B 全部完成。
