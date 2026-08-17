import Foundation

#if DEBUG || UI_QA_SIMULATOR
struct DialogPromptDebugSnapshot {
    let prompt: String
    let containsArchiveContext: Bool
    let recordedAt: Date
}

enum DialogPromptDebugRecorder {
    private(set) static var lastSnapshot: DialogPromptDebugSnapshot?

    static func record(prompt: String, recordedAt: Date = Date()) {
        lastSnapshot = DialogPromptDebugSnapshot(
            prompt: prompt,
            containsArchiveContext: prompt.contains("【记忆档案馆素材线索】"),
            recordedAt: recordedAt
        )
    }

    static func reset() {
        lastSnapshot = nil
    }
}
#endif

private func shouldExposePersonalContext(for context: DigitalHumanContext) -> Bool {
    context.mode != .silent
}

private func shouldExposeArchiveContext(for context: DigitalHumanContext) -> Bool {
    shouldExposePersonalContext(for: context)
}

private func buildDigitalHumanModePolicy(context: DigitalHumanContext) -> String {
    switch context.mode {
    case .sunlight:
        return """


        【当前回响边界】
        - 当前对象用于日常陪伴与记忆整理，语气保持自然、温和、不过度心理化。
        - 不要在对话中说出内部状态名称，也不要解释系统如何分类对象。
        """
    case .star:
        return """


        【关怀回应边界】
        - 当前对象需要更谨慎的陪伴式回应；可以温和关注情绪、睡眠、孤独感和风险信号。
        - 这不是医疗诊断，也不能替代心理医生、精神科医生或急救服务。
        - 遇到强烈痛苦、危险表达或自伤风险时，先共情、降低追问强度，并建议联系身边家人或当地紧急服务。
        - 不要在对话中说出内部状态名称，也不要解释系统如何分类对象。
        """
    case .silent:
        return """


        【非公开展示边界】
        - 当前对象处于不公开展示边界，只保留最克制的陪伴回应。
        - 不主动引用档案素材、亲属线索或可能暴露隐私的历史内容。
        - 不要在对话中说出内部状态名称，也不要解释系统如何分类对象。
        """
    }
}

enum VoiceSDKReadinessState: String {
    case mockASRTTS
    case backendTokenFallback
    case providerCredentialBlocked
    case productionSDKNeedsTrueDeviceQA
    case productionSDKVerified
}

struct VoiceSDKReadinessSummary {
    let state: VoiceSDKReadinessState
    let title: String
    let detail: String
    let allowsProductionClosureClaim: Bool

    static func current(
        backendRuntimeConfigured: Bool,
        backendRuntimeTokenApplied: Bool,
        localConfigReady: Bool,
        productionVoiceSDKQualityVerified: Bool,
        isUIQAMock: Bool = isRunningUIQAMock
    ) -> VoiceSDKReadinessSummary {
        if isUIQAMock {
            return VoiceSDKReadinessSummary(
                state: .mockASRTTS,
                title: "UIQA mock ASR/TTS，仅验证状态机",
                detail: "模拟器只证明回响状态、等待回信和 UI 合同，不证明真实语音识别或播放质量。",
                allowsProductionClosureClaim: false
            )
        }

        guard backendRuntimeConfigured, backendRuntimeTokenApplied else {
            return VoiceSDKReadinessSummary(
                state: .providerCredentialBlocked,
                title: "实时语音凭据代理尚未开放",
                detail: "客户端不会使用共享 Provider 密钥；当前保留文字回响和明确的能力阻断状态。",
                allowsProductionClosureClaim: false
            )
        }

        guard localConfigReady, productionVoiceSDKQualityVerified else {
            return VoiceSDKReadinessSummary(
                state: .productionSDKNeedsTrueDeviceQA,
                title: "生产语音待真机验收",
                detail: "后端 token 和本地配置已可用，仍需真机完成麦克风、ASR、TTS、播放路由、前后台和日志证据。",
                allowsProductionClosureClaim: false
            )
        }

        return VoiceSDKReadinessSummary(
            state: .productionSDKVerified,
            title: "生产语音已通过真机验收",
            detail: "只有真机证据包齐全且无阻塞问题时才允许使用该状态。",
            allowsProductionClosureClaim: true
        )
    }

    private static var isRunningUIQAMock: Bool {
        #if UI_QA_SIMULATOR && targetEnvironment(simulator)
        return true
        #else
        return false
        #endif
    }
}

struct DialogEngineBindingHandle: Equatable, Sendable {
    fileprivate let bindingId: UUID
    fileprivate let ownerId: UUID
    let accountLease: AccountLease
}

/// Controls who owns the lifetime of a dialog session. Echo Live uses an
/// explicit user stop; other callers keep the existing keyword/idle behavior.
enum DialogSessionLifetimePolicy: Equatable, Sendable {
    case automatic
    case userControlledLive
}

enum DialogTextReplyPlaybackError: LocalizedError, Equatable {
    case invalidText
    case sessionBusy
    case unavailable
    case directiveRejected(code: Int)

    var errorDescription: String? {
        switch self {
        case .invalidText:
            return "回响内容为空"
        case .sessionBusy:
            return "实时语音会话正在使用中"
        case .unavailable:
            return "火山实时语音暂不可用"
        case .directiveRejected:
            return "火山实时语音暂未接受本次播报"
        }
    }
}

private func isSameDialogAccountGeneration(_ lhs: AccountLease, _ rhs: AccountLease) -> Bool {
    lhs.subjectId == rhs.subjectId
        && lhs.vaultId == rhs.vaultId
        && lhs.generation == rhs.generation
        && lhs.generationId == rhs.generationId
        && lhs.authorityEpoch == rhs.authorityEpoch
}

/// Local SpeechEngine playback can only use a profile selected by the current
/// Echo binding. This prevents a role switch from falling back to whichever
/// profile the process-global VoiceCloneService happens to expose.
struct DialogEngineScopedTTSVoiceSelection: Equatable, Sendable {
    let bindingID: UUID
    let accountLease: AccountLease
    let contextKey: String
    let lifecycleGeneration: UInt64
    let voiceProfileId: String?

    init?(
        bindingID: UUID,
        accountLease: AccountLease,
        contextKey: String,
        lifecycleGeneration: UInt64,
        voiceProfileId: String?
    ) {
        let normalizedContextKey = contextKey.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !normalizedContextKey.isEmpty else { return nil }

        self.bindingID = bindingID
        self.accountLease = accountLease
        self.contextKey = normalizedContextKey
        self.lifecycleGeneration = lifecycleGeneration
        let normalizedProfileId = voiceProfileId?.trimmingCharacters(in: .whitespacesAndNewlines)
        self.voiceProfileId = normalizedProfileId?.isEmpty == false ? normalizedProfileId : nil
    }

    func matches(bindingID: UUID, accountLease: AccountLease) -> Bool {
        self.bindingID == bindingID
            && isSameDialogAccountGeneration(self.accountLease, accountLease)
    }
}

struct DialogEngineScopedTTSVoiceSelectionStore {
    private(set) var selection: DialogEngineScopedTTSVoiceSelection?

    @discardableResult
    mutating func update(
        bindingID: UUID,
        accountLease: AccountLease,
        contextKey: String,
        lifecycleGeneration: UInt64,
        voiceProfileId: String?
    ) -> Bool {
        guard let candidate = DialogEngineScopedTTSVoiceSelection(
            bindingID: bindingID,
            accountLease: accountLease,
            contextKey: contextKey,
            lifecycleGeneration: lifecycleGeneration,
            voiceProfileId: voiceProfileId
        ) else {
            return false
        }

        if let selection,
           selection.bindingID == bindingID {
            guard isSameDialogAccountGeneration(selection.accountLease, accountLease),
                  candidate.lifecycleGeneration >= selection.lifecycleGeneration else {
                return false
            }
        }

        selection = candidate
        return true
    }

    func resolvedVoiceProfileId(
        bindingID: UUID,
        accountLease: AccountLease
    ) -> String? {
        guard let selection,
              selection.matches(bindingID: bindingID, accountLease: accountLease) else {
            return nil
        }
        return selection.voiceProfileId
    }

    @discardableResult
    mutating func clear(bindingID: UUID) -> Bool {
        guard selection?.bindingID == bindingID else { return false }
        selection = nil
        return true
    }

    mutating func clearAll() {
        selection = nil
    }
}

#if (UI_QA_SIMULATOR || RELEASE_SCOPE_SIMULATOR) && targetEnvironment(simulator)

enum DialogEndReason {
    case manual
    case keyword(String)
    case silenceTimeout
    case serverEnded
}

protocol DialogEngineDelegate: AnyObject {
    func onDialogStarted()
    func onASRResult(text: String, isFinal: Bool)
    func onTTSStarted(text: String)
    func onTTSFinished()
    func onChatStreaming(text: String)
    func onError(error: Error)
    func onDialogEnded(reason: DialogEndReason)
}

final class DialogEngineManager: NSObject {
    static let shared = DialogEngineManager()

    weak var delegate: DialogEngineDelegate?
    private let accountLeaseRuntime = AccountLeaseRuntime.shared
    private var boundAccountLease: AccountLease?
    private var activeDialogAccountLease: AccountLease?
    private var boundBindingHandle: DialogEngineBindingHandle?
    private var activeDialogBindingHandle: DialogEngineBindingHandle?
    private(set) var isEngineReady = false
    private(set) var isDialogActive = false
    private(set) var isRecorderPaused = false
    private(set) var sessionLifetimePolicy: DialogSessionLifetimePolicy = .automatic
    var currentTopic: String?
    var currentConfigurationIsProductionReady: Bool { false }
    private(set) var isLocalTTSPlaybackEnabled = true
    private(set) var usesTurnScopedKnowledgeContext = false
    private(set) var lastSubmittedTurnKnowledgeContextSource: String?
    private(set) var lastSubmittedTurnKnowledgeContextLength = 0
    private var scopedTTSVoiceSelectionStore = DialogEngineScopedTTSVoiceSelectionStore()
    private var externallyManagedAudioSessionLease: AudioOwnerLease?

    private override init() {
        super.init()
    }

    @discardableResult
    func bindAccountLease(
        _ accountLease: AccountLease,
        ownerId: UUID
    ) -> DialogEngineBindingHandle? {
        guard accountLeaseRuntime.validate(accountLease, at: .request).allowed else {
            return nil
        }

        if let boundBindingHandle,
           boundBindingHandle.ownerId == ownerId,
           isSameDialogAccountGeneration(boundBindingHandle.accountLease, accountLease) {
            let rotatedHandle = DialogEngineBindingHandle(
                bindingId: boundBindingHandle.bindingId,
                ownerId: ownerId,
                accountLease: accountLease
            )
            self.boundBindingHandle = rotatedHandle
            boundAccountLease = accountLease
            if activeDialogBindingHandle?.bindingId == rotatedHandle.bindingId {
                activeDialogBindingHandle = rotatedHandle
                activeDialogAccountLease = accountLease
            }
            return rotatedHandle
        }

        if boundBindingHandle != nil {
            isDialogActive = false
            activeDialogAccountLease = nil
            activeDialogBindingHandle = nil
            scopedTTSVoiceSelectionStore.clearAll()
            delegate = nil
        }
        let handle = DialogEngineBindingHandle(
            bindingId: UUID(),
            ownerId: ownerId,
            accountLease: accountLease
        )
        boundBindingHandle = handle
        boundAccountLease = accountLease
        return handle
    }

    @discardableResult
    func unbindAccountLease(_ handle: DialogEngineBindingHandle) -> Bool {
        guard boundBindingHandle == handle else { return false }
        boundBindingHandle = nil
        boundAccountLease = nil
        activeDialogBindingHandle = nil
        activeDialogAccountLease = nil
        isDialogActive = false
        externallyManagedAudioSessionLease = nil
        _ = scopedTTSVoiceSelectionStore.clear(bindingID: handle.bindingId)
        delegate = nil
        return true
    }

    func isCurrentBinding(_ handle: DialogEngineBindingHandle?) -> Bool {
        guard let handle,
              boundBindingHandle == handle else { return false }
        return accountLeaseRuntime.validate(handle.accountLease, at: .runtime).allowed
    }

    /// Echo owns the session through AudioSessionCoordinator; the dialog engine must
    /// only reuse the exact active lease and never configure it a second time.
    @discardableResult
    func adoptExternallyManagedAudioSessionLease(_ lease: AudioOwnerLease) -> Bool {
        guard AudioSessionCoordinator.shared.isCurrentActiveLease(lease) else {
            externallyManagedAudioSessionLease = nil
            return false
        }
        externallyManagedAudioSessionLease = lease
        return true
    }

    private func isActiveAccountLeaseValid(at checkpoint: AccountLeaseCheckpoint) -> Bool {
        guard let accountLease = activeDialogAccountLease ?? boundAccountLease else {
            return false
        }
        return accountLeaseRuntime.validate(accountLease, at: checkpoint).allowed
    }

    func configure(runtimeConfig: RealtimeVoiceRuntimeConfig) -> Bool { !runtimeConfig.isBlocked }
    func interruptAI() {}
    @discardableResult
    func setLocalTTSPlaybackEnabled(_ enabled: Bool) -> Bool {
        isLocalTTSPlaybackEnabled = enabled
        return true
    }

    @discardableResult
    func setLocalTTSVoiceSelection(
        voiceProfileId: String?,
        contextKey: String,
        lifecycleGeneration: UInt64,
        for handle: DialogEngineBindingHandle
    ) -> Bool {
        guard isCurrentBinding(handle) else { return false }
        return scopedTTSVoiceSelectionStore.update(
            bindingID: handle.bindingId,
            accountLease: handle.accountLease,
            contextKey: contextKey,
            lifecycleGeneration: lifecycleGeneration,
            voiceProfileId: voiceProfileId
        )
    }

