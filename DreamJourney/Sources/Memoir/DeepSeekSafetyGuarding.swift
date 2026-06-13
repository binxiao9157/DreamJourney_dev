import Foundation

enum DeepSeekSafetyGuarding {
    static func makeDefaultClient(
        arguments: [String] = ProcessInfo.processInfo.arguments,
        environment: [String: String] = ProcessInfo.processInfo.environment,
        bundle: Bundle = .main,
        httpClient: (any SafetyGuardHTTPClient)? = nil
    ) -> SafetyGuardClient {
        if isMockAllowEnabled(arguments: arguments, environment: environment) ||
            isRoadshowOfflineModeEnabled(arguments: arguments, environment: environment) {
            return SafetyGuardClient(transport: DeepSeekSafetyGuardMockAllowTransport())
        }
        if let baseURL = configuredSafetyGuardBaseURL(environment: environment, bundle: bundle) {
            return SafetyGuardClient(
                transport: SafetyGuardHTTPTransport(
                    baseURL: baseURL,
                    apiKey: configuredSafetyGuardAPIKey(environment: environment, bundle: bundle),
                    httpClient: httpClient
                )
            )
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

    private static func isRoadshowOfflineModeEnabled(
        arguments: [String],
        environment: [String: String]
    ) -> Bool {
        let offlineValue = environment["DREAMJOURNEY_ROADSHOW_OFFLINE"]?.lowercased()
        return arguments.contains("--roadshow-offline-mode") ||
            offlineValue == "1" ||
            offlineValue == "true"
    }

    private static func configuredSafetyGuardBaseURL(
        environment: [String: String],
        bundle: Bundle
    ) -> URL? {
        let rawValue = environment["DREAMJOURNEY_SAFETY_GUARD_BASE_URL"]
            ?? environment["DREAMJOURNEY_SAFETY_GUARD_URL"]
            ?? AppConfiguration.string(forKey: "SafetyGuardBaseURL", infoDictionary: bundle.infoDictionary)
        return trimmedURL(from: rawValue)
    }

    private static func configuredSafetyGuardAPIKey(
        environment: [String: String],
        bundle: Bundle
    ) -> String? {
        let rawValue = environment["DREAMJOURNEY_SAFETY_GUARD_API_KEY"]
            ?? AppConfiguration.string(forKey: "SafetyGuardAPIKey", infoDictionary: bundle.infoDictionary)
        let trimmed = rawValue?.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let trimmed, !trimmed.isEmpty else {
            return nil
        }
        return trimmed
    }

    private static func trimmedURL(from rawValue: String?) -> URL? {
        let trimmed = rawValue?.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let trimmed, !trimmed.isEmpty else {
            return nil
        }
        return URL(string: trimmed)
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
