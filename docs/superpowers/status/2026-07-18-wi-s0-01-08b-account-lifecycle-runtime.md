# WI-S0-01-08B Account Lifecycle Runtime 证据

## 1. 状态

- Work Item：`WI-S0-01-08`
- 子闭环：`WI-S0-01-08B switch / logout / suspension / cold-start runtime integration`
- Authority：`ACCOUNT_LOCAL_STATE`
- 提交：
  - `d4798e8 feat(WI-S0-01-08): teardown voice account runtime`
  - `a2ac9ca feat(WI-S0-01-08): teardown knowledge conversation family state`
  - `8560654 feat(WI-S0-01-08): teardown message notification state`
  - `b9f6c52 feat(WI-S0-01-08): connect account lifecycle runtime`
- 结论：普通切换、退出、私有访问暂停和冷启动失败恢复已统一进入一个串行 lifecycle controller；29 个私有 surface 对应的 13 个 module 均有生产 registration 和 scoped teardown。`WI-S0-01-08` 仍为 `IN_PROGRESS`，下一子闭环 08C 单独完成 account deletion 的不可逆本地 purge。
- 状态上限：本轮未宣称 Provider 远端数据已经删除，也未关闭 G1/G4；普通 logout 不会误用 account deletion 语义。

## 2. 实现

### 2.1 单一入口与顺序

- 新增 `AccountLifecycleTransitionController`，串行执行 actor fence、Echo runtime 释放、模块 teardown 和终态 receipt。
- `UserManager.logout()` 在旧 lease 捕获和后端 logout 请求后进入 controller，只有 receipt 终态后才广播 `djUserDidLogout`。
- `AppCoordinator` 不再重复调用 `signOut/suspend` 或独立清空 `AccountLeaseRuntime`。
- 冷启动 authentication fallback 和 private suspension 使用相同 controller，不再绕过模块收敛。
- 旧操作 finalizer 会核对 owner；若期间已激活新账号，不会清理或退出新账号。

### 2.2 Runtime 与本地状态

- Voice Clone：取消旧账号训练 poll/callback，并按旧 scope 清理可重建音色缓存。
- Memoir TTS：取消旧 scope 合成，清除音频/timeline metadata，不删除 Memoir 草稿或录音。
- Digital Human：actor fence 后先同步通知 Echo 释放腾讯 session/audio runtime，再清理旧 owner context。
- Knowledge/Conversation/Family：旋转 generation、取消同步/提取任务、卸载内存 projection；普通退出保留 owner-scoped 显式草稿并锁定。
- Reply/Message/Notification：按五项旧 lease 身份字段清理延迟回信、本地通知、消息 projection 和 owner registration；设备级 APNs token 保留。
- Widget/QA：清理旧 owner Widget projection、Echo trace、runtime diagnostics 和临时导出；仅保留有界、值最小化 lifecycle receipt。

### 2.3 远端边界

- Voice profile 远端资源在 switch/logout 时记录 `ownerFenced`，不伪造删除完成。
- Digital Human session 在 Echo runtime teardown 中发起释放，receipt 只声明 release requested。
- Account deletion 所需的 voice/provider/object/family 远端 disposition receipt 留给 08C 和后续 rights work item。

## 3. 多 Agent 协作

- Voice/TTS/Digital Human agent：3 个本地 runtime teardown adapter 与组合 Gate。
- Knowledge/Conversation/Family agent：4 个 owner-scoped unmount/purge adapter 与 stale-scope Gate。
- Message/Notification/Widget agent：5 个定向 teardown API，保留 device APNs token。
- 主控：13 module production registry、UserManager/AppCoordinator/Echo 入口接线、Xcode target、统一 Gate、构建和代码审查。

## 4. 验证

- `run-account-lifecycle-entrypoint-gate.sh`：通过。
- `run-account-lifecycle-coordinator-gate.sh`：通过。
- `run-account-lifecycle-module-registry-gate.sh`：通过，29/29 surface、13 module、7 phase、0 gap。
- `run-voice-tts-dh-account-lifecycle-gate.sh`：通过。
- `run-knowledge-conversation-family-account-lifecycle-gate.sh`：通过。
- `run-message-notification-widget-account-lifecycle-gate.sh`：通过。
- `git diff --check`：通过。
- generic iOS Simulator Debug build：通过，日志 `tmp/wi-s0-01-08b-runtime-registry-simulator.log`。
- generic iPhoneOS Debug build：通过，日志 `tmp/wi-s0-01-08b-runtime-registry-iphoneos.log`。
- 构建使用命令行本机覆盖 `com.yxj.dreamjourney.app / 2BTR77V3R8`，未修改共享签名配置。

## 5. 后续交接

08C 只处理 account deletion：在后端 soft delete 成功后以同一个旧 lease 运行全部 module purge，任何本地数据残留必须产生 failure receipt；远端不支持删除的资源必须保留 `pending/unsupported` disposition，不能把普通退出结果冒充删除完成。完成后运行 Slice 1D 总 Gate 并进入 `WI-S0-05-01`。
