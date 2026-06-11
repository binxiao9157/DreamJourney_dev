# Phase 2 Scope Guard Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 接入阶段2第二批基线：让对话/KBLite 携带 privacy scope，并让 DeepSeek/Memoir/Image 远端入口具备 SafetyGuard fail-closed 包装。

**Architecture:** 两条并行主线。Memory worker 只负责 `ConversationMemory`、`Stage1MemoryFacade`、`KBLiteModels`、`KBLitePrivacyScopePolicy`、`KBLiteManager` 和对应验证；Remote worker 只负责 `DeepSeekSafetyGuarding`、`DeepSeekService`/Memoir/TTS guard wrapper 和对应验证。主控 agent 负责 Xcode 工程索引、`verify_phase2.sh` 串联、完整 build 和最终提交。

**Tech Stack:** Swift, UIKit app target, CocoaPods/Xcode project, pure `xcrun swiftc` verification scripts, existing `SafetyGuardClient` and `MemoryPrivacyScope`.

---

## File Structure

- `DreamJourney/Sources/Services/ConversationMemoryManager.swift`: `ConversationTurn` 增加 `privacyMetadata`，record 方法增加兼容重载。
- `DreamJourney/Sources/Services/Stage1MemoryFacade.swift`: `Stage1MailboxMemoryInput` 增加 `privacyMetadata`，提供显式 scope 入口。
- `DreamJourney/Sources/Services/KBLiteModels.swift`: `KBLiteGraph.version = 2`，KB 实体增加 `privacyMetadata`。
- `DreamJourney/Sources/Services/KBLitePrivacyScopePolicy.swift`: 提供纯 Swift 可验证的 KBLite scope helper。
- `DreamJourney/Sources/Services/KBLiteManager.swift`: remote extraction 前按 `KBLitePrivacyScopePolicy` 过滤；quick extract/merge 写入 scope metadata。
- `Scripts/MemoryPrivacyIntegrationVerify/main.swift`: 验证 scoped turn、KBLite v2 decode、remote extraction 过滤策略。
- `DreamJourney/Sources/Memoir/DeepSeekSafetyGuarding.swift`: 提供纯 Swift 可验证的 DeepSeek/Memoir remote guard helper。
- `DreamJourney/Sources/Memoir/DeepSeekService.swift`: 使用 `DeepSeekSafetyGuarding` 保护 chat/knowledge/image 请求。
- `DreamJourney/Sources/Memoir/MemoirService.swift`: 回忆录生成入口使用 guarded chat。
- `DreamJourney/Sources/Memoir/MemoirTTSService.swift`: TTS 输入进入 guard 前置检查。
- `Scripts/RemoteSafetyGuardVerify/main.swift`: 验证 allow 放行、high/unavailable 阻断。
- `DreamJourney.xcodeproj/project.pbxproj`: 主控集成新增脚本无须入 Xcode；生产源码变更需要确保 app target build 通过。
- `Scripts/verify_phase2.sh`: 主控追加两个验证脚本。
- `docs/superpowers/reports/2026-06-11-phase2-progress.md`: 主控更新完成度和剩余风险。

---

### Task 1: Memory/KBLite Privacy Scope Integration

**Files:**
- Modify: `DreamJourney/Sources/Services/ConversationMemoryManager.swift`
- Modify: `DreamJourney/Sources/Services/Stage1MemoryFacade.swift`
- Modify: `DreamJourney/Sources/Services/KBLiteModels.swift`
- Create: `DreamJourney/Sources/Services/KBLitePrivacyScopePolicy.swift`
- Modify: `DreamJourney/Sources/Services/KBLiteManager.swift`
- Create: `Scripts/MemoryPrivacyIntegrationVerify/main.swift`

- [ ] **Step 1: Write the failing verification script**

Create `Scripts/MemoryPrivacyIntegrationVerify/main.swift` with assertions for these behaviors:

