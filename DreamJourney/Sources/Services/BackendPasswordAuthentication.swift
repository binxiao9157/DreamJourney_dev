import Foundation

struct BackendPasswordAuthenticationCapability: Equatable {
    let implemented: Bool
    let enabled: Bool
    let ready: Bool
    let loginReady: Bool
    let changeReady: Bool
    let setupReady: Bool
    let resetReady: Bool
    let reauthReady: Bool
    let loginEndpoint: String
    let setupEndpoint: String
    let changeEndpoint: String
    let resetEndpoint: String
    let resetChallengePurpose: String
    let reauthChallengePurpose: String
    let minimumPasswordLength: Int
    let maximumPasswordLength: Int
    let maximumAttempts: Int
    let lockoutSeconds: Int
    let reasonCode: String
    let sessionContractVersion: Int
    let contractVersion: Int
    private let contractFieldsComplete: Bool

    private var baseReady: Bool {
        contractFieldsComplete
            && implemented
            && enabled
            && ready
            && sessionContractVersion == 2
            && contractVersion == 2
    }

    var canLogin: Bool {
        baseReady
            && loginReady
            && loginEndpoint == "/v2/auth/password/login"
    }

    var canSetupPassword: Bool {
        baseReady
            && setupReady
            && reauthReady
            && setupEndpoint == "/v2/auth/password/setup"
            && reauthChallengePurpose == BackendPasswordAction.sensitiveOperation.rawValue
    }

    var canChangePassword: Bool {
        baseReady
            && changeReady
            && changeEndpoint == "/v2/auth/password/change"
    }

    var canResetPassword: Bool {
        baseReady
            && resetReady
            && reauthReady
            && resetEndpoint == "/v2/auth/password/reset"
            && resetChallengePurpose == BackendPasswordAction.passwordReset.rawValue
    }

    var canManagePassword: Bool {
        canSetupPassword || canChangePassword
    }

    init(json: [String: Any]?) {
        let parsedImplemented = Self.bool(json?["implemented"])
        let parsedEnabled = Self.bool(json?["enabled"])
        let parsedReady = Self.bool(json?["ready"])
        let parsedLoginReady = Self.bool(json?["loginReady"])
        let parsedChangeReady = Self.bool(json?["changeReady"])
        let parsedSetupReady = Self.bool(json?["setupReady"])
        let parsedResetReady = Self.bool(json?["resetReady"])
        let parsedReauthReady = Self.bool(json?["reauthReady"])
        let parsedLoginEndpoint = Self.string(json?["loginEndpoint"])
        let parsedSetupEndpoint = Self.string(json?["setupEndpoint"])
        let parsedChangeEndpoint = Self.string(json?["changeEndpoint"])
        let parsedResetEndpoint = Self.string(json?["resetEndpoint"])
        let parsedResetPurpose = Self.string(json?["resetChallengePurpose"])
        let parsedReauthPurpose = Self.string(json?["reauthChallengePurpose"])
        let parsedMinimumLength = Self.int(json?["minLength"])
        let parsedMaximumLength = Self.int(json?["maxLength"])
        let parsedMaximumAttempts = Self.int(json?["maxAttempts"])
        let parsedLockoutSeconds = Self.int(json?["lockoutSeconds"])
        let parsedSessionContractVersion = Self.int(json?["sessionContractVersion"])
        let parsedContractVersion = Self.int(json?["contractVersion"])

        implemented = parsedImplemented ?? false
        enabled = parsedEnabled ?? false
        ready = parsedReady ?? false
        loginReady = parsedLoginReady ?? false
        changeReady = parsedChangeReady ?? false
        setupReady = parsedSetupReady ?? false
        resetReady = parsedResetReady ?? false
        reauthReady = parsedReauthReady ?? false
        loginEndpoint = parsedLoginEndpoint ?? ""
        setupEndpoint = parsedSetupEndpoint ?? ""
        changeEndpoint = parsedChangeEndpoint ?? ""
        resetEndpoint = parsedResetEndpoint ?? ""
        resetChallengePurpose = parsedResetPurpose ?? ""
        reauthChallengePurpose = parsedReauthPurpose ?? ""
        minimumPasswordLength = max(8, parsedMinimumLength ?? 8)
        maximumPasswordLength = max(minimumPasswordLength, parsedMaximumLength ?? 128)
        maximumAttempts = max(1, parsedMaximumAttempts ?? 1)
        lockoutSeconds = max(1, parsedLockoutSeconds ?? 1)
        reasonCode = Self.string(json?["reason"]) ?? "password_authentication_unavailable"
        sessionContractVersion = parsedSessionContractVersion ?? 0
        contractVersion = parsedContractVersion ?? 0
        contractFieldsComplete = parsedImplemented != nil
            && parsedEnabled != nil
            && parsedReady != nil
            && parsedLoginReady != nil
            && parsedChangeReady != nil
            && parsedSetupReady != nil
            && parsedResetReady != nil
            && parsedReauthReady != nil
            && parsedLoginEndpoint != nil
            && parsedSetupEndpoint != nil
            && parsedChangeEndpoint != nil
            && parsedResetEndpoint != nil
            && parsedResetPurpose != nil
            && parsedReauthPurpose != nil
            && parsedMinimumLength != nil
            && parsedMaximumLength != nil
            && parsedMaximumAttempts != nil
            && parsedLockoutSeconds != nil
            && parsedSessionContractVersion != nil
            && parsedContractVersion != nil
    }

