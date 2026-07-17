# WI-S0-02-01 强身份 Challenge 与 Identity Binding 基础

日期：2026-07-17
Work Item：`WI-S0-02-01`
状态：`INTERNAL_READY / BACKEND_DEPLOYED / G0_G2_SCOPED_VERIFIED / G4_IDENTITY_PROVIDER_BLOCKED / LEGACY_REBIND_OPEN`
Execution owner：`codex-goal:019ece6b-2c15-7521-b160-c42e95d1dd5a`
Authority lock：`IDENTITY_AUTHZ`

## 目标

- 禁止手机号文本直接 claim 私人账号。
- 用 Challenge/Verify 将已验证外部身份绑定到不可枚举的随机 Subject。
- 只持久化 keyed hash、attempt、expiry 和 proof receipt，不保存手机号或验证码明文。
- 真实身份 Provider 未验收时生产 fail closed，不恢复旧密码/手机号直登。

## 已实现合同

- 后端新增 `IdentityBindingService`、provider adapter 和统一的 challenge/rate/verification 错误合同。
- 新增 `POST /v2/auth/challenges` 与 `POST /v2/auth/challenges/{challengeId}/verify`。
- 新增 additive migration `0002`：`identity_hash_key_versions`、`subjects`、`identity_bindings`、`auth_challenges`、`identity_proofs`。
- Subject、Binding、Proof 使用随机 opaque ID；手机号与验证码只以版本化 HMAC-SHA256 存储。
- proof receipt 通过复合外键绑定 Subject/Binding，并由数据库触发器禁止 update/delete。
- challenge 具备 expiry、attempt lock、retry window、provider mode 和 HMAC key version 约束。
- suspended Subject、revoked Binding、disabled provider、HMAC key/version 漂移均 fail closed。
- HMAC version/fingerprint 登记防止密钥漂移静默创建第二个 Subject；在线换钥仍需显式 rehash migration。
- 生产 `/auth/login` 与 `/auth/restore` 返回 `410 legacy_identity_flow_retired`；test-only legacy 开关只在 development/local/test 生效。
- runtime capability 暴露 typed identity challenge 合同；生产 provider disabled 时 `clientFlowEnabled=false`。
- iOS 新增 typed capability/challenge/verification DTO，严格校验 endpoint、contract version、完整字段和带小数秒 ISO8601 时间。
- iOS 登录只展示手机号，先读取 runtime capability，再 create/verify challenge；无能力、响应缺字段或 session 不一致时清理 session 并停止登录。
- 旧密码登录 release guard 已更新为强身份 guard，避免发布回归重新引入密码字段或 `/auth/login` fallback。

## 版本与部署

- 后端提交：`a12545e feat(WI-S0-02-01): add strong identity challenge foundation`。
- iOS 实现提交：`f9208ab feat(WI-S0-02-01): add strict typed identity challenge client`。
- 后端已推送并部署；服务器、`origin/main` 与容器代码均为 `a12545e`。
- Postgres migration head 已从 `0001` 升级并验证为 `0002`。
- 服务器 `.env` 已配置独立 HMAC key、`v1` key version、`disabled` provider 和关闭 legacy login；证据只记录布尔状态，不记录值。
- iOS 提交只保留在 `feature/prd-stitch-ui-adaptation` 本地分支，未自动推送。

## 验证

- 后端全量测试：`431/431` 通过。
- Python compile、migration manifest、`git diff --check` 通过。
- 本地 identity deployed smoke 通过：provider disabled 返回 503，legacy login 返回 410，无目标值泄漏。
- 线上 `/ready`：database/schema/auth 均为 ready，schema reason 为 `migrationHeadVerified`。
- 线上 identity challenge deployed smoke 通过，生产保持 fail closed。
- migration `dry-run -> apply -> verify` 通过，实际应用 `0002`。
- 迁移前 schema `0001` 加密备份验证通过；迁移后重新生成两份 schema `0002` 加密备份，deployed backup smoke 通过。
- iOS identity static check、login boundary check、typed model smoke、legacy release guard 和 PRD coverage guard 通过。
- iOS unsigned generic Simulator Debug build 与 generic iPhoneOS Debug build 均 `BUILD SUCCEEDED`。
- 独立复审的 legacy bypass、fractional date、disabled provider、Subject/Binding 复活、dynamic migration head、HMAC drift、capability fail-open 和 proof DB constraint 八项均已封闭，无 P0/P1 阻断。
- 静态 release regression 已通过本 Work Item 相关 Gate，随后在未由本轮改动引起的旧 Echo delayed-reply notification guard 停止；不得把该结果写成全包 PASS。
- arm64 iOS 26.5 模拟器运行截图仍受工程既有 x86_64-only simulator binary 限制；本项不据此宣称模拟器交互验收。

## 未关闭边界

- G4 真实短信/身份 Provider、平台合同、Privacy 和运营反滥用策略未提供；生产登录挑战因此保持关闭。
- 旧确定性 user ID 的 alias、同手机号 rebind、冲突 quarantine 与受控存量迁移尚未实现；未批量重写任何业务 FK。
- HMAC key/version 变化当前会 fail closed，不代表在线双钥读取、rehash、切换和退役已经完成。
- `AccountSessionActor`、AccountGeneration CAS 和本地 owner isolation 属于 `WI-S0-01`，仍是 iOS 完整账号切换的依赖。
- 本项没有实现 token family 原子轮换、reuse detection、业务资源 AuthZ 或永久密码策略。

## 续接点

Authority lease 继续保持 `IDENTITY_AUTHZ`，进入 `WI-S0-02-02`：实现 access/refresh token family 的原子轮换、reuse detection、单 session/family/all-device revoke，并在真实 Postgres 上完成并发与故障 smoke。`WI-S0-02-01` 的 G4 Provider 与 legacy rebind 边界继续保留，不阻止不依赖真实短信的 token family 开发。
