import CryptoKit
import Foundation

enum BackendRecoveryRuntimeMode: String, Codable {
    case normal
    case readOnly
    case signedOut
    case maintenance
}

struct RecoveryRuntimeRequestDecision: Equatable {
    let allowed: Bool
    let code: String
    let reason: String
}

struct RecoveryRuntimePolicyTransition: Equatable {
    let authorityEpochChanged: Bool
    let modeChanged: Bool
    let previousAuthorityEpoch: String
    let currentAuthorityEpoch: String
}

struct BackendRecoveryRuntimePolicy: Codable, Equatable {
    private static let infrastructurePaths: Set<String> = [
        "/health", "/live", "/ready", "/config/runtime",
    ]
    private static let readMethods: Set<String> = ["GET", "HEAD", "OPTIONS"]

    let schemaVersion: Int
    let mode: BackendRecoveryRuntimeMode
    let authorityEpoch: String
    let writesAllowed: Bool
    let authenticatedSessionPolicy: String
    let cacheWritePolicy: String
    let scope: String
    let configurationValid: Bool
    let contractVersion: Int

    static let unresolved = BackendRecoveryRuntimePolicy(
        schemaVersion: 1,
        mode: .maintenance,
        authorityEpoch: "unresolved",
        writesAllowed: false,
        authenticatedSessionPolicy: "suspend",
        cacheWritePolicy: "disabled",
        scope: "globalRecoveryFence",
        configurationValid: false,
        contractVersion: 1
    )

    init(json: [String: Any]?) {
        guard let json,
              let modeValue = json["mode"] as? String,
              let mode = BackendRecoveryRuntimeMode(rawValue: modeValue),
              let authorityEpoch = (json["authorityEpoch"] as? String)?
                .trimmingCharacters(in: .whitespacesAndNewlines),
              !authorityEpoch.isEmpty,
              Self.intValue(json["schemaVersion"]) ?? 0 >= 1,
              Self.intValue(json["contractVersion"]) ?? 0 >= 1,
              json["scope"] as? String == "globalRecoveryFence",
              json["configurationValid"] as? Bool ?? false else {
            self = .unresolved
            return
        }

        schemaVersion = Self.intValue(json["schemaVersion"]) ?? 1
        self.mode = mode
        self.authorityEpoch = authorityEpoch
        writesAllowed = (json["writesAllowed"] as? Bool ?? false) && mode == .normal
        authenticatedSessionPolicy = json["authenticatedSessionPolicy"] as? String ?? "suspend"
        cacheWritePolicy = json["cacheWritePolicy"] as? String ?? "disabled"
        scope = "globalRecoveryFence"
        configurationValid = true
        contractVersion = Self.intValue(json["contractVersion"]) ?? 1
    }

    func requestDecision(method: String, path: String) -> RecoveryRuntimeRequestDecision {
        let normalizedMethod = method.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        let normalizedPath = path.split(separator: "?", maxSplits: 1).first.map(String.init) ?? path
        if Self.infrastructurePaths.contains(normalizedPath) {
            return .init(allowed: true, code: "recoveryInfrastructureAllowed", reason: "infrastructurePath")
        }
        guard configurationValid else {
            return .init(allowed: false, code: "recoveryRuntimeUnknown", reason: "runtimePolicyUnresolved")
        }
        if mode == .normal {
            if Self.readMethods.contains(normalizedMethod) || writesAllowed {
                return .init(allowed: true, code: "recoveryNormal", reason: "normalOperation")
            }
            return .init(allowed: false, code: "recoveryWriteBlocked", reason: "writesDisabled")
        }
        if mode == .readOnly, Self.readMethods.contains(normalizedMethod) {
            return .init(allowed: true, code: "recoveryReadAllowed", reason: "readOnlyOperation")
        }
        if mode == .readOnly {
            return .init(allowed: false, code: "recoveryWriteBlocked", reason: "readOnlyRecoveryFence")
        }
        return .init(allowed: false, code: "recoveryMaintenance", reason: "\(mode.rawValue)RecoveryFence")
    }

