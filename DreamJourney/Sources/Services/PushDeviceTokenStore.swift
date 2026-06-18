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

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    func saveDeviceToken(_ token: String) {
        let normalizedToken = token.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !normalizedToken.isEmpty else { return }
        defaults.set(normalizedToken, forKey: deviceTokenKey)
    }

    func loadDeviceToken() -> String? {
        guard let token = defaults.string(forKey: deviceTokenKey),
              !token.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return nil
        }
        return token
    }

    func saveRegistration(_ registration: PushDeviceTokenRegistration) -> Bool {
        guard let data = try? JSONEncoder().encode(registration) else {
            return false
        }
        defaults.set(data, forKey: storageKey)
        return true
    }

    func loadRegistration() -> PushDeviceTokenRegistration? {
        guard let data = defaults.data(forKey: storageKey) else {
            return nil
        }
        return try? JSONDecoder().decode(PushDeviceTokenRegistration.self, from: data)
    }

    func registration(for userId: String) -> PushDeviceTokenRegistration? {
        guard let registration = loadRegistration(), registration.userId == userId else {
            return nil
        }
        return registration
    }

    func clear() {
        defaults.removeObject(forKey: storageKey)
        defaults.removeObject(forKey: deviceTokenKey)
    }
}
