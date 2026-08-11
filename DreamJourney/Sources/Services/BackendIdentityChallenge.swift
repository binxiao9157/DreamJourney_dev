import Foundation

struct BackendIdentityChallengeCapability: Equatable {
    let enabled: Bool
    let providerMode: String
    let productionReady: Bool
    let clientFlowEnabled: Bool
    let challengeEndpoint: String
    let verifyEndpointTemplate: String
    let statusEndpointTemplate: String
    let stateContractVersion: Int
    let deliveryReceiptSupported: Bool
    let deliveryRecoverySupported: Bool
    let testAccountFlowEnabled: Bool
    let testAccountTargetRestricted: Bool
    let contractVersion: Int
    private let contractFieldsComplete: Bool

    var canStartClientFlow: Bool {
        guard contractFieldsComplete,
              enabled,
              clientFlowEnabled,
              contractVersion == 1,
              challengeEndpoint == "/v2/auth/challenges",
              verifyEndpointTemplate == "/v2/auth/challenges/{challengeId}/verify" else {
            return false
        }
        let restrictedTestAllowlist = providerMode == "testAllowlist"
            && testAccountFlowEnabled
            && testAccountTargetRestricted
        return productionReady || providerMode == "synthetic" || restrictedTestAllowlist
    }

    var canReadChallengeState: Bool {
        stateContractVersion == 1
            && statusEndpointTemplate == "/v2/auth/challenges/{challengeId}"
    }

    init(json: [String: Any]?) {
        let parsedEnabled = Self.bool(json?["enabled"])
        let parsedProviderMode = Self.string(json?["providerMode"])
        let parsedProductionReady = Self.bool(json?["productionReady"])
        let parsedClientFlowEnabled = Self.bool(json?["clientFlowEnabled"])
        let parsedChallengeEndpoint = Self.string(json?["challengeEndpoint"])
        let parsedVerifyEndpoint = Self.string(json?["verifyEndpointTemplate"])
        let parsedStatusEndpoint = Self.string(json?["statusEndpointTemplate"])
        let parsedStateContractVersion = Self.int(json?["stateContractVersion"])
        let parsedTestAccountFlowEnabled = Self.bool(json?["testAccountFlowEnabled"])
        let parsedTestAccountTargetRestricted = Self.bool(json?["testAccountTargetRestricted"])
        let parsedContractVersion = Self.int(json?["contractVersion"])
        enabled = parsedEnabled ?? false
        providerMode = parsedProviderMode ?? "unavailable"
        productionReady = parsedProductionReady ?? false
        clientFlowEnabled = parsedClientFlowEnabled ?? false
        challengeEndpoint = parsedChallengeEndpoint ?? ""
        verifyEndpointTemplate = parsedVerifyEndpoint ?? ""
        statusEndpointTemplate = parsedStatusEndpoint ?? ""
        stateContractVersion = parsedStateContractVersion ?? 0
        deliveryReceiptSupported = Self.bool(json?["deliveryReceiptSupported"]) ?? false
        deliveryRecoverySupported = Self.bool(json?["deliveryRecoverySupported"]) ?? false
        testAccountFlowEnabled = parsedTestAccountFlowEnabled ?? false
        testAccountTargetRestricted = parsedTestAccountTargetRestricted ?? false
        contractVersion = parsedContractVersion ?? 0
        let testAllowlistFieldsComplete = parsedProviderMode != "testAllowlist"
            || (parsedTestAccountFlowEnabled != nil && parsedTestAccountTargetRestricted != nil)
        contractFieldsComplete = parsedEnabled != nil
            && parsedProviderMode != nil
            && parsedProductionReady != nil
            && parsedClientFlowEnabled != nil
            && parsedChallengeEndpoint != nil
            && parsedVerifyEndpoint != nil
            && parsedContractVersion != nil
            && testAllowlistFieldsComplete
    }

    private static func string(_ value: Any?) -> String? {
        (value as? String)?.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private static func bool(_ value: Any?) -> Bool? {
        if let value = value as? Bool { return value }
        if let value = value as? NSNumber { return value.boolValue }
        if let value = value as? String {
            switch value.lowercased() {
            case "true", "1", "yes": return true
            case "false", "0", "no": return false
            default: return nil
            }
        }
        return nil
    }

    private static func int(_ value: Any?) -> Int? {
        if let value = value as? Int { return value }
        if let value = value as? NSNumber { return value.intValue }
        if let value = value as? String { return Int(value) }
        return nil
    }
}

enum BackendIdentityChallengeLifecycleState: String, Equatable {
    case active
    case verified
    case expired
    case locked
    case unavailable
}

enum BackendIdentityChallengeDeliveryState: String, Equatable {
    case accepted
    case delivered
    case undeliverable
    case unknown
}

enum BackendIdentityChallengeRecoveryState: String, Equatable {
    case available
    case notRequired
    case pending
    case terminal
    case unsupported
}

struct BackendIdentityChallengeStateSnapshot: Equatable {
    let challengeId: String
    let purpose: String
    let deliveryMode: String
    let challengeState: BackendIdentityChallengeLifecycleState
    let deliveryState: BackendIdentityChallengeDeliveryState
    let attempt: Int
    let maxAttempts: Int
    let remainingAttempts: Int
    let retryAfterSeconds: Int
    let recoveryState: BackendIdentityChallengeRecoveryState
    let recoveryAttempt: Int
    let statusEndpoint: String
    let expiresAt: String
    let expiresAtDate: Date
    let productionReady: Bool
    let stateContractVersion: Int
    let contractVersion: Int

