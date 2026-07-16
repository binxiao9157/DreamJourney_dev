import CryptoKit
import Foundation

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

struct ReleasePolicyCacheScope: Hashable {
    let accountOrAnonymousScope: String
    let appBuild: String

    init(accountUserId: String?, appBuild: String) {
        let normalizedAccount = accountUserId?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        if normalizedAccount.isEmpty {
            accountOrAnonymousScope = "anonymous"
        } else {
            accountOrAnonymousScope = "account:\(Self.digest(normalizedAccount))"
        }

        let normalizedBuild = appBuild.trimmingCharacters(in: .whitespacesAndNewlines)
        self.appBuild = normalizedBuild.isEmpty ? "unknown" : normalizedBuild
    }

    var isValid: Bool {
        !accountOrAnonymousScope.isEmpty && appBuild != "unknown" && appBuild != "0"
    }

    fileprivate var storageFingerprint: String {
        Self.digest("\(accountOrAnonymousScope)|\(appBuild)")
    }

    private static func digest(_ value: String) -> String {
        SHA256.hash(data: Data(value.utf8)).map { String(format: "%02x", $0) }.joined()
    }
}

struct ReleasePolicyCacheEnvelope: Codable, Equatable {
    static let currentEnvelopeVersion = 1
    static let supportedPolicySchemaVersion = 1

    let envelopeVersion: Int
    let policySchemaVersion: Int
    let policyVersion: String
    let policyRevision: Int
    let emergencyRevision: Int
    let accountOrAnonymousScope: String
    let appBuild: String
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

    private static let storagePrefix = "dj.releasePolicy.cache.v1"
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