    func setup() {
        guard isActiveAccountLeaseValid(at: .request) else { return }
        isEngineReady = true
    }

    func startDialog(
        sendsGreeting: Bool = true,
        usesTurnScopedKnowledgeContext: Bool = false,
        lifetimePolicy: DialogSessionLifetimePolicy = .automatic
    ) {
        guard isActiveAccountLeaseValid(at: .request),
              let accountLease = boundAccountLease,
              let bindingHandle = boundBindingHandle else { return }
        activeDialogAccountLease = accountLease
        activeDialogBindingHandle = bindingHandle
        self.usesTurnScopedKnowledgeContext = usesTurnScopedKnowledgeContext
        sessionLifetimePolicy = lifetimePolicy
        isRecorderPaused = false
        recordUIQAPromptSnapshot()
        isDialogActive = true
        if isActiveAccountLeaseValid(at: .runtime) {
            delegate?.onDialogStarted()
        }
    }

    @discardableResult
    func startTextReplyPlayback(
        text: String,
        onStarted: @escaping () -> Void,
        completion: @escaping (Result<Void, Error>) -> Void
    ) -> Bool {
        let normalized = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !normalized.isEmpty else {
            completion(.failure(DialogTextReplyPlaybackError.invalidText))
            return false
        }
        guard !isDialogActive else {
            completion(.failure(DialogTextReplyPlaybackError.sessionBusy))
            return false
        }
        onStarted()
        completion(.success(()))
        return true
    }

    func cancelTextReplyPlayback() {}

    @discardableResult
    func pauseRecorder() -> Bool {
        guard isDialogActive else { return false }
        isRecorderPaused = true
        return true
    }

    @discardableResult
    func resumeRecorder() -> Bool {
        guard isDialogActive else { return false }
        isRecorderPaused = false
        return true
    }

    @discardableResult
    func submitTurnKnowledgeContext(
        _ content: String,
        traceID: String?,
        source: String
    ) -> Bool {
        guard isDialogActive,
              isActiveAccountLeaseValid(at: .runtime) else { return false }
        lastSubmittedTurnKnowledgeContextSource = source
        lastSubmittedTurnKnowledgeContextLength = content.utf8.count
        print(
            "[DialogEngine][UIQA] turn RAG submitted " +
            "source=\(source) traceID=\(traceID ?? "none") bytes=\(content.utf8.count)"
        )
        return true
    }

    func stopDialog() {
        guard isDialogActive else { return }
        let shouldDeliver = isActiveAccountLeaseValid(at: .runtime)
        isDialogActive = false
        isRecorderPaused = false
        activeDialogBindingHandle = nil
        activeDialogAccountLease = nil
        if shouldDeliver {
            delegate?.onDialogEnded(reason: .manual)
        }
    }

    func destroyEngine() {
        isEngineReady = false
        isDialogActive = false
        isRecorderPaused = false
        sessionLifetimePolicy = .automatic
        activeDialogBindingHandle = nil
        activeDialogAccountLease = nil
        usesTurnScopedKnowledgeContext = false
        externallyManagedAudioSessionLease = nil
        delegate = nil
    }

    private func recordUIQAPromptSnapshot() {
        #if DEBUG || UI_QA_SIMULATOR
        var prompt = "【UI QA 回响 Prompt】\n你是寻梦环游 AI 助手，不是真人或任何家庭成员本人。请以温和、自然的方式回应长辈。"
        let context = DigitalHumanContextStore.shared.current
        prompt += buildDigitalHumanModePolicy(context: context)
        let archiveSnapshot = MemoryArchiveRepository.shared.contextSnapshot()
        let archiveContext = archiveSnapshot.promptSection
        // Legacy UIQA archive smoke still inspects this synthetic prompt. The production
        // engine suppresses the same startup section when turn-scoped RAG is enabled.
        if shouldExposePersonalContext(for: context), !archiveContext.isEmpty {
            prompt += archiveContext
        }

        DialogPromptDebugRecorder.record(prompt: prompt)
        let snapshot = DialogPromptDebugRecorder.lastSnapshot
        print(
            "[UI_QA] Echo archive prompt containsArchiveContext=\(snapshot?.containsArchiveContext == true) " +
            "available=\(archiveSnapshot.availableItemCount) " +
            "entries=\(archiveSnapshot.debugSummary())"
        )
        #endif
    }
}

enum DialogEngineError: LocalizedError {
    case productionConfigurationMissing
    case initFailed(code: Int)
    case startFailed(code: Int)
    case audioSessionFailed
    case sdkError(code: Int, message: String)

    var errorDescription: String? {
        switch self {
        case .productionConfigurationMissing:
            return "实时语音凭据代理尚未开放，当前可继续使用文字回响"
        case .initFailed(let code):
            return "语音引擎初始化失败 (错误码: \(code))"
        case .startFailed(let code):
            return "语音对话启动失败 (错误码: \(code))"
        case .audioSessionFailed:
            return "音频配置失败，请重试"
        case .sdkError(_, let message):
            return "语音服务异常: \(message)"
        }
    }
}
#else
import Foundation
import AVFoundation
import CocoaLumberjack
import SpeechEngineToB

// MARK: - 对话结束原因

enum DialogEndReason {
    case manual            // 用户手动停止
    case keyword(String)   // 识别到结束关键词
    case silenceTimeout    // 静音超时
    case serverEnded       // 服务端结束
}

// MARK: - DialogEngineDelegate 协议

/// Dialog 引擎对外回调协议
protocol DialogEngineDelegate: AnyObject {
    func onDialogStarted()
    func onASRResult(text: String, isFinal: Bool)
    func onTTSStarted(text: String)
    func onTTSFinished()
    func onChatStreaming(text: String)
    func onError(error: Error)
    func onDialogEnded(reason: DialogEndReason)
}

private final class DialogEngineProviderDelegateProxy: NSObject, SpeechEngineDelegate {
    weak var owner: DialogEngineManager?
    let engineGeneration: UUID

    init(owner: DialogEngineManager, engineGeneration: UUID) {
        self.owner = owner
        self.engineGeneration = engineGeneration
    }

    func onMessage(with type: SEMessageType, andData data: Data) {
        owner?.enqueueProviderMessage(
            type: type,
            data: data,
            engineGeneration: engineGeneration
        )
    }
}

private struct DialogEngineProviderCallbackContext {
    let engineGeneration: UUID
    let dialogOperationId: UUID
    let bindingHandle: DialogEngineBindingHandle
    let delegateIdentity: ObjectIdentifier
}

private struct DialogEngineTextReplyPlayback {
    let id: UUID
    let text: String
    let onStarted: () -> Void
    let completion: (Result<Void, Error>) -> Void
}

// MARK: - DialogEngineManager

/// Dialog 语音对话引擎管理器 - 直接封装火山引擎 SpeechEngineToB SDK
/// 提供语音对话的启动、停止、生命周期管理
final class DialogEngineManager: NSObject {

    // MARK: - Singleton

    static let shared = DialogEngineManager()

    // MARK: - Properties

    weak var delegate: DialogEngineDelegate?
    private let accountLeaseRuntime = AccountLeaseRuntime.shared
    private var boundAccountLease: AccountLease?
    private var engineAccountLease: AccountLease?
    private var activeDialogAccountLease: AccountLease?
    private var boundBindingHandle: DialogEngineBindingHandle?
    private var engineBindingId: UUID?
    private var activeDialogBindingHandle: DialogEngineBindingHandle?
    private var activeDialogOperationId: UUID?
    private var providerSessionOperationId: UUID?
    private var engineCallbackGeneration: UUID?
    private var engineDelegateProxy: DialogEngineProviderDelegateProxy?
    private var requiresEngineRecreationBeforeNextDialog = false
    private var scopedTTSVoiceSelectionStore = DialogEngineScopedTTSVoiceSelectionStore()
    private var externallyManagedAudioSessionLease: AudioOwnerLease?
    private var pendingTextReplyPlayback: DialogEngineTextReplyPlayback?
    private var textReplyPlaybackFallbackWorkItem: DispatchWorkItem?

    /// 引擎是否就绪（已初始化完成）
    private(set) var isEngineReady = false

    /// 是否有活跃对话
    private(set) var isDialogActive = false

    /// Recorder transport may pause while the Digital Human speaks without
    /// ending the provider conversation or the product-level Live session.
    private(set) var isRecorderPaused = false
    private(set) var sessionLifetimePolicy: DialogSessionLifetimePolicy = .automatic

    /// AI 是否正在语音播报中（用于判断是否需要打断）
    private(set) var isAISpeaking = false

    /// 是否正在结束对话中（防止关键词触发后继续处理事件）
    private(set) var isEnding = false
    /// 当前话题（由业务层设置，注入到 system_role 末尾）
    var currentTopic: String?
    private var suppressGreetingForNextStart = false
    private(set) var usesTurnScopedKnowledgeContext = false
    private(set) var lastSubmittedTurnKnowledgeContextSource: String?
    private(set) var lastSubmittedTurnKnowledgeContextLength = 0

    // MARK: - Configuration

    /// 火山引擎 Dialog 服务配置
    private struct Config {
        /// 从火山控制台获取的 AppID
        var appID: String = ""
        /// 从火山控制台获取的 AppKey
        var appKey: String = ""
        /// 从火山控制台获取的 AccessToken
        var token: String = ""
        /// 用户唯一标识（用于日志追踪）
        var uid: String = UIDevice.current.identifierForVendor?.uuidString ?? "unknown"
        /// Backend realtime proxy address. There is deliberately no Provider
        /// default: production Live can start only from a one-time ticket.
        var address: String = ""
        /// Backend realtime proxy URI
        var uri: String = ""
        /// Backend proxy placeholder resource ID
        var resourceID: String = ""
        /// 是否启用 SDK 软件 AEC 回声消除（需要 AEC 模型文件，iOS 硬件 AEC 通过 AVAudioSession voiceChat 模式已生效）
        var enableAEC: Bool = false
        /// 是否启用内置播放器
        var enablePlayer: Bool = true
        /// Backend proxy admission header. It carries a one-time DreamJourney
        /// ticket, never a Provider credential.
        var requestHeaders: [String: String] = [:]

        // MARK: - 对话能力配置

        /// Bot 名称
        var botName: String = "寻梦环游"

        /// System Prompt - 家庆回忆录 AI 人格设定
        var systemPrompt: String = """
            你是「寻梦环游」AI 助手，不是真人，也不代表用户或任何家庭成员本人。你以温暖、耐心、善于倾听的家族历史学家和传记作家方式提供帮助。\
            你的工作是通过温和的提问，引导长辈回忆人生中的重要时刻、情感体验和细节，帮他们把记忆变成可以传递给家人的故事。

            【核心原则】
            1. 多问开放式问题（“什么样的”“什么味道”“谁做的”），避免是非题。
            2. 每个话题至少追问一个感官细节（味道、声音、颜色、触感、气味）。
            3. 对长辈的每句话给予积极回应，绝不评判“记错了”或“这不重要”。
            4. 说话短、慢、亲，不用长句，不用专业术语，像跟自家奶奶聊天。
            5. 触及伤痛时不追问，先共情陪伴。原则——不追问伤痛，只陪伴伤痛。

            【语音节奏】
            - 每轮回复不超过2句话。
            - 说完一个问题后留出停顿，等长辈想，不要急着接话。
            - 长辈说话时绝不打断，哪怕重复了。
            - 重要反馈重复一遍：“您说的锅巴饭，焦黄焦黄的——是那个焦黄焦黄的锅巴饭对吧？”

            【对话节奏】
            - 每轮只追问一个点，不贪多。
            - 长辈说完后，先反馈你听到了什么，再追问。
            - 话题转换跟着食物链、味道链、人物链走，不硬跳。
            - 苦难至少给2轮空间，不急着转轻。
            - 不用“回忆”“铭记”“传承”等大词，用“记得”“说说”“讲讲”。

            【话题引导框架（5层，但不强制线性）】
            1. 根（家在哪里）：小时候住的地方、门口的树/井/河、现在变了什么样。
            2. 味（吃的故事）：过年吃什么、谁做的、小时候最馅什么。
            3. 人（最亲的人）：谁最疼您、小时候谁管您最严。追问五感：声音、手、走路、习惯动作、口头禅。
            4. 事（重要时刻）：这辈子最不容易的日子、最开心的一天。
            5. 传（想留下的）：什么手艺是从上一辈学来的、想给后辈留什么。追问传承线：谁教您→您教了谁→现在谁在做。

            【感官追问】
            - 食物：什么味道？谁做的？用什么柴？出锅第一口什么感觉？
            - 地方：什么颜色？什么气味？
            - 人物：说话什么声音？手摸起来粗糙还是软的？有什么口头禅？
            - 事件：当时穿的什么？天气怎么样？心里什么感觉？

            【情绪应对】
            - 长时间沉默：等待，不追问。
            - 哽咽/声音颤抖：停止追问，说“那段日子确实不容易……不说了吧”。
            - 笑出声：追问细节，这是金矿！
            - 语速突然变快：放慢自己语速，引导展开。
            - 叹气：共情回应“是啊……”然后给停顿。
            - 重复说同一件事：说明这件事很重要，不打断、不提醒“您说过”。

            【方言处理】
            遇到方言词/地方说法时，追问含义：“这个在您老家是什么意思？”
            """

