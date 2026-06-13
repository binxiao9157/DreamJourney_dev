import Foundation
import Alamofire

// MARK: - OpenAvatarChat 后端对接服务

/// 封装与 OpenAvatarChat Python 后端的 HTTP 通信
/// 主要功能：推送本地知识库到后端，供 ChatAgent 的 LLM 工具调用
/// 默认后端地址: http://localhost:8283，可通过 Info.plist 的 OpenAvatarChatBaseURL 覆盖
final class OpenAvatarChatService {

    static let shared = OpenAvatarChatService()

    // MARK: - Configuration

    private static let defaultBaseURL = "http://localhost:8283"

    /// 后端 Base URL — 优先从 Scheme env / LocalConfig.plist / Info.plist 读取
    private let baseURL: String

    private let timeoutInterval: TimeInterval = 30

    // MARK: - Init

    private init() {
        if let url = AppConfiguration.string(forKey: "OpenAvatarChatBaseURL") {
            // 去除末尾斜杠
            self.baseURL = url.hasSuffix("/") ? String(url.dropLast()) : url
        } else {
            self.baseURL = Self.defaultBaseURL
        }
    }

    // MARK: - Models

    /// 知识库同步状态
    struct SyncStatus: Decodable {
        let synced: Bool
        let entityCount: Int
        let lastSyncTime: String?

        enum CodingKeys: String, CodingKey {
            case synced
            case entityCount = "entity_count"
            case lastSyncTime = "last_sync_time"
        }
    }

    /// 注入请求体
    private struct InjectRequest: Encodable {
        let graph_json: String
    }

    /// 搜索请求体
    private struct SearchRequest: Encodable {
        let query: String
        let top_k: Int
    }

    /// 搜索响应
    private struct SearchResponse: Decodable {
        let results: [String]
    }

    /// 通用后端响应（inject 等）
    private struct GenericResponse: Decodable {
        let status: String?
        let message: String?
        let entityCount: Int?

        enum CodingKeys: String, CodingKey {
            case status
            case message
            case entityCount = "entity_count"
        }
    }

    // MARK: - Error

    enum ServiceError: LocalizedError {
        case noKnowledgeData
        case networkError(Error)
        case invalidResponse
        case serverError(String)

        var errorDescription: String? {
            switch self {
            case .noKnowledgeData:
                return "知识库数据为空，无法推送"
            case .networkError(let error):
                return "网络请求失败: \(error.localizedDescription)"
            case .invalidResponse:
                return "后端返回了无效的响应格式"
            case .serverError(let msg):
                return "后端错误: \(msg)"
            }
        }
    }

    // MARK: - Public API

    /// 推送知识库到后端
    ///
    /// 调用 `KBLiteManager.shared.exportJSON(surface: .backendSync)` 获取可同步知识库 JSON，
    /// 然后 POST 到后端 `/api/knowledge/inject`
    ///
    /// - Parameter completion: 回调，成功返回 Void，失败返回错误；网络不通时静默失败
    func syncKnowledgeBase(completion: @escaping (Result<Void, Error>) -> Void) {
        guard let graphJSON = KBLiteManager.shared.exportJSON(surface: .backendSync), !graphJSON.isEmpty else {
            print("[OpenAvatarChat] ⚠️ 知识库为空，跳过推送")
            completion(.failure(ServiceError.noKnowledgeData))
            return
        }

        let request = InjectRequest(graph_json: graphJSON)
        let url = "\(baseURL)/api/knowledge/inject"

        let headers: HTTPHeaders = [
            "Content-Type": "application/json",
        ]

        print("[OpenAvatarChat] 📤 推送知识库到后端: \(url)")

        AF.request(
            url,
            method: .post,
            parameters: request,
            encoder: JSONParameterEncoder.default,
            headers: headers
        )
        .validate(statusCode: 200..<300)
        .responseData(queue: .global(qos: .utility)) { response in
            switch response.result {
            case .success(let data):
                if let resp = try? JSONDecoder().decode(GenericResponse.self, from: data) {
                    print("[OpenAvatarChat] ✅ 知识库推送成功: entity_count=\(resp.entityCount ?? 0)")
                }
                DispatchQueue.main.async {
                    completion(.success(()))
                }
            case .failure(let error):
                print("[OpenAvatarChat] ⚠️ 知识库推送失败（静默）: \(error.localizedDescription)")
                DispatchQueue.main.async {
                    completion(.failure(ServiceError.networkError(error)))
                }
            }
        }
    }

    /// 查询后端知识库同步状态
    ///
    /// - Parameter completion: 回调，成功返回 SyncStatus，失败返回错误
    func checkSyncStatus(completion: @escaping (Result<SyncStatus, Error>) -> Void) {
        let url = "\(baseURL)/api/knowledge/status"

        AF.request(url, method: .get)
            .validate(statusCode: 200..<300)
            .responseData(queue: .global(qos: .utility)) { response in
                switch response.result {
                case .success(let data):
                    guard let status = try? JSONDecoder().decode(SyncStatus.self, from: data) else {
                        DispatchQueue.main.async {
                            completion(.failure(ServiceError.invalidResponse))
                        }
                        return
                    }
                    DispatchQueue.main.async {
                        completion(.success(status))
                    }
                case .failure(let error):
                    print("[OpenAvatarChat] ⚠️ 状态查询失败: \(error.localizedDescription)")
                    DispatchQueue.main.async {
                        completion(.failure(ServiceError.networkError(error)))
                    }
                }
            }
    }

    /// 搜索后端知识库（调试用）
    ///
    /// - Parameters:
    ///   - query: 搜索关键词
    ///   - topK: 返回结果数量，默认 5
    ///   - completion: 回调，成功返回匹配文本数组，失败返回错误
    func searchKnowledge(query: String, topK: Int = 5, completion: @escaping (Result<[String], Error>) -> Void) {
        let request = SearchRequest(query: query, top_k: topK)
        let url = "\(baseURL)/api/knowledge/search"

        let headers: HTTPHeaders = [
            "Content-Type": "application/json",
        ]

        AF.request(
            url,
            method: .post,
            parameters: request,
            encoder: JSONParameterEncoder.default,
            headers: headers
        )
        .validate(statusCode: 200..<300)
        .responseData(queue: .global(qos: .utility)) { response in
            switch response.result {
            case .success(let data):
                guard let searchResp = try? JSONDecoder().decode(SearchResponse.self, from: data) else {
                    DispatchQueue.main.async {
                        completion(.failure(ServiceError.invalidResponse))
                    }
                    return
                }
                DispatchQueue.main.async {
                    completion(.success(searchResp.results))
                }
            case .failure(let error):
                print("[OpenAvatarChat] ⚠️ 知识库搜索失败: \(error.localizedDescription)")
                DispatchQueue.main.async {
                    completion(.failure(ServiceError.networkError(error)))
                }
            }
        }
    }
}
