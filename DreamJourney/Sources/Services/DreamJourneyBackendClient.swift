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

struct VoiceCloneTencentAudioDriveCapability {
    let supported: Bool
    let synthesisEndpoint: String
    let requestOutputMode: String
    let audioFormat: String
    let sampleRate: Int
    let bitsPerSample: Int
    let channelCount: Int
    let fallbackMode: String
    let contractVersion: Int

    init(json: [String: Any]?) {
        supported = json?["supported"] as? Bool ?? false
        synthesisEndpoint = json?["synthesisEndpoint"] as? String ?? "/voice/synthesis"
        requestOutputMode = json?["requestOutputMode"] as? String ?? "tencentAudioDrive"
        audioFormat = json?["audioFormat"] as? String ?? "pcm16kMono"
        sampleRate = Self.intValue(json?["sampleRate"]) ?? 16000
        bitsPerSample = Self.intValue(json?["bitsPerSample"]) ?? 16
        channelCount = Self.intValue(json?["channelCount"]) ?? 1
        fallbackMode = json?["fallbackMode"] as? String ?? "providerTextDrive"
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

struct VoiceCloneRuntimeCapability {
    let enabled: Bool
    let provider: String
    let realProviderReady: Bool
    let trainEndpoint: String
    let queryEndpoint: String
    let synthesisEndpoint: String
    let synthesisProviderReady: Bool
    let requiresAuthorization: Bool
    let qualityAcceptanceRequired: Bool
    let defaultReleaseVisible: Bool
    let speakerIdMode: String
    let consoleSpeakerIdConfigured: Bool
    let speakerIdPoolConfigured: Bool
    let speakerIdPoolCount: Int
    let modelType: Int
    let ttsResourceId: String
    let voiceClone2TrialReady: Bool
    let fallbackMode: String
    let tencentAudioDrive: VoiceCloneTencentAudioDriveCapability
    let contractVersion: Int

    var canSynthesize: Bool {
        enabled && synthesisProviderReady
    }

    static func localFallback(isBackendConfigured: Bool) -> VoiceCloneRuntimeCapability {
        VoiceCloneRuntimeCapability(json: [
            "enabled": isBackendConfigured,
            "provider": "localFallback",
            "realProviderReady": isBackendConfigured,
            "synthesisProviderReady": isBackendConfigured,
            "fallbackMode": isBackendConfigured ? "backendConfigured" : "backendNotConfigured",
            "tencentAudioDrive": [
                "supported": false,
                "requestOutputMode": "tencentAudioDrive",
                "audioFormat": "pcm16kMono",
            ],
        ])
    }

    init(json: [String: Any]?) {
        enabled = json?["enabled"] as? Bool ?? false
        provider = json?["provider"] as? String ?? "unknown"
        realProviderReady = json?["realProviderReady"] as? Bool ?? false
        trainEndpoint = json?["trainEndpoint"] as? String ?? "/voice/profiles"
        queryEndpoint = json?["queryEndpoint"] as? String ?? "/voice/profiles/{user_id}/{voice_profile_id}/refresh"
        synthesisEndpoint = json?["synthesisEndpoint"] as? String ?? "/voice/synthesis"
        synthesisProviderReady = json?["synthesisProviderReady"] as? Bool ?? false
        requiresAuthorization = json?["requiresAuthorization"] as? Bool ?? true
        qualityAcceptanceRequired = json?["qualityAcceptanceRequired"] as? Bool ?? true
        defaultReleaseVisible = json?["defaultReleaseVisible"] as? Bool ?? false
        speakerIdMode = json?["speakerIdMode"] as? String ?? "unknown"
        consoleSpeakerIdConfigured = json?["consoleSpeakerIdConfigured"] as? Bool ?? false
        speakerIdPoolConfigured = json?["speakerIdPoolConfigured"] as? Bool ?? false
        speakerIdPoolCount = Self.intValue(json?["speakerIdPoolCount"]) ?? 0
        modelType = Self.intValue(json?["modelType"]) ?? 0
        ttsResourceId = json?["ttsResourceId"] as? String ?? ""
        voiceClone2TrialReady = json?["voiceClone2TrialReady"] as? Bool ?? false
        fallbackMode = json?["fallbackMode"] as? String ?? "hiddenContract"
        tencentAudioDrive = VoiceCloneTencentAudioDriveCapability(json: json?["tencentAudioDrive"] as? [String: Any])
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
    let voiceClone: VoiceCloneRuntimeCapability
    let digitalHuman: DigitalHumanRuntimeCapability

    init(json: [String: Any]) {
        let capabilities = json["capabilities"] as? [String: Any]
        let voice = json["voice"] as? [String: Any]
        let fallback = voice?["fallback"] as? [String: Any]
        let archive = json["archive"] as? [String: Any]
        let archiveImageAnalysis = json["archiveImageAnalysis"] as? [String: Any]
        let voiceClone = json["voiceClone"] as? [String: Any]
        let digitalHuman = json["digitalHuman"] as? [String: Any]
        realtimeTokenAvailable = capabilities?["realtimeToken"] as? Bool ?? false
        voiceRuntimeConfigEndpoint = voice?["runtimeConfigEndpoint"] as? String
        fallbackMode = fallback?["mode"] as? String
        archiveMediaUploadIntentAvailable = capabilities?["archiveMediaUploadIntent"] as? Bool ?? false
        archiveMediaUploadIntentEndpoint = archive?["uploadIntentEndpoint"] as? String
        self.archiveMedia = ArchiveMediaRuntimeCapability(json: archive, capabilities: capabilities)
        self.archiveImageAnalysis = ArchiveImageAnalysisRuntimeCapability(json: archiveImageAnalysis)
        self.voiceClone = VoiceCloneRuntimeCapability(json: voiceClone)
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
    let sessionLease: DigitalHumanSessionLeaseRuntimeCapability
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
        sessionLease = DigitalHumanSessionLeaseRuntimeCapability(
            json: json?["sessionLease"] as? [String: Any],
            capabilityEnabled: capabilities?["digitalHumanSessionLease"] as? Bool ?? false
        )
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

struct DigitalHumanSessionLeaseRuntimeCapability {
    let enabled: Bool
    let heartbeatEndpointTemplate: String
    let releaseEndpointTemplate: String
    let ttlSeconds: Int
    let heartbeatIntervalSeconds: Int
    let maxConcurrentSessions: Int
    let conflictStatusCode: Int
    let contractVersion: Int

    init(json: [String: Any]?, capabilityEnabled: Bool) {
        enabled = capabilityEnabled || (json?["enabled"] as? Bool ?? false)
        heartbeatEndpointTemplate = json?["heartbeatEndpointTemplate"] as? String
            ?? "/digital-human/sessions/{sessionId}/heartbeat"
        releaseEndpointTemplate = json?["releaseEndpointTemplate"] as? String
            ?? "/digital-human/sessions/{sessionId}/release"
        ttlSeconds = Self.intValue(json?["ttlSeconds"]) ?? 0
        heartbeatIntervalSeconds = Self.intValue(json?["heartbeatIntervalSeconds"]) ?? 0
        maxConcurrentSessions = Self.intValue(json?["maxConcurrentSessions"]) ?? 1
        conflictStatusCode = Self.intValue(json?["conflictStatusCode"]) ?? 409
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

struct DigitalHumanSessionLeaseContract {
    let status: String
    let reused: Bool
    let createdAt: Date?
    let heartbeatAt: Date?
    let expiresAt: Date?
    let heartbeatIntervalSeconds: Int
    let heartbeatEndpoint: String
    let releaseEndpoint: String
    let releaseReason: String?
    let releasedAt: Date?
    let contractVersion: Int

    var isActive: Bool {
        status == "active"
    }

    init(json: [String: Any]) {
        status = json["status"] as? String ?? "unknown"
        reused = json["reused"] as? Bool ?? false
        createdAt = Self.dateValue(json["createdAt"])
        heartbeatAt = Self.dateValue(json["heartbeatAt"])
        expiresAt = Self.dateValue(json["expiresAt"])
        heartbeatIntervalSeconds = max(1, Self.intValue(json["heartbeatIntervalSeconds"]) ?? 45)
        heartbeatEndpoint = json["heartbeatEndpoint"] as? String ?? ""
        releaseEndpoint = json["releaseEndpoint"] as? String ?? ""
        releaseReason = json["releaseReason"] as? String
        releasedAt = Self.dateValue(json["releasedAt"])
        contractVersion = Self.intValue(json["contractVersion"]) ?? 1
    }

    private static func dateValue(_ value: Any?) -> Date? {
        guard let value = value as? String else {
            return nil
        }
        return BackendDateParser.date(from: value)
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

struct DigitalHumanSessionLeaseOperationResult {
    let status: String
    let sessionId: String
    let lease: DigitalHumanSessionLeaseContract

    init?(json: [String: Any]) {
        guard let sessionId = json["sessionId"] as? String,
              let leaseJSON = json["lease"] as? [String: Any] else {
            return nil
        }
        status = json["status"] as? String ?? "unknown"
        self.sessionId = sessionId
        lease = DigitalHumanSessionLeaseContract(json: leaseJSON)
    }
}

struct DigitalHumanSessionContract {
    private static let localAssetVirtualmanKeyInfoKey = "DreamJourneyDigitalHumanAssetVirtualmanKey"
    private static let localAssetVirtualmanKeyOverrideArgument = "DJUseLocalDigitalHumanAssetOverride"

    let sessionId: String
    let userId: String
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
    let assetSource: String
    let driveMode: String
    let alphaEnabled: Bool
    let smartActionEnabled: Bool
    let sessionPolicy: DigitalHumanSessionPolicy
    let credential: DigitalHumanSessionCredential
    let fallbackMode: String
    let fallbackReason: String
    let lease: DigitalHumanSessionLeaseContract?
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
        self.userId = json["userId"] as? String ?? ""
        self.provider = provider
        self.providerMode = providerMode
        self.personaId = personaId
        self.scene = scene
        self.deviceId = json["deviceId"] as? String ?? ""
        self.lifecycleMode = lifecycleMode
        self.lifecycleModeLabel = json["lifecycleModeLabel"] as? String ?? lifecycleMode.displayName
        let backendAssetKey = Self.nonEmptyString(json["assetKey"])
        let backendProviderAssetId = Self.nonEmptyString(json["providerAssetId"])
        let localAssetVirtualmanKey = Self.shouldUseLocalAssetVirtualmanKeyOverride
            ? Self.localAssetVirtualmanKeyOverride
            : nil
        self.assetKey = localAssetVirtualmanKey ?? backendAssetKey
        self.providerAssetId = localAssetVirtualmanKey ?? backendProviderAssetId
        self.providerProjectId = json["providerProjectId"] as? String ?? json["virtualmanProjectId"] as? String
        self.assetSource = localAssetVirtualmanKey != nil ? "localQAOverride" : "backendSession"
        self.driveMode = driveMode
        self.alphaEnabled = json["alphaEnabled"] as? Bool ?? false
        self.smartActionEnabled = json["smartActionEnabled"] as? Bool ?? false
        self.sessionPolicy = DigitalHumanSessionPolicy(json: json["sessionPolicy"] as? [String: Any])
        self.credential = DigitalHumanSessionCredential(json: json["credential"] as? [String: Any])
        let fallback = json["fallback"] as? [String: Any]
        self.fallbackMode = fallback?["mode"] as? String ?? "audioOnly"
        self.fallbackReason = fallback?["reason"] as? String ?? ""
        self.lease = (json["lease"] as? [String: Any]).map(DigitalHumanSessionLeaseContract.init(json:))
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

    private static var localAssetVirtualmanKeyOverride: String? {
        let raw = Bundle.main.object(forInfoDictionaryKey: localAssetVirtualmanKeyInfoKey) as? String
        let value = raw?.trimmingCharacters(in: .whitespacesAndNewlines)
        return value?.isEmpty == false ? value : nil
    }

    private static var shouldUseLocalAssetVirtualmanKeyOverride: Bool {
        ProcessInfo.processInfo.arguments.contains(localAssetVirtualmanKeyOverrideArgument)
    }

    private static func nonEmptyString(_ value: Any?) -> String? {
        guard let value = value as? String else {
            return nil
        }
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
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
    let qualityAcceptanceState: String
    let qualityAcceptedAt: String?
    let isEnabled: Bool
    let defaultReleaseVisible: Bool
    let contractVersion: Int
    let disableContract: String
    let deleteContract: String
    let personaScope: String
    let digitalHumanId: String
    let providerBindingMode: String
    let providerSlotManaged: Bool
    let providerSlotState: String

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
        self.qualityAcceptanceState = json["qualityAcceptanceState"] as? String ?? ""
        self.qualityAcceptedAt = json["qualityAcceptedAt"] as? String
        self.isEnabled = json["isEnabled"] as? Bool ?? false
        self.defaultReleaseVisible = json["defaultReleaseVisible"] as? Bool ?? false
        self.contractVersion = Self.intValue(json["contractVersion"]) ?? 1
        self.disableContract = json["disableContract"] as? String ?? ""
        self.deleteContract = json["deleteContract"] as? String ?? ""
        self.personaScope = json["personaScope"] as? String ?? "personal"
        self.digitalHumanId = json["digitalHumanId"] as? String ?? ""
        self.providerBindingMode = json["providerBindingMode"] as? String ?? (
            voiceProfileId.hasPrefix("S_") ? "legacyDirectProviderId" : "unassigned"
        )
        self.providerSlotManaged = json["providerSlotManaged"] as? Bool ?? false
        self.providerSlotState = json["providerSlotState"] as? String ?? ""
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
    let durationSeconds: Double?
    let providerLogId: String?
    let providerRequestId: String?
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
        self.durationSeconds = Self.doubleValue(audioJSON["durationSeconds"])
        self.providerLogId = json["providerLogId"] as? String
        self.providerRequestId = json["providerRequestId"] as? String
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

    private static func doubleValue(_ value: Any?) -> Double? {
        if let value = value as? Double {
            return value
        }
        if let value = value as? NSNumber {
            return value.doubleValue
        }
        if let value = value as? String {
            return Double(value)
        }
        return nil
    }
}

struct EchoContextPacket {
    let schemaVersion: Int
    let contextVersion: String
    let traceId: String
    let intent: String
    let userId: String
    let archiveItemsAvailable: Int
    let archiveItemsIncluded: Int
    let archiveItemIDs: [String]
    let selectedContextRefs: [String]
    let selectedContextRefsBySource: [String: [String]]
    let filteredContextReasons: [String]
    let selectedContextCount: Int
    let filteredContextCount: Int
    let rankingTraceCount: Int
    let selectedContextSourceCounts: [String: Int]
    let kbFactCount: Int
    let generationContextVersion: String
    let generationContextText: String
    let generationContextSourceRefs: [String]
    let generationContextSourceCounts: [String: Int]
    let generationContextContentHash: String?
    let generationContextTruncated: Bool
    let voiceProfileId: String?
    let cloneReady: Bool
    let voiceOutputMode: String
    let digitalHumanSessionReady: Bool
    let digitalHumanProviderMode: String
    let privacyScopeLabel: String
    let canUseFamilyData: Bool
    let crossScopeArchiveIncluded: Bool
    let fallbacks: [String]
    let latencyMs: Int

    init?(json: [String: Any]) {
        guard let traceId = json["traceId"] as? String,
              let intent = json["intent"] as? String,
              let userId = json["userId"] as? String else {
            return nil
        }
        self.schemaVersion = Self.intValue(json["schemaVersion"]) ?? 0
        self.contextVersion = json["contextVersion"] as? String ?? "echo-context-v1"
        self.traceId = traceId
        self.intent = intent
        self.userId = userId

        let memory = json["memory"] as? [String: Any]
        let facts = memory?["kbFacts"] as? [[String: Any]] ?? []
        self.kbFactCount = facts.count

        let trace = json["trace"] as? [String: Any]
        self.archiveItemIDs = Self.stringArray(trace?["archiveItemIds"])
        let selectedContext = json["selectedContext"] as? [[String: Any]] ?? []
        let filteredContext = json["filteredContext"] as? [[String: Any]] ?? []
        let rankingTrace = json["rankingTrace"] as? [[String: Any]] ?? []
        self.selectedContextRefs = Self.contextRefArray(selectedContext)
        self.selectedContextRefsBySource = Self.contextRefsBySource(selectedContext)
        self.filteredContextReasons = Self.filteredReasonArray(filteredContext)
        self.selectedContextCount = Self.intValue(trace?["selectedContextCount"]) ?? selectedContext.count
        self.filteredContextCount = Self.intValue(trace?["filteredContextCount"]) ?? filteredContext.count
        self.rankingTraceCount = Self.intValue(trace?["rankingTraceCount"]) ?? rankingTrace.count
        self.selectedContextSourceCounts = Self.intDictionary(trace?["selectedContextSourceCounts"])
            ?? Self.contextSourceCounts(selectedContext)

        let generationContext = json["generationContext"] as? [String: Any]
        let generationSourceRefs = generationContext?["sourceRefs"] as? [[String: Any]] ?? []
        self.generationContextVersion = generationContext?["version"] as? String
            ?? "echo-generation-context-unavailable"
        self.generationContextText = generationContext?["text"] as? String ?? ""
        self.generationContextSourceRefs = Self.contextRefArray(generationSourceRefs)
        self.generationContextSourceCounts = Self.intDictionary(generationContext?["sourceCounts"])
            ?? Self.contextSourceCounts(generationSourceRefs)
        self.generationContextContentHash = generationContext?["contentHash"] as? String
        self.generationContextTruncated = Self.boolValue(generationContext?["truncated"]) ?? false

        let voice = json["voice"] as? [String: Any]
        self.voiceProfileId = voice?["voiceProfileId"] as? String
        self.cloneReady = Self.boolValue(voice?["cloneReady"]) ?? false
        self.voiceOutputMode = voice?["outputMode"] as? String ?? "unknown"

        let digitalHuman = json["digitalHuman"] as? [String: Any]
        self.digitalHumanSessionReady = Self.boolValue(digitalHuman?["sessionReady"]) ?? false
        self.digitalHumanProviderMode = digitalHuman?["providerMode"] as? String ?? "unknown"

        let policy = json["policy"] as? [String: Any]
        let privacyScope = policy?["privacyScope"] as? [String: Any]
        self.privacyScopeLabel = privacyScope?["scopeLabel"] as? String ?? "unknown"
        self.canUseFamilyData = Self.boolValue(privacyScope?["canUseFamilyData"])
            ?? Self.boolValue(policy?["canUseFamilyData"])
            ?? false
        self.crossScopeArchiveIncluded = Self.boolValue(policy?["crossScopeArchiveIncluded"]) ?? false
        self.fallbacks = json["fallbacks"] as? [String] ?? []

        let debug = json["debug"] as? [String: Any]
        let sourceCounts = debug?["sourceCounts"] as? [String: Any]
        self.archiveItemsAvailable = Self.intValue(sourceCounts?["archiveItemsAvailable"]) ?? 0
        self.archiveItemsIncluded = Self.intValue(sourceCounts?["archiveItemsIncluded"]) ?? 0
        self.latencyMs = Self.intValue(debug?["latencyMs"]) ?? 0
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

    private static func stringArray(_ value: Any?) -> [String] {
        if let strings = value as? [String] {
            return strings
        }
        if let values = value as? [Any] {
            return values.compactMap { item in
                if let text = item as? String {
                    return text
                }
                if let number = item as? NSNumber {
                    return number.stringValue
                }
                return nil
            }
        }
        return []
    }

    private static func contextRefArray(_ entries: [[String: Any]]) -> [String] {
        entries.compactMap { entry in
            let refId = String(describing: entry["refId"] ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
            return refId.isEmpty ? nil : refId
        }
    }

    private static func contextRefsBySource(_ entries: [[String: Any]]) -> [String: [String]] {
        var result: [String: [String]] = [:]
        for entry in entries {
            let source = String(describing: entry["source"] ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
            let refId = String(describing: entry["refId"] ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
            guard !source.isEmpty, !refId.isEmpty else {
                continue
            }
            result[source, default: []].append(refId)
        }
        return result
    }

    private static func filteredReasonArray(_ entries: [[String: Any]]) -> [String] {
        entries.compactMap { entry in
            let refId = String(describing: entry["refId"] ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
            let reason = String(describing: entry["reason"] ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
            guard !reason.isEmpty else {
                return nil
            }
            return refId.isEmpty ? reason : "\(refId):\(reason)"
        }
    }

    private static func contextSourceCounts(_ entries: [[String: Any]]) -> [String: Int] {
        var counts: [String: Int] = [:]
        for entry in entries {
            let source = String(describing: entry["source"] ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
            guard !source.isEmpty else {
                continue
            }
            counts[source, default: 0] += 1
        }
        return counts
    }

    private static func intDictionary(_ value: Any?) -> [String: Int]? {
        guard let dictionary = value as? [String: Any] else {
            return nil
        }
        var result: [String: Int] = [:]
        for (key, value) in dictionary {
            if let intValue = intValue(value) {
                result[key] = intValue
            }
        }
        return result
    }

    private static func boolValue(_ value: Any?) -> Bool? {
        if let value = value as? Bool {
            return value
        }
        if let value = value as? NSNumber {
            return value.boolValue
        }
        if let value = value as? String {
            switch value.lowercased() {
            case "true", "1", "yes":
                return true
            case "false", "0", "no":
                return false
            default:
                return nil
            }
        }
        return nil
    }
}

struct EchoTraceRecord: Codable {
    let turnID: String
    let traceId: String
    let userId: String
    let recordedAt: Date
    let contextVersion: String
    let archiveItemIDs: [String]
    let archiveItemsIncluded: Int
    let archiveItemsAvailable: Int
    let selectedContextRefs: [String]
    let selectedContextRefsBySource: [String: [String]]
    let filteredContextReasons: [String]
    let selectedContextCount: Int
    let filteredContextCount: Int
    let rankingTraceCount: Int
    let selectedContextSourceCounts: [String: Int]
    let kbFactCount: Int
    let voiceProfileId: String?
    let voiceCloneReady: Bool
    let voiceOutputMode: String
    let digitalHumanSessionReady: Bool
    let digitalHumanProviderMode: String
    let privacyScopeLabel: String
    let canUseFamilyData: Bool
    let crossScopeArchiveIncluded: Bool
    let fallbacks: [String]
    let latencyMs: Int

    enum CodingKeys: String, CodingKey {
        case turnID
        case traceId
        case userId
        case recordedAt
        case contextVersion
        case archiveItemIDs
        case archiveItemsIncluded
        case archiveItemsAvailable
        case selectedContextRefs
        case selectedContextRefsBySource
        case filteredContextReasons
        case selectedContextCount
        case filteredContextCount
        case rankingTraceCount
        case selectedContextSourceCounts
        case kbFactCount
        case voiceProfileId
        case voiceCloneReady
        case voiceOutputMode
        case digitalHumanSessionReady
        case digitalHumanProviderMode
        case privacyScopeLabel
        case canUseFamilyData
        case crossScopeArchiveIncluded
        case fallbacks
        case latencyMs
    }

    init(turnID: String, packet: EchoContextPacket) {
        self.init(
            turnID: turnID,
            traceId: packet.traceId,
            userId: packet.userId,
            archiveItemIDs: packet.archiveItemIDs,
            archiveItemsIncluded: packet.archiveItemsIncluded,
            archiveItemsAvailable: packet.archiveItemsAvailable,
            contextVersion: packet.contextVersion,
            selectedContextRefs: packet.selectedContextRefs,
            selectedContextRefsBySource: packet.selectedContextRefsBySource,
            filteredContextReasons: packet.filteredContextReasons,
            selectedContextCount: packet.selectedContextCount,
            filteredContextCount: packet.filteredContextCount,
            rankingTraceCount: packet.rankingTraceCount,
            selectedContextSourceCounts: packet.selectedContextSourceCounts,
            kbFactCount: packet.kbFactCount,
            voiceProfileId: packet.voiceProfileId,
            voiceCloneReady: packet.cloneReady,
            voiceOutputMode: packet.voiceOutputMode,
            digitalHumanSessionReady: packet.digitalHumanSessionReady,
            digitalHumanProviderMode: packet.digitalHumanProviderMode,
            privacyScopeLabel: packet.privacyScopeLabel,
            canUseFamilyData: packet.canUseFamilyData,
            crossScopeArchiveIncluded: packet.crossScopeArchiveIncluded,
            fallbacks: packet.fallbacks,
            latencyMs: packet.latencyMs
        )
    }

    init(
        turnID: String,
        traceId: String,
        userId: String,
        recordedAt: Date = Date(),
        archiveItemIDs: [String],
        archiveItemsIncluded: Int,
        archiveItemsAvailable: Int,
        contextVersion: String = "echo-context-v1",
        selectedContextRefs: [String] = [],
        selectedContextRefsBySource: [String: [String]] = [:],
        filteredContextReasons: [String] = [],
        selectedContextCount: Int? = nil,
        filteredContextCount: Int? = nil,
        rankingTraceCount: Int = 0,
        selectedContextSourceCounts: [String: Int] = [:],
        kbFactCount: Int,
        voiceProfileId: String?,
        voiceCloneReady: Bool,
        voiceOutputMode: String,
        digitalHumanSessionReady: Bool,
        digitalHumanProviderMode: String,
        privacyScopeLabel: String,
        canUseFamilyData: Bool,
        crossScopeArchiveIncluded: Bool,
        fallbacks: [String],
        latencyMs: Int
    ) {
        self.turnID = turnID
        self.traceId = traceId
        self.userId = userId
        self.recordedAt = recordedAt
        self.contextVersion = contextVersion
        self.archiveItemIDs = archiveItemIDs
        self.archiveItemsIncluded = archiveItemsIncluded
        self.archiveItemsAvailable = archiveItemsAvailable
        self.selectedContextRefs = selectedContextRefs
        self.selectedContextRefsBySource = selectedContextRefsBySource
        self.filteredContextReasons = filteredContextReasons
        self.selectedContextCount = selectedContextCount ?? selectedContextRefs.count
        self.filteredContextCount = filteredContextCount ?? filteredContextReasons.count
        self.rankingTraceCount = rankingTraceCount
        self.selectedContextSourceCounts = selectedContextSourceCounts
        self.kbFactCount = kbFactCount
        self.voiceProfileId = voiceProfileId
        self.voiceCloneReady = voiceCloneReady
        self.voiceOutputMode = voiceOutputMode
        self.digitalHumanSessionReady = digitalHumanSessionReady
        self.digitalHumanProviderMode = digitalHumanProviderMode
        self.privacyScopeLabel = privacyScopeLabel
        self.canUseFamilyData = canUseFamilyData
        self.crossScopeArchiveIncluded = crossScopeArchiveIncluded
        self.fallbacks = fallbacks
        self.latencyMs = latencyMs
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.turnID = try container.decode(String.self, forKey: .turnID)
        self.traceId = try container.decode(String.self, forKey: .traceId)
        self.userId = try container.decode(String.self, forKey: .userId)
        self.recordedAt = try container.decode(Date.self, forKey: .recordedAt)
        self.contextVersion = try container.decodeIfPresent(String.self, forKey: .contextVersion) ?? "echo-context-v1"
        self.archiveItemIDs = try container.decodeIfPresent([String].self, forKey: .archiveItemIDs) ?? []
        self.archiveItemsIncluded = try container.decodeIfPresent(Int.self, forKey: .archiveItemsIncluded) ?? self.archiveItemIDs.count
        self.archiveItemsAvailable = try container.decodeIfPresent(Int.self, forKey: .archiveItemsAvailable) ?? self.archiveItemsIncluded
        self.selectedContextRefs = try container.decodeIfPresent([String].self, forKey: .selectedContextRefs) ?? []
        self.selectedContextRefsBySource = try container.decodeIfPresent([String: [String]].self, forKey: .selectedContextRefsBySource) ?? [:]
        self.filteredContextReasons = try container.decodeIfPresent([String].self, forKey: .filteredContextReasons) ?? []
        self.selectedContextCount = try container.decodeIfPresent(Int.self, forKey: .selectedContextCount) ?? self.selectedContextRefs.count
        self.filteredContextCount = try container.decodeIfPresent(Int.self, forKey: .filteredContextCount) ?? self.filteredContextReasons.count
        self.rankingTraceCount = try container.decodeIfPresent(Int.self, forKey: .rankingTraceCount) ?? 0
        self.selectedContextSourceCounts = try container.decodeIfPresent([String: Int].self, forKey: .selectedContextSourceCounts) ?? [:]
        self.kbFactCount = try container.decodeIfPresent(Int.self, forKey: .kbFactCount) ?? 0
        self.voiceProfileId = try container.decodeIfPresent(String.self, forKey: .voiceProfileId)
        self.voiceCloneReady = try container.decodeIfPresent(Bool.self, forKey: .voiceCloneReady) ?? false
        self.voiceOutputMode = try container.decodeIfPresent(String.self, forKey: .voiceOutputMode) ?? "unknown"
        self.digitalHumanSessionReady = try container.decodeIfPresent(Bool.self, forKey: .digitalHumanSessionReady) ?? false
        self.digitalHumanProviderMode = try container.decodeIfPresent(String.self, forKey: .digitalHumanProviderMode) ?? "unknown"
        self.privacyScopeLabel = try container.decodeIfPresent(String.self, forKey: .privacyScopeLabel) ?? "unknown"
        self.canUseFamilyData = try container.decodeIfPresent(Bool.self, forKey: .canUseFamilyData) ?? false
        self.crossScopeArchiveIncluded = try container.decodeIfPresent(Bool.self, forKey: .crossScopeArchiveIncluded) ?? false
        self.fallbacks = try container.decodeIfPresent([String].self, forKey: .fallbacks) ?? []
        self.latencyMs = try container.decodeIfPresent(Int.self, forKey: .latencyMs) ?? 0
    }

    var logLine: String {
        let archiveIDs = archiveItemIDs.joined(separator: ",")
        let selectedRefs = selectedContextRefs.joined(separator: ",")
        let selectedRefsBySource = selectedContextRefsBySource
            .sorted { $0.key < $1.key }
            .map { "\($0.key):\($0.value.joined(separator: "|"))" }
            .joined(separator: ",")
        let filteredReasons = filteredContextReasons.joined(separator: ",")
        let sourceCounts = selectedContextSourceCounts
            .sorted { $0.key < $1.key }
            .map { "\($0.key):\($0.value)" }
            .joined(separator: ",")
        let fallbackList = fallbacks.joined(separator: ",")
        let profileID = voiceProfileId ?? "none"
        return "[CFLite] trace record " +
        "turnID=\(turnID) traceId=\(traceId) userId=\(userId) " +
        "contextVersion=\(contextVersion) " +
        "privacyScope=\(privacyScopeLabel) canUseFamilyData=\(canUseFamilyData) " +
        "archiveIncluded=\(archiveItemsIncluded)/\(archiveItemsAvailable) " +
        "archiveItemIDs=\(archiveIDs) " +
        "selectedContextRefs=\(selectedRefs) selectedContextCount=\(selectedContextCount) " +
        "selectedContextRefsBySource=\(selectedRefsBySource) " +
        "selectedContextSourceCounts=\(sourceCounts) " +
        "filteredContextReasons=\(filteredReasons) filteredContextCount=\(filteredContextCount) " +
        "rankingTraceCount=\(rankingTraceCount) " +
        "kbFacts=\(kbFactCount) cloneReady=\(voiceCloneReady) " +
        "voiceProfileId=\(profileID) outputMode=\(voiceOutputMode) " +
        "digitalHumanReady=\(digitalHumanSessionReady) " +
        "digitalHumanProviderMode=\(digitalHumanProviderMode) " +
        "crossScopeArchiveIncluded=\(crossScopeArchiveIncluded) " +
        "fallbacks=\(fallbackList) latencyMs=\(latencyMs)"
    }
}

struct EchoRuntimeDiagnosticsSnapshot: Codable {
    let schemaVersion: Int
    let snapshotId: String
    let turnID: String
    let traceId: String
    let userId: String
    let recordedAt: Date
    let archiveItemIDs: [String]
    let archiveItemsIncluded: Int
    let archiveItemsAvailable: Int
    let kbFactCount: Int
    let voiceProfileId: String?
    let voiceCloneReady: Bool
    let voiceOutputMode: String
    let roleVoiceSource: String?
    let roleVoiceDisplayName: String?
    let roleVoiceContextOwnerId: String?
    let audioOwner: String
    let digitalHumanRuntimeState: String
    let digitalHumanSessionReady: Bool
    let digitalHumanProviderMode: String
    let providerLogId: String?
    let providerRequestId: String?
    let providerMode: String?
    let fallbackReason: String?
    let privacyScopeLabel: String
    let canUseFamilyData: Bool
    let crossScopeArchiveIncluded: Bool
    let contextLatencyMs: Int
    let source: String

    init(
        trace: EchoTraceRecord?,
        audioOwner: String,
        selectedVoiceProfileId: String? = nil,
        roleVoiceSource: String? = nil,
        roleVoiceDisplayName: String? = nil,
        roleVoiceContextOwnerId: String? = nil,
        digitalHumanRuntimeState: String,
        digitalHumanSessionReady: Bool? = nil,
        digitalHumanProviderMode: String? = nil,
        providerLogId: String? = nil,
        providerRequestId: String? = nil,
        providerMode: String? = nil,
        fallbackReason: String? = nil,
        source: String
    ) {
        self.schemaVersion = 1
        let uniqueSuffix = String(UUID().uuidString.replacingOccurrences(of: "-", with: "").prefix(24))
        self.snapshotId = "echo_diag_" + uniqueSuffix
        self.turnID = trace?.turnID ?? "unknown"
        self.traceId = trace?.traceId ?? "none"
        self.userId = trace?.userId ?? "unknown"
        self.recordedAt = Date()
        self.archiveItemIDs = trace?.archiveItemIDs ?? []
        self.archiveItemsIncluded = trace?.archiveItemsIncluded ?? 0
        self.archiveItemsAvailable = trace?.archiveItemsAvailable ?? 0
        self.kbFactCount = trace?.kbFactCount ?? 0
        self.voiceProfileId = selectedVoiceProfileId ?? trace?.voiceProfileId
        self.voiceCloneReady = trace?.voiceCloneReady ?? false
        self.voiceOutputMode = trace?.voiceOutputMode ?? "unknown"
        self.roleVoiceSource = roleVoiceSource
        self.roleVoiceDisplayName = roleVoiceDisplayName
        self.roleVoiceContextOwnerId = roleVoiceContextOwnerId
        self.audioOwner = audioOwner
        self.digitalHumanRuntimeState = digitalHumanRuntimeState
        self.digitalHumanSessionReady = digitalHumanSessionReady ?? trace?.digitalHumanSessionReady ?? false
        self.digitalHumanProviderMode = digitalHumanProviderMode ?? trace?.digitalHumanProviderMode ?? "unknown"
        self.providerLogId = providerLogId
        self.providerRequestId = providerRequestId
        self.providerMode = providerMode
        self.fallbackReason = fallbackReason
        self.privacyScopeLabel = trace?.privacyScopeLabel ?? "unknown"
        self.canUseFamilyData = trace?.canUseFamilyData ?? false
        self.crossScopeArchiveIncluded = trace?.crossScopeArchiveIncluded ?? false
        self.contextLatencyMs = trace?.latencyMs ?? 0
        self.source = source
    }
}

final class EchoTraceStore {
    static let shared = EchoTraceStore()

    private let userDefaults: UserDefaults
    private let storageKey = "DreamJourney.EchoTraceStore.records.v1"
    private let maximumRecordCount = 20

    init(userDefaults: UserDefaults = .standard) {
        self.userDefaults = userDefaults
    }

    func record(_ record: EchoTraceRecord) {
        var records = recentRecords()
        records.append(record)
        if records.count > maximumRecordCount {
            records = Array(records.suffix(maximumRecordCount))
        }
        save(records)
    }

    func recentRecords() -> [EchoTraceRecord] {
        guard let data = userDefaults.data(forKey: storageKey) else {
            return []
        }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return (try? decoder.decode([EchoTraceRecord].self, from: data)) ?? []
    }

    func clear() {
        userDefaults.removeObject(forKey: storageKey)
    }

    func exportRecentRecords(
        to directory: URL = FileManager.default.temporaryDirectory,
        fileName: String = "echo-trace-records.json"
    ) throws -> URL {
        let records = recentRecords()
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let url = directory.appendingPathComponent(fileName)
        let data = try Self.makeJSONEncoder().encode(records)
        try data.write(to: url, options: [.atomic])
        return url
    }

    private func save(_ records: [EchoTraceRecord]) {
        guard let data = try? Self.makeJSONEncoder().encode(records) else {
            return
        }
        userDefaults.set(data, forKey: storageKey)
    }

    private static func makeJSONEncoder() -> JSONEncoder {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        return encoder
    }
}

final class EchoRuntimeDiagnosticsStore {
    static let shared = EchoRuntimeDiagnosticsStore()

    private let userDefaults: UserDefaults
    private let storageKey = "DreamJourney.EchoRuntimeDiagnosticsStore.snapshots.v1"
    private let maximumSnapshotCount = 20

    init(userDefaults: UserDefaults = .standard) {
        self.userDefaults = userDefaults
    }

    func record(_ snapshot: EchoRuntimeDiagnosticsSnapshot) {
        var snapshots = recentSnapshots()
        snapshots.append(snapshot)
        if snapshots.count > maximumSnapshotCount {
            snapshots = Array(snapshots.suffix(maximumSnapshotCount))
        }
        save(snapshots)
    }

    func recentSnapshots() -> [EchoRuntimeDiagnosticsSnapshot] {
        guard let data = userDefaults.data(forKey: storageKey) else {
            return []
        }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return (try? decoder.decode([EchoRuntimeDiagnosticsSnapshot].self, from: data)) ?? []
    }

    func clear() {
        userDefaults.removeObject(forKey: storageKey)
    }

    func exportRecentSnapshots(
        to directory: URL = FileManager.default.temporaryDirectory,
        fileName: String = "echo-runtime-diagnostics.json"
    ) throws -> URL {
        let snapshots = recentSnapshots()
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let url = directory.appendingPathComponent(fileName)
        let data = try Self.makeJSONEncoder().encode(snapshots)
        try data.write(to: url, options: [.atomic])
        return url
    }

    private func save(_ snapshots: [EchoRuntimeDiagnosticsSnapshot]) {
        guard let data = try? Self.makeJSONEncoder().encode(snapshots) else {
            return
        }
        userDefaults.set(data, forKey: storageKey)
    }

    private static func makeJSONEncoder() -> JSONEncoder {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        return encoder
    }
}

struct EchoContextV2ClueSummary: Codable {
    let contextVersion: String
    let selectedContextRefs: [String]
    let selectedContextRefsBySource: [String: [String]]
    let archiveRefs: [String]
    let kbFactRefs: [String]
    let personaRefs: [String]
    let careRefs: [String]
    let filteredContextReasons: [String]
    let rankingTraceCount: Int
    let selectedContextSourceCounts: [String: Int]
    let fallbacks: [String]
    let latencyMs: Int

    init(record: EchoTraceRecord?) {
        self.contextVersion = record?.contextVersion ?? "missing"
        self.selectedContextRefs = record?.selectedContextRefs ?? []
        self.selectedContextRefsBySource = record?.selectedContextRefsBySource ?? [:]
        self.archiveRefs = Self.sourceRefs(record, source: "archive", fallback: record?.archiveItemIDs ?? [])
        self.kbFactRefs = Self.sourceRefs(record, source: "kbFact")
        self.personaRefs = Self.sourceRefs(record, source: "persona")
        self.careRefs = Self.sourceRefs(record, source: "care")
        self.filteredContextReasons = record?.filteredContextReasons ?? []
        self.rankingTraceCount = record?.rankingTraceCount ?? 0
        self.selectedContextSourceCounts = record?.selectedContextSourceCounts ?? [:]
        self.fallbacks = record?.fallbacks ?? []
        self.latencyMs = record?.latencyMs ?? 0
    }

    static func sourceRefs(
        _ record: EchoTraceRecord?,
        source: String,
        fallback: [String] = []
    ) -> [String] {
        let refs = record?.selectedContextRefsBySource[source] ?? []
        return refs.isEmpty ? fallback : refs
    }

    func panelLines(prefix: String = "ctx") -> [String] {
        [
            "\(prefix) 使用线索",
            "\(prefix) archive: \(Self.preview(archiveRefs))",
            "\(prefix) kbFact: \(Self.preview(kbFactRefs))",
            "\(prefix) persona: \(Self.preview(personaRefs))",
            "\(prefix) care: \(Self.preview(careRefs))",
            "\(prefix) filtered: \(Self.preview(filteredContextReasons))",
            "\(prefix) ranking: \(rankingTraceCount)",
            "\(prefix) sources: \(Self.previewSourceCounts(selectedContextSourceCounts))",
            "\(prefix) fallbacks: \(Self.preview(fallbacks))",
            "\(prefix) latencyMs: \(latencyMs)"
        ]
    }

    private static func preview(_ values: [String], limit: Int = 3) -> String {
        guard !values.isEmpty else {
            return "none"
        }
        let prefix = values.prefix(limit).joined(separator: ",")
        let overflow = values.count > limit ? "+\(values.count - limit)" : ""
        return prefix + overflow
    }

    private static func previewSourceCounts(_ counts: [String: Int]) -> String {
        guard !counts.isEmpty else {
            return "none"
        }
        return counts
            .sorted { $0.key < $1.key }
            .map { "\($0.key):\($0.value)" }
            .joined(separator: ",")
    }
}

struct EchoContextBuildEvidenceSummary: Codable {
    let status: String
    let traceId: String
    let userId: String
    let contextVersion: String?
    let archiveItemIDs: [String]
    let archiveItemsIncluded: Int
    let archiveItemsAvailable: Int
    let selectedContextRefs: [String]
    let filteredContextReasons: [String]
    let selectedContextCount: Int
    let filteredContextCount: Int
    let rankingTraceCount: Int
    let selectedContextSourceCounts: [String: Int]
    let clueSummary: EchoContextV2ClueSummary
    let kbFactCount: Int
    let voiceProfileId: String?
    let voiceOutputMode: String
    let digitalHumanSessionReady: Bool
    let digitalHumanProviderMode: String
    let privacyScopeLabel: String
    let canUseFamilyData: Bool
    let crossScopeArchiveIncluded: Bool
    let fallbacks: [String]
    let latencyMs: Int
    let failureReason: String?

    init(record: EchoTraceRecord?) {
        self.status = record == nil ? "missing" : "ready"
        self.traceId = record?.traceId ?? "none"
        self.userId = record?.userId ?? "unknown"
        self.contextVersion = record?.contextVersion
        self.archiveItemIDs = record?.archiveItemIDs ?? []
        self.archiveItemsIncluded = record?.archiveItemsIncluded ?? 0
        self.archiveItemsAvailable = record?.archiveItemsAvailable ?? 0
        self.selectedContextRefs = record?.selectedContextRefs ?? []
        self.filteredContextReasons = record?.filteredContextReasons ?? []
        self.selectedContextCount = record?.selectedContextCount ?? 0
        self.filteredContextCount = record?.filteredContextCount ?? 0
        self.rankingTraceCount = record?.rankingTraceCount ?? 0
        self.selectedContextSourceCounts = record?.selectedContextSourceCounts ?? [:]
        self.clueSummary = EchoContextV2ClueSummary(record: record)
        self.kbFactCount = record?.kbFactCount ?? 0
        self.voiceProfileId = record?.voiceProfileId
        self.voiceOutputMode = record?.voiceOutputMode ?? "unknown"
        self.digitalHumanSessionReady = record?.digitalHumanSessionReady ?? false
        self.digitalHumanProviderMode = record?.digitalHumanProviderMode ?? "unknown"
        self.privacyScopeLabel = record?.privacyScopeLabel ?? "unknown"
        self.canUseFamilyData = record?.canUseFamilyData ?? false
        self.crossScopeArchiveIncluded = record?.crossScopeArchiveIncluded ?? false
        self.fallbacks = record?.fallbacks ?? []
        self.latencyMs = record?.latencyMs ?? 0
        self.failureReason = record == nil ? "contextPacketMissing" : nil
    }
}

struct EchoDigitalHumanSessionEvidenceSummary: Codable {
    let status: String
    let sessionId: String?
    let provider: String?
    let providerMode: String?
    let personaId: String?
    let scene: String?
    let lifecycleMode: String?
    let driveMode: String?
    let assetSource: String?
    let hasProviderAssetId: Bool
    let hasProviderProjectId: Bool
    let credentialMode: String?
    let credentialExpiresAt: Date?
    let hasBackendIssuedCredential: Bool
    let fallbackMode: String?
    let fallbackReason: String?
    let contractVersion: Int?
    let failureReason: String?
    let failureDetail: String?

    init(contract: DigitalHumanSessionContract) {
        self.status = "ready"
        self.sessionId = contract.sessionId
        self.provider = contract.provider
        self.providerMode = contract.providerMode
        self.personaId = contract.personaId
        self.scene = contract.scene
        self.lifecycleMode = contract.lifecycleMode.rawValue
        self.driveMode = contract.driveMode
        self.assetSource = contract.assetSource
        self.hasProviderAssetId = contract.providerAssetId?.isEmpty == false
        self.hasProviderProjectId = contract.providerProjectId?.isEmpty == false
        self.credentialMode = contract.credential.mode
        self.credentialExpiresAt = contract.credential.expiresAt
        self.hasBackendIssuedCredential = contract.credential.appKey?.isEmpty == false
            && contract.credential.accessToken?.isEmpty == false
        self.fallbackMode = contract.fallbackMode
        self.fallbackReason = contract.fallbackReason
        self.contractVersion = contract.contractVersion
        self.failureReason = nil
        self.failureDetail = nil
    }

    static func unavailable(reason: String, detail: String? = nil) -> EchoDigitalHumanSessionEvidenceSummary {
        EchoDigitalHumanSessionEvidenceSummary(status: "unavailable", reason: reason, detail: detail)
    }

    static func failed(reason: String, detail: String? = nil) -> EchoDigitalHumanSessionEvidenceSummary {
        EchoDigitalHumanSessionEvidenceSummary(status: "failed", reason: reason, detail: detail)
    }

    private init(status: String, reason: String, detail: String?) {
        self.status = status
        self.sessionId = nil
        self.provider = nil
        self.providerMode = nil
        self.personaId = nil
        self.scene = nil
        self.lifecycleMode = nil
        self.driveMode = nil
        self.assetSource = nil
        self.hasProviderAssetId = false
        self.hasProviderProjectId = false
        self.credentialMode = nil
        self.credentialExpiresAt = nil
        self.hasBackendIssuedCredential = false
        self.fallbackMode = nil
        self.fallbackReason = nil
        self.contractVersion = nil
        self.failureReason = reason
        self.failureDetail = detail
    }
}

struct EchoVoiceSynthesisEvidenceSummary: Codable {
    let status: String
    let voiceProfileId: String?
    let providerMode: String?
    let outputMode: String?
    let audioFormat: String?
    let byteCount: Int
    let sampleRate: Int?
    let bitsPerSample: Int?
    let channelCount: Int?
    let durationSeconds: Double?
    let providerLogId: String?
    let providerRequestId: String?
    let tencentAudioDriveCompatible: Bool
    let visemeFrameCount: Int
    let failureReason: String?
    let failureDetail: String?

    init(synthesis: VoiceCloneSynthesisResult) {
        self.status = "ready"
        self.voiceProfileId = synthesis.voiceProfileId
        self.providerMode = synthesis.providerMode
        self.outputMode = synthesis.outputMode
        self.audioFormat = synthesis.audioFormat
        self.byteCount = synthesis.byteCount
        self.sampleRate = synthesis.sampleRate
        self.bitsPerSample = synthesis.bitsPerSample
        self.channelCount = synthesis.channelCount
        self.durationSeconds = synthesis.durationSeconds
        self.providerLogId = synthesis.providerLogId
        self.providerRequestId = synthesis.providerRequestId
        self.tencentAudioDriveCompatible = synthesis.isTencentAudioDrivePCMCompatible
        self.visemeFrameCount = synthesis.visemeTimeline?.frames.count ?? 0
        self.failureReason = nil
        self.failureDetail = nil
    }

    static func unavailable(reason: String, detail: String? = nil) -> EchoVoiceSynthesisEvidenceSummary {
        EchoVoiceSynthesisEvidenceSummary(status: "unavailable", reason: reason, detail: detail)
    }

    static func failed(
        voiceProfileId: String?,
        outputMode: String?,
        providerLogId: String?,
        providerRequestId: String?,
        reason: String,
        detail: String?
    ) -> EchoVoiceSynthesisEvidenceSummary {
        EchoVoiceSynthesisEvidenceSummary(
            status: "failed",
            voiceProfileId: voiceProfileId,
            outputMode: outputMode,
            providerLogId: providerLogId,
            providerRequestId: providerRequestId,
            reason: reason,
            detail: detail
        )
    }

    private init(status: String, reason: String, detail: String?) {
        self.init(
            status: status,
            voiceProfileId: nil,
            outputMode: nil,
            providerLogId: nil,
            providerRequestId: nil,
            reason: reason,
            detail: detail
        )
    }

    private init(
        status: String,
        voiceProfileId: String?,
        outputMode: String?,
        providerLogId: String?,
        providerRequestId: String?,
        reason: String,
        detail: String?
    ) {
        self.status = status
        self.voiceProfileId = voiceProfileId
        self.providerMode = nil
        self.outputMode = outputMode
        self.audioFormat = nil
        self.byteCount = 0
        self.sampleRate = nil
        self.bitsPerSample = nil
        self.channelCount = nil
        self.durationSeconds = nil
        self.providerLogId = providerLogId
        self.providerRequestId = providerRequestId
        self.tencentAudioDriveCompatible = false
        self.visemeFrameCount = 0
        self.failureReason = reason
        self.failureDetail = detail
    }
}

struct EchoTraceEvidencePackage: Codable {
    let schemaVersion: Int
    let packageId: String
    let generatedAt: Date
    let source: String
    let turnID: String
    let traceId: String
    let traceRecord: EchoTraceRecord?
    let runtimeDiagnostics: EchoRuntimeDiagnosticsSnapshot?
    let contextBuild: EchoContextBuildEvidenceSummary
    let digitalHumanSession: EchoDigitalHumanSessionEvidenceSummary?
    let voiceSynthesis: EchoVoiceSynthesisEvidenceSummary?
    let redactionPolicy: [String]

    init(
        traceRecord: EchoTraceRecord?,
        runtimeDiagnostics: EchoRuntimeDiagnosticsSnapshot?,
        digitalHumanSession: EchoDigitalHumanSessionEvidenceSummary?,
        voiceSynthesis: EchoVoiceSynthesisEvidenceSummary?,
        source: String
    ) {
        self.schemaVersion = 1
        let uniqueSuffix = String(UUID().uuidString.replacingOccurrences(of: "-", with: "").prefix(24))
        self.packageId = "echo_evidence_" + uniqueSuffix
        self.generatedAt = Date()
        self.source = source
        self.turnID = runtimeDiagnostics?.turnID ?? traceRecord?.turnID ?? "unknown"
        self.traceId = runtimeDiagnostics?.traceId ?? traceRecord?.traceId ?? "none"
        self.traceRecord = traceRecord
        self.runtimeDiagnostics = runtimeDiagnostics
        self.contextBuild = EchoContextBuildEvidenceSummary(record: traceRecord)
        self.digitalHumanSession = digitalHumanSession
        self.voiceSynthesis = voiceSynthesis
        self.redactionPolicy = [
            "不导出原始音频或音频正文",
            "不导出供应商访问密钥",
            "只保留 providerLogId/providerRequestId 用于服务商排查",
            "只导出档案 ID、数量和权限摘要，不导出档案正文"
        ]
    }
}

final class EchoTraceEvidencePackageStore {
    static let shared = EchoTraceEvidencePackageStore()

    private let userDefaults: UserDefaults
    private let storageKey = "DreamJourney.EchoTraceEvidencePackageStore.packages.v1"
    private let maximumPackageCount = 20

    init(userDefaults: UserDefaults = .standard) {
        self.userDefaults = userDefaults
    }

    func record(_ package: EchoTraceEvidencePackage) {
        var packages = recentPackages()
        packages.append(package)
        if packages.count > maximumPackageCount {
            packages = Array(packages.suffix(maximumPackageCount))
        }
        save(packages)
    }

    func recentPackages() -> [EchoTraceEvidencePackage] {
        guard let data = userDefaults.data(forKey: storageKey) else {
            return []
        }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return (try? decoder.decode([EchoTraceEvidencePackage].self, from: data)) ?? []
    }

    func clear() {
        userDefaults.removeObject(forKey: storageKey)
    }

    func exportRecentPackages(
        to directory: URL = FileManager.default.temporaryDirectory,
        fileName: String = "echo-trace-evidence-packages.json"
    ) throws -> URL {
        let packages = recentPackages()
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let url = directory.appendingPathComponent(fileName)
        let data = try Self.makeJSONEncoder().encode(packages)
        try data.write(to: url, options: [.atomic])
        return url
    }

    private func save(_ packages: [EchoTraceEvidencePackage]) {
        guard let data = try? Self.makeJSONEncoder().encode(packages) else {
            return
        }
        userDefaults.set(data, forKey: storageKey)
    }

    private static func makeJSONEncoder() -> JSONEncoder {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        return encoder
    }
}

struct EchoQAFallbackSummary: Codable {
    let contextFallbacks: [String]
    let runtimeFallbackReason: String?
    let digitalHumanFallbackReason: String?
    let digitalHumanFailureReason: String?
    let voiceSynthesisFailureReason: String?
    let inferredFallbacks: [String]

    init(
        traceRecord: EchoTraceRecord?,
        runtimeDiagnostics: EchoRuntimeDiagnosticsSnapshot?,
        digitalHumanSession: EchoDigitalHumanSessionEvidenceSummary?,
        voiceSynthesis: EchoVoiceSynthesisEvidenceSummary?
    ) {
        self.contextFallbacks = traceRecord?.fallbacks ?? []
        self.runtimeFallbackReason = runtimeDiagnostics?.fallbackReason
        self.digitalHumanFallbackReason = digitalHumanSession?.fallbackReason
        self.digitalHumanFailureReason = digitalHumanSession?.failureReason
        self.voiceSynthesisFailureReason = voiceSynthesis?.failureReason

        var inferred = Set<String>()
        for fallback in contextFallbacks where !fallback.isEmpty {
            inferred.insert(fallback)
        }
        if let runtimeFallbackReason, !runtimeFallbackReason.isEmpty {
            inferred.insert("runtime:\(runtimeFallbackReason)")
        }
        if let digitalHumanFallbackReason, !digitalHumanFallbackReason.isEmpty {
            inferred.insert("digitalHumanFallback:\(digitalHumanFallbackReason)")
        }
        if let digitalHumanFailureReason, !digitalHumanFailureReason.isEmpty {
            inferred.insert("digitalHumanFailure:\(digitalHumanFailureReason)")
        }
        if let voiceSynthesisFailureReason, !voiceSynthesisFailureReason.isEmpty {
            inferred.insert("voiceSynthesis:\(voiceSynthesisFailureReason)")
        }
        self.inferredFallbacks = inferred.sorted()
    }
}

struct EchoQAEvidenceBundle: Codable {
    let schemaVersion: Int
    let bundleId: String
    let generatedAt: Date
    let source: String
    let turnID: String
    let traceId: String
    let evidencePackage: EchoTraceEvidencePackage
    let traceRecord: EchoTraceRecord?
    let runtimeDiagnostics: EchoRuntimeDiagnosticsSnapshot?
    let contextClues: EchoContextV2ClueSummary
    let digitalHumanSession: EchoDigitalHumanSessionEvidenceSummary?
    let voiceSynthesis: EchoVoiceSynthesisEvidenceSummary?
    let fallbackSummary: EchoQAFallbackSummary
    let redactionPolicy: [String]

    init(evidencePackage: EchoTraceEvidencePackage) {
        self.schemaVersion = 2
        let uniqueSuffix = String(UUID().uuidString.replacingOccurrences(of: "-", with: "").prefix(24))
        self.bundleId = "echo_qa_bundle_" + uniqueSuffix
        self.generatedAt = Date()
        self.source = evidencePackage.source
        self.turnID = evidencePackage.turnID
        self.traceId = evidencePackage.traceId
        self.evidencePackage = evidencePackage
        self.traceRecord = evidencePackage.traceRecord
        self.runtimeDiagnostics = evidencePackage.runtimeDiagnostics
        self.contextClues = evidencePackage.contextBuild.clueSummary
        self.digitalHumanSession = evidencePackage.digitalHumanSession
        self.voiceSynthesis = evidencePackage.voiceSynthesis
        self.fallbackSummary = EchoQAFallbackSummary(
            traceRecord: evidencePackage.traceRecord,
            runtimeDiagnostics: evidencePackage.runtimeDiagnostics,
            digitalHumanSession: evidencePackage.digitalHumanSession,
            voiceSynthesis: evidencePackage.voiceSynthesis
        )
        self.redactionPolicy = evidencePackage.redactionPolicy + [
            "QA bundle v2 汇总 Context V2 线索、数字人 session、声音合成和 fallback 摘要",
            "不导出 raw audio、PCM、音频 base64 或供应商密钥",
            "手动分享仅在 QA 面板中开放"
        ]
    }
}

final class EchoQAEvidenceBundleStore {
    static let shared = EchoQAEvidenceBundleStore()

    private let userDefaults: UserDefaults
    private let storageKey = "DreamJourney.EchoQAEvidenceBundleStore.bundles.v2"
    private let maximumBundleCount = 20

    init(userDefaults: UserDefaults = .standard) {
        self.userDefaults = userDefaults
    }

    func record(_ bundle: EchoQAEvidenceBundle) {
        var bundles = recentBundles()
        bundles.append(bundle)
        if bundles.count > maximumBundleCount {
            bundles = Array(bundles.suffix(maximumBundleCount))
        }
        save(bundles)
    }

    func recentBundles() -> [EchoQAEvidenceBundle] {
        guard let data = userDefaults.data(forKey: storageKey) else {
            return []
        }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return (try? decoder.decode([EchoQAEvidenceBundle].self, from: data)) ?? []
    }

    func clear() {
        userDefaults.removeObject(forKey: storageKey)
    }

    func exportLatestBundle(
        to directory: URL = FileManager.default.temporaryDirectory,
        fileName: String = "echo-qa-evidence-bundle.json"
    ) throws -> URL {
        guard let latestBundle = recentBundles().last else {
            throw NSError(
                domain: "DreamJourney.EchoQAEvidenceBundleStore",
                code: 1,
                userInfo: [NSLocalizedDescriptionKey: "没有可导出的 Echo QA 证据包"]
            )
        }
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let url = directory.appendingPathComponent(fileName)
        let data = try Self.makeJSONEncoder().encode(latestBundle)
        try data.write(to: url, options: [.atomic])
        return url
    }

    private func save(_ bundles: [EchoQAEvidenceBundle]) {
        guard let data = try? Self.makeJSONEncoder().encode(bundles) else {
            return
        }
        userDefaults.set(data, forKey: storageKey)
    }

    private static func makeJSONEncoder() -> JSONEncoder {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        return encoder
    }
}

final class DreamJourneyBackendClient {
    static let shared = DreamJourneyBackendClient()

    private enum RequestAuthPolicy {
        case automatic
        case backendOnly
    }

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
    private let authSessionStore = BackendAuthSessionStore.shared
    private let authRefreshQueue = DispatchQueue(label: "com.dreamjourney.backend-auth-refresh")
    private var authRefreshWaiters: [(Bool) -> Void] = []
    private var isAuthRefreshInFlight = false

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

    var isDigitalHumanSessionConfigured: Bool {
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

    var isContextBuildConfigured: Bool {
        hasExplicitBaseURL
    }

    var isKnowledgeSyncConfigured: Bool {
        hasExplicitBaseURL
    }

    var isTimeLetterDispatchConfigured: Bool {
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

    func fetchVoiceCloneRuntimeCapability(
        completion: @escaping (Result<VoiceCloneRuntimeCapability, Error>) -> Void
    ) {
        fetchRuntimeConfig { result in
            completion(result.map(\.voiceClone))
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

    func heartbeatDigitalHumanSession(
        _ contract: DigitalHumanSessionContract,
        completion: @escaping (Result<DigitalHumanSessionLeaseOperationResult, Error>) -> Void
    ) {
        guard let lease = contract.lease,
              lease.isActive,
              !contract.userId.isEmpty,
              !contract.deviceId.isEmpty else {
            completion(.failure(ClientError.backendError(
                statusCode: nil,
                detail: "digital human session lease is unavailable"
            )))
            return
        }
        let fallbackPath = "/digital-human/sessions/\(pathComponent(contract.sessionId))/heartbeat"
        let path = validatedDigitalHumanLeasePath(lease.heartbeatEndpoint, fallback: fallbackPath)
        requestJSON(
            path: path,
            method: .post,
            payload: ["userId": contract.userId, "deviceId": contract.deviceId]
        ) { result in
            switch result {
            case .success(let object):
                guard let operation = DigitalHumanSessionLeaseOperationResult(json: object) else {
                    completion(.failure(ClientError.invalidJSONResponse))
                    return
                }
                completion(.success(operation))
            case .failure(let error):
                completion(.failure(error))
            }
        }
    }

    func releaseDigitalHumanSession(
        _ contract: DigitalHumanSessionContract,
        reason: String,
        completion: @escaping (Result<DigitalHumanSessionLeaseOperationResult, Error>) -> Void
    ) {
        guard let lease = contract.lease,
              !contract.userId.isEmpty,
              !contract.deviceId.isEmpty else {
            completion(.failure(ClientError.backendError(
                statusCode: nil,
                detail: "digital human session lease is unavailable"
            )))
            return
        }
        let fallbackPath = "/digital-human/sessions/\(pathComponent(contract.sessionId))/release"
        let path = validatedDigitalHumanLeasePath(lease.releaseEndpoint, fallback: fallbackPath)
        requestJSON(
            path: path,
            method: .post,
            payload: [
                "userId": contract.userId,
                "deviceId": contract.deviceId,
                "reason": String(reason.prefix(80)),
            ]
        ) { result in
            switch result {
            case .success(let object):
                guard let operation = DigitalHumanSessionLeaseOperationResult(json: object) else {
                    completion(.failure(ClientError.invalidJSONResponse))
                    return
                }
                completion(.success(operation))
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

    func acceptVoiceCloneQuality(
        userId: String,
        profileId voiceProfileId: String,
        completion: @escaping (Result<VoiceCloneProfileContract, Error>) -> Void
    ) {
        let path = "/voice/profiles/\(pathComponent(userId))/\(pathComponent(voiceProfileId))/quality-acceptance"
        requestJSON(path: path, method: .post, payload: ["accepted": true]) { result in
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

    func buildEchoContextPacket(
        userId: String,
        query: String,
        personaScope: String,
        digitalHumanId: String,
        lifecycleMode: DigitalHumanMode,
        viewerFamilyMemberID: String? = nil,
        completion: @escaping (Result<EchoContextPacket, Error>) -> Void
    ) {
        var payload: [String: Any] = [
            "userId": userId,
            "intent": "echo_chat",
            "query": query,
            "personaScope": personaScope,
            "digitalHumanId": digitalHumanId,
            "lifecycleMode": lifecycleMode.rawValue,
        ]
        if let viewerFamilyMemberID,
           !viewerFamilyMemberID.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            payload["viewerFamilyMemberID"] = viewerFamilyMemberID
        }
        requestJSON(path: "/context/build", method: .post, payload: payload) { result in
            switch result {
            case .success(let object):
                guard let packetJSON = object["contextPacket"] as? [String: Any],
                      let packet = EchoContextPacket(json: packetJSON) else {
                    completion(.failure(ClientError.invalidJSONResponse))
                    return
                }
                completion(.success(packet))
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
        requestJSON(
            path: "/auth/login",
            method: .post,
            payload: payload,
            authPolicy: .backendOnly,
            allowsRefresh: false
        ) { [weak self] result in
            guard let self else { return }
            switch result {
            case .success(let object):
                guard let user = object["user"] as? [String: Any],
                      let responseUserId = user["id"] as? String,
                      !responseUserId.isEmpty else {
                    self.authSessionStore.clear()
                    completion(.failure(ClientError.invalidJSONResponse))
                    return
                }
                if let auth = object["auth"] as? [String: Any],
                   auth["userId"] as? String != responseUserId {
                    self.authSessionStore.clear()
                    completion(.failure(ClientError.invalidJSONResponse))
                    return
                }
                do {
                    try self.adoptAuthSession(from: object)
                    completion(.success(object))
                } catch {
                    completion(.failure(error))
                }
            case .failure(let error):
                completion(.failure(error))
            }
        }
    }

    func logoutAuthSession() {
        guard let session = authSessionStore.currentSession else { return }
        requestJSON(
            path: "/auth/logout",
            method: .post,
            payload: ["refreshToken": session.refreshToken],
            authPolicy: .automatic,
            allowsRefresh: false
        ) { _ in }
        authSessionStore.clear(sessionId: session.sessionId)
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

    func dispatchDueTimeLetters(
        nowISO: String? = nil,
        limit: Int = 25,
        completion: @escaping (Result<[String: Any], Error>) -> Void
    ) {
        var payload: [String: Any] = ["limit": limit]
        if let nowISO, !nowISO.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            payload["now"] = nowISO
        }
        requestJSON(path: "/archive/time-letters/dispatch-due", method: .post, payload: payload, completion: completion)
    }

    func listMailboxLetters(userId: String, completion: @escaping (Result<[String: Any], Error>) -> Void) {
        requestJSON(path: "/mailbox/letters/\(pathComponent(userId))", method: .get, payload: nil, completion: completion)
    }

    func getTimeLetterDetail(
        ownerUserId: String,
        itemId: String,
        viewerUserId: String,
        nowISO: String? = nil,
        completion: @escaping (Result<[String: Any], Error>) -> Void
    ) {
        var path = "/archive/time-letters/\(pathComponent(ownerUserId))/\(pathComponent(itemId))/detail"
        var queryItems = [URLQueryItem(name: "viewerUserId", value: viewerUserId)]
        if let nowISO, !nowISO.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            queryItems.append(URLQueryItem(name: "now", value: nowISO))
        }
        var components = URLComponents()
        components.queryItems = queryItems
        if let query = components.percentEncodedQuery, !query.isEmpty {
            path += "?\(query)"
        }
        requestJSON(path: path, method: .get, payload: nil, completion: completion)
    }

    func markMailboxLetterRead(
        userId: String,
        letterId: String,
        readAtISO: String? = nil,
        completion: @escaping (Result<[String: Any], Error>) -> Void
    ) {
        var payload: [String: Any] = [:]
        if let readAtISO, !readAtISO.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            payload["readAt"] = readAtISO
        }
        requestJSON(
            path: "/mailbox/letters/\(pathComponent(userId))/\(pathComponent(letterId))/read",
            method: .post,
            payload: payload,
            completion: completion
        )
    }

    func archiveMailboxLetter(
        userId: String,
        letterId: String,
        archivedAtISO: String? = nil,
        completion: @escaping (Result<[String: Any], Error>) -> Void
    ) {
        var payload: [String: Any] = [:]
        if let archivedAtISO, !archivedAtISO.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            payload["archivedAt"] = archivedAtISO
        }
        requestJSON(
            path: "/mailbox/letters/\(pathComponent(userId))/\(pathComponent(letterId))/archive",
            method: .post,
            payload: payload,
            completion: completion
        )
    }

    func syncKnowledge(userId: String, graph: [String: Any], completion: @escaping (Result<[String: Any], Error>) -> Void) {
        requestJSON(path: "/kb/sync", method: .post, payload: ["userId": userId, "graph": graph], completion: completion)
    }

    func mutateKnowledge(
        userId: String,
        graph: [String: Any],
        operationId: String,
        baseRevision: Int,
        completion: @escaping (Result<[String: Any], Error>) -> Void
    ) {
        requestJSON(
            path: "/kb/mutations",
            method: .post,
            payload: [
                "userId": userId,
                "operationId": operationId,
                "baseRevision": baseRevision,
                "graph": graph,
            ],
            completion: completion
        )
    }

    func fetchKnowledgeChanges(
        userId: String,
        sinceRevision: Int,
        completion: @escaping (Result<[String: Any], Error>) -> Void
    ) {
        requestJSON(
            path: "/kb/changes/\(pathComponent(userId))?sinceRevision=\(max(0, sinceRevision))",
            method: .get,
            payload: nil,
            completion: completion
        )
    }

    func extractKnowledge(
        userId: String,
        transcript: String,
        existingSummary: String,
        sessionId: Int,
        completion: @escaping (Result<KBExtractionResult, Error>) -> Void
    ) {
        requestJSON(
            path: "/kb/extract",
            method: .post,
            payload: [
                "userId": userId,
                "transcript": transcript,
                "existingSummary": existingSummary,
                "sessionId": sessionId,
                "boundaryAcknowledged": true,
                "privacyMetadata": [
                    "scope": "generationAllowed",
                    "sourceRefs": [
                        [
                            "kind": "conversationSession",
                            "id": "session-\(sessionId)",
                            "title": "对话来源",
                        ],
                    ],
                ],
            ]
        ) { result in
            switch result {
            case .success(let object):
                guard let extraction = object["extraction"] as? [String: Any],
                      JSONSerialization.isValidJSONObject(extraction),
                      let data = try? JSONSerialization.data(withJSONObject: extraction),
                      let decoded = try? JSONDecoder().decode(KBExtractionResult.self, from: data) else {
                    completion(.failure(ClientError.invalidJSONResponse))
                    return
                }
                completion(.success(decoded))
            case .failure(let error):
                completion(.failure(error))
            }
        }
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
        authPolicy: RequestAuthPolicy = .automatic,
        allowsRefresh: Bool = true,
        completion: @escaping (Result<[String: Any], Error>) -> Void
    ) {
        let url = "\(baseURL)\(path)"
        let requestHeaders = authPolicy == .automatic ? authHeaders : authHeaders(for: authPolicy)
        AF.request(url, method: method, parameters: payload, encoding: JSONEncoding.default, headers: requestHeaders)
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
                    if statusCode == 401,
                       allowsRefresh,
                       authPolicy == .automatic,
                       self.authSessionStore.currentSession != nil {
                        self.refreshAuthSession { refreshed in
                            if refreshed {
                                self.requestJSON(
                                    path: path,
                                    method: method,
                                    payload: payload,
                                    authPolicy: authPolicy,
                                    allowsRefresh: false,
                                    completion: completion
                                )
                            } else {
                                let detail = Self.backendErrorMessage(from: response.data)
                                    ?? "登录状态已失效，请重新登录"
                                completion(.failure(ClientError.backendError(
                                    statusCode: statusCode,
                                    detail: detail
                                )))
                            }
                        }
                        return
                    }
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

    @discardableResult
    private func adoptAuthSession(from object: [String: Any]) throws -> Bool {
        guard let authObject = object["auth"] else {
            authSessionStore.clear()
            return false
        }
        guard let authJSON = authObject as? [String: Any],
              let session = BackendAuthSessionContract(json: authJSON) else {
            throw ClientError.invalidJSONResponse
        }
        if let user = object["user"] as? [String: Any],
           let responseUserId = user["id"] as? String,
           session.userId != responseUserId {
            throw ClientError.invalidJSONResponse
        }
        try authSessionStore.save(session)
        return true
    }

    private func refreshAuthSession(completion: @escaping (Bool) -> Void) {
        authRefreshQueue.async {
            self.authRefreshWaiters.append(completion)
            guard !self.isAuthRefreshInFlight else { return }
            guard let currentSession = self.authSessionStore.currentSession else {
                self.finishAuthRefresh(success: false)
                return
            }
            self.isAuthRefreshInFlight = true
            self.requestJSON(
                path: "/auth/refresh",
                method: .post,
                payload: ["refreshToken": currentSession.refreshToken],
                authPolicy: .backendOnly,
                allowsRefresh: false
            ) { result in
                let refreshed: Bool
                switch result {
                case .success(let object):
                    refreshed = (try? self.adoptAuthSession(from: object)) == true
                case .failure:
                    refreshed = false
                }
                if !refreshed {
                    self.authSessionStore.clear(sessionId: currentSession.sessionId)
                }
                self.authRefreshQueue.async {
                    self.finishAuthRefresh(success: refreshed)
                }
            }
        }
    }

    private func finishAuthRefresh(success: Bool) {
        let waiters = authRefreshWaiters
        authRefreshWaiters.removeAll()
        isAuthRefreshInFlight = false
        DispatchQueue.main.async {
            waiters.forEach { $0(success) }
        }
    }

    private func validatedDigitalHumanLeasePath(_ candidate: String, fallback: String) -> String {
        guard candidate.hasPrefix("/digital-human/sessions/"),
              !candidate.contains("?"),
              !candidate.contains("#") else {
            return fallback
        }
        return candidate
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
        authHeaders(for: .automatic)
    }

    private func authHeaders(for policy: RequestAuthPolicy) -> HTTPHeaders? {
        var values: [String: String] = [:]
        if let apiToken {
            values["X-DreamJourney-Api-Token"] = apiToken
        }

        if policy == .automatic, let session = authSessionStore.currentSession {
            values["Authorization"] = "Bearer \(session.accessToken)"
            values["X-DreamJourney-User-Id"] = session.userId
        } else if policy == .automatic, let apiToken {
            values["Authorization"] = "Bearer \(apiToken)"
        }
        return values.isEmpty ? nil : HTTPHeaders(values)
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
