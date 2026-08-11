import Foundation

enum RuntimeCapabilityID: String, CaseIterable {
    case archiveImageAnalysis
    case archiveAudioUpload
    case archiveVideoUpload
    case ownerTruthMediaStorage
    case ownerTruthMediaProcessing
    case identityChallenge
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

enum RuntimeCapabilityControlState: String, Codable {
    case legacy
    case ready
    case blocked
    case stale
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
    let providerKind: String
    let operation: String
    let dataClass: String
    let region: String
    let retentionPolicyVersion: String
    let configurationStatus: String
    let evidenceStatus: String
    let controlState: RuntimeCapabilityControlState
    let readinessEpoch: String?
    let readinessObservedAt: Date?
    let readinessExpiresAt: Date?
    let controlContractComplete: Bool
    let providerMetadataComplete: Bool
    let contractComplete: Bool

    /// The runtime contract is safe to use as an authority boundary.  A missing
    /// external verification receipt is intentionally not treated as a provider
    /// outage for internal/QA flows, but an explicitly stale receipt is.  This
    /// prevents a cached runtime response from reviving an expired provider path.
    var isRuntimeContractUsable: Bool {
        contractComplete
            && implemented
            && enabled
            && reason != "externalEvidenceStale"
            && controlState != .blocked
            && controlState != .stale
            && (controlState != .ready || isReadinessEpochUsable())
    }

    /// Provider-backed effects additionally require the provider to be ready.
    /// Keep this separate from `isRuntimeContractUsable` because individual
    /// operations (for example clone training versus synthesis) may carry a
    /// more specific provider readiness signal.
    var isProviderEffectAllowed: Bool {
        isRuntimeContractUsable && providerReady
    }

    var isProviderOperational: Bool {
        isProviderEffectAllowed
    }

    var isPubliclyAvailable: Bool {
        isProviderOperational && releaseVisible && externalVerified
    }

    /// A server-authorized closed pilot may use an internally operated feature
    /// before public-release evidence has been completed. The account policy
    /// remains the authority; this only describes runtime readiness.
    var isClosedPilotAvailable: Bool {
        isProviderOperational && releaseVisible
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
            "providerKind=\(providerKind)",
            "operation=\(operation)",
            "dataClass=\(dataClass)",
            "region=\(region)",
            "retention=\(retentionPolicyVersion)",
            "configuration=\(configurationStatus)",
            "evidence=\(evidenceStatus)",
            "control=\(controlState.rawValue)",
            "readinessEpoch=\(readinessEpoch ?? "none")",
            "readinessExpiresAt=\(readinessExpiresAt?.ISO8601Format() ?? "none")",
            "fallback=\(fallbackMode)",
            "reason=\(reason)",
            "contractComplete=\(contractComplete)",
        ].joined(separator: " ")
    }

    func isReadinessEpochUsable(at date: Date = Date()) -> Bool {
        guard controlState == .ready else {
            return controlState == .legacy
        }
        guard controlContractComplete,
              let readinessEpoch,
              !readinessEpoch.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
              let readinessObservedAt,
              let readinessExpiresAt else {
            return false
        }
        return readinessObservedAt < readinessExpiresAt && date < readinessExpiresAt
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
        let parsedProviderKind = json["providerKind"] as? String
        let parsedOperation = json["operation"] as? String
        let parsedDataClass = json["dataClass"] as? String
        let parsedRegion = json["region"] as? String
        let parsedRetentionPolicyVersion = json["retentionPolicyVersion"] as? String
        let parsedConfigurationStatus = json["configurationStatus"] as? String
        let parsedEvidenceStatus = json["evidenceStatus"] as? String
        let rawControlState = json["controlState"] as? String
        if rawControlState != nil,
           RuntimeCapabilityControlState(rawValue: rawControlState ?? "") == nil {
            return nil
        }
        controlState = rawControlState.flatMap(RuntimeCapabilityControlState.init(rawValue:)) ?? .legacy
        readinessEpoch = (json["readinessEpoch"] as? String)?.trimmingCharacters(in: .whitespacesAndNewlines)
        readinessObservedAt = Self.dateValue(json["readinessObservedAt"])
        readinessExpiresAt = Self.dateValue(json["readinessExpiresAt"])
        switch controlState {
        case .legacy:
            controlContractComplete = true
        case .ready:
            controlContractComplete = readinessEpoch?.isEmpty == false
                && readinessObservedAt != nil
                && readinessExpiresAt != nil
        case .blocked, .stale:
            controlContractComplete = readinessEpoch == nil
                && readinessObservedAt != nil
                && readinessExpiresAt != nil
        }
        guard controlContractComplete else { return nil }
        providerKind = parsedProviderKind ?? "unknown"
        operation = parsedOperation ?? "unknown"
        dataClass = parsedDataClass ?? "unknown"
        region = parsedRegion ?? "unknown"
        retentionPolicyVersion = parsedRetentionPolicyVersion ?? "unknown"
        configurationStatus = parsedConfigurationStatus ?? "unknown"
        evidenceStatus = parsedEvidenceStatus ?? "unknown"
        providerMetadataComplete = parsedProviderKind != nil
            && parsedOperation != nil
            && parsedDataClass != nil
            && parsedRegion != nil
            && parsedRetentionPolicyVersion != nil
            && parsedConfigurationStatus != nil
            && parsedEvidenceStatus != nil
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
            providerKind: "unknown",
            operation: "unknown",
            dataClass: "unknown",
            region: "unknown",
            retentionPolicyVersion: "unknown",
            configurationStatus: "unknown",
            evidenceStatus: "unknown",
            controlState: .legacy,
            readinessEpoch: nil,
            readinessObservedAt: nil,
            readinessExpiresAt: nil,
            controlContractComplete: false,
            providerMetadataComplete: false,
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
        providerKind: String,
        operation: String,
        dataClass: String,
        region: String,
        retentionPolicyVersion: String,
        configurationStatus: String,
        evidenceStatus: String,
        controlState: RuntimeCapabilityControlState,
        readinessEpoch: String?,
        readinessObservedAt: Date?,
        readinessExpiresAt: Date?,
        controlContractComplete: Bool,
        providerMetadataComplete: Bool,
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
        self.providerKind = providerKind
        self.operation = operation
        self.dataClass = dataClass
        self.region = region
        self.retentionPolicyVersion = retentionPolicyVersion
        self.configurationStatus = configurationStatus
        self.evidenceStatus = evidenceStatus
        self.controlState = controlState
        self.readinessEpoch = readinessEpoch
        self.readinessObservedAt = readinessObservedAt
        self.readinessExpiresAt = readinessExpiresAt
        self.controlContractComplete = controlContractComplete
        self.providerMetadataComplete = providerMetadataComplete
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
