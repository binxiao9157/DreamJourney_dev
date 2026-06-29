import Foundation
import Alamofire

private enum BackendDateParser {
    private static let fractionalISO8601Formatter: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter
    }()

    private static let standardISO8601Formatter = ISO8601DateFormatter()

    static func date(from value: String) -> Date? {
        fractionalISO8601Formatter.date(from: value)
            ?? standardISO8601Formatter.date(from: value)
    }
}

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
    let digitalHuman: DigitalHumanRuntimeCapability

    init(json: [String: Any]) {
        let capabilities = json["capabilities"] as? [String: Any]
        let voice = json["voice"] as? [String: Any]
        let fallback = voice?["fallback"] as? [String: Any]
        let archive = json["archive"] as? [String: Any]
        let archiveImageAnalysis = json["archiveImageAnalysis"] as? [String: Any]
        let digitalHuman = json["digitalHuman"] as? [String: Any]
        realtimeTokenAvailable = capabilities?["realtimeToken"] as? Bool ?? false
        voiceRuntimeConfigEndpoint = voice?["runtimeConfigEndpoint"] as? String
        fallbackMode = fallback?["mode"] as? String
        archiveMediaUploadIntentAvailable = capabilities?["archiveMediaUploadIntent"] as? Bool ?? false
        archiveMediaUploadIntentEndpoint = archive?["uploadIntentEndpoint"] as? String
        self.archiveMedia = ArchiveMediaRuntimeCapability(json: archive, capabilities: capabilities)
        self.archiveImageAnalysis = ArchiveImageAnalysisRuntimeCapability(json: archiveImageAnalysis)
        self.digitalHuman = DigitalHumanRuntimeCapability(json: digitalHuman, capabilities: capabilities)
    }
}

struct DigitalHumanRuntimeCapability {
    let enabled: Bool
    let provider: String
    let providerMode: String
    let realProviderReady: Bool
    let sdkProvider: String
    let sdkAuthMode: String
    let sdkAdapterLinked: Bool
    let sdkReadinessMessage: String
    let requiredServerEnv: [String]
    let requiredAssetEnv: [String]
    let optionalASREnv: [String]
    let providerFieldAliases: [String]
    let sessionEndpoint: String
    let driveModes: [String]
    let fallbackMode: String
    let defaultReleaseVisible: Bool
    let requiresBackendIssuedCredential: Bool
    let contractVersion: Int

    var canCreateMockSession: Bool {
        enabled && provider == "tencent" && providerMode == "mockContract"
    }

