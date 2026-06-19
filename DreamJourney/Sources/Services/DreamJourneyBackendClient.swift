import Foundation
import Alamofire

struct ArchiveImageAnalysisRuntimeCapability {
    let enabled: Bool
    let endpoint: String
    let provider: String
    let supportsVision: Bool
    let fallbackMode: String
    let statuses: [String]

    var canRunVisionAnalysis: Bool {
        enabled && supportsVision
    }

    var availabilityDisplayText: String {
        if canRunVisionAnalysis {
            return "AI 图像分析可用"
        }
        if enabled && fallbackMode == "retryableFailure" {
            return "AI 分析暂不可用，可稍后重试"
        }
        return "AI 分析暂不可用"
    }

    init(json: [String: Any]?) {
        enabled = json?["enabled"] as? Bool ?? false
        endpoint = json?["endpoint"] as? String ?? "/archive/image-analysis"
        provider = json?["provider"] as? String ?? "unknown"
        supportsVision = json?["supportsVision"] as? Bool ?? false
        fallbackMode = json?["fallbackMode"] as? String ?? "retryableFailure"
        statuses = json?["statuses"] as? [String] ?? []
    }
}

struct ArchiveMediaRuntimeCapability {
    let uploadIntentAvailable: Bool
    let uploadIntentEndpoint: String
    let storageProvider: String
    let providerDisplayName: String
    let providerMode: String
    let requiresClientUpload: Bool
    let uploadURLScheme: String
    let realProviderReady: Bool
    let providerSwitchContractVersion: Int
    let clientUploadAction: String
    let supportedMediaKinds: [String]
    let audioFileSizeLimitMB: Int
    let videoFileSizeLimitMB: Int
    let uploadIntentTTLSeconds: Int

    var availabilityDisplayText: String {
        uploadIntentAvailable ? "后端媒体同步可用" : "后端媒体同步未配置"
    }

    var providerDisplayText: String {
        "\(providerDisplayName) · \(storageProvider) · \(uploadIntentEndpoint)"
    }

    var providerModeDisplayText: String {
        if providerMode == "mock" || clientUploadAction == "metadataOnly" {
            return "Mock 模式，仅同步媒体元数据"
        }
        if realProviderReady {
            return "真实对象存储已接入"
        }
        return "真实对象存储待接入"
    }

    var uploadExecutionDisplayText: String {
        requiresClientUpload ? "需要客户端执行文件 PUT" : "暂不执行真实文件 PUT"
    }

    func supports(kind: MemoryArchiveItemKind) -> Bool {
        supportedMediaKinds.contains(kind.rawValue)
    }

    func fileSizeLimitDisplayText(for kind: MemoryArchiveItemKind) -> String {
        switch kind {
        case .audio:
            return "音频上限 \(audioFileSizeLimitMB)MB"
        case .video:
            return "视频上限 \(videoFileSizeLimitMB)MB"
        default:
            return "该类型暂不支持媒体上传"
        }
    }

    static func localFallback(isBackendConfigured: Bool) -> ArchiveMediaRuntimeCapability {
        ArchiveMediaRuntimeCapability(
            uploadIntentAvailable: isBackendConfigured,
            uploadIntentEndpoint: MemoryArchiveMediaReleaseReadiness.mediaUploadIntentEndpoint,
            storageProvider: "mockObjectStorage",
            providerDisplayName: "Mock Object Storage",
            providerMode: "mock",
            requiresClientUpload: false,
            uploadURLScheme: "mock",
            realProviderReady: false,
            providerSwitchContractVersion: 1,
            clientUploadAction: "metadataOnly",
            supportedMediaKinds: [
                MemoryArchiveItemKind.audio.rawValue,
                MemoryArchiveItemKind.video.rawValue,
            ],
            audioFileSizeLimitMB: MemoryArchiveMediaReleaseReadiness.audioFileSizeLimitMB,
            videoFileSizeLimitMB: MemoryArchiveMediaReleaseReadiness.videoFileSizeLimitMB,
            uploadIntentTTLSeconds: MemoryArchiveMediaReleaseReadiness.uploadIntentTTLSeconds
        )
    }