    init?(
        json: [String: Any],
        now: Date = Date(),
        allowsLegacyState: Bool
    ) {
        guard let challengeId = Self.string(json["challengeId"]),
              let purpose = Self.string(json["purpose"]),
              let deliveryMode = Self.string(json["deliveryMode"]),
              let expiresAt = Self.string(json["expiresAt"]),
              let expiresAtDate = Self.iso8601Date(expiresAt),
              !challengeId.isEmpty,
              ["login", "register", "restore", "invitation"].contains(purpose),
              deliveryMode == "acceptedOnly",
              Self.int(json["contractVersion"]) == 1 else {
            return nil
        }

        let stateVersion = Self.int(json["stateContractVersion"]) ?? 0
        let parsedState: BackendIdentityChallengeLifecycleState
        let parsedDelivery: BackendIdentityChallengeDeliveryState
        let parsedRecovery: BackendIdentityChallengeRecoveryState
        let parsedAttempt: Int
        let parsedMaxAttempts: Int
        let parsedRemainingAttempts: Int
        let parsedRecoveryAttempt: Int
        let parsedStatusEndpoint: String

        if stateVersion == 0, allowsLegacyState {
            parsedState = .active
            parsedDelivery = .accepted
            parsedRecovery = .unsupported
            parsedAttempt = 0
            parsedMaxAttempts = max(1, Self.int(json["maxAttempts"]) ?? 1)
            parsedRemainingAttempts = parsedMaxAttempts
            parsedRecoveryAttempt = 0
            parsedStatusEndpoint = ""
        } else {
            guard stateVersion == 1,
                  let challengeState = Self.state(json["challengeState"]),
                  let deliveryState = Self.delivery(json["deliveryState"]),
                  let recoveryState = Self.recovery(json["recoveryState"]),
                  let attempt = Self.int(json["attempt"]),
                  let maxAttempts = Self.int(json["maxAttempts"]),
                  let remainingAttempts = Self.int(json["remainingAttempts"]),
                  let recoveryAttempt = Self.int(json["recoveryAttempt"]),
                  let statusEndpoint = Self.string(json["statusEndpoint"]),
                  attempt >= 0,
                  maxAttempts > 0,
                  attempt <= maxAttempts,
                  remainingAttempts == maxAttempts - attempt,
                  recoveryAttempt >= 0,
                  statusEndpoint == "/v2/auth/challenges/\(challengeId)",
                  Self.validDeliveryRecoveryPair(deliveryState, recoveryState) else {
                return nil
            }
            parsedState = challengeState
            parsedDelivery = deliveryState
            parsedRecovery = recoveryState
            parsedAttempt = attempt
            parsedMaxAttempts = maxAttempts
            parsedRemainingAttempts = remainingAttempts
            parsedRecoveryAttempt = recoveryAttempt
            parsedStatusEndpoint = statusEndpoint
        }

        if parsedState == .active, expiresAtDate <= now {
            return nil
        }
        self.challengeId = challengeId
        self.purpose = purpose
        self.deliveryMode = deliveryMode
        self.challengeState = parsedState
        self.deliveryState = parsedDelivery
        self.attempt = parsedAttempt
        self.maxAttempts = parsedMaxAttempts
        self.remainingAttempts = parsedRemainingAttempts
        self.retryAfterSeconds = max(0, Self.int(json["retryAfterSeconds"]) ?? 0)
        self.recoveryState = parsedRecovery
        self.recoveryAttempt = parsedRecoveryAttempt
        self.statusEndpoint = parsedStatusEndpoint
        self.expiresAt = expiresAt
        self.expiresAtDate = expiresAtDate
        self.productionReady = Self.bool(json["productionReady"]) ?? false
        self.stateContractVersion = stateVersion
        self.contractVersion = 1
    }

    func isExpired(at date: Date = Date()) -> Bool {
        expiresAtDate <= date
    }

