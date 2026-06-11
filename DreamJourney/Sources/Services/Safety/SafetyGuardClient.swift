import Foundation

protocol SafetyGuardTransport {
    func evaluate(_ request: SafetyGuardRequest) throws -> SafetyGuardResponse
}

protocol SafetyGuardHTTPClient {
    func perform(_ request: URLRequest) throws -> (Data, HTTPURLResponse)
}

enum SafetyGuardHTTPTransportError: Error {
    case nonHTTPResponse
    case statusCode(Int)
}

final class SafetyGuardURLSessionHTTPClient: SafetyGuardHTTPClient {
    private let session: URLSession

    init(session: URLSession = .shared) {
        self.session = session
    }

    func perform(_ request: URLRequest) throws -> (Data, HTTPURLResponse) {
        let semaphore = DispatchSemaphore(value: 0)
        var result: Result<(Data, HTTPURLResponse), Error>?

        let task = session.dataTask(with: request) { data, response, error in
            defer { semaphore.signal() }

            if let error {
                result = .failure(error)
                return
            }

            guard let httpResponse = response as? HTTPURLResponse else {
                result = .failure(SafetyGuardHTTPTransportError.nonHTTPResponse)
                return
            }

            result = .success((data ?? Data(), httpResponse))
        }
        task.resume()
        semaphore.wait()

        guard let result else {
            throw SafetyGuardHTTPTransportError.nonHTTPResponse
        }
        return try result.get()
    }
}

final class SafetyGuardHTTPTransport: SafetyGuardTransport {
    private let baseURL: URL
    private let apiKey: String?
    private let httpClient: any SafetyGuardHTTPClient
    private let timeoutInterval: TimeInterval

    init(
        baseURL: URL,
        apiKey: String? = nil,
        httpClient: (any SafetyGuardHTTPClient)? = nil,
        timeoutInterval: TimeInterval = 10
    ) {
        self.baseURL = baseURL
        self.apiKey = apiKey
        self.httpClient = httpClient ?? SafetyGuardURLSessionHTTPClient()
        self.timeoutInterval = timeoutInterval
    }

    func evaluate(_ request: SafetyGuardRequest) throws -> SafetyGuardResponse {
        let encoder = JSONEncoder()
        var urlRequest = URLRequest(url: evaluateURL())
        urlRequest.httpMethod = "POST"
        urlRequest.timeoutInterval = timeoutInterval
        urlRequest.setValue("application/json; charset=utf-8", forHTTPHeaderField: "Content-Type")
        urlRequest.setValue("application/json", forHTTPHeaderField: "Accept")
        urlRequest.setValue("no-store", forHTTPHeaderField: "Cache-Control")
        if let apiKey, !apiKey.isEmpty {
            urlRequest.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        }
        urlRequest.httpBody = try encoder.encode(request)

        let (data, response) = try httpClient.perform(urlRequest)
        guard (200..<300).contains(response.statusCode) else {
            throw SafetyGuardHTTPTransportError.statusCode(response.statusCode)
        }

        return try JSONDecoder().decode(SafetyGuardResponse.self, from: data)
    }

    private func evaluateURL() -> URL {
        if baseURL.path.trimmingCharacters(in: CharacterSet(charactersIn: "/")) == "v1/safety/evaluate" {
            return baseURL.removingTrailingPathSlash()
        }
        return baseURL
            .appendingPathComponent("v1")
            .appendingPathComponent("safety")
            .appendingPathComponent("evaluate")
    }
}

private extension URL {
    func removingTrailingPathSlash() -> URL {
        guard var components = URLComponents(url: self, resolvingAgainstBaseURL: false) else {
            return self
        }
        while components.path.count > 1 && components.path.hasSuffix("/") {
            components.path.removeLast()
        }
        return components.url ?? self
    }
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