```swift
import Foundation

private func assertCondition(_ condition: @autoclosure () -> Bool, _ message: String) {
    guard condition() else {
        fputs("FAIL: \(message)\n", stderr)
        exit(1)
    }
}

let localTurnJSON = """
{"role":"user","text":"只在本机聊聊","timestamp":0}
""".data(using: .utf8)!

let decodedLegacyTurn = try JSONDecoder().decode(ConversationTurn.self, from: localTurnJSON)
assertCondition(decodedLegacyTurn.privacyMetadata.scope == .localOnly, "legacy turn should default to localOnly")

let generationInput = Stage1MailboxMemoryInput(
    text: "可以用于生成的上海工作记忆",
    privacyMetadata: MemoryPrivacyMetadata(scope: .generationAllowed)
)
assertCondition(generationInput.privacyMetadata.scope == .generationAllowed, "input should carry explicit generation scope")

let scopedTurns = [
    ConversationTurn(role: "user", text: "私密内容", timestamp: Date(), privacyMetadata: MemoryPrivacyMetadata(scope: .privateOnly)),
    ConversationTurn(role: "user", text: "本机内容", timestamp: Date(), privacyMetadata: MemoryPrivacyMetadata(scope: .localOnly)),
    ConversationTurn(role: "user", text: "可生成内容", timestamp: Date(), privacyMetadata: MemoryPrivacyMetadata(scope: .generationAllowed))
]
let remoteTurns = KBLitePrivacyScopePolicy.remoteExtractableTurns(from: scopedTurns)
assertCondition(remoteTurns.map(\\.text) == ["可生成内容"], "only generationAllowed turns should enter remote extraction")

var person = KBPerson(id: "p1", name: "爷爷", aliases: [], relation: nil, traits: [], sourceSessionIds: [1], createdAt: Date(), updatedAt: Date())
assertCondition(person.privacyMetadata.scope == .localOnly, "new KBPerson should default to localOnly")
person.privacyMetadata = MemoryPrivacyMetadata(scope: .generationAllowed)
assertCondition(PrivacyScopePolicy.canUse(metadata: person.privacyMetadata, surface: .prompt), "generation KBPerson should be prompt-usable")

let legacyGraphJSON = """
{"version":1,"lastUpdated":0,"sessionCount":0,"people":[],"places":[],"events":[],"facts":[]}
""".data(using: .utf8)!
let graph = try JSONDecoder().decode(KBLiteGraph.self, from: legacyGraphJSON)
assertCondition(graph.version == 2, "decoded graph should migrate to v2 in memory")

print("MemoryPrivacyIntegration verification passed")
```

- [ ] **Step 2: Run the verification to see RED**

Run:

```bash
xcrun swiftc \
  DreamJourney/Sources/Services/Privacy/MemoryPrivacyScope.swift \
  DreamJourney/Sources/Services/ConversationMemoryManager.swift \
  DreamJourney/Sources/Services/Stage1MemoryFacade.swift \
  DreamJourney/Sources/Services/KBLiteModels.swift \
  DreamJourney/Sources/Services/KBLitePrivacyScopePolicy.swift \
  Scripts/MemoryPrivacyIntegrationVerify/main.swift \
  -o /tmp/dreamjourney_memory_privacy_integration_verify
```

Expected: FAIL because `ConversationTurn.privacyMetadata`, `Stage1MailboxMemoryInput.privacyMetadata`, or `KBLiteManager.remoteExtractableTurns` does not exist.

- [ ] **Step 3: Implement minimal model changes**

Add `privacyMetadata` to `ConversationTurn` with custom `init(from:)` defaulting missing metadata to `.localOnly`. Add explicit initializer:

```swift
init(
    role: String,
    text: String,
    timestamp: Date,
    privacyMetadata: MemoryPrivacyMetadata = MemoryPrivacyMetadata(scope: .localOnly)
) {
    self.role = role
    self.text = text
    self.timestamp = timestamp
    self.privacyMetadata = privacyMetadata
}
```

Update `recordUserTurn`/`recordAITurn` to accept optional metadata and keep old callers working:

```swift
func recordUserTurn(text: String, privacyMetadata: MemoryPrivacyMetadata = MemoryPrivacyMetadata(scope: .localOnly))
func recordAITurn(text: String, privacyMetadata: MemoryPrivacyMetadata = MemoryPrivacyMetadata(scope: .localOnly))
```

Update `Stage1MailboxMemoryInput`:

```swift
let privacyMetadata: MemoryPrivacyMetadata
```

with default `.localOnly`.

- [ ] **Step 4: Implement KBLite scope defaults and filtering**

Set `KBLiteGraph.version` to 2 and decode old graph version as 2. Add `privacyMetadata` to `KBPerson`, `KBPlace`, `KBEvent`, `KBFact` with default `.localOnly`.

Add:

```swift
enum KBLitePrivacyScopePolicy {
    static func remoteExtractableTurns(from turns: [ConversationTurn]) -> [ConversationTurn] {
        turns.filter {
            PrivacyScopePolicy.canUse(metadata: $0.privacyMetadata, surface: .remoteExtraction)
        }
    }

    static func localExtractableTurns(from turns: [ConversationTurn]) -> [ConversationTurn] {
        turns.filter { $0.privacyMetadata.scope != .privateOnly }
    }
}
```

