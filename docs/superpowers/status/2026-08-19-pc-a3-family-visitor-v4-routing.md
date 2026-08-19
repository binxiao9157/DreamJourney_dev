# PC-A3 Family/Visitor V4 权限路由验收

日期：2026-08-19
状态：`COMPLETE`
关联：GAP-05、ARCH-001、ECHO-001、FAM-001、PUB-002、SEC-001
下一项：PC-A4 音色独立授权与累计创建上限

## 1. 完成范围

1. Backend 新增 fail-closed 身份路由：只有认证主体与目标 Owner 一致时才能进入私人 V4 Context。
2. Family 关系本身不再授权读取 Source、Candidate、MemoryVersion、私人 Projection、Archive 或 KBLite。
3. Family 请求私人 `/context/build`、`/echo/answers` 时返回 `familyPrivateContextDenied`，且明确 `privateContextAllowed=false`、`legacyFallbackAllowed=false`。
4. ShareGrant admission 将 `ownerSubjectId` 绑定到 VisitorSession；iOS 只有在当前家庭对象、有效 VisitorSession 和 Owner 主体三者一致时才读取 PublicProjection。
5. 无匹配 VisitorSession 时，iOS 只展示 FamilyContribution 引导，不调用私人 Context 或生成 Provider。
6. 非本人路由不创建腾讯数字人 Session；账号、角色、Session 或生命周期变化后，旧异步回调由现有 AccountLease、lifecycle token 和 context key 丢弃。

## 2. 权限矩阵

| 主体与授权 | 私人 V4 | PublicProjection | FamilyContribution | Legacy 回退 | 腾讯数字人 |
|---|---:|---:|---:|---:|---:|
| Owner 本人 | 允许 | 不需要 | 不需要 | 禁止 | 按独立能力 Gate |
| 已接受 Family、无 ShareGrant | 禁止 | 禁止 | 引导 | 禁止 | 禁止 |
| 已接受 Family、匹配 VisitorSession | 禁止 | 允许 | 不需要 | 禁止 | 禁止 |
| Session Owner 不匹配、过期或撤销 | 禁止 | 禁止 | 引导或拒绝 | 禁止 | 禁止 |
| 未接受关系或身份缺失 | 禁止 | 禁止 | 禁止 | 禁止 | 禁止 |

## 3. 版本与部署

- Backend 提交：`83240f6e9af54044d4b2d94d12af1228596ca68b`。
- iOS 提交：`b4caa0b4`。
- 服务器源码：`83240f6e9af54044d4b2d94d12af1228596ca68b`，工作区 clean。
- 部署方式：重建并强制重建 `api` 容器；无数据库迁移。
- `/health`：HTTP 200，`store=postgres`。
- `/ready`：database、schema、auth、incident 全部 ready；migration head 保持 `0096`。

## 4. 验证结果

### Backend

- `scripts/verify_backend.sh`：2145 项主 unittest 及全部标准 Gate 通过。
- `scripts/run-backend-family-visitor-v4-routing-gate.sh`：27/27 通过。
- `scripts/run-backend-publication-visitor-access-gate.sh`：16/16 通过。
- 部署容器内路由 smoke：Family 无 ShareGrant 返回 `familyContribution`，私人和 Legacy 读取均为 false。
- `git diff --check`、py_compile、FastAPI smoke 通过。

### iOS

- `PublicationVisitorAccessTests`：15/15 通过。
- Echo Family Context、Publication default-off、Owner management、Visitor scope、Publication lifecycle 和 release-policy cache Gate 全部通过。
- generic iPhoneOS Debug build 通过，Bundle ID `com.yxj.dreamjourney.app`，Team `2BTR77V3R8`。
- 构建报告：`tmp/visual-qa/prd-stitch-ui/iphoneos-generic-build/20260819-pc-a3/report.md`。

## 5. 安全与兼容边界

- `viewerFamilyMemberID` 不再作为私人读取凭据；即使旧客户端继续传值，Backend 也在 Context 生成前拒绝。
- VisitorSession 仅授权已发布、脱敏且版本绑定的 PublicProjection，不提升为 OwnerTruthCommandContext。
- admission 响应新增 Owner 绑定字段；grant credential 和 session credential 的一次性、进程内及 no-store 边界保持不变。
- 旧家庭 Context 过滤代码仍可服务历史内部场景，但公开 Family Echo 不再进入该路径。
- 三份与本轮无关的未跟踪状态文档未纳入提交。

## 6. 回滚与交接

本轮没有不可逆迁移。若 Visitor 公开读取异常，可关闭 Publication Visitor release policy；私人 V4 仍保持 fail-closed，不回退旧家庭私人读取。下一项 PC-A4 以声音主体为计数和授权边界，先核对现有 profile lifecycle、purpose consent、Provider slot 与 Echo binding，再实现累计创建 5 次的原子服务端合同。
