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

let checks: [(String, () throws -> Void)] = [
    ("safe allow", verifySafeAllow),
    ("local high short-circuit", verifyLocalHighShortCircuit),
    ("transport unavailable fail closed", verifyTransportUnavailableFailsClosed),
    ("snake_case JSON decode/encode", verifySnakeCaseCoding)
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