        /// 开场白问题库（每次随机选一个播报，为空则不播报）
        var greetings: [String] = [
            "您好呀，我是寻梦环游，今天想跟您说说话不？",
            "又见面啦，今天过得怎么样？",
            "您好，最近有什么开心的事想说说吗？",
            "喔，您来啦，今天想聊点什么？",
            "您好呀，今天有什么新鲜事想跟我讲讲？",
            "您好，今天天气怎么样？跟我聊聊呗？",
            "又是新的一天，想跟您说说话，您有空不？"
        ]

        /// ASR 热词列表（提升识别准确率）
        var hotwords: [String] = [
            "寻梦环游", "家书", "回忆录", "老家",
            "锅巴饭", "大灶", "柴火", "过年",
            "奶奶", "爷爷", "外婆", "外公",
            "小时候", "老房子", "手艺", "传承"
        ]

        /// TTS 语速倍率（0.8 = 比正常慢 1.2 倍，适老）
        var speechRate: Double = 0.8

        // MARK: - 对话结束机制

        /// 触发结束对话的关键词列表（ASR 识别结果包含其中任一则结束）
        var endKeywords: [String] = [
            "生成回忆录", "生成家书", "写家书",
            "停止", "结束", "不聊了", "再见",
            "我要去忙了", "先这样吧", "下次再聊"
        ]

        /// 静音超时时长（秒），无语音输入超过此时间自动结束对话
        var silenceTimeoutSeconds: TimeInterval = 60

        var isProductionReady: Bool {
            Self.isConfiguredValue(appID) &&
                Self.isConfiguredValue(appKey) &&
                Self.isConfiguredValue(token) &&
                Self.isConfiguredValue(address) &&
                Self.isConfiguredValue(uri) &&
                Self.isConfiguredValue(resourceID) &&
                !requestHeaders.isEmpty
        }

        static func isConfiguredValue(_ value: String) -> Bool {
            let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty else { return false }
            guard !trimmed.hasPrefix("$(") else { return false }
            return !trimmed.hasPrefix("YOUR_")
        }
    }

    /// 当前配置
    private var config = Config()
    var currentConfigurationIsProductionReady: Bool { config.isProductionReady }

    // MARK: - Private

    private static let defaultTTSSpeaker = "zh_male_yunzhou_jupiter_bigtts"

    private var engine: SpeechEngine?
    private var isSettingUp = false

    /// 静音超时计时器
    private var silenceTimer: Timer?

    /// 当前对话结束原因（用于回调时传递）
    private var pendingEndReason: DialogEndReason = .manual

    /// AI 回复流式拼接缓冲区
    private var chatBuffer: String = ""

    private override init() {
        super.init()
    }

    @discardableResult
    func bindAccountLease(
        _ accountLease: AccountLease,
        ownerId: UUID
    ) -> DialogEngineBindingHandle? {
        guard accountLeaseRuntime.validate(accountLease, at: .request).allowed else {
            return nil
        }

        if let boundBindingHandle,
           boundBindingHandle.ownerId == ownerId,
           isSameDialogAccountGeneration(boundBindingHandle.accountLease, accountLease) {
            let rotatedHandle = DialogEngineBindingHandle(
                bindingId: boundBindingHandle.bindingId,
                ownerId: ownerId,
                accountLease: accountLease
            )
            self.boundBindingHandle = rotatedHandle
            boundAccountLease = accountLease
            if engineBindingId == rotatedHandle.bindingId {
                engineAccountLease = accountLease
            }
            if activeDialogBindingHandle?.bindingId == rotatedHandle.bindingId {
                activeDialogBindingHandle = rotatedHandle
                activeDialogAccountLease = accountLease
            }
            return rotatedHandle
        }

        if boundBindingHandle != nil {
            destroyEngine()
            scopedTTSVoiceSelectionStore.clearAll()
            delegate = nil
        }
        let handle = DialogEngineBindingHandle(
            bindingId: UUID(),
            ownerId: ownerId,
            accountLease: accountLease
        )
        boundBindingHandle = handle
        boundAccountLease = accountLease
        return handle
    }

    @discardableResult
    func unbindAccountLease(_ handle: DialogEngineBindingHandle) -> Bool {
        guard boundBindingHandle == handle else { return false }
        destroyEngine()
        _ = scopedTTSVoiceSelectionStore.clear(bindingID: handle.bindingId)
        boundBindingHandle = nil
        boundAccountLease = nil
        delegate = nil
        return true
    }

    func isCurrentBinding(_ handle: DialogEngineBindingHandle?) -> Bool {
        guard let handle,
              boundBindingHandle == handle else { return false }
        return accountLeaseRuntime.validate(handle.accountLease, at: .runtime).allowed
    }

    /// Echo owns the session through AudioSessionCoordinator; the dialog engine must
    /// only reuse the exact active lease and never configure it a second time.
    @discardableResult
    func adoptExternallyManagedAudioSessionLease(_ lease: AudioOwnerLease) -> Bool {
        guard AudioSessionCoordinator.shared.isCurrentActiveLease(lease) else {
            externallyManagedAudioSessionLease = nil
            return false
        }
        externallyManagedAudioSessionLease = lease
        return true
    }

    private func isActiveAccountLeaseValid(at checkpoint: AccountLeaseCheckpoint) -> Bool {
        guard let accountLease = activeDialogAccountLease ?? engineAccountLease ?? boundAccountLease else {
            return false
        }
        return accountLeaseRuntime.validate(accountLease, at: checkpoint).allowed
    }

    // MARK: - Public API

    @discardableResult
    func setLocalTTSPlaybackEnabled(_ enabled: Bool) -> Bool {
        guard config.enablePlayer != enabled else {
            return true
        }
        guard !isDialogActive else {
            DDLogWarn("[DialogEngine] 对话进行中，跳过本地 TTS 播放开关切换")
            return false
        }

        config.enablePlayer = enabled
        print("[DialogEngine] local TTS playback \(enabled ? "enabled" : "disabled")")
        DDLogInfo("[DialogEngine] 本地 TTS 播放已\(enabled ? "开启" : "关闭")")

        if isEngineReady {
            destroyEngine()
        }
        return true
    }

    @discardableResult
    func setLocalTTSVoiceSelection(
        voiceProfileId: String?,
        contextKey: String,
        lifecycleGeneration: UInt64,
        for handle: DialogEngineBindingHandle
    ) -> Bool {
        guard isCurrentBinding(handle) else { return false }
        return scopedTTSVoiceSelectionStore.update(
            bindingID: handle.bindingId,
            accountLease: handle.accountLease,
            contextKey: contextKey,
            lifecycleGeneration: lifecycleGeneration,
            voiceProfileId: voiceProfileId
        )
    }

    /// Applies a backend-issued, one-time proxy ticket. Provider credentials
    /// and the upstream Provider address never enter the app bundle.
    @discardableResult
    func configure(runtimeConfig: RealtimeVoiceRuntimeConfig) -> Bool {
        guard !runtimeConfig.mobileDirectAllowed,
              runtimeConfig.accessPath == "backendRealtimeProxy",
              runtimeConfig.credentialMode == "oneTimeBackendProxyTicket",
              !runtimeConfig.isBlocked,
              let address = runtimeConfig.proxyAddress,
              let uri = runtimeConfig.proxyURI,
              let token = runtimeConfig.sessionToken,
              let header = runtimeConfig.sessionHeader,
              let clientID = runtimeConfig.sdkClientID,
              let clientKey = runtimeConfig.sdkClientKey,
              let resourceID = runtimeConfig.sdkResourceID else {
            DDLogWarn(
                "[DialogEngine] providerCredentialBlocked " +
                "mode=\(runtimeConfig.credentialMode) " +
                "path=\(runtimeConfig.accessPath) " +
                "reason=\(runtimeConfig.decisionReasonCode ?? "unknown") " +
                "fallback=\(runtimeConfig.fallbackMode ?? "text")"
            )
            return false
        }
        if isDialogActive {
            DDLogWarn("[DialogEngine] active Live session refuses runtime reconfiguration")
            return false
        }
        if isEngineReady {
            destroyEngine()
        }
        config.appID = clientID
        config.appKey = clientKey
        config.token = token
        config.address = address
        config.uri = uri
        config.resourceID = resourceID
        config.uid = runtimeConfig.uid ?? config.uid
        config.requestHeaders = [header: token]
        DDLogInfo("[DialogEngine] backend realtime proxy ticket applied")
        return true
    }

    /// 客户端主动打断 AI 回复（仅在 AI 正在播报时生效）
    func interruptAI() {
        guard isDialogActive, isAISpeaking, let engine = engine else { return }
        let result = engine.send(SEDirectiveEventClientInterrupt, data: "{}")
        if result == SENoError {
            isAISpeaking = false
            print("[DialogEngine] ✅ 已打断 AI 播报")
            DDLogInfo("[DialogEngine] 客户端打断 AI")
        } else {
            print("[DialogEngine] ⚠️ 打断指令发送失败: \(result.rawValue)")
        }
    }

    /// 初始化引擎（预加载）
    func setup() {
        guard let setupAccountLease = boundAccountLease,
              let setupBindingHandle = boundBindingHandle,
              accountLeaseRuntime.validate(setupAccountLease, at: .request).allowed else {
            return
        }
        guard !isEngineReady else {
            DDLogInfo("[DialogEngine] 引擎已就绪，跳过重复初始化")
            return
        }

        guard !isSettingUp else {
            DDLogInfo("[DialogEngine] 正在初始化中，跳过")
            return
        }

        isSettingUp = true

        guard config.isProductionReady else {
            print("[DialogEngine] ❌ 生产语音 SDK 配置缺失或仍为占位值")
            DDLogError("[DialogEngine] 生产语音 SDK 配置缺失或仍为占位值")
            isSettingUp = false
            delegate?.onError(error: DialogEngineError.productionConfigurationMissing)
            return
        }

        // 准备环境（首次调用）
        SpeechEngine.prepareEnvironment()

        // 创建引擎实例
        let speechEngine = SpeechEngine()
        let callbackGeneration = UUID()
        let delegateProxy = DialogEngineProviderDelegateProxy(
            owner: self,
            engineGeneration: callbackGeneration
        )
        let created = speechEngine.createEngine(with: delegateProxy)
        guard created else {
            DDLogError("[DialogEngine] createEngine 失败")
            isSettingUp = false
            delegate?.onError(error: DialogEngineError.initFailed(code: -1))
            return
        }

        // 配置引擎参数
        configureEngine(speechEngine)

        // 初始化引擎
        let result = speechEngine.initEngine()
        isSettingUp = false

        print("[DialogEngine] initEngine 返回: \(result.rawValue)")
        if result == SENoError {
            guard let currentBindingHandle = boundBindingHandle,
                  currentBindingHandle.bindingId == setupBindingHandle.bindingId,
                  isSameDialogAccountGeneration(currentBindingHandle.accountLease, setupAccountLease),
                  accountLeaseRuntime.validate(currentBindingHandle.accountLease, at: .runtime).allowed else {
                speechEngine.destroy()
                return
            }
            self.engine = speechEngine
            self.engineAccountLease = currentBindingHandle.accountLease
            self.engineBindingId = currentBindingHandle.bindingId
            self.engineCallbackGeneration = callbackGeneration
            self.engineDelegateProxy = delegateProxy
            self.isEngineReady = true
            print("[DialogEngine] ✅ 引擎初始化成功")
            DDLogInfo("[DialogEngine] 引擎初始化成功")
        } else {
            print("[DialogEngine] ❌ 引擎初始化失败: \(result.rawValue)")
            DDLogError("[DialogEngine] 引擎初始化失败: \(result.rawValue)")
            speechEngine.destroy()
            delegate?.onError(error: DialogEngineError.initFailed(code: Int(result.rawValue)))
        }
    }

    /// 开始语音对话
    func startDialog(
        sendsGreeting: Bool = true,
        usesTurnScopedKnowledgeContext: Bool = false,
        lifetimePolicy: DialogSessionLifetimePolicy = .automatic
    ) {
        guard let accountLease = boundAccountLease,
              let bindingHandle = boundBindingHandle,
              accountLeaseRuntime.validate(accountLease, at: .request).allowed else {
            return
        }
        if isDialogActive, let engine {
            _ = engine.send(SEDirectiveSyncStopEngine)
            isDialogActive = false
            activeDialogAccountLease = nil
            activeDialogBindingHandle = nil
            activeDialogOperationId = nil
            providerSessionOperationId = nil
            requiresEngineRecreationBeforeNextDialog = true
        }
        rotateProviderEngineBeforeNextDialogIfNeeded()
        let dialogOperationId = UUID()
        activeDialogAccountLease = accountLease
        activeDialogBindingHandle = bindingHandle
        activeDialogOperationId = dialogOperationId
        self.usesTurnScopedKnowledgeContext = usesTurnScopedKnowledgeContext
        sessionLifetimePolicy = lifetimePolicy
        isRecorderPaused = false
        suppressGreetingForNextStart = !sendsGreeting
        // 引擎未就绪时先初始化
        guard isEngineReady, engine != nil else {
            DDLogInfo("[DialogEngine] 引擎未就绪，先初始化")
            setup()
            if isEngineReady {
                performStartDialog(
                    accountLease: accountLease,
                    bindingHandle: bindingHandle,
                    dialogOperationId: dialogOperationId
                )
                return
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
                guard let self,
                      self.boundBindingHandle == bindingHandle,
                      self.activeDialogBindingHandle == bindingHandle,
                      self.activeDialogOperationId == dialogOperationId,
                      self.activeDialogAccountLease == accountLease,
                      self.accountLeaseRuntime.validate(accountLease, at: .timer).allowed,
                      self.isEngineReady else { return }
                self.performStartDialog(
                    accountLease: accountLease,
                    bindingHandle: bindingHandle,
                    dialogOperationId: dialogOperationId
                )
            }
            return
        }

        performStartDialog(
            accountLease: accountLease,
            bindingHandle: bindingHandle,
            dialogOperationId: dialogOperationId
        )
    }