    init(json: [String: Any]?, capabilities: [String: Any]?) {
        enabled = capabilities?["digitalHumanSession"] as? Bool ?? json?["enabled"] as? Bool ?? false
        provider = json?["provider"] as? String ?? "unknown"
        providerMode = json?["providerMode"] as? String ?? "unknown"
        realProviderReady = json?["realProviderReady"] as? Bool ?? false
        sdkProvider = json?["sdkProvider"] as? String ?? ""
        sdkAuthMode = json?["sdkAuthMode"] as? String ?? ""
        sdkAdapterLinked = json?["sdkAdapterLinked"] as? Bool ?? false
        sdkReadinessMessage = json?["sdkReadinessMessage"] as? String ?? ""
        requiredServerEnv = json?["requiredServerEnv"] as? [String] ?? []
        requiredAssetEnv = json?["requiredAssetEnv"] as? [String] ?? []
        optionalASREnv = json?["optionalASREnv"] as? [String] ?? []
        providerFieldAliases = json?["providerFieldAliases"] as? [String] ?? []
        sessionEndpoint = json?["sessionEndpoint"] as? String ?? "/digital-human/sessions"
        driveModes = json?["driveModes"] as? [String] ?? []
        fallbackMode = json?["fallbackMode"] as? String ?? "audioOnly"
        defaultReleaseVisible = json?["defaultReleaseVisible"] as? Bool ?? false
        requiresBackendIssuedCredential = json?["requiresBackendIssuedCredential"] as? Bool ?? true
        contractVersion = Self.intValue(json?["contractVersion"]) ?? 1
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

struct DigitalHumanSessionPolicy {
    let allowInterrupt: Bool
    let maxDurationSeconds: Int
    let proactiveSpeechAllowed: Bool

    init(json: [String: Any]?) {
        allowInterrupt = json?["allowInterrupt"] as? Bool ?? false
        maxDurationSeconds = Self.intValue(json?["maxDurationSeconds"]) ?? 0
        proactiveSpeechAllowed = json?["proactiveSpeechAllowed"] as? Bool ?? false
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

struct DigitalHumanSessionCredential {
    let mode: String
    let expiresAt: Date?
    let appKey: String?
    let accessToken: String?

    init(json: [String: Any]?) {
        mode = json?["mode"] as? String ?? "unknown"
        appKey = json?["appkey"] as? String ?? json?["appKey"] as? String
        accessToken = json?["accesstoken"] as? String ?? json?["accessToken"] as? String
        if let expiresAtValue = json?["expiresAt"] as? String {
            expiresAt = BackendDateParser.date(from: expiresAtValue)
        } else {
            expiresAt = nil
        }
    }
}

struct DigitalHumanSessionContract {
    let sessionId: String
    let provider: String
    let providerMode: String
    let personaId: String
    let scene: String
    let deviceId: String
    let lifecycleMode: DigitalHumanMode
    let lifecycleModeLabel: String
    let assetKey: String?
    let providerAssetId: String?
    let providerProjectId: String?
    let driveMode: String
    let alphaEnabled: Bool
    let smartActionEnabled: Bool
    let sessionPolicy: DigitalHumanSessionPolicy
    let credential: DigitalHumanSessionCredential
    let fallbackMode: String
    let fallbackReason: String
    let contractVersion: Int

    init?(json: [String: Any]) {
        guard let sessionId = json["sessionId"] as? String,
              let provider = json["provider"] as? String,
              let providerMode = json["providerMode"] as? String,
              let personaId = json["personaId"] as? String,
              let scene = json["scene"] as? String,
              let lifecycleModeRaw = json["lifecycleMode"] as? String,
              let lifecycleMode = DigitalHumanMode(rawValue: lifecycleModeRaw),
              let driveMode = json["driveMode"] as? String else {
            return nil
        }
        self.sessionId = sessionId
        self.provider = provider
        self.providerMode = providerMode
        self.personaId = personaId
        self.scene = scene
        self.deviceId = json["deviceId"] as? String ?? ""
        self.lifecycleMode = lifecycleMode
        self.lifecycleModeLabel = json["lifecycleModeLabel"] as? String ?? lifecycleMode.displayName
        self.assetKey = json["assetKey"] as? String
        self.providerAssetId = json["providerAssetId"] as? String
        self.providerProjectId = json["providerProjectId"] as? String ?? json["virtualmanProjectId"] as? String
        self.driveMode = driveMode
        self.alphaEnabled = json["alphaEnabled"] as? Bool ?? false
        self.smartActionEnabled = json["smartActionEnabled"] as? Bool ?? false
        self.sessionPolicy = DigitalHumanSessionPolicy(json: json["sessionPolicy"] as? [String: Any])
        self.credential = DigitalHumanSessionCredential(json: json["credential"] as? [String: Any])
        let fallback = json["fallback"] as? [String: Any]
        self.fallbackMode = fallback?["mode"] as? String ?? "audioOnly"
        self.fallbackReason = fallback?["reason"] as? String ?? ""
        self.contractVersion = Self.intValue(json["contractVersion"]) ?? 1
    }

    func toDigitalHumanProfile(displayName: String) -> DigitalHumanProfile {
        DigitalHumanProfile(
            provider: provider,
            personaId: personaId,
            displayName: displayName,
            lifecycleMode: lifecycleMode,
            driveMode: driveMode,
            alphaEnabled: alphaEnabled,
            smartActionEnabled: smartActionEnabled,
            assetKey: assetKey
        )
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
              let expiresAt = BackendDateParser.date(from: expiresAtValue) else {
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
              let expiresAt = BackendDateParser.date(from: expiresAtValue),
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
    let providerStatus: String
    let providerMessage: String
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
        self.providerStatus = json["providerStatus"] as? String ?? ""
        self.providerMessage = json["providerMessage"] as? String ?? ""
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

struct VoiceCloneSynthesisResult {
    let voiceProfileId: String
    let providerMode: String
    let outputMode: String?
    let audioBase64: String
    let audioFormat: String
    let byteCount: Int
    let sampleRate: Int?
    let bitsPerSample: Int?
    let channelCount: Int?
    let visemeTimeline: DigitalHumanLipSyncTimeline?

    init?(json: [String: Any]) {
        guard let voiceProfileId = json["voiceProfileId"] as? String,
              let audioJSON = json["audio"] as? [String: Any],
              let audioBase64 = audioJSON["data"] as? String,
              let audioFormat = audioJSON["format"] as? String else {
            return nil
        }
        self.voiceProfileId = voiceProfileId
        self.providerMode = json["providerMode"] as? String ?? "unknown"
        self.outputMode = json["outputMode"] as? String
        self.audioBase64 = audioBase64
        self.audioFormat = audioFormat
        self.byteCount = Self.intValue(audioJSON["byteCount"]) ?? 0
        self.sampleRate = Self.intValue(audioJSON["sampleRate"])
        self.bitsPerSample = Self.intValue(audioJSON["bitsPerSample"])
        self.channelCount = Self.intValue(audioJSON["channelCount"])
        if let visemeTimelineJSON = json["visemeTimeline"] as? [String: Any] {
            self.visemeTimeline = DigitalHumanLipSyncTimeline(json: visemeTimelineJSON)
        } else {
            self.visemeTimeline = nil
        }
    }

    var audioData: Data? {
        Data(base64Encoded: audioBase64)
    }

    var isTencentAudioDrivePCMCompatible: Bool {
        outputMode == "tencentAudioDrive"
            && audioFormat == "pcm16kMono"
            && sampleRate == 16000
            && bitsPerSample == 16
            && channelCount == 1
            && byteCount > 0
    }

    var tencentAudioDrivePCMData: Data? {
        guard isTencentAudioDrivePCMCompatible else {
            return nil
        }
        return audioData
    }

    var lipSyncPlaybackEvent: DigitalHumanPlaybackEvent? {
        guard let visemeTimeline else {
            return nil
        }
        return .visemeTimeline(visemeTimeline)
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
        case backendError(statusCode: Int?, detail: String)

        var errorDescription: String? {
            switch self {
            case .invalidJSONResponse:
                return "后端返回的数据不是有效 JSON"
            case .unsupportedJSONRoot:
                return "后端返回的 JSON 根节点不是对象"
            case .backendError(let statusCode, let detail):
                if let statusCode {
                    return "后端请求失败（\(statusCode)）：\(detail)"
                }
                return "后端请求失败：\(detail)"
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

    var isAccountDeletionConfigured: Bool {
        hasExplicitBaseURL
    }

    var isRealtimeVoiceConfigConfigured: Bool {
        hasExplicitBaseURL
    }

    var isVoiceCloneProfileConfigured: Bool {
        hasExplicitBaseURL
    }

    var isVoiceCloneSynthesisConfigured: Bool {
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

    func fetchDigitalHumanRuntimeCapability(
        completion: @escaping (Result<DigitalHumanRuntimeCapability, Error>) -> Void
    ) {
        fetchRuntimeConfig { result in
            completion(result.map(\.digitalHuman))
        }
    }

    func createDigitalHumanSession(
        userId: String,
        personaId: String,
        scene: String,
        deviceId: String,
        lifecycleMode: DigitalHumanMode,
        completion: @escaping (Result<DigitalHumanSessionContract, Error>) -> Void
    ) {
        let payload: [String: Any] = [
            "userId": userId,
            "personaId": personaId,
            "scene": scene,
            "deviceId": deviceId,
            "lifecycleMode": lifecycleMode.rawValue,
        ]
        requestJSON(path: "/digital-human/sessions", method: .post, payload: payload) { result in
            switch result {
            case .success(let object):
                guard let contract = DigitalHumanSessionContract(json: object) else {
                    completion(.failure(ClientError.invalidJSONResponse))
                    return
                }
                completion(.success(contract))
            case .failure(let error):
                completion(.failure(error))
            }
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

    func refreshVoiceCloneProfile(
        userId: String,
        profileId voiceProfileId: String,
        completion: @escaping (Result<VoiceCloneProfileContract, Error>) -> Void
    ) {
        let path = "/voice/profiles/\(pathComponent(userId))/\(pathComponent(voiceProfileId))/refresh"
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

    func requestVoiceCloneSynthesis(
        userId: String,
        voiceProfileId: String,
        text: String,
        audioFormat: String = "mp3",
        sampleRate: Int = 24000,
        speechRate: Int = -10,
        loudnessRate: Int = 10,
        outputMode: String? = nil,
        completion: @escaping (Result<VoiceCloneSynthesisResult, Error>) -> Void
    ) {
        var payload: [String: Any] = [
            "userId": userId,
            "voiceProfileId": voiceProfileId,
            "text": text,
            "format": audioFormat,
            "sampleRate": sampleRate,
            "speechRate": speechRate,
            "loudnessRate": loudnessRate,
        ]
        if let outputMode, !outputMode.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            payload["outputMode"] = outputMode
        }
        requestJSON(path: "/voice/synthesis", method: .post, payload: payload) { result in
            switch result {
            case .success(let object):
                guard let synthesis = VoiceCloneSynthesisResult(json: object) else {
                    completion(.failure(ClientError.invalidJSONResponse))
                    return
                }
                completion(.success(synthesis))
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

    func softDeleteAccount(
        userId: String,
        phone: String,
        completion: @escaping (Result<[String: Any], Error>) -> Void
    ) {
        requestJSON(
            path: "/auth/delete",
            method: .post,
            payload: [
                "userId": userId,
                "phone": phone,
                "firstConfirmation": true,
                "secondConfirmation": true,
            ],
            completion: completion
        )
    }

    func restoreAccount(
        phone: String,
        nickname: String? = nil,
        completion: @escaping (Result<[String: Any], Error>) -> Void
    ) {
        var payload: [String: Any] = ["phone": phone]
        if let nickname, !nickname.isEmpty {
            payload["nickname"] = nickname
        }
        requestJSON(path: "/auth/restore", method: .post, payload: payload, completion: completion)
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

    func inviteFamilyMember(
        userId: String,
        name: String,
        relation: String,
        phone: String,
        completion: @escaping (Result<FamilyMember, Error>) -> Void
    ) {
        requestJSON(
            path: "/family/invite",
            method: .post,
            payload: [
                "userId": userId,
                "name": name,
                "relation": relation,
                "phone": phone,
            ]
        ) { result in
            switch result {
            case .success(let object):
                guard let memberJSON = object["member"] as? [String: Any],
                      let member = FamilyMember.fromBackendJSON(memberJSON) else {
                    completion(.failure(ClientError.invalidJSONResponse))
                    return
                }
                completion(.success(member))
            case .failure(let error):
                completion(.failure(error))
            }
        }
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
                    let statusCode = response.response?.statusCode
                    if let backendMessage = Self.backendErrorMessage(from: response.data) {
                        DispatchQueue.main.async {
                            completion(.failure(ClientError.backendError(statusCode: statusCode, detail: backendMessage)))
                        }
                        return
                    }
                    DispatchQueue.main.async {
                        if let statusCode {
                            completion(.failure(ClientError.backendError(statusCode: statusCode, detail: error.localizedDescription)))
                        } else {
                            completion(.failure(error))
                        }
                    }
                }
            }
    }

    private static func backendErrorMessage(from data: Data?) -> String? {
        guard let data, !data.isEmpty else { return nil }

        if let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
            if let detail = object["detail"] as? String, !detail.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                return detail
            }
            if let message = object["message"] as? String, !message.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                return message
            }
            if let error = object["error"] as? String, !error.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                return error
            }
            if let detail = object["detail"] {
                return String(describing: detail)
            }
        }

        guard let text = String(data: data, encoding: .utf8)?
            .trimmingCharacters(in: .whitespacesAndNewlines),
              !text.isEmpty else {
            return nil
        }
        return String(text.prefix(240))
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