    init(
        uploadIntentAvailable: Bool,
        uploadIntentEndpoint: String,
        storageProvider: String,
        providerDisplayName: String,
        providerMode: String,
        requiresClientUpload: Bool,
        uploadURLScheme: String,
        realProviderReady: Bool,
        providerSwitchContractVersion: Int,
        clientUploadAction: String,
        supportedMediaKinds: [String],
        audioFileSizeLimitMB: Int,
        videoFileSizeLimitMB: Int,
        uploadIntentTTLSeconds: Int
    ) {
        self.uploadIntentAvailable = uploadIntentAvailable
        self.uploadIntentEndpoint = uploadIntentEndpoint
        self.storageProvider = storageProvider
        self.providerDisplayName = providerDisplayName
        self.providerMode = providerMode
        self.requiresClientUpload = requiresClientUpload
        self.uploadURLScheme = uploadURLScheme
        self.realProviderReady = realProviderReady
        self.providerSwitchContractVersion = providerSwitchContractVersion
        self.clientUploadAction = clientUploadAction
        self.supportedMediaKinds = supportedMediaKinds
        self.audioFileSizeLimitMB = audioFileSizeLimitMB
        self.videoFileSizeLimitMB = videoFileSizeLimitMB
        self.uploadIntentTTLSeconds = uploadIntentTTLSeconds
    }

    init(json: [String: Any]?, capabilities: [String: Any]?) {
        uploadIntentAvailable = capabilities?["archiveMediaUploadIntent"] as? Bool ?? false
        uploadIntentEndpoint = json?["uploadIntentEndpoint"] as? String
            ?? MemoryArchiveMediaReleaseReadiness.mediaUploadIntentEndpoint
        storageProvider = json?["storageProvider"] as? String ?? "unknown"
        providerDisplayName = json?["providerDisplayName"] as? String ?? storageProvider
        providerMode = json?["providerMode"] as? String ?? "unknown"
        requiresClientUpload = json?["requiresClientUpload"] as? Bool ?? true
        uploadURLScheme = json?["uploadURLScheme"] as? String ?? "unknown"
        realProviderReady = json?["realProviderReady"] as? Bool ?? false
        providerSwitchContractVersion = Self.intValue(json?["providerSwitchContractVersion"]) ?? 1
        clientUploadAction = json?["clientUploadAction"] as? String ?? "unknown"
        supportedMediaKinds = json?["supportedMediaKinds"] as? [String] ?? []
        audioFileSizeLimitMB = Self.intValue(json?["audioFileSizeLimitMB"])
            ?? MemoryArchiveMediaReleaseReadiness.audioFileSizeLimitMB
        videoFileSizeLimitMB = Self.intValue(json?["videoFileSizeLimitMB"])
            ?? MemoryArchiveMediaReleaseReadiness.videoFileSizeLimitMB
        uploadIntentTTLSeconds = Self.intValue(json?["uploadIntentTTLSeconds"])
            ?? MemoryArchiveMediaReleaseReadiness.uploadIntentTTLSeconds
    }

    private static func intValue(_ value: Any?) -> Int? {
        if let value = value as? Int {
            return value
        }
        if let value = value as? NSNumber {
            return value.intValue
        }
        if let value = value as? String {
            return Int(value)
        }
        return nil
    }
}

struct BackendRuntimeConfig {
    let realtimeTokenAvailable: Bool
    let voiceRuntimeConfigEndpoint: String?
    let fallbackMode: String?
    let archiveMediaUploadIntentAvailable: Bool
    let archiveMediaUploadIntentEndpoint: String?
    let archiveMedia: ArchiveMediaRuntimeCapability
    let archiveImageAnalysis: ArchiveImageAnalysisRuntimeCapability

