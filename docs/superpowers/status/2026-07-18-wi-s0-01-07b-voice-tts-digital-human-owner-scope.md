# WI-S0-01-07B Voice / TTS / Digital Human Owner Scope 证据

## 1. 状态

- Work Item：`WI-S0-01-07`
- 子闭环：`WI-S0-01-07B Voice / TTS / Digital Human local owner scope`
- Authority：`ACCOUNT_LOCAL_STATE`
- 结论：07B 内部实现、G0 可执行检查和通用 iOS 构建完成；Voice Clone 本地状态已补一条 simulator-only 的 A/B G1 子证据。结合 07A，`WI-S0-01-07` 达到内部代码完成状态，下一任务进入 `WI-S0-01-08`。
- 状态上限：本轮未修改后端或 Provider 行为，也未声明真实设备、恢复演练或产品验收完成；Memoir TTS / Digital Human 与真实账号 UI 切换的 G1、G3 恢复/回滚证据和 G4 外部验收继续开放。

## 2. 实现结果

### 2.1 Voice Clone 本地状态

- 新增 `VoiceCloneLocalStateStore`，使用 AccountLease 的 subject、vault、generation 和 generationId 构造隔离身份，并以不可逆摘要生成存储键。
- 同一 generation 的 session refresh 可继续读取；切换账号或进入新 generation 后不能读取旧状态。
- 异步写入提交前重新校验 lease，过期回调执行回滚，不得写入当前账号。
- 旧全局 speaker/sample/provider 状态不自动认领，统一进入 quarantine 并保留迁移回执。
- 移除固定 `default` principal fallback；家庭成员音色继续通过既有 FamilyRepository 合同解析。

### 2.2 Memoir TTS 缓存

- 音频目录、metadata 目录和缓存 identity 按 subject、vault、generation、generationId 隔离。
- memoir 文件名改用摘要，metadata envelope 在读取时校验 owner scope。
- 同 generation 刷新会话可复用缓存；其他账号和新 generation fail closed。
- 旧 `memoir_audio` / `memoir_tts_cache` 全局文件迁入 quarantine，不自动归属当前用户。
- 合成完成后若 AccountLease 已失效，同时回滚音频和 metadata，避免旧账号异步结果落盘。

### 2.3 Digital Human Context

- Digital Human context 改为 generation-scoped envelope 与存储键。
- 无有效 lease 时返回不可用上下文，不再生成匿名或默认 subject。
- 同 generation session refresh 可恢复上下文；切换账号或新 generation 后拒绝旧上下文。
- 旧 subject-only payload 进入 quarantine，不自动认领。
- 只有通过 lease 校验并完成持久化后才发送 context 更新通知。

### 2.4 组合 Gate 与 inventory

- 新增 Voice Clone、Memoir TTS、Digital Human Context 三个独立 owner-scope Gate。
- 新增 `run-voice-tts-digital-human-owner-scope-gate.sh`，串联三项 Gate、Echo runtime AccountLease、Digital Human secure path 和 AccountStoreInventory。
- 更新 AccountStoreInventory 中 S07、S10、S11、S12 的实际状态，并显式排除仅用于 QA 的全局私有存储退役 UIQA 文件。
- 修正 Archive AccountLease 静态检查对 07A 新 wrapper/overload 结构的旧断言；产品行为未改变。

## 3. 并行协作与提交

本子闭环由主控拆成三个互不重叠模块并行实现，随后统一审查、修正 inventory 并运行组合 Gate：

- Voice Clone：`3261a1b feat(WI-S0-01-07): scope voice clone local state`
- Memoir TTS：`066b9b8 feat(WI-S0-01-07): isolate memoir TTS cache`
- Digital Human Context：`430a047 feat(WI-S0-01-07): isolate digital human context`
- 组合 QA / inventory：`f0788e1 test(WI-S0-01-07): close account local state gate`

## 4. 验证

- `Scripts/QA/product-v4/run-voice-clone-local-owner-scope-gate.sh`：通过。
- `Scripts/QA/product-v4/run-memoir-tts-cache-owner-scope-gate.sh`：通过。
- `Scripts/QA/product-v4/run-digital-human-context-owner-scope-gate.sh`：通过。
- `Scripts/QA/product-v4/run-voice-tts-digital-human-owner-scope-gate.sh`：通过。
- AccountStoreInventory：`catalogCategories=17`、`registeredSurfaces=28`、`registeredSourceFiles=57`、`unknownPrivateSurface=0`。
- `git diff --check`：通过。
- generic iOS Simulator Debug build：通过；日志为 `tmp/visual-qa/prd-stitch-ui/wi-s0-01-07b/simulator-build.log`。
- generic iPhoneOS Debug build：通过；使用本机签名覆盖 `2BTR77V3R8 / com.yxj.dreamjourney.app`，未修改共享工程签名。
- iPhoneOS 报告：`tmp/visual-qa/prd-stitch-ui/iphoneos-generic-build/20260718-wi-s0-01-07b-owner-scope/report.md`。

### 4.1 Voice Clone 本地状态 simulator-only G1 子证据（2026-07-30）

- 新增 QA-only launch arg：`DJRunVoiceCloneOwnerScopeSmoke`；仅在 `UI_QA_SIMULATOR && targetEnvironment(simulator)` 编译，不进入公开 UI、Provider 调用或真实音色训练。
- Smoke 实际使用 `VoiceCloneLocalStateStore`，验证 Account A/B 相互隔离、generation 变化不继承旧 profile、旧 lease 写入被拒绝、删除 Account A 只清理 A 的 scoped state、旧全局 voice clone payload 被 quarantine。
- `Scripts/QA/product-v4/run-voice-clone-owner-scope-uiqa-smoke.sh`：通过。
- result：`tmp/visual-qa/product-v4/voice-clone-owner-scope/20260730-voice-clone-owner-scope-r3/voice-clone-owner-scope-uiqa-result.json`，六项断言均为 `true`。
- screenshot：`tmp/visual-qa/product-v4/voice-clone-owner-scope/20260730-voice-clone-owner-scope-r3/01-voice-clone-owner-scope.png`。
- 既有 `Scripts/QA/product-v4/run-voice-clone-local-owner-scope-gate.sh` 保持通过；generic iPhoneOS Debug build 通过，日志为 `tmp/visual-qa/product-v4/voice-clone-owner-scope/20260730-voice-clone-owner-scope-r3/generic-iphoneos-build.log`。
- 此证据不覆盖真实登录/退出 UI、Memoir TTS、Digital Human session、Provider、恢复演练或真机验收，不能单独关闭整个 `WI-S0-01-07` 的外部门。

## 5. 后续交接

下一步进入 `WI-S0-01-08`：统一编排 account switch、logout、delete 和冷启动恢复对所有 account-local module 的清理/失效顺序；先建立模块清单和可执行状态机 Gate，再接真实 UI 生命周期，不重复改写 01-01..07 已完成的 owner-scoped store。
