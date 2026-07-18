import Foundation
import Alamofire
import CryptoKit

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
    let axisSnapshot: RuntimeCapabilitySnapshot

    var canRunVisionAnalysis: Bool {
        supportsVision && axisSnapshot.isProviderOperational
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

    init(json: [String: Any]?, axisSnapshot: RuntimeCapabilitySnapshot? = nil) {
        enabled = json?["enabled"] as? Bool ?? false
        endpoint = json?["endpoint"] as? String ?? "/archive/image-analysis"
        provider = json?["provider"] as? String ?? "unknown"
        supportsVision = json?["supportsVision"] as? Bool ?? false
        fallbackMode = json?["fallbackMode"] as? String ?? "retryableFailure"
        statuses = json?["statuses"] as? [String] ?? []
        self.axisSnapshot = axisSnapshot ?? RuntimeCapabilitySnapshot.conservativeLegacy(
            capability: RuntimeCapabilityID.archiveImageAnalysis.rawValue,
            implemented: true,
            enabled: enabled,
            providerReady: enabled && supportsVision,
            provider: provider,
            fallbackMode: fallbackMode
        )
    }
}

struct BackendReleasePolicyFeatureDecision: Equatable {
    let feature: String
    let enabled: Bool
    let releaseVisible: Bool
    let audience: String
    let cohort: String
    let requiredGates: [String]
    let reason: String

    init?(_ json: [String: Any]) {
        guard let feature = json["feature"] as? String,
              let enabled = json["enabled"] as? Bool,
              let releaseVisible = json["releaseVisible"] as? Bool,
              let audience = json["audience"] as? String,
              let cohort = json["cohort"] as? String,
              let requiredGates = json["requiredGates"] as? [String],
              let reason = json["reason"] as? String else {
            return nil
        }
        self.feature = feature
        self.enabled = enabled
        self.releaseVisible = releaseVisible
        self.audience = audience
        self.cohort = cohort
        self.requiredGates = requiredGates
        self.reason = reason
    }

    private init(feature: String, reason: String) {
        self.feature = feature
        enabled = false
        releaseVisible = false
        audience = "unknown"
        cohort = "unknown"
        requiredGates = ["G0"]
        self.reason = reason
    }

    static func failClosed(feature: String, reason: String) -> BackendReleasePolicyFeatureDecision {
        BackendReleasePolicyFeatureDecision(feature: feature, reason: reason)
    }
}

enum BackendReleasePolicyContractError: LocalizedError {
    case malformedSnapshot
    case accountScopeChanged

    var errorDescription: String? {
        switch self {
        case .malformedSnapshot:
            return "发布策略合同无效，相关可选功能已保持关闭"
        case .accountScopeChanged:
            return "账号已切换，旧发布策略响应已丢弃"
        }
    }
}

struct BackendReleasePolicySnapshot {
    let schemaVersion: Int
    let policyVersion: String
    let policyRevision: Int
    let issuedAt: Date
    let expiresAt: Date
    let minClient: Int
    let emergencyRevision: Int
    let audience: String
    let cohort: String
    let source: String
    let shadowMode: Bool
    let snapshotDecision: String
    let features: [BackendReleasePolicyFeatureDecision]

    var isExpired: Bool {
        Date() >= expiresAt
    }

    init(json: [String: Any]) throws {
        guard let schemaVersion = Self.intValue(json["schemaVersion"]),
              schemaVersion == 1,
              let policyVersion = json["policyVersion"] as? String,
              let policyRevision = Self.intValue(json["policyRevision"]),
              let issuedAtValue = json["issuedAt"] as? String,
              let issuedAt = BackendDateParser.date(from: issuedAtValue),
              let expiresAtValue = json["expiresAt"] as? String,
              let expiresAt = BackendDateParser.date(from: expiresAtValue),
              let minClient = Self.intValue(json["minClient"]),
              let emergencyRevision = Self.intValue(json["emergencyRevision"]),
              let audience = json["audience"] as? String,
              let cohort = json["cohort"] as? String,
              let source = json["source"] as? String,
              source == "server",
              let shadowMode = json["shadowMode"] as? Bool,
              let snapshotDecision = json["snapshotDecision"] as? String,
              let rawFeatures = json["features"] as? [[String: Any]] else {
            throw BackendReleasePolicyContractError.malformedSnapshot
        }
        let features = rawFeatures.compactMap(BackendReleasePolicyFeatureDecision.init)
        guard features.count == rawFeatures.count else {
            throw BackendReleasePolicyContractError.malformedSnapshot
        }
        self.schemaVersion = schemaVersion
        self.policyVersion = policyVersion
        self.policyRevision = policyRevision
        self.issuedAt = issuedAt
        self.expiresAt = expiresAt
        self.minClient = minClient
        self.emergencyRevision = emergencyRevision
        self.audience = audience
        self.cohort = cohort
        self.source = source
        self.shadowMode = shadowMode
        self.snapshotDecision = snapshotDecision
        self.features = features
    }

