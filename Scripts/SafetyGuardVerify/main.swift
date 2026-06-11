import Foundation

private enum VerifyFailure: Error, CustomStringConvertible {
    case failed(String)

    var description: String {
        switch self {
        case .failed(let message):
            return message
        }
    }
}

private func expect(_ condition: @autoclosure () -> Bool, _ message: String) throws {
    if !condition() {
        throw VerifyFailure.failed(message)
    }
}

private final class MockTransport: SafetyGuardTransport {
    let result: Result<SafetyGuardResponse, Error>
    private(set) var calls = 0

    init(result: Result<SafetyGuardResponse, Error>) {
        self.result = result
    }

    func evaluate(_ request: SafetyGuardRequest) throws -> SafetyGuardResponse {
        calls += 1
        return try result.get()
    }
}

private struct TransportUnavailable: Error {}
private struct NetworkUnavailable: Error {}

private final class RecordingHTTPClient: SafetyGuardHTTPClient {
    private(set) var requests: [URLRequest] = []
    let result: Result<(Data, HTTPURLResponse), Error>

    init(result: Result<(Data, HTTPURLResponse), Error>) {
        self.result = result
    }

    func perform(_ request: URLRequest) throws -> (Data, HTTPURLResponse) {
        requests.append(request)
        return try result.get()
    }
}

private func makeRequest(
    text: String,
    target: SafetyGuardTarget = .deepseek
) -> SafetyGuardRequest {
    SafetyGuardRequest(
        requestID: "req-1",
        clientEventID: "event-1",
        sessionID: "session-1",
        userIDHash: "user-hash",
        deviceIDHash: "device-hash",
        surface: .dialog,
        stage: .userInputPreLLM,
        contentType: .text,
        text: text,
        mediaRef: nil,
        locale: "zh-CN",
        sdkEventType: "SEEventChatTextQueryConfirmed",
        target: target,
        noStoreRaw: true
    )
}

private func makeAllowResponse() -> SafetyGuardResponse {
    SafetyGuardResponse(
        decisionID: "decision-allow",
        riskLevel: .safe,
        action: .allow,
        categories: [],
        policyVersion: "safety-2026-06-11",
        reasonCode: "SAFE",
        safeReplacementKey: nil,
        canPersist: true,
        canSendToLLM: true,
        canSendToTTS: true,
        canShowInFamilyDashboard: true,
        audit: SafetyGuardAudit(
            rawContentStored: false,
            contentHMACSHA256: "server-keyed-hmac",
            contentLength: 5,
            evaluatedAt: "2026-06-11T00:00:00Z",
            latencyMS: 12
        )
    )
}

private func verifySafeAllow() throws {
    let transport = MockTransport(result: .success(makeAllowResponse()))
    let client = SafetyGuardClient(transport: transport)

    let response = client.evaluate(makeRequest(text: "今天想聊聊晚饭"))

    try expect(response.action == .allow, "safe text should preserve server allow action")
    try expect(response.canSendToLLM, "safe allow should preserve canSendToLLM")
    try expect(response.canSendToTTS, "safe allow should preserve canSendToTTS")
    try expect(response.audit.rawContentStored == false, "audit must not store raw content")
    try expect(transport.calls == 1, "safe text should call transport once")
}

private func verifyLocalHighShortCircuit() throws {
    let transport = MockTransport(result: .success(makeAllowResponse()))
    let client = SafetyGuardClient(transport: transport)

    let response = client.evaluate(makeRequest(text: "我不想活了，想结束生命"))

    try expect(response.riskLevel == .high || response.riskLevel == .critical, "local high text should return high/critical")
    try expect(response.action == .block || response.action == .escalate, "local high text should block or escalate")
    try expect(response.canPersist == false, "local high text must not persist")
    try expect(response.canSendToLLM == false, "local high text must not send to LLM")
    try expect(response.canSendToTTS == false, "local high text must not send to TTS")
    try expect(response.audit.rawContentStored == false, "local high audit must not store raw content")
    try expect(transport.calls == 0, "local high text must not call transport")
}

private func verifyTransportUnavailableFailsClosed() throws {
    let transport = MockTransport(result: .failure(TransportUnavailable()))
    let client = SafetyGuardClient(transport: transport)

    let response = client.evaluate(makeRequest(text: "普通问候"))

    try expect(response.action == .block, "remote target should fail closed with block")
    try expect(response.reasonCode == "GUARD_UNAVAILABLE", "fail closed should expose guard unavailable reason")
    try expect(response.canSendToLLM == false, "fail closed must not send to LLM")
    try expect(response.canSendToTTS == false, "fail closed must not send to TTS")
    try expect(response.audit.rawContentStored == false, "fail closed audit must not store raw content")
}

