# P000: P0 跨账号授权策略与 Shadow 证据

Status: done
Parent: none
Root: P000
Source Ticket: none (none)
Source Check: none
Package: problems/P000
Body: problems/P000/README.md
Ticket(s): T000

## Problem
Close the Lodestar task represented by `/Users/yxj/Documents/Codex/Video/DreamJourney_dev/docs/plans/task_10_p0-cross-account-authorization-policy-shadow.md` using recursive problem, ticket, result, and check state.

Task context:

# P0 跨账号授权策略与 Shadow 证据

## Success Criteria
- owner 访问自身资源返回 `allowOwner`。
- 已接受家庭成员读取其专属关怀快照返回 `allowFamily`，ownership 为 `delegated`。
- 时间信件 owner 和到期后的有效收件人可通过各自 principal 访问；伪造 `viewerUserId` 被标记为 deny。
- 家庭邀请只能由与邀请手机号映射一致的用户 principal 接受。
- 普通用户调用 dispatch/purge 等 system-only 路由被标记为 deny。
- 默认 shadow 不改变现有公开行为；测试 enforce 能允许合法委托并拒绝已知越权。
- 响应头和日志不包含 token、手机号、明文用户 ID 或信件正文。
- 后端测试、HTTP smoke、release QA、generic iPhoneOS/simulator build 和 `git diff --check` 通过。

## Subproblems
- P001: 授权策略模型与单元测试
- P002: 中间件集成与跨账号 FastAPI 验证
- P003: 非真机 QA Gate 与文档收敛

## Results
- R003

## Latest Check
C003

## Bodies
- Problem: problems/P000/README.md
- Ticket T000: problems/P000/tickets/T000.md
- Result R003: problems/P000/results/R003.md
- Check C003: problems/P000/checks/C003.md

## Follow-ups
- none
