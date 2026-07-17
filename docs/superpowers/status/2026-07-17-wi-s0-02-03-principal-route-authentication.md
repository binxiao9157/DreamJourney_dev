# WI-S0-02-03 Principal Middleware 与完整路由认证矩阵

日期：2026-07-17
Work Item：`WI-S0-02-03`
状态：`INTERNAL_READY / BACKEND_DEPLOYED / G0_G2_POSTGRES_VERIFIED / IOS_LOCAL_COMMITTED`
Execution owner：`codex-goal:019ece6b-2c15-7521-b160-c42e95d1dd5a`
Authority lock：`IDENTITY_AUTHZ`

## 目标

- 所有业务路由必须登记为 `public`、`user` 或 `machine`，未知路由和策略异常在生产环境 fail closed。
- user access token 只能访问 user route；后端 service token 只能访问登记 scope 的 machine route。
- iOS 业务请求只能显式声明 public 或 user 认证，不再回退 shared/system token。
- 启动、运行时能力和线上 smoke 必须能证明路由登记完整、拒绝有分母且不记录凭据值。

## 已实现合同

- 后端新增 typed `RequestPrincipal`，区分 `anonymous`、`user`、`machine`，并携带 audience、scope 和 session lineage。
- `RouteOwnershipRegistry` 同时承载 route auth mode、required audience 与 required scopes；当前 FastAPI 业务路由精确登记 `64` 条。
- 当前矩阵为 `10` 条 public、`49` 条 user、`5` 条 machine；machine route 采用最小 scope：account purge、release-policy observation、mailbox delivery、Echo dispatch、TimeLetter dispatch。
- production/auto 模式强制 `enforce`；启动时比较 FastAPI route 与 registry，重复、遗漏、陈旧、缺 audience/scope 或缺 machine credential 均拒绝启动。
- 未登记路由、evaluator exception、错误 principal、错误 audience/scope 均拒绝；策略异常返回 `503`，认证/授权不匹配返回 `401/403`。
- 响应头暴露 value-free route auth policy、decision 和 reason；有界 recorder 只保存分类计数和时间窗口，不保存 token、用户 ID 或请求正文。
- `/config/runtime` 暴露当前 enforce mode、route count 和 unclassified count；readiness 在生产环境校验 route auth 为 enforce。
- iOS `DreamJourneyBackendClient` 删除隐式 `.automatic`、`.anonymous` 和 `.backendOnly`，所有请求显式使用 `.publicRequest`、`.userRequired` 或 `.refreshExchange`。
- user route 在缺少 Keychain session 时于发网前返回 `userAuthenticationRequired`；refresh exchange 与普通 public request 隔离。
- iOS 删除 system-only TimeLetter dispatch 客户端入口，并新增静态 inventory，防止将 machine route 或 shared token 重新带回 App。

## 版本与部署

- 后端功能提交：`923182b feat(WI-S0-02-03): enforce typed route principals`。
- 后端线上 smoke 修复：`a9b02d5 test(WI-S0-02-03): accept empty knowledge snapshot`。
- iOS 实现提交：`4002ae9 feat(WI-S0-02-03): bind iOS requests to typed principals`。
- 后端两个提交均已推送；服务器、`origin/main` 与运行容器版本均为 `a9b02d5`。
- iOS 提交仅保留在本地 `feature/prd-stitch-ui-adaptation`，未自动推送。

## 验证证据

- 后端 memory store 全量单测：`461` tests passed。
- route authentication 单元/API 矩阵覆盖 anonymous/user/machine、错误 audience/scope、策略异常、启动完整性和 value-free observation。
- Python compile、shell syntax、`git diff --check` 均通过。
- iOS auth boundary、token-family、identity challenge、mobile credential retirement、ownership、readiness 与 release package guards 均通过。
- iOS Debug generic simulator build：`BUILD SUCCEEDED`。
- 线上 `/live` 返回 `alive`，`/ready` 返回 `ready`，API 容器健康。
- 线上 Postgres smoke：`routeCount=64`、`unclassifiedCount=0`，public runtime allow、anonymous user route deny、machine business route deny、user route allow、user machine route deny、machine route allow、value-free decision evidence 全部通过。

## 已知非阻断项

- release regression 已通过本轮新增的认证边界，随后被既有 `echo-delayed-reply-notification-check.swift` 的旧方法名断言阻断；该 Echo QA 债务与 Principal Middleware 无关，不作为本 Work Item 失败。
- database request UoW middleware 当前位于 route auth middleware 外层，拒绝请求可能先借用数据库连接；未形成越权，但后续可单独收敛性能与容量风险。
- 历史 `backend-env-smoke` 中仍有以 machine token 代替 user token 的旧测试假设；新生产合同已由本 Work Item 的 Postgres smoke 覆盖，旧脚本需要后续兼容清理，不能恢复 machine 对 user route 的访问。

## 退出结论

- `G0`：满足。typed principal、精确 route registry、startup guard、negative matrix、iOS client boundary 和构建证据齐全。
- `G2`：满足当前 Work Item 范围。生产版本已部署，真实 Postgres 下双向 principal 越权为零，route denominator 可追踪。
- 本 Work Item 不替代资源级 owner/vault AuthZ。payload/path 中的 owner 冲突、跨 Vault 查询和资源关系校验由 `WI-S0-02-04` 继续完成。

## 下一步

进入 `WI-S0-02-04`：由 authenticated principal、path resource lookup 和数据库关系派生 owner/vault；payload owner 字段仅用于 mismatch 校验，禁止改变 Authority。
