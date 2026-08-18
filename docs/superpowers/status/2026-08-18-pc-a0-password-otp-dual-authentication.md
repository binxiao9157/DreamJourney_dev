# PC-A0 密码与手机号验证码双登录验收

日期：2026-08-18
状态：`WAITING_EXTERNAL_CONFIGURATION`（代码、部署和非真机合同已验证）
关联：AUTH-001、PROF-001、PCQ-02
下一项：PC-A1 测试账号角色与权限

## 1. 完成范围

1. 后端新增密码设置、登录、修改、忘记/重置和敏感操作 OTP 再认证合同；密码与 OTP 使用同一 Access/Refresh Session 模型。
2. 密码凭据使用 PBKDF2-SHA256 单向哈希和参数升级判断，记录 revision、失败次数、锁定、重置回执；未知账号和错误密码使用统一错误码且执行等价哈希比较。
3. OTP challenge 支持 `passwordReset` 和 `sensitiveOperation`，action token 经 HMAC 摘要存储、限时且只能消费一次；未知手机号重置不创建账户、不暴露账号存在性。
4. 密码修改和重置会撤销旧 token family，成功响应签发同一 v2 Session 合同的新会话。
5. PostgreSQL migration `0094` 增加登录锁定和一次性 action grant 存储，并扩展 OTP purpose 约束。
6. iOS 登录页提供密码/验证码分段模式；个人设置接入密码设置/修改，重置页和敏感操作再认证均由后端 typed capability 控制。
7. 服务器当前 OTP Provider 为 `testAllowlist`。密码登录公开可用，但 `setupReady/resetReady/reauthReady=false`；测试恢复能力单独返回 `testRecoveryReady=true`，不会向普通用户误暴露“忘记密码”入口。

## 2. 版本与部署

- iOS 实现提交：`5aaf3543`（`feat: add password and otp dual authentication`），当前未推送。
- Backend 实现提交：`3ea80d1`（`feat: add password and otp dual authentication`）。
- Backend 发布边界修复：`994b3cc`（`fix: keep test otp recovery hidden`）。
- Backend 远端与服务器源码：`994b3ccee904c38d0a4000f43ec3f9ff8e005ccd`。
- Backend 部署镜像：`sha256:66559250000a7d6680c352032d72224f5465c387672e2d27dcd2aa0c443960a1`。
- 数据库 migration head：`0094`，迁移 apply/verify 均通过。

## 3. 验证结果

### Backend

- PC-A0 最终专项 Gate：106 项通过。
- 实现基线全量 `verify_backend.sh`：2121 项 unittest 及后续标准 Gate 通过；最终发布边界修复另由专项 Gate 覆盖。
- 线上 `/ready`：database/schema/auth/incident 均为 ready。
- 线上 deployed smoke：合同 v2、负向登录、公开恢复入口关闭、测试白名单诊断状态均通过。
- 密码枚举负向、锁定、OTP 重放、重置 token 单次使用、Session family 撤销和迁移合同通过。
- `git diff --check` 通过；服务器 Git 工作区干净。

### iOS

- 登录、个人密码设置/修改、Identity Challenge、Password Authentication typed model、Auth Boundary 和 Release Feature Matrix 检查通过。
- generic iPhoneOS Debug build 通过，Bundle ID 使用本机 `com.yxj.dreamjourney.app`。
- arm64 模拟器 build/install/launch 通过。
- UIQA 验证密码/验证码模式可切换；测试白名单环境不显示公开密码重置入口。
- `git diff --check` 通过。

## 4. 证据

- 证据目录：`artifacts/product-confirmed/20260818-pc-a0/PC-A0/`
- 验证摘要：`checks.log`、`smoke.json`、`backend-deployed-smoke.log`、`build.log`
- 部署前后快照：`runtime-before.json`、`runtime-after.json`、`ready-after.json`
- UIQA：`uiqa/password-otp-login.png`、`uiqa/password-login.png`

证据包不包含 token、手机号、密码、Provider 凭据或用户数据。

## 5. 外部 Gate 与后续

真实短信 Provider、签名、模板和非白名单测试号码尚未配置，因此不能宣称生产 OTP 到达、普通用户密码恢复或敏感操作短信再认证已完成。该外部 Gate 不影响密码 Session 合同稳定，也不阻塞 `PC-A1`。

后续进入 `PC-A1`：将测试验证码资格与产品 entitlement 分离，补 `testRole`、`featureEntitlements`、`scenarioBindings`、`entitlementRevision`、旧 Session 撤销和 super 越权负向验证。