private func verifySnakeCaseCoding() throws {
    let json = """
    {
      "request_id": "req-2",
      "client_event_id": "event-2",
      "session_id": "session-2",
      "user_id_hash": "user-hash",
      "device_id_hash": "device-hash",
      "surface": "memory_archive",
      "stage": "local_save_pre_persist",
      "content_type": "summary",
      "text": "transient only",
      "media_ref": "upload-token",
      "locale": "zh-CN",
      "sdk_event_type": "SEEventChatTextQueryConfirmed",
      "target": "local_only",
      "no_store_raw": true
    }
    """.data(using: .utf8)!

    let decoded = try JSONDecoder().decode(SafetyGuardRequest.self, from: json)
    try expect(decoded.surface == .memoryArchive, "surface should decode snake_case memory_archive")
    try expect(decoded.stage == .localSavePrePersist, "stage should decode snake_case local_save_pre_persist")
    try expect(decoded.contentType == .summary, "content_type should decode snake_case summary")
    try expect(decoded.target == .localOnly, "target should decode snake_case local_only")

    let encoded = try JSONEncoder().encode(decoded)
    let object = try JSONSerialization.jsonObject(with: encoded) as? [String: Any]
    try expect(object?["request_id"] as? String == "req-2", "request_id should encode as snake_case")
    try expect(object?["content_type"] as? String == "summary", "content_type should encode as snake_case")
    try expect(object?["no_store_raw"] as? Bool == true, "no_store_raw should encode as snake_case")
}

private func makeHTTPURLResponse(statusCode: Int) -> HTTPURLResponse {
    HTTPURLResponse(
        url: URL(string: "https://guard.example.com/v1/safety/evaluate")!,
        statusCode: statusCode,
        httpVersion: "HTTP/1.1",
        headerFields: ["Content-Type": "application/json"]
    )!
}

private func makeAllowResponseData() throws -> Data {
    try JSONEncoder().encode(makeAllowResponse())
}

private func verifyHTTPTransportPostsEvaluateRequest() throws {
    let httpClient = RecordingHTTPClient(
        result: .success((try makeAllowResponseData(), makeHTTPURLResponse(statusCode: 200)))
    )
    let transport = SafetyGuardHTTPTransport(
        baseURL: URL(string: "https://guard.example.com")!,
        apiKey: "test-key",
        httpClient: httpClient
    )

    let response = try transport.evaluate(makeRequest(text: "普通问候"))

    try expect(response.action == .allow, "HTTP transport should decode allow response")
    try expect(httpClient.requests.count == 1, "HTTP transport should issue one request")
    let request = try expectValue(httpClient.requests.first, "HTTP request should be captured")
    try expect(request.httpMethod == "POST", "HTTP transport should use POST")
    try expect(request.url?.absoluteString == "https://guard.example.com/v1/safety/evaluate", "HTTP transport should post to /v1/safety/evaluate")
    try expect(request.value(forHTTPHeaderField: "Content-Type")?.contains("application/json") == true, "HTTP transport should send JSON content type")
    try expect(request.value(forHTTPHeaderField: "Accept") == "application/json", "HTTP transport should accept JSON")
    try expect(request.value(forHTTPHeaderField: "Cache-Control") == "no-store", "HTTP transport should request no-store cache policy")
    try expect(request.value(forHTTPHeaderField: "Authorization") == "Bearer test-key", "HTTP transport should attach bearer token")

    let body = try expectValue(request.httpBody, "HTTP transport should send a request body")
    let object = try JSONSerialization.jsonObject(with: body) as? [String: Any]
    try expect(object?["request_id"] as? String == "req-1", "HTTP body should use request_id snake_case")
    try expect(object?["no_store_raw"] as? Bool == true, "HTTP body should preserve no_store_raw")
}

private func verifyHTTPTransportAcceptsEvaluateURL() throws {
    let httpClient = RecordingHTTPClient(
        result: .success((try makeAllowResponseData(), makeHTTPURLResponse(statusCode: 200)))
    )
    let transport = SafetyGuardHTTPTransport(
        baseURL: URL(string: "https://guard.example.com/v1/safety/evaluate")!,
        httpClient: httpClient
    )

    _ = try transport.evaluate(makeRequest(text: "普通问候"))

    let request = try expectValue(httpClient.requests.first, "HTTP request should be captured")
    try expect(request.url?.absoluteString == "https://guard.example.com/v1/safety/evaluate", "HTTP transport should not duplicate evaluate path")
}