    func decision(for feature: DJFeature) -> BackendReleasePolicyFeatureDecision {
        guard !isExpired else {
            return .failClosed(feature: feature.rawValue, reason: "expiredPolicy")
        }
        return features.first(where: { $0.feature == feature.rawValue })
            ?? .failClosed(feature: feature.rawValue, reason: "unknownFeature")
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

struct BackendCachedReleasePolicyEvaluation {
    let state: ReleasePolicyCacheState
    let accessMode: ReleasePolicyAccessMode
    let reason: String
    let policyVersion: String?
    let policyRevision: Int?
    let emergencyRevision: Int?
    let ageSeconds: TimeInterval?
    let snapshot: BackendReleasePolicySnapshot?

    func decision(for feature: DJFeature) -> BackendReleasePolicyFeatureDecision {
        guard accessMode == .useCachedPolicy, let snapshot else {
            return .failClosed(feature: feature.rawValue, reason: reason)
        }
        return snapshot.decision(for: feature)
    }

    init(cache: ReleasePolicyCacheEvaluation, risk: ReleasePolicyRiskClass) {
        policyVersion = cache.policyVersion
        policyRevision = cache.policyRevision
        emergencyRevision = cache.emergencyRevision
        ageSeconds = cache.ageSeconds

        guard cache.accessMode == .useCachedPolicy else {
            state = cache.state
            accessMode = cache.accessMode
            reason = cache.reason
            snapshot = nil
            return
        }
        guard let payload = cache.payload,
              let json = try? JSONSerialization.jsonObject(with: payload) as? [String: Any],
              let parsedSnapshot = try? BackendReleasePolicySnapshot(json: json) else {
            state = .corrupt
            accessMode = risk.unavailableAccessMode
            reason = "cachedPolicyContractInvalid"
            snapshot = nil
            return
        }

        state = .fresh
        accessMode = .useCachedPolicy
        reason = cache.reason
        snapshot = parsedSnapshot
    }
}

extension BackendCachedReleasePolicyEvaluation {
    func featureGatePolicySnapshot(for feature: DJFeature) -> FeatureGatePolicySnapshot {
        let featureDecision = decision(for: feature)
        return FeatureGatePolicySnapshot(
            accessMode: accessMode,
            policyVersion: policyVersion,
            policyRevision: policyRevision,
            emergencyRevision: emergencyRevision,
            expiresAt: snapshot?.expiresAt,
            featureEnabled: featureDecision.enabled,
            releaseVisible: featureDecision.releaseVisible,
            reason: featureDecision.reason
        )
    }
}

final class FeatureGateService {
    static let shared = FeatureGateService()

    private let evaluator = FeatureGateEvaluator()
    private let lock = NSLock()
    private var routeDecisions: [DJFeature: FeatureDecision] = [:]
    private var latestDecisions: [DJFeature: FeatureDecision] = [:]

    private init() {}

    var clientBuild: Int {
        let rawValue = Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String
        return max(1, Int(rawValue ?? "") ?? 1)
    }

    func refreshPolicy(completion: ((Result<BackendReleasePolicySnapshot, Error>) -> Void)? = nil) {
        let cached = DreamJourneyBackendClient.shared.cachedReleasePolicyEvaluation(
            risk: .futureBeta,
            clientBuild: clientBuild
        )
        DreamJourneyBackendClient.shared.fetchReleasePolicy(
            clientBuild: clientBuild,
            knownPolicyRevision: cached.policyRevision ?? 0
        ) { result in
            completion?(result)
        }
    }

    @discardableResult
    func captureRoute(
        feature: DJFeature,
        risk: ReleasePolicyRiskClass? = nil,
        localEnabled: Bool? = nil,
        qaSyntheticOverride: Bool = false
    ) -> FeatureDecision {
        let resolvedRisk = risk ?? riskClass(for: feature)
        let decision = evaluator.capture(
            feature: feature,
            risk: resolvedRisk,
            purpose: .route,
            localEnabled: localEnabled ?? FeatureFlagService.shared.isEnabled(feature),
            qaSyntheticOverride: Self.qaOverrideAllowed(qaSyntheticOverride),
            accountGeneration: accountGeneration,
            policy: currentPolicy(for: feature, risk: resolvedRisk)
        )
        lock.lock()
        routeDecisions[feature] = decision
        latestDecisions[feature] = decision
        lock.unlock()
        return decision
    }

    func isRouteAllowed(
        _ feature: DJFeature,
        risk: ReleasePolicyRiskClass? = nil,
        localEnabled: Bool? = nil,
        qaSyntheticOverride: Bool = false
    ) -> Bool {
        captureRoute(
            feature: feature,
            risk: risk,
            localEnabled: localEnabled,
            qaSyntheticOverride: qaSyntheticOverride
        ).allowed
    }

    func requestDecision(for feature: DJFeature) -> FeatureDecision {
        let risk = riskClass(for: feature)
        let generation = accountGeneration
        let localEnabled = FeatureFlagService.shared.isEnabled(feature)
        let captured: FeatureDecision?
        lock.lock()
        captured = routeDecisions[feature]
        lock.unlock()

        let decision: FeatureDecision
        if let captured, captured.accountGeneration == generation {
            decision = evaluator.revalidateForRequest(
                captured: captured,
                localEnabled: localEnabled,
                accountGeneration: generation,
                currentPolicy: currentPolicy(for: feature, risk: risk)
            )
        } else {
            decision = evaluator.capture(
                feature: feature,
                risk: risk,
                purpose: .request,
                localEnabled: localEnabled,
                qaSyntheticOverride: false,
                accountGeneration: generation,
                policy: currentPolicy(for: feature, risk: risk)
            )
        }
        storeLatest(decision)
        return decision
    }

    func revalidateRequest(_ captured: FeatureDecision) -> FeatureDecision {
        let decision = evaluator.revalidateForRequest(
            captured: captured,
            localEnabled: FeatureFlagService.shared.isEnabled(captured.feature),
            accountGeneration: accountGeneration,
            currentPolicy: currentPolicy(for: captured.feature, risk: riskClass(for: captured.feature))
        )
        storeLatest(decision)
        return decision
    }

    func qaEvidenceSnapshot(features: [DJFeature]) -> [FeatureDecisionEvidenceSummary] {
        lock.lock()
        let decisions = features.compactMap { latestDecisions[$0] }
        lock.unlock()
        return decisions.map(FeatureDecisionEvidenceSummary.init(decision:))
    }

    func invalidateCapturedRoutes() {
        lock.lock()
        routeDecisions.removeAll()
        latestDecisions.removeAll()
        lock.unlock()
    }

    func featureForRequest(
        path: String,
        method: HTTPMethod,
        payload: [String: Any]?
    ) -> DJFeature? {
        let normalizedPath = path.split(separator: "?", maxSplits: 1).first.map(String.init) ?? path
        if normalizedPath.hasPrefix("/digital-human/") { return .digitalHumanLivePanel }
        if normalizedPath.hasPrefix("/voice/") || normalizedPath == "/tts" { return .voiceCloneShell }
        if normalizedPath.hasPrefix("/family/") { return .familyManagement }
        if normalizedPath.hasPrefix("/care/") { return .careDashboard }
        if normalizedPath.hasPrefix("/mailbox/letters")
            || normalizedPath.hasPrefix("/archive/time-letters/") {
            return .timeLetters
        }
        if normalizedPath == "/profile" { return .profileSettings }
        if normalizedPath == "/context/build"
            || normalizedPath.hasPrefix("/echo/delayed-replies") {
            return .echoTextInput
        }
        if normalizedPath == "/archive/image-analysis" { return .archiveLocalAnalysis }
        if normalizedPath == "/archive/photos" { return .archiveRemoteFetch }
        if normalizedPath == "/auth/password" { return .accountPasswordChange }
        if normalizedPath == "/auth/delete" || normalizedPath == "/auth/restore" {
            return .accountDeletion
        }
        if normalizedPath == "/archive/media/upload-intent" {
            return archiveMediaFeature(payload)
        }
        if normalizedPath == "/archive/items" {
            return archiveItemFeature(payload)
        }
        if method == .get, normalizedPath.hasPrefix("/archive/items/") {
            return .archiveRemoteFetch
        }
        return nil
    }

    func metadataHeaders(for decision: FeatureDecision) -> [String: String] {
        var headers: [String: String] = [
            "X-DreamJourney-Feature": decision.feature.rawValue,
            "X-DreamJourney-Feature-Decision-Id": decision.decisionId,
            "X-DreamJourney-Feature-Allowed": decision.allowed ? "true" : "false",
            "X-DreamJourney-Account-Generation": decision.accountGeneration,
            "X-DreamJourney-Client-Build": String(clientBuild),
            "X-DreamJourney-Policy-Audience": "owner",
            "X-DreamJourney-Policy-Cohort": "closedPilotAdultSelf",
        ]
        if let policyVersion = decision.policyVersion {
            headers["X-DreamJourney-Policy-Version"] = policyVersion
        }
        if let policyRevision = decision.policyRevision {
            headers["X-DreamJourney-Policy-Revision"] = String(policyRevision)
        }
        if let emergencyRevision = decision.emergencyRevision {
            headers["X-DreamJourney-Emergency-Revision"] = String(emergencyRevision)
        }
        return headers
    }

    private var accountGeneration: String {
        let source = BackendAuthSessionStore.shared.currentSession?.sessionId
            ?? UserManager.shared.currentUser?.id
            ?? "anonymous"
        return SHA256.hash(data: Data(source.utf8))
            .map { String(format: "%02x", $0) }
            .joined()
            .prefix(24)
            .description
    }

    private func currentPolicy(
        for feature: DJFeature,
        risk: ReleasePolicyRiskClass
    ) -> FeatureGatePolicySnapshot {
        DreamJourneyBackendClient.shared.cachedReleasePolicyEvaluation(
            risk: risk,
            clientBuild: clientBuild
        ).featureGatePolicySnapshot(for: feature)
    }

    private func storeLatest(_ decision: FeatureDecision) {
        lock.lock()
        latestDecisions[decision.feature] = decision
        lock.unlock()
    }

    private func riskClass(for feature: DJFeature) -> ReleasePolicyRiskClass {
        switch feature {
        case .echoTextInput, .profileSettings, .legalCenter, .accountDeletion:
            return .ownerTextCore
        case .voiceCloneShell, .digitalHumanLivePanel, .archiveRemoteFetch:
            return .providerEffect
        default:
            return .futureBeta
        }
    }

    private func archiveMediaFeature(_ payload: [String: Any]?) -> DJFeature {
        let rawKind = payload?["mediaType"] ?? payload?["kind"] ?? payload?["assetKind"]
        switch String(describing: rawKind ?? "").lowercased() {
        case "audio", "voice", "recording":
            return .archiveAudioUpload
        case "video", "movie":
            return .archiveVideoUpload
        default:
            return .archiveRemoteFetch
        }
    }

    private func archiveItemFeature(_ payload: [String: Any]?) -> DJFeature? {
        let metadata = payload?["metadata"] as? [String: Any]
        let rawKind = payload?["kind"]
            ?? payload?["type"]
            ?? payload?["assetKind"]
            ?? metadata?["kind"]
            ?? metadata?["assetKind"]
        switch String(describing: rawKind ?? "").lowercased() {
        case "timeletter", "time_letter", "letter":
            return .timeLetters
        case "audio", "voice", "recording":
            return .archiveAudioUpload
        case "video", "movie":
            return .archiveVideoUpload
        default:
            return nil
        }
    }

    private static func qaOverrideAllowed(_ requested: Bool) -> Bool {
        #if DEBUG || UI_QA_SIMULATOR
        return requested
        #else
        return false
        #endif
    }
}

struct BackendReleasePolicyRuntimeDescriptor {
    let endpoint: String
    let schemaVersion: Int
    let policyVersion: String
    let policyRevision: Int
    let ttlSeconds: Int
    let minClient: Int
    let emergencyRevision: Int
    let source: String
    let shadowMode: Bool
    let commandMode: String
    let rolloutContractVersion: Int
    let runtimeContractVersion: Int
    let canaryFeatures: [String]
    let killSwitchFeatures: [String]

    init(json: [String: Any]?) {
        endpoint = json?["endpoint"] as? String ?? "/v2/release-policy"
        schemaVersion = Self.intValue(json?["schemaVersion"]) ?? 0
        policyVersion = json?["policyVersion"] as? String ?? "unknown"
        policyRevision = Self.intValue(json?["policyRevision"]) ?? 0
        ttlSeconds = Self.intValue(json?["ttlSeconds"]) ?? 0
        minClient = Self.intValue(json?["minClient"]) ?? Int.max
        emergencyRevision = Self.intValue(json?["emergencyRevision"]) ?? 0
        source = json?["source"] as? String ?? "unknown"
        shadowMode = json?["shadowMode"] as? Bool ?? true
        commandMode = json?["commandMode"] as? String ?? (shadowMode ? "observe" : "enforce")
        rolloutContractVersion = Self.intValue(json?["rolloutContractVersion"]) ?? 0
        runtimeContractVersion = Self.intValue(json?["runtimeContractVersion"]) ?? 0
        canaryFeatures = json?["canaryFeatures"] as? [String] ?? []
        killSwitchFeatures = json?["killSwitchFeatures"] as? [String] ?? []
    }

    private static func intValue(_ value: Any?) -> Int? {
        if let value = value as? Int { return value }
        if let value = value as? NSNumber { return value.intValue }
        if let value = value as? String { return Int(value) }
        return nil
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
    let axisSnapshot: RuntimeCapabilitySnapshot

    var canSynthesize: Bool {
        axisSnapshot.isProviderOperational
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

    init(json: [String: Any]?, axisSnapshot: RuntimeCapabilitySnapshot? = nil) {
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
        self.axisSnapshot = axisSnapshot ?? RuntimeCapabilitySnapshot.conservativeLegacy(
            capability: RuntimeCapabilityID.voiceCloneShell.rawValue,
            implemented: true,
            enabled: enabled,
            providerReady: enabled && synthesisProviderReady,
            provider: provider,
            fallbackMode: fallbackMode
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
    let capabilitySnapshotSchemaVersion: Int
    let capabilitySnapshots: [String: RuntimeCapabilitySnapshot]
    let realtimeTokenAvailable: Bool
    let voiceRuntimeConfigEndpoint: String?
    let fallbackMode: String?
    let archiveMediaUploadIntentAvailable: Bool
    let archiveMediaUploadIntentEndpoint: String?
    let archiveMedia: ArchiveMediaRuntimeCapability
    let archiveImageAnalysis: ArchiveImageAnalysisRuntimeCapability
    let voiceClone: VoiceCloneRuntimeCapability
    let digitalHuman: DigitalHumanRuntimeCapability
    let releasePolicy: BackendReleasePolicyRuntimeDescriptor
    let recovery: BackendRecoveryRuntimePolicy
    let identityChallenge: BackendIdentityChallengeCapability

    init(json: [String: Any]) {
        capabilitySnapshotSchemaVersion = Self.intValue(json["capabilitySnapshotSchemaVersion"]) ?? 0
        let rawSnapshots = json["capabilitySnapshots"] as? [String: Any] ?? [:]
        let decodedSnapshots: [String: RuntimeCapabilitySnapshot] = rawSnapshots.reduce(into: [:]) { result, entry in
            guard let value = entry.value as? [String: Any],
                  let snapshot = RuntimeCapabilitySnapshot(json: value),
                  snapshot.capability == entry.key else {
                return
            }
            result[entry.key] = snapshot
        }
        capabilitySnapshots = decodedSnapshots
        let capabilities = json["capabilities"] as? [String: Any]
        let voice = json["voice"] as? [String: Any]
        let fallback = voice?["fallback"] as? [String: Any]
        let archive = json["archive"] as? [String: Any]
        let archiveImageAnalysis = json["archiveImageAnalysis"] as? [String: Any]
        let voiceClone = json["voiceClone"] as? [String: Any]
        let digitalHuman = json["digitalHuman"] as? [String: Any]
        let releasePolicy = json["releasePolicy"] as? [String: Any]
        let recovery = json["recovery"] as? [String: Any]
        let auth = json["auth"] as? [String: Any]
        realtimeTokenAvailable = capabilities?["realtimeToken"] as? Bool ?? false
        voiceRuntimeConfigEndpoint = voice?["runtimeConfigEndpoint"] as? String
        fallbackMode = fallback?["mode"] as? String
        archiveMediaUploadIntentAvailable = capabilities?["archiveMediaUploadIntent"] as? Bool ?? false
        archiveMediaUploadIntentEndpoint = archive?["uploadIntentEndpoint"] as? String
        self.archiveMedia = ArchiveMediaRuntimeCapability(json: archive, capabilities: capabilities)
        self.archiveImageAnalysis = ArchiveImageAnalysisRuntimeCapability(
            json: archiveImageAnalysis,
            axisSnapshot: decodedSnapshots[RuntimeCapabilityID.archiveImageAnalysis.rawValue]
        )
        self.voiceClone = VoiceCloneRuntimeCapability(
            json: voiceClone,
            axisSnapshot: decodedSnapshots[RuntimeCapabilityID.voiceCloneShell.rawValue]
        )
        self.digitalHuman = DigitalHumanRuntimeCapability(
            json: digitalHuman,
            capabilities: capabilities,
            axisSnapshot: decodedSnapshots[RuntimeCapabilityID.digitalHumanLivePanel.rawValue]
        )
        self.releasePolicy = BackendReleasePolicyRuntimeDescriptor(json: releasePolicy)
        self.recovery = BackendRecoveryRuntimePolicy(json: recovery)
        identityChallenge = BackendIdentityChallengeCapability(
            json: auth?["identityChallenge"] as? [String: Any]
        )
    }

    private static func intValue(_ value: Any?) -> Int? {
        if let value = value as? Int { return value }
        if let value = value as? NSNumber { return value.intValue }
        if let value = value as? String { return Int(value) }
        return nil
    }
}

struct DigitalHumanRuntimeCapability {
    private static let scopedSessionRequirements: Set<String> = ["scope", "ttl", "audience", "revocation"]

    let enabled: Bool
    let provider: String
    let providerMode: String
    let realProviderReady: Bool
    let sdkProvider: String
    let sdkAuthMode: String
    let credentialMode: String
    let accessPath: String
    let mobileDirectAllowed: Bool
    let brokerStatus: String
    let decision: String?
    let decisionReasonCode: String?
    let requiredCredentialProperties: [String]
    let verifiedCredentialProperties: [String]
    let missingCredentialProperties: [String]
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
    let axisSnapshot: RuntimeCapabilitySnapshot

    var canCreateMockSession: Bool {
        enabled && provider == "tencent" && providerMode == "mockContract"
    }

    var allowsScopedMobileSession: Bool {
        axisSnapshot.isProviderOperational
            && credentialMode == "scopedSessionCredential"
            && accessPath == "scopedSessionCredential"
            && mobileDirectAllowed
            && brokerStatus == "verified"
            && Set(requiredCredentialProperties) == Self.scopedSessionRequirements
            && Set(verifiedCredentialProperties) == Self.scopedSessionRequirements
            && missingCredentialProperties.isEmpty
            && contractVersion >= 4
    }

    init(
        json: [String: Any]?,
        capabilities: [String: Any]?,
        axisSnapshot: RuntimeCapabilitySnapshot? = nil
    ) {
        enabled = capabilities?["digitalHumanSession"] as? Bool ?? json?["enabled"] as? Bool ?? false
        provider = json?["provider"] as? String ?? "unknown"
        providerMode = json?["providerMode"] as? String ?? "unknown"
        realProviderReady = json?["realProviderReady"] as? Bool ?? false
        sdkProvider = json?["sdkProvider"] as? String ?? ""
        sdkAuthMode = json?["sdkAuthMode"] as? String ?? ""
        credentialMode = json?["credentialMode"] as? String ?? "blockedStaticCredential"
        accessPath = json?["accessPath"] as? String ?? "textFallback"
        mobileDirectAllowed = json?["mobileDirectAllowed"] as? Bool ?? false
        brokerStatus = json?["brokerStatus"] as? String ?? "unknown"
        let decisionReceipt = json?["decisionReceipt"] as? [String: Any]
        decision = decisionReceipt?["decision"] as? String
        decisionReasonCode = decisionReceipt?["reasonCode"] as? String
        requiredCredentialProperties = decisionReceipt?["requiredProperties"] as? [String] ?? []
        verifiedCredentialProperties = decisionReceipt?["verifiedProperties"] as? [String] ?? []
        missingCredentialProperties = decisionReceipt?["missingProperties"] as? [String] ?? []
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
        self.axisSnapshot = axisSnapshot ?? RuntimeCapabilitySnapshot.conservativeLegacy(
            capability: RuntimeCapabilityID.digitalHumanLivePanel.rawValue,
            implemented: true,
            enabled: enabled,
            providerReady: enabled && realProviderReady,
            provider: provider,
            fallbackMode: fallbackMode
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
    let scopedSessionReady: Bool

    var isUsableScopedSessionCredential: Bool {
        mode == "scopedSessionCredential"
            && scopedSessionReady
            && (expiresAt.map { $0 > Date() } ?? false)
    }

    init(json: [String: Any]?) {
        mode = json?["mode"] as? String ?? "unknown"
        scopedSessionReady = json?["scopedSessionReady"] as? Bool ?? false
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

enum AccountDeletionAcceptanceContractError: LocalizedError {
    case incompleteAccessFirstReceipt

    var errorDescription: String? {
        switch self {
        case .incompleteAccessFirstReceipt:
            return "注销回执未确认访问暂停与会话撤销，本地数据尚未清理"
        }
    }
}

struct AccountDeletionAcceptanceContract {
    let contractVersion: Int
    let status: String
    let deletionState: String
    let accessState: String
    let authEpoch: Int
    let providerCapabilityState: String
    let sessionRevocationScope: String
    let accessRevocationEventId: String
    let accessRevocationStatus: String

    var isAccessFirstAccepted: Bool {
        status == "softDeleted"
            && deletionState == "softDeleted"
            && accessState == "suspended_restorable"
            && authEpoch > 0
            && providerCapabilityState == "revoked"
            && sessionRevocationScope == "allDevices"
            && !accessRevocationEventId.isEmpty
            && ["pending", "dispatched"].contains(accessRevocationStatus)
    }

    init(json: [String: Any]) throws {
        guard let status = json["status"] as? String,
              let deletion = json["deletion"] as? [String: Any],
              let deletionState = deletion["deletionState"] as? String,
              let accessState = deletion["accessState"] as? String,
              let authEpoch = Self.intValue(deletion["authEpoch"]),
              let providerCapabilityState = deletion["providerCapabilityState"] as? String,
              let sessionRevocation = json["sessionRevocation"] as? [String: Any],
              let sessionRevocationScope = sessionRevocation["scope"] as? String,
              let accessRevocation = json["accessRevocation"] as? [String: Any],
              let accessRevocationEventId = accessRevocation["eventId"] as? String,
              let accessRevocationEventType = accessRevocation["eventType"] as? String,
              let accessRevocationStatus = accessRevocation["status"] as? String,
              status == "softDeleted",
              deletionState == "softDeleted",
              accessState == "suspended_restorable",
              authEpoch > 0,
              providerCapabilityState == "revoked",
              sessionRevocationScope == "allDevices",
              !accessRevocationEventId.isEmpty,
              accessRevocationEventType == "RightsAccessRevoked",
              ["pending", "dispatched"].contains(accessRevocationStatus) else {
            throw AccountDeletionAcceptanceContractError.incompleteAccessFirstReceipt
        }

        contractVersion = Self.intValue(json["contractVersion"]) ?? 1
        self.status = status
        self.deletionState = deletionState
        self.accessState = accessState
        self.authEpoch = authEpoch
        self.providerCapabilityState = providerCapabilityState
        self.sessionRevocationScope = sessionRevocationScope
        self.accessRevocationEventId = accessRevocationEventId
        self.accessRevocationStatus = accessRevocationStatus
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

struct DigitalHumanSessionContract {
    #if DEBUG || UI_QA_SIMULATOR
    private static let localAssetVirtualmanKeyEnvironmentKey = "DREAMJOURNEY_DIGITAL_HUMAN_ASSET_VIRTUALMAN_KEY"
    private static let localAssetVirtualmanKeyOverrideArgument = "DJUseLocalDigitalHumanAssetOverride"
    #endif

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
        #if DEBUG || UI_QA_SIMULATOR
        let raw = ProcessInfo.processInfo.environment[localAssetVirtualmanKeyEnvironmentKey]
        let value = raw?.trimmingCharacters(in: .whitespacesAndNewlines)
        return value?.isEmpty == false ? value : nil
        #else
        return nil
        #endif
    }

    private static var shouldUseLocalAssetVirtualmanKeyOverride: Bool {
        #if DEBUG || UI_QA_SIMULATOR
        ProcessInfo.processInfo.arguments.contains(localAssetVirtualmanKeyOverrideArgument)
        #else
        false
        #endif
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
    let status: String
    let credentialMode: String
    let accessPath: String
    let mobileDirectAllowed: Bool
    let brokerStatus: String
    let providerReady: Bool
    let releaseVisible: Bool
    let retryable: Bool
    let decision: String?
    let decisionReasonCode: String?
    let requiredCredentialProperties: [String]
    let verifiedCredentialProperties: [String]
    let missingCredentialProperties: [String]
    let fallbackMode: String?
    let contractVersion: Int

    var isBlocked: Bool {
        status == "blocked"
            || credentialMode == "blockedStaticCredential"
            || !providerReady
            || !mobileDirectAllowed
            || accessPath != "scopedSessionCredential"
    }

    init?(json: [String: Any]) {
        guard let status = json["status"] as? String,
              let credentialMode = json["credentialMode"] as? String else {
            return nil
        }
        self.status = status
        self.credentialMode = credentialMode
        self.accessPath = json["accessPath"] as? String ?? "backendProxyOrText"
        self.mobileDirectAllowed = json["mobileDirectAllowed"] as? Bool ?? false
        self.brokerStatus = json["brokerStatus"] as? String ?? "unknown"
        self.providerReady = json["providerReady"] as? Bool ?? false
        self.releaseVisible = json["releaseVisible"] as? Bool ?? false
        self.retryable = json["retryable"] as? Bool ?? false
        let decisionReceipt = json["decisionReceipt"] as? [String: Any]
        self.decision = decisionReceipt?["decision"] as? String
        self.decisionReasonCode = decisionReceipt?["reasonCode"] as? String
        self.requiredCredentialProperties = decisionReceipt?["requiredProperties"] as? [String] ?? []
        self.verifiedCredentialProperties = decisionReceipt?["verifiedProperties"] as? [String] ?? []
        self.missingCredentialProperties = decisionReceipt?["missingProperties"] as? [String] ?? []
        let fallback = json["fallback"] as? [String: Any]
        self.fallbackMode = fallback?["mode"] as? String
        self.contractVersion = Self.intValue(json["contractVersion"]) ?? 1
    }

    private static func intValue(_ value: Any?) -> Int? {
        if let value = value as? Int { return value }
        if let value = value as? NSNumber { return value.intValue }
        if let value = value as? String { return Int(value) }
        return nil
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
        self.providerLogId = json["providerLogIdHash"] as? String
        self.providerRequestId = json["providerRequestIdHash"] as? String
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
    let personaScope: String?
    let digitalHumanId: String?
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
        let persona = json["persona"] as? [String: Any]
        self.personaScope = Self.nonEmptyString(persona?["personaScope"])
            ?? Self.nonEmptyString(json["personaScope"])
        self.digitalHumanId = Self.nonEmptyString(persona?["digitalHumanId"])
            ?? Self.nonEmptyString(json["digitalHumanId"])

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

    private static func nonEmptyString(_ value: Any?) -> String? {
        guard let value = value as? String else {
            return nil
        }
        let normalized = value.trimmingCharacters(in: .whitespacesAndNewlines)
        return normalized.isEmpty ? nil : normalized
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
    let featurePolicyDecisions: [FeatureDecisionEvidenceSummary]?
    let source: String

    init(
        trace: EchoTraceRecord?,
        ownerUserId: String? = nil,
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
        featurePolicyDecisions: [FeatureDecisionEvidenceSummary] = [],
        source: String
    ) {
        self.schemaVersion = 1
        let uniqueSuffix = String(UUID().uuidString.replacingOccurrences(of: "-", with: "").prefix(24))
        self.snapshotId = "echo_diag_" + uniqueSuffix
        let explicitOwnerUserId = EchoTraceOwnerScope.normalizedOwnerUserId(ownerUserId)
        let traceOwnerUserId = EchoTraceOwnerScope.normalizedOwnerUserId(trace?.userId)
        let scopedTrace = explicitOwnerUserId == nil || explicitOwnerUserId == traceOwnerUserId
            ? trace
            : nil
        self.turnID = scopedTrace?.turnID ?? "unknown"
        self.traceId = scopedTrace?.traceId ?? "none"
        self.userId = explicitOwnerUserId ?? traceOwnerUserId ?? "unknown"
        self.recordedAt = Date()
        self.archiveItemIDs = scopedTrace?.archiveItemIDs ?? []
        self.archiveItemsIncluded = scopedTrace?.archiveItemsIncluded ?? 0
        self.archiveItemsAvailable = scopedTrace?.archiveItemsAvailable ?? 0
        self.kbFactCount = scopedTrace?.kbFactCount ?? 0
        self.voiceProfileId = selectedVoiceProfileId ?? scopedTrace?.voiceProfileId
        self.voiceCloneReady = scopedTrace?.voiceCloneReady ?? false
        self.voiceOutputMode = scopedTrace?.voiceOutputMode ?? "unknown"
        self.roleVoiceSource = roleVoiceSource
        self.roleVoiceDisplayName = roleVoiceDisplayName
        self.roleVoiceContextOwnerId = roleVoiceContextOwnerId
        self.audioOwner = audioOwner
        self.digitalHumanRuntimeState = digitalHumanRuntimeState
        self.digitalHumanSessionReady = digitalHumanSessionReady ?? scopedTrace?.digitalHumanSessionReady ?? false
        self.digitalHumanProviderMode = digitalHumanProviderMode ?? scopedTrace?.digitalHumanProviderMode ?? "unknown"
        self.providerLogId = providerLogId
        self.providerRequestId = providerRequestId
        self.providerMode = providerMode
        self.fallbackReason = fallbackReason
        self.privacyScopeLabel = scopedTrace?.privacyScopeLabel ?? "unknown"
        self.canUseFamilyData = scopedTrace?.canUseFamilyData ?? false
        self.crossScopeArchiveIncluded = scopedTrace?.crossScopeArchiveIncluded ?? false
        self.contextLatencyMs = scopedTrace?.latencyMs ?? 0
        self.featurePolicyDecisions = featurePolicyDecisions
        self.source = source
    }
}

enum EchoTraceStorageError: LocalizedError {
    case inactiveOwner
    case invalidEvidenceOwner
    case noEvidenceBundle

    var errorDescription: String? {
        switch self {
        case .inactiveOwner:
            return "Echo 诊断数据所属账号已失效"
        case .invalidEvidenceOwner:
            return "Echo 证据包缺少一致的账号信息"
        case .noEvidenceBundle:
            return "没有可导出的 Echo QA 证据包"
        }
    }
}

final class EchoTraceOwnerScope {
    static let shared = EchoTraceOwnerScope()

    private let lock = NSRecursiveLock()
    private var activeOwnerDigest: String?

    private init() {}

    static func normalizedOwnerUserId(_ ownerUserId: String?) -> String? {
        let normalized = ownerUserId?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        guard !normalized.isEmpty, normalized.lowercased() != "unknown" else {
            return nil
        }
        return normalized
    }

    static func ownerDigest(for ownerUserId: String?) -> String? {
        guard let normalizedOwnerUserId = normalizedOwnerUserId(ownerUserId) else {
            return nil
        }
        return SHA256.hash(data: Data("echo-trace-owner-v2|\(normalizedOwnerUserId)".utf8))
            .map { String(format: "%02x", $0) }
            .joined()
    }

    func withActiveOwner<T>(
        ownerUserId: String,
        operation: (String) throws -> T
    ) rethrows -> T? {
        guard let ownerDigest = Self.ownerDigest(for: ownerUserId) else {
            return nil
        }
        lock.lock()
        defer { lock.unlock() }
        guard activeOwnerDigest == ownerDigest else {
            return nil
        }
        return try operation(ownerDigest)
    }

    fileprivate func transition(
        to ownerUserId: String?,
        clearingOwnerUserIds: [String],
        cleanup: (Set<String>) -> Void
    ) {
        lock.lock()
        defer { lock.unlock() }

        let nextOwnerDigest = Self.ownerDigest(for: ownerUserId)
        var ownerDigestsToClear = Set(clearingOwnerUserIds.compactMap(Self.ownerDigest(for:)))
        if let activeOwnerDigest {
            ownerDigestsToClear.insert(activeOwnerDigest)
        }
        if let nextOwnerDigest {
            ownerDigestsToClear.remove(nextOwnerDigest)
        }

        activeOwnerDigest = nil
        cleanup(ownerDigestsToClear)
        activeOwnerDigest = nextOwnerDigest
    }
}

private final class EchoOwnerScopedDefaultsStore<Value: Codable> {
    private let userDefaults: UserDefaults
    private let storageKeyPrefix: String
    private let legacyStorageKey: String
    private let legacyExportFileName: String
    private let maximumValueCount: Int
    private let ownerScope: EchoTraceOwnerScope
    private let exportNamespace: String
    private let exportRootDirectoryName = "DreamJourneyEchoQAExports"

    init(
        userDefaults: UserDefaults,
        storageKeyPrefix: String,
        legacyStorageKey: String,
        legacyExportFileName: String,
        maximumValueCount: Int,
        ownerScope: EchoTraceOwnerScope = .shared
    ) {
        self.userDefaults = userDefaults
        self.storageKeyPrefix = storageKeyPrefix
        self.legacyStorageKey = legacyStorageKey
        self.legacyExportFileName = legacyExportFileName
        self.maximumValueCount = maximumValueCount
        self.ownerScope = ownerScope
        self.exportNamespace = SHA256.hash(data: Data(storageKeyPrefix.utf8))
            .map { String(format: "%02x", $0) }
            .joined()
    }

    func record(
        _ value: Value,
        ownerUserId: String,
        ownerIsValid: (String) -> Bool
    ) -> Bool {
        guard let normalizedOwnerUserId = EchoTraceOwnerScope.normalizedOwnerUserId(ownerUserId),
              ownerIsValid(normalizedOwnerUserId) else {
            return false
        }
        return ownerScope.withActiveOwner(ownerUserId: normalizedOwnerUserId) { ownerDigest in
            var values = loadValues(forOwnerDigest: ownerDigest)
            values.append(value)
            if values.count > maximumValueCount {
                values = Array(values.suffix(maximumValueCount))
            }
            return save(values, forOwnerDigest: ownerDigest)
        } ?? false
    }

    func values(
        ownerUserId: String,
        ownerIsValid: (Value, String) -> Bool
    ) -> [Value] {
        guard let normalizedOwnerUserId = EchoTraceOwnerScope.normalizedOwnerUserId(ownerUserId) else {
            return []
        }
        return ownerScope.withActiveOwner(ownerUserId: normalizedOwnerUserId) { ownerDigest in
            loadValues(forOwnerDigest: ownerDigest).filter {
                ownerIsValid($0, normalizedOwnerUserId)
            }
        } ?? []
    }

    func clear(ownerUserId: String) -> Bool {
        guard let normalizedOwnerUserId = EchoTraceOwnerScope.normalizedOwnerUserId(ownerUserId) else {
            return false
        }
        return ownerScope.withActiveOwner(ownerUserId: normalizedOwnerUserId) { ownerDigest in
            clearStorage(forOwnerDigest: ownerDigest)
            return true
        } ?? false
    }

    func export(
        ownerUserId: String,
        to url: URL,
        latestValueOnly: Bool = false,
        ownerIsValid: (Value, String) -> Bool
    ) throws -> URL {
        guard let normalizedOwnerUserId = EchoTraceOwnerScope.normalizedOwnerUserId(ownerUserId),
              let exportedURL = try ownerScope.withActiveOwner(
                ownerUserId: normalizedOwnerUserId,
                operation: { ownerDigest in
                    let values = loadValues(forOwnerDigest: ownerDigest).filter {
                        ownerIsValid($0, normalizedOwnerUserId)
                    }
                    let data: Data
                    if latestValueOnly {
                        guard let latestValue = values.last else {
                            throw EchoTraceStorageError.noEvidenceBundle
                        }
                        data = try Self.makeJSONEncoder().encode(latestValue)
                    } else {
                        data = try Self.makeJSONEncoder().encode(values)
                    }
                    let scopedURL = url.deletingLastPathComponent()
                        .appendingPathComponent(exportRootDirectoryName, isDirectory: true)
                        .appendingPathComponent(ownerDigest, isDirectory: true)
                        .appendingPathComponent(exportNamespace, isDirectory: true)
                        .appendingPathComponent(url.lastPathComponent, isDirectory: false)
                    try FileManager.default.createDirectory(
                        at: scopedURL.deletingLastPathComponent(),
                        withIntermediateDirectories: true
                    )
                    try data.write(to: scopedURL, options: [.atomic])
                    recordExportURL(scopedURL, forOwnerDigest: ownerDigest)
                    return scopedURL
                }
              ) else {
            throw EchoTraceStorageError.inactiveOwner
        }
        return exportedURL
    }

    fileprivate func clearStorage(forOwnerDigest ownerDigest: String) {
        userDefaults.removeObject(forKey: storageKey(forOwnerDigest: ownerDigest))
        removeExportedFiles(forOwnerDigest: ownerDigest)
    }

    fileprivate func purgeLegacyStorage() {
        userDefaults.removeObject(forKey: legacyStorageKey)
        let legacyURL = FileManager.default.temporaryDirectory
            .appendingPathComponent(legacyExportFileName, isDirectory: false)
        try? FileManager.default.removeItem(at: legacyURL)
    }

    private func storageKey(forOwnerDigest ownerDigest: String) -> String {
        "\(storageKeyPrefix)\(ownerDigest)"
    }

    private func exportManifestKey(forOwnerDigest ownerDigest: String) -> String {
        "\(storageKeyPrefix)exports.\(ownerDigest)"
    }

    private func recordExportURL(_ url: URL, forOwnerDigest ownerDigest: String) {
        let manifestKey = exportManifestKey(forOwnerDigest: ownerDigest)
        var paths = Set(userDefaults.stringArray(forKey: manifestKey) ?? [])
        paths.insert(url.path)
        userDefaults.set(paths.sorted(), forKey: manifestKey)
    }

    private func removeExportedFiles(forOwnerDigest ownerDigest: String) {
        let manifestKey = exportManifestKey(forOwnerDigest: ownerDigest)
        let paths = userDefaults.stringArray(forKey: manifestKey) ?? []
        let namespaceDirectories = Set(paths.map {
            URL(fileURLWithPath: $0).deletingLastPathComponent().standardizedFileURL
        })
        for directory in namespaceDirectories where directory.lastPathComponent == exportNamespace {
            try? FileManager.default.removeItem(at: directory)
        }
        userDefaults.removeObject(forKey: manifestKey)
    }

    private func loadValues(forOwnerDigest ownerDigest: String) -> [Value] {
        guard let data = userDefaults.data(forKey: storageKey(forOwnerDigest: ownerDigest)) else {
            return []
        }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return (try? decoder.decode([Value].self, from: data)) ?? []
    }

    private func save(_ values: [Value], forOwnerDigest ownerDigest: String) -> Bool {
        guard let data = try? Self.makeJSONEncoder().encode(values) else {
            return false
        }
        userDefaults.set(data, forKey: storageKey(forOwnerDigest: ownerDigest))
        return true
    }

    private static func makeJSONEncoder() -> JSONEncoder {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        return encoder
    }
}

final class EchoTraceStore {
    static let shared = EchoTraceStore()

    private static let storageKeyPrefix = "DreamJourney.EchoTraceStore.records.v2.owner."
    private static let legacyStorageKey = "DreamJourney.EchoTraceStore.records.v1"
    private let maximumRecordCount = 20
    private let storage: EchoOwnerScopedDefaultsStore<EchoTraceRecord>

    init(userDefaults: UserDefaults = .standard) {
        storage = EchoOwnerScopedDefaultsStore(
            userDefaults: userDefaults,
            storageKeyPrefix: Self.storageKeyPrefix,
            legacyStorageKey: Self.legacyStorageKey,
            legacyExportFileName: "echo-trace-records.json",
            maximumValueCount: maximumRecordCount
        )
    }

    @discardableResult
    func record(_ record: EchoTraceRecord, ownerUserId: String) -> Bool {
        storage.record(record, ownerUserId: ownerUserId) { normalizedOwnerUserId in
            EchoTraceOwnerScope.normalizedOwnerUserId(record.userId) == normalizedOwnerUserId
        }
    }

    func recentRecords(ownerUserId: String) -> [EchoTraceRecord] {
        storage.values(ownerUserId: ownerUserId) { record, normalizedOwnerUserId in
            EchoTraceOwnerScope.normalizedOwnerUserId(record.userId) == normalizedOwnerUserId
        }
    }

    @discardableResult
    func clear(ownerUserId: String) -> Bool {
        storage.clear(ownerUserId: ownerUserId)
    }

    func exportRecentRecords(
        ownerUserId: String,
        to directory: URL = FileManager.default.temporaryDirectory,
        fileName: String = "echo-trace-records.json"
    ) throws -> URL {
        let url = directory.appendingPathComponent(fileName)
        return try storage.export(ownerUserId: ownerUserId, to: url) { record, normalizedOwnerUserId in
            EchoTraceOwnerScope.normalizedOwnerUserId(record.userId) == normalizedOwnerUserId
        }
    }

    fileprivate func clearStorage(forOwnerDigest ownerDigest: String) {
        storage.clearStorage(forOwnerDigest: ownerDigest)
    }

    fileprivate func purgeLegacyStorage() {
        storage.purgeLegacyStorage()
    }
}

final class EchoRuntimeDiagnosticsStore {
    static let shared = EchoRuntimeDiagnosticsStore()

    private static let storageKeyPrefix = "DreamJourney.EchoRuntimeDiagnosticsStore.snapshots.v2.owner."
    private static let legacyStorageKey = "DreamJourney.EchoRuntimeDiagnosticsStore.snapshots.v1"
    private let maximumSnapshotCount = 20
    private let storage: EchoOwnerScopedDefaultsStore<EchoRuntimeDiagnosticsSnapshot>

    init(userDefaults: UserDefaults = .standard) {
        storage = EchoOwnerScopedDefaultsStore(
            userDefaults: userDefaults,
            storageKeyPrefix: Self.storageKeyPrefix,
            legacyStorageKey: Self.legacyStorageKey,
            legacyExportFileName: "echo-runtime-diagnostics.json",
            maximumValueCount: maximumSnapshotCount
        )
    }

    @discardableResult
    func record(_ snapshot: EchoRuntimeDiagnosticsSnapshot, ownerUserId: String) -> Bool {
        storage.record(snapshot, ownerUserId: ownerUserId) { normalizedOwnerUserId in
            EchoTraceOwnerScope.normalizedOwnerUserId(snapshot.userId) == normalizedOwnerUserId
        }
    }

    func recentSnapshots(ownerUserId: String) -> [EchoRuntimeDiagnosticsSnapshot] {
        storage.values(ownerUserId: ownerUserId) { snapshot, normalizedOwnerUserId in
            EchoTraceOwnerScope.normalizedOwnerUserId(snapshot.userId) == normalizedOwnerUserId
        }
    }

    @discardableResult
    func clear(ownerUserId: String) -> Bool {
        storage.clear(ownerUserId: ownerUserId)
    }

    func exportRecentSnapshots(
        ownerUserId: String,
        to directory: URL = FileManager.default.temporaryDirectory,
        fileName: String = "echo-runtime-diagnostics.json"
    ) throws -> URL {
        let url = directory.appendingPathComponent(fileName)
        return try storage.export(ownerUserId: ownerUserId, to: url) { snapshot, normalizedOwnerUserId in
            EchoTraceOwnerScope.normalizedOwnerUserId(snapshot.userId) == normalizedOwnerUserId
        }
    }

    fileprivate func clearStorage(forOwnerDigest ownerDigest: String) {
        storage.clearStorage(forOwnerDigest: ownerDigest)
    }

    fileprivate func purgeLegacyStorage() {
        storage.purgeLegacyStorage()
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
    let ownerUserId: String
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

    init(contract: DigitalHumanSessionContract, ownerUserId: String) {
        self.ownerUserId = ownerUserId
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
        self.hasBackendIssuedCredential = contract.credential.scopedSessionReady
        self.fallbackMode = contract.fallbackMode
        self.fallbackReason = contract.fallbackReason
        self.contractVersion = contract.contractVersion
        self.failureReason = nil
        self.failureDetail = nil
    }

    static func unavailable(
        ownerUserId: String,
        reason: String,
        detail: String? = nil
    ) -> EchoDigitalHumanSessionEvidenceSummary {
        EchoDigitalHumanSessionEvidenceSummary(
            ownerUserId: ownerUserId,
            status: "unavailable",
            reason: reason,
            detail: detail
        )
    }

    static func failed(
        ownerUserId: String,
        reason: String,
        detail: String? = nil
    ) -> EchoDigitalHumanSessionEvidenceSummary {
        EchoDigitalHumanSessionEvidenceSummary(
            ownerUserId: ownerUserId,
            status: "failed",
            reason: reason,
            detail: detail
        )
    }

    private init(ownerUserId: String, status: String, reason: String, detail: String?) {
        self.ownerUserId = ownerUserId
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
    let ownerUserId: String
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

    init(synthesis: VoiceCloneSynthesisResult, ownerUserId: String) {
        self.ownerUserId = ownerUserId
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

    static func unavailable(
        ownerUserId: String,
        reason: String,
        detail: String? = nil
    ) -> EchoVoiceSynthesisEvidenceSummary {
        EchoVoiceSynthesisEvidenceSummary(
            ownerUserId: ownerUserId,
            status: "unavailable",
            reason: reason,
            detail: detail
        )
    }

    static func failed(
        ownerUserId: String,
        voiceProfileId: String?,
        outputMode: String?,
        providerLogId: String?,
        providerRequestId: String?,
        reason: String,
        detail: String?
    ) -> EchoVoiceSynthesisEvidenceSummary {
        EchoVoiceSynthesisEvidenceSummary(
            ownerUserId: ownerUserId,
            status: "failed",
            voiceProfileId: voiceProfileId,
            outputMode: outputMode,
            providerLogId: providerLogId,
            providerRequestId: providerRequestId,
            reason: reason,
            detail: detail
        )
    }

    private init(ownerUserId: String, status: String, reason: String, detail: String?) {
        self.init(
            ownerUserId: ownerUserId,
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
        ownerUserId: String,
        status: String,
        voiceProfileId: String?,
        outputMode: String?,
        providerLogId: String?,
        providerRequestId: String?,
        reason: String,
        detail: String?
    ) {
        self.ownerUserId = ownerUserId
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
    let ownerUserId: String
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

    var derivedOwnerUserId: String? {
        guard let packageOwner = EchoTraceOwnerScope.normalizedOwnerUserId(ownerUserId) else {
            return nil
        }
        let traceOwner = traceRecord.flatMap {
            EchoTraceOwnerScope.normalizedOwnerUserId($0.userId)
        }
        let runtimeOwner = runtimeDiagnostics.flatMap {
            EchoTraceOwnerScope.normalizedOwnerUserId($0.userId)
        }
        let digitalHumanOwner = digitalHumanSession.flatMap {
            EchoTraceOwnerScope.normalizedOwnerUserId($0.ownerUserId)
        }
        let voiceSynthesisOwner = voiceSynthesis.flatMap {
            EchoTraceOwnerScope.normalizedOwnerUserId($0.ownerUserId)
        }
        guard traceRecord == nil || traceOwner == packageOwner,
              runtimeDiagnostics == nil || runtimeOwner == packageOwner,
              digitalHumanSession == nil || digitalHumanOwner == packageOwner,
              voiceSynthesis == nil || voiceSynthesisOwner == packageOwner else {
            return nil
        }
        return packageOwner
    }

    init(
        ownerUserId: String,
        traceRecord: EchoTraceRecord?,
        runtimeDiagnostics: EchoRuntimeDiagnosticsSnapshot?,
        digitalHumanSession: EchoDigitalHumanSessionEvidenceSummary?,
        voiceSynthesis: EchoVoiceSynthesisEvidenceSummary?,
        source: String
    ) {
        self.schemaVersion = 1
        self.ownerUserId = ownerUserId
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
            "只保留 providerLogId/providerRequestId 的无值哈希用于服务商排查",
            "只导出档案 ID、数量和权限摘要，不导出档案正文"
        ]
    }
}

final class EchoTraceEvidencePackageStore {
    static let shared = EchoTraceEvidencePackageStore()

    private static let storageKeyPrefix = "DreamJourney.EchoTraceEvidencePackageStore.packages.v2.owner."
    private static let legacyStorageKey = "DreamJourney.EchoTraceEvidencePackageStore.packages.v1"
    private let maximumPackageCount = 20
    private let storage: EchoOwnerScopedDefaultsStore<EchoTraceEvidencePackage>

    init(userDefaults: UserDefaults = .standard) {
        storage = EchoOwnerScopedDefaultsStore(
            userDefaults: userDefaults,
            storageKeyPrefix: Self.storageKeyPrefix,
            legacyStorageKey: Self.legacyStorageKey,
            legacyExportFileName: "echo-trace-evidence-packages.json",
            maximumValueCount: maximumPackageCount
        )
    }

    @discardableResult
    func record(_ package: EchoTraceEvidencePackage, ownerUserId: String) -> Bool {
        storage.record(package, ownerUserId: ownerUserId) { normalizedOwnerUserId in
            package.derivedOwnerUserId == normalizedOwnerUserId
        }
    }

    func recentPackages(ownerUserId: String) -> [EchoTraceEvidencePackage] {
        storage.values(ownerUserId: ownerUserId) { package, normalizedOwnerUserId in
            package.derivedOwnerUserId == normalizedOwnerUserId
        }
    }

    @discardableResult
    func clear(ownerUserId: String) -> Bool {
        storage.clear(ownerUserId: ownerUserId)
    }

    func exportRecentPackages(
        ownerUserId: String,
        to directory: URL = FileManager.default.temporaryDirectory,
        fileName: String = "echo-trace-evidence-packages.json"
    ) throws -> URL {
        let url = directory.appendingPathComponent(fileName)
        return try storage.export(ownerUserId: ownerUserId, to: url) { package, normalizedOwnerUserId in
            package.derivedOwnerUserId == normalizedOwnerUserId
        }
    }

    fileprivate func clearStorage(forOwnerDigest ownerDigest: String) {
        storage.clearStorage(forOwnerDigest: ownerDigest)
    }

    fileprivate func purgeLegacyStorage() {
        storage.purgeLegacyStorage()
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

    var derivedOwnerUserId: String? {
        evidencePackage.derivedOwnerUserId
    }

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

    private static let storageKeyPrefix = "DreamJourney.EchoQAEvidenceBundleStore.bundles.v3.owner."
    private static let legacyStorageKey = "DreamJourney.EchoQAEvidenceBundleStore.bundles.v2"
    private let maximumBundleCount = 20
    private let storage: EchoOwnerScopedDefaultsStore<EchoQAEvidenceBundle>

    init(userDefaults: UserDefaults = .standard) {
        storage = EchoOwnerScopedDefaultsStore(
            userDefaults: userDefaults,
            storageKeyPrefix: Self.storageKeyPrefix,
            legacyStorageKey: Self.legacyStorageKey,
            legacyExportFileName: "echo-qa-evidence-bundle.json",
            maximumValueCount: maximumBundleCount
        )
    }

    @discardableResult
    func record(_ bundle: EchoQAEvidenceBundle, ownerUserId: String) -> Bool {
        storage.record(bundle, ownerUserId: ownerUserId) { normalizedOwnerUserId in
            bundle.derivedOwnerUserId == normalizedOwnerUserId
        }
    }

    func recentBundles(ownerUserId: String) -> [EchoQAEvidenceBundle] {
        storage.values(ownerUserId: ownerUserId) { bundle, normalizedOwnerUserId in
            bundle.derivedOwnerUserId == normalizedOwnerUserId
        }
    }

    @discardableResult
    func clear(ownerUserId: String) -> Bool {
        storage.clear(ownerUserId: ownerUserId)
    }

    func exportLatestBundle(
        ownerUserId: String,
        to directory: URL = FileManager.default.temporaryDirectory,
        fileName: String = "echo-qa-evidence-bundle.json"
    ) throws -> URL {
        let url = directory.appendingPathComponent(fileName)
        return try storage.export(
            ownerUserId: ownerUserId,
            to: url,
            latestValueOnly: true
        ) { bundle, normalizedOwnerUserId in
            bundle.derivedOwnerUserId == normalizedOwnerUserId
        }
    }

    fileprivate func clearStorage(forOwnerDigest ownerDigest: String) {
        storage.clearStorage(forOwnerDigest: ownerDigest)
    }

    fileprivate func purgeLegacyStorage() {
        storage.purgeLegacyStorage()
    }

}

enum EchoTraceAccountLifecycle {
    static func activate(ownerUserId: String?) {
        transition(to: ownerUserId, clearingOwnerUserIds: [])
    }

    static func switchOwner(from previousOwnerUserId: String?, to ownerUserId: String) {
        transition(
            to: ownerUserId,
            clearingOwnerUserIds: previousOwnerUserId.map { [$0] } ?? []
        )
    }

    static func invalidateAndClear(ownerUserId: String?) {
        transition(
            to: nil,
            clearingOwnerUserIds: ownerUserId.map { [$0] } ?? []
        )
    }

    private static func transition(to ownerUserId: String?, clearingOwnerUserIds: [String]) {
        EchoTraceOwnerScope.shared.transition(
            to: ownerUserId,
            clearingOwnerUserIds: clearingOwnerUserIds
        ) { ownerDigestsToClear in
            for ownerDigest in ownerDigestsToClear {
                EchoTraceStore.shared.clearStorage(forOwnerDigest: ownerDigest)
                EchoRuntimeDiagnosticsStore.shared.clearStorage(forOwnerDigest: ownerDigest)
                EchoTraceEvidencePackageStore.shared.clearStorage(forOwnerDigest: ownerDigest)
                EchoQAEvidenceBundleStore.shared.clearStorage(forOwnerDigest: ownerDigest)
                let defaultOwnerExportDirectory = FileManager.default.temporaryDirectory
                    .appendingPathComponent("DreamJourneyEchoQAExports", isDirectory: true)
                    .appendingPathComponent(ownerDigest, isDirectory: true)
                try? FileManager.default.removeItem(at: defaultOwnerExportDirectory)
            }
            EchoTraceStore.shared.purgeLegacyStorage()
            EchoRuntimeDiagnosticsStore.shared.purgeLegacyStorage()
            EchoTraceEvidencePackageStore.shared.purgeLegacyStorage()
            EchoQAEvidenceBundleStore.shared.purgeLegacyStorage()
        }
    }
}

final class DreamJourneyBackendClient {
    static let shared = DreamJourneyBackendClient()

    struct BackendErrorContext: Equatable {
        let code: String?
        let operationId: String?
        let detail: String

        init(code: String? = nil, operationId: String? = nil, detail: String) {
            self.code = code
            self.operationId = operationId
            self.detail = detail
        }
    }

    private enum RequestAuthPolicy {
        case publicRequest
        case userRequired
        case refreshExchange
    }

    private struct EndpointDescriptor {
        let path: String
        let method: HTTPMethod
        let authPolicy: RequestAuthPolicy
        let purpose: String
        let ownerBinding: String
        let sessionUserAssertions: [String]

        init(
            path: String,
            method: HTTPMethod,
            authPolicy: RequestAuthPolicy,
            payload: [String: Any]?,
            sessionUserId: String?
        ) {
            self.path = path
            self.method = method
            self.authPolicy = authPolicy
            purpose = Self.purpose(for: path)
            sessionUserAssertions = [
                Self.normalizedUserId(sessionUserId),
                Self.normalizedUserId(payload?["userId"]),
            ].compactMap { $0 }
            switch authPolicy {
            case .publicRequest:
                ownerBinding = "public"
            case .userRequired:
                ownerBinding = sessionUserAssertions.isEmpty
                    ? "sessionActor"
                    : "sessionActorAssertion"
            case .refreshExchange:
                ownerBinding = "refreshTokenFamily"
            }
        }

        private static func normalizedUserId(_ value: Any?) -> String? {
            guard let value = value as? String else { return nil }
            let normalized = value.trimmingCharacters(in: .whitespacesAndNewlines)
            return normalized.isEmpty ? nil : normalized
        }

        private static func purpose(for path: String) -> String {
            let normalizedPath = path.split(separator: "?", maxSplits: 1).first.map(String.init) ?? path
            if normalizedPath.hasPrefix("/auth/") || normalizedPath.hasPrefix("/v2/auth/") {
                return "identity"
            }
            if normalizedPath.hasPrefix("/archive/") { return "archive" }
            if normalizedPath.hasPrefix("/family/") { return "family" }
            if normalizedPath.hasPrefix("/care/") { return "care" }
            if normalizedPath.hasPrefix("/voice/") { return "voice" }
            if normalizedPath.hasPrefix("/digital-human/") { return "digitalHuman" }
            if normalizedPath.hasPrefix("/kb/") { return "knowledge" }
            if normalizedPath.hasPrefix("/echo/") || normalizedPath == "/context/build" { return "echo" }
            if normalizedPath == "/profile" || normalizedPath.hasPrefix("/account/") { return "account" }
            if normalizedPath.hasPrefix("/config/") || normalizedPath.hasPrefix("/v2/release-policy") {
                return "runtimePolicy"
            }
            return "business"
        }
    }

    enum ClientError: LocalizedError {
        case invalidJSONResponse
        case unsupportedJSONRoot
        case userAuthenticationRequired
        case sessionUpgradeRequired(minimumBuild: Int?, accessMode: String)
        case accountScopeChanged
        case featurePolicyDenied(feature: String, reason: String)
        case recoveryAccessDenied(mode: String, code: String, reason: String)
        case backendError(statusCode: Int?, context: BackendErrorContext)

        var backendErrorContext: BackendErrorContext? {
            guard case .backendError(_, let context) = self else { return nil }
            return context
        }

        var errorDescription: String? {
            switch self {
            case .invalidJSONResponse:
                return "后端返回的数据不是有效 JSON"
            case .unsupportedJSONRoot:
                return "后端返回的 JSON 根节点不是对象"
            case .userAuthenticationRequired:
                return "需要登录后才能继续"
            case .sessionUpgradeRequired(let minimumBuild, let accessMode):
                let buildText = minimumBuild.map { "（最低版本 \($0)）" } ?? ""
                return "当前登录会话需要重新验证或升级 App\(buildText)，现处于 \(accessMode) 模式"
            case .accountScopeChanged:
                return "账号已切换，旧请求结果已丢弃"
            case .featurePolicyDenied(let feature, let reason):
                return "功能请求已被发布策略拦截（\(feature)：\(reason)）"
            case .recoveryAccessDenied(let mode, let code, let reason):
                return "服务处于恢复状态（\(mode)：\(code)，\(reason)）"
            case .backendError(let statusCode, let context):
                if let statusCode {
                    return "后端请求失败（\(statusCode)）：\(context.detail)"
                }
                return "后端请求失败：\(context.detail)"
            }
        }
    }

    private static let defaultBaseURL = "http://127.0.0.1:3100"
    private static let placeholderBaseURL = "$(DREAMJOURNEY_BACKEND_BASE_URL)"
    private let baseURL: String
    private let hasExplicitBaseURL: Bool
    private let authSessionStore = BackendAuthSessionStore.shared
    private let accountSessionActor = AccountSessionActor.shared
    private let accountLeaseRuntime = AccountLeaseRuntime.shared
    private let releasePolicyStore = ReleasePolicyStore.shared
    private let recoveryRuntimePolicyStore = RecoveryRuntimePolicyStore.shared
    private let authRefreshQueue = DispatchQueue(label: "com.dreamjourney.backend-auth-refresh")
    private struct AuthRefreshGroup {
        let capturedSession: BackendAuthSessionContract
        let accountLease: AccountSessionRefreshLease
        var waiters: [(BackendAuthSessionContract?) -> Void]
    }
    private struct AuthRefreshClientReference: @unchecked Sendable {
        let value: DreamJourneyBackendClient
    }
    private var activeAuthRefreshGroup: AuthRefreshGroup?
    private var pendingAuthRefreshGroups: [AuthRefreshGroup] = []

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

    var isReleasePolicyConfigured: Bool {
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

    }

    func postArchiveItem(_ payload: [String: Any], completion: @escaping (Result<[String: Any], Error>) -> Void) {
        requestJSON(
            path: "/archive/items",
            method: .post,
            payload: payload,
            authPolicy: .userRequired,
            completion: completion
        )
    }

    func deleteArchiveItem(
        userId: String,
        itemId: String,
        operationId: String? = nil,
        completion: @escaping (Result<[String: Any], Error>) -> Void
    ) {
        var path = "/archive/items/\(pathComponent(userId))/\(pathComponent(itemId))"
        if let operationId = operationId?.trimmingCharacters(in: .whitespacesAndNewlines),
           !operationId.isEmpty {
            path += "?operationId=\(queryComponent(operationId))"
        }
        requestJSON(
            path: path,
            method: .delete,
            payload: nil,
            authPolicy: .userRequired,
            sessionUserId: userId,
            completion: completion
        )
    }

    func fetchRuntimeConfig(completion: @escaping (Result<BackendRuntimeConfig, Error>) -> Void) {
        requestJSON(
            path: "/config/runtime",
            method: .get,
            payload: nil,
            authPolicy: .publicRequest,
            allowsRefresh: false,
            additionalHeaders: [
                "X-DreamJourney-Runtime-Contract-Version": "2",
                "X-DreamJourney-Client-Build": String(FeatureGateService.shared.clientBuild),
            ]
        ) { result in
            let mapped = result.map(BackendRuntimeConfig.init(json:))
            if case .success(let config) = mapped {
                self.adoptRecoveryRuntimePolicy(config.recovery)
                RuntimeCapabilitySnapshotStore.shared.replace(with: config.capabilitySnapshots)
            }
            completion(mapped)
        }
    }

    func fetchReleasePolicy(
        audience: String = "owner",
        cohort: String = "closedPilotAdultSelf",
        clientBuild: Int,
        knownPolicyRevision: Int = 0,
        completion: @escaping (Result<BackendReleasePolicySnapshot, Error>) -> Void
    ) {
        let requestedScope = releasePolicyCacheScope(clientBuild: clientBuild)
        let path = "/v2/release-policy"
            + "?audience=\(queryComponent(audience))"
            + "&cohort=\(queryComponent(cohort))"
            + "&clientBuild=\(max(0, clientBuild))"
            + "&knownPolicyRevision=\(max(0, knownPolicyRevision))"
        requestJSON(
            path: path,
            method: .get,
            payload: nil,
            authPolicy: .publicRequest
        ) { result in
            switch result {
            case .success(let json):
                do {
                    let snapshot = try BackendReleasePolicySnapshot(json: json)
                    let payload = try JSONSerialization.data(withJSONObject: json, options: [.sortedKeys])
                    guard requestedScope == self.releasePolicyCacheScope(clientBuild: clientBuild) else {
                        throw BackendReleasePolicyContractError.accountScopeChanged
                    }
                    try self.releasePolicyStore.save(
                        payload: payload,
                        policySchemaVersion: snapshot.schemaVersion,
                        policyVersion: snapshot.policyVersion,
                        policyRevision: snapshot.policyRevision,
                        emergencyRevision: snapshot.emergencyRevision,
                        scope: requestedScope,
                        fetchedAt: Date(),
                        expiresAt: snapshot.expiresAt
                    )
                    completion(.success(snapshot))
                } catch {
                    completion(.failure(error))
                }
            case .failure(let error):
                completion(.failure(error))
            }
        }
    }

    func cachedReleasePolicyEvaluation(
        risk: ReleasePolicyRiskClass,
        clientBuild: Int,
        now: Date = Date(),
        minimumEmergencyRevision: Int = 0
    ) -> BackendCachedReleasePolicyEvaluation {
        let cache = releasePolicyStore.evaluate(
            scope: releasePolicyCacheScope(clientBuild: clientBuild),
            risk: risk,
            now: now,
            minimumEmergencyRevision: minimumEmergencyRevision
        )
        return BackendCachedReleasePolicyEvaluation(cache: cache, risk: risk)
    }

    func invalidateCachedReleasePolicyAuthority(clientBuild: Int) {
        releasePolicyStore.remove(scope: releasePolicyCacheScope(clientBuild: clientBuild))
    }

    private func releasePolicyCacheScope(clientBuild: Int) -> ReleasePolicyCacheScope {
        ReleasePolicyCacheScope(
            accountUserId: authSessionStore.currentSession?.userId,
            appBuild: String(max(0, clientBuild))
        )
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
        requestJSON(
            path: "/digital-human/sessions",
            method: .post,
            payload: payload,
            authPolicy: .userRequired
        ) { result in
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
                context: .init(detail: "digital human session lease is unavailable")
            )))
            return
        }
        let fallbackPath = "/digital-human/sessions/\(pathComponent(contract.sessionId))/heartbeat"
        let path = validatedDigitalHumanLeasePath(lease.heartbeatEndpoint, fallback: fallbackPath)
        requestJSON(
            path: path,
            method: .post,
            payload: ["userId": contract.userId, "deviceId": contract.deviceId],
            authPolicy: .userRequired
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
                context: .init(detail: "digital human session lease is unavailable")
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
            ],
            authPolicy: .userRequired
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
        requestJSON(
            path: "/voice/realtime-token",
            method: .post,
            payload: ["userId": userId],
            authPolicy: .userRequired
        ) { result in
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
        requestJSON(
            path: "/voice/profiles",
            method: .post,
            payload: payload,
            authPolicy: .userRequired
        ) { result in
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
        requestJSON(
            path: "/voice/profiles/\(pathComponent(userId))",
            method: .get,
            payload: nil,
            authPolicy: .userRequired,
            sessionUserId: userId
        ) { result in
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
        requestJSON(
            path: path,
            method: .post,
            payload: nil,
            authPolicy: .userRequired,
            sessionUserId: userId
        ) { result in
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
        requestJSON(
            path: path,
            method: .post,
            payload: nil,
            authPolicy: .userRequired,
            sessionUserId: userId
        ) { result in
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
        requestJSON(
            path: path,
            method: .post,
            payload: ["accepted": true],
            authPolicy: .userRequired,
            sessionUserId: userId
        ) { result in
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
        requestJSON(
            path: "/voice/synthesis",
            method: .post,
            payload: payload,
            authPolicy: .userRequired
        ) { result in
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
        requestJSON(
            path: "/context/build",
            method: .post,
            payload: payload,
            authPolicy: .userRequired
        ) { result in
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
        requestJSON(path: path, method: .delete, payload: nil, authPolicy: .userRequired) { result in
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
        requestJSON(
            path: "/archive/media/upload-intent",
            method: .post,
            payload: payload,
            authPolicy: .userRequired
        ) { result in
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
        requestJSON(
            path: "/archive/image-analysis",
            method: .post,
            payload: payload,
            authPolicy: .userRequired,
            completion: completion
        )
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
            authPolicy: .publicRequest,
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
                    guard try self.adoptAuthSession(from: object) else {
                        throw ClientError.invalidJSONResponse
                    }
                    completion(.success(object))
                } catch {
                    completion(.failure(error))
                }
            case .failure(let error):
                completion(.failure(error))
            }
        }
    }

    func createIdentityChallenge(
        phone: String,
        purpose: String = "login",
        completion: @escaping (Result<BackendIdentityChallengeContract, Error>) -> Void
    ) {
        requestJSON(
            path: "/v2/auth/challenges",
            method: .post,
            payload: [
                "identityType": "phone",
                "target": phone,
                "purpose": purpose,
            ],
            authPolicy: .publicRequest,
            allowsRefresh: false
        ) { result in
            completion(result.flatMap { object in
                guard let challenge = BackendIdentityChallengeContract(json: object) else {
                    return .failure(ClientError.invalidJSONResponse)
                }
                return .success(challenge)
            })
        }
    }

    func verifyIdentityChallenge(
        challengeId: String,
        verificationCode: String,
        nickname: String,
        completion: @escaping (Result<[String: Any], Error>) -> Void
    ) {
        let payload: [String: Any] = [
            "code": verificationCode,
            "nickname": nickname,
        ]
        requestJSON(
            path: "/v2/auth/challenges/\(pathComponent(challengeId))/verify",
            method: .post,
            payload: payload,
            authPolicy: .publicRequest,
            allowsRefresh: false
        ) { [weak self] result in
            guard let self else { return }
            switch result {
            case .success(let object):
                guard let identity = BackendIdentityVerificationContract(json: object),
                      let user = object["user"] as? [String: Any],
                      let userId = user["id"] as? String,
                      userId == identity.subjectId,
                      let auth = object["auth"] as? [String: Any],
                      auth["userId"] as? String == identity.subjectId else {
                    self.authSessionStore.clear()
                    completion(.failure(ClientError.invalidJSONResponse))
                    return
                }
                do {
                    guard try self.adoptAuthSession(from: object) else {
                        throw ClientError.invalidJSONResponse
                    }
                    completion(.success(object))
                } catch {
                    self.authSessionStore.clear()
                    completion(.failure(error))
                }
            case .failure(let error):
                completion(.failure(error))
            }
        }
    }

    func resumePrivateAccessSession(completion: @escaping (Bool) -> Void) {
        guard let capturedSession = authSessionStore.currentSession,
              capturedSession.isPrivateAccessEligible else {
            if let userId = UserManager.shared.currentUser?.id {
                UserManager.shared.suspendPrivateAccess(
                    for: userId,
                    reason: "startupSessionUnavailable",
                    notify: false
                )
            }
            DispatchQueue.main.async { completion(false) }
            return
        }

        refreshAuthSession(for: capturedSession) { refreshedSession in
            guard let refreshedSession else {
                UserManager.shared.suspendPrivateAccess(
                    for: capturedSession.userId,
                    reason: "startupSessionValidationFailed",
                    notify: false
                )
                completion(false)
                return
            }
            guard UserManager.shared.prepareCachedProfileForValidatedSession(refreshedSession) else {
                UserManager.shared.suspendPrivateAccess(
                    for: refreshedSession.userId,
                    reason: "startupProfileRecoveryFailed",
                    notify: false
                )
                completion(false)
                return
            }
            completion(UserManager.shared.markPrivateAccessValidated(session: refreshedSession))
        }
    }

    func logoutAuthSession() {
        guard let session = authSessionStore.currentSession else { return }
        requestJSON(
            path: "/auth/logout",
            method: .post,
            payload: ["refreshToken": session.refreshToken],
            authPolicy: .userRequired,
            allowsRefresh: false,
            requiredAuthSession: session
        ) { _ in }
        authSessionStore.clear(ifCurrentMatches: session)
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
        requestJSON(
            path: "/profile",
            method: .post,
            payload: payload,
            authPolicy: .userRequired,
            completion: completion
        )
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
            authPolicy: .userRequired,
            completion: completion
        )
    }

    func softDeleteAccount(
        userId: String,
        phone: String,
        completion: @escaping (Result<AccountDeletionAcceptanceContract, Error>) -> Void
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
            authPolicy: .userRequired,
            completion: { result in
                switch result {
                case .success(let object):
                    do {
                        completion(.success(try AccountDeletionAcceptanceContract(json: object)))
                    } catch {
                        completion(.failure(error))
                    }
                case .failure(let error):
                    completion(.failure(error))
                }
            }
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
        requestJSON(
            path: "/auth/restore",
            method: .post,
            payload: payload,
            authPolicy: .publicRequest,
            completion: completion
        )
    }

    func listArchiveItems(userId: String, completion: @escaping (Result<[String: Any], Error>) -> Void) {
        requestJSON(
            path: "/archive/items/\(pathComponent(userId))",
            method: .get,
            payload: nil,
            authPolicy: .userRequired,
            sessionUserId: userId,
            completion: completion
        )
    }

    func listMailboxLetters(userId: String, completion: @escaping (Result<[String: Any], Error>) -> Void) {
        requestJSON(
            path: "/mailbox/letters/\(pathComponent(userId))",
            method: .get,
            payload: nil,
            authPolicy: .userRequired,
            sessionUserId: userId,
            completion: completion
        )
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
        requestJSON(
            path: path,
            method: .get,
            payload: nil,
            authPolicy: .userRequired,
            sessionUserId: viewerUserId,
            completion: completion
        )
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
            authPolicy: .userRequired,
            sessionUserId: userId,
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
            authPolicy: .userRequired,
            sessionUserId: userId,
            completion: completion
        )
    }

    func syncKnowledge(userId: String, graph: [String: Any], completion: @escaping (Result<[String: Any], Error>) -> Void) {
        requestJSON(
            path: "/kb/sync",
            method: .post,
            payload: ["userId": userId, "graph": graph],
            authPolicy: .userRequired,
            completion: completion
        )
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
            authPolicy: .userRequired,
            completion: completion
        )
    }

    func mutateKnowledgeV2(
        userId: String,
        upserts: [String: [[String: Any]]],
        tombstones: [[String: Any]],
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
                "mutationSchemaVersion": 2,
                "upserts": upserts,
                "tombstones": tombstones,
            ],
            authPolicy: .userRequired,
            completion: completion
        )
    }

    func governKnowledge(
        userId: String,
        operationId: String,
        baseRevision: Int,
        action: KBKnowledgeGovernanceAction,
        completion: @escaping (Result<KBKnowledgeGovernanceResponse, Error>) -> Void
    ) {
        let actionObject: [String: Any]
        do {
            actionObject = try action.backendJSONObject()
        } catch {
            completion(.failure(error))
            return
        }

        requestJSON(
            path: "/kb/governance/actions",
            method: .post,
            payload: [
                "governanceSchemaVersion": 1,
                "userId": userId,
                "operationId": operationId,
                "baseRevision": baseRevision,
                "action": actionObject,
            ],
            authPolicy: .userRequired
        ) { result in
            switch result {
            case .success(let object):
                do {
                    let response = try KBKnowledgeGovernanceResponse(json: object)
                    guard response.userId == userId, response.operationId == operationId else {
                        throw KBKnowledgeGovernanceModelError.invalidResponse(
                            "response identity does not match the request"
                        )
                    }
                    completion(.success(response))
                } catch {
                    completion(.failure(error))
                }
            case .failure(let error):
                completion(.failure(error))
            }
        }
    }

    func fetchKnowledgeChanges(
        userId: String,
        sinceRevision: Int,
        targetRevision: Int? = nil,
        pageLimit: Int = 50,
        completion: @escaping (Result<KnowledgeChangePage, Error>) -> Void
    ) {
        let normalizedSinceRevision = max(0, sinceRevision)
        var components = URLComponents()
        components.percentEncodedPath = "/kb/changes/\(pathComponent(userId))"
        var queryItems = [
            URLQueryItem(name: "sinceRevision", value: String(normalizedSinceRevision)),
            URLQueryItem(name: "limit", value: String(min(100, max(1, pageLimit)))),
        ]
        if let targetRevision {
            queryItems.append(URLQueryItem(name: "targetRevision", value: String(max(0, targetRevision))))
        }
        components.queryItems = queryItems
        guard let path = components.string else {
            completion(.failure(ClientError.invalidJSONResponse))
            return
        }
        requestJSON(
            path: path,
            method: .get,
            payload: nil,
            authPolicy: .userRequired,
            sessionUserId: userId
        ) { result in
            switch result {
            case .success(let object):
                do {
                    completion(.success(try KnowledgeChangePage(
                        json: object,
                        expectedUserId: userId,
                        requestedSinceRevision: normalizedSinceRevision,
                        requestedTargetRevision: targetRevision
                    )))
                } catch {
                    completion(.failure(error))
                }
            case .failure(let error):
                completion(.failure(error))
            }
        }
    }

    func fetchKnowledgeSnapshot(
        userId: String,
        completion: @escaping (Result<KnowledgeSnapshotResponse, Error>) -> Void
    ) {
        requestJSON(
            path: "/kb/snapshot/\(pathComponent(userId))",
            method: .get,
            payload: nil,
            authPolicy: .userRequired,
            sessionUserId: userId
        ) { result in
            switch result {
            case .success(let object):
                do {
                    completion(.success(try KnowledgeSnapshotResponse(
                        json: object,
                        expectedUserId: userId
                    )))
                } catch {
                    completion(.failure(error))
                }
            case .failure(let error):
                completion(.failure(error))
            }
        }
    }

    func fetchKnowledgeSourceRefAudit(
        userId: String,
        completion: @escaping (Result<KBKnowledgeSourceRefAuditResponse, Error>) -> Void
    ) {
        requestJSON(
            path: "/kb/source-ref-audit/\(pathComponent(userId))",
            method: .get,
            payload: nil,
            authPolicy: .userRequired,
            sessionUserId: userId
        ) { result in
            switch result {
            case .success(let object):
                guard let response = KBKnowledgeSourceRefAuditResponse(
                    json: object,
                    expectedUserId: userId
                ) else {
                    completion(.failure(ClientError.invalidJSONResponse))
                    return
                }
                completion(.success(response))
            case .failure(let error):
                completion(.failure(error))
            }
        }
    }

    func extractKnowledge(
        userId: String,
        transcript: String,
        turns: [ConversationTurn],
        existingSummary: String,
        sessionId: Int,
        completion: @escaping (Result<KBExtractionResult, Error>) -> Void
    ) {
        extractKnowledgeEnvelope(
            userId: userId,
            transcript: transcript,
            turns: turns,
            existingSummary: existingSummary,
            sessionId: sessionId,
            personaScope: "personal",
            digitalHumanId: userId
        ) { result in
            completion(result.map(\.extraction))
        }
    }

    func extractKnowledgeEnvelope(
        userId: String,
        transcript: String,
        turns: [ConversationTurn],
        existingSummary: String,
        sessionId: Int,
        personaScope: String = "personal",
        digitalHumanId: String? = nil,
        completion: @escaping (Result<KBKnowledgeExtractionEnvelope, Error>) -> Void
    ) {
        let indexedTurns: [[String: Any]] = turns.enumerated().map { index, turn in
            [
                "index": index,
                "role": turn.role == "user" ? "user" : "assistant",
                "text": turn.text,
            ]
        }
        requestJSON(
            path: "/kb/extract",
            method: .post,
            payload: [
                "userId": userId,
                "extractionSchemaVersion": 2,
                "sourcePolicy": "userEvidenceOnly",
                "turns": indexedTurns,
                "transcript": transcript,
                "existingSummary": existingSummary,
                "sessionId": sessionId,
                "personaScope": personaScope,
                "digitalHumanId": digitalHumanId ?? userId,
                "sourceContractVersion": KBKnowledgeSourceIdentityPolicy.sourceContractVersion,
                "boundaryAcknowledged": true,
                "privacyMetadata": [
                    "scope": "generationAllowed",
                    "sourceRefs": [],
                ],
            ],
            authPolicy: .userRequired
        ) { result in
            switch result {
            case .success(let object):
                guard JSONSerialization.isValidJSONObject(object),
                      let data = try? JSONSerialization.data(withJSONObject: object) else {
                    completion(.failure(ClientError.invalidJSONResponse))
                    return
                }
                do {
                    let envelope = try Self.makeKnowledgeExtractionDecoder().decode(
                        KBKnowledgeExtractionEnvelope.self,
                        from: data
                    )
                    completion(.success(envelope))
                } catch {
                    completion(.failure(ClientError.invalidJSONResponse))
                }
            case .failure(let error):
                completion(.failure(error))
            }
        }
    }

    private static func makeKnowledgeExtractionDecoder() -> JSONDecoder {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .custom { decoder in
            let container = try decoder.singleValueContainer()
            let value = try container.decode(String.self)
            guard let date = BackendDateParser.date(from: value) else {
                throw DecodingError.dataCorruptedError(
                    in: container,
                    debugDescription: "Expected an ISO-8601 date"
                )
            }
            return date
        }
        return decoder
    }

    func listFamilyMembers(userId: String, completion: @escaping (Result<[String: Any], Error>) -> Void) {
        requestJSON(
            path: "/family/members/\(pathComponent(userId))",
            method: .get,
            payload: nil,
            authPolicy: .userRequired,
            sessionUserId: userId,
            completion: completion
        )
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
            ],
            authPolicy: .userRequired
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
        requestJSON(
            path: "/care/snapshots/latest/\(pathComponent(userId))",
            method: .get,
            payload: nil,
            authPolicy: .userRequired,
            sessionUserId: userId,
            completion: completion
        )
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
        requestJSON(
            path: "/devices/push-token",
            method: .post,
            payload: payload,
            authPolicy: .userRequired,
            completion: completion
        )
    }

    func scheduleEchoDelayedReplyPush(
        userId: String,
        delayedReply: EchoDelayedReply,
        rawTranscript: String,
        completion: @escaping (Result<[String: Any], Error>) -> Void
    ) {
        var payload: [String: Any] = [
            "userId": userId,
            "delayedReplyId": delayedReply.id,
            "deliverAt": ISO8601DateFormatter().string(from: delayedReply.deliverAt),
            "minutes": delayedReply.minutes,
            "trigger": delayedReply.trigger.rawValue,
            "rawTranscript": rawTranscript,
        ]
        if let registration = PushDeviceTokenStore.shared.registration(for: userId) {
            let registeredDeviceTokenPayload: [String: Any] = ["deviceTokenId": registration.deviceTokenId]
            payload.merge(registeredDeviceTokenPayload) { _, new in new }
        }
        requestJSON(
            path: "/echo/delayed-replies",
            method: .post,
            payload: payload,
            authPolicy: .userRequired,
            completion: completion
        )
    }

    private func requestJSON(
        path: String,
        method: HTTPMethod,
        payload: [String: Any]?,
        authPolicy: RequestAuthPolicy,
        allowsRefresh: Bool = true,
        allowsRecoveryRefresh: Bool = true,
        recoveryClearSession: BackendAuthSessionContract? = nil,
        mutatesAuthenticatedSessionForRecoveryPolicy: Bool = true,
        requiredAuthSession: BackendAuthSessionContract? = nil,
        accountLease: BackendAccountLease? = nil,
        applicationLease: AccountLease? = nil,
        sessionUserId: String? = nil,
        featureDecision: FeatureDecision? = nil,
        additionalHeaders: [String: String] = [:],
        completion: @escaping (Result<[String: Any], Error>) -> Void
    ) {
        let endpoint = EndpointDescriptor(
            path: path,
            method: method,
            authPolicy: authPolicy,
            payload: payload,
            sessionUserId: sessionUserId
        )
        let requestAuthSession: BackendAuthSessionContract?
        let requestAccountLease: BackendAccountLease?
        let requestApplicationLease: AccountLease?
        switch endpoint.authPolicy {
        case .userRequired:
            guard UserManager.shared.canEnterPrivateUI else {
                DispatchQueue.main.async {
                    completion(.failure(ClientError.userAuthenticationRequired))
                }
                return
            }
            let currentSession = authSessionStore.currentSession
            guard let authenticatedSession = currentSession else {
                DispatchQueue.main.async {
                    completion(.failure(ClientError.userAuthenticationRequired))
                }
                return
            }
            guard authenticatedSession.isPrivateAccessEligible else {
                DispatchQueue.main.async {
                    completion(.failure(ClientError.sessionUpgradeRequired(
                        minimumBuild: nil,
                        accessMode: "signedOut"
                    )))
                }
                return
            }
            guard endpoint.sessionUserAssertions.allSatisfy({ $0 == authenticatedSession.userId }) else {
                DispatchQueue.main.async {
                    completion(.failure(ClientError.accountScopeChanged))
                }
                return
            }
            if let requiredAuthSession,
               currentSession?.matchesCASIdentity(requiredAuthSession) != true {
                DispatchQueue.main.async {
                    completion(.failure(ClientError.accountScopeChanged))
                }
                return
            }
            let selectedSession = requiredAuthSession ?? authenticatedSession
            requestAuthSession = selectedSession
            let capturedLease = accountLease ?? BackendAccountLease(session: selectedSession)
            guard capturedLease.permits(
                session: requestAuthSession,
                currentUserId: UserManager.shared.currentUser?.id
            ) else {
                DispatchQueue.main.async {
                    completion(.failure(ClientError.accountScopeChanged))
                }
                return
            }
            requestAccountLease = capturedLease
            let capturedApplicationLease = applicationLease
                ?? accountLeaseRuntime.capture(forSubjectId: selectedSession.userId)
            guard let capturedApplicationLease,
                  accountLeaseRuntime.validate(capturedApplicationLease, at: .request).allowed else {
                DispatchQueue.main.async {
                    completion(.failure(ClientError.accountScopeChanged))
                }
                return
            }
            requestApplicationLease = capturedApplicationLease
        case .publicRequest, .refreshExchange:
            requestAuthSession = nil
            requestAccountLease = nil
            requestApplicationLease = nil
        }

        let recoveryDecision = RecoveryRuntimePolicyStore.shared.requestDecision(
            method: method.rawValue,
            path: path
        )
        if !recoveryDecision.allowed {
            if allowsRecoveryRefresh, path != "/config/runtime" {
                fetchRuntimeConfig { result in
                    guard self.isCurrentAccountLease(
                        requestAccountLease,
                        applicationLease: requestApplicationLease,
                        at: .commit
                    ) else {
                        completion(.failure(ClientError.accountScopeChanged))
                        return
                    }
                    switch result {
                    case .success:
                        self.requestJSON(
                            path: path,
                            method: method,
                            payload: payload,
                            authPolicy: authPolicy,
                            allowsRefresh: allowsRefresh,
                            allowsRecoveryRefresh: false,
                            recoveryClearSession: recoveryClearSession,
                            mutatesAuthenticatedSessionForRecoveryPolicy: mutatesAuthenticatedSessionForRecoveryPolicy,
                            requiredAuthSession: requiredAuthSession,
                            accountLease: requestAccountLease,
                            applicationLease: requestApplicationLease,
                            sessionUserId: sessionUserId,
                            featureDecision: featureDecision,
                            additionalHeaders: additionalHeaders,
                            completion: completion
                        )
                    case .failure:
                        let current = self.recoveryRuntimePolicyStore.currentPolicy
                        let denied = self.recoveryRuntimePolicyStore.requestDecision(
                            method: method.rawValue,
                            path: path
                        )
                        completion(.failure(ClientError.recoveryAccessDenied(
                            mode: current.mode.rawValue,
                            code: denied.code,
                            reason: denied.reason
                        )))
                    }
                }
                return
            }
            let current = recoveryRuntimePolicyStore.currentPolicy
            DispatchQueue.main.async {
                completion(.failure(ClientError.recoveryAccessDenied(
                    mode: current.mode.rawValue,
                    code: recoveryDecision.code,
                    reason: recoveryDecision.reason
                )))
            }
            return
        }

        let gatedFeature = FeatureGateService.shared.featureForRequest(
            path: path,
            method: method,
            payload: payload
        )
        let preparedFeatureDecision: FeatureDecision?
        if let featureDecision {
            preparedFeatureDecision = FeatureGateService.shared.revalidateRequest(featureDecision)
        } else if let gatedFeature {
            preparedFeatureDecision = FeatureGateService.shared.requestDecision(for: gatedFeature)
        } else {
            preparedFeatureDecision = nil
        }
        if let preparedFeatureDecision, !preparedFeatureDecision.allowed {
            DispatchQueue.main.async {
                completion(.failure(ClientError.featurePolicyDenied(
                    feature: preparedFeatureDecision.feature.rawValue,
                    reason: preparedFeatureDecision.reason
                )))
            }
            return
        }

        let url = "\(baseURL)\(endpoint.path)"
        var baselineHeaders = authHeaders(for: endpoint.authPolicy, session: requestAuthSession) ?? HTTPHeaders()
        baselineHeaders.add(
            name: "X-DreamJourney-Client-Build",
            value: String(FeatureGateService.shared.clientBuild)
        )
        baselineHeaders.add(
            name: "X-DreamJourney-Auth-Contract-Version",
            value: String(requestAuthSession?.contractVersion ?? (endpoint.authPolicy == .refreshExchange ? 2 : 0))
        )
        baselineHeaders.add(name: "X-DreamJourney-Request-Purpose", value: endpoint.purpose)
        baselineHeaders.add(name: "X-DreamJourney-Owner-Binding", value: endpoint.ownerBinding)
        var requestHeaders: HTTPHeaders? = baselineHeaders
        if !additionalHeaders.isEmpty {
            var headers = requestHeaders ?? HTTPHeaders()
            for (name, value) in additionalHeaders {
                headers.add(name: name, value: value)
            }
            requestHeaders = headers
        }
        if let preparedFeatureDecision {
            var headers = requestHeaders ?? HTTPHeaders()
            for (name, value) in FeatureGateService.shared.metadataHeaders(for: preparedFeatureDecision) {
                headers.add(name: name, value: value)
            }
            requestHeaders = headers
        }
        AF.request(
            url,
            method: endpoint.method,
            parameters: payload,
            encoding: JSONEncoding.default,
            headers: requestHeaders
        )
            .validate(statusCode: 200..<300)
            .responseData(queue: .global(qos: .utility)) { response in
                guard self.isCurrentAccountLease(
                    requestAccountLease,
                    applicationLease: requestApplicationLease,
                    at: .commit
                ) else {
                    self.deliverRequestResult(
                        .failure(ClientError.accountScopeChanged),
                        accountLease: nil,
                        applicationLease: nil,
                        completion: completion
                    )
                    return
                }
                switch response.result {
                case .success(let data):
                    do {
                        let json = try JSONSerialization.jsonObject(with: data)
                        guard let object = json as? [String: Any] else {
                            self.deliverRequestResult(
                                .failure(ClientError.unsupportedJSONRoot),
                                accountLease: requestAccountLease,
                                applicationLease: requestApplicationLease,
                                completion: completion
                            )
                            return
                        }
                        self.deliverRequestResult(
                            .success(object),
                            accountLease: requestAccountLease,
                            applicationLease: requestApplicationLease,
                            completion: completion
                        )
                    } catch {
                        self.deliverRequestResult(
                            .failure(ClientError.invalidJSONResponse),
                            accountLease: requestAccountLease,
                            applicationLease: requestApplicationLease,
                            completion: completion
                        )
                    }
                case .failure(let error):
                    let statusCode = response.response?.statusCode
                    if let recoveryPolicy = Self.recoveryRuntimePolicy(from: response.data) {
                        DispatchQueue.main.async {
                            guard self.isCurrentAccountLease(
                                requestAccountLease,
                                applicationLease: requestApplicationLease,
                                at: .ui
                            ) else {
                                completion(.failure(ClientError.accountScopeChanged))
                                return
                            }
                            self.adoptRecoveryRuntimePolicy(
                                recoveryPolicy,
                                clearSessionIfCurrentMatches: recoveryClearSession,
                                mutateAuthenticatedSession: mutatesAuthenticatedSessionForRecoveryPolicy
                            )
                            let denied = recoveryPolicy.requestDecision(
                                method: method.rawValue,
                                path: path
                            )
                            completion(.failure(ClientError.recoveryAccessDenied(
                                mode: recoveryPolicy.mode.rawValue,
                                code: denied.code,
                                reason: denied.reason
                            )))
                        }
                        return
                    }
                    if statusCode == 426 {
                        let contract = Self.clientUpgradeContract(from: response.data)
                        if let userId = requestAuthSession?.userId {
                            UserManager.shared.suspendPrivateAccess(
                                for: userId,
                                reason: "clientUpgradeRequired"
                            )
                        }
                        self.deliverRequestResult(
                            .failure(ClientError.sessionUpgradeRequired(
                                minimumBuild: contract.minimumBuild,
                                accessMode: contract.accessMode
                            )),
                            accountLease: requestAccountLease,
                            applicationLease: requestApplicationLease,
                            completion: completion
                        )
                        return
                    }
                    if statusCode == 401,
                       allowsRefresh,
                       authPolicy == .userRequired,
                       let requestAuthSession,
                       let currentSession = self.authSessionStore.currentSession {
                        if currentSession.isValidRefreshSuccessor(of: requestAuthSession) {
                            self.requestJSON(
                                path: path,
                                method: method,
                                payload: payload,
                                authPolicy: authPolicy,
                                allowsRefresh: false,
                                allowsRecoveryRefresh: allowsRecoveryRefresh,
                                recoveryClearSession: recoveryClearSession,
                                mutatesAuthenticatedSessionForRecoveryPolicy: mutatesAuthenticatedSessionForRecoveryPolicy,
                                requiredAuthSession: currentSession,
                                accountLease: requestAccountLease,
                                applicationLease: requestApplicationLease,
                                sessionUserId: sessionUserId,
                                featureDecision: preparedFeatureDecision,
                                additionalHeaders: additionalHeaders,
                                completion: completion
                            )
                            return
                        }
                        guard currentSession.matchesCASIdentity(requestAuthSession) else {
                            let context = Self.backendErrorContext(from: response.data)
                                ?? .init(
                                    code: "auth_session_changed",
                                    detail: "登录状态已变化，请重试"
                                )
                            self.deliverRequestResult(
                                .failure(ClientError.backendError(
                                    statusCode: statusCode,
                                    context: context
                                )),
                                accountLease: requestAccountLease,
                                applicationLease: requestApplicationLease,
                                completion: completion
                            )
                            return
                        }
                        self.refreshAuthSession(for: requestAuthSession) { refreshedSession in
                            guard self.isCurrentAccountLease(
                                requestAccountLease,
                                applicationLease: requestApplicationLease,
                                at: .commit
                            ) else {
                                completion(.failure(ClientError.accountScopeChanged))
                                return
                            }
                            if let refreshedSession {
                                self.requestJSON(
                                    path: path,
                                    method: method,
                                    payload: payload,
                                    authPolicy: authPolicy,
                                    allowsRefresh: false,
                                    allowsRecoveryRefresh: allowsRecoveryRefresh,
                                    recoveryClearSession: recoveryClearSession,
                                    mutatesAuthenticatedSessionForRecoveryPolicy: mutatesAuthenticatedSessionForRecoveryPolicy,
                                    requiredAuthSession: refreshedSession,
                                    accountLease: requestAccountLease,
                                    applicationLease: requestApplicationLease,
                                    sessionUserId: sessionUserId,
                                    featureDecision: preparedFeatureDecision,
                                    additionalHeaders: additionalHeaders,
                                    completion: completion
                                )
                            } else {
                                UserManager.shared.suspendPrivateAccess(
                                    for: requestAuthSession.userId,
                                    reason: "authRefreshUnavailable"
                                )
                                let context = Self.backendErrorContext(from: response.data)
                                    ?? .init(detail: "登录状态已失效，请重新登录")
                                completion(.failure(ClientError.backendError(
                                    statusCode: statusCode,
                                    context: context
                                )))
                            }
                        }
                        return
                    }
                    if let context = Self.backendErrorContext(from: response.data) {
                        self.deliverRequestResult(
                            .failure(ClientError.backendError(
                                statusCode: statusCode,
                                context: context
                            )),
                            accountLease: requestAccountLease,
                            applicationLease: requestApplicationLease,
                            completion: completion
                        )
                        return
                    }
                    if let statusCode {
                        self.deliverRequestResult(
                            .failure(ClientError.backendError(
                                statusCode: statusCode,
                                context: .init(detail: error.localizedDescription)
                            )),
                            accountLease: requestAccountLease,
                            applicationLease: requestApplicationLease,
                            completion: completion
                        )
                    } else {
                        self.deliverRequestResult(
                            .failure(error),
                            accountLease: requestAccountLease,
                            applicationLease: requestApplicationLease,
                            completion: completion
                        )
                    }
                }
            }
    }

    private func isCurrentAccountLease(
        _ lease: BackendAccountLease?,
        applicationLease: AccountLease?,
        at checkpoint: AccountLeaseCheckpoint
    ) -> Bool {
        if let lease,
           !lease.permits(
               session: authSessionStore.currentSession,
               currentUserId: UserManager.shared.currentUser?.id
           ) {
            return false
        }
        guard let applicationLease else { return lease == nil }
        return accountLeaseRuntime.validate(applicationLease, at: checkpoint).allowed
    }

    private func deliverRequestResult(
        _ result: Result<[String: Any], Error>,
        accountLease: BackendAccountLease?,
        applicationLease: AccountLease?,
        completion: @escaping (Result<[String: Any], Error>) -> Void
    ) {
        DispatchQueue.main.async {
            guard self.isCurrentAccountLease(
                accountLease,
                applicationLease: applicationLease,
                at: .ui
            ) else {
                completion(.failure(ClientError.accountScopeChanged))
                return
            }
            completion(result)
        }
    }

    private func adoptRecoveryRuntimePolicy(
        _ policy: BackendRecoveryRuntimePolicy,
        clearSessionIfCurrentMatches capturedSession: BackendAuthSessionContract? = nil,
        mutateAuthenticatedSession: Bool = true
    ) {
        let transition = recoveryRuntimePolicyStore.update(policy)
        accountLeaseRuntime.updateAuthorityEpoch(policy.authorityEpoch)
        if transition.authorityEpochChanged {
            RuntimeCapabilitySnapshotStore.shared.invalidate()
            NotificationCenter.default.post(
                name: .djRecoveryAuthorityEpochDidChange,
                object: nil,
                userInfo: [
                    "previousAuthorityEpoch": transition.previousAuthorityEpoch,
                    "authorityEpoch": transition.currentAuthorityEpoch,
                ]
            )
        }
        guard mutateAuthenticatedSession else { return }
        if policy.mode == .signedOut || policy.authenticatedSessionPolicy == "clear" {
            let sessionToClear = capturedSession ?? authSessionStore.currentSession
            let didClear: Bool
            if let capturedSession {
                didClear = authSessionStore.clear(ifCurrentMatches: capturedSession)
            } else {
                authSessionStore.clear()
                didClear = sessionToClear != nil
            }
            if didClear, let userId = sessionToClear?.userId {
                UserManager.shared.invalidateBackendSession(for: userId)
            }
        } else if policy.authenticatedSessionPolicy == "suspend",
                  let userId = (capturedSession ?? authSessionStore.currentSession)?.userId {
            UserManager.shared.suspendPrivateAccess(
                for: userId,
                reason: "recoveryPolicySuspended"
            )
        }
    }

    private static func recoveryRuntimePolicy(from data: Data?) -> BackendRecoveryRuntimePolicy? {
        guard let data,
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let recovery = json["recovery"] as? [String: Any] else {
            return nil
        }
        return BackendRecoveryRuntimePolicy(json: recovery)
    }

    private static func clientUpgradeContract(from data: Data?) -> (minimumBuild: Int?, accessMode: String) {
        guard let data,
              let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let detail = object["detail"] as? [String: Any] else {
            return (nil, "readOnly")
        }
        let minimumBuild: Int?
        if let value = detail["minimumClientBuild"] as? Int {
            minimumBuild = value
        } else if let value = detail["minimumClientBuild"] as? NSNumber {
            minimumBuild = value.intValue
        } else if let value = detail["minimumClientBuild"] as? String {
            minimumBuild = Int(value)
        } else {
            minimumBuild = nil
        }
        let accessMode = normalizedBackendErrorString(detail["accessMode"]) ?? "readOnly"
        return (minimumBuild, accessMode)
    }

    @discardableResult
    private func adoptAuthSession(from object: [String: Any]) throws -> Bool {
        guard let session = try decodedAuthSession(from: object) else {
            authSessionStore.clear()
            return false
        }
        guard session.isPrivateAccessEligible else {
            authSessionStore.clear()
            throw ClientError.sessionUpgradeRequired(minimumBuild: nil, accessMode: "signedOut")
        }
        try authSessionStore.save(session)
        return true
    }

    private func decodedAuthSession(from object: [String: Any]) throws -> BackendAuthSessionContract? {
        guard let authObject = object["auth"] else {
            return nil
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
        return session
    }

    private func accountCredentialSnapshot(
        for session: BackendAuthSessionContract
    ) -> AccountSessionCredentialSnapshot? {
        guard session.isPrivateAccessEligible,
              let tokenFamilyId = session.tokenFamilyId,
              let sessionVersion = session.sessionVersion else {
            return nil
        }
        return AccountSessionCredentialSnapshot(
            subjectId: session.userId,
            vaultId: session.userId,
            sessionId: session.sessionId,
            tokenFamilyId: tokenFamilyId,
            sessionVersion: sessionVersion,
            isPrivateAccessEligible: true,
            trust: .requiresOnlineValidation
        )
    }

    private func refreshAuthSession(
        for capturedSession: BackendAuthSessionContract,
        completion: @escaping (BackendAuthSessionContract?) -> Void
    ) {
        guard let credential = accountCredentialSnapshot(for: capturedSession) else {
            authSessionStore.clear(ifCurrentMatches: capturedSession)
            UserManager.shared.invalidateBackendSession(for: capturedSession.userId)
            DispatchQueue.main.async { completion(nil) }
            return
        }
        let clientReference = AuthRefreshClientReference(value: self)
        Task { [accountSessionActor, clientReference] in
            guard let accountLease = await accountSessionActor.captureRefreshLease(for: credential) else {
                DispatchQueue.main.async { completion(nil) }
                return
            }
            clientReference.value.authRefreshQueue.async {
                let client = clientReference.value
                if var active = client.activeAuthRefreshGroup,
                   active.capturedSession.matchesCASIdentity(capturedSession),
                   active.accountLease == accountLease {
                    active.waiters.append(completion)
                    client.activeAuthRefreshGroup = active
                    return
                }

                if let index = client.pendingAuthRefreshGroups.firstIndex(where: {
                    $0.capturedSession.matchesCASIdentity(capturedSession)
                        && $0.accountLease == accountLease
                }) {
                    client.pendingAuthRefreshGroups[index].waiters.append(completion)
                } else {
                    client.pendingAuthRefreshGroups.append(.init(
                        capturedSession: capturedSession,
                        accountLease: accountLease,
                        waiters: [completion]
                    ))
                }
                client.startNextAuthRefreshIfNeeded()
            }
        }
    }

    private func startNextAuthRefreshIfNeeded() {
        dispatchPrecondition(condition: .onQueue(authRefreshQueue))
        guard activeAuthRefreshGroup == nil,
              !pendingAuthRefreshGroups.isEmpty else {
            return
        }

        let group = pendingAuthRefreshGroups.removeFirst()
        guard authSessionStore.currentSession?.matchesCASIdentity(group.capturedSession) == true else {
            DispatchQueue.main.async {
                group.waiters.forEach { $0(nil) }
            }
            startNextAuthRefreshIfNeeded()
            return
        }

        activeAuthRefreshGroup = group
        let clientReference = AuthRefreshClientReference(value: self)
        Task { [accountSessionActor, clientReference] in
            let isCurrent = await accountSessionActor.isCurrentRefreshLease(group.accountLease)
            clientReference.value.authRefreshQueue.async {
                let client = clientReference.value
                guard let active = client.activeAuthRefreshGroup,
                      active.capturedSession.matchesCASIdentity(group.capturedSession),
                      active.accountLease == group.accountLease else {
                    return
                }
                guard isCurrent else {
                    client.finishAuthRefresh(
                        capturedSession: group.capturedSession,
                        accountLease: group.accountLease,
                        refreshedSession: nil
                    )
                    return
                }
                client.performAuthRefresh(group)
            }
        }
    }

    private func performAuthRefresh(_ group: AuthRefreshGroup) {
        dispatchPrecondition(condition: .onQueue(authRefreshQueue))
        let capturedSession = group.capturedSession
        let accountLease = group.accountLease
        requestJSON(
                path: "/auth/refresh",
                method: .post,
                payload: ["refreshToken": capturedSession.refreshToken],
                authPolicy: .refreshExchange,
                allowsRefresh: false,
                allowsRecoveryRefresh: false,
                recoveryClearSession: capturedSession,
                mutatesAuthenticatedSessionForRecoveryPolicy: false
            ) { result in
                switch result {
                case .success(let object):
                    do {
                        if let session = try self.decodedAuthSession(from: object),
                           session.isValidRefreshSuccessor(of: capturedSession),
                           let credential = self.accountCredentialSnapshot(for: session) {
                            let store = self.authSessionStore
                            let clientReference = AuthRefreshClientReference(value: self)
                            Task {
                                let client = clientReference.value
                                let accountSessionActor = client.accountSessionActor
                                let committed = await accountSessionActor.commitRefreshedCredential(
                                    credential,
                                    lease: accountLease,
                                    writer: {
                                        try store.replace(
                                            session,
                                            ifCurrentMatches: capturedSession
                                        )
                                    }
                                )
                                clientReference.value.authRefreshQueue.async {
                                    let client = clientReference.value
                                    client.finishAuthRefresh(
                                        capturedSession: capturedSession,
                                        accountLease: accountLease,
                                        refreshedSession: committed ? session : nil
                                    )
                                }
                            }
                            return
                        }
                    } catch {
                        break
                    }
                case .failure(let error):
                    if Self.isTerminalAuthRefreshError(error) {
                        let store = self.authSessionStore
                        let clientReference = AuthRefreshClientReference(value: self)
                        Task {
                            let client = clientReference.value
                            let accountSessionActor = client.accountSessionActor
                            let didInvalidate = await accountSessionActor.invalidateRefreshLease(
                                accountLease,
                                reason: "terminalAuthRefreshFailure",
                                clear: {
                                    store.clear(ifCurrentMatches: capturedSession)
                                }
                            )
                            if didInvalidate {
                                DispatchQueue.main.async {
                                    UserManager.shared.invalidateBackendSession(
                                        for: capturedSession.userId
                                    )
                                }
                            }
                            clientReference.value.authRefreshQueue.async {
                                let client = clientReference.value
                                client.finishAuthRefresh(
                                    capturedSession: capturedSession,
                                    accountLease: accountLease,
                                    refreshedSession: nil
                                )
                            }
                        }
                        return
                    }
                }
                self.authRefreshQueue.async {
                    self.finishAuthRefresh(
                        capturedSession: capturedSession,
                        accountLease: accountLease,
                        refreshedSession: nil
                    )
                }
            }
    }

    private func finishAuthRefresh(
        capturedSession: BackendAuthSessionContract,
        accountLease: AccountSessionRefreshLease,
        refreshedSession: BackendAuthSessionContract?
    ) {
        dispatchPrecondition(condition: .onQueue(authRefreshQueue))
        guard let active = activeAuthRefreshGroup,
              active.capturedSession.matchesCASIdentity(capturedSession),
              active.accountLease == accountLease else {
            return
        }
        activeAuthRefreshGroup = nil
        DispatchQueue.main.async {
            active.waiters.forEach { $0(refreshedSession) }
        }
        startNextAuthRefreshIfNeeded()
    }

    private static func isTerminalAuthRefreshError(_ error: Error) -> Bool {
        guard case ClientError.backendError(let statusCode, let context) = error,
              statusCode == 401,
              let code = context.code else {
            return false
        }
        return [
            "invalid_or_expired_refresh_token",
            "legacy_session_reauth_required",
            "refresh_token_reuse_detected",
            "token_family_revoked",
            "session_revoked",
        ].contains(code)
    }

    private func validatedDigitalHumanLeasePath(_ candidate: String, fallback: String) -> String {
        guard candidate.hasPrefix("/digital-human/sessions/"),
              !candidate.contains("?"),
              !candidate.contains("#") else {
            return fallback
        }
        return candidate
    }

    private static func backendErrorContext(from data: Data?) -> BackendErrorContext? {
        guard let data, !data.isEmpty else { return nil }

        if let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
            if let detail = object["detail"] as? [String: Any] {
                let code = normalizedBackendErrorString(detail["code"])
                let operationId = normalizedBackendErrorString(detail["operationId"])
                let message = normalizedBackendErrorString(detail["message"])
                    ?? normalizedBackendErrorString(detail["error"])
                    ?? code
                    ?? "后端请求失败"
                return BackendErrorContext(
                    code: code,
                    operationId: operationId,
                    detail: message
                )
            }
            if let detail = normalizedBackendErrorString(object["detail"]) {
                return BackendErrorContext(detail: detail)
            }
            if let message = normalizedBackendErrorString(object["message"]) {
                return BackendErrorContext(detail: message)
            }
            if let error = normalizedBackendErrorString(object["error"]) {
                return BackendErrorContext(detail: error)
            }
        }

        guard let text = String(data: data, encoding: .utf8)?
            .trimmingCharacters(in: .whitespacesAndNewlines),
              !text.isEmpty else {
            return nil
        }
        return BackendErrorContext(detail: String(text.prefix(240)))
    }

    private static func normalizedBackendErrorString(_ value: Any?) -> String? {
        guard let value = value as? String else { return nil }
        let normalized = value.trimmingCharacters(in: .whitespacesAndNewlines)
        return normalized.isEmpty ? nil : normalized
    }

    private func authHeaders(
        for policy: RequestAuthPolicy,
        session: BackendAuthSessionContract?
    ) -> HTTPHeaders? {
        guard policy == .userRequired,
              let session else {
            return nil
        }
        return HTTPHeaders([
            "Authorization": "Bearer \(session.accessToken)",
            "X-DreamJourney-User-Id": session.userId,
        ])
    }

    private func pathComponent(_ value: String) -> String {
        var allowed = CharacterSet.urlPathAllowed
        allowed.remove(charactersIn: "/?#[]@!$&'()*+,;=")
        return value.addingPercentEncoding(withAllowedCharacters: allowed) ?? value
    }

    private func queryComponent(_ value: String) -> String {
        var allowed = CharacterSet.alphanumerics
        allowed.insert(charactersIn: "-._~")
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
