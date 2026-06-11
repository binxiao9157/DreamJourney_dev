# DreamJourney 阶段2进度汇总

日期：2026-06-11

分支：`feature/phase2-mock-dialog-engine`

基线：`feature/phase1-integrated-mvp`

## 当前完成度

| 开发包 | 完成度 | 状态 |
| --- | ---: | --- |
| Mock/Simulator 基线 | 80% | `MockDialogEngine` 已实现，纯 Swift 验证、iPhoneOS build、simulator SDK typecheck 通过；完整 Simulator app build 仍受 `SpeechEngineToB` slice 影响，后续需独立 smoke target 或 Pod 条件化。 |
| Safety Guard 合约 | 70% | 合约和 iOS client 已固化；DeepSeek chat/knowledge/image、Memoir、TTS 入口默认 fail-closed，并支持显式 mock allow 演示开关。 |
| Privacy Scope 模型 | 80% | `ConversationTurn`、`Stage1MailboxMemoryInput`、MemoryArchive、TimeMailbox、KBLite v2 实体已携带 `privacyMetadata`，旧数据可迁移到保守默认 scope。 |
| KBLite/Export/Widget 过滤 | 70% | KBLite remote extraction、prompt context、JSON export、Widget App Group、PDF 输入图谱、backend sync 已按 scope 过滤；MemoryArchive 可显式授予 generation/family scope。 |
| CareDashboard/Family Sync 阶段2 | 35% | Family share package、FamilyRepository 已改用 familyCircle sanitized graph；CareDashboard transcript 入口已按 `.careDashboard` 过滤，只允许 familyCircle。 |

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
- 新增 SafetyGuard mock allow 选择器：默认仍 fail-closed，使用 `--use-mock-safety-guard` 或 `DREAMJOURNEY_SAFETY_GUARD=mock_allow` 时才允许阶段2远端演示。
- 新增 `KBLitePrivacyScopePolicy.sanitizedGraph`，按 `MemoryUseSurface` 裁剪 KBLite graph 并清理人物、地点、事件、事实之间的悬挂引用。
- `KBLiteManager.exportJSON(surface:)`、Widget App Group 输出、OpenAvatar backend sync、KBLite PDF 输入图谱已统一走 sanitized graph；当前 `.export`、`.widget`、`.backendSync` 在未显式授权前保持空输出。
- Family share package 和 `FamilyRepository` 改用 `.familySync` sanitized graph，只允许 `familyCircle` 进入家庭同步/亲属圈自动同步。
- MemoryArchive 和 TimeMailbox 模型新增 `privacyMetadata`，旧数据迁移为保守 scope；MemoryArchive 文本/照片、TimeMailbox 写信 UI 已支持显式选择私密/本机/可生成/亲友范围。
- MemoryArchive 保存到 Stage1 对话记忆和图片分析入 KBLite 时保留用户选择的 scope；照片只有 `.generationAllowed` 才触发远端图片分析。
- CareDashboard 读取当前 transcript 前按 `.careDashboard` 过滤，默认 localOnly 对话不进入家庭关怀看板统计。

## 最新验证

执行：

```bash
bash Scripts/verify_phase2.sh
```

结果：

- `SafetyMonitor verification: 10/10 passed`
- `TimeMailbox verification passed`，覆盖 mailbox scope 持久化和旧信件默认 localOnly 迁移。
- `MemoryArchive verification passed`，覆盖 archive scope 持久化、旧数据迁移、generation photo pending、family photo 不远端分析。
- `CareDashboard verification passed`
- `KBLite 验收结果: 32/32 通过`
- `DreamJourney.xcodeproj/project.pbxproj: OK`
- iPhoneOS Debug build: `** BUILD SUCCEEDED **`
- `MockDialogEngine verification passed`
- `SafetyGuard verification: 4/4 passed`
- `PrivacyScope verification passed`
- `MemoryPrivacyIntegration verification passed`，覆盖 graph-level sanitized 输出、family/export/widget/backend/care surface 过滤、CareDashboard family-only transcript 和关系引用清理。
- `RemoteSafetyGuard verification passed`，覆盖 default fail-closed、env/launch arg mock allow、本地 high 阻断。
- `MockDialogEngine simulator typecheck` 通过
- `git diff --check` / `git diff --cached --check` 通过

## 下一步

1. 接入真实 `/v1/safety/evaluate` transport；当前 mock allow 只用于阶段2演示，不是生产安全方案。
2. 为普通对话 UI 增加显式 scope 授权选择，并决定 export/widget/backend 是否需要新的显式授权 scope。
3. 补 Family/CareDashboard 的家庭授权模型、成员级可见性和端到端 UI 验证。
4. 处理完整 Simulator app build 的 `SpeechEngineToB` slice 阻断。
