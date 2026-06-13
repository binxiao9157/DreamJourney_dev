import Foundation

// MARK: - DreamJourneyBackend Client

final class DreamJourneyBackendClient {
    static let shared = DreamJourneyBackendClient()

    private static let configKey = "DreamJourneyBackendBaseURL"
    private let session: URLSession
    private let timeoutInterval: TimeInterval

    init(session: URLSession = .shared, timeoutInterval: TimeInterval = 12) {
        self.session = session
        self.timeoutInterval = timeoutInterval
    }

    var baseURLString: String? {
        AppConfiguration.string(forKey: Self.configKey)?.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
    }

    var isConfigured: Bool {
        baseURLString.flatMap(URL.init(string:)) != nil
    }

    func syncKnowledgeBase(
        userId: String,
        graphJSON: String,
        completion: @escaping (Result<KBSyncResponse, Swift.Error>) -> Void
    ) {
        guard let graphObject = Self.jsonObject(from: graphJSON) else {
            completion(.failure(Error.invalidGraphJSON))
            return
        }
        let payload: [String: Any] = [
            "userId": userId,
            "graph": graphObject
        ]
        performJSONRequest(
            path: "kb/sync",
            method: "POST",
            bodyObject: payload,
            responseType: KBSyncResponse.self,
            completion: completion
        )
    }

    func fetchRuntimeConfig(completion: @escaping (Result<RuntimeConfig, Swift.Error>) -> Void) {
        performJSONRequest(
            path: "config/runtime",
            method: "GET",
            bodyObject: nil,
            responseType: RuntimeConfig.self,
            completion: completion
        )
    }

    func syncCareSnapshot(
        userId: String,
        viewerFamilyMemberID: String?,
        snapshot: CareSignalSnapshot,
        completion: @escaping (Result<CareSnapshotResponse, Swift.Error>) -> Void
    ) {
        guard let snapshotObject = Self.jsonObject(fromEncodable: snapshot) else {
            completion(.failure(Error.invalidCareSnapshot))
            return
        }
        var payload: [String: Any] = [
            "userId": userId,
            "snapshot": snapshotObject
        ]
        if let viewerFamilyMemberID, !viewerFamilyMemberID.isEmpty {
            payload["viewerFamilyMemberID"] = viewerFamilyMemberID
        }
        performJSONRequest(
            path: "care/snapshots",
            method: "POST",
            bodyObject: payload,
            responseType: CareSnapshotResponse.self,
            completion: completion
        )
    }

    func fetchLatestCareSnapshot(
        userId: String,
        viewerFamilyMemberID: String?,
        completion: @escaping (Result<CareSnapshotLatestResponse, Swift.Error>) -> Void
    ) {
        do {
            let path = "care/snapshots/latest/\(userId.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? userId)"
            guard var components = URLComponents(url: try endpointURL(path: path), resolvingAgainstBaseURL: false) else {
                throw Error.invalidURL
            }
            if let viewerFamilyMemberID, !viewerFamilyMemberID.isEmpty {
                components.queryItems = [URLQueryItem(name: "viewerFamilyMemberID", value: viewerFamilyMemberID)]
            }
            guard let url = components.url else { throw Error.invalidURL }
            var request = URLRequest(url: url)
            request.httpMethod = "GET"
            request.timeoutInterval = timeoutInterval
            request.setValue("application/json", forHTTPHeaderField: "Accept")
            session.dataTask(with: request) { data, response, error in
                if let error {
                    completion(.failure(error))
                    return
                }
                do {
                    try Self.validate(response: response)
                    let decoder = Self.jsonDecoder()
                    let decoded = try decoder.decode(CareSnapshotLatestResponse.self, from: data ?? Data())
                    completion(.success(decoded))
                } catch {
                    completion(.failure(error))
                }
            }.resume()
        } catch {
            completion(.failure(error))
        }
    }

