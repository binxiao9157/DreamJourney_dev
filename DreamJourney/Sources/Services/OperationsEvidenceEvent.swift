import CryptoKit
import Foundation

struct OperationsEvidenceEventEnvelope: Codable, Equatable {
    let eventId: String
    let schemaVersion: Int
    let type: String
    let operationId: String
    let correlationId: String?
    let principalHash: String?
    let resourceType: String?
    let resourceIdHash: String?
    let state: String
    let reason: String
    let attempt: Int
    let occurredAt: Date
    let env: String
    let build: String
    let redactionVersion: Int
    let operation: String
    let route: String?
    let latencyMs: Int?
    let policyVersion: String?
    let clientBuild: Int?
    let feature: String?
    let decision: String?
}

enum OperationsEvidenceEventMapper {
    static func echoRuntime(
        _ snapshot: EchoRuntimeDiagnosticsSnapshot,
        environment: String,
        build: String
    ) -> OperationsEvidenceEventEnvelope {
        let eventDigest = digest(snapshot.snapshotId, namespace: "echoRuntimeEvent")
        let operationDigest = digest(snapshot.turnID, namespace: "echoOperation")
        let correlationDigest = snapshot.traceId == "none"
            ? nil
            : digest(snapshot.traceId, namespace: "echoTrace")
        let principalHash = snapshot.userId == "unknown"
            ? nil
            : digest(snapshot.userId, namespace: "principal")
        let resourceHash = snapshot.turnID == "unknown"
            ? nil
            : digest(snapshot.turnID, namespace: "echoTurn")
        let hasFallback = snapshot.fallbackReason?.isEmpty == false
        let reason = hasFallback
            ? safeCode(snapshot.fallbackReason, fallback: "redactedRuntimeReason")
            : "completed"

        return OperationsEvidenceEventEnvelope(
            eventId: "evt_" + String(eventDigest.prefix(32)),
            schemaVersion: 1,
            type: "operation",
            operationId: "op_" + String(operationDigest.prefix(32)),
            correlationId: correlationDigest.map { "corr_" + String($0.prefix(32)) },
            principalHash: principalHash,
            resourceType: "echoTurn",
            resourceIdHash: resourceHash,
            state: hasFallback ? "failed" : "succeeded",
            reason: reason,
            attempt: 1,
            occurredAt: snapshot.recordedAt,
            env: safeCode(environment, fallback: "unknown"),
            build: safeCode(build, fallback: "unknown"),
            redactionVersion: 1,
            operation: "echoRuntime",
            route: nil,
            latencyMs: max(0, snapshot.contextLatencyMs),
            policyVersion: nil,
            clientBuild: Int(build),
            feature: "echoTextInput",
            decision: hasFallback ? "fallback" : "completed"
        )
    }

    private static func digest(_ value: String, namespace: String) -> String {
        SHA256.hash(data: Data("operations-event-v1|\(namespace)|\(value)".utf8))
            .map { String(format: "%02x", $0) }
            .joined()
    }

    private static func safeCode(_ value: String?, fallback: String) -> String {
        let normalized = value?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        guard !normalized.isEmpty,
              normalized.utf8.count <= 128,
              normalized.unicodeScalars.allSatisfy({ scalar in
                  switch scalar.value {
                  case 48...57, 65...90, 97...122, 45, 46, 58, 95:
                      return true
                  default:
                      return false
                  }
              }) else {
            return fallback
        }
        return normalized
    }
}
