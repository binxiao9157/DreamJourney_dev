import Foundation

enum NarrativeBackendServiceError: Error {
    case malformedResponse
    case accountScopeChanged
}

protocol NarrativeBackendServicePort {
    func listProjects(accountLease: AccountLease, subjectPersonaId: String, completion: @escaping (Result<[NarrativeProject], Error>) -> Void)
    func createProject(accountLease: AccountLease, subjectPersonaId: String, projectType: BookProjectType, narratorType: NarrativeNarratorType, title: String, completion: @escaping (Result<NarrativeProject, Error>) -> Void)
    func project(accountLease: AccountLease, projectId: String, subjectPersonaId: String, completion: @escaping (Result<NarrativeProject, Error>) -> Void)
    func readiness(accountLease: AccountLease, projectId: String, subjectPersonaId: String, completion: @escaping (Result<NarrativeReadiness, Error>) -> Void)
    func command(accountLease: AccountLease, projectId: String, subjectPersonaId: String, command: NarrativeCommandEnvelope, completion: @escaping (Result<NarrativeCommandResult, Error>) -> Void)
    func job(accountLease: AccountLease, projectId: String, jobId: String, subjectPersonaId: String, completion: @escaping (Result<NarrativeJob, Error>) -> Void)
    func cancelJob(accountLease: AccountLease, projectId: String, jobId: String, subjectPersonaId: String, completion: @escaping (Result<NarrativeJob, Error>) -> Void)
    func artifacts(accountLease: AccountLease, projectId: String, subjectPersonaId: String, artifactType: NarrativeArtifactType?, completion: @escaping (Result<[NarrativeArtifact], Error>) -> Void)
    func readerManifest(accountLease: AccountLease, projectId: String, subjectPersonaId: String, completion: @escaping (Result<NarrativeReaderManifest, Error>) -> Void)
    func readerChapter(accountLease: AccountLease, projectId: String, chapterKey: String, subjectPersonaId: String, completion: @escaping (Result<NarrativeReaderChapter, Error>) -> Void)
    func export(accountLease: AccountLease, projectId: String, subjectPersonaId: String, completion: @escaping (Result<NarrativeExport, Error>) -> Void)
    func deleteProject(accountLease: AccountLease, projectId: String, expectedProjectVersion: Int, subjectPersonaId: String, completion: @escaping (Result<NarrativeDeleteResult, Error>) -> Void)
}

final class NarrativeBackendService: NarrativeBackendServicePort {
    static let shared = NarrativeBackendService()

    private let client: DreamJourneyBackendClient
    private let accountLeaseRuntime: AccountLeaseRuntimePort
    private let decoder = JSONDecoder()

    init(
        client: DreamJourneyBackendClient = .shared,
        accountLeaseRuntime: AccountLeaseRuntimePort = AccountLeaseRuntime.shared
    ) {
        self.client = client
        self.accountLeaseRuntime = accountLeaseRuntime
    }

    func listProjects(accountLease: AccountLease, subjectPersonaId: String, completion: @escaping (Result<[NarrativeProject], Error>) -> Void) {
        request(accountLease: accountLease, path: base(accountLease) + "?subjectPersonaId=\(escaped(subjectPersonaId))", method: "GET") { (result: Result<NarrativeProjectList, Error>) in
            completion(result.flatMap { value in Self.validated { try value.validated().projects } })
        }
    }

    func createProject(accountLease: AccountLease, subjectPersonaId: String, projectType: BookProjectType, narratorType: NarrativeNarratorType, title: String, completion: @escaping (Result<NarrativeProject, Error>) -> Void) {
        request(
            accountLease: accountLease,
            path: base(accountLease),
            method: "POST",
            payload: [
                "subjectPersonaId": subjectPersonaId,
                "projectType": projectType.rawValue,
                "narratorType": narratorType.rawValue,
                "title": title,
            ],
            completion: { (result: Result<NarrativeProject, Error>) in
                completion(result.flatMap { value in Self.validated { try value.validated() } })
            }
        )
    }

