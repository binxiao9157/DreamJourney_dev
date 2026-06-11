# DreamJourney 阶段2进度汇总

日期：2026-06-11

分支：`feature/phase2-mock-dialog-engine`

基线：`feature/phase1-integrated-mvp`

## 当前完成度

| 开发包 | 完成度 | 状态 |
| --- | ---: | --- |
| Mock/Simulator 基线 | 80% | `MockDialogEngine` 已实现，纯 Swift 验证、iPhoneOS build、simulator SDK typecheck 通过；完整 Simulator app build 仍受 `SpeechEngineToB` slice 影响，后续需独立 smoke target 或 Pod 条件化。 |
| Safety Guard 合约 | 65% | 合约和 iOS client 已固化；新增 `DeepSeekSafetyGuarding`，DeepSeek chat/knowledge/image、Memoir、TTS 入口已接入 fail-closed guard 骨架。 |
| Privacy Scope 模型 | 70% | `ConversationTurn`、`Stage1MailboxMemoryInput`、KBLite v2 实体已携带 `privacyMetadata`，旧数据默认迁移为 `.localOnly`。 |
| KBLite/Export/Widget 过滤 | 35% | KBLite remote extraction 和 prompt context 已按 scope 过滤；Export/Widget/PDF/Family/CareDashboard 仍待 sanitized 输出改造。 |
| CareDashboard/Family Sync 阶段2 | 0% | 等 scope 和家庭授权模型进入代码后开始。 |

## 已完成

- 抽出 `DialogEndReason` 和 `DialogEngineDelegate` 到 `DialogEngineModels.swift`，解除 mock 验证对火山 SDK manager 的依赖。
- 新增 `MockDialogEngine`，支持 setup/start/stop/destroy、确定性回复、高风险触发危机结束。
- `DialogEngineFactory` 新增 `.mock` 和 `makeDefault(arguments:environment:)`。
- `AIRecordingViewController` 改用 `DialogEngineFactory.makeDefault()`。
- 新增 `Scripts/MockDialogEngineVerify/main.swift` 和 `Scripts/verify_phase2.sh`。
- 在新阶段2 worktree 执行 `pod install`，建立可构建依赖基线。
- 新增 `SafetyGuardRequest/Response/Audit` 与 `SafetyGuardClient`，建立服务端 guard 接入骨架。
- 新增 `MemoryPrivacyScope`、`MemoryUseSurface`、`PrivacyScopePolicy` 和 migration helper。
- 新增 `Scripts/SafetyGuardVerify/main.swift`、`Scripts/PrivacyScopeVerify/main.swift`，并接入阶段2统一验证脚本。
- 新增 `ConversationTurn.privacyMetadata` 与 `Stage1MailboxMemoryInput.privacyMetadata`，旧数据缺字段时默认 `.localOnly`。
- `KBLiteGraph.version` 升至 2，`KBPerson/KBPlace/KBEvent/KBFact` 增加 privacy metadata。
- 新增 `KBLitePrivacyScopePolicy`，KBLite 远端提取只允许 `.generationAllowed` transcript，prompt context 过滤不可用实体。
- 新增 `DeepSeekSafetyGuarding`，DeepSeek chat/knowledge/image、Memoir 生成、Memoir TTS 发起前执行 guard。

## 最新验证

执行：

```bash
bash Scripts/verify_phase2.sh
```

结果：

- `SafetyMonitor verification: 10/10 passed`
- `TimeMailbox verification passed`
- `MemoryArchive verification passed`
- `CareDashboard verification passed`
- `KBLite 验收结果: 32/32 通过`
- `DreamJourney.xcodeproj/project.pbxproj: OK`
- iPhoneOS Debug build: `** BUILD SUCCEEDED **`
- `MockDialogEngine verification passed`
- `SafetyGuard verification: 4/4 passed`
- `PrivacyScope verification passed`
- `MemoryPrivacyIntegration verification passed`
- `RemoteSafetyGuard verification passed`
- `MockDialogEngine simulator typecheck` 通过
- `git diff --check` / `git diff --cached --check` 通过

## 下一步

1. 接入真实 `/v1/safety/evaluate` transport 或阶段2 mock allow transport；当前默认 fail-closed 会阻断远端 DeepSeek/TTS 功能。
2. 推进 export/widget/PDF/family/care 的 sanitized 输出改造。
3. 为 `MemoryArchive`、`TimeMailbox`、普通对话 UI 增加显式 scope 授权选择。
4. 处理完整 Simulator app build 的 `SpeechEngineToB` slice 阻断。
