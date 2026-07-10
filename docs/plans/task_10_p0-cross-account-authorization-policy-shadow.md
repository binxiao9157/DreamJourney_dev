# P0 跨账号授权策略与 Shadow 证据

## 背景

Task 9 已完成 opaque access/refresh session 和基础 ownership shadow，但当前中间件仍把所有跨账号 `userId` 视为简单 mismatch。家庭关怀、时间信件收件人和邀请接受本身需要合法跨账号访问；如果直接开启全局 enforce，会误拦这些业务，同时现有 `requesterPhone` / `viewerUserId` 仍可能被客户端伪造。

## 范围

- 建立统一、可测试的跨账号授权策略评估器。
- 覆盖 owner、已接受家庭成员、时间信件有效收件人、家庭邀请接收人和 system-only 调度路由。
- 将登录 principal 与 `viewerUserId`、家庭成员手机号映射、邀请手机号绑定。
- 对关怀快照、时间信件详情和邀请接受执行敏感路由 principal 绑定；即使全局仍为 shadow，也不向伪造 viewer 返回敏感内容。
- 在响应头输出不含 PII 的 policy / decision / reason 证据。
- 默认继续运行 `shadow`；已知合法委托访问标记为 `delegated`，已知越权标记为 `mismatch`。
- `enforce` 测试模式按策略允许合法家庭访问并拒绝伪造 viewer、非成员和用户调用 system-only 路由。
- 增加后端单测、真实 HTTP smoke、iOS/release QA 静态 gate 和状态文档。

## 不在范围

- 将生产环境切换为 `AUTH_OWNERSHIP_MODE=enforce`。
- 短信验证码、手机号所有权证明或公开注册策略。
- 改动家庭、时间信件、消息中心或关怀的公开 UI。
- APNs、真机或弱网验收。
- 一次性覆盖所有历史路由；未列入矩阵的路由继续使用 Task 9 ownership fallback。

## 步骤

- [x] 先补跨账号授权策略单测和 middleware 集成失败用例。
- [x] 实现 owner / family / recipient / system-only 策略评估。
- [x] 接入安全响应头、shadow 日志和 enforce-safe 决策。
- [x] 增加本地 HTTP smoke 和 release regression 可选 gate。
- [x] 更新覆盖矩阵并完成后端、iOS 构建与 diff 验证。
- [x] 关闭递归 ledger，记录生产 enforce 的剩余前置条件。

## 成功标准

- owner 访问自身资源返回 `allowOwner`。
- 已接受家庭成员读取其专属关怀快照返回 `allowFamily`，ownership 为 `delegated`。
- 时间信件 owner 和到期后的有效收件人可通过各自 principal 访问；伪造 `viewerUserId` 被标记为 deny。
- 家庭邀请只能由与邀请手机号映射一致的用户 principal 接受。
- 普通用户调用 dispatch/purge 等 system-only 路由被标记为 deny。
- 默认 shadow 不改变合法公开行为；敏感跨账号路由拒绝伪造 principal，测试 enforce 还能允许合法委托并拒绝其他已知越权。
- 响应头和日志不包含 token、手机号、明文用户 ID 或信件正文。
- 后端测试、HTTP smoke、release QA、generic iPhoneOS/simulator build 和 `git diff --check` 通过。

## 递归 Ledger

- Ledger ID：`L20260710-193743`。
- 状态：已关闭（4/4 problems、4/4 checks success）。

## 验证证据

- 后端：`./scripts/verify_backend.sh` 通过 169 项测试、compile 和 FastAPI smoke。
- 本地 HTTP：`tmp/visual-qa/prd-stitch-ui/backend-cross-account-authorization-shadow-smoke/task10-principal-bound/report.json`。
- Release QA：`tmp/visual-qa/prd-stitch-ui/release-regression/20260710-cross-account-auth-final/report.md`。
- iOS：simulator Debug 和 generic iPhoneOS build 通过。
- 未完成边界：服务器/Postgres 部署 smoke、SMS identity proof、全路由 ownership enforce、真机弱网/Keychain。
