# DreamJourney 阶段2进度汇总

日期：2026-06-11

分支：`feature/phase2-mock-dialog-engine`

基线：`feature/phase1-integrated-mvp`

## 当前完成度

| 开发包 | 完成度 | 状态 |
| --- | ---: | --- |
| Mock/Simulator 基线 | 80% | `MockDialogEngine` 已实现，纯 Swift 验证、iPhoneOS build、simulator SDK typecheck 通过；完整 Simulator app build 仍受 `SpeechEngineToB` slice 影响，后续需独立 smoke target 或 Pod 条件化。 |
| Safety Guard 合约 | 35% | 只读 agent 已产出服务端合约和 iOS 接入点，已固化到 `docs/superpowers/specs/2026-06-11-safety-guard-contract.md`。 |
| Privacy Scope 模型 | 35% | 只读 agent 已完成端到端隐私审计，已固化到 `docs/superpowers/specs/2026-06-11-memory-privacy-scope.md`。 |
| KBLite/Export/Widget 过滤 | 0% | 等 privacy scope 数据模型进入代码后开始。 |
| CareDashboard/Family Sync 阶段2 | 0% | 等 scope 和家庭授权模型进入代码后开始。 |

## 已完成

- 抽出 `DialogEndReason` 和 `DialogEngineDelegate` 到 `DialogEngineModels.swift`，解除 mock 验证对火山 SDK manager 的依赖。
- 新增 `MockDialogEngine`，支持 setup/start/stop/destroy、确定性回复、高风险触发危机结束。
- `DialogEngineFactory` 新增 `.mock` 和 `makeDefault(arguments:environment:)`。
- `AIRecordingViewController` 改用 `DialogEngineFactory.makeDefault()`。
- 新增 `Scripts/MockDialogEngineVerify/main.swift` 和 `Scripts/verify_phase2.sh`。
- 在新阶段2 worktree 执行 `pod install`，建立可构建依赖基线。

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
- `MockDialogEngine simulator typecheck` 通过
- `git diff --check` / `git diff --cached --check` 通过

## 下一步

1. 提交并推送 `feature/phase2-mock-dialog-engine`。
2. 新建 Safety Guard 客户端骨架任务。
3. 新建 Privacy Scope 数据模型任务。
4. 再开 Memory/KBLite agent，基于 scope 模型改造 sanitized graph。
