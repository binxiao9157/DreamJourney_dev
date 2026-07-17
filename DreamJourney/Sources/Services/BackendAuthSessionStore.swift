import Foundation
import KeychainAccess

struct BackendAuthSessionContract: Codable, Equatable, Sendable {
    let sessionId: String
    let userId: String
    let subjectId: String?
    let parentSessionId: String?
    let tokenType: String
    let accessToken: String
    let refreshToken: String
    let accessExpiresInSeconds: Int
    let refreshExpiresInSeconds: Int
    let accessExpiresAt: String
    let refreshExpiresAt: String
    let contractVersion: Int
    let tokenFamilyId: String?
    let sessionVersion: Int?

    private enum CodingKeys: String, CodingKey {
        case sessionId
        case userId
        case subjectId
        case parentSessionId
        case tokenType
        case accessToken
        case refreshToken
        case accessExpiresInSeconds
        case refreshExpiresInSeconds
        case accessExpiresAt
        case refreshExpiresAt
        case contractVersion
        case tokenFamilyId
        case sessionVersion
    }

    var isLegacy: Bool {
        contractVersion == 1
    }

    var isPrivateAccessEligible: Bool {
        contractVersion == 2
            && (subjectId == nil || subjectId == userId)
            && tokenFamilyId?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false
            && (sessionVersion ?? 0) > 0
            && isRefreshCredentialUsable
    }

    var isRefreshCredentialUsable: Bool {
        guard let expiresAt = Self.backendDate(from: refreshExpiresAt) else { return false }
        return expiresAt > Date()
    }

    func isPrivateAccessEligible(for userId: String) -> Bool {
        let expectedUserId = userId.trimmingCharacters(in: .whitespacesAndNewlines)
        return isPrivateAccessEligible
            && !expectedUserId.isEmpty
            && self.userId == expectedUserId
    }

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

        let parsedContractVersion: Int
        if json["contractVersion"] == nil {
            parsedContractVersion = 1
        } else if let contractVersion = Self.strictInt(json["contractVersion"]) {
            parsedContractVersion = contractVersion
        } else {
            return nil
        }

        let tokenFamilyId: String?
        let sessionVersion: Int?
        switch parsedContractVersion {
        case 1:
            tokenFamilyId = nil
            sessionVersion = nil
        case 2:
            guard let parsedTokenFamilyId = Self.string(json["tokenFamilyId"]),
                  !parsedTokenFamilyId.isEmpty,
                  let parsedSessionVersion = Self.strictInt(json["sessionVersion"]),
                  parsedSessionVersion > 0 else {
                return nil
            }
            tokenFamilyId = parsedTokenFamilyId
            sessionVersion = parsedSessionVersion
        default:
            return nil
        }

        self.sessionId = sessionId
        self.userId = userId
        subjectId = Self.string(json["subjectId"])
        parentSessionId = Self.string(json["parentSessionId"])
        if let subjectId, subjectId != userId {
            return nil
        }
        tokenType = Self.string(json["tokenType"]) ?? "Bearer"
        self.accessToken = accessToken
        self.refreshToken = refreshToken
        accessExpiresInSeconds = Self.int(json["accessExpiresInSeconds"]) ?? 0
        refreshExpiresInSeconds = Self.int(json["refreshExpiresInSeconds"]) ?? 0
        self.accessExpiresAt = accessExpiresAt
        self.refreshExpiresAt = refreshExpiresAt
        contractVersion = parsedContractVersion
        self.tokenFamilyId = tokenFamilyId
        self.sessionVersion = sessionVersion
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let decodedSessionId = try container.decode(String.self, forKey: .sessionId)
            .trimmingCharacters(in: .whitespacesAndNewlines)
        let decodedUserId = try container.decode(String.self, forKey: .userId)
            .trimmingCharacters(in: .whitespacesAndNewlines)
        let decodedAccessToken = try container.decode(String.self, forKey: .accessToken)
            .trimmingCharacters(in: .whitespacesAndNewlines)
        let decodedRefreshToken = try container.decode(String.self, forKey: .refreshToken)
            .trimmingCharacters(in: .whitespacesAndNewlines)
        guard !decodedSessionId.isEmpty,
              !decodedUserId.isEmpty,
              decodedAccessToken.hasPrefix("dja_"),
              decodedRefreshToken.hasPrefix("djr_") else {
            throw DecodingError.dataCorrupted(.init(
                codingPath: decoder.codingPath,
                debugDescription: "Stored auth session identity or token format is invalid"
            ))
        }