    private static func validDeliveryRecoveryPair(
        _ delivery: BackendIdentityChallengeDeliveryState,
        _ recovery: BackendIdentityChallengeRecoveryState
    ) -> Bool {
        switch delivery {
        case .delivered:
            return recovery == .notRequired
        case .undeliverable:
            return recovery == .terminal
        case .accepted, .unknown:
            return recovery == .available || recovery == .pending || recovery == .unsupported
        }
    }

    private static func state(_ value: Any?) -> BackendIdentityChallengeLifecycleState? {
        string(value).flatMap(BackendIdentityChallengeLifecycleState.init(rawValue:))
    }

    private static func delivery(_ value: Any?) -> BackendIdentityChallengeDeliveryState? {
        string(value).flatMap(BackendIdentityChallengeDeliveryState.init(rawValue:))
    }

    private static func recovery(_ value: Any?) -> BackendIdentityChallengeRecoveryState? {
        string(value).flatMap(BackendIdentityChallengeRecoveryState.init(rawValue:))
    }

    private static func string(_ value: Any?) -> String? {
        (value as? String)?.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private static func bool(_ value: Any?) -> Bool? {
        if let value = value as? Bool { return value }
        if let value = value as? NSNumber { return value.boolValue }
        return nil
    }

    private static func int(_ value: Any?) -> Int? {
        if let value = value as? Int { return value }
        if let value = value as? NSNumber { return value.intValue }
        if let value = value as? String { return Int(value) }
        return nil
    }

    private static func iso8601Date(_ value: String) -> Date? {
        let fractional = ISO8601DateFormatter()
        fractional.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let date = fractional.date(from: value) {
            return date
        }
        return ISO8601DateFormatter().date(from: value)
    }
}

struct BackendIdentityChallengeContract: Equatable {
    let state: BackendIdentityChallengeStateSnapshot

    var challengeId: String { state.challengeId }
    var purpose: String { state.purpose }
    var deliveryMode: String { state.deliveryMode }
    var challengeState: BackendIdentityChallengeLifecycleState { state.challengeState }
    var deliveryState: BackendIdentityChallengeDeliveryState { state.deliveryState }
    var attempt: Int { state.attempt }
    var maxAttempts: Int { state.maxAttempts }
    var remainingAttempts: Int { state.remainingAttempts }
    var retryAfterSeconds: Int { state.retryAfterSeconds }
    var recoveryState: BackendIdentityChallengeRecoveryState { state.recoveryState }
    var recoveryAttempt: Int { state.recoveryAttempt }
    var statusEndpoint: String { state.statusEndpoint }
    var expiresAt: String { state.expiresAt }
    var expiresAtDate: Date { state.expiresAtDate }
    var productionReady: Bool { state.productionReady }
    var stateContractVersion: Int { state.stateContractVersion }
    var contractVersion: Int { state.contractVersion }

    init?(json object: [String: Any], now: Date = Date()) {
        guard (object["status"] as? String) == "accepted",
              let json = object["challenge"] as? [String: Any],
              let state = BackendIdentityChallengeStateSnapshot(
                json: json,
                now: now,
                allowsLegacyState: true
              ),
              state.challengeState == .active else {
            return nil
        }
        self.state = state
    }

    func isExpired(at date: Date = Date()) -> Bool {
        state.isExpired(at: date)
    }
}

struct BackendIdentityChallengeStateContract: Equatable {
    let state: BackendIdentityChallengeStateSnapshot

    init?(json object: [String: Any], now: Date = Date()) {
        guard (object["status"] as? String) == "available",
              let json = object["challenge"] as? [String: Any],
              let state = BackendIdentityChallengeStateSnapshot(
                json: json,
                now: now,
                allowsLegacyState: false
              ) else {
            return nil
        }
        self.state = state
    }
}

struct BackendIdentityVerificationContract: Equatable {
    let subjectId: String
    let bindingId: String
    let proofReceiptId: String
    let contractVersion: Int

    init?(json object: [String: Any]) {
        guard Self.string(object["status"]) == "verified",
              Self.int(object["contractVersion"]) == 1,
              let json = object["subject"] as? [String: Any] else {
            return nil
        }
        guard let subjectId = Self.string(json["subjectId"]),
              let bindingId = Self.string(json["bindingId"]),
              let proofReceiptId = Self.string(json["proofReceiptId"]),
              Self.int(json["contractVersion"]) == 1,
              !subjectId.isEmpty,
              !bindingId.isEmpty,
              !proofReceiptId.isEmpty else {
            return nil
        }
        self.subjectId = subjectId
        self.bindingId = bindingId
        self.proofReceiptId = proofReceiptId
        contractVersion = 1
    }

    private static func string(_ value: Any?) -> String? {
        (value as? String)?.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private static func int(_ value: Any?) -> Int? {
        if let value = value as? Int { return value }
        if let value = value as? NSNumber { return value.intValue }
        if let value = value as? String { return Int(value) }
        return nil
    }
}
