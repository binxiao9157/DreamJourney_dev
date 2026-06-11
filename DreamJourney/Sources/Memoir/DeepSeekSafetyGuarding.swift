import Foundation

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

enum DeepSeekSafetyGuardUnavailableTransportError: Error {
    case unavailable
}

final class DeepSeekSafetyGuardUnavailableTransport: SafetyGuardTransport {
    func evaluate(_ request: SafetyGuardRequest) throws -> SafetyGuardResponse {
        throw DeepSeekSafetyGuardUnavailableTransportError.unavailable
    }
}