    private init(
        schemaVersion: Int,
        mode: BackendRecoveryRuntimeMode,
        authorityEpoch: String,
        writesAllowed: Bool,
        authenticatedSessionPolicy: String,
        cacheWritePolicy: String,
        scope: String,
        configurationValid: Bool,
        contractVersion: Int
    ) {
        self.schemaVersion = schemaVersion
        self.mode = mode
        self.authorityEpoch = authorityEpoch
        self.writesAllowed = writesAllowed
        self.authenticatedSessionPolicy = authenticatedSessionPolicy
        self.cacheWritePolicy = cacheWritePolicy
        self.scope = scope
        self.configurationValid = configurationValid
        self.contractVersion = contractVersion
    }

    private static func intValue(_ value: Any?) -> Int? {
        if let value = value as? Int { return value }
        if let value = value as? NSNumber { return value.intValue }
        if let value = value as? String { return Int(value) }
        return nil
    }
}

final class RecoveryRuntimePolicyStore {
    static let shared = RecoveryRuntimePolicyStore()

    private static let storageKey = "dj.recovery.runtime.policy.v1"
    private let lock = NSLock()
    private let userDefaults: UserDefaults
    private var policy: BackendRecoveryRuntimePolicy

    init(userDefaults: UserDefaults = .standard) {
        self.userDefaults = userDefaults
        if let data = userDefaults.data(forKey: Self.storageKey),
           let restored = try? JSONDecoder().decode(BackendRecoveryRuntimePolicy.self, from: data),
           restored.configurationValid {
            policy = restored
        } else {
            policy = .unresolved
        }
    }

    var currentPolicy: BackendRecoveryRuntimePolicy {
        lock.lock()
        defer { lock.unlock() }
        return policy
    }

    @discardableResult
    func update(_ nextPolicy: BackendRecoveryRuntimePolicy) -> RecoveryRuntimePolicyTransition {
        lock.lock()
        let previous = policy
        policy = nextPolicy
        if let data = try? JSONEncoder().encode(nextPolicy) {
            userDefaults.set(data, forKey: Self.storageKey)
        } else {
            userDefaults.removeObject(forKey: Self.storageKey)
        }
        lock.unlock()

        return RecoveryRuntimePolicyTransition(
            authorityEpochChanged: previous.authorityEpoch != nextPolicy.authorityEpoch,
            modeChanged: previous.mode != nextPolicy.mode,
            previousAuthorityEpoch: previous.authorityEpoch,
            currentAuthorityEpoch: nextPolicy.authorityEpoch
        )
    }

    func requestDecision(method: String, path: String) -> RecoveryRuntimeRequestDecision {
        currentPolicy.requestDecision(method: method, path: path)
    }
}

extension Notification.Name {
    static let djRecoveryAuthorityEpochDidChange = Notification.Name(
        "dj.recovery.authorityEpochDidChange"
    )
}

enum ReleasePolicyRiskClass: String, Codable {
    case ownerTextCore
    case futureBeta
    case providerEffect

    var unavailableAccessMode: ReleasePolicyAccessMode {
        switch self {
        case .ownerTextCore:
            return .readOnly
        case .futureBeta, .providerEffect:
            return .deny
        }
    }
}

enum ReleasePolicyAccessMode: String, Codable {
    case useCachedPolicy
    case readOnly
    case deny
}

enum ReleasePolicyCacheState: String, Codable {
    case fresh
    case missing
    case expired
    case clockSkew
    case corrupt
    case scopeMismatch
    case appBuildMismatch
    case unsupportedSchema
    case emergencyRevisionStale
    case invalidScope
}

enum FeatureGatePurpose: String, Codable {
    case route
    case request
}

struct FeatureGatePolicySnapshot: Equatable {
    let accessMode: ReleasePolicyAccessMode
    let policyVersion: String?
    let policyRevision: Int?
    let emergencyRevision: Int?
    let expiresAt: Date?
    let featureEnabled: Bool
    let releaseVisible: Bool
    let reason: String

