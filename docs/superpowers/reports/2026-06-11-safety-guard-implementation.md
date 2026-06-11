# Safety Guard Implementation Report

日期：2026-06-11

分支：`feature/phase2-mock-dialog-engine`

## 变更范围

- 新增 `SafetyGuardRequest`、`SafetyGuardResponse`、`SafetyGuardAudit` 和合约枚举模型，显式映射 snake_case JSON 字段。
- 新增 `SafetyGuardClient`，支持注入 `SafetyGuardTransport`。
- 接入本地 `SafetyMonitor` quick check：本地 high 文本不调用 transport，直接返回阻断/升级响应。
- 远端 target 在 guard transport 不可用时 fail closed，禁止发送到 LLM/TTS。
- 审计模型不包含原文，所有本地生成响应均设置 `raw_content_stored=false`。
- 新增纯 Swift 验证脚本覆盖 safe allow、本地 high 短路、transport unavailable fail closed、snake_case 编解码。

## TDD 记录

RED：

```sh
xcrun swiftc DreamJourney/Sources/Services/Safety/SafetyModels.swift DreamJourney/Sources/Services/Safety/SafetyMonitor.swift DreamJourney/Sources/Services/Safety/SafetyGuardModels.swift DreamJourney/Sources/Services/Safety/SafetyGuardClient.swift Scripts/SafetyGuardVerify/main.swift -o /tmp/dreamjourney_safety_guard_verify && /tmp/dreamjourney_safety_guard_verify
```

结果：失败，编译器报告 `SafetyGuardRequest`、`SafetyGuardResponse`、`SafetyGuardTransport`、`SafetyGuardClient` 等类型缺失。

GREEN：

```sh
xcrun swiftc DreamJourney/Sources/Services/Safety/SafetyModels.swift DreamJourney/Sources/Services/Safety/SafetyMonitor.swift DreamJourney/Sources/Services/Safety/SafetyGuardModels.swift DreamJourney/Sources/Services/Safety/SafetyGuardClient.swift Scripts/SafetyGuardVerify/main.swift -o /tmp/dreamjourney_safety_guard_verify && /tmp/dreamjourney_safety_guard_verify
```

结果：

```text
PASS: safe allow
PASS: local high short-circuit
PASS: transport unavailable fail closed
PASS: snake_case JSON decode/encode
SafetyGuard verification: 4/4 passed
```
