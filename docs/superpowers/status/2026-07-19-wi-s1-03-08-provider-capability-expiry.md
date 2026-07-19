# WI-S1-03-08 Provider Capability / Expiry Boundary

日期：2026-07-19

## 当前状态

- Work Item：`WI-S1-03-08`
- Authority lock：`IOS_COMPOSITION`
- Execution owner：`codex-goal:019ece6b-2c15-7521-b160-c42e95d1dd5a`
- 当前结果：`SUBSLICE_COMPLETE / FOUR_G0_SLICES_VERIFIED / WORK_ITEM_G0_INTEGRATION_REVIEW_PENDING / G1_G3_G4_OPEN`
- 已完成切片：`WI-S1-03-08-TYPED_PORT_CORE_ADAPTER_G0`、
  `WI-S1-03-08-OWNER_KEYED_CACHE_IDENTITY_G0`、
  `WI-S1-03-08-VOICECLONE_STATE_RUNTIME_BOUNDARY_G0`、
  `WI-S1-03-08-PROVIDER_CAPABILITY_EXPIRY_G0`
- 范围：收敛 VoiceClone、Memoir TTS 与腾讯数智人 session 的 runtime capability、凭据和 lease
  失效边界；不修改 Echo 全屏 UI、Provider 配置、公开发布范围或真实音频行为。

## 已实现

本切片将“配置字段存在”与“当前可以安全调用 Provider”分开处理：

- `RuntimeCapabilitySnapshot` 新增运行时合同与 Provider effect 两层判断。合同缺字段、未启用、未实现、
  或外部证据已过期时均 fail-closed；`externalEvidenceMissing` 仍保留既有 QA/内部合同路径，不能被误作
  真实 Provider 已就绪；
- VoiceClone 的训练、查询、合成能力分别消费真实 runtime capability。训练/查询要求 voice provider
  ready，合成要求 synthesis provider ready；Memoir TTS 在读取已验收 profile 前先请求 capability，未知或
  不可用时返回明确错误，不继续把本地配置当成可用 Provider；
- Profile 的音色复刻壳层以 capability 控制训练提交和状态刷新。不可训练/查询时不会继续发请求；
- 数字人真实云端 session 同时要求 runtime capability、scoped credential 与 active、未过期 lease。
  本地 `mockContract` 只保留给完整、未过期 QA 合同，不能绕过 stale/incomplete runtime contract；
- `DigitalHumanSessionCredential`、`DigitalHumanSessionLeaseContract` 与
  `DigitalHumanSessionContract` 增加统一可用性判断。Factory 只接受可用 session contract；
  Echo 在创建和激活前分别检查 capability 与 contract，否则释放不安全 contract 并回普通 Echo；
- heartbeat 成功时必须回传同一 session 的新 lease。Controller 会替换本地 contract lease 并续期
  `EchoRuntimeSessionCoordinator`；过期 session 的新 work、迟到 callback 或无效续期都被拒绝；
- Echo 的复刻 PCM 路径在 voice capability 尚未取得时不再隐式尝试默认音色。它记录
  `voiceCloneRuntimeCapabilityUnknown`，等待能力结果后再决定是否可走 `tencentAudioDrive`。

这仍是客户端 runtime 安全边界：它不证明腾讯会话、火山合成或音频播放在真实设备上成功，也不改变
`AudioOwnerLease` 当前 observe-only 的实际 AudioSession 写入权。

## 验证

执行：

```bash
bash Scripts/QA/product-v4/run-voice-tts-digital-human-owner-scope-gate.sh
bash Scripts/QA/product-v4/run-voice-tts-dh-account-lifecycle-gate.sh
swift Scripts/QA/prd-stitch-ui/voice-clone-stale-ready-state-check.swift
python3 Scripts/QA/product-v4/product-v4-account-store-inventory-check.py
python3 Scripts/QA/product-v4/product-v4-current-handoff-check.py
python3 Scripts/QA/product-v4/product-v4-docs-check.py
xcodebuild build-for-testing -workspace DreamJourney.xcworkspace -scheme DreamJourney -configuration Debug -destination 'generic/platform=iOS' CODE_SIGNING_ALLOWED=NO
git diff --check
```

结果：`PASS`。

- capability snapshot、VoiceClone training/query/synthesis、数字人 client/factory、lease expiry/renewal
  的静态和独立 Swift model smoke 全部通过；
- `EchoRuntimeSessionCoordinatorTests` 覆盖过期 session 拒绝新 work，以及 heartbeat renewal 延长回调边界；
- Voice/TTS/Digital Human owner-scope 与 account lifecycle 组合 Gate 通过；
- Debug、`generic/platform=iOS`、`CODE_SIGNING_ALLOWED=NO` 的 `build-for-testing` 成功。既有第三方地图
  静态库 warning 仍存在，本切片未新增该类 warning；
- `git diff --check` 通过。

## 未完成边界

- G1 模拟器 runtime、G3 Provider capability/成本/真实 credential、G4 真机腾讯会话、PCM、有声、口型、
  打断和麦克风恢复均未因此关闭；
- Provider 返回的 capability/lease 真实性仍由后端与 Provider 负责。本地只保证过期、未知或不完整合同
  不会被当作可安全使用；
- 没有引入新的 Provider key、没有把 credential 下发给 iOS、没有开放任何新的 Voice/DH 功能；
- 统一、强制的 AVAudioSession owner 仍属于后续 runtime/audio 迁移，当前只保留已有 observe-only evidence。

## 下一步

`WI-S1-03-08` 的四个本地 G0 子切片已完成，下一步进行 G0 integration review，确认旧的 global
cache/timer/default-provider 调用无残留且四个切片的组合 gate 维持通过。通过后才交接给
`WI-S1-03-09` 的 notification/deeplink runtime owner routing；该后续工作不会扩大 Voice/DH 的公开范围。
