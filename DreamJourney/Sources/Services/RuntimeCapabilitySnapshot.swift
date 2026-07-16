import Foundation

enum RuntimeCapabilityID: String, CaseIterable {
    case archiveImageAnalysis
    case archiveAudioUpload
    case archiveVideoUpload
    case timeLetters
    case familyManagement
    case familySpace
    case voiceCloneShell
    case digitalHumanLivePanel
}

enum RuntimeCapabilityReadiness: String, Codable {
    case unknown
    case notImplemented
    case disabled
    case providerUnavailable
    case releaseHidden
    case externalVerificationMissing
    case externalEvidenceStale
    case ready
}

struct RuntimeCapabilitySnapshot: Equatable {
    let schemaVersion: Int
    let capability: String
    let implemented: Bool
    let enabled: Bool
    let providerReady: Bool
    let releaseVisible: Bool
    let externalVerified: Bool
    let provider: String
    let fallbackMode: String
    let reason: String
    let evidenceTimestamp: Date?
    let contractComplete: Bool

    var isProviderOperational: Bool {
        contractComplete && implemented && enabled && providerReady
    }

    var isPubliclyAvailable: Bool {
        isProviderOperational && releaseVisible && externalVerified
    }

    var readiness: RuntimeCapabilityReadiness {
        guard contractComplete else { return .unknown }
        guard implemented else { return .notImplemented }
        guard enabled else { return .disabled }
        guard providerReady else { return .providerUnavailable }
        if reason == "externalEvidenceStale" { return .externalEvidenceStale }
        if reason == "externalEvidenceMissing" { return .externalVerificationMissing }
        guard releaseVisible else { return .releaseHidden }
        guard externalVerified else { return .externalVerificationMissing }
        return .ready
    }

    var diagnosticSummary: String {
        [
            "capability=\(capability)",
            "implemented=\(implemented)",
            "enabled=\(enabled)",
            "providerReady=\(providerReady)",
            "releaseVisible=\(releaseVisible)",
            "externalVerified=\(externalVerified)",
            "provider=\(provider)",
            "fallback=\(fallbackMode)",
            "reason=\(reason)",
            "contractComplete=\(contractComplete)",
        ].joined(separator: " ")
    }

    init?(json: [String: Any]) {
        guard Self.intValue(json["schemaVersion"]) == 1,
              let capability = json["capability"] as? String,
              let implemented = json["implemented"] as? Bool,
              let enabled = json["enabled"] as? Bool,
              let providerReady = json["providerReady"] as? Bool,
              let releaseVisible = json["releaseVisible"] as? Bool,
              let externalVerified = json["externalVerified"] as? Bool,
              let provider = json["provider"] as? String,
              let fallbackMode = json["fallbackMode"] as? String,
              let reason = json["reason"] as? String else {
            return nil
        }
        schemaVersion = 1
        self.capability = capability
        self.implemented = implemented
        self.enabled = enabled
        self.providerReady = providerReady
        self.releaseVisible = releaseVisible
        self.externalVerified = externalVerified
        self.provider = provider
        self.fallbackMode = fallbackMode
        self.reason = reason
        evidenceTimestamp = Self.dateValue(json["evidenceTimestamp"])
        contractComplete = true
    }

    static func conservativeLegacy(
        capability: String,
        implemented: Bool,
        enabled: Bool,
        providerReady: Bool,
        provider: String,
        fallbackMode: String = "unknown"
    ) -> RuntimeCapabilitySnapshot {
        RuntimeCapabilitySnapshot(
            schemaVersion: 0,
            capability: capability,
            implemented: implemented,
            enabled: enabled,
            providerReady: providerReady,
            releaseVisible: false,
            externalVerified: false,
            provider: provider,
            fallbackMode: fallbackMode,
            reason: "legacyCapabilityContractIncomplete",
            evidenceTimestamp: nil,
            contractComplete: false
        )
    }

    private init(
        schemaVersion: Int,
        capability: String,
        implemented: Bool,
        enabled: Bool,
        providerReady: Bool,
        releaseVisible: Bool,
        externalVerified: Bool,
        provider: String,
        fallbackMode: String,
        reason: String,
        evidenceTimestamp: Date?,
        contractComplete: Bool
    ) {
        self.schemaVersion = schemaVersion
        self.capability = capability
        self.implemented = implemented
        self.enabled = enabled
        self.providerReady = providerReady
        self.releaseVisible = releaseVisible
        self.externalVerified = externalVerified
        self.provider = provider
        self.fallbackMode = fallbackMode
        self.reason = reason
        self.evidenceTimestamp = evidenceTimestamp
        self.contractComplete = contractComplete
    }

    private static func intValue(_ value: Any?) -> Int? {
        if let value = value as? Int { return value }
        if let value = value as? NSNumber { return value.intValue }
        if let value = value as? String { return Int(value) }
        return nil
    }

    private static func dateValue(_ value: Any?) -> Date? {
        guard let rawValue = value as? String else { return nil }
        let fractional = ISO8601DateFormatter()
        fractional.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return fractional.date(from: rawValue) ?? ISO8601DateFormatter().date(from: rawValue)
    }
}

final class RuntimeCapabilitySnapshotStore {
    static let shared = RuntimeCapabilitySnapshotStore()

    private let lock = NSLock()
    private var snapshots: [String: RuntimeCapabilitySnapshot] = [:]

    private init() {}

    func replace(with values: [String: RuntimeCapabilitySnapshot]) {
        lock.lock()
        snapshots = values
        lock.unlock()
    }

    func snapshot(for capability: RuntimeCapabilityID) -> RuntimeCapabilitySnapshot? {
        lock.lock()
        let value = snapshots[capability.rawValue]
        lock.unlock()
        return value
    }

    func invalidate() {
        lock.lock()
        snapshots.removeAll()
        lock.unlock()
    }
}