    /// Speaks a backend-generated text reply through the same Fire realtime
    /// dialog transport and role-bound speaker used by Live. The recorder is
    /// paused before text is injected, so this one-shot route cannot create a
    /// second user turn or mutate the Live conversation.
    @discardableResult
    func startTextReplyPlayback(
        text: String,
        onStarted: @escaping () -> Void,
        completion: @escaping (Result<Void, Error>) -> Void
    ) -> Bool {
        let normalized = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !normalized.isEmpty else {
            completion(.failure(DialogTextReplyPlaybackError.invalidText))
            return false
        }
        guard pendingTextReplyPlayback == nil,
              !isDialogActive,
              config.enablePlayer,
              currentConfigurationIsProductionReady,
              boundBindingHandle != nil else {
            completion(.failure(DialogTextReplyPlaybackError.sessionBusy))
            return false
        }

        pendingTextReplyPlayback = DialogEngineTextReplyPlayback(
            id: UUID(),
            text: normalized,
            onStarted: onStarted,
            completion: completion
        )
        startDialog(
            sendsGreeting: false,
            usesTurnScopedKnowledgeContext: true,
            lifetimePolicy: .automatic
        )
        guard isEngineReady, activeDialogOperationId != nil else {
            completeTextReplyPlayback(
                .failure(DialogTextReplyPlaybackError.unavailable),
                stopsProviderSession: true
            )
            return false
        }
        return true
    }

    func cancelTextReplyPlayback() {
        guard pendingTextReplyPlayback != nil else { return }
        textReplyPlaybackFallbackWorkItem?.cancel()
        textReplyPlaybackFallbackWorkItem = nil
        pendingTextReplyPlayback = nil
        closeTextReplyProviderSession()
    }

    /// 结束语音对话
    func stopDialog() {
        stopDialog(reason: .manual)
    }

    /// 结束语音对话（带原因）
    func stopDialog(reason: DialogEndReason) {
        if pendingTextReplyPlayback != nil {
            cancelTextReplyPlayback()
            return
        }
        guard isDialogActive,
              let engine,
              let callbackContext = currentProviderCallbackContext() else { return }

        isEnding = true
        invalidateSilenceTimer()
        pendingEndReason = reason

        // 同步停止引擎（官方推荐）
        let result = engine.send(SEDirectiveSyncStopEngine)
        if result != SENoError {
            DDLogError("[DialogEngine] SyncStopEngine 失败: \(result.rawValue)")
        }

        isDialogActive = false
        isRecorderPaused = false
        isAISpeaking = false
        isEnding = false
        activeDialogAccountLease = nil
        activeDialogBindingHandle = nil
        activeDialogOperationId = nil
        providerSessionOperationId = nil
        requiresEngineRecreationBeforeNextDialog = true
        restoreAudioSessionIfNeeded()

        switch reason {
        case .keyword(let kw):
            print("[DialogEngine] 🛑 关键词触发结束: \(kw)")
            DDLogInfo("[DialogEngine] 关键词触发结束: \(kw)")
        case .silenceTimeout:
            print("[DialogEngine] ⏰ 静音超时触发结束")
            DDLogInfo("[DialogEngine] 静音超时触发结束")
        default:
            DDLogInfo("[DialogEngine] 对话已停止")
        }

        deliverProviderCallback(
            callbackContext,
            requiresActiveOperation: false
        ) { _, delegate in
            delegate.onDialogEnded(reason: reason)
        }
    }

    /// Temporarily releases microphone capture while preserving the same
    /// realtime provider session and its accumulated conversation context.
    @discardableResult
    func pauseRecorder() -> Bool {
        guard isDialogActive, !isRecorderPaused, let engine else {
            return isDialogActive && isRecorderPaused
        }
        let result = engine.send(SEDirectivePauseRecorder)
        guard result == SENoError else {
            DDLogError("[DialogEngine] PauseRecorder failed: \(result.rawValue)")
            return false
        }
        isRecorderPaused = true
        invalidateSilenceTimer()
        DDLogInfo("[DialogEngine] recorder paused; provider Live session preserved")
        return true
    }

    @discardableResult
    func resumeRecorder() -> Bool {
        guard isDialogActive, isRecorderPaused, let engine else {
            return isDialogActive && !isRecorderPaused
        }
        let result = engine.send(SEDirectiveResumeRecorder)
        guard result == SENoError else {
            DDLogError("[DialogEngine] ResumeRecorder failed: \(result.rawValue)")
            return false
        }
        isRecorderPaused = false
        resetSilenceTimer()
        DDLogInfo("[DialogEngine] recorder resumed in existing provider Live session")
        return true
    }

    /// 播报开场白（对应豆包SDK的 SayHello 事件 3006）
    /// 应在引擎启动成功（SEEngineStart 回调）后调用
    func sayHello(_ content: String? = nil) {
        guard let engine = engine else { return }
        let greeting = content ?? "您好呀，我是寻梦环游，今天想跟您聊聊天，听听您的故事。"
        let json = "{\"content\": \"\(greeting)\"}"
        engine.send(SEDirectiveEventSayHello, data: json)
        DDLogInfo("[DialogEngine] 开场白已发送: \(greeting)")
    }

    /// 客户端打断AI（对应豆包SDK的 ClientInterrupt 事件 3010）
    /// 当AI正在说话时用户开口说话，可调用此方法打断
    func clientInterrupt() {
        guard let engine = engine else { return }
        engine.send(SEDirectiveEventClientInterrupt, data: "{}")
        DDLogInfo("[DialogEngine] 发送打断指令")
    }

    /// 为当前已确认的用户 query 提交后端筛选后的知识上下文。
    /// ChatRagText 会把 content 绑定到 SDK 当前等待中的 turn，不修改下一轮 system_role。
    @discardableResult
    func submitTurnKnowledgeContext(
        _ content: String,
        traceID: String?,
        source: String
    ) -> Bool {
        guard isDialogActive, let engine else {
            DDLogWarn("[DialogEngine] 忽略 turn RAG：对话未激活")
            return false
        }
        guard let payloadData = try? JSONSerialization.data(
            withJSONObject: ["content": content],
            options: []
        ), let payload = String(data: payloadData, encoding: .utf8) else {
            DDLogError("[DialogEngine] turn RAG JSON 编码失败")
            return false
        }

        let result = engine.send(SEDirectiveEventChatRagText, data: payload)
        guard result == SENoError else {
            DDLogError("[DialogEngine] turn RAG 提交失败: \(result.rawValue)")
            return false
        }
        lastSubmittedTurnKnowledgeContextSource = source
        lastSubmittedTurnKnowledgeContextLength = content.utf8.count
        DDLogInfo(
            "[DialogEngine] turn RAG 已提交 source=\(source) " +
            "traceID=\(traceID ?? "none") bytes=\(content.utf8.count)"
        )
        return true
    }

    /// 销毁引擎（登出/退出时调用）
    func destroyEngine() {
        invalidateSilenceTimer()
        textReplyPlaybackFallbackWorkItem?.cancel()
        textReplyPlaybackFallbackWorkItem = nil
        pendingTextReplyPlayback = nil
        if isDialogActive {
            _ = engine?.send(SEDirectiveSyncStopEngine)
        }
        engine?.destroy()
        engine = nil
        engineAccountLease = nil
        engineBindingId = nil
        engineCallbackGeneration = nil
        engineDelegateProxy = nil
        activeDialogBindingHandle = nil
        activeDialogOperationId = nil
        providerSessionOperationId = nil
        requiresEngineRecreationBeforeNextDialog = false
        activeDialogAccountLease = nil
        isEngineReady = false
        isDialogActive = false
        isRecorderPaused = false
        isAISpeaking = false
        isEnding = false
        sessionLifetimePolicy = .automatic
        usesTurnScopedKnowledgeContext = false
        restoreAudioSessionIfNeeded()
        externallyManagedAudioSessionLease = nil
        DDLogInfo("[DialogEngine] 引擎已销毁")
    }

    private func rotateProviderEngineBeforeNextDialogIfNeeded() {
        guard requiresEngineRecreationBeforeNextDialog else { return }
        let retiredGeneration = engineCallbackGeneration?.uuidString ?? "none"
        destroyEngine()
        DDLogInfo("[DialogEngine] 已轮换 provider callback generation，隔离上一会话晚到事件 retiredGeneration=\(retiredGeneration)")
    }

    // MARK: - Audio Session 管理

    private var shouldLetExternalTTSOwnAudioSession: Bool {
        !config.enablePlayer
    }

    /// Configures the legacy session only when a non-Echo caller owns this engine.
    /// Echo passes an exact coordinator lease and must never race this direct path.
    private func configureAudioSession() -> Bool {
        if let externallyManagedAudioSessionLease {
            guard AudioSessionCoordinator.shared.isCurrentActiveLease(externallyManagedAudioSessionLease) else {
                DDLogError("[DialogEngine] 外部 AudioSession lease 已失效，拒绝启动对话")
                delegate?.onError(error: DialogEngineError.audioSessionFailed)
                return false
            }
            DDLogInfo("[DialogEngine] 复用 Echo AudioSessionCoordinator lease")
            return true
        }

        let session = AVAudioSession.sharedInstance()
        do {
            if session.category != .playAndRecord || session.mode != .voiceChat {
                try session.setCategory(
                    .playAndRecord,
                    mode: .voiceChat,
                    options: [.defaultToSpeaker, .allowBluetoothHFP]
                )
            }
            try session.setActive(true)
            if shouldLetExternalTTSOwnAudioSession {
                DDLogInfo("[DialogEngine] AudioSession 配置为 playAndRecord + voiceChat，腾讯数字人远端音频接管播放")
                print("[DialogEngine] AudioSession active for external digital-human TTS playback")
            } else {
                DDLogInfo("[DialogEngine] AudioSession 配置为 playAndRecord + voiceChat")
            }
            return true
        } catch {
            DDLogError("[DialogEngine] AudioSession 配置失败: \(error.localizedDescription)")
            delegate?.onError(error: DialogEngineError.audioSessionFailed)
            return false
        }
    }

    private func restoreAudioSessionIfNeeded() {
        if externallyManagedAudioSessionLease != nil {
            DDLogInfo("[DialogEngine] 跳过 AudioSession 恢复：Echo coordinator 持有会话")
            return
        }
        guard !shouldLetExternalTTSOwnAudioSession else {
            DDLogInfo("[DialogEngine] 跳过 AudioSession 恢复：外部数字人 TTS 仍可能在播放")
            print("[DialogEngine] skip AudioSession restore; external digital-human TTS owns playback")
            return
        }
        restoreAudioSession()
    }

    /// 恢复音频会话为默认播放模式
    private func restoreAudioSession() {
        let session = AVAudioSession.sharedInstance()
        do {
            try session.setCategory(.playback, mode: .default)
            try session.setActive(false, options: .notifyOthersOnDeactivation)
            DDLogInfo("[DialogEngine] AudioSession 恢复为 playback")
        } catch {
            DDLogError("[DialogEngine] AudioSession 恢复失败: \(error.localizedDescription)")
        }
    }

    // MARK: - Persona / Prompt

    /// 模型对话风格（speaking_style），适配豆包语音SDK的 dialog.speaking_style 参数
    /// 对应SDK配置界面的"模型对话风格"字段
    private let speakingStyle = """
温柔耐心，像邻家晚辈跟长辈聊天。语气温暖亲切，语速慢，说话简短。
经常用「嗯」「是嘛」「真好」「原来是这样」等语气词表示在听。
偶尔感叹「哇」「真好啊」「那可真不容易」来表达共情。
用「您」称呼，绝对不要用网络流行语或生僻词汇。
回复要口语化，像在说话而不是在写文章。

千万不要：
1. 长篇大论，一句话超过30个字
2. 一次问多个问题
3. 用书面语（如「请您描述一下」「能否谈谈您的感受」）
4. 机械地切换话题，像在走流程
5. 对老人的沉默表现出不耐烦
6. 只回应不追问，错失采集时间、地点、人物的机会
"""

