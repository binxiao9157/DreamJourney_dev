import Foundation
import Alamofire

struct BackendRuntimeConfig {
    let realtimeTokenAvailable: Bool
    let voiceRuntimeConfigEndpoint: String?
    let fallbackMode: String?

    init(json: [String: Any]) {
        let capabilities = json["capabilities"] as? [String: Any]
        let voice = json["voice"] as? [String: Any]
        let fallback = voice?["fallback"] as? [String: Any]
        realtimeTokenAvailable = capabilities?["realtimeToken"] as? Bool ?? false
        voiceRuntimeConfigEndpoint = voice?["runtimeConfigEndpoint"] as? String
        fallbackMode = fallback?["mode"] as? String
    }
}

struct RealtimeVoiceRuntimeConfig {
    let authMode: String
    let address: String
    let uri: String
    let resourceID: String
    let appID: String?
    let appKey: String?
    let appToken: String?
    let uid: String
    let expiresInSeconds: Int
    let expiresAt: Date
    let fallbackMode: String?

    var isExpired: Bool {
        expiresAt <= Date()
    }

    init?(json: [String: Any]) {
        guard let authMode = json["authMode"] as? String,
              let address = json["address"] as? String,
              let uri = json["uri"] as? String,
              let resourceID = json["resourceID"] as? String,
              let uid = json["uid"] as? String,
              let expiresInSeconds = json["expiresInSeconds"] as? Int,
              let expiresAtValue = json["expiresAt"] as? String,
              let expiresAt = ISO8601DateFormatter().date(from: expiresAtValue) else {
            return nil
        }

        self.authMode = authMode
        self.address = address
        self.uri = uri
        self.resourceID = resourceID
        self.appID = json["appID"] as? String
        self.appKey = json["appKey"] as? String
        self.appToken = json["appToken"] as? String
        self.uid = uid
        self.expiresInSeconds = expiresInSeconds
        self.expiresAt = expiresAt
        let fallback = json["fallback"] as? [String: Any]
        self.fallbackMode = fallback?["mode"] as? String
    }
}

final class DreamJourneyBackendClient {
    static let shared = DreamJourneyBackendClient()

    enum ClientError: LocalizedError {
        case invalidJSONResponse
        case unsupportedJSONRoot

        var errorDescription: String? {
            switch self {
            case .invalidJSONResponse:
                return "后端返回的数据不是有效 JSON"
            case .unsupportedJSONRoot:
                return "后端返回的 JSON 根节点不是对象"
            }
        }
    }

    private static let defaultBaseURL = "http://127.0.0.1:3100"
    private static let placeholderBaseURL = "$(DREAMJOURNEY_BACKEND_BASE_URL)"
    private static let placeholderAPIToken = "YOUR_DREAMJOURNEY_BACKEND_API_TOKEN"
    private static let placeholderAPITokenBuildSetting = "$(DREAMJOURNEY_BACKEND_API_TOKEN)"

    private let baseURL: String
    private let apiToken: String?
    private let hasExplicitBaseURL: Bool

    var isProfileSyncConfigured: Bool {
        hasExplicitBaseURL
    }

    var isLoginSyncConfigured: Bool {
        hasExplicitBaseURL
    }

    var isArchiveSyncConfigured: Bool {
        hasExplicitBaseURL
    }

    var isCareSnapshotConfigured: Bool {
        hasExplicitBaseURL
    }

    var isEchoDelayedReplyPushConfigured: Bool {
        hasExplicitBaseURL
    }

    var isPushDeviceTokenRegistrationConfigured: Bool {
        hasExplicitBaseURL
    }

    var isPasswordChangeConfigured: Bool {
        hasExplicitBaseURL
    }

    var isRealtimeVoiceConfigConfigured: Bool {
        hasExplicitBaseURL
    }

    private init() {
        let configured = Bundle.main.object(forInfoDictionaryKey: "DreamJourneyBackendBaseURL") as? String
        let raw = configured?.trimmingCharacters(in: .whitespacesAndNewlines)
        let resolved = raw?.isEmpty == false && raw != Self.placeholderBaseURL ? raw! : Self.defaultBaseURL
        self.baseURL = resolved.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        self.hasExplicitBaseURL = raw?.isEmpty == false && raw != Self.placeholderBaseURL

        let configuredToken = Bundle.main.object(forInfoDictionaryKey: "DreamJourneyBackendAPIToken") as? String
        let token = configuredToken?.trimmingCharacters(in: .whitespacesAndNewlines)
        if let token, !token.isEmpty, token != Self.placeholderAPIToken, token != Self.placeholderAPITokenBuildSetting {
            self.apiToken = token
        } else {
            self.apiToken = nil
        }
    }

    func postArchiveItem(_ payload: [String: Any], completion: @escaping (Result<[String: Any], Error>) -> Void) {
        requestJSON(path: "/archive/items", method: .post, payload: payload, completion: completion)
    }

    func fetchRuntimeConfig(completion: @escaping (Result<BackendRuntimeConfig, Error>) -> Void) {
        requestJSON(path: "/config/runtime", method: .get, payload: nil) { result in
            completion(result.map(BackendRuntimeConfig.init(json:)))
        }
    }

    func fetchRealtimeVoiceConfig(
        userId: String,
        completion: @escaping (Result<RealtimeVoiceRuntimeConfig, Error>) -> Void
    ) {
        requestJSON(path: "/voice/realtime-token", method: .post, payload: ["userId": userId]) { result in
            switch result {
            case .success(let object):
                guard let runtimeConfig = RealtimeVoiceRuntimeConfig(json: object) else {
                    completion(.failure(ClientError.invalidJSONResponse))
                    return
                }
                completion(.success(runtimeConfig))
            case .failure(let error):
                completion(.failure(error))
            }
        }
    }