        let decodedContractVersion = try container.decodeIfPresent(Int.self, forKey: .contractVersion) ?? 1
        let decodedTokenFamilyId: String?
        let decodedSessionVersion: Int?
        switch decodedContractVersion {
        case 1:
            decodedTokenFamilyId = nil
            decodedSessionVersion = nil
        case 2:
            let familyId = try container.decodeIfPresent(String.self, forKey: .tokenFamilyId)?
                .trimmingCharacters(in: .whitespacesAndNewlines)
            guard let familyId, !familyId.isEmpty else {
                throw DecodingError.dataCorruptedError(
                    forKey: .tokenFamilyId,
                    in: container,
                    debugDescription: "Contract v2 auth session requires tokenFamilyId"
                )
            }
            guard let sessionVersion = try container.decodeIfPresent(Int.self, forKey: .sessionVersion),
                  sessionVersion > 0 else {
                throw DecodingError.dataCorruptedError(
                    forKey: .sessionVersion,
                    in: container,
                    debugDescription: "Contract v2 auth session requires a positive sessionVersion"
                )
            }
            decodedTokenFamilyId = familyId
            decodedSessionVersion = sessionVersion
        default:
            throw DecodingError.dataCorruptedError(
                forKey: .contractVersion,
                in: container,
                debugDescription: "Unsupported auth session contract version"
            )
        }

        sessionId = decodedSessionId
        userId = decodedUserId
        subjectId = try container.decodeIfPresent(String.self, forKey: .subjectId)?
            .trimmingCharacters(in: .whitespacesAndNewlines)
        parentSessionId = try container.decodeIfPresent(String.self, forKey: .parentSessionId)?
            .trimmingCharacters(in: .whitespacesAndNewlines)
        if let subjectId, !subjectId.isEmpty, subjectId != decodedUserId {
            throw DecodingError.dataCorruptedError(
                forKey: .subjectId,
                in: container,
                debugDescription: "Stored auth subject does not match userId"
            )
        }
        tokenType = try container.decodeIfPresent(String.self, forKey: .tokenType) ?? "Bearer"
        accessToken = decodedAccessToken
        refreshToken = decodedRefreshToken
        accessExpiresInSeconds = try container.decodeIfPresent(Int.self, forKey: .accessExpiresInSeconds) ?? 0
        refreshExpiresInSeconds = try container.decodeIfPresent(Int.self, forKey: .refreshExpiresInSeconds) ?? 0
        accessExpiresAt = try container.decode(String.self, forKey: .accessExpiresAt)
        refreshExpiresAt = try container.decode(String.self, forKey: .refreshExpiresAt)
        contractVersion = decodedContractVersion
        tokenFamilyId = decodedTokenFamilyId
        sessionVersion = decodedSessionVersion
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(sessionId, forKey: .sessionId)
        try container.encode(userId, forKey: .userId)
        try container.encodeIfPresent(subjectId, forKey: .subjectId)
        try container.encodeIfPresent(parentSessionId, forKey: .parentSessionId)
        try container.encode(tokenType, forKey: .tokenType)
        try container.encode(accessToken, forKey: .accessToken)
        try container.encode(refreshToken, forKey: .refreshToken)
        try container.encode(accessExpiresInSeconds, forKey: .accessExpiresInSeconds)
        try container.encode(refreshExpiresInSeconds, forKey: .refreshExpiresInSeconds)
        try container.encode(accessExpiresAt, forKey: .accessExpiresAt)
        try container.encode(refreshExpiresAt, forKey: .refreshExpiresAt)
        try container.encode(contractVersion, forKey: .contractVersion)

