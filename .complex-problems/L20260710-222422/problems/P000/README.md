# P0 全路由 Ownership 审计与 Principal 绑定

## Problem

Close the Lodestar task represented by `/Users/yxj/Documents/Codex/Video/DreamJourney_dev/docs/plans/task_11_p0-full-route-ownership-audit.md` using recursive problem, ticket, result, and check state.

Task context:

# P0 全路由 Ownership 审计与 Principal 绑定

## 背景

Task 9/10 已部署到线上 `66db803`，Postgres auth session 和跨账号 shadow smoke 已通过。当前后端仍依赖通用 ownership claim fallback 观察多数用户资源路由；全局 `AUTH_OWNERSHIP_MODE` 必须继续保持 `shadow`，但已验证的用户私有资源不应继续允许 bearer principal 访问其他用户数据。同时 iOS 仍会主动调用全局时间信件 `dispatch-due`，而服务器定时器已经启用。

## 范围

- 为全部 FastAPI 业务路由建立显式 ownership 分类注册表。
- 分类至少包括：public auth、authenticated service、user-session、owner body、owner path、delegated、system-only。
- 自动检查新增路由未分类时失败，防止审计清单漂移。
- 对明确 owner-bound/system-only 路由绑定已验证 bearer principal；legacy system token 继续兼容。
- 合法家庭关怀、时间信件收件人和邀请接收继续复用 Task 10 delegated policy。
- 删除 iOS 对全局时间信件 `dispatch-due` 的主动触发，只拉当前用户 mailbox。
- 保持全局 ownership mode 为 `shadow`，不宣称 production enforce ready。
- 增加后端单测、HTTP smoke、Swift 静态 guard、release gate、审计报告和部署验证。

## 不在范围

- SMS identity proof 或公开注册策略。
- 将 `AUTH_OWNERSHIP_MODE` 改为 `enforce`。
- 修改公开 UI、Stitch 视觉或真机流程。
- 重新设计家庭关系解除、管理员角色或多租户 RBAC。
- 允许客户端触发全局调度任务。

## 步骤

- [ ] 生成完整业务路由清单并先补“所有路由必须分类”的失败测试。
- [ ] 实现 route ownership registry 和 owner/system principal-bound 决策。
- [ ] 补高风险读写路由的错误 principal 403 集成测试。
- [ ] 移除 iOS 全局 `dispatch-due` 调用，保留 mailbox 拉取。
- [ ] 增加审计报告、HTTP smoke、release regression 可选 gate和状态文档。
- [ ] 完成后端/iOS 全量验证、提交推送、重新部署和线上 Postgres smoke。
- [ ] 关闭递归 ledger，记录 SMS 与全局 enforce 后续边界。

## 成功标准

- 所有业务路由均有唯一、显式 ownership 分类；新增未分类路由使测试失败。
- user bearer 不能读写其他用户的 profile、archive、mailbox、voice、KB、memory、session、push、echo 或 family owner 资源。
- user bearer 不能调用 purge、mailbox create、echo/time-letter dispatch 等 system-only 路由。
- system backend token 与本地无 token 开发模式保持兼容。
- delegated family/time-letter/invitation 路由继续通过。
- iOS 刷新提醒只读取 mailbox，不再触发全局 dispatch。
- runtime 和 QA 报告继续明确 `ownershipMode=shadow`、`productionEnforceReady=false`。
- 后端全量测试、线上 Postgres smoke、release QA、simulator/generic iPhoneOS build 和两仓库 `git diff --check` 通过。

## 递归 Ledger

- Ledger ID：待初始化。
- 状态：进行中。



## Success Criteria

- 所有业务路由均有唯一、显式 ownership 分类；新增未分类路由使测试失败。
- user bearer 不能读写其他用户的 profile、archive、mailbox、voice、KB、memory、session、push、echo 或 family owner 资源。
- user bearer 不能调用 purge、mailbox create、echo/time-letter dispatch 等 system-only 路由。
- system backend token 与本地无 token 开发模式保持兼容。
- delegated family/time-letter/invitation 路由继续通过。
- iOS 刷新提醒只读取 mailbox，不再触发全局 dispatch。
- runtime 和 QA 报告继续明确 `ownershipMode=shadow`、`productionEnforceReady=false`。
- 后端全量测试、线上 Postgres smoke、release QA、simulator/generic iPhoneOS build 和两仓库 `git diff --check` 通过。
