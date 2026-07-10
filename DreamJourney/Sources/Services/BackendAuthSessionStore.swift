import Foundation
import KeychainAccess

struct BackendAuthSessionContract: Codable, Equatable {
    let sessionId: String
    let userId: String
    let tokenType: String
    let accessToken: String
    let refreshToken: String
    let accessExpiresInSeconds: Int
    let refreshExpiresInSeconds: Int
    let accessExpiresAt: String
    let refreshExpiresAt: String
    let contractVersion: Int

    init?(json: [String: Any]) {
        guard let sessionId = Self.string(json["sessionId"]),
              let userId = Self.string(json["userId"]),
              let accessToken = Self.string(json["accessToken"]),
              let refreshToken = Self.string(json["refreshToken"]),
              let accessExpiresAt = Self.string(json["accessExpiresAt"]),
              let refreshExpiresAt = Self.string(json["refreshExpiresAt"]),
              !sessionId.isEmpty,
              !userId.isEmpty,
              accessToken.hasPrefix("dja_"),
              refreshToken.hasPrefix("djr_") else {
            return nil
        }
        self.sessionId = sessionId
        self.userId = userId
        tokenType = Self.string(json["tokenType"]) ?? "Bearer"
        self.accessToken = accessToken
        self.refreshToken = refreshToken
        accessExpiresInSeconds = Self.int(json["accessExpiresInSeconds"]) ?? 0
        refreshExpiresInSeconds = Self.int(json["refreshExpiresInSeconds"]) ?? 0
        self.accessExpiresAt = accessExpiresAt
        self.refreshExpiresAt = refreshExpiresAt
        contractVersion = Self.int(json["contractVersion"]) ?? 1
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

final class BackendAuthSessionStore {
    static let shared = BackendAuthSessionStore()

    private let storageKey = "current-auth-session"
    private let keychain: Keychain
    private let lock = NSLock()
    private var cachedSession: BackendAuthSessionContract?
    private var didLoad = false

    private init() {
        keychain = Keychain(service: "com.dreamjourney.backend-auth-session")
            .accessibility(.afterFirstUnlockThisDeviceOnly)
            .synchronizable(false)
    }

    var currentSession: BackendAuthSessionContract? {
        lock.lock()
        defer { lock.unlock() }
        if !didLoad {
            cachedSession = loadFromKeychain()
            didLoad = true
        }
        return cachedSession
    }

    func save(_ session: BackendAuthSessionContract) throws {
        let encoded = try JSONEncoder().encode(session)
        lock.lock()
        defer { lock.unlock() }
        try keychain.set(encoded, key: storageKey)
        cachedSession = session
        didLoad = true
    }

    func clear(sessionId: String? = nil) {
        lock.lock()
        defer { lock.unlock() }
        if !didLoad {
            cachedSession = loadFromKeychain()
            didLoad = true
        }
        if let sessionId, cachedSession?.sessionId != sessionId {
            return
        }
        try? keychain.remove(storageKey)
        cachedSession = nil
    }

    private func loadFromKeychain() -> BackendAuthSessionContract? {
        guard let data = try? keychain.getData(storageKey) else {
            return nil
        }
        return try? JSONDecoder().decode(BackendAuthSessionContract.self, from: data)
    }
}