    static func unavailable(
        accessMode: ReleasePolicyAccessMode,
        reason: String
    ) -> FeatureGatePolicySnapshot {
        FeatureGatePolicySnapshot(
            accessMode: accessMode,
            policyVersion: nil,
            policyRevision: nil,
            emergencyRevision: nil,
            expiresAt: nil,
            featureEnabled: false,
            releaseVisible: false,
            reason: reason
        )
    }
}

struct FeatureDecision: Equatable {
    let decisionId: String
    let feature: DJFeature
    let purpose: FeatureGatePurpose
    let policyVersion: String?
    let policyRevision: Int?
    let emergencyRevision: Int?
    let validatedPolicyRevision: Int?
    let validatedEmergencyRevision: Int?
    let accountGeneration: String
    let allowed: Bool
    let reason: String
    let expiresAt: Date?

    var capturedPolicyRevision: Int? { policyRevision }

    func deniedForRequest(
        reason: String,
        validatedPolicyRevision: Int? = nil,
        validatedEmergencyRevision: Int? = nil
    ) -> FeatureDecision {
        FeatureDecision(
            decisionId: decisionId,
            feature: feature,
            purpose: .request,
            policyVersion: policyVersion,
            policyRevision: policyRevision,
            emergencyRevision: emergencyRevision,
            validatedPolicyRevision: validatedPolicyRevision,
            validatedEmergencyRevision: validatedEmergencyRevision,
            accountGeneration: accountGeneration,
            allowed: false,
            reason: reason,
            expiresAt: expiresAt
        )
    }
}

struct FeatureDecisionEvidenceSummary: Codable, Equatable {
    let decisionId: String
    let feature: String
    let purpose: String
    let policyVersion: String?
    let capturedPolicyRevision: Int?
    let capturedEmergencyRevision: Int?
    let validatedPolicyRevision: Int?
    let validatedEmergencyRevision: Int?
    let accountGeneration: String
    let allowed: Bool
    let reason: String
    let expiresAt: Date?

    init(decision: FeatureDecision) {
        decisionId = decision.decisionId
        feature = decision.feature.rawValue
        purpose = decision.purpose.rawValue
        policyVersion = decision.policyVersion
        capturedPolicyRevision = decision.policyRevision
        capturedEmergencyRevision = decision.emergencyRevision
        validatedPolicyRevision = decision.validatedPolicyRevision
        validatedEmergencyRevision = decision.validatedEmergencyRevision
        accountGeneration = decision.accountGeneration
        allowed = decision.allowed
        reason = decision.reason
        expiresAt = decision.expiresAt
    }
}

struct FeatureGateEvaluator {
    func capture(
        feature: DJFeature,
        risk: ReleasePolicyRiskClass,
        purpose: FeatureGatePurpose,
        localEnabled: Bool,
        qaSyntheticOverride: Bool,
        accountGeneration: String,
        policy: FeatureGatePolicySnapshot
    ) -> FeatureDecision {
        let normalizedGeneration = accountGeneration.trimmingCharacters(in: .whitespacesAndNewlines)
        let generation = normalizedGeneration.isEmpty ? "anonymous" : normalizedGeneration

        let allowed: Bool
        let reason: String
        if purpose == .route, qaSyntheticOverride {
            allowed = true
            reason = "qaSyntheticRouteOnly"
        } else if !localEnabled {
            allowed = false
            reason = "localFeatureDisabled"
        } else {
            switch policy.accessMode {
            case .useCachedPolicy:
                allowed = policy.featureEnabled && (purpose == .request || policy.releaseVisible)
                reason = allowed ? policy.reason : policy.reason
            case .readOnly:
                allowed = purpose == .route && risk == .ownerTextCore
                reason = allowed ? "ownerCoreReadOnly" : policy.reason
            case .deny:
                allowed = false
                reason = policy.reason
            }
        }

        return FeatureDecision(
            decisionId: UUID().uuidString.lowercased(),
            feature: feature,
            purpose: purpose,
            policyVersion: policy.policyVersion,
            policyRevision: policy.policyRevision,
            emergencyRevision: policy.emergencyRevision,
            validatedPolicyRevision: policy.policyRevision,
            validatedEmergencyRevision: policy.emergencyRevision,
            accountGeneration: generation,
            allowed: allowed,
            reason: reason,
            expiresAt: policy.expiresAt
        )
    }

