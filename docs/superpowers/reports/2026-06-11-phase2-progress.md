# DreamJourney 阶段2进度汇总

日期：2026-06-11

分支：`feature/phase2-mock-dialog-engine`

基线：`feature/phase1-integrated-mvp`

## 当前完成度

| 开发包 | 完成度 | 状态 |
| --- | ---: | --- |
| Mock/Simulator 基线 | 80% | `MockDialogEngine` 已实现，纯 Swift 验证、iPhoneOS build、simulator SDK typecheck 通过；完整 Simulator app build 仍受 `SpeechEngineToB` slice 影响，后续需独立 smoke target 或 Pod 条件化。 |
| Safety Guard 合约 | 55% | 合约已固化；新增 iOS 端 `SafetyGuardClient`/模型骨架，覆盖本地 high 短路、远端 guard 不可用 fail closed、snake_case 编解码验证。 |
| Privacy Scope 模型 | 55% | 审计与 scope 规格已固化；新增 `MemoryPrivacyScope`/`PrivacyScopePolicy` 最小模型，覆盖 scope policy、sanitized 过滤、旧 `isPrivate` 迁移验证。 |
| KBLite/Export/Widget 过滤 | 0% | 等 privacy scope 数据模型进入代码后开始。 |
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
- `MockDialogEngine simulator typecheck` 通过
- `git diff --check` / `git diff --cached --check` 通过

## 下一步

1. 提交并推送阶段2第二批 Safety/Privacy 基线。
2. 开始 Memory/KBLite agent：把 scope metadata 接入 `ConversationMemory` 与 `KBLiteGraph`。
3. 开始 DeepSeek/图片/回忆录 agent：在远端模型入口前接入 `SafetyGuardClient`。
4. 再推进 export/widget/care/family 的 sanitized 输出改造。