    init(json: [String: Any]) {
        let capabilities = json["capabilities"] as? [String: Any]
        let voice = json["voice"] as? [String: Any]
        let fallback = voice?["fallback"] as? [String: Any]
        let archive = json["archive"] as? [String: Any]
        let archiveImageAnalysis = json["archiveImageAnalysis"] as? [String: Any]
        realtimeTokenAvailable = capabilities?["realtimeToken"] as? Bool ?? false
        voiceRuntimeConfigEndpoint = voice?["runtimeConfigEndpoint"] as? String
        fallbackMode = fallback?["mode"] as? String
        archiveMediaUploadIntentAvailable = capabilities?["archiveMediaUploadIntent"] as? Bool ?? false
        archiveMediaUploadIntentEndpoint = archive?["uploadIntentEndpoint"] as? String
        self.archiveMedia = ArchiveMediaRuntimeCapability(json: archive, capabilities: capabilities)
        self.archiveImageAnalysis = ArchiveImageAnalysisRuntimeCapability(json: archiveImageAnalysis)
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

struct ArchiveMediaUploadIntent {
    let uploadIntentId: String
    let archiveItemId: String
    let kind: String
    let storageProvider: String
    let providerDisplayName: String
    let providerMode: String
    let requiresClientUpload: Bool
    let uploadURLScheme: String
    let realProviderReady: Bool
    let providerSwitchContractVersion: Int
    let clientUploadAction: String
    let objectKey: String
    let uploadURL: String
    let expiresAt: Date
    let expiresInSeconds: Int
    let maxFileSizeBytes: Int64
    let requiredHeaders: [String: String]
    let personaScope: String
    let digitalHumanId: String

    init?(json: [String: Any]) {
        guard let uploadIntentId = json["uploadIntentId"] as? String,
              let archiveItemId = json["archiveItemId"] as? String,
              let kind = json["kind"] as? String,
              let storageProvider = json["storageProvider"] as? String,
              let providerDisplayName = json["providerDisplayName"] as? String,
              let providerMode = json["providerMode"] as? String,
              let objectKey = json["objectKey"] as? String,
              let uploadURL = json["uploadURL"] as? String,
              let expiresAtValue = json["expiresAt"] as? String,
              let expiresAt = ISO8601DateFormatter().date(from: expiresAtValue),
              let expiresInSeconds = json["expiresInSeconds"] as? Int,
              let personaScope = json["personaScope"] as? String,
              let digitalHumanId = json["digitalHumanId"] as? String else {
            return nil
        }

        self.uploadIntentId = uploadIntentId
        self.archiveItemId = archiveItemId
        self.kind = kind
        self.storageProvider = storageProvider
        self.providerDisplayName = providerDisplayName
        self.providerMode = providerMode
        self.requiresClientUpload = json["requiresClientUpload"] as? Bool ?? true
        self.uploadURLScheme = json["uploadURLScheme"] as? String ?? "unknown"
        self.realProviderReady = json["realProviderReady"] as? Bool ?? false
        self.providerSwitchContractVersion = Self.intValue(json["providerSwitchContractVersion"]) ?? 1
        self.clientUploadAction = json["clientUploadAction"] as? String ?? "unknown"
        self.objectKey = objectKey
        self.uploadURL = uploadURL
        self.expiresAt = expiresAt
        self.expiresInSeconds = expiresInSeconds
        self.maxFileSizeBytes = Self.int64Value(json["maxFileSizeBytes"]) ?? 0
        self.requiredHeaders = json["requiredHeaders"] as? [String: String] ?? [:]
        self.personaScope = personaScope
        self.digitalHumanId = digitalHumanId
    }

    private static func int64Value(_ value: Any?) -> Int64? {
        if let int = value as? Int {
            return Int64(int)
        }
        if let int64 = value as? Int64 {
            return int64
        }
        if let number = value as? NSNumber {
            return number.int64Value
        }
        if let string = value as? String {
            return Int64(string)
        }
        return nil
    }

    private static func intValue(_ value: Any?) -> Int? {
        if let value = value as? Int {
            return value
        }
        if let value = value as? NSNumber {
            return value.intValue
        }
        if let value = value as? String {
            return Int(value)
        }
        return nil
    }
}

struct VoiceCloneProfileContract {
    let voiceProfileId: String
    let sampleStatus: VoiceCloneSampleStatus
    let authorizationConfirmed: Bool
    let authorizationVersion: String
    let authorizationCopy: String
    let providerMode: String
    let realCloneProviderReady: Bool
    let qualityAcceptanceRequired: Bool
    let isEnabled: Bool
    let defaultReleaseVisible: Bool
    let contractVersion: Int
    let disableContract: String
    let deleteContract: String
    let personaScope: String
    let digitalHumanId: String

    init?(json: [String: Any]) {
        guard let voiceProfileId = json["voiceProfileId"] as? String,
              let statusRaw = json["sampleStatus"] as? String,
              let sampleStatus = VoiceCloneSampleStatus(rawValue: statusRaw) else {
            return nil
        }
        self.voiceProfileId = voiceProfileId
        self.sampleStatus = sampleStatus
        self.authorizationConfirmed = json["authorizationConfirmed"] as? Bool ?? false
        self.authorizationVersion = json["authorizationVersion"] as? String ?? "voice-clone-consent-v1"
        self.authorizationCopy = json["authorizationCopy"] as? String ?? ""
        self.providerMode = json["providerMode"] as? String ?? "mockContract"
        self.realCloneProviderReady = json["realCloneProviderReady"] as? Bool ?? false
        self.qualityAcceptanceRequired = json["qualityAcceptanceRequired"] as? Bool ?? true
        self.isEnabled = json["isEnabled"] as? Bool ?? false
        self.defaultReleaseVisible = json["defaultReleaseVisible"] as? Bool ?? false
        self.contractVersion = Self.intValue(json["contractVersion"]) ?? 1
        self.disableContract = json["disableContract"] as? String ?? ""
        self.deleteContract = json["deleteContract"] as? String ?? ""
        self.personaScope = json["personaScope"] as? String ?? "personal"
        self.digitalHumanId = json["digitalHumanId"] as? String ?? ""
    }

    private static func intValue(_ value: Any?) -> Int? {
        if let value = value as? Int {
            return value
        }
        if let value = value as? NSNumber {
            return value.intValue
        }
        if let value = value as? String {
            return Int(value)
        }
        return nil
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

    var isArchiveMediaUploadIntentConfigured: Bool {
        hasExplicitBaseURL
    }

    var isArchiveImageAnalysisConfigured: Bool {
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

    func deleteArchiveItem(
        userId: String,
        itemId: String,
        completion: @escaping (Result<[String: Any], Error>) -> Void
    ) {
        let path = "/archive/items/\(pathComponent(userId))/\(pathComponent(itemId))"
        requestJSON(path: path, method: .delete, payload: nil, completion: completion)
    }

    func fetchRuntimeConfig(completion: @escaping (Result<BackendRuntimeConfig, Error>) -> Void) {
        requestJSON(path: "/config/runtime", method: .get, payload: nil) { result in
            completion(result.map(BackendRuntimeConfig.init(json:)))
        }
    }

    func fetchArchiveImageAnalysisRuntimeCapability(
        completion: @escaping (Result<ArchiveImageAnalysisRuntimeCapability, Error>) -> Void
    ) {
        fetchRuntimeConfig { result in
            completion(result.map(\.archiveImageAnalysis))
        }
    }

    func fetchArchiveMediaRuntimeCapability(
        completion: @escaping (Result<ArchiveMediaRuntimeCapability, Error>) -> Void
    ) {
        fetchRuntimeConfig { result in
            completion(result.map(\.archiveMedia))
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

    func saveVoiceCloneProfile(
        payload: [String: Any],
        completion: @escaping (Result<VoiceCloneProfileContract, Error>) -> Void
    ) {
        requestJSON(path: "/voice/profiles", method: .post, payload: payload) { result in
            switch result {
            case .success(let object):
                guard let profileJSON = object["profile"] as? [String: Any],
                      let profile = VoiceCloneProfileContract(json: profileJSON) else {
                    completion(.failure(ClientError.invalidJSONResponse))
                    return
                }
                completion(.success(profile))
            case .failure(let error):
                completion(.failure(error))
            }
        }
    }

    func fetchVoiceCloneProfiles(
        userId: String,
        completion: @escaping (Result<[VoiceCloneProfileContract], Error>) -> Void
    ) {
        requestJSON(path: "/voice/profiles/\(pathComponent(userId))", method: .get, payload: nil) { result in
            switch result {
            case .success(let object):
                guard let profileJSONArray = object["profiles"] as? [[String: Any]] else {
                    completion(.failure(ClientError.invalidJSONResponse))
                    return
                }
                completion(.success(profileJSONArray.compactMap(VoiceCloneProfileContract.init(json:))))
            case .failure(let error):
                completion(.failure(error))
            }
        }
    }

    func disableVoiceCloneProfile(
        userId: String,
        profileId voiceProfileId: String,
        completion: @escaping (Result<VoiceCloneProfileContract, Error>) -> Void
    ) {
        let path = "/voice/profiles/\(pathComponent(userId))/\(pathComponent(voiceProfileId))/disable"
        requestJSON(path: path, method: .post, payload: nil) { result in
            switch result {
            case .success(let object):
                guard let profileJSON = object["profile"] as? [String: Any],
                      let profile = VoiceCloneProfileContract(json: profileJSON) else {
                    completion(.failure(ClientError.invalidJSONResponse))
                    return
                }
                completion(.success(profile))
            case .failure(let error):
                completion(.failure(error))
            }
        }
    }

    func deleteVoiceCloneProfile(
        userId: String,
        profileId voiceProfileId: String,
        completion: @escaping (Result<VoiceCloneProfileContract, Error>) -> Void
    ) {
        let path = "/voice/profiles/\(pathComponent(userId))/\(pathComponent(voiceProfileId))"
        requestJSON(path: path, method: .delete, payload: nil) { result in
            switch result {
            case .success(let object):
                guard let profileJSON = object["profile"] as? [String: Any],
                      let profile = VoiceCloneProfileContract(json: profileJSON) else {
                    completion(.failure(ClientError.invalidJSONResponse))
                    return
                }
                completion(.success(profile))
            case .failure(let error):
                completion(.failure(error))
            }
        }
    }

    func requestArchiveMediaUploadIntent(
        payload: [String: Any],
        completion: @escaping (Result<ArchiveMediaUploadIntent, Error>) -> Void
    ) {
        requestJSON(path: "/archive/media/upload-intent", method: .post, payload: payload) { result in
            switch result {
            case .success(let object):
                guard let intentJSON = object["uploadIntent"] as? [String: Any],
                      let intent = ArchiveMediaUploadIntent(json: intentJSON) else {
                    completion(.failure(ClientError.invalidJSONResponse))
                    return
                }
                completion(.success(intent))
            case .failure(let error):
                completion(.failure(error))
            }
        }
    }

    func requestArchiveImageAnalysis(
        userId: String,
        archiveItemId: String,
        imageBase64: String,
        completion: @escaping (Result<[String: Any], Error>) -> Void
    ) {
        let payload: [String: Any] = [
            "userId": userId,
            "archiveItemId": archiveItemId,
            "imageBase64": imageBase64,
            "privacyMetadata": ["scope": "generationAllowed"],
        ]
        requestJSON(path: "/archive/image-analysis", method: .post, payload: payload, completion: completion)
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

    func fetchFamilyMembers(
        userId: String,
        completion: @escaping (Result<[FamilyMember], Error>) -> Void
    ) {
        listFamilyMembers(userId: userId) { result in
            switch result {
            case .success(let object):
                guard let members = Self.familyMembers(from: object) else {
                    completion(.failure(ClientError.invalidJSONResponse))
                    return
                }
                completion(.success(members))
            case .failure(let error):
                completion(.failure(error))
            }
        }
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

    private static func familyMembers(from object: [String: Any]) -> [FamilyMember]? {
        let candidates: [[String: Any]]
        if let members = object["members"] as? [[String: Any]] {
            candidates = members
        } else if let items = object["items"] as? [[String: Any]] {
            candidates = items
        } else if let data = object["data"] as? [String: Any] {
            return familyMembers(from: data)
        } else if let item = object["item"] as? [String: Any] {
            candidates = [item]
        } else {
            return nil
        }

        return candidates.compactMap(FamilyMember.fromBackendJSON)
    }
}