    private static func string(_ value: Any?) -> String? {
        guard let value = value as? String else { return nil }
        let normalized = value.trimmingCharacters(in: .whitespacesAndNewlines)
        return normalized.isEmpty ? nil : normalized
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

enum BackendPasswordAction: String, Equatable {
    case passwordReset
    case sensitiveOperation
}

struct BackendPasswordActionTokenContract: Equatable {
    let actionToken: String
    let action: BackendPasswordAction
    let expiresAt: String
    let expiresAtDate: Date
    let contractVersion: Int

    var isExpired: Bool {
        expiresAtDate <= Date()
    }

    init?(
        json: [String: Any],
        expectedAction: BackendPasswordAction,
        now: Date = Date()
    ) {
        if let status = Self.string(json["status"]),
           !["verified", "authorized"].contains(status) {
            return nil
        }
        guard let actionToken = Self.string(json["actionToken"]),
              let actionRaw = Self.string(json["action"]),
              let action = BackendPasswordAction(rawValue: actionRaw),
              action == expectedAction,
              let expiresAt = Self.string(json["expiresAt"]),
              let expiresAtDate = Self.iso8601Date(expiresAt),
              expiresAtDate > now,
              Self.int(json["contractVersion"]) == 2 else {
            return nil
        }
        self.actionToken = actionToken
        self.action = action
        self.expiresAt = expiresAt
        self.expiresAtDate = expiresAtDate
        contractVersion = 2
    }

    private static func string(_ value: Any?) -> String? {
        guard let value = value as? String else { return nil }
        let normalized = value.trimmingCharacters(in: .whitespacesAndNewlines)
        return normalized.isEmpty ? nil : normalized
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
        return fractional.date(from: value) ?? ISO8601DateFormatter().date(from: value)
    }
}

struct BackendPasswordLoginContract: Equatable {
    let userId: String
    let nickname: String

    init?(json: [String: Any]) {
        guard Self.string(json["status"]) == "authenticated",
              Self.int(json["contractVersion"]) == 2,
              let user = json["user"] as? [String: Any],
              let userId = Self.string(user["id"]),
              let auth = json["auth"] as? [String: Any],
              Self.string(auth["userId"]) == userId,
              let password = json["password"] as? [String: Any],
              Self.bool(password["configured"]) == true,
              let passwordRevision = Self.int(password["passwordRevision"]),
              passwordRevision > 0,
              Self.int(password["contractVersion"]) == 2 else {
            return nil
        }
        self.userId = userId
        nickname = Self.string(user["nickname"]) ?? ""
    }

    private static func string(_ value: Any?) -> String? {
        guard let value = value as? String else { return nil }
        let normalized = value.trimmingCharacters(in: .whitespacesAndNewlines)
        return normalized.isEmpty ? nil : normalized
    }

    private static func int(_ value: Any?) -> Int? {
        if let value = value as? Int { return value }
        if let value = value as? NSNumber { return value.intValue }
        if let value = value as? String { return Int(value) }
        return nil
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
}

enum BackendPasswordMutationAction: String, Equatable {
    case setup
    case change
    case reset
}

struct BackendPasswordMutationContract: Equatable {
    let action: BackendPasswordMutationAction
    let status: String
    let passwordRevision: Int?
    let revokedFamilyCount: Int
    let revokedSessionCount: Int
    let loginRequired: Bool
    let contractVersion: Int

    init?(json: [String: Any], expectedAction: BackendPasswordMutationAction) {
        guard let status = Self.string(json["status"]),
              Self.int(json["contractVersion"]) == 2 else {
            return nil
        }

        let password = json["password"] as? [String: Any]
        let auth = json["auth"] as? [String: Any]
        let revocation = json["sessionRevocation"] as? [String: Any]
        let revision = Self.int(password?["passwordRevision"])
        let requiresReplacementSession = expectedAction != .reset

        switch expectedAction {
        case .setup:
            guard status == "configured",
                  Self.bool(password?["configured"]) == true,
                  let revision,
                  revision > 0,
                  auth != nil else {
                return nil
            }
        case .change:
            guard status == "changed",
                  Self.bool(password?["configured"]) == true,
                  let revision,
                  revision > 0,
                  auth != nil else {
                return nil
            }
        case .reset:
            guard status == "resetAccepted",
                  Self.bool(json["loginRequired"]) == true,
                  password == nil,
                  auth == nil else {
                return nil
            }
        }

        action = expectedAction
        self.status = status
        passwordRevision = revision
        revokedFamilyCount = max(0, Self.int(revocation?["revokedFamilyCount"]) ?? 0)
        revokedSessionCount = max(0, Self.int(revocation?["revokedSessionCount"]) ?? 0)
        loginRequired = Self.bool(json["loginRequired"]) ?? !requiresReplacementSession
        contractVersion = 2
    }

    private static func string(_ value: Any?) -> String? {
        guard let value = value as? String else { return nil }
        let normalized = value.trimmingCharacters(in: .whitespacesAndNewlines)
        return normalized.isEmpty ? nil : normalized
    }

    private static func int(_ value: Any?) -> Int? {
        if let value = value as? Int { return value }
        if let value = value as? NSNumber { return value.intValue }
        if let value = value as? String { return Int(value) }
        return nil
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
}

enum BackendPasswordFailureState: Equatable {
    case locked(message: String, retryAfterSeconds: Int?)
    case reauthenticationRequired(message: String)
    case invalidCredentials(message: String)
    case unavailable(message: String)
    case failed(message: String)

    static func resolve(code: String?, retryAfterSeconds: Int?, message: String) -> Self {
        let normalized = (code ?? "").lowercased()
        if normalized.contains("lock") {
            return .locked(message: "尝试次数过多，密码操作已临时锁定。", retryAfterSeconds: retryAfterSeconds)
        }
        if normalized.contains("reauth")
            || normalized.contains("action_token")
            || normalized.contains("reset_token") {
            return .reauthenticationRequired(message: "本次身份验证已失效，请重新获取验证码。")
        }
        if normalized.contains("invalid_credentials")
            || normalized.contains("password_invalid")
            || normalized.contains("authentication_failed")
            || normalized.contains("credential_invalid") {
            return .invalidCredentials(message: "手机号或密码不正确。")
        }
        if normalized.contains("unavailable") || normalized.contains("disabled") {
            return .unavailable(message: "密码服务暂不可用，请稍后重试。")
        }
        if normalized.contains("already_configured") {
            return .failed(message: "该账号已设置密码，请选择修改密码。")
        }
        if normalized.contains("not_configured") {
            return .failed(message: "该账号尚未设置密码，请先完成手机号验证。")
        }
        return .failed(message: message)
    }
}