    func project(accountLease: AccountLease, projectId: String, subjectPersonaId: String, completion: @escaping (Result<NarrativeProject, Error>) -> Void) {
        request(accountLease: accountLease, path: projectPath(accountLease, projectId) + query(subjectPersonaId), method: "GET") { (result: Result<NarrativeProject, Error>) in
            completion(result.flatMap { value in Self.validated { try value.validated() } })
        }
    }

    func readiness(accountLease: AccountLease, projectId: String, subjectPersonaId: String, completion: @escaping (Result<NarrativeReadiness, Error>) -> Void) {
        request(accountLease: accountLease, path: projectPath(accountLease, projectId) + "/readiness" + query(subjectPersonaId), method: "GET") { (result: Result<NarrativeReadiness, Error>) in
            completion(result.flatMap { value in Self.validated { try value.validated() } })
        }
    }

    func command(accountLease: AccountLease, projectId: String, subjectPersonaId: String, command: NarrativeCommandEnvelope, completion: @escaping (Result<NarrativeCommandResult, Error>) -> Void) {
        guard let payload = encodeObject(command) else {
            completion(.failure(NarrativeBackendServiceError.malformedResponse))
            return
        }
        request(accountLease: accountLease, path: projectPath(accountLease, projectId) + "/commands" + query(subjectPersonaId), method: "POST", payload: payload) { (result: Result<NarrativeCommandResult, Error>) in
            completion(result.flatMap { value in Self.validated { try value.validated() } })
        }
    }

    func job(accountLease: AccountLease, projectId: String, jobId: String, subjectPersonaId: String, completion: @escaping (Result<NarrativeJob, Error>) -> Void) {
        request(accountLease: accountLease, path: projectPath(accountLease, projectId) + "/jobs/\(escaped(jobId))" + query(subjectPersonaId), method: "GET") { (result: Result<NarrativeJob, Error>) in
            completion(result.flatMap { value in Self.validated { try value.validated() } })
        }
    }

    func cancelJob(accountLease: AccountLease, projectId: String, jobId: String, subjectPersonaId: String, completion: @escaping (Result<NarrativeJob, Error>) -> Void) {
        request(accountLease: accountLease, path: projectPath(accountLease, projectId) + "/jobs/\(escaped(jobId))/cancel" + query(subjectPersonaId), method: "POST") { (result: Result<NarrativeJob, Error>) in
            completion(result.flatMap { value in Self.validated { try value.validated() } })
        }
    }

    func artifacts(accountLease: AccountLease, projectId: String, subjectPersonaId: String, artifactType: NarrativeArtifactType?, completion: @escaping (Result<[NarrativeArtifact], Error>) -> Void) {
        let typeQuery = artifactType.map { "&artifactType=\(escaped($0.rawValue))" } ?? ""
        request(accountLease: accountLease, path: projectPath(accountLease, projectId) + "/artifacts" + query(subjectPersonaId) + typeQuery, method: "GET") { (result: Result<NarrativeArtifactList, Error>) in
            completion(result.flatMap { value in Self.validated { try value.validated().artifacts } })
        }
    }

    func readerManifest(accountLease: AccountLease, projectId: String, subjectPersonaId: String, completion: @escaping (Result<NarrativeReaderManifest, Error>) -> Void) {
        request(accountLease: accountLease, path: projectPath(accountLease, projectId) + "/reader/manifest" + query(subjectPersonaId), method: "GET") { (result: Result<NarrativeReaderManifest, Error>) in
            completion(result.flatMap { value in Self.validated { try value.validated() } })
        }
    }

    func readerChapter(accountLease: AccountLease, projectId: String, chapterKey: String, subjectPersonaId: String, completion: @escaping (Result<NarrativeReaderChapter, Error>) -> Void) {
        request(accountLease: accountLease, path: projectPath(accountLease, projectId) + "/reader/chapters/\(escaped(chapterKey))" + query(subjectPersonaId), method: "GET") { (result: Result<NarrativeReaderChapter, Error>) in
            completion(result.flatMap { value in Self.validated { try value.validated() } })
        }
    }