Use this helper before remote LLM extraction. If no remote-allowed turns exist, skip DeepSeek and run `quickExtract` on non-private local turns only.

- [ ] **Step 5: Run verification GREEN**

Run:

```bash
xcrun swiftc \
  DreamJourney/Sources/Services/Privacy/MemoryPrivacyScope.swift \
  DreamJourney/Sources/Services/ConversationMemoryManager.swift \
  DreamJourney/Sources/Services/Stage1MemoryFacade.swift \
  DreamJourney/Sources/Services/KBLiteModels.swift \
  DreamJourney/Sources/Services/KBLitePrivacyScopePolicy.swift \
  Scripts/MemoryPrivacyIntegrationVerify/main.swift \
  -o /tmp/dreamjourney_memory_privacy_integration_verify && \
  /tmp/dreamjourney_memory_privacy_integration_verify
```

Expected: `MemoryPrivacyIntegration verification passed`.

---

### Task 2: Remote SafetyGuard Wrapper

**Files:**
- Modify: `DreamJourney/Sources/Memoir/DeepSeekService.swift`
- Create: `DreamJourney/Sources/Memoir/DeepSeekSafetyGuarding.swift`
- Modify: `DreamJourney/Sources/Memoir/MemoirService.swift`
- Modify: `DreamJourney/Sources/Memoir/MemoirTTSService.swift`
- Create: `Scripts/RemoteSafetyGuardVerify/main.swift`

- [ ] **Step 1: Write the failing verification script**

Create `Scripts/RemoteSafetyGuardVerify/main.swift` with mock transport and no network:

```swift
import Foundation

private func assertCondition(_ condition: @autoclosure () -> Bool, _ message: String) {
    guard condition() else {
        fputs("FAIL: \(message)\n", stderr)
        exit(1)
    }
}

private final class AllowTransport: SafetyGuardTransport {
    func evaluate(_ request: SafetyGuardRequest) throws -> SafetyGuardResponse {
        SafetyGuardResponse(
            decisionID: "allow",
            riskLevel: .safe,
            action: .allow,
            categories: [],
            policyVersion: "safety-2026-06-11",
            reasonCode: "SAFE",
            safeReplacementKey: nil,
            canPersist: true,
            canSendToLLM: true,
            canSendToTTS: true,
            canShowInFamilyDashboard: false,
            audit: SafetyGuardAudit(rawContentStored: false, contentHMACSHA256: nil, contentLength: request.text?.count ?? 0, evaluatedAt: "2026-06-11T00:00:00Z", latencyMS: 1)
        )
    }
}

let allowGuard = SafetyGuardClient(transport: AllowTransport())
let chatDecision = DeepSeekSafetyGuarding.guardDecision(
    text: "普通回忆",
    surface: .memoir,
    stage: .userInputPreLLM,
    target: .deepseek,
    guardClient: allowGuard
)
assertCondition(chatDecision.canSendToLLM, "allow guard should permit LLM")

let blockedDecision = DeepSeekSafetyGuarding.guardDecision(
    text: "我不想活了",
    surface: .memoir,
    stage: .userInputPreLLM,
    target: .deepseek,
    guardClient: allowGuard
)
assertCondition(!blockedDecision.canSendToLLM, "local high should block LLM")
assertCondition(blockedDecision.action == .block || blockedDecision.action == .escalate, "local high should block or escalate")

print("RemoteSafetyGuard verification passed")
```

- [ ] **Step 2: Run RED**

Run:

```bash
xcrun swiftc \
  DreamJourney/Sources/Services/Safety/SafetyModels.swift \
  DreamJourney/Sources/Services/Safety/SafetyMonitor.swift \
  DreamJourney/Sources/Services/Safety/SafetyGuardModels.swift \
  DreamJourney/Sources/Services/Safety/SafetyGuardClient.swift \
  DreamJourney/Sources/Memoir/DeepSeekSafetyGuarding.swift \
  Scripts/RemoteSafetyGuardVerify/main.swift \
  -o /tmp/dreamjourney_remote_safety_guard_verify
```

Expected: FAIL because `DeepSeekSafetyGuarding.guardDecision(text:surface:stage:target:guardClient:)` is missing.

- [ ] **Step 3: Implement guard helper**

Add a pure Swift helper that builds a `SafetyGuardRequest` and returns `SafetyGuardResponse`:

