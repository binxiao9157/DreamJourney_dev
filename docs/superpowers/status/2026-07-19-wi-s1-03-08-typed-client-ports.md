# WI-S1-03-08 Voice/DH Typed Client Ports

日期：2026-07-19

## 当前状态

- Work Item：`WI-S1-03-08`
- Authority lock：`IOS_COMPOSITION`
- Execution owner：`codex-goal:019ece6b-2c15-7521-b160-c42e95d1dd5a`
- 当前结果：`IN_PROGRESS / TWO_G0_SLICES_VERIFIED / G1_G3_G4_OPEN`
- 已完成切片：`WI-S1-03-08-TYPED_PORT_CORE_ADAPTER_G0`、`WI-S1-03-08-OWNER_KEYED_CACHE_IDENTITY_G0`
- 当前下一切片：`WI-S1-03-08-VOICECLONE_STATE_RUNTIME_BOUNDARY_G0`
- 范围：为回忆录复刻语音合成和 Echo 数字人 session 的核心调用建立 typed client port；不改变
  全屏 UI、公开范围、Provider 或真实音频行为。

## 已实现

- 新增 `VoiceDigitalHumanOperationScope`，把 `AccountLease`、persona owner、角色 key 与 runtime
  generation 作为 Voice/DH 请求的不可变本地上下文；空 persona 或角色会在进入 client adapter 前被拒绝。
- 新增 `VoiceCloneSynthesisRequest` 和 `DigitalHumanSessionRequest`，明确将 owner、profile、文本、
  音频参数、scene、device 与 lifecycle mode 传入 typed boundary；这些值不包含 Provider 凭据。
- 新增 `DigitalHumanSessionLeaseOperationRequest`。heartbeat/release 在调用既有 backend client 前确认
  session contract 的 `userId` 与捕获的 `AccountLease.subjectId` 一致；不匹配时返回
  `accountContractMismatch`，不请求 Provider。
- `DreamJourneyBackendClient` 以 adapter 方式实现两个 port，底层继续复用已存在的
  `/voice/synthesis` 和 `/digital-human/sessions` 合同；本轮没有改网络 payload、服务器逻辑或客户端保存的
  Provider key。
- `MemoirTTSService` 现在依赖注入 `VoiceCloneSynthesisClientPort`，构造带账户/角色/runtime generation 的
  synthesis request，不再直接调用 `DreamJourneyBackendClient.shared`。
- `EchoViewController` 现在依赖注入 `DigitalHumanSessionClientPort`；核心的 session create、heartbeat 和
  release 都经由 typed request。旧角色、旧账户或无效 persona 的请求不能静默落到默认角色。
- 新增模型覆盖，固定 scope 的归一化、空值拒绝、profile request 字段和 session owner/persona 映射。
- 新增 `product-v4-ios-voice-dh-client-port-check.py` 与
  `run-ios-voice-dh-client-port-gate.sh`；并纳入既有 Voice/TTS/Digital Human owner-scope Gate。
- 修复已有 Archive 静态检查的 QA 误报：仅在 `UI_QA_SIMULATOR && targetEnvironment(simulator)` 编译的
  结果文件可以写入 Documents，生产 Archive 路径仍禁止共享 Documents 媒体写入。该修正已独立提交
  `0fe3276`。

## 验证

执行：

```bash
bash Scripts/QA/product-v4/run-ios-voice-dh-client-port-gate.sh
bash Scripts/QA/product-v4/run-voice-tts-digital-human-owner-scope-gate.sh
xcodebuild build-for-testing \
  -workspace DreamJourney.xcworkspace \
  -scheme DreamJourney \
  -configuration Debug \
  -destination 'generic/platform=iOS' \
  CODE_SIGNING_ALLOWED=NO
git diff --check
```

结果：`PASS`。

- typed-port 静态 Gate 验证 scope、request、backend adapter、Memoir TTS 与 Echo 的三个核心接入点，
  以及新增 XCTest 覆盖声明；
- Voice/TTS/Digital Human owner-scope 聚合 Gate 完整通过；
- `build-for-testing` 成功，App 与 `DreamJourneyTests` bundle 均已编译；
- 尝试在已启动的 iOS Simulator 执行
  `DreamJourneyTests/VoiceDigitalHumanClientPortModelTests`，但当前 scheme 仅暴露通用 Simulator
  placeholder，未暴露该已启动设备作为可选 destination；测试没有执行，这不是代码失败；
- 构建仍有既有第三方地图静态库 object-file warning，本切片未新增该类 warning，结果为
  `TEST BUILD SUCCEEDED`。

## 未完成边界

- `VoiceCloneService` 的训练状态轮询和本地 owner-scoped storage 仍使用既有服务边界；本轮只迁移核心
  synthesis/session port，后续需要按同一 typed contract 收敛其 timer/cache。
- `MemoirTTSService` 的 owner-keyed cache identity 已在后续 G0 切片完成，详见
  [owner-keyed cache identity](2026-07-19-wi-s1-03-08-owner-keyed-cache-identity.md)。
- Echo 中仅核心 production create/heartbeat/release 使用 port；UIQA-only helper 仍保留旧 client 调用，
  不能作为生产接入完成的证据。
- 不涉及真实 Provider 合成、腾讯数字人 session、PCM audio-drive、试听与 Echo 音色一致性、音频 owner
  强制仲裁或任何真机验证；G1/G3/G4 保持开放。

## 下一步

继续 `WI-S1-03-08-VOICECLONE_STATE_RUNTIME_BOUNDARY_G0`：收敛 `VoiceCloneService` 的 profile/state timer、
owner 与 runtime generation 绑定；旧账户、旧角色或旧 timer 回调不得覆盖当前角色。之后再处理 Digital
Human runtime adapter 的剩余边界。