    func revalidateForRequest(
        captured: FeatureDecision,
        localEnabled: Bool,
        accountGeneration: String,
        currentPolicy: FeatureGatePolicySnapshot,
        now: Date = Date()
    ) -> FeatureDecision {
        guard captured.allowed else {
            return captured.deniedForRequest(reason: captured.reason)
        }

        let normalizedGeneration = accountGeneration.trimmingCharacters(in: .whitespacesAndNewlines)
        let currentGeneration = normalizedGeneration.isEmpty ? "anonymous" : normalizedGeneration
        guard captured.accountGeneration == currentGeneration else {
            return captured.deniedForRequest(reason: "accountGenerationChanged")
        }
        guard localEnabled else {
            return captured.deniedForRequest(reason: "localFeatureDisabled")
        }
        if let expiresAt = captured.expiresAt, expiresAt <= now {
            return captured.deniedForRequest(
                reason: "capturedPolicyExpired",
                validatedPolicyRevision: currentPolicy.policyRevision,
                validatedEmergencyRevision: currentPolicy.emergencyRevision
            )
        }
        guard captured.policyVersion == currentPolicy.policyVersion else {
            return captured.deniedForRequest(
                reason: "policyVersionChanged",
                validatedPolicyRevision: currentPolicy.policyRevision,
                validatedEmergencyRevision: currentPolicy.emergencyRevision
            )
        }
        guard currentPolicy.accessMode == .useCachedPolicy,
              currentPolicy.featureEnabled else {
            return captured.deniedForRequest(
                reason: currentPolicy.reason,
                validatedPolicyRevision: currentPolicy.policyRevision,
                validatedEmergencyRevision: currentPolicy.emergencyRevision
            )
        }

        return FeatureDecision(
            decisionId: captured.decisionId,
            feature: captured.feature,
            purpose: .request,
            policyVersion: captured.policyVersion,
            policyRevision: captured.policyRevision,
            emergencyRevision: captured.emergencyRevision,
            validatedPolicyRevision: currentPolicy.policyRevision,
            validatedEmergencyRevision: currentPolicy.emergencyRevision,
            accountGeneration: captured.accountGeneration,
            allowed: true,
            reason: "capturedPolicyRevalidated",
            expiresAt: captured.expiresAt
        )
    }
}

struct ReleasePolicyCacheScope: Hashable {
    let accountOrAnonymousScope: String
    let appBuild: String
    let audience: String
    let cohort: String

    init(
        accountUserId: String?,
        appBuild: String,
        audience: String = "owner",
        cohort: String = "closedPilotAdultSelf"
    ) {
        let normalizedAccount = accountUserId?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        if normalizedAccount.isEmpty {
            accountOrAnonymousScope = "anonymous"
        } else {
            accountOrAnonymousScope = "account:\(Self.digest(normalizedAccount))"
        }

        let normalizedBuild = appBuild.trimmingCharacters(in: .whitespacesAndNewlines)
        self.appBuild = normalizedBuild.isEmpty ? "unknown" : normalizedBuild
        self.audience = audience.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        self.cohort = cohort.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var isValid: Bool {
        !accountOrAnonymousScope.isEmpty
            && appBuild != "unknown"
            && appBuild != "0"
            && ["owner", "family", "visitor", "qa"].contains(audience)
            && !cohort.isEmpty
    }

    fileprivate var storageFingerprint: String {
        Self.digest("\(accountOrAnonymousScope)|\(appBuild)|\(audience)|\(cohort)")
    }

    private static func digest(_ value: String) -> String {
        SHA256.hash(data: Data(value.utf8)).map { String(format: "%02x", $0) }.joined()
    }
}

struct ReleasePolicyCacheEnvelope: Codable, Equatable {
    static let currentEnvelopeVersion = 2
    static let supportedPolicySchemaVersion = 1