```swift
enum DeepSeekSafetyGuarding {
    static func guardDecision(
        text: String,
        surface: SafetyGuardSurface,
        stage: SafetyGuardStage,
        target: SafetyGuardTarget,
        guardClient: SafetyGuardClient
    ) -> SafetyGuardResponse {
        let request = SafetyGuardRequest(
            requestID: UUID().uuidString,
            clientEventID: UUID().uuidString,
            sessionID: "local-session",
            userIDHash: "local-user",
            deviceIDHash: "local-device",
            surface: surface,
            stage: stage,
            contentType: .text,
            text: text,
            mediaRef: nil,
            locale: "zh-CN",
            sdkEventType: nil,
            target: target,
            noStoreRaw: true
        )
        return guardClient.evaluate(request)
    }
}
```

- [ ] **Step 4: Wire guarded paths**

Before remote chat/extract/image request construction, call the guard helper. If the response does not allow the target capability, complete with `.failure(.invalidResponse)` and do not issue `AF.request`.

For TTS, block when `canSendToTTS == false`.

- [ ] **Step 5: Run GREEN**

Run:

```bash
xcrun swiftc \
  DreamJourney/Sources/Services/Safety/SafetyModels.swift \
  DreamJourney/Sources/Services/Safety/SafetyMonitor.swift \
  DreamJourney/Sources/Services/Safety/SafetyGuardModels.swift \
  DreamJourney/Sources/Services/Safety/SafetyGuardClient.swift \
  DreamJourney/Sources/Memoir/DeepSeekSafetyGuarding.swift \
  Scripts/RemoteSafetyGuardVerify/main.swift \
  -o /tmp/dreamjourney_remote_safety_guard_verify && \
  /tmp/dreamjourney_remote_safety_guard_verify
```

Expected: `RemoteSafetyGuard verification passed`.

---

### Task 3: Controller Integration and Verification

**Files:**
- Modify: `DreamJourney.xcodeproj/project.pbxproj`
- Modify: `Scripts/verify_phase2.sh`
- Modify: `docs/superpowers/reports/2026-06-11-phase2-progress.md`

- [ ] **Step 1: Add any new production Swift files to Xcode project**

Only production files under `DreamJourney/Sources/**` need pbxproj source entries.

- [ ] **Step 2: Add verification scripts to `Scripts/verify_phase2.sh`**

Add:

```bash
echo "== MemoryPrivacyIntegration =="
xcrun swiftc \
  DreamJourney/Sources/Services/Privacy/MemoryPrivacyScope.swift \
  DreamJourney/Sources/Services/ConversationMemoryManager.swift \
  DreamJourney/Sources/Services/Stage1MemoryFacade.swift \
  DreamJourney/Sources/Services/KBLiteModels.swift \
  DreamJourney/Sources/Services/KBLitePrivacyScopePolicy.swift \
  Scripts/MemoryPrivacyIntegrationVerify/main.swift \
  -o /tmp/dreamjourney_memory_privacy_integration_verify
/tmp/dreamjourney_memory_privacy_integration_verify

echo "== RemoteSafetyGuard =="
xcrun swiftc \
  DreamJourney/Sources/Services/Safety/SafetyModels.swift \
  DreamJourney/Sources/Services/Safety/SafetyMonitor.swift \
  DreamJourney/Sources/Services/Safety/SafetyGuardModels.swift \
  DreamJourney/Sources/Services/Safety/SafetyGuardClient.swift \
  DreamJourney/Sources/Memoir/DeepSeekSafetyGuarding.swift \
  Scripts/RemoteSafetyGuardVerify/main.swift \
  -o /tmp/dreamjourney_remote_safety_guard_verify
/tmp/dreamjourney_remote_safety_guard_verify
```

- [ ] **Step 3: Run full verification**

Run:

```bash
bash Scripts/verify_phase2.sh
```

Expected:

- `SafetyMonitor verification: 10/10 passed`
- `KBLite 验收结果: 32/32 通过`
- iPhoneOS Debug build: `** BUILD SUCCEEDED **`
- `MockDialogEngine verification passed`
- `SafetyGuard verification: 4/4 passed`
- `PrivacyScope verification passed`
- `MemoryPrivacyIntegration verification passed`
- `RemoteSafetyGuard verification passed`
- `MockDialogEngine simulator typecheck` exits 0
- `git diff --check` exits 0

- [ ] **Step 4: Commit and push**

Run:

```bash
git add DreamJourney.xcodeproj/project.pbxproj Scripts/verify_phase2.sh docs/superpowers/reports/2026-06-11-phase2-progress.md DreamJourney/Sources Scripts
git commit -m "feat: integrate phase 2 scope and guard flows"
git push
```