private func verifyHTTPTransportAcceptsEvaluateURLWithTrailingSlash() throws {
    let httpClient = RecordingHTTPClient(
        result: .success((try makeAllowResponseData(), makeHTTPURLResponse(statusCode: 200)))
    )
    let transport = SafetyGuardHTTPTransport(
        baseURL: URL(string: "https://guard.example.com/v1/safety/evaluate/")!,
        httpClient: httpClient
    )

    _ = try transport.evaluate(makeRequest(text: "普通问候"))

    let request = try expectValue(httpClient.requests.first, "HTTP request should be captured")
    try expect(request.url?.absoluteString == "https://guard.example.com/v1/safety/evaluate", "HTTP transport should normalize trailing slash evaluate URL")
}

private func verifyHTTPTransportOmitsAuthorizationWithoutAPIKey() throws {
    let httpClient = RecordingHTTPClient(
        result: .success((try makeAllowResponseData(), makeHTTPURLResponse(statusCode: 200)))
    )
    let transport = SafetyGuardHTTPTransport(
        baseURL: URL(string: "https://guard.example.com")!,
        httpClient: httpClient
    )

    _ = try transport.evaluate(makeRequest(text: "普通问候"))

    let request = try expectValue(httpClient.requests.first, "HTTP request should be captured")
    try expect(request.value(forHTTPHeaderField: "Authorization") == nil, "HTTP transport should omit Authorization without API key")
}

private func verifyHTTPTransportThrowsOnNon2xx() throws {
    let httpClient = RecordingHTTPClient(
        result: .success((Data("{}".utf8), makeHTTPURLResponse(statusCode: 503)))
    )
    let transport = SafetyGuardHTTPTransport(
        baseURL: URL(string: "https://guard.example.com/")!,
        httpClient: httpClient
    )
    let client = SafetyGuardClient(transport: transport)

    let response = client.evaluate(makeRequest(text: "普通问候"))

    try expect(response.action == .block, "non-2xx HTTP response should fail closed through SafetyGuardClient")
    try expect(response.reasonCode == "GUARD_UNAVAILABLE", "non-2xx HTTP response should report guard unavailable")
}

private func verifyHTTPTransportNetworkErrorFailsClosed() throws {
    let httpClient = RecordingHTTPClient(result: .failure(NetworkUnavailable()))
    let transport = SafetyGuardHTTPTransport(
        baseURL: URL(string: "https://guard.example.com")!,
        httpClient: httpClient
    )
    let client = SafetyGuardClient(transport: transport)

    let response = client.evaluate(makeRequest(text: "普通问候"))

    try expect(response.action == .block, "network error should fail closed through SafetyGuardClient")
    try expect(response.reasonCode == "GUARD_UNAVAILABLE", "network error should report guard unavailable")
}

private func verifyHTTPTransportDecodeFailureFailsClosed() throws {
    let httpClient = RecordingHTTPClient(
        result: .success((Data("{\"unexpected\":true}".utf8), makeHTTPURLResponse(statusCode: 200)))
    )
    let transport = SafetyGuardHTTPTransport(
        baseURL: URL(string: "https://guard.example.com")!,
        httpClient: httpClient
    )
    let client = SafetyGuardClient(transport: transport)

    let response = client.evaluate(makeRequest(text: "普通问候"))

    try expect(response.action == .block, "invalid HTTP response body should fail closed through SafetyGuardClient")
    try expect(response.reasonCode == "GUARD_UNAVAILABLE", "invalid HTTP response body should report guard unavailable")
}

private func verifyDefaultClientUsesHTTPTransportWhenConfigured() throws {
    let httpClient = RecordingHTTPClient(
        result: .success((try makeAllowResponseData(), makeHTTPURLResponse(statusCode: 200)))
    )
    let client = DeepSeekSafetyGuarding.makeDefaultClient(
        arguments: ["DreamJourney"],
        environment: ["DREAMJOURNEY_SAFETY_GUARD_BASE_URL": "https://guard.example.com"],
        httpClient: httpClient
    )

    let response = client.evaluate(makeRequest(text: "普通问候"))

    try expect(response.action == .allow, "configured default client should use HTTP transport")
    try expect(httpClient.requests.count == 1, "configured default client should call HTTP transport")
}

