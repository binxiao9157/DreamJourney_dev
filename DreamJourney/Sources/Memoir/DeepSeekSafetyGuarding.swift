import Foundation

enum DeepSeekSafetyGuarding {
    static func makeDefaultClient(
        arguments: [String] = ProcessInfo.processInfo.arguments,
        environment: [String: String] = ProcessInfo.processInfo.environment
    ) -> SafetyGuardClient {
        if isMockAllowEnabled(arguments: arguments, environment: environment) {
            return SafetyGuardClient(transport: DeepSeekSafetyGuardMockAllowTransport())
        }
        return SafetyGuardClient(transport: DeepSeekSafetyGuardUnavailableTransport())
    }

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

    private static func isMockAllowEnabled(
        arguments: [String],
        environment: [String: String]
    ) -> Bool {
        arguments.contains("--use-mock-safety-guard") ||
            environment["DREAMJOURNEY_SAFETY_GUARD"]?.lowercased() == "mock_allow"
    }
}

enum DeepSeekSafetyGuardUnavailableTransportError: Error {
    case unavailable
}

final class DeepSeekSafetyGuardUnavailableTransport: SafetyGuardTransport {
    func evaluate(_ request: SafetyGuardRequest) throws -> SafetyGuardResponse {
        throw DeepSeekSafetyGuardUnavailableTransportError.unavailable
    }
}

final class DeepSeekSafetyGuardMockAllowTransport: SafetyGuardTransport {
    func evaluate(_ request: SafetyGuardRequest) throws -> SafetyGuardResponse {
        SafetyGuardResponse(
            decisionID: "mock-\(request.requestID)",
            riskLevel: .safe,
            action: .allow,
            categories: ["mock_allow"],
            policyVersion: "safety-2026-06-11",
            reasonCode: "MOCK_ALLOW",
            safeReplacementKey: nil,
            canPersist: true,
            canSendToLLM: request.target == .deepseek || request.target == .volcengineDialog,
            canSendToTTS: request.target == .volcengineTTS,
            canShowInFamilyDashboard: false,
            audit: SafetyGuardAudit(
                rawContentStored: false,
                contentHMACSHA256: nil,
                contentLength: request.text?.count ?? 0,
                evaluatedAt: ISO8601DateFormatter().string(from: Date()),
                latencyMS: 0
            )
        )
    }
}