        switch contractVersion {
        case 1:
            break
        case 2:
            guard let tokenFamilyId, let sessionVersion, sessionVersion > 0 else {
                throw EncodingError.invalidValue(
                    self,
                    .init(
                        codingPath: encoder.codingPath,
                        debugDescription: "Contract v2 auth session has incomplete lineage"
                    )
                )
            }
            try container.encode(tokenFamilyId, forKey: .tokenFamilyId)
            try container.encode(sessionVersion, forKey: .sessionVersion)
        default:
            throw EncodingError.invalidValue(
                self,
                .init(
                    codingPath: encoder.codingPath,
                    debugDescription: "Unsupported auth session contract version"
                )
            )
        }
    }

    func isValidRefreshSuccessor(of captured: BackendAuthSessionContract) -> Bool {
        guard userId == captured.userId,
              sessionId != captured.sessionId else {
            return false
        }

        switch (captured.contractVersion, contractVersion) {
        case (2, 2):
            guard let capturedFamilyId = captured.tokenFamilyId,
                  let tokenFamilyId,
                  let capturedVersion = captured.sessionVersion,
                  let sessionVersion else {
                return false
            }
            return tokenFamilyId == capturedFamilyId
                && sessionVersion == capturedVersion + 1
                && (subjectId == nil || subjectId == userId)
                && (parentSessionId == nil || parentSessionId == captured.sessionId)
        default:
            return false
        }
    }

    func matchesCASIdentity(_ captured: BackendAuthSessionContract) -> Bool {
        userId == captured.userId
            && sessionId == captured.sessionId
            && tokenFamilyId == captured.tokenFamilyId
            && sessionVersion == captured.sessionVersion
    }

    private static func string(_ value: Any?) -> String? {
        (value as? String)?.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private static func strictInt(_ value: Any?) -> Int? {
        guard let value, !(value is Bool) else { return nil }
        if let value = value as? Int { return value }
        guard let number = value as? NSNumber else { return nil }
        let doubleValue = number.doubleValue
        guard doubleValue.isFinite,
              doubleValue.rounded(.towardZero) == doubleValue,
              number.compare(NSNumber(value: Int.min)) != .orderedAscending,
              number.compare(NSNumber(value: Int.max)) != .orderedDescending else {
            return nil
        }
        return number.intValue
    }

    private static func int(_ value: Any?) -> Int? {
        if let value = value as? Int { return value }
        if let value = value as? NSNumber { return value.intValue }
        if let value = value as? String { return Int(value) }
        return nil
    }

    private static func backendDate(from value: String) -> Date? {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let date = formatter.date(from: value) {
            return date
        }
        formatter.formatOptions = [.withInternetDateTime]
        return formatter.date(from: value)
    }
}

enum BackendAuthSessionStoreError: Error {
    case ineligibleSessionWriteRejected
}

struct BackendAccountLease: Equatable {
    let userId: String
    let sessionId: String
    let contractVersion: Int
    let tokenFamilyId: String?
    let sessionVersion: Int?

    init(session: BackendAuthSessionContract) {
        userId = session.userId
        sessionId = session.sessionId
        contractVersion = session.contractVersion
        tokenFamilyId = session.tokenFamilyId
        sessionVersion = session.sessionVersion
    }

    func permits(
        session currentSession: BackendAuthSessionContract?,
        currentUserId: String?
    ) -> Bool {
        guard currentUserId == userId,
              let currentSession,
              currentSession.userId == userId,
              currentSession.contractVersion == contractVersion else {
            return false
        }

        if currentSession.sessionId == sessionId {
            return currentSession.tokenFamilyId == tokenFamilyId
                && currentSession.sessionVersion == sessionVersion
        }

        guard contractVersion == 2,
              let tokenFamilyId,
              let sessionVersion,
              currentSession.tokenFamilyId == tokenFamilyId,
              let currentVersion = currentSession.sessionVersion else {
            return false
        }
        return currentVersion > sessionVersion
    }
}

final class BackendAuthSessionStore: @unchecked Sendable {
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
        loadIfNeededLocked()
        return cachedSession
    }

    func save(_ session: BackendAuthSessionContract) throws {
        guard session.isPrivateAccessEligible else {
            throw BackendAuthSessionStoreError.ineligibleSessionWriteRejected
        }
        let encoded = try JSONEncoder().encode(session)
        lock.lock()
        defer { lock.unlock() }
        try keychain.set(encoded, key: storageKey)
        cachedSession = session
        didLoad = true
    }

    @discardableResult
    func replace(
        _ session: BackendAuthSessionContract,
        ifCurrentMatches captured: BackendAuthSessionContract
    ) throws -> Bool {
        guard session.isPrivateAccessEligible else {
            throw BackendAuthSessionStoreError.ineligibleSessionWriteRejected
        }
        let encoded = try JSONEncoder().encode(session)
        lock.lock()
        defer { lock.unlock() }
        loadIfNeededLocked()
        guard cachedSession?.matchesCASIdentity(captured) == true else {
            return false
        }
        try keychain.set(encoded, key: storageKey)
        cachedSession = session
        return true
    }

    func clear() {
        lock.lock()
        defer { lock.unlock() }
        loadIfNeededLocked()
        try? keychain.remove(storageKey)
        cachedSession = nil
    }

    @discardableResult
    func clear(ifCurrentMatches captured: BackendAuthSessionContract) -> Bool {
        lock.lock()
        defer { lock.unlock() }
        loadIfNeededLocked()
        guard cachedSession?.matchesCASIdentity(captured) == true else {
            return false
        }
        try? keychain.remove(storageKey)
        cachedSession = nil
        return true
    }

    private func loadIfNeededLocked() {
        guard !didLoad else { return }
        cachedSession = loadFromKeychain()
        didLoad = true
    }

    private func loadFromKeychain() -> BackendAuthSessionContract? {
        guard let data = try? keychain.getData(storageKey) else {
            return nil
        }
        return try? JSONDecoder().decode(BackendAuthSessionContract.self, from: data)
    }
}