    let envelopeVersion: Int
    let policySchemaVersion: Int
    let policyVersion: String
    let policyRevision: Int
    let emergencyRevision: Int
    let accountOrAnonymousScope: String
    let appBuild: String
    let audience: String
    let cohort: String
    let fetchedAt: Date
    let expiresAt: Date
    let payloadHash: String
    let payload: Data
}

struct ReleasePolicyCacheEvaluation: Equatable {
    let state: ReleasePolicyCacheState
    let accessMode: ReleasePolicyAccessMode
    let reason: String
    let policyVersion: String?
    let policyRevision: Int?
    let emergencyRevision: Int?
    let ageSeconds: TimeInterval?
    let payload: Data?
}

enum ReleasePolicyStoreError: LocalizedError {
    case invalidScope
    case invalidMetadata
    case invalidLifetime

    var errorDescription: String? {
        switch self {
        case .invalidScope:
            return "发布策略缓存作用域无效"
        case .invalidMetadata:
            return "发布策略缓存元数据无效"
        case .invalidLifetime:
            return "发布策略缓存有效期无效"
        }
    }
}

final class ReleasePolicyStore {
    static let shared = ReleasePolicyStore()

    private static let storagePrefix = "dj.releasePolicy.cache.v2"
    private static let maximumFutureClockSkew: TimeInterval = 300

    private let userDefaults: UserDefaults
    private let lock = NSLock()
    init(userDefaults: UserDefaults = .standard) {
        self.userDefaults = userDefaults
    }

    func save(
        payload: Data,
        policySchemaVersion: Int,
        policyVersion: String,
        policyRevision: Int,
        emergencyRevision: Int,
        scope: ReleasePolicyCacheScope,
        fetchedAt: Date,
        expiresAt: Date
    ) throws {
        guard scope.isValid else { throw ReleasePolicyStoreError.invalidScope }
        let normalizedVersion = policyVersion.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !payload.isEmpty,
              !normalizedVersion.isEmpty,
              policySchemaVersion > 0,
              policyRevision >= 0,
              emergencyRevision >= 0 else {
            throw ReleasePolicyStoreError.invalidMetadata
        }
        guard expiresAt > fetchedAt else { throw ReleasePolicyStoreError.invalidLifetime }

        let envelope = ReleasePolicyCacheEnvelope(
            envelopeVersion: ReleasePolicyCacheEnvelope.currentEnvelopeVersion,
            policySchemaVersion: policySchemaVersion,
            policyVersion: normalizedVersion,
            policyRevision: policyRevision,
            emergencyRevision: emergencyRevision,
            accountOrAnonymousScope: scope.accountOrAnonymousScope,
            appBuild: scope.appBuild,
            audience: scope.audience,
            cohort: scope.cohort,
            fetchedAt: fetchedAt,
            expiresAt: expiresAt,
            payloadHash: Self.payloadHash(payload),
            payload: payload
        )
        let encoded = try JSONEncoder().encode(envelope)

        lock.lock()
        defer { lock.unlock() }
        userDefaults.set(encoded, forKey: storageKey(for: scope))
    }

