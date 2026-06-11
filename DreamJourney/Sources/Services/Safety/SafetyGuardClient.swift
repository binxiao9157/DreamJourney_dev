import Foundation

protocol SafetyGuardTransport {
    func evaluate(_ request: SafetyGuardRequest) throws -> SafetyGuardResponse
}

final class SafetyGuardClient {
    private let transport: any SafetyGuardTransport
    private let monitor: SafetyMonitor
    private let policyVersion = "safety-2026-06-11"

    init(transport: any SafetyGuardTransport, monitor: SafetyMonitor = .shared) {
        self.transport = transport
        self.monitor = monitor
    }

    func evaluate(_ request: SafetyGuardRequest) -> SafetyGuardResponse {
        let localAssessment = monitor.evaluate(request.text ?? "")
        if localAssessment.level >= .high {
            return localHighRiskResponse(for: request)
        }

        do {
            return try transport.evaluate(request)
        } catch {
            if request.target == .localOnly {
                return localOnlyPendingResponse(for: request, assessment: localAssessment)
            }
            return guardUnavailableResponse(for: request)
        }
    }

    private func localHighRiskResponse(for request: SafetyGuardRequest) -> SafetyGuardResponse {
        SafetyGuardResponse(
            decisionID: "local-\(request.requestID)",
            riskLevel: .high,
            action: .escalate,
            categories: ["self_harm"],
            policyVersion: policyVersion,
            reasonCode: "LOCAL_HIGH_RISK",
            safeReplacementKey: "crisis_intervention_default",
            canPersist: false,
            canSendToLLM: false,
            canSendToTTS: false,
            canShowInFamilyDashboard: false,
            audit: audit(for: request, latencyMS: 0)
        )
    }

    private func guardUnavailableResponse(for request: SafetyGuardRequest) -> SafetyGuardResponse {
        SafetyGuardResponse(
            decisionID: "local-\(request.requestID)",
            riskLevel: .medium,
            action: .block,
            categories: ["guard_unavailable"],
            policyVersion: policyVersion,
            reasonCode: "GUARD_UNAVAILABLE",
            safeReplacementKey: nil,
            canPersist: false,
            canSendToLLM: false,
            canSendToTTS: false,
            canShowInFamilyDashboard: false,
            audit: audit(for: request, latencyMS: 0)
        )
    }

    private func localOnlyPendingResponse(
        for request: SafetyGuardRequest,
        assessment: SafetyAssessment
    ) -> SafetyGuardResponse {
        let isCare = assessment.level == .medium
        return SafetyGuardResponse(
            decisionID: "local-\(request.requestID)",
            riskLevel: isCare ? .medium : .safe,
            action: isCare ? .allowWithCare : .allow,
            categories: isCare ? ["local_only_pending"] : [],
            policyVersion: policyVersion,
            reasonCode: "LOCAL_ONLY_PENDING",
            safeReplacementKey: nil,
            canPersist: true,
            canSendToLLM: false,
            canSendToTTS: false,
            canShowInFamilyDashboard: false,
            audit: audit(for: request, latencyMS: 0)
        )
    }

    private func audit(for request: SafetyGuardRequest, latencyMS: Int) -> SafetyGuardAudit {
        SafetyGuardAudit(
            rawContentStored: false,
            contentHMACSHA256: nil,
            contentLength: request.text?.count ?? 0,
            evaluatedAt: ISO8601DateFormatter().string(from: Date()),
            latencyMS: latencyMS
        )
    }
}