    /// 构建背景人设（system_role），适配豆包语音SDK的 dialog.system_role 参数
    /// 对应SDK配置界面的"背景人设"字段
    private func buildSystemRole() -> String {
        var role = """
你叫寻梦环游，是一个温暖、耐心的 AI 助手。你用邻家晚辈般的语气陪伴老人回忆过去的人生故事，为他和他的家人留下一份珍贵的回忆，但不能声称自己是人类。

【你是谁】
你是寻梦环游 AI 助手，不是真人，也不是用户或任何家庭成员本人。你的使命是听老人讲故事，把那些珍贵的记忆保存下来。
用户问你叫什么或你是谁时，要明确回答“我是寻梦环游 AI 助手，不是真人本人”，绝对不能冒充真人或说自己是“豆包”。

【核心原则】
1. 你是一个很好的倾听者。认真听老人说的每一句话，记住他提到的细节，让你的回应能体现出你真的在听。
2. 主动提问，引起老人聊天的兴趣。当话题冷下来时，用好奇、温暖的提问让老人想继续说下去，而不是被动等待。
3. 绝不编造老人没有说过的内容。你只能基于老人实际说过的话来回应和追问，永远不要替老人编故事、补充细节或臆想他没提过的事情。
4. 用聊天的方式展开话题，不要像问卷一样机械提问。
5. 每次只问一个问题，问题要简短、具体、好回答。
6. 老人说完后，先真诚回应和共情，再自然追问细节。
7. 老人跑题了不要打断，顺着话题聊，再巧妙引回来。
8. 老人沉默时，等几秒再温和引导，不要急着填满空白。
9. 如果老人情绪低落，给予安慰，不要追问细节。
10. 说话简洁，每句话不超过30个字。

【引出回忆的技巧】
- 用具体场景切入：「您小时候过年是什么样的呀？」「那时候住的地方还记得吗？」
- 用感官触发记忆：「有没有一种味道，让您一下子就想到小时候？」「那个年代最常见的颜色是什么呢？」
- 用对比引出变化：「以前和现在比，变化最大的地方在哪里？」「那时候跟现在可真不一样吧？」
- 用身边小事打开话匣：「今天吃了什么好吃的呀？」「您平时早上几点起来呀？」
- 用天气季节联想：「最近天气凉了，您以前冬天都怎么过呀？」「下雪的时候您小时候玩什么呢？」
- 用食物引出回忆：「您最拿手的菜是什么呀？」「小时候过年家里做什么好吃的？」
- 用老物件勾起记忆：「以前家里有没有那种老收音机呀？」「您还记不记得第一块手表是什么牌子的？」
- 从家人聊起：「您家几个兄弟姐妹呀？」「小时候跟谁最亲？」
- 追问细节：「能再讲讲那个人吗？」「后来呢？」「您当时心里是怎么想的？」
- 珍视每一句话：「这句话太珍贵了，特别想听您多说一点。」「这个故事真好，您再跟我讲讲后来的事。」

【话题示例】（根据聊天氛围自然切换，不要像走流程挨个问）
- 日常生活：「您今天做了什么呀？」「平时喜欢去哪儿溜达溜达？」
- 童年趣事：「小时候最喜欢玩什么呀？」「那时候放学了都干什么呢？」
- 家乡记忆：「您老家在哪儿呀？」「老家那边有什么好玩的习俗吗？」
- 过年过节：「您小时候过年是什么样的呀？」「最盼着过年的什么事？」
- 吃的记忆：「小时候最爱吃的零食是什么呀？」「那时候有什么好吃的现在吃不到了？」
- 上学读书：「您上的第一所学校还记得吗？」「有没有哪个老师让您印象特别深？」
- 工作岁月：「第一份工作是做什么的呀？」「那时候上班跟现在可不一样吧？」
- 难忘的人：「有没有一个人，对您影响特别大？」「年轻时候最好的朋友还记得吗？」
- 青春时光：「年轻时候流行什么歌呀？」「那时候周末都去哪儿玩呢？」
- 恋爱家庭：「您跟老伴怎么认识的呀？」「第一次见面是什么感觉？」
- 生儿育女：「第一次当爸爸妈妈的时候是什么心情呀？」「孩子小时候淘气吗？」
- 人生转折：「有没有哪个决定改变了您的一生？」「回头看，哪个时候最重要？」
- 手艺本事：「您有什么拿手本事呀？」「有没有什么绝活儿教教我？」
- 人生感悟：「如果跟年轻时候的自己说句话，您想说什么？」「这辈子最值得的事是什么？」

【回忆录数据采集】
你的每一次对话，都是在为老人攒一份珍贵的回忆录。聊天时要自然地引导老人讲出以下四类信息，但绝不能像填表一样问，要像好奇的孩子追着长辈问故事：

1. 【时间】什么时候的事？——「那是哪一年的事呀？」「您那时候多大？」
2. 【地点】在哪儿发生的？——「那是哪儿呀？」「那个地方现在还在吗？」
3. 【人物】和谁在一起？——「谁跟您一起去的？」「那人后来还有联系吗？」
4. 【细节】具体发生了什么？——「后来呢？」「您当时心里怎么想的？」「能再讲讲那个场景吗？」

采集节奏（自然融入对话，不要机械切换）：
- 老人提到一件事 → 先共情 → 再追问时间或地点
- 老人提到一个人 → 先回应 → 再问这个人的故事
- 老人说到一个场景 → 先感慨 → 再追问细节
- 每次只追问一个维度，不要连珠炮似的问
- 如果老人对某个维度没有回应，不要硬追问，换一个角度
"""

        // 如果设置了当前话题，动态追加到人设末尾
        if let topic = currentTopic, !topic.isEmpty {
            role += "\n\n【本次聊天话题】\n家人想了解的是：「\(topic)」\n请以这个问题为起点，自然地引导老人聊起相关的故事。不要一上来就念问题，先打个招呼暖场，然后巧妙地引向这个话题。"
        }

        return role
    }

    // MARK: - Private

    /// 配置 Dialog 引擎参数
    private func configureEngine(_ engine: SpeechEngine) {
        // 引擎类型：Dialog
        engine.setStringParam(SE_DIALOG_ENGINE, forKey: SE_PARAMS_KEY_ENGINE_NAME_STRING)

        // 鉴权
        engine.setStringParam(config.appID, forKey: SE_PARAMS_KEY_APP_ID_STRING)
        engine.setStringParam(config.appKey, forKey: SE_PARAMS_KEY_APP_KEY_STRING)
        engine.setStringParam(config.token, forKey: SE_PARAMS_KEY_APP_TOKEN_STRING)

        // 用户标识
        engine.setStringParam(config.uid, forKey: SE_PARAMS_KEY_UID_STRING)

        // 资源 ID
        engine.setStringParam(config.resourceID, forKey: SE_PARAMS_KEY_RESOURCE_ID_STRING)

        // Dialog 服务地址
        engine.setStringParam(config.address, forKey: SE_PARAMS_KEY_DIALOG_ADDRESS_STRING)
        engine.setStringParam(config.uri, forKey: SE_PARAMS_KEY_DIALOG_URI_STRING)

        if let headerData = try? JSONSerialization.data(
            withJSONObject: config.requestHeaders,
            options: []
        ), let headerJSON = String(data: headerData, encoding: .utf8) {
            engine.setStringParam(headerJSON, forKey: SE_PARAMS_KEY_REQUEST_HEADERS_STRING)
        }
        // A proxy ticket is one-use. A network failure creates a new explicit
        // Live start and a fresh ticket instead of silently replaying it.
        engine.setBoolParam(false, forKey: SE_PARAMS_KEY_ENABLE_WS_RECONNECT_BOOL)

        // 录音类型：使用设备内置录音机
        engine.setStringParam(SE_RECORDER_TYPE_RECORDER, forKey: SE_PARAMS_KEY_RECORDER_TYPE_STRING)

        // AEC 回声消除
        engine.setBoolParam(config.enableAEC, forKey: SE_PARAMS_KEY_ENABLE_AEC_BOOL)

        // 启用内置播放器。数字人接管声音时，SpeechEngine 只负责 ASR/对话文本，
        // 不创建播放器，也不抢腾讯云渲染的远端音频会话。
        engine.setBoolParam(config.enablePlayer, forKey: SE_PARAMS_KEY_DIALOG_ENABLE_PLAYER_BOOL)
        engine.setBoolParam(!config.enablePlayer, forKey: SE_PARAMS_KEY_PREVENT_PLAYER_CREATION_BOOL)
        engine.setBoolParam(!config.enablePlayer, forKey: SE_PARAMS_KEY_FULLLINK_DISABLE_TTS_BOOL)
        engine.setBoolParam(false, forKey: SE_PARAMS_KEY_RESET_AUDIOSESSION_BOOL)
        engine.setBoolParam(false, forKey: SE_PARAMS_KEY_RESTART_AUDIOSESSION_BOOL)
        engine.setBoolParam(config.enablePlayer, forKey: SE_PARAMS_KEY_RESUME_OTHERS_INTERRUPTED_PLAYBACK_BOOL)
        print(
            "[DialogEngine] local player config enablePlayer=\(config.enablePlayer), " +
            "preventPlayerCreation=\(!config.enablePlayer), " +
            "fullLinkDisableTTS=\(!config.enablePlayer)"
        )

        // 音量回调
        engine.setBoolParam(true, forKey: SE_PARAMS_KEY_ENABLE_GET_VOLUME_BOOL)

        // 日志级别
        #if DEBUG
        engine.setStringParam(SE_LOG_LEVEL_DEBUG, forKey: SE_PARAMS_KEY_LOG_LEVEL_STRING)
        #else
        engine.setStringParam(SE_LOG_LEVEL_WARN, forKey: SE_PARAMS_KEY_LOG_LEVEL_STRING)
        #endif
    }

    /// 执行开始对话
    private func performStartDialog(
        accountLease: AccountLease,
        bindingHandle: DialogEngineBindingHandle,
        dialogOperationId: UUID
    ) {
        guard boundBindingHandle == bindingHandle,
              activeDialogBindingHandle == bindingHandle,
              activeDialogOperationId == dialogOperationId,
              activeDialogAccountLease == accountLease,
              accountLeaseRuntime.validate(accountLease, at: .runtime).allowed,
              engineBindingId == bindingHandle.bindingId,
              let engineAccountLease,
              isSameDialogAccountGeneration(engineAccountLease, accountLease),
              let engine = engine else {
            print("[DialogEngine] ❌ performStartDialog: engine 为 nil")
            return
        }

        print("[DialogEngine] 配置 AudioSession...")
        guard configureAudioSession() else {
            completeTextReplyPlayback(
                .failure(DialogTextReplyPlaybackError.unavailable),
                stopsProviderSession: true
            )
            return
        }

        // 先同步停止引擎（官方推荐，避免异步线程问题）
        print("[DialogEngine] 发送 SyncStopEngine 指令...")
        let syncStopResult = engine.send(SEDirectiveSyncStopEngine)
        print("[DialogEngine] SyncStopEngine 返回: \(syncStopResult.rawValue)")


        // 构建 StartEngine 配置 JSON
        let systemRole = buildSystemRole()
        let ttsSpeaker = resolvedTTSSpeaker(for: bindingHandle)

        var dialogConfig: [String: Any] = [
            "asr": [
                "audio_info": [
                    "format": "pcm",
                    "sample_rate": 16000,
                    "channel": 1
                ],
                "extra": [
                    "end_smooth_window_ms": 3000,   // 3秒停顿容忍，老人说话断续多
                    "enable_custom_vad": true         // 启用自定义VAD
                ]
            ],
            "dialog": [
                "bot_name": "寻梦环游",
                "system_role": systemRole,
                "speaking_style": speakingStyle,
                "extra": [
                    "model": "1.2.1.1"               // O2.0版本，精品音色
                ]
            ]
            ]
        if config.enablePlayer {
            dialogConfig["tts"] = [
                "speaker": ttsSpeaker,
                "audio_config": [
                    "speech_rate": -20,      // 慢20%，适老化
                    "loudness_rate": 10       // 大声10%，适老化
                ]
            ]
        } else {
            print("[DialogEngine] Tencent audio owner active; StartEngine omits Fire TTS config")
        }
        if !config.systemPrompt.isEmpty {
            var fullPrompt = config.systemPrompt
            let context = DigitalHumanContextStore.shared.current
            fullPrompt += buildDigitalHumanModePolicy(context: context)
            if shouldExposePersonalContext(for: context),
               !usesTurnScopedKnowledgeContext {
                // 注入跨会话记忆上下文
                let memory = ConversationMemoryManager.shared.currentMemory
                if memory.sessionCount > 0 {
                    fullPrompt += buildMemoryContext(memory: memory)
                    print("[DialogEngine] 🧠 已注入记忆上下文 (第\(memory.sessionCount + 1)次对话)")
                }
                let archiveContext = buildArchiveContext()
                if !archiveContext.isEmpty {
                    fullPrompt += archiveContext
                    print("[DialogEngine] 🗂️ 已注入记忆档案馆素材")
                }
            }
            #if DEBUG || UI_QA_SIMULATOR
            DialogPromptDebugRecorder.record(prompt: fullPrompt)
            #endif
            // 正确写入 dialog 子字典的 system_role（而非 dialogConfig 顶层）
            if var dialog = dialogConfig["dialog"] as? [String: Any] {
                dialog["system_role"] = fullPrompt
                dialogConfig["dialog"] = dialog
            }
        }

        var startConfig: [String: Any] = [
            "dialog": dialogConfig
        ]

        // ASR 热词配置
        if !config.hotwords.isEmpty {
            startConfig["asr"] = [
                "hot_words": config.hotwords
            ]
        }

        // TTS 语速配置（适老慢速）。腾讯数智人接管声音时不请求火山 TTS 音频，
        // 只保留 Chat 文本结果，再交给 Tencent cloud render 播放和驱动口型。
        if config.enablePlayer {
            startConfig["tts"] = [
                "speaker": ttsSpeaker,
                "speech_rate": config.speechRate
            ]
        }

        let configJSON: String
        if let jsonData = try? JSONSerialization.data(withJSONObject: startConfig),
           let jsonStr = String(data: jsonData, encoding: .utf8) {
            configJSON = jsonStr
        } else {
            configJSON = "{\"dialog\":{\"bot_name\":\"\(config.botName)\"}}"
        }

        // 启动引擎（SDK 内部自动处理连接、会话、录音）
        print("[DialogEngine] 发送 StartEngine 指令, data: \(configJSON)")
        let startResult = engine.send(SEDirectiveStartEngine, data: configJSON)
        print("[DialogEngine] StartEngine 返回: \(startResult.rawValue)")

        if startResult != SENoError {
            DDLogError("[DialogEngine] StartEngine 失败: \(startResult.rawValue)")
            restoreAudioSessionIfNeeded()
            if completeTextReplyPlayback(
                .failure(
                    DialogTextReplyPlaybackError.directiveRejected(
                        code: Int(startResult.rawValue)
                    )
                ),
                stopsProviderSession: true
            ) {
                return
            }
            if let callbackContext = currentProviderCallbackContext(),
               finishProviderOperation(callbackContext) {
                deliverProviderCallback(
                    callbackContext,
                    requiresActiveOperation: false
                ) { _, delegate in
                    delegate.onError(
                        error: DialogEngineError.startFailed(
                            code: Int(startResult.rawValue)
                        )
                    )
                }
            }
            return
        }

        print("[DialogEngine] ⏳ 引擎启动中，等待回调...")
    }

