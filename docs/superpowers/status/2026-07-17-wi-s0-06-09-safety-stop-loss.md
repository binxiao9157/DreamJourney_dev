# WI-S0-06-09 即时安全止损

日期：2026-07-17
Work Item：`WI-S0-06-09`
状态：`IMPLEMENTED / BACKEND_DEPLOYED / G0_G2_VERIFIED / G1_G4_OPEN`
Execution owner：`codex-goal:019ece6b-2c15-7521-b160-c42e95d1dd5a`
Authority lock：`RELEASE_POLICY`

## 目标

- 持续披露 AI/非真人身份。
- 在危机表达进入 Persona、档案上下文、延迟回信、声音复刻或数字人 Provider 前切换为中性安全模式。
- 对不合格的 Voice/数字人主体请求执行服务端 hard deny。
- 保持 M1-M4 未验收能力默认关闭，未知或离线状态不放行。

## 已实现合同

- 后端新增类型化安全策略，统一危机分类、中性回复、主体资格和 effect deny 合同。
- `/context/build` 在读取档案、知识库、Persona 和 Provider 状态前执行安全判断；危机包不包含原始表达、记忆、Persona 权限、Voice 或数字人状态。
- 延迟回信只接收请求期 `rawTranscript`，危机表达不持久化并返回 `409`。
- Voice/数字人 effect 要求主体资格证据；缺失或不合格时 hard deny。
- ReleasePolicy 对 M1-M4 effect 路由默认执行关闭边界，不因全局 observe 绕过。
- iOS Echo 在上下文构建和 Provider effect 前执行同构安全判断，取消延迟回信、语音、数字人输出并展示固定中性回复。
- iOS 角色提示持续声明 AI/非真人身份；危机路径不改变公开页面布局。
- ReleasePolicy 刷新失败时，iOS 清除缓存权限和捕获路由，禁止使用过期能力继续执行 effect。

## 版本与部署

- 后端提交：`9693dc7 feat(WI-S0-06-09): enforce immediate safety boundaries`。
- iOS 实现提交：`de4cff4 feat(WI-S0-06-09): enforce neutral safety mode`。
- 后端已推送、部署；服务器与 `origin/main` 均为 `9693dc7`。
- iOS 提交仅保留在 `feature/prd-stitch-ui-adaptation` 本地分支，未自动推送。

## 验证

- 后端全量测试：412 项通过。
- 后端 safety/release focused tests 与 Python compile 通过。
- 本地 uvicorn safety deployed smoke 通过。
- 线上 `/health`：`production/postgres`；`/ready` 的 database、schema、auth 均为 ready。
- 线上 `Backend WI-S0-06-09 deployed safety smoke passed`。
- iOS safety model smoke、静态 integration check、延迟回信合同、ReleasePolicy cache/captured-feature checks 全部通过。
- iOS unsigned generic Simulator Debug build：`BUILD SUCCEEDED`。
- `git diff --check` 通过。

## 边界与 Gate

- 本 Work Item 的代码合同和已部署后端证据关闭 scoped G0/G2，不代表 M1/M2 已获准公开。
- G1 的隐私/法律复核和 G4 的产品、监管及真实主体资格决策仍保持外部门状态。
- M1-M4 继续默认关闭；未提供合格主体证据时不得启动声音复刻或数字人 effect。
- 证据中不保存真实凭据值、用户正文或危机原文。

## 续接点

Authority lease 转交 `IDENTITY_AUTHZ`，下一 Work Item 为 `WI-S0-02-01`：建立 challenge/verify、随机 Subject 与 Identity Binding 的最小闭环。access/refresh token family 的原子轮换和撤销由后续 `WI-S0-02-02` 承接。