    func inviteFamilyMember(
        userId: String,
        name: String,
        relation: String,
        phone: String,
        completion: @escaping (Result<FamilyInviteResponse, Swift.Error>) -> Void
    ) {
        let payload: [String: Any] = [
            "userId": userId,
            "name": name,
            "relation": relation,
            "phone": phone,
            "isOnline": false,
            "lastUpdated": "邀请已发送"
        ]
        performJSONRequest(
            path: "family/invite",
            method: "POST",
            bodyObject: payload,
            responseType: FamilyInviteResponse.self,
            completion: completion
        )
    }

    func fetchFamilyMembers(
        userId: String,
        completion: @escaping (Result<FamilyMembersResponse, Swift.Error>) -> Void
    ) {
        let escapedUserID = userId.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? userId
        performJSONRequest(
            path: "family/members/\(escapedUserID)",
            method: "GET",
            bodyObject: nil,
            responseType: FamilyMembersResponse.self,
            completion: completion
        )
    }

    func revokeFamilyMember(
        userId: String,
        memberId: String,
        completion: @escaping (Result<FamilyRevokeResponse, Swift.Error>) -> Void
    ) {
        let escapedUserID = userId.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? userId
        let escapedMemberID = memberId.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? memberId
        performJSONRequest(
            path: "family/members/\(escapedUserID)/\(escapedMemberID)/revoke",
            method: "POST",
            bodyObject: nil,
            responseType: FamilyRevokeResponse.self,
            completion: completion
        )
    }

    func acceptFamilyMember(
        userId: String,
        memberId: String,
        phone: String,
        completion: @escaping (Result<FamilyAcceptResponse, Swift.Error>) -> Void
    ) {
        let escapedUserID = userId.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? userId
        let escapedMemberID = memberId.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? memberId
        performJSONRequest(
            path: "family/members/\(escapedUserID)/\(escapedMemberID)/accept",
            method: "POST",
            bodyObject: ["phone": phone],
            responseType: FamilyAcceptResponse.self,
            completion: completion
        )
    }

    func fetchDistrictPayload(keyword: String) async throws -> Data {
        guard var components = URLComponents(url: try endpointURL(path: "maps/district"), resolvingAgainstBaseURL: false) else {
            throw Error.invalidURL
        }
        components.queryItems = [
            URLQueryItem(name: "keyword", value: keyword)
        ]
        guard let url = components.url else { throw Error.invalidURL }
        var request = URLRequest(url: url)
        request.timeoutInterval = timeoutInterval
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        let (data, response) = try await session.data(for: request)
        try Self.validate(response: response)
        return data
    }

    private func performJSONRequest<T: Decodable>(
        path: String,
        method: String,
        bodyObject: Any?,
        responseType: T.Type,
        completion: @escaping (Result<T, Swift.Error>) -> Void
    ) {
        do {
            var request = URLRequest(url: try endpointURL(path: path))
            request.httpMethod = method
            request.timeoutInterval = timeoutInterval
            request.setValue("application/json", forHTTPHeaderField: "Accept")
            if let bodyObject {
                request.httpBody = try JSONSerialization.data(withJSONObject: bodyObject)
                request.setValue("application/json; charset=utf-8", forHTTPHeaderField: "Content-Type")
            }

            session.dataTask(with: request) { data, response, error in
                if let error {
                    completion(.failure(error))
                    return
                }
                do {
                    try Self.validate(response: response)
                    let decoded = try Self.jsonDecoder().decode(T.self, from: data ?? Data())
                    completion(.success(decoded))
                } catch {
                    completion(.failure(error))
                }
            }.resume()
        } catch {
            completion(.failure(error))
        }
    }

    private func endpointURL(path: String) throws -> URL {
        guard let baseURLString else { throw Error.missingBaseURL }
        let normalizedBase = baseURLString.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        let normalizedPath = path.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        guard let url = URL(string: "\(normalizedBase)/\(normalizedPath)") else {
            throw Error.invalidURL
        }
        return url
    }