    func postArchiveItem(
        _ payload: [String: Any],
        personaScope: String,
        digitalHumanId: String,
        completion: @escaping (Result<[String: Any], Error>) -> Void
    ) {
        var scopedPayload = payload
        scopedPayload["personaScope"] = personaScope
        scopedPayload["digitalHumanId"] = digitalHumanId
        postArchiveItem(scopedPayload, completion: completion)
    }

    func upsertUser(
        phone: String,
        nickname: String,
        password: String? = nil,
        completion: @escaping (Result<[String: Any], Error>) -> Void
    ) {
        var payload: [String: Any] = ["phone": phone, "nickname": nickname]
        if let password, !password.isEmpty {
            payload["password"] = password
        }
        requestJSON(path: "/auth/login", method: .post, payload: payload, completion: completion)
    }

    func updateProfile(
        userId: String,
        nickname: String,
        gender: String?,
        region: String?,
        avatarName: String?,
        completion: @escaping (Result<[String: Any], Error>) -> Void
    ) {
        var payload: [String: Any] = ["userId": userId, "nickname": nickname]
        if let gender {
            payload["gender"] = gender
        }
        if let region {
            payload["region"] = region
        }
        if let avatarName {
            payload["avatarName"] = avatarName
        }
        requestJSON(path: "/profile", method: .post, payload: payload, completion: completion)
    }

    func changePassword(
        userId: String,
        oldPassword: String,
        newPassword: String,
        completion: @escaping (Result<[String: Any], Error>) -> Void
    ) {
        requestJSON(
            path: "/auth/password",
            method: .post,
            payload: ["userId": userId, "oldPassword": oldPassword, "newPassword": newPassword],
            completion: completion
        )
    }

    func listArchiveItems(userId: String, completion: @escaping (Result<[String: Any], Error>) -> Void) {
        requestJSON(path: "/archive/items/\(pathComponent(userId))", method: .get, payload: nil, completion: completion)
    }

    func syncKnowledge(userId: String, graph: [String: Any], completion: @escaping (Result<[String: Any], Error>) -> Void) {
        requestJSON(path: "/kb/sync", method: .post, payload: ["userId": userId, "graph": graph], completion: completion)
    }

    func listFamilyMembers(userId: String, completion: @escaping (Result<[String: Any], Error>) -> Void) {
        requestJSON(path: "/family/members/\(pathComponent(userId))", method: .get, payload: nil, completion: completion)
    }

    func latestCareSnapshot(userId: String, completion: @escaping (Result<[String: Any], Error>) -> Void) {
        requestJSON(path: "/care/snapshots/latest/\(pathComponent(userId))", method: .get, payload: nil, completion: completion)
    }

    func registerPushDeviceToken(
        userId: String,
        deviceToken: String,
        environment: String,
        deviceId: String,
        completion: @escaping (Result<[String: Any], Error>) -> Void
    ) {
        let payload: [String: Any] = [
            "userId": userId,
            "deviceToken": deviceToken,
            "platform": "ios",
            "environment": environment,
            "deviceId": deviceId,
        ]
        requestJSON(path: "/devices/push-token", method: .post, payload: payload, completion: completion)
    }

    func scheduleEchoDelayedReplyPush(
        userId: String,
        delayedReply: EchoDelayedReply,
        completion: @escaping (Result<[String: Any], Error>) -> Void
    ) {
        var payload: [String: Any] = [
            "userId": userId,
            "delayedReplyId": delayedReply.id,
            "deliverAt": ISO8601DateFormatter().string(from: delayedReply.deliverAt),
            "minutes": delayedReply.minutes,
            "trigger": delayedReply.trigger.rawValue,
        ]
        if let registration = PushDeviceTokenStore.shared.registration(for: userId) {
            let registeredDeviceTokenPayload: [String: Any] = ["deviceTokenId": registration.deviceTokenId]
            payload.merge(registeredDeviceTokenPayload) { _, new in new }
        }
        requestJSON(path: "/echo/delayed-replies", method: .post, payload: payload, completion: completion)
    }

    private func requestJSON(
        path: String,
        method: HTTPMethod,
        payload: [String: Any]?,
        completion: @escaping (Result<[String: Any], Error>) -> Void
    ) {
        let url = "\(baseURL)\(path)"
        AF.request(url, method: method, parameters: payload, encoding: JSONEncoding.default, headers: authHeaders)
            .validate(statusCode: 200..<300)
            .responseData(queue: .global(qos: .utility)) { response in
                switch response.result {
                case .success(let data):
                    do {
                        let json = try JSONSerialization.jsonObject(with: data)
                        guard let object = json as? [String: Any] else {
                            DispatchQueue.main.async {
                                completion(.failure(ClientError.unsupportedJSONRoot))
                            }
                            return
                        }
                        DispatchQueue.main.async {
                            completion(.success(object))
                        }
                    } catch {
                        DispatchQueue.main.async {
                            completion(.failure(ClientError.invalidJSONResponse))
                        }
                    }
                case .failure(let error):
                    DispatchQueue.main.async {
                        completion(.failure(error))
                    }
                }
            }
    }

    private var authHeaders: HTTPHeaders? {
        guard let apiToken else { return nil }
        return ["Authorization": "Bearer \(apiToken)"]
    }

    private func pathComponent(_ value: String) -> String {
        var allowed = CharacterSet.urlPathAllowed
        allowed.remove(charactersIn: "/?#[]@!$&'()*+,;=")
        return value.addingPercentEncoding(withAllowedCharacters: allowed) ?? value
    }
}