    private func resolvedTTSSpeaker(for bindingHandle: DialogEngineBindingHandle) -> String {
        guard let speakerId = scopedTTSVoiceSelectionStore.resolvedVoiceProfileId(
            bindingID: bindingHandle.bindingId,
            accountLease: bindingHandle.accountLease
        ) else {
            DDLogInfo("[DialogEngine] 使用默认 TTS speaker: \(Self.defaultTTSSpeaker)")
            return Self.defaultTTSSpeaker
        }
        DDLogInfo("[DialogEngine] 使用声音复刻 TTS speaker: \(speakerId)")
        return speakerId
    }

    // MARK: - 关键词检测

    /// 检测 ASR 识别结果是否包含结束关键词
    private func checkEndKeyword(in text: String) -> String? {
        guard sessionLifetimePolicy == .automatic else { return nil }
        let lowered = text.lowercased()
        return config.endKeywords.first { lowered.contains($0) }
    }

    // MARK: - 静音超时计时器

    /// 启动/重置静音超时计时器
    private func resetSilenceTimer() {
        invalidateSilenceTimer()
        guard sessionLifetimePolicy == .automatic,
              !isRecorderPaused,
              config.silenceTimeoutSeconds > 0,
              let accountLease = activeDialogAccountLease,
              accountLeaseRuntime.validate(accountLease, at: .timer).allowed else { return }

        silenceTimer = Timer.scheduledTimer(
            withTimeInterval: config.silenceTimeoutSeconds,
            repeats: false
        ) { [weak self] _ in
            guard let self,
                  self.activeDialogAccountLease == accountLease,
                  self.accountLeaseRuntime.validate(accountLease, at: .timer).allowed,
                  self.isDialogActive else { return }
            print("[DialogEngine] ⏰ 静音超时 \(self.config.silenceTimeoutSeconds)秒，自动结束对话")
            self.stopDialog(reason: .silenceTimeout)
        }
    }

    /// 停止静音超时计时器
    private func invalidateSilenceTimer() {
        silenceTimer?.invalidate()
        silenceTimer = nil
    }
}

// MARK: - Provider callback provenance

extension DialogEngineManager {

    fileprivate func enqueueProviderMessage(
        type: SEMessageType,
        data: Data,
        engineGeneration: UUID
    ) {
        DispatchQueue.main.async { [weak self] in
            self?.handleProviderMessage(
                type: type,
                data: data,
                engineGeneration: engineGeneration
            )
        }
    }

    private func currentProviderCallbackContext(
        engineGeneration: UUID? = nil
    ) -> DialogEngineProviderCallbackContext? {
        guard let currentEngineGeneration = engineCallbackGeneration,
              engineGeneration == nil || engineGeneration == currentEngineGeneration,
              let dialogOperationId = activeDialogOperationId,
              let bindingHandle = activeDialogBindingHandle,
              let delegate,
              bindingHandle == boundBindingHandle,
              bindingHandle.bindingId == engineBindingId,
              activeDialogAccountLease == bindingHandle.accountLease,
              accountLeaseRuntime.validate(bindingHandle.accountLease, at: .runtime).allowed else {
            return nil
        }
        return DialogEngineProviderCallbackContext(
            engineGeneration: currentEngineGeneration,
            dialogOperationId: dialogOperationId,
            bindingHandle: bindingHandle,
            delegateIdentity: ObjectIdentifier(delegate)
        )
    }

    private func isCurrentProviderCallbackContext(
        _ context: DialogEngineProviderCallbackContext,
        checkpoint: AccountLeaseCheckpoint = .ui,
        requiresActiveOperation: Bool = true
    ) -> Bool {
        guard engineCallbackGeneration == context.engineGeneration,
              boundBindingHandle == context.bindingHandle,
              engineBindingId == context.bindingHandle.bindingId,
              let delegate,
              ObjectIdentifier(delegate) == context.delegateIdentity,
              accountLeaseRuntime.validate(
                context.bindingHandle.accountLease,
                at: checkpoint
              ).allowed else {
            return false
        }
        guard requiresActiveOperation else { return true }
        return activeDialogOperationId == context.dialogOperationId
            && activeDialogBindingHandle == context.bindingHandle
            && activeDialogAccountLease == context.bindingHandle.accountLease
    }

    private func deliverProviderCallback(
        _ context: DialogEngineProviderCallbackContext,
        checkpoint: AccountLeaseCheckpoint = .ui,
        requiresActiveOperation: Bool = true,
        _ action: (DialogEngineManager, DialogEngineDelegate) -> Void
    ) {
        guard isCurrentProviderCallbackContext(
            context,
            checkpoint: checkpoint,
            requiresActiveOperation: requiresActiveOperation
        ), let delegate else {
            DDLogWarn("[DialogEngine] 丢弃已失去来源归属的 provider 回调")
            return
        }
        action(self, delegate)
    }

    @discardableResult
    private func finishProviderOperation(
        _ context: DialogEngineProviderCallbackContext
    ) -> Bool {
        guard isCurrentProviderCallbackContext(
            context,
            checkpoint: .runtime,
            requiresActiveOperation: true
        ) else { return false }
        isDialogActive = false
        isRecorderPaused = false
        isAISpeaking = false
        activeDialogAccountLease = nil
        activeDialogBindingHandle = nil
        activeDialogOperationId = nil
        providerSessionOperationId = nil
        requiresEngineRecreationBeforeNextDialog = true
        return true
    }

