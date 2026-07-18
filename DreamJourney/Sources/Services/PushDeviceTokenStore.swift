import Foundation

struct PushDeviceTokenRegistration: Codable, Equatable {
    let userId: String
    let deviceTokenId: String
    let deviceTokenHash: String
    let platform: String
    let environment: String
    let deviceId: String
    let deliveryProviderState: String

    init(
        userId: String,
        deviceTokenId: String,
        deviceTokenHash: String,
        platform: String,
        environment: String,
        deviceId: String,
        deliveryProviderState: String
    ) {
        self.userId = userId
        self.deviceTokenId = deviceTokenId
        self.deviceTokenHash = deviceTokenHash
        self.platform = platform
        self.environment = environment
        self.deviceId = deviceId
        self.deliveryProviderState = deliveryProviderState
    }

    init?(json: [String: Any]) {
        guard let userId = json["userId"] as? String,
              let deviceTokenId = json["deviceTokenId"] as? String,
              let deviceTokenHash = json["deviceTokenHash"] as? String,
              let platform = json["platform"] as? String,
              let environment = json["environment"] as? String,
              let deviceId = json["deviceId"] as? String else {
            return nil
        }

        self.userId = userId
        self.deviceTokenId = deviceTokenId
        self.deviceTokenHash = deviceTokenHash
        self.platform = platform
        self.environment = environment
        self.deviceId = deviceId
        self.deliveryProviderState = json["deliveryProviderState"] as? String ?? "pending"
    }
}

private struct PushDeviceTokenRegistrationEnvelope: Codable {
    let subjectId: String
    let vaultId: String
    let generation: UInt64
    let generationId: UUID
    let authorityEpoch: String
    let registration: PushDeviceTokenRegistration

    init(registration: PushDeviceTokenRegistration, accountLease: AccountLease) {
        subjectId = accountLease.subjectId
        vaultId = accountLease.vaultId
        generation = accountLease.generation
        generationId = accountLease.generationId
        authorityEpoch = accountLease.authorityEpoch
        self.registration = registration
    }

    func matches(_ accountLease: AccountLease) -> Bool {
        subjectId == accountLease.subjectId
            && vaultId == accountLease.vaultId
            && generation == accountLease.generation
            && generationId == accountLease.generationId
            && authorityEpoch == accountLease.authorityEpoch
    }

    func matchesLifecycleLease(_ accountLease: AccountLease) -> Bool {
        subjectId == accountLease.subjectId
            && vaultId == accountLease.vaultId
            && generation == accountLease.generation
            && generationId == accountLease.generationId
            && authorityEpoch == accountLease.authorityEpoch
    }
}

enum PushDeviceTokenEnvironment {
    static var current: String {
        #if DEBUG
        return "sandbox"
        #else
        return "production"
        #endif
    }
}

final class PushDeviceTokenStore {
    static let shared = PushDeviceTokenStore()

    private let storageKey = "dj.pushDeviceToken.registration"
    private let deviceTokenKey = "dj.pushDeviceToken.localToken"
    private let defaults: UserDefaults
    private let accountLeaseRuntime: AccountLeaseRuntimePort
    private let lock = NSLock()

    init(
        defaults: UserDefaults = .standard,
        accountLeaseRuntime: AccountLeaseRuntimePort = AccountLeaseRuntime.shared
    ) {
        self.defaults = defaults
        self.accountLeaseRuntime = accountLeaseRuntime
    }

    func saveDeviceToken(_ token: String) {
        let normalizedToken = token.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !normalizedToken.isEmpty else { return }
        withLock {
            defaults.set(normalizedToken, forKey: deviceTokenKey)
        }
    }

    func loadDeviceToken() -> String? {
        withLock {
            guard let token = defaults.string(forKey: deviceTokenKey),
                  !token.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
                return nil
            }
            return token
        }
    }

    func saveRegistration(
        _ registration: PushDeviceTokenRegistration,
        accountLease: AccountLease
    ) -> Bool {
        guard registration.userId == accountLease.subjectId,
              accountLeaseRuntime.validate(accountLease, at: .commit).allowed,
              let data = try? JSONEncoder().encode(
                  PushDeviceTokenRegistrationEnvelope(
                      registration: registration,
                      accountLease: accountLease
                  )
              ) else {
            return false
        }
        return withLock {
            defaults.set(data, forKey: storageKey)
            guard accountLeaseRuntime.validate(accountLease, at: .commit).allowed else {
                if defaults.data(forKey: storageKey) == data {
                    defaults.removeObject(forKey: storageKey)
                }
                return false
            }
            return defaults.data(forKey: storageKey) == data
        }
    }

    func loadRegistration() -> PushDeviceTokenRegistration? {
        guard let accountLease = accountLeaseRuntime.capture(forSubjectId: nil),
              accountLeaseRuntime.validate(accountLease, at: .request).allowed else {
            return nil
        }
        let registration = withLock { () -> PushDeviceTokenRegistration? in
            guard let data = defaults.data(forKey: storageKey),
                  let envelope = try? JSONDecoder().decode(
                      PushDeviceTokenRegistrationEnvelope.self,
                      from: data
                  ),
                  envelope.matches(accountLease),
                  envelope.registration.userId == accountLease.subjectId else {
                return nil
            }
            return envelope.registration
        }
        guard accountLeaseRuntime.validate(accountLease, at: .runtime).allowed else { return nil }
        return registration
    }

    func registration(for userId: String) -> PushDeviceTokenRegistration? {
        guard let registration = loadRegistration(), registration.userId == userId else {
            return nil
        }
        return registration
    }

    func clear() {
        withLock {
            defaults.removeObject(forKey: storageKey)
            defaults.removeObject(forKey: deviceTokenKey)
        }
    }

    @discardableResult
    func teardownForAccountLifecycle(oldAccountLease: AccountLease?) -> Bool {
        guard let oldAccountLease else { return false }
        return withLock {
            guard let data = defaults.data(forKey: storageKey) else { return true }
            guard let envelope = try? JSONDecoder().decode(
                PushDeviceTokenRegistrationEnvelope.self,
                from: data
            ) else {
                return false
            }
            guard envelope.matchesLifecycleLease(oldAccountLease) else { return true }
            let deviceTokenBeforeTeardown = defaults.string(forKey: deviceTokenKey)
            defaults.removeObject(forKey: storageKey)
            return defaults.data(forKey: storageKey) == nil
                && defaults.string(forKey: deviceTokenKey) == deviceTokenBeforeTeardown
        }
    }

    private func withLock<T>(_ body: () -> T) -> T {
        lock.lock()
        defer { lock.unlock() }
        return body()
    }
}