private func verifyDefaultClientUsesBundleHTTPConfiguration() throws {
    let httpClient = RecordingHTTPClient(
        result: .success((try makeAllowResponseData(), makeHTTPURLResponse(statusCode: 200)))
    )
    let bundleURL = FileManager.default
        .temporaryDirectory
        .appendingPathComponent("DreamJourneySafetyGuardVerify.bundle", isDirectory: true)
    try? FileManager.default.removeItem(at: bundleURL)
    try FileManager.default.createDirectory(at: bundleURL, withIntermediateDirectories: true)
    let infoURL = bundleURL.appendingPathComponent("Info.plist")
    let plist: [String: Any] = [
        "CFBundleIdentifier": "com.dreamjourney.safety-guard-verify",
        "CFBundlePackageType": "BNDL",
        "SafetyGuardBaseURL": "https://guard.example.com",
        "SafetyGuardAPIKey": "bundle-key"
    ]
    let data = try PropertyListSerialization.data(fromPropertyList: plist, format: .xml, options: 0)
    try data.write(to: infoURL)
    let bundle = try expectValue(Bundle(url: bundleURL), "temporary bundle should load")

    let client = DeepSeekSafetyGuarding.makeDefaultClient(
        arguments: ["DreamJourney"],
        environment: [:],
        bundle: bundle,
        httpClient: httpClient
    )

    let response = client.evaluate(makeRequest(text: "普通问候"))

    try expect(response.action == .allow, "bundle configured default client should use HTTP transport")
    let request = try expectValue(httpClient.requests.first, "bundle configured HTTP request should be captured")
    try expect(request.value(forHTTPHeaderField: "Authorization") == "Bearer bundle-key", "bundle API key should be used as bearer token")
}

private func verifyMockAllowOverridesHTTPConfiguration() throws {
    let httpClient = RecordingHTTPClient(
        result: .success((Data("{}".utf8), makeHTTPURLResponse(statusCode: 503)))
    )
    let client = DeepSeekSafetyGuarding.makeDefaultClient(
        arguments: ["DreamJourney"],
        environment: [
            "DREAMJOURNEY_SAFETY_GUARD": "mock_allow",
            "DREAMJOURNEY_SAFETY_GUARD_BASE_URL": "https://guard.example.com"
        ],
        httpClient: httpClient
    )

    let response = client.evaluate(makeRequest(text: "普通问候"))

    try expect(response.action == .allow, "mock allow should override HTTP configuration")
    try expect(response.reasonCode == "MOCK_ALLOW", "mock allow should preserve mock reason")
    try expect(httpClient.requests.isEmpty, "mock allow should not call configured HTTP transport")
}

private func expectValue<T>(_ value: T?, _ message: String) throws -> T {
    guard let value else {
        throw VerifyFailure.failed(message)
    }
    return value
}

let checks: [(String, () throws -> Void)] = [
    ("safe allow", verifySafeAllow),
    ("local high short-circuit", verifyLocalHighShortCircuit),
    ("transport unavailable fail closed", verifyTransportUnavailableFailsClosed),
    ("snake_case JSON decode/encode", verifySnakeCaseCoding),
    ("HTTP transport POST /v1/safety/evaluate", verifyHTTPTransportPostsEvaluateRequest),
    ("HTTP transport accepts full evaluate URL", verifyHTTPTransportAcceptsEvaluateURL),
    ("HTTP transport accepts full evaluate URL with trailing slash", verifyHTTPTransportAcceptsEvaluateURLWithTrailingSlash),
    ("HTTP transport omits Authorization without API key", verifyHTTPTransportOmitsAuthorizationWithoutAPIKey),
    ("HTTP transport non-2xx fail closed", verifyHTTPTransportThrowsOnNon2xx),
    ("HTTP transport network error fail closed", verifyHTTPTransportNetworkErrorFailsClosed),
    ("HTTP transport decode failure fail closed", verifyHTTPTransportDecodeFailureFailsClosed),
    ("configured default client uses HTTP transport", verifyDefaultClientUsesHTTPTransportWhenConfigured),
    ("bundle configured default client uses HTTP transport", verifyDefaultClientUsesBundleHTTPConfiguration),
    ("mock allow overrides HTTP configuration", verifyMockAllowOverridesHTTPConfiguration)
]

var passed = 0
for (name, check) in checks {
    do {
        try check()
        passed += 1
        print("PASS: \(name)")
    } catch {
        print("FAIL: \(name): \(error)")
        exit(1)
    }
}

print("SafetyGuard verification: \(passed)/\(checks.count) passed")