    private func handleProviderMessage(
        type: SEMessageType,
        data: Data,
        engineGeneration: UUID
    ) {
        dispatchPrecondition(condition: .onQueue(.main))
        guard let callbackContext = currentProviderCallbackContext(
            engineGeneration: engineGeneration
        ) else {
            DDLogWarn(
                "[DialogEngine] 忽略失效 provider 回调 " +
                "type=\(type.rawValue) generation=\(engineGeneration.uuidString)"
            )
            return
        }
        switch type {
        case SEEventConnectionStarted,
             SEEventConnectionFailed,
             SEEventConnectionFinished,
             SEEventSessionStarted,
             SEEventSessionFailed,
             SEEventSessionFinished,
             SEEventSessionCanceled,
             SEEngineStart,
             SEEngineStop,
             SEEngineError:
            break
        default:
            guard providerSessionOperationId == callbackContext.dialogOperationId else {
                DDLogWarn(
                    "[DialogEngine] 忽略未归属到当前 session 的 provider 回调 " +
                    "type=\(type.rawValue)"
                )
                return
            }
        }
        // 正在结束对话时，忽略除连接/会话结束外的所有事件
        if isEnding {
            switch type {
            case SEEventConnectionFinished, SEEventSessionFinished, SEEventSessionCanceled:
                break // 这些事件需要继续处理
            default:
                return // 其他事件直接忽略
            }
        }

        let dataStr = String(data: data, encoding: .utf8) ?? "(binary \(data.count) bytes)"
        print("[DialogEngine] onMessage type=\(type.rawValue), data=\(dataStr.prefix(500))")

        if pendingTextReplyPlayback != nil {
            switch type {
            case SEEventConnectionStarted,
                 SEEventConnectionFailed,
                 SEEventConnectionFinished,
                 SEEventSessionStarted,
                 SEEventSessionFailed,
                 SEEventSessionFinished,
                 SEEventSessionCanceled,
                 SEEventTTSSentenceStart,
                 SEEventTTSSentenceEnd,
                 SEEventTTSResponse,
                 SEEventTTSEnded,
                 SEPlayerAudioData,
                 SEPlayerStartPlayAudio,
                 SEPlayerFinishPlayAudio,
                 SEEngineStart,
                 SEEngineStop,
                 SEEngineError:
                break
            default:
                DDLogVerbose(
                    "[DialogEngine] suppressed non-playback callback during text Echo"
                )
                return
            }
        }

        switch type {
        // MARK: Connection Events
        case SEEventConnectionStarted:
            print("[DialogEngine] ✅ 连接已建立")
            DDLogInfo("[DialogEngine] 连接已建立")

        case SEEventConnectionFailed:
            let msg = parseErrorMessage(from: data)
            print("[DialogEngine] ❌ 连接失败: \(msg)")
            DDLogError("[DialogEngine] 连接失败: \(msg)")
            if completeTextReplyPlayback(
                .failure(
                    DialogTextReplyPlaybackError.directiveRejected(
                        code: Int(type.rawValue)
                    )
                ),
                stopsProviderSession: true
            ) {
                return
            }
            guard finishProviderOperation(callbackContext) else { return }
            restoreAudioSessionIfNeeded()
            deliverProviderCallback(
                callbackContext,
                requiresActiveOperation: false
            ) { _, delegate in
                delegate.onError(
                    error: DialogEngineError.sdkError(
                        code: Int(type.rawValue),
                        message: msg
                    )
                )
            }

        case SEEventConnectionFinished:
            DDLogInfo("[DialogEngine] 连接已关闭")
            if completeTextReplyPlayback(
                .failure(DialogTextReplyPlaybackError.unavailable),
                stopsProviderSession: false
            ) {
                return
            }
            _ = finishProviderOperation(callbackContext)

        // MARK: Session Events
        case SEEventSessionStarted:
            print("[DialogEngine] ✅ 对话会话已开始")
            DDLogInfo("[DialogEngine] 对话会话已开始")
            isDialogActive = true
            providerSessionOperationId = callbackContext.dialogOperationId
            if pendingTextReplyPlayback != nil {
                submitPendingTextReplyPlayback()
                return
            }
            // 发送开场白
            sendGreetingIfNeeded()
            // 启动静音超时计时器
            deliverProviderCallback(callbackContext) { manager, delegate in
                manager.resetSilenceTimer()
                delegate.onDialogStarted()
            }

        case SEEventSessionFinished:
            DDLogInfo("[DialogEngine] 对话会话已结束")
            invalidateSilenceTimer()
            if completeTextReplyPlayback(
                .failure(DialogTextReplyPlaybackError.unavailable),
                stopsProviderSession: false
            ) {
                return
            }
            guard finishProviderOperation(callbackContext) else { return }
            deliverProviderCallback(
                callbackContext,
                requiresActiveOperation: false
            ) { _, delegate in
                delegate.onDialogEnded(reason: .serverEnded)
            }

        case SEEventSessionFailed:
            let msg = parseErrorMessage(from: data)
            print("[DialogEngine] ❌ 会话失败: \(msg)")
            DDLogError("[DialogEngine] 会话失败: \(msg)")
            if completeTextReplyPlayback(
                .failure(
                    DialogTextReplyPlaybackError.directiveRejected(
                        code: Int(type.rawValue)
                    )
                ),
                stopsProviderSession: true
            ) {
                return
            }
            guard finishProviderOperation(callbackContext) else { return }
            deliverProviderCallback(
                callbackContext,
                requiresActiveOperation: false
            ) { _, delegate in
                delegate.onError(
                    error: DialogEngineError.sdkError(
                        code: Int(type.rawValue),
                        message: msg
                    )
                )
            }

        case SEEventSessionCanceled:
            DDLogInfo("[DialogEngine] 会话已取消")
            invalidateSilenceTimer()
            if completeTextReplyPlayback(
                .failure(DialogTextReplyPlaybackError.unavailable),
                stopsProviderSession: false
            ) {
                return
            }
            guard finishProviderOperation(callbackContext) else { return }
            deliverProviderCallback(
                callbackContext,
                requiresActiveOperation: false
            ) { _, delegate in
                delegate.onDialogEnded(reason: .serverEnded)
            }

        // MARK: ASR Events
        case SEEventASRInfo:
            let asrRawStr = String(data: data, encoding: .utf8) ?? ""
            let parsedASRInfo = parseASRResult(from: data)

            // Live 模式允许用户直接开口打断本地 AI 播报。只有识别到非空
            // 用户文本时才发送 ClientInterrupt，避免纯播放器回声误触发。
            if isAISpeaking {
                let interruptText = parsedASRInfo?.text.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
                guard sessionLifetimePolicy == .userControlledLive,
                      !interruptText.isEmpty else {
                    print("[DialogEngine] 🎤 AI播报中，忽略ASRInfo回声")
                    return
                }
                interruptAI()
            }
            // 重置静音超时计时器
            deliverProviderCallback(callbackContext) { manager, _ in
                manager.resetSilenceTimer()
            }
            // 解析 ASR 结果
            print("[DialogEngine] 🎤 ASRInfo raw: \(asrRawStr.prefix(300))")

            if let result = parsedASRInfo {
                print("[DialogEngine] 🎤 ASRInfo parsed: text=\(result.text), isFinal=\(result.isFinal)")
                if result.isFinal {
                    if let keyword = checkEndKeyword(in: result.text) {
                        print("[DialogEngine] 🛑 检测到结束关键词: \(keyword)")
                        isEnding = true
                        deliverProviderCallback(callbackContext) { manager, delegate in
                            delegate.onASRResult(text: result.text, isFinal: true)
                            manager.stopDialog(reason: .keyword(keyword))
                        }
                        return
                    }
                }
                deliverProviderCallback(callbackContext) { _, delegate in
                    delegate.onASRResult(text: result.text, isFinal: result.isFinal)
                }
            } else {
                // 解析失败，尝试从 raw JSON 中提取任何文本
                print("[DialogEngine] ⚠️ ASRInfo parseASRResult 返回 nil，尝试 raw 提取")
                if let extractedText = extractAnyText(from: data) {
                    // 检测关键词
                    if let keyword = checkEndKeyword(in: extractedText) {
                        print("[DialogEngine] 🛑 raw 匹配到结束关键词: \(keyword)")
                        isEnding = true
                        deliverProviderCallback(callbackContext) { manager, delegate in
                            delegate.onASRResult(text: extractedText, isFinal: true)
                            manager.stopDialog(reason: .keyword(keyword))
                        }
                        return
                    }
                    // 转发为中间结果
                    deliverProviderCallback(callbackContext) { _, delegate in
                        delegate.onASRResult(text: extractedText, isFinal: false)
                    }
                } else {
                    // 最终兜底：raw string 中匹配关键词或提取中文文本
                    if let keyword = checkEndKeyword(in: asrRawStr) {
                        print("[DialogEngine] 🛑 raw string 匹配到结束关键词: \(keyword)")
                        isEnding = true
                        deliverProviderCallback(callbackContext) { manager, delegate in
                            delegate.onASRResult(text: keyword, isFinal: true)
                            manager.stopDialog(reason: .keyword(keyword))
                        }
                        return
                    }
                    // 尝试从 raw string 中提取引号内文本或中文字符
                    let chineseText = extractChineseText(from: asrRawStr)
                    if !chineseText.isEmpty {
                        deliverProviderCallback(callbackContext) { _, delegate in
                            delegate.onASRResult(text: chineseText, isFinal: false)
                        }
                    }
                }
            }

        case SEEventASRResponse:
            let parsedASRResponse = parseASRResult(from: data)
            if isAISpeaking {
                let interruptText = parsedASRResponse?.text.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
                guard sessionLifetimePolicy == .userControlledLive,
                      !interruptText.isEmpty else {
                    print("[DialogEngine] 🎤 AI播报中，忽略ASRResponse回声")
                    return
                }
                interruptAI()
            }
            // ASR 识别结果（流式，通过 is_interim 区分中间/最终）
            deliverProviderCallback(callbackContext) { manager, _ in
                manager.resetSilenceTimer()
            }
            if let result = parsedASRResponse {
                print("[DialogEngine] 🎤 ASRResponse: text=\(result.text), isFinal=\(result.isFinal)")
                if result.isFinal {
                    if let keyword = checkEndKeyword(in: result.text) {
                        print("[DialogEngine] 🛑 ASRResponse 检测到结束关键词: \(keyword)")
                        isEnding = true
                        deliverProviderCallback(callbackContext) { manager, delegate in
                            delegate.onASRResult(text: result.text, isFinal: true)
                            manager.stopDialog(reason: .keyword(keyword))
                        }
                        return
                    }
                }
                deliverProviderCallback(callbackContext) { _, delegate in
                    delegate.onASRResult(text: result.text, isFinal: result.isFinal)
                }
            }

        case SEEventASREnded:
            DDLogInfo("[DialogEngine] ASR 结束")

        case SEEventChatTextQueryConfirmed:
            let confirmedQueryText = parseQueryConfirmedText(from: data)
            if isAISpeaking {
                let interruptText = confirmedQueryText?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
                guard sessionLifetimePolicy == .userControlledLive,
                      !interruptText.isEmpty else {
                    print("[DialogEngine] 🎤 AI播报中，忽略ChatTextQueryConfirmed回声")
                    return
                }
                interruptAI()
            }
            // 用户语音已确认，这是发送给 LLM 的最终文本
            print("[DialogEngine] ✅ 用户语音确认: \(dataStr.prefix(300))")
            deliverProviderCallback(callbackContext) { manager, _ in
                manager.resetSilenceTimer()
            }
            // 解析用户查询文本
            if let queryText = confirmedQueryText, !queryText.isEmpty {
                // 检测结束关键词
                if let keyword = checkEndKeyword(in: queryText) {
                    print("[DialogEngine] 🛑 用户确认文本中检测到结束关键词: \(keyword)")
                    isEnding = true
                    deliverProviderCallback(callbackContext) { manager, delegate in
                        delegate.onASRResult(text: queryText, isFinal: true)
                        manager.stopDialog(reason: .keyword(keyword))
                    }
                    return
                }
                deliverProviderCallback(callbackContext) { _, delegate in
                    delegate.onASRResult(text: queryText, isFinal: true)
                }
            }

        // MARK: TTS Events
        case SEEventTTSSentenceStart:
            guard config.enablePlayer else {
                print("[DialogEngine] skipped Fire TTS sentence start; Tencent owns audible playback")
                return
            }
            // TTS 句子开始 - 标记 AI 正在播报
            isAISpeaking = true
            if pendingTextReplyPlayback != nil {
                return
            }
            // AI 说话时也重置静音计时器（AI 播报期间不应触发超时）
            deliverProviderCallback(callbackContext) { manager, _ in
                manager.resetSilenceTimer()
            }
            if let text = parseTTSText(from: data), !text.isEmpty {
                if !chatBuffer.isEmpty {
                    // streaming 已经展示了内容，不重复调用 onTTSStarted
                    chatBuffer = ""
                } else {
                    // 没有 streaming，TTS 是唯一的文本来源
                    deliverProviderCallback(callbackContext) { _, delegate in
                        delegate.onTTSStarted(text: text)
                    }
                }
            } else if !chatBuffer.isEmpty {
                // TTS 没文本但 streaming 已经展示了，清空 buffer 即可
                chatBuffer = ""
            }

        case SEEventTTSSentenceEnd:
            guard config.enablePlayer else {
                print("[DialogEngine] skipped Fire TTS sentence end; Tencent owns audible playback")
                return
            }
            if pendingTextReplyPlayback != nil {
                return
            }
            // 部分 SpeechEngine 版本在 SentenceStart 只给空文本，完整文本出现在
            // SentenceEnd。数字人主音频模式依赖这里的文本转交给腾讯云渲染。
            if let text = parseTTSText(from: data), !text.isEmpty {
                chatBuffer = ""
                deliverProviderCallback(callbackContext) { _, delegate in
                    delegate.onTTSStarted(text: text)
                }
            }

        case SEEventTTSEnded:
            guard config.enablePlayer else {
                print("[DialogEngine] skipped Fire TTS ended; Tencent owns audible playback")
                return
            }
            isAISpeaking = false
            DDLogInfo("[DialogEngine] TTS 播放结束")
            if let playback = pendingTextReplyPlayback {
                scheduleTextReplyPlaybackCompletionFallback(playbackID: playback.id)
                return
            }
            deliverProviderCallback(callbackContext) { _, delegate in
                delegate.onTTSFinished()
            }

        case SEPlayerFinishPlayAudio:
            guard config.enablePlayer else {
                print("[DialogEngine] skipped Fire player finish; Tencent owns audible playback")
                return
            }
            isAISpeaking = false
            DDLogInfo("[DialogEngine] 播放器播放完毕")
            if completeTextReplyPlayback(.success(()), stopsProviderSession: true) {
                return
            }
            deliverProviderCallback(callbackContext) { _, delegate in
                delegate.onTTSFinished()
            }

        // MARK: Chat Events
        case SEEventChatResponse:
            // AI 对话流式 chunk —— 拼接到 buffer，不直接展示
            if let text = parseChatText(from: data) {
                chatBuffer += text
                // 实时更新 UI（流式效果）
                let currentText = chatBuffer
                deliverProviderCallback(callbackContext) { _, delegate in
                    delegate.onChatStreaming(text: currentText)
                }
            }

        case SEEventChatEnded:
            DDLogInfo("[DialogEngine] Chat 结束")
            // 如果 chatBuffer 有内容但未通过 TTS 展示，展示它
            if !chatBuffer.isEmpty {
                let finalText = chatBuffer
                chatBuffer = ""
                deliverProviderCallback(callbackContext) { _, delegate in
                    delegate.onTTSStarted(text: finalText)
                }
            }

        // MARK: Engine Events
        case SEEngineStart:
            print("[DialogEngine] ✅ 引擎已启动 (SEEngineStart)")
            DDLogInfo("[DialogEngine] 引擎启动成功")
            // 开场白由 SEEventSessionStarted → sendGreetingIfNeeded() 统一发送，此处不重复

        case SEEngineStop:
            print("[DialogEngine] 引擎已停止 (SEEngineStop)")

        case SEEngineError:
            let msg = parseErrorMessage(from: data)
            print("[DialogEngine] ❌ 引擎错误: \(msg)")
            DDLogError("[DialogEngine] 引擎错误: \(msg)")
            if completeTextReplyPlayback(
                .failure(
                    DialogTextReplyPlaybackError.directiveRejected(
                        code: Int(type.rawValue)
                    )
                ),
                stopsProviderSession: true
            ) {
                return
            }
            deliverProviderCallback(callbackContext) { _, delegate in
                delegate.onError(
                    error: DialogEngineError.sdkError(
                        code: Int(type.rawValue),
                        message: msg
                    )
                )
            }

        default:
            print("[DialogEngine] 📨 未处理消息类型: \(type.rawValue), data: \(dataStr.prefix(200))")
            DDLogVerbose("[DialogEngine] 收到消息类型: \(type.rawValue)")
            // 兜底：未知事件中尝试提取 ASR 文本（部分 SDK 版本用不同事件类型发送 ASR 结果）
            if let extracted = extractAnyText(from: data), !extracted.isEmpty {
                // 只在包含中文字符时才认为是 ASR 结果（避免误抦引擎状态信息）
                let hasChinese = extracted.unicodeScalars.contains { $0.value >= 0x4E00 && $0.value <= 0x9FFF }
                if hasChinese {
                    print("[DialogEngine] 📨 default 分支提取到 ASR 文本: \(extracted)")
                    deliverProviderCallback(callbackContext) { manager, delegate in
                        manager.resetSilenceTimer()
                        delegate.onASRResult(text: extracted, isFinal: false)
                    }
                }
            }
        }
    }

    // MARK: - JSON Parsing Helpers

    private func submitPendingTextReplyPlayback() {
        guard let playback = pendingTextReplyPlayback,
              let engine else {
            return
        }

        let pauseResult = engine.send(SEDirectivePauseRecorder)
        guard pauseResult == SENoError else {
            completeTextReplyPlayback(
                .failure(
                    DialogTextReplyPlaybackError.directiveRejected(
                        code: Int(pauseResult.rawValue)
                    )
                ),
                stopsProviderSession: true
            )
            return
        }
        isRecorderPaused = true
        // startDialog(sendsGreeting: false) leaves this flag set because the
        // one-shot route bypasses sendGreetingIfNeeded(). Clear it so the next
        // real Live session keeps its normal greeting behavior.
        suppressGreetingForNextStart = false

        guard let payloadData = try? JSONSerialization.data(
            withJSONObject: ["content": playback.text],
            options: []
        ), let payload = String(data: payloadData, encoding: .utf8) else {
            completeTextReplyPlayback(
                .failure(DialogTextReplyPlaybackError.invalidText),
                stopsProviderSession: true
            )
            return
        }

        // SayHello is the same provider-side text-to-audio event already used
        // by the proven Live greeting path. It accepts arbitrary content and
        // keeps text Echo on the same realtime ticket, player, and role voice
        // without entering the microphone/LLM turn pipeline.
        let result = engine.send(SEDirectiveEventSayHello, data: payload)
        guard result == SENoError else {
            completeTextReplyPlayback(
                .failure(
                    DialogTextReplyPlaybackError.directiveRejected(
                        code: Int(result.rawValue)
                    )
                ),
                stopsProviderSession: true
            )
            return
        }
        playback.onStarted()
        print("[DialogEngine] text Echo reply submitted through realtime SayHello")
        DDLogInfo("[DialogEngine] text Echo reply submitted through realtime SayHello")
    }

    private func scheduleTextReplyPlaybackCompletionFallback(playbackID: UUID) {
        textReplyPlaybackFallbackWorkItem?.cancel()
        let characterCount = pendingTextReplyPlayback?.text.count ?? 0
        let delay = max(4.0, min(30.0, Double(characterCount) * 0.35))
        let workItem = DispatchWorkItem { [weak self] in
            guard let self,
                  self.pendingTextReplyPlayback?.id == playbackID else {
                return
            }
            self.completeTextReplyPlayback(.success(()), stopsProviderSession: true)
        }
        textReplyPlaybackFallbackWorkItem = workItem
        DispatchQueue.main.asyncAfter(deadline: .now() + delay, execute: workItem)
    }

    @discardableResult
    private func completeTextReplyPlayback(
        _ result: Result<Void, Error>,
        stopsProviderSession: Bool
    ) -> Bool {
        guard let playback = pendingTextReplyPlayback else { return false }
        textReplyPlaybackFallbackWorkItem?.cancel()
        textReplyPlaybackFallbackWorkItem = nil
        pendingTextReplyPlayback = nil
        if stopsProviderSession {
            closeTextReplyProviderSession()
        }
        playback.completion(result)
        return true
    }

