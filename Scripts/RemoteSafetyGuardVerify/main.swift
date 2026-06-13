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
            audit: SafetyGuardAudit(
                rawContentStored: false,
                contentHMACSHA256: nil,
                contentLength: request.text?.count ?? 0,
                evaluatedAt: "2026-06-11T00:00:00Z",
                latencyMS: 1
            )
        )
    }
}

private enum FailingTransportError: Error {
    case unavailable
}

private final class FailingTransport: SafetyGuardTransport {
    func evaluate(_ request: SafetyGuardRequest) throws -> SafetyGuardResponse {
        throw FailingTransportError.unavailable
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

let unavailableGuard = SafetyGuardClient(transport: FailingTransport())
let unavailableDecision = DeepSeekSafetyGuarding.guardDecision(
    text: "普通回忆",
    surface: .memoir,
    stage: .userInputPreLLM,
    target: .deepseek,
    guardClient: unavailableGuard
)
assertCondition(!unavailableDecision.canSendToLLM, "unavailable guard should fail closed for LLM")
assertCondition(!unavailableDecision.canSendToTTS, "unavailable guard should fail closed for TTS")
assertCondition(unavailableDecision.action == .block, "unavailable guard should block")
assertCondition(unavailableDecision.reasonCode == "GUARD_UNAVAILABLE", "unavailable guard should report guard unavailable")

let defaultClient = DeepSeekSafetyGuarding.makeDefaultClient(arguments: ["DreamJourney"], environment: [:])
let defaultDecision = DeepSeekSafetyGuarding.guardDecision(
    text: "普通回忆",
    surface: .memoir,
    stage: .userInputPreLLM,
    target: .deepseek,
    guardClient: defaultClient
)
assertCondition(!defaultDecision.canSendToLLM, "default safety guard client should fail closed")
assertCondition(defaultDecision.reasonCode == "GUARD_UNAVAILABLE", "default fail-closed should report guard unavailable")

let envAllowClient = DeepSeekSafetyGuarding.makeDefaultClient(
    arguments: ["DreamJourney"],
    environment: ["DREAMJOURNEY_SAFETY_GUARD": "mock_allow"]
)
let envAllowDecision = DeepSeekSafetyGuarding.guardDecision(
    text: "普通回忆",
    surface: .memoir,
    stage: .userInputPreLLM,
    target: .deepseek,
    guardClient: envAllowClient
)
assertCondition(envAllowDecision.canSendToLLM, "mock_allow environment should allow LLM")
assertCondition(envAllowDecision.action == .allow, "mock_allow environment should return allow")
assertCondition(envAllowDecision.reasonCode == "MOCK_ALLOW", "mock_allow environment should expose mock reason")

let argAllowClient = DeepSeekSafetyGuarding.makeDefaultClient(
    arguments: ["DreamJourney", "--use-mock-safety-guard"],
    environment: [:]
)
let argTTSDecision = DeepSeekSafetyGuarding.guardDecision(
    text: "普通回忆",
    surface: .tts,
    stage: .ttsInputPreSynth,
    target: .volcengineTTS,
    guardClient: argAllowClient
)
assertCondition(argTTSDecision.canSendToTTS, "mock safety launch arg should allow TTS")

let offlineArgClient = DeepSeekSafetyGuarding.makeDefaultClient(
    arguments: ["DreamJourney", "--roadshow-offline-mode"],
    environment: ["DREAMJOURNEY_SAFETY_GUARD_BASE_URL": "https://guard.example"]
)
let offlineArgDecision = DeepSeekSafetyGuarding.guardDecision(
    text: "普通回忆",
    surface: .memoir,
    stage: .userInputPreLLM,
    target: .deepseek,
    guardClient: offlineArgClient
)
assertCondition(!offlineArgDecision.canSendToLLM, "roadshow offline launch arg should not silently mock safety guard in real testing mode")
assertCondition(offlineArgDecision.reasonCode == "GUARD_UNAVAILABLE", "roadshow offline launch arg should fail closed unless mock guard is explicit")

let offlineEnvClient = DeepSeekSafetyGuarding.makeDefaultClient(
    arguments: ["DreamJourney"],
    environment: [
        "DREAMJOURNEY_ROADSHOW_OFFLINE": "true",
        "DREAMJOURNEY_SAFETY_GUARD_BASE_URL": "https://guard.example"
    ]
)
let offlineEnvDecision = DeepSeekSafetyGuarding.guardDecision(
    text: "普通回忆",
    surface: .memoir,
    stage: .userInputPreLLM,
    target: .deepseek,
    guardClient: offlineEnvClient
)
assertCondition(!offlineEnvDecision.canSendToLLM, "roadshow offline environment should not silently mock safety guard in real testing mode")
assertCondition(offlineEnvDecision.reasonCode == "GUARD_UNAVAILABLE", "roadshow offline environment should fail closed unless mock guard is explicit")

print("RemoteSafetyGuard verification passed")