    func evaluate(
        scope: ReleasePolicyCacheScope,
        risk: ReleasePolicyRiskClass,
        now: Date = Date(),
        minimumEmergencyRevision: Int = 0
    ) -> ReleasePolicyCacheEvaluation {
        guard scope.isValid else {
            return unavailable(state: .invalidScope, risk: risk, reason: "invalidScope")
        }

        lock.lock()
        let encoded = userDefaults.data(forKey: storageKey(for: scope))
        lock.unlock()

        guard let encoded else {
            return unavailable(state: .missing, risk: risk, reason: "missingPolicyCache")
        }
        guard let envelope = try? JSONDecoder().decode(ReleasePolicyCacheEnvelope.self, from: encoded) else {
            return unavailable(state: .corrupt, risk: risk, reason: "corruptPolicyCache")
        }
        guard envelope.accountOrAnonymousScope == scope.accountOrAnonymousScope else {
            return unavailable(state: .scopeMismatch, risk: risk, reason: "accountScopeMismatch", envelope: envelope, now: now)
        }
        guard envelope.appBuild == scope.appBuild else {
            return unavailable(state: .appBuildMismatch, risk: risk, reason: "appBuildMismatch", envelope: envelope, now: now)
        }
        guard envelope.audience == scope.audience,
              envelope.cohort == scope.cohort else {
            return unavailable(
                state: .scopeMismatch,
                risk: risk,
                reason: "policyAudienceOrCohortMismatch",
                envelope: envelope,
                now: now
            )
        }
        guard envelope.envelopeVersion == ReleasePolicyCacheEnvelope.currentEnvelopeVersion,
              envelope.policySchemaVersion == ReleasePolicyCacheEnvelope.supportedPolicySchemaVersion else {
            return unavailable(state: .unsupportedSchema, risk: risk, reason: "unsupportedPolicySchema", envelope: envelope, now: now)
        }
        guard envelope.payloadHash == Self.payloadHash(envelope.payload),
              !envelope.payload.isEmpty,
              envelope.expiresAt > envelope.fetchedAt else {
            return unavailable(state: .corrupt, risk: risk, reason: "invalidPolicyCacheIntegrity", envelope: envelope, now: now)
        }
        guard now >= envelope.fetchedAt.addingTimeInterval(-Self.maximumFutureClockSkew) else {
            return unavailable(state: .clockSkew, risk: risk, reason: "policyCacheClockSkew", envelope: envelope, now: now)
        }
        guard envelope.emergencyRevision >= max(0, minimumEmergencyRevision) else {
            return unavailable(
                state: .emergencyRevisionStale,
                risk: risk,
                reason: "emergencyRevisionStale",
                envelope: envelope,
                now: now
            )
        }
        guard now < envelope.expiresAt else {
            return unavailable(state: .expired, risk: risk, reason: "expiredPolicyCache", envelope: envelope, now: now)
        }

        return ReleasePolicyCacheEvaluation(
            state: .fresh,
            accessMode: .useCachedPolicy,
            reason: "freshPolicyCache",
            policyVersion: envelope.policyVersion,
            policyRevision: envelope.policyRevision,
            emergencyRevision: envelope.emergencyRevision,
            ageSeconds: max(0, now.timeIntervalSince(envelope.fetchedAt)),
            payload: envelope.payload
        )
    }

    func remove(scope: ReleasePolicyCacheScope) {
        lock.lock()
        defer { lock.unlock() }
        userDefaults.removeObject(forKey: storageKey(for: scope))
    }

    func storageKey(for scope: ReleasePolicyCacheScope) -> String {
        "\(Self.storagePrefix).\(scope.storageFingerprint)"
    }

    private func unavailable(
        state: ReleasePolicyCacheState,
        risk: ReleasePolicyRiskClass,
        reason: String,
        envelope: ReleasePolicyCacheEnvelope? = nil,
        now: Date? = nil
    ) -> ReleasePolicyCacheEvaluation {
        ReleasePolicyCacheEvaluation(
            state: state,
            accessMode: risk.unavailableAccessMode,
            reason: reason,
            policyVersion: envelope?.policyVersion,
            policyRevision: envelope?.policyRevision,
            emergencyRevision: envelope?.emergencyRevision,
            ageSeconds: envelope.flatMap { envelope in
                now.map { max(0, $0.timeIntervalSince(envelope.fetchedAt)) }
            },
            payload: nil
        )
    }

    private static func payloadHash(_ payload: Data) -> String {
        SHA256.hash(data: payload).map { String(format: "%02x", $0) }.joined()
    }
}