    private func closeTextReplyProviderSession() {
        invalidateSilenceTimer()
        if activeDialogOperationId != nil {
            _ = engine?.send(SEDirectiveSyncStopEngine)
        }
        isDialogActive = false
        isRecorderPaused = false
        isAISpeaking = false
        isEnding = false
        activeDialogAccountLease = nil
        activeDialogBindingHandle = nil
        activeDialogOperationId = nil
        providerSessionOperationId = nil
        requiresEngineRecreationBeforeNextDialog = true
        restoreAudioSessionIfNeeded()
    }

    /// 解析 ASR 文本和是否为最终结果
    private func parseASRResult(from data: Data) -> (text: String, isFinal: Bool)? {
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else { return nil }

        // === 方式1: results[] 数组结构（实际 SDK 格式） ===
        // {"results": [{"text": "能听到我", "is_interim": true, ...}], "extra": {"origin_text": "能听到我"}}
        if let results = json["results"] as? [[String: Any]], let first = results.first {
            let text = first["text"] as? String ?? ""
            if !text.isEmpty {
                let isInterim = first["is_interim"] as? Bool ?? true
                return (text, !isInterim)  // is_interim=false 表示最终结果
            }
        }

        // === 方式2: extra.origin_text 字段（备用） ===
        if let extra = json["extra"] as? [String: Any],
           let originText = extra["origin_text"] as? String, !originText.isEmpty {
            let results = json["results"] as? [[String: Any]]
            let isInterim = results?.first?["is_interim"] as? Bool ?? true
            return (originText, !isInterim)
        }

        // === 方式3: 旧格式兼容 ===
        let definite = json["definite"] as? Int ?? 0
        let isFinal = (definite == 1)
        if let text = json["text"] as? String, !text.isEmpty { return (text, isFinal) }
        if let result = json["result"] as? String, !result.isEmpty { return (result, isFinal) }
        if let utterances = json["utterances"] as? [[String: Any]],
           let first = utterances.first,
           let text = first["text"] as? String, !text.isEmpty {
            let uttDefinite = first["definite"] as? Int ?? definite
            return (text, uttDefinite == 1)
        }
        return nil
    }

    private func parseTTSText(from data: Data) -> String? {
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else { return nil }
        if let text = json["text"] as? String { return text }
        if let sentence = json["sentence"] as? String { return sentence }
        return nil
    }

    /// 解析 ChatTextQueryConfirmed 事件中的用户查询文本
    private func parseQueryConfirmedText(from data: Data) -> String? {
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            // 非 JSON，直接尝试当作纯文本
            if let text = String(data: data, encoding: .utf8), !text.isEmpty {
                // 去掉引号和空白
                let cleaned = text.trimmingCharacters(in: CharacterSet.whitespacesAndNewlines.union(.init(charactersIn: "\"")))
                return cleaned.isEmpty ? nil : cleaned
            }
            return nil
        }
        // 常见字段名
        if let text = json["text"] as? String, !text.isEmpty { return text }
        if let query = json["query"] as? String, !query.isEmpty { return query }
        if let content = json["content"] as? String, !content.isEmpty { return content }
        if let input = json["input"] as? String, !input.isEmpty { return input }
        if let result = json["result"] as? String, !result.isEmpty { return result }
        if let message = json["message"] as? String, !message.isEmpty { return message }
        // 尝试从嵌套结构中查找
        if let asr = json["asr"] as? [String: Any] {
            if let text = asr["text"] as? String, !text.isEmpty { return text }
            if let result = asr["result"] as? String, !result.isEmpty { return result }
        }
        return nil
    }

    private func parseChatText(from data: Data) -> String? {
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else { return nil }
        if let text = json["text"] as? String { return text }
        if let content = json["content"] as? String { return content }
        if let message = json["message"] as? String { return message }
        // Dialog SDK 可能用 delta 字段表示增量文本
        if let delta = json["delta"] as? String { return delta }
        return nil
    }

    /// 从 JSON 中提取任何可用的文本字段（兆底方案）
    private func extractAnyText(from data: Data) -> String? {
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else { return nil }
        // 遍历所有常见文本字段名
        let textKeys = ["text", "result", "content", "sentence", "message", "transcript", "asr_text"]
        for key in textKeys {
            if let text = json[key] as? String, !text.isEmpty {
                return text
            }
        }
        // 尝试从嵌套结构中查找
        for (_, value) in json {
            if let dict = value as? [String: Any] {
                for key in textKeys {
                    if let text = dict[key] as? String, !text.isEmpty {
                        return text
                    }
                }
            }
            if let arr = value as? [[String: Any]], let first = arr.first {
                for key in textKeys {
                    if let text = first[key] as? String, !text.isEmpty {
                        return text
                    }
                }
            }
        }
        return nil
    }

    private func parseErrorMessage(from data: Data) -> String {
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            return String(data: data, encoding: .utf8) ?? "未知错误"
        }
        if let msg = json["message"] as? String { return msg }
        if let msg = json["error"] as? String { return msg }
        if let msg = json["msg"] as? String { return msg }
        if let error = json["err_msg"] as? [String: Any] {
            if let msg = error["message"] as? String { return msg }
            if let msg = error["error"] as? String { return msg }
            if let msg = error["msg"] as? String { return msg }
        }
        return "未知错误 (\(json))"
    }

    /// 从 raw string 中提取中文文本（最终兜底方案）
    private func extractChineseText(from rawStr: String) -> String {
        // 尝试匹配引号内的中文内容，如 "text":"..."
        let patterns = [
            "\"text\"\\s*:\\s*\"([^\"]+)\"",
            "\"result\"\\s*:\\s*\"([^\"]+)\"",
            "\"content\"\\s*:\\s*\"([^\"]+)\"",
            "\"sentence\"\\s*:\\s*\"([^\"]+)\"",
            "\"transcript\"\\s*:\\s*\"([^\"]+)\""
        ]
        for pattern in patterns {
            if let regex = try? NSRegularExpression(pattern: pattern),
               let match = regex.firstMatch(in: rawStr, range: NSRange(rawStr.startIndex..., in: rawStr)),
               let range = Range(match.range(at: 1), in: rawStr) {
                let text = String(rawStr[range])
                if !text.isEmpty { return text }
            }
        }
        return ""
    }

    // MARK: - 开场白

    /// 会话建立后发送开场白（有历史时用上下文关联，否则随机）
    private func sendGreetingIfNeeded() {
        guard let engine = engine else { return }
        guard !suppressGreetingForNextStart else {
            suppressGreetingForNextStart = false
            print("[DialogEngine] skipped greeting for resumed digital-human listening")
            DDLogInfo("[DialogEngine] 恢复数字人监听，跳过开场白")
            return
        }

        let memory = ConversationMemoryManager.shared.currentMemory
        let context = DigitalHumanContextStore.shared.current
        let shouldUseContextualGreeting = shouldExposePersonalContext(for: context)
        let greeting: String

        // 判断是否有有意义的上下文（四维度摘要至少1个维度）
        let hasContext = shouldUseContextualGreeting && memory.sessionCount > 0 && memory.lastSummary.hasAnyDimension

        if hasContext {
            // 有历史记忆 → 上下文关联开场白
            greeting = generateContextGreeting(memory: memory)
        } else {
            // 首次对话或无有意义上下文 → 系统推荐话题
            greeting = recommendedTopicGreeting()
        }

        let payload: [String: Any] = ["content": greeting]
        guard let jsonData = try? JSONSerialization.data(withJSONObject: payload),
              let jsonStr = String(data: jsonData, encoding: .utf8) else { return }

        let result = engine.send(SEDirectiveEventSayHello, data: jsonStr)
        if result == SENoError {
            print("[DialogEngine] ✅ 开场白已发送: \(greeting)")
        } else {
            print("[DialogEngine] ⚠️ 开场白发送失败: \(result.rawValue)")
        }
    }

    /// 生成上下文关联的开场白（基于四维度摘要 + 知识库，每次随机不重复）
    private func generateContextGreeting(memory: ConversationMemory) -> String {
        let summary = memory.lastSummary
        let sentence = summary.toNaturalSentence()

        // 【KBLite】尝试用知识库丰富开场白
        let kbHint = KBLiteManager.shared.buildGreetingHint()

        // 有自然摘要时，围绕摘要构造开场白
        if !sentence.isEmpty {
            let templates = [
                "又见面啦！上次您聊到\(sentence)，今天还想接着说说吗？",
                "您好呀！我还记着\(sentence)呢，后来又想起什么了没？",
                "您来啦！上次说的\(sentence)可真好，今天想再跟我讲讲吗？",
                "又见面了！\(sentence)那件事我一直记着呢，还想听听更多。",
                "您好！上次聊的\(sentence)太有意思了，今天想接着聊吗？",
            ]
            return templates.randomElement()!
        }

        // 如果知识库有人物信息，用人物做开场
        if !kbHint.isEmpty {
            let personTemplates: [String] = [
                "又见面啦！我还记得您说过\(kbHint)，今天想聊聊谁呀？",
                "您好呀！上次咱们提到\(kbHint)，今天想接着说说吗？",
                "您来啦！我记着\(kbHint)呢，今天想聊点什么？",
            ]
            return personTemplates.randomElement()!
        }

        // 只有个别维度，直接引用
        if !summary.person.isEmpty {
            return "又见面啦！上次您提到的\(summary.person)，后来怎么样了呀？"
        }
        if !summary.place.isEmpty {
            return "您好呀！上次聊到\(summary.place)，今天还想说说那儿的事吗？"
        }
        if !summary.event.isEmpty {
            return "您来啦！上次聊的\(summary.event)，今天想接着讲吗？"
        }
        if !summary.time.isEmpty {
            return "又见面啦！上次您聊起\(summary.time)的事，今天还想继续吗？"
        }

        // 四维度都为空，回退系统推荐
        return recommendedTopicGreeting()
    }

    /// 系统推荐话题开场白（无上下文时使用，每次随机不重复）
    private func recommendedTopicGreeting() -> String {
        let topics = [
            "您好呀，我是寻梦环游！今天想跟您聊聊天，您小时候最喜欢玩什么呀？",
            "您好！我是寻梦环游，今天想听您讲讲过去的事。您老家在哪儿呀？",
            "又见面啦！今天想聊点什么呢？要不跟我说说您最拿手的菜？",
            "您好呀！我是寻梦环游，今天有没有什么想跟我说的？比如小时候过年是什么样的？",
            "您好！今天天气不错，您以前这种天气都做什么呀？",
            "您好呀！我是寻梦环游，您还记不记得第一份工作是做什么的？",
            "又见面啦！今天想聊点什么？要不讲讲您跟老伴怎么认识的？",
            "您好！我是寻梦环游，小时候有没有哪种味道让您到现在都忘不了？",
            "您好呀！今天想听听您的故事，您有什么拿手本事吗？",
            "您好！我是寻梦环游，您有没有一直记在心里的人，想跟我聊聊？",
        ]
        return topics.randomElement()!
    }

    // MARK: - 记忆上下文构建

    /// 将历史记忆构建为 system_prompt 追加段落（基于四维度摘要 + 知识库）
    private func buildMemoryContext(memory: ConversationMemory) -> String {
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "M月d日"
        let dateStr = dateFormatter.string(from: memory.lastSessionDate)

        let summary = memory.lastSummary
        var context = "\n\n【用户记忆档案】\n"
        context += "- 这是第\(memory.sessionCount + 1)次和这位长辈聊天。\n"
        context += "- 上次聊天时间：\(dateStr)\n"

        if !summary.time.isEmpty {
            context += "- 提到的时间：\(summary.time)\n"
        }
        if !summary.place.isEmpty {
            context += "- 提到的地方：\(summary.place)\n"
        }
        if !summary.person.isEmpty {
            context += "- 提到的人物：\(summary.person)\n"
        }
        if !summary.event.isEmpty {
            context += "- 聊到的事件：\(summary.event)\n"
        }

        if summary.hasAnyDimension {
            let sentence = summary.toNaturalSentence()
            context += "- 上次对话摘要：\(sentence)\n"
        }

        // 【KBLite】附加知识库上下文（累计的人物、地点、事件、事实）
        let kbContext = KBLiteManager.shared.buildGenerationAllowedContextString(query: nil)
        if !kbContext.isEmpty {
            context += kbContext
        }

        // V4: legacy KBLite is a compatibility projection only. It must not
        // independently select follow-up questions or present inferred gaps as
        // an Echo instruction; authoritative recommendations come from the
        // Owner Truth recommendation flow after its policy checks.

        context += "\n请基于以上记忆自然地延续话题，让长辈感受到你记得他/她说过的事。\n"
        context += "不要直接报出以上信息，而是在对话中自然地引用。\n"
        context += "继续围绕时间、地点、人物、事件这四个维度追问细节，帮老人把故事讲完整。"

        return context
    }

    private func buildArchiveContext() -> String {
        let context = DigitalHumanContextStore.shared.current
        guard shouldExposeArchiveContext(for: context) else { return "" }
        return MemoryArchiveRepository.shared.contextSnapshot().promptSection
    }
}

// MARK: - Error

enum DialogEngineError: LocalizedError {
    case productionConfigurationMissing
    case initFailed(code: Int)
    case startFailed(code: Int)
    case audioSessionFailed
    case sdkError(code: Int, message: String)

    var errorDescription: String? {
        switch self {
        case .productionConfigurationMissing:
            return "实时语音凭据代理尚未开放，当前可继续使用文字回响"
        case .initFailed(let code):
            return "语音引擎初始化失败 (错误码: \(code))"
        case .startFailed(let code):
            return "语音对话启动失败 (错误码: \(code))"
        case .audioSessionFailed:
            return "音频配置失败，请重试"
        case .sdkError(_, let message):
            return "语音服务异常: \(message)"
        }
    }
}
#endif
