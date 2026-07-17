import Foundation

struct BackendIdentityChallengeCapability: Equatable {
    let enabled: Bool
    let providerMode: String
    let productionReady: Bool
    let clientFlowEnabled: Bool
    let challengeEndpoint: String
    let verifyEndpointTemplate: String
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
        return productionReady || providerMode == "synthetic"
    }

    init(json: [String: Any]?) {
        let parsedEnabled = Self.bool(json?["enabled"])
        let parsedProviderMode = Self.string(json?["providerMode"])
        let parsedProductionReady = Self.bool(json?["productionReady"])
        let parsedClientFlowEnabled = Self.bool(json?["clientFlowEnabled"])
        let parsedChallengeEndpoint = Self.string(json?["challengeEndpoint"])
        let parsedVerifyEndpoint = Self.string(json?["verifyEndpointTemplate"])
        let parsedContractVersion = Self.int(json?["contractVersion"])
        enabled = parsedEnabled ?? false
        providerMode = parsedProviderMode ?? "unavailable"
        productionReady = parsedProductionReady ?? false
        clientFlowEnabled = parsedClientFlowEnabled ?? false
        challengeEndpoint = parsedChallengeEndpoint ?? ""
        verifyEndpointTemplate = parsedVerifyEndpoint ?? ""
        contractVersion = parsedContractVersion ?? 0
        contractFieldsComplete = parsedEnabled != nil
            && parsedProviderMode != nil
            && parsedProductionReady != nil
            && parsedClientFlowEnabled != nil
            && parsedChallengeEndpoint != nil
            && parsedVerifyEndpoint != nil
            && parsedContractVersion != nil
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

struct BackendIdentityChallengeContract: Equatable {
    let challengeId: String
    let purpose: String
    let deliveryMode: String
    let expiresAt: String
    let retryAfterSeconds: Int
    let productionReady: Bool
    let contractVersion: Int
    let expiresAtDate: Date

    init?(json object: [String: Any], now: Date = Date()) {
        guard Self.string(object["status"]) == "accepted",
              let json = object["challenge"] as? [String: Any] else {
            return nil
        }
        guard let challengeId = Self.string(json["challengeId"]),
              let purpose = Self.string(json["purpose"]),
              let deliveryMode = Self.string(json["deliveryMode"]),
              let expiresAt = Self.string(json["expiresAt"]),
              let expiresAtDate = Self.iso8601Date(expiresAt),
              !challengeId.isEmpty,
              ["login", "register", "restore", "invitation"].contains(purpose),
              deliveryMode == "acceptedOnly",
              Self.int(json["contractVersion"]) == 1,
              expiresAtDate > now else {
            return nil
        }
        self.challengeId = challengeId
        self.purpose = purpose
        self.deliveryMode = deliveryMode
        self.expiresAt = expiresAt
        self.expiresAtDate = expiresAtDate
        retryAfterSeconds = max(0, Self.int(json["retryAfterSeconds"]) ?? 0)
        productionReady = Self.bool(json["productionReady"]) ?? false
        contractVersion = 1
    }

    func isExpired(at date: Date = Date()) -> Bool {
        expiresAtDate <= date
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