    func export(accountLease: AccountLease, projectId: String, subjectPersonaId: String, completion: @escaping (Result<NarrativeExport, Error>) -> Void) {
        request(accountLease: accountLease, path: projectPath(accountLease, projectId) + "/export" + query(subjectPersonaId) + "&format=json", method: "GET") { (result: Result<NarrativeExport, Error>) in
            completion(result.flatMap { value in Self.validated { try value.validated() } })
        }
    }

    func deleteProject(accountLease: AccountLease, projectId: String, expectedProjectVersion: Int, subjectPersonaId: String, completion: @escaping (Result<NarrativeDeleteResult, Error>) -> Void) {
        let path = projectPath(accountLease, projectId)
            + query(subjectPersonaId)
            + "&expectedProjectVersion=\(expectedProjectVersion)"
        request(accountLease: accountLease, path: path, method: "DELETE") { (result: Result<NarrativeDeleteResult, Error>) in
            completion(result.flatMap { value in Self.validated { try value.validated() } })
        }
    }

    private func request<T: Decodable>(accountLease: AccountLease, path: String, method: String, payload: [String: Any]? = nil, completion: @escaping (Result<T, Error>) -> Void) {
        guard accountLeaseRuntime.validate(accountLease, at: .request).allowed else {
            completion(.failure(NarrativeBackendServiceError.accountScopeChanged))
            return
        }
        client.requestNarrativeJSON(path: path, method: method, payload: payload, accountLease: accountLease) { [weak self] result in
            guard let self else { return }
            guard self.accountLeaseRuntime.validate(accountLease, at: .commit).allowed else {
                completion(.failure(NarrativeBackendServiceError.accountScopeChanged))
                return
            }
            completion(result.flatMap { object in
                guard JSONSerialization.isValidJSONObject(object),
                      let data = try? JSONSerialization.data(withJSONObject: object) else {
                    return .failure(NarrativeBackendServiceError.malformedResponse)
                }
                do { return .success(try self.decoder.decode(T.self, from: data)) }
                catch {
                    if let diagnostic = Self.decodingDiagnostic(error) {
                        print("[Narrative] decode failed type=\(String(describing: T.self)) \(diagnostic)")
                    }
                    return .failure(error)
                }
            })
        }
    }

    private static func decodingDiagnostic(_ error: Error) -> String? {
        let path: ([CodingKey]) -> String = { keys in
            let value = keys.map(\.stringValue).joined(separator: ".")
            return value.isEmpty ? "root" : value
        }
        switch error {
        case DecodingError.keyNotFound(let key, let context):
            return "reason=keyNotFound path=\(path(context.codingPath + [key]))"
        case DecodingError.typeMismatch(_, let context):
            return "reason=typeMismatch path=\(path(context.codingPath))"
        case DecodingError.valueNotFound(_, let context):
            return "reason=valueNotFound path=\(path(context.codingPath))"
        case DecodingError.dataCorrupted(let context):
            return "reason=dataCorrupted path=\(path(context.codingPath))"
        default:
            return nil
        }
    }

    private func base(_ lease: AccountLease) -> String { "/v2/vaults/\(escaped(lease.vaultId))/narrative-projects" }
    private func projectPath(_ lease: AccountLease, _ projectId: String) -> String { base(lease) + "/\(escaped(projectId))" }
    private func query(_ subjectPersonaId: String) -> String { "?subjectPersonaId=\(escaped(subjectPersonaId))" }
    private func escaped(_ value: String) -> String { value.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? value }

    private func encodeObject<T: Encodable>(_ value: T) -> [String: Any]? {
        guard let data = try? JSONEncoder().encode(value),
              let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else { return nil }
        return object
    }

    private static func validated<T>(_ body: () throws -> T) -> Result<T, Error> {
        do { return .success(try body()) }
        catch { return .failure(error) }
    }
}