    private static func jsonObject(from json: String) -> Any? {
        guard let data = json.data(using: .utf8) else { return nil }
        return try? JSONSerialization.jsonObject(with: data)
    }

    private static func jsonObject<T: Encodable>(fromEncodable value: T) -> Any? {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        guard let data = try? encoder.encode(value) else { return nil }
        return try? JSONSerialization.jsonObject(with: data)
    }

    private static func jsonDecoder() -> JSONDecoder {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }

    private static func validate(response: URLResponse?) throws {
        guard let httpResponse = response as? HTTPURLResponse else {
            throw Error.nonHTTPResponse
        }
        guard (200..<300).contains(httpResponse.statusCode) else {
            throw Error.statusCode(httpResponse.statusCode)
        }
    }
}

extension DreamJourneyBackendClient {
    enum Error: LocalizedError {
        case missingBaseURL
        case invalidURL
        case invalidGraphJSON
        case invalidCareSnapshot
        case nonHTTPResponse
        case statusCode(Int)

        var errorDescription: String? {
            switch self {
            case .missingBaseURL:
                return "未配置 DreamJourneyBackendBaseURL"
            case .invalidURL:
                return "DreamJourney 后端地址无效"
            case .invalidGraphJSON:
                return "KBLite 图谱 JSON 无效"
            case .invalidCareSnapshot:
                return "关怀看板快照 JSON 无效"
            case .nonHTTPResponse:
                return "后端返回非 HTTP 响应"
            case .statusCode(let code):
                return "后端返回 HTTP \(code)"
            }
        }
    }

    struct KBSyncResponse: Decodable {
        let status: String
        let userId: String
        let updatedAt: String
        let counts: Counts

        struct Counts: Decodable {
            let people: Int
            let places: Int
            let events: Int
            let facts: Int
        }
    }

    struct RuntimeConfig: Decodable {
        let environment: String
        let baseURL: String?
        let capabilities: [String: Bool]
    }

    struct CareSnapshotResponse: Decodable {
        let status: String
        let item: CareSnapshotItem
    }

    struct CareSnapshotLatestResponse: Decodable {
        let userId: String
        let item: CareSnapshotItem
    }

    struct CareSnapshotItem: Decodable {
        let id: String
        let userId: String
        let viewerFamilyMemberID: String?
        let snapshot: CareSignalSnapshot
        let createdAt: String
    }

    struct FamilyInviteResponse: Decodable {
        let status: String
        let member: FamilyMemberPayload
    }

    struct FamilyMembersResponse: Decodable {
        let userId: String
        let members: [FamilyMemberPayload]
    }

    struct FamilyRevokeResponse: Decodable {
        let status: String
        let member: FamilyMemberPayload
    }

    struct FamilyAcceptResponse: Decodable {
        let status: String
        let member: FamilyMemberPayload
    }

    struct FamilyMemberPayload: Decodable {
        let id: String
        let name: String?
        let displayName: String?
        let relation: String?
        let phone: String?
        let accessStatus: String?
        let invitationStatus: String?
        let isOnline: Bool?
        let lastUpdated: String?
        let createdAt: String?
        let revokedAt: String?

        var isRevoked: Bool {
            accessStatus == "revoked" || invitationStatus == "revoked" || revokedAt != nil
        }

        func toFamilyMember() -> FamilyMember? {
            let resolvedName = (name ?? displayName ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
            guard !resolvedName.isEmpty else { return nil }
            let resolvedRelation = (relation ?? "亲友").trimmingCharacters(in: .whitespacesAndNewlines)
            return FamilyMember(
                id: id,
                name: resolvedName,
                relation: resolvedRelation.isEmpty ? "亲友" : resolvedRelation,
                phone: phone,
                isOnline: isOnline ?? false,
                lastUpdated: lastUpdated ?? "服务器同步"
            )
        }
    }
}
