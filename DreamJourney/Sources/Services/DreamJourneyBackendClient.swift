import Foundation
import Alamofire

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
        hasExplicitBaseURL || apiToken != nil
    }

    var isEchoDelayedReplyPushConfigured: Bool {
        hasExplicitBaseURL || apiToken != nil
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

    func upsertUser(phone: String, nickname: String, completion: @escaping (Result<[String: Any], Error>) -> Void) {
        requestJSON(path: "/auth/login", method: .post, payload: ["phone": phone, "nickname": nickname], completion: completion)
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

    func scheduleEchoDelayedReplyPush(
        userId: String,
        delayedReply: EchoDelayedReply,
        completion: @escaping (Result<[String: Any], Error>) -> Void
    ) {
        let payload: [String: Any] = [
            "userId": userId,
            "delayedReplyId": delayedReply.id,
            "deliverAt": ISO8601DateFormatter().string(from: delayedReply.deliverAt),
            "minutes": delayedReply.minutes,
            "trigger": delayedReply.trigger.rawValue,
        ]
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
