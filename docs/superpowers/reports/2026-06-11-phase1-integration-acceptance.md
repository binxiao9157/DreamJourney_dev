# DreamJourney 阶段1集成验收与风险报告

日期：2026-06-11

主控分支：`feature/phase1-integrated-mvp`

基线提交：`90ecc63819e2f6da2fb8acad979a095932804b87`

## 集成范围

- 安全兜底：`SafetyMonitor`、危机干预页、危机会话不写入记忆或回忆录。
- 记忆统一入口：`Stage1MemoryFacade` 接入主页、对话引擎、回忆录、知识库和同步入口。
- 时空信箱：本地信件、延迟投递、边界回复、高风险拦截；信件正文默认不进入全局记忆。
- 记忆档案馆：文本/照片素材本地归档；私密素材不进入 Stage1/KBLite，照片分析需要明确选择。
- 长辈关怀看板：基于真实对话生成脱敏信号；空数据展示“数据不足”，不显示“状态稳定”。
- 工程验证：新增源码加入 Xcode target，提供一键验收脚本。

## 一键验证

```bash
bash Scripts/verify_phase1.sh
```

脚本包含：

- `SafetyMonitor` 纯逻辑验证。
- `TimeMailbox` 纯逻辑验证。
- `MemoryArchive` 纯逻辑验证。
- `CareDashboard` 纯逻辑验证。
- `swift kblite_verify.swift`。
- `git diff --check` 和 `git diff --cached --check`。
- `plutil -lint DreamJourney.xcodeproj/project.pbxproj`。
- `xcodebuild -workspace DreamJourney.xcworkspace -scheme DreamJourney -sdk iphoneos -configuration Debug CODE_SIGNING_ALLOWED=NO build`。

## 审查反馈收敛

- 无 Critical。
- 已补仓库内一键验证脚本，避免接手方手动拼命令。
- 已补仓库内阶段1验收报告。
- 已统一 `SafetyVerify` 的失败输出。
- 已补危机会话 transcript 丢弃和回忆录边界。
- 已收紧信箱/档案馆默认隐私策略。
- 已补关怀看板空数据状态。

## 已知限制

- Simulator 构建受 `SpeechEngineToB` 二进制模拟器 slice 限制影响；本轮以 iPhoneOS Debug build 作为工程 gate。
- SDK 事件 `SEEventChatTextQueryConfirmed` 可能已在远端 LLM 前后发生，本地只能保证 UI/TTS/记忆链路阻断；需补服务端 safety guard 或 SDK 前置拦截能力。
- Apple 免费语音分支尚未完整接入，当前只保留 `DialogEngineFactory` seam。
- 关怀看板当前仅使用本机当前/最近 transcript，不含长期趋势、亲友账号、云同步和 APNs。
- 声音克隆、persona speaker 绑定、撤回和审计链路未进入本阶段实现。

## 收口状态

- [x] 只读审查 agent 已返回。
- [x] 危机会话 transcript 丢弃。
- [x] 时空信箱正文默认不写入 Stage1 记忆。
- [x] 私密档案默认不写入 Stage1/KBLite。
- [x] 空关怀数据不显示状态稳定。
- [x] 仓库内已补阶段1验收报告。
- [x] 仓库内已补一键验证脚本。
- [x] 最终一键验证已重新执行。

## 最终验证结果

2026-06-11 14:48 执行：

```bash
bash Scripts/verify_phase1.sh
```

结果：

- `SafetyMonitor verification: 10/10 passed`
- `TimeMailbox verification passed`
- `MemoryArchive verification passed`
- `CareDashboard verification passed`
- `KBLite 验收结果: 32/32 通过`
- `git diff --check` 和 `git diff --cached --check` 通过
- `DreamJourney.xcodeproj/project.pbxproj: OK`
- `** BUILD SUCCEEDED **`
