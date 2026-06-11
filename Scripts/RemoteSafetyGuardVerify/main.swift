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

print("RemoteSafetyGuard verification passed")
