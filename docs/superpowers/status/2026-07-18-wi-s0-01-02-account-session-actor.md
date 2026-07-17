# WI-S0-01-02 AccountSessionActor 与冷启动一致性证据

## 结论

- 状态：`INTERNAL_READY / G0_G1_DETERMINISTIC_VERIFIED / IOS_LOCAL_COMMITTED / G4_EXTERNAL_BLOCKED`
- iOS 实现提交：`5343122 feat(WI-S0-01-02): centralize account session activation`
- 后端：本 Work Item 无代码变化；继续使用已部署的 typed session 基线 `main@ab668a7`。
- 发布边界：没有新增公开入口；强身份 Provider 的 G4 仍保持 `EXTERNAL_BLOCKED`，不阻断后续不依赖外部门的 Work Item。

## 终版规则

终版 Product Spec 29.2 是本项冲突裁决依据：有效 Keychain session 与缺失或错误的本地 profile cache 并不等价于无效登录。冷启动必须先隐藏错误 profile，在线验证 session，再以 session subject 重建正确的 display cache 和 scope；业务根路由只接受 Actor 的 committed receipt。

本项不再允许：

- 仅凭 `UserDefaults` 的 `dj_current_user` 或 `dj_is_logged_in` 进入私人业务页。
- session/profile mismatch 时清除仍有效的 Keychain session。
- 启动验证前按缓存 user 激活 Echo trace 或私人 store。
- 晚到的验证、登出或 suspend 回调覆盖新 generation。

## 实现

1. 新增真实 Swift `actor AccountSessionActor`，统一维护：
   - `subjectId / vaultId / sessionId / tokenFamilyId`
   - 持久递增 `generation` 与随机 `generationId`
   - `signedOut / activating / active / switching / suspended / deleting`
   - `authentication / validation / privateUI` 根路由 receipt
2. 新增最小、值脱敏的 `AccountSessionActivationJournalStore`：
   - `prepared -> sessionSaved -> storesMounted -> profileCached -> committed`
   - 不持久化 subject、session、token family 或 token 值。
   - 同一次激活在阶段推进和 `activating -> active` 期间保持同一 generation；登录、切换、登出、暂停和删除才旋转 generation。
3. `AppCoordinator` 只在 receipt 为 `active + privateUI + committed` 后发布三 Tab 根路由；旧 callback 由 expected generation 拒绝。
4. `UserManager` 将缓存 profile 降为 display-only：
   - 有效 session + profile 缺失/错误时隔离旧 profile，但保留 session。
   - session refresh 验证后按 session subject 重建 placeholder profile，再开放私人访问。
   - Echo trace 和 Knowledge/KBLite scope 只在验证完成后激活。
5. UIQA 的 synthetic credential 仅存在于 `UI_QA_SIMULATOR && targetEnvironment(simulator)`，正式 composition 不接受本地假登录。
6. 账号 store inventory 已登记 activation journal；`unknownPrivateSurface=0` 保持不变。

## 验证

以下检查均通过：

- `Scripts/QA/product-v4/run-account-session-actor-gate.sh`
  - 编译并执行生产 `AccountSessionActor.swift`。
  - 覆盖无状态、仅 profile、仅 credential、profile/session mismatch、无效 credential、在线激活、切号、登出、删除、旧 callback、晚到登出、UIQA、重启和损坏 journal。
- `Scripts/QA/product-v4/run-account-store-inventory-gate.sh`
  - `catalogCategories=17`
  - `registeredSurfaces=28`
  - `registeredSourceFiles=52`
  - `discoveredPrivateSurfaceFiles=44`
  - `unknownPrivateSurface=0`
- `product-v4-ios-typed-auth-cutover-check.py`
- `run-token-family-client-model-smoke.sh`
- `product-v4-token-family-client-check.py`
- `product-v4-login-identity-boundary-check.py`
- `product-v4-ios-client-auth-boundary-check.py`
- `auth-session-ownership-shadow-check.swift`
- `git diff --check`
- Release generic iPhoneOS build，`CODE_SIGNING_ALLOWED=NO`，通过。
  - 日志：`/tmp/DreamJourney-WI-S0-01-02-release-final.log`
  - 本次修改文件没有新增编译 warning；日志中仍有既有 Pods/第三方 SDK warning。

## 未在本项冒充完成的内容

- profile 目前按 validated session subject 创建安全 placeholder；完整昵称、头像、手机号应由后续 canonical `/me` profile hydration 覆盖，缓存不作为身份 Authority。
- 本项只把现有私人 store 的 mount 时机置于 committed route 前；逐 surface 的 `AccountLease` request/commit/UI/runtime checkpoint 属于 `WI-S0-01-04`。
- refresh single-flight 与 Keychain 保存 CAS 属于下一项 `WI-S0-01-03`。
- 真机、OTP/strong identity Provider 和正式外部安全审查不属于本项的内部完成声明。

## 下一项

`WI-S0-01-03 Refresh 结果的 Session/Generation CAS`：把 refresh attempt 和保存操作绑定到原始 `sessionId + tokenFamilyId + generationId`，拒绝切号、登出或 revoke 后的晚到响应。
