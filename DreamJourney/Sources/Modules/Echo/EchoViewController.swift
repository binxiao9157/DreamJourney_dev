import AVFoundation
import CryptoKit
import UIKit
#if UI_QA_SIMULATOR && targetEnvironment(simulator)
import Alamofire
#endif

/// Product duration is separate from recorder/SDK connection lifetime.
/// Pure monotonic state allows deadline/busy/late-callback tests without sleeping.
struct EchoLiveSessionLimit {
    enum Action: Equatable { case none, farewell, stalledClose, farewellTimeout }
    private(set) var startedAt: TimeInterval?
    private(set) var lastProgress: TimeInterval = 0
    private(set) var farewellAt: TimeInterval?
    private(set) var closed = false
    let duration: TimeInterval = 600
    let stalledWait: TimeInterval = 90
    let farewellBudget: TimeInterval = 20

    mutating func start(now: TimeInterval) {
        guard startedAt == nil, !closed else { return }
        startedAt = now; lastProgress = now
    }
    mutating func progress(now: TimeInterval) { lastProgress = now }
    mutating func cancel() { closed = true }
    mutating func tick(now: TimeInterval, busy: Bool) -> Action {
        guard !closed, let startedAt else { return .none }
        if let farewellAt {
            if now - farewellAt >= farewellBudget { closed = true; return .farewellTimeout }
            return .none
        }
        guard now - startedAt >= duration else { return .none }
        if busy {
            if now - max(lastProgress, startedAt + duration) >= stalledWait {
                closed = true; return .stalledClose
            }
            return .none
        }
        farewellAt = now
        return .farewell
    }
}

/// Local, fixed product farewell. Never injected as a provider/user message.
private final class EchoLiveFarewellSpeaker: NSObject, AVSpeechSynthesizerDelegate {
    private let synthesizer = AVSpeechSynthesizer()
    private var completion: (() -> Void)?
    override init() { super.init(); synthesizer.delegate = self }
    func speak(_ text: String, completion: @escaping () -> Void) {
        self.completion = completion
        let utterance = AVSpeechUtterance(string: text)
        utterance.voice = AVSpeechSynthesisVoice(language: "zh-CN")
        synthesizer.speak(utterance)
    }
    func cancel() {
        completion = nil
        synthesizer.stopSpeaking(at: .immediate)
    }
    func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didFinish utterance: AVSpeechUtterance) {
        finish()
    }
    func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didCancel utterance: AVSpeechUtterance) {
        finish()
    }
    private func finish() { let done = completion; completion = nil; done?() }
}

private enum EchoDigitalHumanAudioOwner: String {
    case tencentDigitalHuman
    case localPreview
    case fallbackMuted
    case volcengineLocalTTS

    var logLabel: String {
        "audioOwner=\(rawValue)"
    }
}

enum EchoLiveAudioRoute: Equatable {
    case volcengineLocalTTS
    case tencentDigitalHuman
    case unavailable(reason: String)

    var diagnosticCode: String {
        switch self {
        case .volcengineLocalTTS:
            return "volcengineLocalTTS"
        case .tencentDigitalHuman:
            return "tencentDigitalHuman"
        case .unavailable:
            return "unavailable"
        }
    }
}

enum EchoLiveAudioRoutePolicy {
    static func select(
        wantsDigitalHuman: Bool,
        providerCanOwnAudio: Bool
    ) -> EchoLiveAudioRoute {
        guard wantsDigitalHuman, providerCanOwnAudio else {
            return .volcengineLocalTTS
        }
        return .tencentDigitalHuman
    }
}

struct EchoRealtimeVoiceRuntimeFailureDiagnostic: Equatable {
    let stage: String
    let httpStatus: Int?
    let businessCode: String

    init(error: Error) {
        guard let backendFailure = error as? any OwnerTruthBackendFailureClassifying else {
            stage = "request"
            httpStatus = nil
            businessCode = "unknown"
            return
        }

        httpStatus = backendFailure.ownerTruthBackendStatusCode
        let code = backendFailure.ownerTruthBackendErrorCode ?? ""
        switch code {
        case "authenticatedVoiceSessionRequired":
            stage = "auth"
            businessCode = code
        case "echoLiveTargetRequired", "echoLiveTargetMismatch",
                "echoFamilyQueryNotAuthorized", "echoLivePersonaScopeInvalid",
                "realtimeVoiceSubjectUnavailable":
            stage = "targetAuthorization"
            businessCode = code
        case "formalMemorySnapshotUnavailable", "formalMemorySnapshotTooLarge":
            stage = "snapshot"
            businessCode = code
        case "realtimeVoiceFormalMemoryBindingInvalid":
            stage = "binding"
            businessCode = code
        case "realtimeVoiceConcurrentSessionLimit":
            stage = "ticketStore"
            businessCode = code
        case "realtimeVoiceUpstreamURLInvalid", "realtimeVoicePublicURLInvalid":
            stage = "capability"
            businessCode = code
        default:
            stage = "unknown"
            businessCode = "unknown"
        }
    }
}

enum EchoVoiceLaunchStage: String, Codable {
    case tap, permissionStart, permissionEnd, lease, policy, runtime, authentication
    case ticketCreated, ticketResumed, ticketResponse, decode
    case sdkConfigure, sdkStart, sessionStarted, audioActivation, listening, terminal
}

struct EchoVoiceLaunchDiagnosticRecord: Codable {
    let attemptID: String
    let recordedAt: Date
    let stage: EchoVoiceLaunchStage
    let elapsedMilliseconds: Int
    let requestCount: Int
    let ticketExposure: String
    let firstFailureStage: EchoVoiceLaunchStage?
    let errorFamily: String?
    let errorDomain: String?
    let errorCode: Int?
    let httpStatus: Int?
    let policyReason: String?
    let terminalReason: String?
}

final class EchoVoiceLaunchDiagnosticStore {
    static let shared = EchoVoiceLaunchDiagnosticStore()

    private let queue = DispatchQueue(label: "dreamjourney.echo.voice-launch-diagnostics", qos: .utility)
    private let rootDirectory: URL
    private var writeFailures = Set<String>()

    init(rootDirectory: URL? = nil) {
        self.rootDirectory = rootDirectory
            ?? FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
                .appendingPathComponent("EchoVoiceLaunchDiagnostics", isDirectory: true)
    }

    private func scope(_ ownerID: String) -> String {
        SHA256.hash(data: Data(ownerID.utf8)).map { String(format: "%02x", $0) }.joined()
    }

    private func url(for digest: String) -> URL {
        rootDirectory.appendingPathComponent("\(digest).json")
    }

    func record(_ snapshot: EchoVoiceLaunchDiagnosticRecord, ownerID: String) {
        let digest = scope(ownerID)
        queue.async {
            do {
                try FileManager.default.createDirectory(
                    at: self.rootDirectory, withIntermediateDirectories: true
                )
                let file = self.url(for: digest)
                var records = (try? Data(contentsOf: file)).flatMap {
                    try? JSONDecoder().decode([EchoVoiceLaunchDiagnosticRecord].self, from: $0)
                } ?? []
                records.append(snapshot)
                let bounded = Array(records.suffix(96))
                try JSONEncoder().encode(bounded).write(to: file, options: .atomic)
            } catch {
                self.writeFailures.insert(digest)
            }
        }
    }

    func recent(ownerID: String) -> [EchoVoiceLaunchDiagnosticRecord] {
        let digest = scope(ownerID)
        return queue.sync {
            guard let data = try? Data(contentsOf: url(for: digest)) else { return [] }
            return (try? JSONDecoder().decode([EchoVoiceLaunchDiagnosticRecord].self, from: data)) ?? []
        }
    }

    func persistenceFailed(ownerID: String) -> Bool {
        let digest = scope(ownerID)
        return queue.sync { writeFailures.contains(digest) }
    }

    func waitForPendingWrites() {
        queue.sync {}
    }
}

final class EchoVoiceLaunchAttempt {
    static let defaultTimeout: TimeInterval = 15

    let id = UUID().uuidString.lowercased()
    let accountLease: AccountLease?
    let initialCaptureID: UUID?
    let initialAudioLeaseID: UUID?
    private let ownerID: String
    private let timeout: TimeInterval
    private let now: () -> TimeInterval
    private let scheduleTimeout: (TimeInterval, DispatchWorkItem) -> Void
    private let store: EchoVoiceLaunchDiagnosticStore
    private let lock = NSLock()
    private let createdAt: TimeInterval
    private var deadline: TimeInterval?
    private var watchdog: DispatchWorkItem?
    private var cancelTicket: (() -> Void)?
    private var terminalReason: String?
    private var stage: EchoVoiceLaunchStage = .tap
    private var requestCount = 0
    private var exposure = "notCreated"
    private var firstFailureStage: EchoVoiceLaunchStage?
    private var firstErrorFamily: String?
    private var firstErrorDomain: String?
    private var firstErrorCode: Int?
    private var firstHTTPStatus: Int?
    private var firstPolicyReason: String?
    private var didSubmitSDKStart = false
    private var didResolvePermission = false

    init(
        ownerID: String,
        accountLease: AccountLease? = nil,
        initialCaptureID: UUID?,
        initialAudioLeaseID: UUID? = nil,
        timeout: TimeInterval = EchoVoiceLaunchAttempt.defaultTimeout,
        now: @escaping () -> TimeInterval = { ProcessInfo.processInfo.systemUptime },
        scheduleTimeout: @escaping (TimeInterval, DispatchWorkItem) -> Void = { delay, work in
            DispatchQueue.global(qos: .userInitiated).asyncAfter(
                deadline: .now() + delay, execute: work
            )
        },
        store: EchoVoiceLaunchDiagnosticStore = .shared
    ) {
        self.ownerID = ownerID
        self.accountLease = accountLease
        self.initialCaptureID = initialCaptureID
        self.initialAudioLeaseID = initialAudioLeaseID
        self.timeout = timeout
        self.now = now
        self.scheduleTimeout = scheduleTimeout
        self.store = store
        createdAt = now()
        store.record(snapshot(), ownerID: ownerID)
    }

    var isActive: Bool {
        lock.lock()
        defer { lock.unlock() }
        return terminalReason == nil && (deadline.map { now() < $0 } ?? true)
    }

    var sdkStartSubmitted: Bool {
        lock.lock()
        defer { lock.unlock() }
        return didSubmitSDKStart
    }

    func claimPermissionResponse() -> Bool {
        lock.lock()
        defer { lock.unlock() }
        guard terminalReason == nil, !didResolvePermission else { return false }
        didResolvePermission = true
        return true
    }

    func beginBudget(onTimeout: @escaping () -> Void) {
        lock.lock()
        guard terminalReason == nil, deadline == nil else { lock.unlock(); return }
        deadline = now() + timeout
        let work = DispatchWorkItem { [weak self] in
            guard self?.finishIfTimedOut() == true else { return }
            onTimeout()
        }
        watchdog = work
        lock.unlock()
        scheduleTimeout(timeout, work)
    }

    @discardableResult
    func finishIfTimedOut() -> Bool {
        lock.lock()
        guard terminalReason == nil, let deadline, now() >= deadline else {
            lock.unlock()
            return false
        }
        terminalReason = "timeout"
        firstFailureStage = firstFailureStage ?? stage
        firstErrorFamily = firstErrorFamily ?? "timeout"
        let cancel = cancelTicket
        cancelTicket = nil
        let snapshot = snapshot()
        lock.unlock()
        cancel?()
        store.record(snapshot, ownerID: ownerID)
        return true
    }

    func cancelIfPending() {
        if !finishIfTimedOut() {
            _ = finish("cancelled")
        }
    }

    @discardableResult
    func note(
        _ next: EchoVoiceLaunchStage,
        exposure nextExposure: String? = nil,
        ticketRequestOrdinal: Int? = nil
    ) -> Int? {
        lock.lock()
        guard terminalReason == nil else { lock.unlock(); return nil }
        if let ticketRequestOrdinal, ticketRequestOrdinal != requestCount {
            lock.unlock()
            return nil
        }
        let lateResume = next == .ticketResumed
            && exposure == "responseReceived"
            && stage != .ticketCreated
        if !lateResume { stage = next }
        if next == .sdkStart { didSubmitSDKStart = true }
        if next == .ticketCreated {
            requestCount += 1
            exposure = nextExposure ?? "requestCreated"
        } else if let nextExposure,
           Self.exposureRank(nextExposure) > Self.exposureRank(exposure) {
            exposure = nextExposure
        }
        let snapshot = snapshot()
        let ordinal = requestCount
        lock.unlock()
        store.record(snapshot, ownerID: ownerID)
        return ordinal
    }

    private static func exposureRank(_ value: String) -> Int {
        switch value {
        case "requestCreated": return 1
        case "taskResumed": return 2
        case "responseReceived": return 3
        default: return 0
        }
    }

    func bindTicketCancellation(_ cancel: @escaping () -> Void) {
        lock.lock()
        let shouldCancel = terminalReason != nil || (deadline.map { now() >= $0 } ?? false)
        if !shouldCancel { cancelTicket = cancel }
        lock.unlock()
        if shouldCancel { cancel() }
    }

    @discardableResult
    func finish(_ reason: String, error: Error? = nil) -> Bool {
        lock.lock()
        guard terminalReason == nil, deadline.map({ now() < $0 }) ?? true else {
            lock.unlock()
            return false
        }
        terminalReason = Self.safeTerminalReason(reason)
        if reason != "listening" {
            firstFailureStage = firstFailureStage ?? stage
        }
        if let error {
            firstFailureStage = firstFailureStage ?? stage
            let classified = Self.classify(error)
            firstErrorFamily = firstErrorFamily ?? classified.family
            firstHTTPStatus = firstHTTPStatus ?? classified.httpStatus
            if let urlErrorCode = classified.urlErrorCode {
                firstErrorDomain = NSURLErrorDomain
                firstErrorCode = urlErrorCode
            } else if let clientError = error as? DreamJourneyBackendClient.ClientError,
                      case .featurePolicyDenied(_, let policyReason) = clientError {
                firstPolicyReason = Self.safePolicyReason(policyReason)
            }
        }
        stage = reason == "listening" ? .listening : .terminal
        let cancel = reason == "listening" ? nil : cancelTicket
        cancelTicket = nil
        watchdog?.cancel()
        watchdog = nil
        let snapshot = snapshot()
        lock.unlock()
        cancel?()
        store.record(snapshot, ownerID: ownerID)
        return true
    }

    private static func safePolicyReason(_ value: String) -> String {
        let allowed: Set<String> = [
            "capturedPolicyExpired", "expiredPolicyCache", "policyVersionChanged",
            "localFeatureDisabled", "releasePolicyDenied", "accountGenerationChanged",
            "scopeMismatch", "productClosed",
        ]
        return allowed.contains(value) ? value : "other"
    }

    private static func safeTerminalReason(_ value: String) -> String {
        let allowed: Set<String> = [
            "listening", "timeout", "cancelled", "permissionDenied",
            "voiceLaunchTimeout", "accountLeaseInvalid",
            "backendVoiceRuntimeUnavailable", "productSessionMismatch",
            "liveAudioRouteUnavailable", "audioSessionCoordinatorActivationFailed",
            "providerCredentialBlocked", "backendVoiceRuntimeRequestFailed",
            "policyDenied", "sdkStartFailed",
        ]
        return allowed.contains(value) ? value : "other"
    }

    private static func classify(_ error: Error) -> (
        family: String, httpStatus: Int?, urlErrorCode: Int?
    ) {
        if let clientError = error as? DreamJourneyBackendClient.ClientError {
            switch clientError {
            case .featurePolicyDenied:
                return ("policyDenied", nil, nil)
            case .userAuthenticationRequired, .sessionUpgradeRequired:
                return ("authentication", nil, nil)
            case .accountScopeChanged:
                return ("accountChanged", nil, nil)
            case .invalidJSONResponse, .unsupportedJSONRoot:
                return ("decode", nil, nil)
            case .backendError(let statusCode, _):
                let diagnostic = EchoRealtimeVoiceRuntimeFailureDiagnostic(error: error)
                return (diagnostic.stage == "unknown" ? "backend" : diagnostic.stage,
                        statusCode, nil)
            case .recoveryAccessDenied:
                return ("recoveryAccessDenied", nil, nil)
            case .verifiedPreHandlerAuthenticationRejection:
                return ("authentication", 401, nil)
            }
        }
        if let code = DreamJourneyBackendClient.ownerTruthURLFailureCode(error) {
            return ("network", nil, code)
        }
        return ("request", nil, nil)
    }

    private func snapshot() -> EchoVoiceLaunchDiagnosticRecord {
        EchoVoiceLaunchDiagnosticRecord(
            attemptID: id,
            recordedAt: Date(),
            stage: stage,
            elapsedMilliseconds: max(0, Int((now() - createdAt) * 1_000)),
            requestCount: requestCount,
            ticketExposure: exposure,
            firstFailureStage: firstFailureStage,
            errorFamily: firstErrorFamily,
            errorDomain: firstErrorDomain,
            errorCode: firstErrorCode,
            httpStatus: firstHTTPStatus,
            policyReason: firstPolicyReason,
            terminalReason: terminalReason
        )
    }
}

private enum EchoLivePlaybackTerminalCause: Equatable {
    case finished
    case userInterrupted
    case providerFailed(code: String)
    case watchdogInterrupted

    var diagnosticCode: String {
        switch self {
        case .finished:
            return "finished"
        case .userInterrupted:
            return "userInterrupted"
        case .providerFailed:
            return "providerFailed"
        case .watchdogInterrupted:
            return "watchdogInterrupted"
        }
    }

    var detail: String? {
        if case .providerFailed(let code) = self {
            return code
        }
        return nil
    }
}

struct EchoLivePlaybackReceiptState: Equatable {
    let route: EchoLiveAudioRoute
    private(set) var phase: DialogEngineDelegatedPlaybackPhase = .submitted
    private(set) var replyID: String? = nil

    var didStart: Bool {
        phase == .audioStarted
    }

    @discardableResult
    mutating func acknowledgeStart(for callbackRoute: EchoLiveAudioRoute) -> Bool {
        guard callbackRoute == route else { return false }
        guard phase == .submitted
            || phase == .providerAccepted
            || phase == .synthesisEnded else { return false }
        phase = .audioStarted
        return true
    }

    func canComplete(for callbackRoute: EchoLiveAudioRoute) -> Bool {
        guard callbackRoute == route else { return false }
        return phase == .audioFinished
    }

    @discardableResult
    mutating func apply(
        _ progress: DialogEngineDelegatedPlaybackProgress,
        callbackRoute: EchoLiveAudioRoute
    ) -> Bool {
        guard callbackRoute == route else { return false }
        switch progress {
        case .providerAccepted(let nextReplyID):
            guard !nextReplyID.isEmpty,
                  phase == .submitted || phase == .providerAccepted,
                  replyID == nil || replyID == nextReplyID else { return false }
            replyID = nextReplyID
            phase = .providerAccepted
            return true
        case .audioActivityObserved(let nextReplyID):
            guard matches(nextReplyID),
                  phase == .providerAccepted
                    || phase == .audioStarted
                    || phase == .synthesisEnded else { return false }
            return true
        case .audioStarted(let nextReplyID):
            guard matches(nextReplyID),
                  phase == .providerAccepted
                    || phase == .audioStarted
                    || phase == .synthesisEnded else { return false }
            phase = .audioStarted
            return true
        case .synthesisEnded(let nextReplyID):
            guard matches(nextReplyID),
                  phase == .providerAccepted
                    || phase == .audioStarted
                    || phase == .synthesisEnded else { return false }
            phase = .synthesisEnded
            return true
        case .audioFinished(let nextReplyID):
            guard matches(nextReplyID),
                  phase == .providerAccepted
                    || phase == .audioStarted
                    || phase == .synthesisEnded
                    || phase == .audioFinished else { return false }
            phase = .audioFinished
            return true
        case .interrupted(let nextReplyID):
            guard phase != .audioFinished,
                  phase != .failed,
                  nextReplyID == nil || nextReplyID == replyID else { return false }
            phase = .interrupted
            return true
        case .failed(let nextReplyID, _):
            guard phase != .audioFinished,
                  nextReplyID == nil || nextReplyID == replyID else { return false }
            phase = .failed
            return true
        }
    }

    private func matches(_ nextReplyID: String) -> Bool {
        !nextReplyID.isEmpty && replyID == nextReplyID
    }
}

private struct EchoLiveAudioRouteLease {
    let id: UUID
    let route: EchoLiveAudioRoute
    let accountGeneration: UInt64
    let contextKey: String
}

private struct EchoLivePlaybackReceipt {
    let id: UUID
    var state: EchoLivePlaybackReceiptState
    let turnID: String
    let lifecycleToken: DigitalHumanLifecycleToken
    let submittedAt: Date
    let answerCharacterCount: Int
}

private struct EchoRoleVoiceProfileSelection {
    enum Source: String {
        case selfAssistantDefault
        case personalOwner
        case personalOwnerVoiceProfileMissing
        case familyVoiceNotPermitted
    }

    let voiceProfileId: String?
    let source: Source
    let contextOwnerId: String
    let displayName: String

    var shouldShowMissingStatus: Bool {
        switch source {
        case .selfAssistantDefault, .personalOwner, .familyVoiceNotPermitted:
            return false
        case .personalOwnerVoiceProfileMissing:
            return true
        }
    }

    var statusText: String {
        switch source {
        case .selfAssistantDefault:
            return "AI 助手使用默认音色"
        case .personalOwner:
            return "本人复刻音色正在回响"
        case .personalOwnerVoiceProfileMissing:
            return "本人暂未启用复刻音色"
        case .familyVoiceNotPermitted:
            return "家人复刻音色当前不可用于回响"
        }
    }
}

private struct EchoMemoryGapHandoff {
    enum Destination: String {
        case ownerInterview
        case familyContribution
    }

    let question: String
    let destination: Destination
    let contextKey: String
}

struct EchoRecentConversationBuffer: Equatable {
    static let maximumTurnCount = 6
    static let maximumTurnCharacters = 500
    static let maximumTotalCharacters = 2_400

    private(set) var turns: [EchoConversationTurn] = []
    private(set) var productSessionID = UUID().uuidString

    mutating func startUserTurn(_ rawText: String) -> [EchoConversationTurn] {
        let priorTurns = turns
        append(role: .user, text: rawText)
        return priorTurns
    }

    mutating func appendAssistantTurn(_ rawText: String) {
        append(role: .assistant, text: rawText)
    }

    mutating func reset() {
        turns.removeAll(keepingCapacity: true)
        productSessionID = UUID().uuidString
    }

    private mutating func append(role: EchoConversationTurn.Role, text rawText: String) {
        let normalized = rawText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !normalized.isEmpty else { return }
        let bounded = String(normalized.prefix(Self.maximumTurnCharacters))
        let turn = EchoConversationTurn(role: role, text: bounded)
        guard turns.last != turn else { return }
        turns.append(turn)
        while turns.count > Self.maximumTurnCount
                || turns.reduce(0, { $0 + $1.text.count }) > Self.maximumTotalCharacters {
            turns.removeFirst()
        }
    }
}

enum EchoLiveMemoryCaptureState: Equatable {
    case live
    case syncPaused
    case saving
    case coverageGap(unsealedTurnCount: Int)
    case queued
    case organizing
    case retryWaiting(attempt: Int, maxAttempts: Int)
    case pendingReview
    case empty
    case statusUnknown
    case terminalFailure(code: String?)
    case quarantined
    case unavailable

    var isTerminal: Bool {
        switch self {
        case .pendingReview, .empty, .terminalFailure, .quarantined, .unavailable:
            return true
        case .live, .syncPaused, .saving, .coverageGap, .queued, .organizing,
             .retryWaiting, .statusUnknown:
            return false
        }
    }

    var isAwaitingOrganizationStatus: Bool {
        switch self {
        case .queued, .organizing, .retryWaiting, .statusUnknown:
            return true
        case .live, .syncPaused, .saving, .coverageGap, .pendingReview, .empty,
             .terminalFailure, .quarantined, .unavailable:
            return false
        }
    }

    var allowsDeliveryPipeline: Bool {
        switch self {
        case .live, .syncPaused, .saving, .coverageGap:
            return true
        case .queued, .organizing, .retryWaiting, .pendingReview, .empty,
             .statusUnknown, .terminalFailure, .quarantined, .unavailable:
            return false
        }
    }
}

struct EchoLiveMemoryCaptureFirstFailure: Equatable {
    enum Stage: String {
        case memberRegistration
        case canonicalBody
        case closeIntent
        case closeWatermark
        case canonicalConflict
    }

    let stage: Stage
    let reason: String
}

struct EchoLiveMemoryFollowUpRecord: Codable, Equatable {
    let productSessionID: String
    let reviewBatchID: UUID
    let createdAt: Date
    var updatedAt: Date
    var lastRecoveryObservation: EchoLiveMemoryRecoveryObservation? = nil
}

enum EchoLiveMemoryRecoveryObservationKind: String, Codable, Equatable {
    case pendingReview
    case empty
    case terminalFailure
    case quarantined
}

struct EchoLiveMemoryRecoveryObservation: Codable, Equatable {
    let kind: EchoLiveMemoryRecoveryObservationKind
    let observedAt: Date
    let safeFailureCode: String?
}

enum EchoLiveMemoryFollowUpScanStatus: String, Equatable {
    case valid
    case absent
    case unreadable
    case decodeInvalid
    case schemaUnsupported
    case scopeMismatch
}

struct EchoLiveMemoryFollowUpScanOutcome: Equatable {
    let status: EchoLiveMemoryFollowUpScanStatus
    let records: [EchoLiveMemoryFollowUpRecord]
}

private struct EchoLiveMemoryFollowUpEnvelopeV2: Codable, Equatable {
    static let schemaVersion = "echo-live-memory-follow-up-v2"

    let schemaVersion: String
    let subjectID: String
    let vaultID: String
    let authorityEpoch: String
    let records: [EchoLiveMemoryFollowUpRecord]
}

/// Persists only opaque workflow coordinates after the server has durably
/// admitted a closed conversation. Transcript and memory values stay in the
/// authoritative backend; this store only lets another page instance resume
/// status reads without reusing the closed product session for a new Live.
final class EchoLiveMemoryFollowUpStore {
    static let shared = EchoLiveMemoryFollowUpStore()

    private let defaults: UserDefaults
    private let rootDirectory: URL
    private let fileManager: FileManager
    private let lock = NSLock()
    private let now: () -> Date

    init(
        defaults: UserDefaults = .standard,
        rootDirectory: URL? = nil,
        fileManager: FileManager = .default,
        now: @escaping () -> Date = Date.init
    ) {
        self.defaults = defaults
        self.fileManager = fileManager
        self.now = now
        let root = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? fileManager.urls(for: .documentDirectory, in: .userDomainMask).first
            ?? fileManager.temporaryDirectory
        if let rootDirectory {
            self.rootDirectory = rootDirectory
        } else if defaults === UserDefaults.standard {
            self.rootDirectory = root
                .appendingPathComponent("DreamJourney", isDirectory: true)
                .appendingPathComponent("EchoLiveMemoryFollowUp", isDirectory: true)
                .appendingPathComponent("v2", isDirectory: true)
        } else {
            // Suite-scoped defaults are test/preview stores. Keep their durable
            // files isolated so one synthetic account cannot leak coordinates
            // into another test that happens to use the same account fixture.
            self.rootDirectory = fileManager.temporaryDirectory
                .appendingPathComponent("DreamJourneyFollowUpTests", isDirectory: true)
                .appendingPathComponent(
                    String(describing: ObjectIdentifier(defaults)),
                    isDirectory: true
                )
        }
    }

    func records(for accountLease: AccountLease) -> [EchoLiveMemoryFollowUpRecord] {
        lock.lock()
        defer { lock.unlock() }
        return scanUnlocked(accountLease: accountLease).records
            .sorted { $0.createdAt < $1.createdAt }
    }

    func scan(for accountLease: AccountLease) -> EchoLiveMemoryFollowUpScanOutcome {
        lock.lock()
        defer { lock.unlock() }
        return scanUnlocked(accountLease: accountLease)
    }

    func upsert(
        productSessionID: String,
        reviewBatchID: OwnerTruthRecordID,
        for accountLease: AccountLease
    ) throws {
        lock.lock()
        defer { lock.unlock() }
        let timestamp = now()
        var records = try recordsForMutation(accountLease: accountLease)
        if let index = records.firstIndex(where: { $0.productSessionID == productSessionID }) {
            records[index] = EchoLiveMemoryFollowUpRecord(
                productSessionID: productSessionID,
                reviewBatchID: reviewBatchID.rawValue,
                createdAt: records[index].createdAt,
                updatedAt: timestamp,
                lastRecoveryObservation: records[index].lastRecoveryObservation
            )
        } else {
            records.append(EchoLiveMemoryFollowUpRecord(
                productSessionID: productSessionID,
                reviewBatchID: reviewBatchID.rawValue,
                createdAt: timestamp,
                updatedAt: timestamp
            ))
        }
        try write(records, accountLease: accountLease)
    }

    func remove(productSessionID: String, for accountLease: AccountLease) throws {
        lock.lock()
        defer { lock.unlock() }
        var records = try recordsForMutation(accountLease: accountLease)
        records.removeAll { $0.productSessionID == productSessionID }
        try write(records, accountLease: accountLease)
    }

    func recordRecoveryObservation(
        _ observation: EchoLiveMemoryRecoveryObservation,
        productSessionID: String,
        reviewBatchID: OwnerTruthRecordID,
        for accountLease: AccountLease
    ) throws {
        lock.lock()
        defer { lock.unlock() }
        var records = try recordsForMutation(accountLease: accountLease)
        guard let index = records.firstIndex(where: {
            $0.productSessionID == productSessionID
                && $0.reviewBatchID == reviewBatchID.rawValue
        }) else {
            throw OwnerTruthInterviewLiveTurnOutboxError.invalidPersistenceEnvelope
        }
        records[index].lastRecoveryObservation = observation
        try write(records, accountLease: accountLease)
    }

    private func recordsForMutation(
        accountLease: AccountLease
    ) throws -> [EchoLiveMemoryFollowUpRecord] {
        let outcome = scanUnlocked(accountLease: accountLease)
        switch outcome.status {
        case .valid, .absent:
            return outcome.records
        case .unreadable, .decodeInvalid, .schemaUnsupported, .scopeMismatch:
            throw OwnerTruthInterviewLiveTurnOutboxError.storageFailure
        }
    }

    private func scanUnlocked(
        accountLease: AccountLease
    ) -> EchoLiveMemoryFollowUpScanOutcome {
        let v2 = readV2Outcome(accountLease: accountLease)
        if v2.status == .valid { return v2 }

        let legacy = readLegacyOutcome(accountLease: accountLease)
        if legacy.status == .valid {
            // A valid V1 record is an explicit fallback. Repairing V2 is best
            // effort and the V1 copy remains available until V2 validates.
            try? writeV2(legacy.records, accountLease: accountLease)
            return legacy
        }
        if v2.status != .absent { return v2 }
        return legacy
    }

    private func write(
        _ records: [EchoLiveMemoryFollowUpRecord],
        accountLease: AccountLease
    ) throws {
        do {
            if records.isEmpty {
                let url = fileURL(accountLease)
                if fileManager.fileExists(atPath: url.path) {
                    try fileManager.removeItem(at: url)
                }
                defaults.removeObject(forKey: key(accountLease))
            } else {
                try writeV2(records, accountLease: accountLease)
                defaults.set(try JSONEncoder().encode(records), forKey: key(accountLease))
            }
        } catch {
            throw OwnerTruthInterviewLiveTurnOutboxError.storageFailure
        }
    }

    private func readLegacyOutcome(
        accountLease: AccountLease
    ) -> EchoLiveMemoryFollowUpScanOutcome {
        guard let data = defaults.data(forKey: key(accountLease)) else {
            return EchoLiveMemoryFollowUpScanOutcome(status: .absent, records: [])
        }
        do {
            return EchoLiveMemoryFollowUpScanOutcome(
                status: .valid,
                records: try JSONDecoder().decode(
                    [EchoLiveMemoryFollowUpRecord].self,
                    from: data
                )
            )
        } catch {
            return EchoLiveMemoryFollowUpScanOutcome(status: .decodeInvalid, records: [])
        }
    }

    private func readV2Outcome(
        accountLease: AccountLease
    ) -> EchoLiveMemoryFollowUpScanOutcome {
        let url = fileURL(accountLease)
        guard fileManager.fileExists(atPath: url.path) else {
            return EchoLiveMemoryFollowUpScanOutcome(status: .absent, records: [])
        }
        let data: Data
        do {
            data = try Data(contentsOf: url)
        } catch {
            return EchoLiveMemoryFollowUpScanOutcome(status: .unreadable, records: [])
        }
        let envelope: EchoLiveMemoryFollowUpEnvelopeV2
        do {
            envelope = try JSONDecoder().decode(EchoLiveMemoryFollowUpEnvelopeV2.self, from: data)
        } catch {
            return EchoLiveMemoryFollowUpScanOutcome(status: .decodeInvalid, records: [])
        }
        guard envelope.schemaVersion == EchoLiveMemoryFollowUpEnvelopeV2.schemaVersion else {
            return EchoLiveMemoryFollowUpScanOutcome(status: .schemaUnsupported, records: [])
        }
        guard envelope.subjectID == accountLease.subjectId,
              envelope.vaultID == accountLease.vaultId,
              envelope.authorityEpoch == accountLease.authorityEpoch else {
            return EchoLiveMemoryFollowUpScanOutcome(status: .scopeMismatch, records: [])
        }
        return EchoLiveMemoryFollowUpScanOutcome(status: .valid, records: envelope.records)
    }

    private func readV2(accountLease: AccountLease) throws -> EchoLiveMemoryFollowUpEnvelopeV2 {
        let data = try Data(contentsOf: fileURL(accountLease))
        let decoder = JSONDecoder()
        let envelope = try decoder.decode(EchoLiveMemoryFollowUpEnvelopeV2.self, from: data)
        guard envelope.schemaVersion == EchoLiveMemoryFollowUpEnvelopeV2.schemaVersion,
              envelope.subjectID == accountLease.subjectId,
              envelope.vaultID == accountLease.vaultId,
              envelope.authorityEpoch == accountLease.authorityEpoch else {
            throw OwnerTruthInterviewLiveTurnOutboxError.invalidPersistenceEnvelope
        }
        return envelope
    }

    private func writeV2(
        _ records: [EchoLiveMemoryFollowUpRecord],
        accountLease: AccountLease
    ) throws {
        let url = fileURL(accountLease)
        try fileManager.createDirectory(
            at: url.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        let envelope = EchoLiveMemoryFollowUpEnvelopeV2(
            schemaVersion: EchoLiveMemoryFollowUpEnvelopeV2.schemaVersion,
            subjectID: accountLease.subjectId,
            vaultID: accountLease.vaultId,
            authorityEpoch: accountLease.authorityEpoch,
            records: records
        )
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        try encoder.encode(envelope).write(to: url, options: .atomic)
        guard try readV2(accountLease: accountLease) == envelope else {
            throw OwnerTruthInterviewLiveTurnOutboxError.storageFailure
        }
    }

    func durableFileURLForTesting(for accountLease: AccountLease) -> URL {
        fileURL(accountLease)
    }

    private func fileURL(_ accountLease: AccountLease) -> URL {
        rootDirectory
            .appendingPathComponent(scopeDigest(accountLease), isDirectory: true)
            .appendingPathComponent("follow-up.json", isDirectory: false)
    }

    private func key(_ accountLease: AccountLease) -> String {
        "echo.live-memory-follow-up.v1.\(scopeDigest(accountLease))"
    }

    private func scopeDigest(_ accountLease: AccountLease) -> String {
        let scope = [
            accountLease.subjectId,
            accountLease.vaultId,
            accountLease.authorityEpoch,
        ].joined(separator: "|")
        let digest = SHA256.hash(data: Data(scope.utf8)).map {
            String(format: "%02x", $0)
        }.joined()
        return digest
    }
}

enum EchoLiveMemoryCompletionPhase: String, Codable, Equatable {
    case endPrepared
    case ended
    case acknowledgementPrepared
    case acknowledged
    case admissionPrepared
    case admitted

    fileprivate var order: Int {
        switch self {
        case .endPrepared: return 0
        case .ended: return 1
        case .acknowledgementPrepared: return 2
        case .acknowledged: return 3
        case .admissionPrepared: return 4
        case .admitted: return 5
        }
    }
}

struct EchoLiveMemoryCompletionCheckpoint: Codable, Equatable {
    static let schemaVersion = "echo-live-memory-completion-v1"

    let schemaVersion: String
    let productSessionID: String
    var phase: EchoLiveMemoryCompletionPhase
    var endCommand: OwnerTruthInterviewEndCommand?
    var endReceipt: OwnerTruthInterviewNaturalInputReceipt?
    var endTransportOutcome: EchoLiveMemoryCompletionTransportOutcome? = nil
    var acknowledgementCommand: OwnerTruthInterviewReviewBatchAcknowledgementCommand?
    var acknowledgementReceipt: OwnerTruthInterviewReviewBatchAcknowledgementReceipt?
    var acknowledgementTransportOutcome: EchoLiveMemoryCompletionTransportOutcome? = nil
    var admissionCommand: OwnerTruthInterviewCandidateProposalAdmissionCommand?
    var admittedReviewBatchID: OwnerTruthRecordID?
    var admissionTransportOutcome: EchoLiveMemoryCompletionTransportOutcome? = nil
    let createdAt: Date
    var updatedAt: Date
}

enum EchoLiveMemoryCompletionTransportOutcome: String, Codable, Equatable {
    case notSent
    case outcomeUnknown
    case serverRejected
    case committed
}

enum EchoLiveMemoryCompletionCheckpointScanStatus: String, Equatable {
    case valid
    case absent
    case unreadable
    case decodeInvalid
    case schemaUnsupported
    case scopeMismatch
}

struct EchoLiveMemoryCompletionCheckpointScanOutcome: Equatable {
    let productSessionID: String
    let status: EchoLiveMemoryCompletionCheckpointScanStatus
    let checkpoint: EchoLiveMemoryCompletionCheckpoint?
}

/// Atomic, account-scoped hand-off journal for the three completion commands.
/// It stores only opaque coordinates and version fences, never transcript text,
/// credentials, prompts, or provider responses.
final class EchoLiveMemoryCompletionCheckpointStore {
    static let shared = EchoLiveMemoryCompletionCheckpointStore()

    private let rootDirectory: URL
    private let fileManager: FileManager
    private let now: () -> Date
    private let lock = NSLock()

    init(
        rootDirectory: URL? = nil,
        fileManager: FileManager = .default,
        now: @escaping () -> Date = Date.init
    ) {
        self.fileManager = fileManager
        self.now = now
        let root = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? fileManager.urls(for: .documentDirectory, in: .userDomainMask).first
            ?? fileManager.temporaryDirectory
        self.rootDirectory = rootDirectory ?? root
            .appendingPathComponent("DreamJourney", isDirectory: true)
            .appendingPathComponent("EchoLiveMemoryCompletion", isDirectory: true)
            .appendingPathComponent("v1", isDirectory: true)
    }

    func load(
        productSessionID: String,
        for accountLease: AccountLease
    ) throws -> EchoLiveMemoryCompletionCheckpoint? {
        try withLock {
            let url = fileURL(productSessionID: productSessionID, accountLease: accountLease)
            guard fileManager.fileExists(atPath: url.path) else { return nil }
            return try read(url: url, productSessionID: productSessionID, accountLease: accountLease)
        }
    }

    func records(for accountLease: AccountLease) -> [EchoLiveMemoryCompletionCheckpoint] {
        do {
            return try withLock {
            let directory = scopeDirectoryURL(accountLease: accountLease)
            guard let urls = try? fileManager.contentsOfDirectory(
                at: directory,
                includingPropertiesForKeys: nil,
                options: [.skipsHiddenFiles]
            ) else {
                return []
            }
            let checkpoints: [EchoLiveMemoryCompletionCheckpoint] = urls.compactMap { url in
                guard let data = try? Data(contentsOf: url),
                      let checkpoint = try? Self.decoder().decode(
                        EchoLiveMemoryCompletionCheckpoint.self,
                        from: data
                      ),
                      checkpoint.schemaVersion == EchoLiveMemoryCompletionCheckpoint.schemaVersion,
                      url.deletingPathExtension().lastPathComponent
                        == Self.digest(normalizedProductSessionID(checkpoint.productSessionID)),
                      isValid(checkpoint) else {
                    return nil
                }
                return checkpoint
            }
            return checkpoints.sorted {
                $0.createdAt == $1.createdAt
                    ? $0.productSessionID < $1.productSessionID
                    : $0.createdAt < $1.createdAt
            }
            }
        } catch {
            return []
        }
    }

    func scan(
        productSessionID: String,
        for accountLease: AccountLease
    ) -> EchoLiveMemoryCompletionCheckpointScanOutcome {
        let normalizedSessionID = normalizedProductSessionID(productSessionID)
        return (try? withLock {
            let url = fileURL(
                productSessionID: normalizedSessionID,
                accountLease: accountLease
            )
            guard fileManager.fileExists(atPath: url.path) else {
                return EchoLiveMemoryCompletionCheckpointScanOutcome(
                    productSessionID: normalizedSessionID,
                    status: .absent,
                    checkpoint: nil
                )
            }
            let data: Data
            do {
                data = try Data(contentsOf: url)
            } catch {
                return EchoLiveMemoryCompletionCheckpointScanOutcome(
                    productSessionID: normalizedSessionID,
                    status: .unreadable,
                    checkpoint: nil
                )
            }
            guard let object = try? JSONSerialization.jsonObject(with: data),
                  let envelope = object as? [String: Any] else {
                return EchoLiveMemoryCompletionCheckpointScanOutcome(
                    productSessionID: normalizedSessionID,
                    status: .decodeInvalid,
                    checkpoint: nil
                )
            }
            guard let schemaVersion = envelope["schemaVersion"] as? String else {
                return EchoLiveMemoryCompletionCheckpointScanOutcome(
                    productSessionID: normalizedSessionID,
                    status: .decodeInvalid,
                    checkpoint: nil
                )
            }
            guard schemaVersion == EchoLiveMemoryCompletionCheckpoint.schemaVersion else {
                return EchoLiveMemoryCompletionCheckpointScanOutcome(
                    productSessionID: normalizedSessionID,
                    status: .schemaUnsupported,
                    checkpoint: nil
                )
            }
            guard let storedSessionID = envelope["productSessionID"] as? String,
                  normalizedProductSessionID(storedSessionID) == normalizedSessionID else {
                return EchoLiveMemoryCompletionCheckpointScanOutcome(
                    productSessionID: normalizedSessionID,
                    status: .scopeMismatch,
                    checkpoint: nil
                )
            }
            guard let checkpoint = try? Self.decoder().decode(
                EchoLiveMemoryCompletionCheckpoint.self,
                from: data
            ), isValid(checkpoint) else {
                return EchoLiveMemoryCompletionCheckpointScanOutcome(
                    productSessionID: normalizedSessionID,
                    status: .decodeInvalid,
                    checkpoint: nil
                )
            }
            return EchoLiveMemoryCompletionCheckpointScanOutcome(
                productSessionID: normalizedSessionID,
                status: .valid,
                checkpoint: checkpoint
            )
        }) ?? EchoLiveMemoryCompletionCheckpointScanOutcome(
            productSessionID: normalizedSessionID,
            status: .unreadable,
            checkpoint: nil
        )
    }

    @discardableResult
    func prepareEnd(
        _ command: OwnerTruthInterviewEndCommand,
        productSessionID: String,
        for accountLease: AccountLease
    ) throws -> EchoLiveMemoryCompletionCheckpoint {
        try withLock {
            let url = fileURL(productSessionID: productSessionID, accountLease: accountLease)
            if fileManager.fileExists(atPath: url.path) {
                let existing = try read(
                    url: url,
                    productSessionID: productSessionID,
                    accountLease: accountLease
                )
                guard existing.endCommand == command else {
                    throw OwnerTruthInterviewLiveTurnOutboxError.invalidPersistenceEnvelope
                }
                return existing
            }
            let timestamp = now()
            let checkpoint = EchoLiveMemoryCompletionCheckpoint(
                schemaVersion: EchoLiveMemoryCompletionCheckpoint.schemaVersion,
                productSessionID: productSessionID,
                phase: .endPrepared,
                endCommand: command,
                endReceipt: nil,
                acknowledgementCommand: nil,
                acknowledgementReceipt: nil,
                admissionCommand: nil,
                admittedReviewBatchID: nil,
                createdAt: timestamp,
                updatedAt: timestamp
            )
            try write(checkpoint, to: url, accountLease: accountLease)
            return checkpoint
        }
    }

    @discardableResult
    func acceptEnd(
        _ receipt: OwnerTruthInterviewNaturalInputReceipt,
        productSessionID: String,
        for accountLease: AccountLease
    ) throws -> EchoLiveMemoryCompletionCheckpoint {
        try update(productSessionID: productSessionID, accountLease: accountLease) { checkpoint in
            guard let command = checkpoint.endCommand, receipt.matches(command) else {
                throw OwnerTruthInterviewLiveTurnOutboxError.invalidPersistenceEnvelope
            }
            if checkpoint.phase.order >= EchoLiveMemoryCompletionPhase.ended.order {
                guard checkpoint.endReceipt == nil || checkpoint.endReceipt == receipt else {
                    throw OwnerTruthInterviewLiveTurnOutboxError.invalidPersistenceEnvelope
                }
                return
            }
            guard checkpoint.phase == .endPrepared else {
                throw OwnerTruthInterviewLiveTurnOutboxError.invalidPersistenceEnvelope
            }
            checkpoint.phase = .ended
            checkpoint.endReceipt = receipt
            checkpoint.endTransportOutcome = .committed
        }
    }

    @discardableResult
    func recordEndTransportOutcome(
        _ outcome: EchoLiveMemoryCompletionTransportOutcome,
        command: OwnerTruthInterviewEndCommand,
        productSessionID: String,
        for accountLease: AccountLease
    ) throws -> EchoLiveMemoryCompletionCheckpoint {
        try update(productSessionID: productSessionID, accountLease: accountLease) { checkpoint in
            guard checkpoint.phase == .endPrepared,
                  checkpoint.endCommand == command else {
                throw OwnerTruthInterviewLiveTurnOutboxError.invalidPersistenceEnvelope
            }
            checkpoint.endTransportOutcome = outcome
        }
    }

    @discardableResult
    func prepareAcknowledgement(
        _ command: OwnerTruthInterviewReviewBatchAcknowledgementCommand,
        productSessionID: String,
        for accountLease: AccountLease
    ) throws -> EchoLiveMemoryCompletionCheckpoint {
        try update(productSessionID: productSessionID, accountLease: accountLease) { checkpoint in
            if checkpoint.phase.order >= EchoLiveMemoryCompletionPhase.acknowledgementPrepared.order {
                guard checkpoint.acknowledgementCommand == command else {
                    throw OwnerTruthInterviewLiveTurnOutboxError.invalidPersistenceEnvelope
                }
                return
            }
            guard checkpoint.phase == .ended,
                  let receipt = checkpoint.endReceipt,
                  receipt.threadID == command.threadID,
                  receipt.sessionID == command.sessionID else {
                throw OwnerTruthInterviewLiveTurnOutboxError.invalidPersistenceEnvelope
            }
            checkpoint.phase = .acknowledgementPrepared
            checkpoint.acknowledgementCommand = command
        }
    }

    @discardableResult
    func acceptAcknowledgement(
        _ receipt: OwnerTruthInterviewReviewBatchAcknowledgementReceipt,
        productSessionID: String,
        for accountLease: AccountLease
    ) throws -> EchoLiveMemoryCompletionCheckpoint {
        try update(productSessionID: productSessionID, accountLease: accountLease) { checkpoint in
            guard let command = checkpoint.acknowledgementCommand, receipt.matches(command) else {
                throw OwnerTruthInterviewLiveTurnOutboxError.invalidPersistenceEnvelope
            }
            if checkpoint.phase.order >= EchoLiveMemoryCompletionPhase.acknowledged.order {
                guard checkpoint.acknowledgementReceipt == nil
                    || checkpoint.acknowledgementReceipt == receipt else {
                    throw OwnerTruthInterviewLiveTurnOutboxError.invalidPersistenceEnvelope
                }
                return
            }
            guard checkpoint.phase == .acknowledgementPrepared else {
                throw OwnerTruthInterviewLiveTurnOutboxError.invalidPersistenceEnvelope
            }
            checkpoint.phase = .acknowledged
            checkpoint.acknowledgementReceipt = receipt
            checkpoint.acknowledgementTransportOutcome = .committed
        }
    }

    @discardableResult
    func recordAcknowledgementTransportOutcome(
        _ outcome: EchoLiveMemoryCompletionTransportOutcome,
        command: OwnerTruthInterviewReviewBatchAcknowledgementCommand,
        productSessionID: String,
        for accountLease: AccountLease
    ) throws -> EchoLiveMemoryCompletionCheckpoint {
        try update(productSessionID: productSessionID, accountLease: accountLease) { checkpoint in
            guard checkpoint.phase == .acknowledgementPrepared,
                  checkpoint.acknowledgementCommand == command else {
                throw OwnerTruthInterviewLiveTurnOutboxError.invalidPersistenceEnvelope
            }
            checkpoint.acknowledgementTransportOutcome = outcome
        }
    }

    @discardableResult
    func prepareAdmission(
        _ command: OwnerTruthInterviewCandidateProposalAdmissionCommand,
        productSessionID: String,
        for accountLease: AccountLease
    ) throws -> EchoLiveMemoryCompletionCheckpoint {
        try update(productSessionID: productSessionID, accountLease: accountLease) { checkpoint in
            if checkpoint.phase.order >= EchoLiveMemoryCompletionPhase.admissionPrepared.order {
                guard checkpoint.admissionCommand == command else {
                    throw OwnerTruthInterviewLiveTurnOutboxError.invalidPersistenceEnvelope
                }
                return
            }
            guard checkpoint.phase == .acknowledged,
                  let receipt = checkpoint.acknowledgementReceipt,
                  receipt.reviewBatchID == command.reviewBatchID,
                  receipt.reviewBatchVersion == command.expectedReviewBatchVersion else {
                throw OwnerTruthInterviewLiveTurnOutboxError.invalidPersistenceEnvelope
            }
            checkpoint.phase = .admissionPrepared
            checkpoint.admissionCommand = command
        }
    }

    @discardableResult
    func acceptAdmission(
        _ receipt: OwnerTruthInterviewCandidateProposalAdmissionReceipt,
        productSessionID: String,
        for accountLease: AccountLease
    ) throws -> EchoLiveMemoryCompletionCheckpoint {
        try update(productSessionID: productSessionID, accountLease: accountLease) { checkpoint in
            guard let command = checkpoint.admissionCommand, receipt.matches(command) else {
                throw OwnerTruthInterviewLiveTurnOutboxError.invalidPersistenceEnvelope
            }
            if checkpoint.phase == .admitted {
                guard checkpoint.admittedReviewBatchID == receipt.reviewBatchID else {
                    throw OwnerTruthInterviewLiveTurnOutboxError.invalidPersistenceEnvelope
                }
                return
            }
            guard checkpoint.phase == .admissionPrepared else {
                throw OwnerTruthInterviewLiveTurnOutboxError.invalidPersistenceEnvelope
            }
            checkpoint.phase = .admitted
            checkpoint.admittedReviewBatchID = receipt.reviewBatchID
            checkpoint.admissionTransportOutcome = .committed
        }
    }

    @discardableResult
    func recordAdmissionTransportOutcome(
        _ outcome: EchoLiveMemoryCompletionTransportOutcome,
        command: OwnerTruthInterviewCandidateProposalAdmissionCommand,
        productSessionID: String,
        for accountLease: AccountLease
    ) throws -> EchoLiveMemoryCompletionCheckpoint {
        try update(productSessionID: productSessionID, accountLease: accountLease) { checkpoint in
            guard checkpoint.phase == .admissionPrepared,
                  checkpoint.admissionCommand == command else {
                throw OwnerTruthInterviewLiveTurnOutboxError.invalidPersistenceEnvelope
            }
            checkpoint.admissionTransportOutcome = outcome
        }
    }

    func remove(productSessionID: String, for accountLease: AccountLease) throws {
        try withLock {
            let url = fileURL(productSessionID: productSessionID, accountLease: accountLease)
            if fileManager.fileExists(atPath: url.path) {
                try fileManager.removeItem(at: url)
            }
        }
    }

    private func update(
        productSessionID: String,
        accountLease: AccountLease,
        mutation: (inout EchoLiveMemoryCompletionCheckpoint) throws -> Void
    ) throws -> EchoLiveMemoryCompletionCheckpoint {
        try withLock {
            let url = fileURL(productSessionID: productSessionID, accountLease: accountLease)
            var checkpoint = try read(
                url: url,
                productSessionID: productSessionID,
                accountLease: accountLease
            )
            try mutation(&checkpoint)
            checkpoint.updatedAt = now()
            try write(checkpoint, to: url, accountLease: accountLease)
            return checkpoint
        }
    }

    private func read(
        url: URL,
        productSessionID: String,
        accountLease: AccountLease
    ) throws -> EchoLiveMemoryCompletionCheckpoint {
        do {
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            let checkpoint = try decoder.decode(
                EchoLiveMemoryCompletionCheckpoint.self,
                from: Data(contentsOf: url)
            )
            guard checkpoint.schemaVersion == EchoLiveMemoryCompletionCheckpoint.schemaVersion,
                  checkpoint.productSessionID == normalizedProductSessionID(productSessionID),
                  isValid(checkpoint) else {
                throw OwnerTruthInterviewLiveTurnOutboxError.invalidPersistenceEnvelope
            }
            return checkpoint
        } catch let error as OwnerTruthInterviewLiveTurnOutboxError {
            throw error
        } catch {
            throw OwnerTruthInterviewLiveTurnOutboxError.invalidPersistenceEnvelope
        }
    }

    private func write(
        _ checkpoint: EchoLiveMemoryCompletionCheckpoint,
        to url: URL,
        accountLease: AccountLease
    ) throws {
        guard isValid(checkpoint) else {
            throw OwnerTruthInterviewLiveTurnOutboxError.invalidPersistenceEnvelope
        }
        do {
            let encoder = JSONEncoder()
            encoder.dateEncodingStrategy = .iso8601
            encoder.outputFormatting = [.sortedKeys]
            try KnowledgeLocalStoragePolicy.write(try encoder.encode(checkpoint), to: url)
        } catch {
            throw OwnerTruthInterviewLiveTurnOutboxError.storageFailure
        }
    }

    private func fileURL(productSessionID: String, accountLease: AccountLease) -> URL {
        scopeDirectoryURL(accountLease: accountLease)
            .appendingPathComponent(Self.digest(normalizedProductSessionID(productSessionID)) + ".json")
    }

    private func scopeDirectoryURL(accountLease: AccountLease) -> URL {
        let scope = [
            "echo-live-completion-scope-v1",
            accountLease.subjectId,
            accountLease.vaultId,
            accountLease.authorityEpoch,
        ].map { "\($0.utf8.count):\($0)" }.joined(separator: "|")
        let scopeDigest = Self.digest(scope)
        return rootDirectory
            .appendingPathComponent(scopeDigest, isDirectory: true)
    }

    private static func decoder() -> JSONDecoder {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }

    private func normalizedProductSessionID(_ value: String) -> String {
        value.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func isValid(_ checkpoint: EchoLiveMemoryCompletionCheckpoint) -> Bool {
        guard !normalizedProductSessionID(checkpoint.productSessionID).isEmpty,
              checkpoint.endCommand != nil else { return false }
        switch checkpoint.phase {
        case .endPrepared:
            return true
        case .ended:
            return checkpoint.endReceipt != nil
        case .acknowledgementPrepared:
            return checkpoint.endReceipt != nil && checkpoint.acknowledgementCommand != nil
        case .acknowledged:
            return checkpoint.acknowledgementReceipt != nil
        case .admissionPrepared:
            return checkpoint.acknowledgementReceipt != nil && checkpoint.admissionCommand != nil
        case .admitted:
            return checkpoint.admittedReviewBatchID != nil
        }
    }

    private func withLock<T>(_ body: () throws -> T) throws -> T {
        lock.lock()
        defer { lock.unlock() }
        return try body()
    }

    private static func digest(_ value: String) -> String {
        SHA256.hash(data: Data(value.utf8)).map { String(format: "%02x", $0) }.joined()
    }
}

/// Persists one user-controlled Live conversation through the V4 private
/// interview lane. Assistant turns remain context only; only owner turns can
/// become evidence for a pending memory candidate.
protocol EchoLiveMemoryCaptureClient:
    OwnerTruthInterviewNaturalInputClient,
    OwnerTruthInterviewPendingReviewBatchInboxClient,
    OwnerTruthInterviewReviewBatchAcknowledgementClient,
    OwnerTruthInterviewCandidateProposalAdmissionClient,
    OwnerTruthInterviewCandidateProposalStatusClient,
    OwnerTruthLiveDeliveryStatusClient {}

extension DreamJourneyBackendClient: EchoLiveMemoryCaptureClient {}

/// Registers provider transcript callbacks before the UI can close the Live
/// session. A callback accepted before `close()` keeps its original
/// coordinator identity even when its main-thread delivery runs later.
final class EchoCanonicalTranscriptIngress {
    typealias DeliveryScheduler = (@escaping () -> Void) -> Void

    private let lock = NSLock()
    private let coordinator: EchoLiveMemoryCaptureCoordinator
    private let scheduler: DeliveryScheduler
    private var isOpen = true

    init(
        coordinator: EchoLiveMemoryCaptureCoordinator,
        scheduler: @escaping DeliveryScheduler = { delivery in
            if Thread.isMainThread {
                delivery()
            } else {
                DispatchQueue.main.async(execute: delivery)
            }
        }
    ) {
        self.coordinator = coordinator
        self.scheduler = scheduler
    }

    @discardableResult
    func submit(_ event: NativeLiveCanonicalTranscriptEvent) -> Bool {
        lock.lock()
        guard isOpen else {
            lock.unlock()
            return false
        }
        let coordinator = coordinator
        lock.unlock()

        scheduler {
            guard coordinator.acceptsCanonicalTranscriptIngress else { return }
            coordinator.appendCanonicalTurn(event)
        }
        return true
    }

    @discardableResult
    func submitMember(_ member: NativeLiveCanonicalTranscriptMember) -> Bool {
        lock.lock()
        guard isOpen else {
            lock.unlock()
            return false
        }
        let coordinator = coordinator
        guard coordinator.acceptsCanonicalTranscriptIngress else {
            lock.unlock()
            return false
        }
        coordinator.registerCanonicalMember(member)
        lock.unlock()
        return true
    }

    /// Delivers a provider callback that was accepted and identity-frozen
    /// before this ingress was closed. New callbacks still fail at the router;
    /// this path only preserves the original session handoff for queued work.
    @discardableResult
    func reserveFrozen(_ member: NativeLiveCanonicalTranscriptMember) -> Bool {
        coordinator.reserveCanonicalHandoff(member)
    }

    @discardableResult
    func submitFrozen(
        member: NativeLiveCanonicalTranscriptMember?,
        event: NativeLiveCanonicalTranscriptEvent?
    ) -> Bool {
        guard member != nil || event != nil else { return false }
        let coordinator = coordinator
        scheduler {
            coordinator.completeCanonicalHandoff(member: member, event: event)
        }
        return true
    }

    func close() {
        lock.lock()
        isOpen = false
        lock.unlock()
    }
}

final class EchoLiveMemoryCaptureCoordinator {
    private struct Turn: Equatable {
        let delivery: OwnerTruthInterviewLiveTurnDelivery
        var dispatchState: OwnerTruthInterviewLiveTurnDispatchState

        var role: OwnerTruthInterviewNaturalInputMessageRole { delivery.role }
        var text: String { delivery.text }
    }

    private enum CanonicalPersistenceOperation {
        case member(NativeLiveCanonicalTranscriptMember)
        case event(NativeLiveCanonicalTranscriptEvent)
        case frozenHandoff(
            member: NativeLiveCanonicalTranscriptMember,
            event: NativeLiveCanonicalTranscriptEvent?
        )

        var stage: EchoLiveMemoryCaptureFirstFailure.Stage {
            switch self {
            case .member: return .memberRegistration
            case .event: return .canonicalBody
            case .frozenHandoff(_, let event):
                return event == nil ? .memberRegistration : .canonicalBody
            }
        }

        var estimatedByteCount: Int {
            switch self {
            case .member(let member):
                return 256
                    + member.canonicalTurnID.utf8.count
                    + member.handoffID.utf8.count
            case .event(let event):
                return 384
                    + event.canonicalTurnID.utf8.count
                    + event.text.utf8.count
                    + (event.observationID?.utf8.count ?? 0)
            case .frozenHandoff(let member, let event):
                return 384
                    + member.canonicalTurnID.utf8.count
                    + member.handoffID.utf8.count
                    + (event?.text.utf8.count ?? 0)
                    + (event?.observationID?.utf8.count ?? 0)
            }
        }

        var storeWrite: OwnerTruthInterviewLiveTurnOutboxStore.CanonicalWrite {
            switch self {
            case .member(let member): return .member(member)
            case .event(let event): return .event(event)
            case .frozenHandoff(let member, let event): return .handoff(member, event)
            }
        }

        var containsBody: Bool {
            switch self {
            case .event: return true
            case .frozenHandoff(_, let event): return event != nil
            case .member: return false
            }
        }
    }

    private struct CanonicalPersistenceDrainResult {
        let snapshot: OwnerTruthInterviewLiveTurnOutboxSnapshot?
        let persistedBody: Bool
        let failureStage: EchoLiveMemoryCaptureFirstFailure.Stage?
        let error: Error?
        let overflowed: Bool
    }

    let id = UUID()
    private let accountLease: AccountLease
    private let client: EchoLiveMemoryCaptureClient
    private let accountLeaseRuntime: AccountLeaseRuntimePort
    private let productSessionID: String
    private let completionTraceID = "b8-completion-\(UUID().uuidString.lowercased())"
    private let liveTurnOutboxStore: OwnerTruthInterviewLiveTurnOutboxStore
    private let followUpStore: EchoLiveMemoryFollowUpStore
    private let completionCheckpointStore: EchoLiveMemoryCompletionCheckpointStore
    private let criticalDiagnosticsStore: NativeLiveDiagnosticsRingStore
    /// Disk work must never happen on Volcengine's audio/ASR callback queue.
    /// This serial queue also preserves the local client sequence order.
    private let persistenceQueue = DispatchQueue(label: "com.dreamjourney.echo.live-memory-outbox")
    private let naturalInputPolicyAvailable: () -> Bool
    private let naturalInputPolicyRefresh: (@escaping (Bool) -> Void) -> Void
    private let candidateReviewPolicyAvailable: () -> Bool
    private let candidateReviewPolicyRefresh: (@escaping (Bool) -> Void) -> Void
    private let recoveryEnabled: Bool
    private var recoveryAccepted = false
    private var recoveryNegotiationInFlight = false
    private var recoveryProgress: OwnerTruthLiveRecoveryProgress?
    private var recoveryPublicationAuthorized = false
    private var recoveryOperationID: UUID?
    private var recoveryTimeout: DispatchWorkItem?
    private var recoveryTimer: DispatchWorkItem?
    private var recoveryObservedAt: Date?
    private var recoveryGracefulStopPersisted = false
    private(set) var recoveryGracefulStopPersistenceFinished = false
    private var recoveryDidRequestBackpressureStop = false
    private var recoveryBackpressureMonitor = OwnerTruthLiveBackpressureMonitor()
    var isPartialRecoveryPublication: Bool { recoveryProgress?.publication?.isPartial == true }
    var onRecoveryBackpressureStop: (() -> Void)?
    private var naturalInputUseCase: OwnerTruthInterviewNaturalInputUseCase?
    private var lastBoundNaturalInputReceipt: OwnerTruthInterviewNaturalInputReceipt?
    private var deliveryStatusPolicyRefreshGeneration: UInt = 0
    private var isDeliveryStatusPolicyRefreshInFlight = false
    private var deliveryStatusReadGeneration: UInt = 0
    private var isDeliveryStatusReadInFlight = false
    private var deliveryStatusTimeoutWorkItem: DispatchWorkItem?
    private struct DeliveryObservationRound {
        let id: UUID
        let startedAt: TimeInterval
        var requestCount: Int
    }
    private var deliveryObservationRound: DeliveryObservationRound?
    private var deliveryObservationRetryWorkItem: DispatchWorkItem?
    private let deliveryObservationNow: () -> TimeInterval
    private let deliveryObservationSchedule: (TimeInterval, @escaping () -> Void) -> DispatchWorkItem
    private var closingProgressTimeoutWorkItem: DispatchWorkItem?
    private var closingProgressGeneration: UInt = 0
    private var didAttemptClosingNaturalInputRecovery = false
    private var acknowledgementUseCase: OwnerTruthInterviewReviewBatchAcknowledgementUseCase?
    private var admissionUseCase: OwnerTruthInterviewCandidateProposalAdmissionUseCase?
    private var sameSessionStatusReader: EchoLiveMemoryRecoveryCoordinator?
    private var sameSessionStatusSubscriptionToken: UUID?
    private var queuedTurns: [Turn] = []
    private var inFlightTurn: Turn?
    private var inFlightRequestStartedAtUptime: UInt64?
    /// A process-local, single-use permit for retrying the exact append that a
    /// command-scoped status read proved was rejected before application.
    /// Durable `authenticationRetryExposed` is deliberately not a permit: once
    /// persisted, a rebuilt coordinator must treat the attempt as unknown.
    private var authorizedAuthenticationRetryMessageID: OwnerTruthRecordID?
    private var pendingAuthenticationRejectionEvidence:
        OwnerTruthInterviewPreHandlerAuthenticationRejectionEvidence?
    private var ownerTurnCount = 0
    private var capturedOwnerTurnCount = 0
    private var persistedOwnerTurnCount = 0
    private var lastClientSequenceNumber = 0
    private var unsealedCanonicalTurnCount = 0
    private var canonicalConflictCount = 0
    private(set) var firstCaptureFailure: EchoLiveMemoryCaptureFirstFailure?
    private(set) var canonicalCoverageSummary = OwnerTruthInterviewCanonicalCoverageSummary.empty
    private var preparedStartCommand: OwnerTruthInterviewNaturalInputStartCommand?
    private var startDispatchState: OwnerTruthInterviewLiveStartDispatchState?
    /// Optional aggregate-only instrumentation; callbacks must not perform disk I/O.
    private let persistenceCostObservation: ((String, Double, Int) -> Void)?
    private let pendingPersistenceLock = NSLock()
    private struct QueuedCanonicalWrite {
        let operation: CanonicalPersistenceOperation
        let enqueuedAt: TimeInterval
        let depth: Int
    }
    // Protected by pendingPersistenceLock. Capacity includes queued, in-flight,
    // and retained recovery operations, not just the failure buffer.
    private var queuedCanonicalWrites: [QueuedCanonicalWrite] = []
    private var outstandingCanonicalWriteCount = 0
    private var outstandingCanonicalWriteBytes = 0

    private var storedPendingPersistenceCount = 0
    private var storedCanonicalRecoveryCount = 0
    private var storedCanonicalPersistenceOverflowed = false
    private var reservedCanonicalHandoffIDs = Set<String>()
    private var reservedCanonicalHandoffs:
        [String: NativeLiveCanonicalTranscriptMember] = [:]
    /// Accessed only on `persistenceQueue`; mirrored count is protected above.
    private var canonicalPersistenceRecoveryBuffer: [CanonicalPersistenceOperation] = []
    private var canonicalPersistenceRecoveryBytes = 0
    /// Retry the original failed prefix before combining newer arrivals.
    private var failedCanonicalBatchCount = 0
    private var canonicalPersistenceOverflowed = false
    private var canonicalOverflowGapNeedsPersistence = false
    private var durableCaptureHandoffComplete = false {
        didSet {
            guard oldValue != durableCaptureHandoffComplete else { return }
            onCaptureOwnershipReleaseEligibilityChange?()
        }
    }
    private var diagnosticsSessionPinned = true
    private static let canonicalPersistenceRecoveryItemLimit = 128
    private static let canonicalPersistenceRecoveryByteLimit = 4 * 1_024 * 1_024
    private var isAcknowledgingInFlightTurn = false
    private var closeRequestPersisted = false
    private var closeIntentPersisted = false
    private var closeIntentPersistenceInFlight = false
    private var isCaptureOpen = true
    private var isClearingCompletedOutbox = false
    private var isFinishing = false
    private var didRequestEnd = false
    private var didBeginOrganization = false
    private var acceptedEndedReceiptIdentity: String?
    private var activeReviewBatchID: OwnerTruthRecordID?
    private var observerGeneration: UInt = 0
    private var isBackgrounded = false
    private var cleanupPending = false
    private var isRestoringLegacyClosingOutbox = false
    private var lifecycleObserver: NSObjectProtocol?
    private var lastOwnerText = ""
    private var lastOwnerTurnAt: Date?
    private var lastAssistantText = ""
    private var lastAssistantOwnerTurnCount = 0
    private static let duplicateOwnerTurnWindow: TimeInterval = 1.0
    private let organizationStatusTimeout: TimeInterval
    private let deliveryStatusTimeout: TimeInterval
    private let closingProgressTimeout: TimeInterval
    private let liveAuthorityNow: () -> Date

    private(set) var state: EchoLiveMemoryCaptureState = .live {
        didSet {
            guard oldValue != state else { return }
            PrivacySafeDiagnostics.log(
                subsystem: "EchoLiveMemory",
                event: "captureStateChanged",
                states: [
                    "from": String(describing: oldValue),
                    "to": String(describing: state),
                ],
                counts: [
                    "ownerTurnCount": ownerTurnCount,
                    "persistedOwnerTurnCount": persistedOwnerTurnCount,
                    "queuedTurnCount": queuedTurns.count,
                ]
            )
            onStateChange?(state)
            if state != .saving {
                cancelClosingProgressDeadline()
            }
        }
    }

    var onStateChange: ((EchoLiveMemoryCaptureState) -> Void)?
    var onCoverageSummaryChange: ((OwnerTruthInterviewCanonicalCoverageSummary) -> Void)?
    var onCaptureOwnershipReleaseEligibilityChange: (() -> Void)?

    var acceptsTurns: Bool {
        isCaptureOpen && !isFinishing
    }

    var acceptsCanonicalTranscriptIngress: Bool {
        accountLeaseRuntime.validate(accountLease, at: .request).allowed
    }

    var canReleaseCaptureOwnership: Bool {
        if recoveryAccepted && (recoveryOperationID != nil || !queuedTurns.isEmpty || inFlightTurn != nil) {
            return false
        }
        switch state {
        case .pendingReview, .empty, .terminalFailure, .quarantined:
            return pendingPersistenceCount == 0
                && pendingCanonicalHandoffCount == 0
                && pendingCanonicalRecoveryCount == 0
        case .unavailable, .coverageGap, .statusUnknown:
            return durableCaptureHandoffComplete
                && pendingPersistenceCount == 0
                && pendingCanonicalHandoffCount == 0
                && pendingCanonicalRecoveryCount == 0
        case .live, .syncPaused, .saving, .queued, .organizing, .retryWaiting:
            return false
        }
    }

    private func recordFirstCaptureFailure(
        stage: EchoLiveMemoryCaptureFirstFailure.Stage,
        error: Error,
        callbackOrdinal: UInt64? = nil
    ) {
        guard firstCaptureFailure == nil else { return }
        let reason: String
        switch error as? OwnerTruthInterviewLiveTurnOutboxError {
        case .storageFailure:
            reason = "storageFailure"
        case .invalidPersistenceEnvelope:
            reason = "invalidPersistenceEnvelope"
        case .canonicalTurnConflict:
            reason = "canonicalTurnConflict"
        case .closeSequenceMismatch:
            reason = "closeSequenceMismatch"
        case .invalidProductSessionID:
            reason = "invalidProductSessionID"
        case .turnAlreadyAcknowledged:
            reason = "turnAlreadyAcknowledged"
        case nil:
            reason = "unknownPersistenceFailure"
        }
        firstCaptureFailure = EchoLiveMemoryCaptureFirstFailure(
            stage: stage,
            reason: reason
        )
        criticalDiagnosticsStore.recordFirstCriticalFailure(
            accountLease: accountLease,
            providerSessionID: productSessionID,
            stage: stage.rawValue,
            reason: reason,
            callbackOrdinal: callbackOrdinal
        )
        PrivacySafeDiagnostics.log(
            subsystem: "EchoLiveMemory",
            event: "firstCaptureFailure",
            states: ["stage": stage.rawValue, "reason": reason],
            counts: [
                "pendingPersistenceCount": pendingPersistenceCount,
                "handoffCount": pendingCanonicalHandoffCount,
                "canonicalConflictCount": canonicalConflictCount,
            ]
        )
    }

    private var pendingPersistenceCount: Int {
        pendingPersistenceLock.lock()
        defer { pendingPersistenceLock.unlock() }
        return storedPendingPersistenceCount
    }

    private var pendingCanonicalHandoffCount: Int {
        pendingPersistenceLock.lock()
        defer { pendingPersistenceLock.unlock() }
        return reservedCanonicalHandoffIDs.count
    }

    private var pendingCanonicalRecoveryCount: Int {
        pendingPersistenceLock.lock()
        defer { pendingPersistenceLock.unlock() }
        return storedCanonicalRecoveryCount
    }

    private var hasCanonicalPersistenceOverflow: Bool {
        pendingPersistenceLock.lock()
        defer { pendingPersistenceLock.unlock() }
        return storedCanonicalPersistenceOverflowed
    }

    func reserveCanonicalHandoff(_ member: NativeLiveCanonicalTranscriptMember) -> Bool {
        guard accountLeaseRuntime.validate(accountLease, at: .request).allowed else {
            return false
        }
        pendingPersistenceLock.lock()
        defer { pendingPersistenceLock.unlock() }
        guard isCaptureOpen, !isFinishing else { return false }
        reservedCanonicalHandoffIDs.insert(member.handoffID)
        reservedCanonicalHandoffs[member.handoffID] = member
        return true
    }

    func completeCanonicalHandoff(
        member: NativeLiveCanonicalTranscriptMember?,
        event: NativeLiveCanonicalTranscriptEvent?
    ) {
        guard acceptsCanonicalTranscriptIngress else {
            if isFinishing {
                state = .unavailable
            }
            return
        }
        if let member {
            enqueueCanonicalPersistence(.frozenHandoff(member: member, event: event))
        } else if let event {
            appendCanonicalTurn(event)
        }
    }

    private func markCanonicalHandoffDurable(_ handoffID: String) {
        pendingPersistenceLock.lock()
        reservedCanonicalHandoffIDs.remove(handoffID)
        reservedCanonicalHandoffs.removeValue(forKey: handoffID)
        pendingPersistenceLock.unlock()
        onCaptureOwnershipReleaseEligibilityChange?()
    }

    private func beginPersistence() {
        pendingPersistenceLock.lock()
        storedPendingPersistenceCount += 1
        pendingPersistenceLock.unlock()
    }

    private func endPersistence() {
        pendingPersistenceLock.lock()
        storedPendingPersistenceCount = max(0, storedPendingPersistenceCount - 1)
        pendingPersistenceLock.unlock()
    }

    private func setCanonicalRecoveryCount(_ count: Int) {
        pendingPersistenceLock.lock()
        storedCanonicalRecoveryCount = count
        pendingPersistenceLock.unlock()
    }

    private func markCanonicalPersistenceOverflow() {
        pendingPersistenceLock.lock()
        storedCanonicalPersistenceOverflowed = true
        canonicalOverflowGapNeedsPersistence = true
        pendingPersistenceLock.unlock()
    }

    #if UI_QA_SIMULATOR && targetEnvironment(simulator)
    var isTurnDrainCompleteForUIQA: Bool {
        state == .live
            && ownerTurnCount > 0
            && pendingPersistenceCount == 0
            && pendingCanonicalHandoffCount == 0
            && pendingCanonicalRecoveryCount == 0
            && !hasCanonicalPersistenceOverflow
            && inFlightTurn == nil
            && queuedTurns.isEmpty
            && !isAcknowledgingInFlightTurn
    }
    #endif

    #if DEBUG
    var pendingCanonicalHandoffCountForTesting: Int {
        pendingCanonicalHandoffCount
    }


    var pendingCanonicalRecoveryCountForTesting: Int {
        pendingCanonicalRecoveryCount
    }

    func notifyWhenCanonicalPersistenceIdleForTesting(
        _ completion: @escaping () -> Void
    ) {
        persistenceQueue.async {
            DispatchQueue.main.async(execute: completion)
        }
    }
    #endif

    init(
        accountLease: AccountLease,
        client: EchoLiveMemoryCaptureClient = DreamJourneyBackendClient.shared,
        accountLeaseRuntime: AccountLeaseRuntimePort = AccountLeaseRuntime.shared,
        productSessionID: String? = nil,
        liveTurnOutboxStore: OwnerTruthInterviewLiveTurnOutboxStore = .shared,
        followUpStore: EchoLiveMemoryFollowUpStore = .shared,
        completionCheckpointStore: EchoLiveMemoryCompletionCheckpointStore = .shared,
        criticalDiagnosticsStore: NativeLiveDiagnosticsRingStore = .shared,
        persistenceCostObservation: ((String, Double, Int) -> Void)? = nil,
        recoveryEnabled: Bool = Bundle.main.object(forInfoDictionaryKey: "LiveRecoveryEnabled") as? Bool ?? false,
        organizationStatusTimeout: TimeInterval = 180,
        deliveryStatusTimeout: TimeInterval = 15,
        deliveryObservationNow: @escaping () -> TimeInterval = {
            ProcessInfo.processInfo.systemUptime
        },
        deliveryObservationSchedule: @escaping (TimeInterval, @escaping () -> Void) -> DispatchWorkItem = {
            delay, action in
            let item = DispatchWorkItem(block: action)
            DispatchQueue.main.asyncAfter(deadline: .now() + delay, execute: item)
            return item
        },
        closingProgressTimeout: TimeInterval = 15,
        liveAuthorityNow: @escaping () -> Date = Date.init,
        naturalInputPolicyAvailable: @escaping () -> Bool,
        naturalInputPolicyRefresh: @escaping (@escaping (Bool) -> Void) -> Void = { $0(false) },
        candidateReviewPolicyAvailable: @escaping () -> Bool,
        candidateReviewPolicyRefresh: @escaping (@escaping (Bool) -> Void) -> Void = {
            $0(false)
        }
    ) {
        self.accountLease = accountLease
        self.client = client
        self.accountLeaseRuntime = accountLeaseRuntime
        let normalizedProductSessionID = productSessionID?
            .trimmingCharacters(in: .whitespacesAndNewlines)
        self.productSessionID = normalizedProductSessionID?.isEmpty == false
            ? normalizedProductSessionID!
            : "echo_live_\(UUID().uuidString.lowercased())"
        self.liveTurnOutboxStore = liveTurnOutboxStore
        self.followUpStore = followUpStore
        self.completionCheckpointStore = completionCheckpointStore
        self.criticalDiagnosticsStore = criticalDiagnosticsStore
        self.persistenceCostObservation = persistenceCostObservation
        self.recoveryEnabled = recoveryEnabled
        self.organizationStatusTimeout = organizationStatusTimeout
        self.deliveryStatusTimeout = max(0.01, deliveryStatusTimeout)
        self.deliveryObservationNow = deliveryObservationNow
        self.deliveryObservationSchedule = deliveryObservationSchedule
        self.closingProgressTimeout = max(0.01, closingProgressTimeout)
        self.liveAuthorityNow = liveAuthorityNow
        self.naturalInputPolicyAvailable = naturalInputPolicyAvailable
        self.naturalInputPolicyRefresh = naturalInputPolicyRefresh
        self.candidateReviewPolicyAvailable = candidateReviewPolicyAvailable
        self.candidateReviewPolicyRefresh = candidateReviewPolicyRefresh
        criticalDiagnosticsStore.beginActiveSession(
            accountLease: accountLease,
            providerSessionID: self.productSessionID
        )
        criticalDiagnosticsStore.snapshotAsync(accountLease: accountLease, providerSessionID: self.productSessionID) { [weak self] snapshot in
            guard let self, let prior = snapshot.firstCriticalFailure,
                  let stage = EchoLiveMemoryCaptureFirstFailure.Stage(rawValue: prior.source),
                  let reason = prior.reason else { return }
            // The persisted first error precedes any new observation after rebuild.
            // Diagnostics restore never gates capture/close or changes their state.
            self.firstCaptureFailure = EchoLiveMemoryCaptureFirstFailure(stage: stage, reason: reason)
        }
        lifecycleObserver = NotificationCenter.default.addObserver(
            forName: .djAppLifecycleEventForwarded,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            guard let event = AppLifecycleEventNotification.event(from: notification.userInfo) else {
                return
            }
            self?.receiveLifecycleEvent(event)
        }
        if !restoreCompletionCheckpointIfNeeded() {
            restoreDurableTurnsIfNeeded()
        }
    }

    deinit {
        recoveryTimer?.cancel()
        recoveryTimeout?.cancel()
        releaseCriticalDiagnosticsPin()
        deliveryStatusTimeoutWorkItem?.cancel()
        deliveryObservationRetryWorkItem?.cancel()
        closingProgressTimeoutWorkItem?.cancel()
        stopSameSessionStatusObservation(suspend: true)
        if let lifecycleObserver {
            NotificationCenter.default.removeObserver(lifecycleObserver)
        }
    }

    var trackedProductSessionID: String { productSessionID }

    func releaseCaptureOwnership() {
        guard canReleaseCaptureOwnership else { return }
        releaseCriticalDiagnosticsPin()
    }

    private func releaseCriticalDiagnosticsPin() {
        guard diagnosticsSessionPinned else { return }
        diagnosticsSessionPinned = false
        criticalDiagnosticsStore.endActiveSession(
            accountLease: accountLease,
            providerSessionID: productSessionID
        )
    }

    func resumeOrganization(reviewBatchID: OwnerTruthRecordID) {
        guard state == .live, !didBeginOrganization else { return }
        didBeginOrganization = true
        activeReviewBatchID = reviewBatchID
        state = .queued
        persistFollowUpThenBeginObservation(reviewBatchID: reviewBatchID)
    }

    func appendOwnerTurn(_ text: String) {
        guard acceptsTurns, let normalized = normalizedTurn(text) else { return }
        let now = Date()
        if normalized == lastOwnerText,
           let lastOwnerTurnAt,
           now.timeIntervalSince(lastOwnerTurnAt) <= Self.duplicateOwnerTurnWindow {
            return
        }
        lastOwnerText = normalized
        lastOwnerTurnAt = now
        capturedOwnerTurnCount += 1
        turnSegments(normalized).forEach {
            persistAndEnqueue(role: .owner, text: $0)
        }
    }

    func appendAssistantTurn(_ text: String) {
        guard acceptsTurns,
              capturedOwnerTurnCount > 0,
              let normalized = normalizedTurn(text) else {
            return
        }
        guard normalized != lastAssistantText
                || lastAssistantOwnerTurnCount != capturedOwnerTurnCount else {
            return
        }
        lastAssistantText = normalized
        lastAssistantOwnerTurnCount = capturedOwnerTurnCount
        turnSegments(normalized).forEach {
            persistAndEnqueue(role: .assistant, text: $0)
        }
    }

    func appendCanonicalTurn(_ event: NativeLiveCanonicalTranscriptEvent) {
        guard acceptsTurns || isFinishing else { return }
        enqueueCanonicalPersistence(.event(event))
    }

    func registerCanonicalMember(_ member: NativeLiveCanonicalTranscriptMember) {
        guard acceptsTurns || isFinishing else { return }
        enqueueCanonicalPersistence(.member(member))
    }

    private func enqueueCanonicalPersistence(_ operation: CanonicalPersistenceOperation) {
        let observer = persistenceCostObservation
        pendingPersistenceLock.lock()
        guard !storedCanonicalPersistenceOverflowed,
              outstandingCanonicalWriteCount < Self.canonicalPersistenceRecoveryItemLimit,
              outstandingCanonicalWriteBytes + operation.estimatedByteCount <= Self.canonicalPersistenceRecoveryByteLimit else {
            pendingPersistenceLock.unlock()
            receiveCanonicalPersistenceDrain(CanonicalPersistenceDrainResult(snapshot: nil, persistedBody: false,
                failureStage: operation.stage, error: OwnerTruthInterviewLiveTurnOutboxError.storageFailure,
                overflowed: true), submitted: nil)
            return
        }
        outstandingCanonicalWriteCount += 1
        outstandingCanonicalWriteBytes += operation.estimatedByteCount
        storedPendingPersistenceCount += 1
        queuedCanonicalWrites.append(QueuedCanonicalWrite(operation: operation,
            enqueuedAt: observer == nil ? 0 : ProcessInfo.processInfo.systemUptime,
            depth: storedPendingPersistenceCount))
        pendingPersistenceLock.unlock()
        // Each admitted operation owns a bounded queue ticket. Earlier tickets
        // consume only already queued work, never wait to fill a batch.
        persistenceQueue.async { [weak self] in
            guard let self else { return }
            self.pendingPersistenceLock.lock()
            let entries = Array(self.queuedCanonicalWrites.prefix(32))
            self.queuedCanonicalWrites.removeFirst(entries.count)
            self.pendingPersistenceLock.unlock()
            guard !entries.isEmpty else { return }
            let startedAt = observer == nil ? 0 : ProcessInfo.processInfo.systemUptime
            for entry in entries {
                observer?("queueWait", (startedAt - entry.enqueuedAt) * 1000, entry.depth)
                self.canonicalPersistenceRecoveryBuffer.append(entry.operation)
                self.canonicalPersistenceRecoveryBytes += entry.operation.estimatedByteCount
            }
            self.setCanonicalRecoveryCount(self.canonicalPersistenceRecoveryBuffer.count)
            let result = self.drainCanonicalPersistenceBuffer()
            let durableAt = observer == nil ? 0 : ProcessInfo.processInfo.systemUptime
            observer?("durableExecution", (durableAt - startedAt) * 1000, entries.count)
            DispatchQueue.main.async { [weak self] in
                guard let self else { return }
                observer?("mainCompletionWait", (ProcessInfo.processInfo.systemUptime - durableAt) * 1000, entries.count)
                for _ in entries { self.endPersistence() }
                // Adopt one final snapshot, never publish it once per operation.
                self.receiveCanonicalPersistenceDrain(result, submitted: nil)
            }
        }
    }

    private func drainCanonicalPersistenceBuffer() -> CanonicalPersistenceDrainResult {
        var latestSnapshot: OwnerTruthInterviewLiveTurnOutboxSnapshot?
        var persistedBody = false

        if canonicalOverflowGapNeedsPersistence {
            do {
                latestSnapshot = try liveTurnOutboxStore.markCanonicalOverflowGap(
                    for: accountLease,
                    productSessionID: productSessionID
                )
                canonicalOverflowGapNeedsPersistence = false
            } catch {
                return CanonicalPersistenceDrainResult(
                    snapshot: nil,
                    persistedBody: false,
                    failureStage: .canonicalBody,
                    error: error,
                    overflowed: true
                )
            }
        }

        while let head = canonicalPersistenceRecoveryBuffer.first {
            let limit = failedCanonicalBatchCount > 0 ? failedCanonicalBatchCount : 32
            let batch = Array(canonicalPersistenceRecoveryBuffer.prefix(limit))
            do {
                let committed = try liveTurnOutboxStore.persistCanonicalBatch(batch.map(\.storeWrite),
                    for: accountLease, productSessionID: productSessionID)
                if let snapshot = committed.snapshot { latestSnapshot = snapshot }
                for operation in batch.prefix(committed.committedCount) {
                    persistedBody = persistedBody || operation.containsBody
                    if case .frozenHandoff(let member, _) = operation {
                        markCanonicalHandoffDurable(member.handoffID)
                    }
                    canonicalPersistenceRecoveryBytes -= operation.estimatedByteCount
                    pendingPersistenceLock.lock()
                    outstandingCanonicalWriteCount -= 1
                    outstandingCanonicalWriteBytes -= operation.estimatedByteCount
                    pendingPersistenceLock.unlock()
                }
                failedCanonicalBatchCount = max(0, failedCanonicalBatchCount - committed.committedCount)
                canonicalPersistenceRecoveryBuffer.removeFirst(committed.committedCount)
                setCanonicalRecoveryCount(canonicalPersistenceRecoveryBuffer.count)
                if let error = committed.firstError {
                    failedCanonicalBatchCount = batch.count - committed.committedCount
                    return CanonicalPersistenceDrainResult(snapshot: latestSnapshot, persistedBody: persistedBody,
                        failureStage: batch[committed.committedCount].stage, error: error, overflowed: false)
                }
            } catch {
                failedCanonicalBatchCount = batch.count
                return CanonicalPersistenceDrainResult(snapshot: latestSnapshot, persistedBody: persistedBody,
                    failureStage: head.stage, error: error, overflowed: false)
            }
        }

        return CanonicalPersistenceDrainResult(
            snapshot: latestSnapshot,
            persistedBody: persistedBody,
            failureStage: nil,
            error: nil,
            overflowed: false
        )
    }

    private func retryCanonicalPersistenceForFinish() {
        guard pendingCanonicalRecoveryCount > 0 || hasCanonicalPersistenceOverflow else {
            persistCloseIntent()
            return
        }
        beginPersistence()
        persistenceQueue.async { [weak self] in
            guard let self else { return }
            let result = self.drainCanonicalPersistenceBuffer()
            DispatchQueue.main.async { [weak self] in
                guard let self else { return }
                self.endPersistence()
                self.receiveCanonicalPersistenceDrain(result, submitted: nil)
            }
        }
    }

    private func receiveCanonicalPersistenceDrain(
        _ result: CanonicalPersistenceDrainResult,
        submitted operation: CanonicalPersistenceOperation?
    ) {
        if let snapshot = result.snapshot {
            ownerTurnCount = snapshot.ownerTurnCount
            capturedOwnerTurnCount = max(capturedOwnerTurnCount, snapshot.ownerTurnCount)
            lastClientSequenceNumber = snapshot.lastClientSequenceNumber
            applyCanonicalCoverage(
                snapshot,
                stage: result.persistedBody ? "turnUpsertAccepted" : "memberRegistrationAccepted"
            )
            applyPendingTurns(snapshot)
            if isFinishing, closeIntentPersisted {
                durableCaptureHandoffComplete =
                    snapshot.pendingCloseManifestHandoffCount == 0
                    && pendingCanonicalHandoffCount == 0
                    && pendingCanonicalRecoveryCount == 0
            }
            if result.persistedBody {
                ensureNaturalInputSession()
                advanceNaturalInputPipeline()
            }
        }

        if let error = result.error, let stage = result.failureStage {
            recordFirstCaptureFailure(stage: stage, error: error)
            if result.overflowed {
                markCanonicalPersistenceOverflow()
                isCaptureOpen = false
            }
            PrivacySafeDiagnostics.log(
                subsystem: "EchoLiveMemory",
                event: "canonicalPersistenceDeferred",
                states: [
                    "stage": stage.rawValue,
                    "reason": result.overflowed ? "bufferCapacityExceeded" : "storageFailure",
                ],
                counts: ["bufferedCount": pendingCanonicalRecoveryCount]
            )
            state = .unavailable
            return
        }

        switch operation {
        case .member(let member):
            PrivacySafeDiagnostics.log(
                subsystem: "EchoLiveMemory",
                event: "canonicalMemberRegistration",
                states: [
                    "accepted": "true",
                    "role": member.role.rawValue,
                    "ingressKind": member.ingressKind?.rawValue ?? "unknown",
                ],
                counts: ["ingressOrdinal": Int(member.ingressOrdinal)]
            )
        case .event(let event):
            PrivacySafeDiagnostics.log(
                subsystem: "EchoLiveMemory",
                event: "canonicalTurnUpsert",
                states: [
                    "accepted": "true",
                    "role": event.role.rawValue,
                    "finality": event.finality.rawValue,
                    "evidenceSource": event.evidenceSource.rawValue,
                ]
            )
        case .frozenHandoff(let member, let event):
            PrivacySafeDiagnostics.log(
                subsystem: "EchoLiveMemory",
                event: "canonicalFrozenHandoffPersisted",
                states: [
                    "role": member.role.rawValue,
                    "ingressKind": member.ingressKind?.rawValue ?? "unknown",
                    "hasBody": event == nil ? "false" : "true",
                ],
                counts: ["ingressOrdinal": Int(member.ingressOrdinal)]
            )
        case nil:
            break
        }

        if hasCanonicalPersistenceOverflow {
            state = .unavailable
            return
        }

        if let snapshot = result.snapshot, isFinishing {
            let blockingIssueCount = snapshot.unsealedCanonicalTurnCount
                + snapshot.canonicalConflictCount
            state = blockingIssueCount > 0
                ? .coverageGap(unsealedTurnCount: blockingIssueCount)
                : .saving
            persistCloseIntent()
        } else if state == .unavailable, !isFinishing {
            state = .live
        }
    }

    func persistRecoveryGracefulStop() {
        guard recoveryAccepted, !recoveryGracefulStopPersistenceFinished else { return }
        let store = liveTurnOutboxStore, lease = accountLease, session = productSessionID
        persistenceQueue.async { [weak self] in
            let result = Result { try store.requestRecoveryGracefulStop(for: lease, productSessionID: session) }
            DispatchQueue.main.async {
                guard let self else { return }
                self.recoveryGracefulStopPersistenceFinished = true
                if case .success = result {
                    self.recoveryGracefulStopPersisted = true
                    self.scheduleRecoveryPulse(after: 0)
                } else {
                    // Do not claim a successful save when the disk rejected the intent.
                    self.state = .unavailable
                }
            }
        }
    }

    func finish() {
        pendingPersistenceLock.lock()
        guard !isFinishing else {
            pendingPersistenceLock.unlock()
            return
        }
        isCaptureOpen = false
        isFinishing = true
        let hasPendingCanonicalHandoff = !reservedCanonicalHandoffIDs.isEmpty
        let acceptedHandoffs = Array(reservedCanonicalHandoffs.values)
        pendingPersistenceLock.unlock()
        if ownerTurnCount == 0,
           unsealedCanonicalTurnCount == 0,
           pendingPersistenceCount == 0,
           pendingCanonicalRecoveryCount == 0,
           !hasCanonicalPersistenceOverflow,
           !hasPendingCanonicalHandoff {
            queuedTurns.removeAll()
            state = .empty
            return
        }
        let blockingIssueCount = unsealedCanonicalTurnCount + canonicalConflictCount
        state = blockingIssueCount > 0
            ? .coverageGap(unsealedTurnCount: blockingIssueCount)
            : .saving
        armClosingProgressDeadline(stage: "finish")
        persistCloseIntent(acceptedHandoffs: acceptedHandoffs)
        retryCanonicalPersistenceForFinish()
    }

    @discardableResult
    private func restoreCompletionCheckpointIfNeeded() -> Bool {
        let checkpoint: EchoLiveMemoryCompletionCheckpoint
        do {
            guard let stored = try completionCheckpointStore.load(
                productSessionID: productSessionID,
                for: accountLease
            ) else {
                return false
            }
            checkpoint = stored
        } catch {
            state = .statusUnknown
            return true
        }

        isFinishing = true
        isCaptureOpen = false
        closeRequestPersisted = true
        closeIntentPersisted = true
        didRequestEnd = true
        switch checkpoint.phase {
        case .endPrepared, .ended, .acknowledgementPrepared, .acknowledged,
             .admissionPrepared:
            // Reconstructed coordinators never replay completion writes. The
            // B6 recovery service owns bounded, account-scoped status GETs.
            state = .statusUnknown
        case .admitted:
            guard let reviewBatchID = checkpoint.admittedReviewBatchID else {
                state = .statusUnknown
                return true
            }
            didBeginOrganization = true
            activeReviewBatchID = reviewBatchID
            state = .queued
            persistFollowUpThenBeginObservation(reviewBatchID: reviewBatchID)
        }
        return true
    }

    private func restoreDurableTurnsIfNeeded() {
        do {
            guard let snapshot = try liveTurnOutboxStore.load(
                for: accountLease,
                productSessionID: productSessionID
            ) else {
                return
            }
            ownerTurnCount = snapshot.ownerTurnCount
            capturedOwnerTurnCount = snapshot.ownerTurnCount
            lastClientSequenceNumber = snapshot.lastClientSequenceNumber
            applyCanonicalCoverage(snapshot, stage: "durableRestore")
            preparedStartCommand = snapshot.preparedStartCommand
            startDispatchState = snapshot.startDispatchState
            recoveryAccepted = snapshot.acceptedRecoveryProtocol == "live-recovery-v1"
            recoveryProgress = snapshot.recoveryProgress
            if recoveryAccepted { scheduleRecoveryPulse(after: 0) }
            if snapshot.hasCanonicalOverflowGap {
                markCanonicalPersistenceOverflow()
                canonicalOverflowGapNeedsPersistence = false
            }
            queuedTurns = snapshot.pendingTurns.map {
                Turn(
                    delivery: $0,
                    dispatchState: snapshot.pendingDispatchStates[$0.messageID] ?? .outcomeUnknown
                )
            }
            persistedOwnerTurnCount = max(
                0,
                snapshot.ownerTurnCount - snapshot.pendingTurns.filter { $0.role == .owner }.count
            )
            isFinishing = snapshot.isClosing
            isCaptureOpen = !snapshot.isClosing
            closeRequestPersisted = snapshot.closeRequestedLastClientSequenceNumber != nil
            closeIntentPersisted = snapshot.isClosing
            isRestoringLegacyClosingOutbox = snapshot.isClosing && !recoveryAccepted
            if snapshot.isClosing && queuedTurns.isEmpty && !recoveryAccepted {
                // Legacy snapshots did not persist the end command. With no
                // remaining stable append command, starting a new interview
                // would attach the close to the wrong conversation.
                state = .statusUnknown
                return
            }
            if !queuedTurns.isEmpty || isFinishing {
                ensureNaturalInputSession()
                DispatchQueue.main.async { [weak self] in
                    self?.advanceNaturalInputPipeline()
                }
            }
        } catch {
            state = .unavailable
        }
    }

    private func persistAndEnqueue(
        role: OwnerTruthInterviewNaturalInputMessageRole,
        text: String
    ) {
        beginPersistence()
        let accountLease = accountLease
        let productSessionID = productSessionID
        let store = liveTurnOutboxStore
        persistenceQueue.async { [weak self] in
            let result = Result {
                try store.enqueue(
                    role: role,
                    text: text,
                    for: accountLease,
                    productSessionID: productSessionID
                )
            }
            DispatchQueue.main.async {
                guard let self else { return }
                self.endPersistence()
                switch result {
                case .success(let snapshot):
                    self.ownerTurnCount = snapshot.ownerTurnCount
                    self.lastClientSequenceNumber = snapshot.lastClientSequenceNumber
                    self.applyPendingTurns(snapshot)
                    self.ensureNaturalInputSession()
                    if self.isFinishing {
                        self.persistCloseIntent()
                    } else {
                        self.persistCloseRequestIfReady()
                    }
                    self.advanceNaturalInputPipeline()
                case .failure(let error):
                    self.recordFirstCaptureFailure(stage: .canonicalBody, error: error)
                    self.isCaptureOpen = false
                    self.state = .unavailable
                }
            }
        }
    }

    private func applyPendingTurns(_ snapshot: OwnerTruthInterviewLiveTurnOutboxSnapshot) {
        let deliveries = snapshot.pendingTurns
        let inFlightMessageID = inFlightTurn?.delivery.messageID
        let dispatchStates = snapshot.pendingDispatchStates
        let deliveryIDs = Set(deliveries.map(\.messageID))
        queuedTurns.removeAll { !deliveryIDs.contains($0.delivery.messageID) }
        for delivery in deliveries where delivery.messageID != inFlightMessageID {
            let state = dispatchStates[delivery.messageID] ?? .outcomeUnknown
            if let index = queuedTurns.firstIndex(where: {
                $0.delivery.messageID == delivery.messageID
            }) {
                queuedTurns[index].dispatchState = state
            } else {
                queuedTurns.append(Turn(delivery: delivery, dispatchState: state))
            }
        }
        queuedTurns.sort {
            $0.delivery.clientSequenceNumber < $1.delivery.clientSequenceNumber
        }
    }

    private func applyCanonicalCoverage(
        _ snapshot: OwnerTruthInterviewLiveTurnOutboxSnapshot,
        stage: String
    ) {
        let previousSummary = canonicalCoverageSummary
        let previousConflictCount = canonicalConflictCount
        unsealedCanonicalTurnCount = snapshot.unsealedCanonicalTurnCount
        canonicalConflictCount = snapshot.canonicalConflictCount
        canonicalCoverageSummary = snapshot.canonicalCoverageSummary
        if previousConflictCount == 0, snapshot.canonicalConflictCount > 0 {
            recordFirstCaptureFailure(
                stage: .canonicalConflict,
                error: OwnerTruthInterviewLiveTurnOutboxError.canonicalTurnConflict,
                callbackOrdinal: snapshot.firstCanonicalConflictIngressOrdinal
            )
        }
        let summary = snapshot.canonicalCoverageSummary
        PrivacySafeDiagnostics.log(
            subsystem: "EchoLiveMemory",
            event: "canonicalCoverageObserved",
            states: [
                "stage": stage,
                "firstGapRole": summary.firstGapRole?.rawValue ?? "none",
                "firstGapReason": summary.firstGapReason?.rawValue ?? "none",
                "firstGapIngressKind": summary.firstGapIngressKind?.rawValue ?? "unknown",
                "firstConflictReason": snapshot.firstCanonicalConflictReason?.rawValue ?? "none",
                "hasPersistedLocalText": summary.hasPersistedLocalText ? "true" : "false",
            ],
            counts: [
                "registeredMembers": summary.registeredMemberCount,
                "membersWithoutBody": summary.memberWithoutBodyCount,
                "partialTurns": summary.partialTurnCount,
                "completeBlockedTurns": summary.completeBlockedTurnCount,
                "deliveryCount": summary.deliveryCount,
                "serverConfirmedCount": summary.serverConfirmedCount,
                "firstGapOrdinal": summary.firstGapOrdinal ?? 0,
                "firstGapIngressOrdinal": Int(summary.firstGapIngressOrdinal ?? 0),
                "canonicalConflictCount": snapshot.canonicalConflictCount,
            ]
        )
        if previousSummary != summary {
            onCoverageSummaryChange?(summary)
        }
    }

    private func persistCloseRequestIfReady() {
        guard isFinishing,
              closeIntentPersisted,
              pendingPersistenceCount == 0,
              pendingCanonicalHandoffCount == 0,
              pendingCanonicalRecoveryCount == 0,
              !hasCanonicalPersistenceOverflow,
              unsealedCanonicalTurnCount == 0,
              canonicalConflictCount == 0,
              ownerTurnCount > 0,
              !closeRequestPersisted else {
            return
        }
        let lastClientSequenceNumber = max(
            self.lastClientSequenceNumber,
            queuedTurns.last?.delivery.clientSequenceNumber ?? 0,
            inFlightTurn?.delivery.clientSequenceNumber ?? 0
        )
        guard lastClientSequenceNumber > 0 else { return }
        let accountLease = accountLease
        let productSessionID = productSessionID
        let store = liveTurnOutboxStore
        closeRequestPersisted = true
        persistenceQueue.async { [weak self] in
            let result = Result {
                try store.markClosing(
                    lastClientSequenceNumber: lastClientSequenceNumber,
                    for: accountLease,
                    productSessionID: productSessionID
                )
            }
            DispatchQueue.main.async {
                guard let self else { return }
                switch result {
                case .success:
                    self.scheduleRecoveryPulse(after: 0)
                    self.armClosingProgressDeadline(stage: "closeWatermarkPersisted")
                    self.ensureNaturalInputSession()
                    self.advanceNaturalInputPipeline()
                case .failure(let error):
                    self.recordFirstCaptureFailure(stage: .closeWatermark, error: error)
                    self.closeRequestPersisted = false
                    self.state = .unavailable
                }
            }
        }
    }

    private func persistCloseIntent(
        acceptedHandoffs: [NativeLiveCanonicalTranscriptMember]? = nil
    ) {
        guard isFinishing else { return }
        if acceptedHandoffs == nil {
            guard pendingPersistenceCount == 0,
                  pendingCanonicalHandoffCount == 0,
                  pendingCanonicalRecoveryCount == 0 else {
                return
            }
        }
        guard !closeIntentPersisted,
              !closeIntentPersistenceInFlight else {
            persistCloseRequestIfReady()
            return
        }
        closeIntentPersistenceInFlight = true
        let accountLease = accountLease
        let productSessionID = productSessionID
        let store = liveTurnOutboxStore
        persistenceQueue.async { [weak self] in
            let result = Result {
                try store.requestClose(
                    acceptedHandoffs: acceptedHandoffs ?? [],
                    for: accountLease,
                    productSessionID: productSessionID
                )
            }
            DispatchQueue.main.async {
                guard let self else { return }
                self.closeIntentPersistenceInFlight = false
                switch result {
                case .success(let snapshot):
                    self.ownerTurnCount = snapshot.ownerTurnCount
                    self.capturedOwnerTurnCount = max(
                        self.capturedOwnerTurnCount,
                        snapshot.ownerTurnCount
                    )
                    self.lastClientSequenceNumber = snapshot.lastClientSequenceNumber
                    self.applyCanonicalCoverage(snapshot, stage: "closeIntentPersisted")
                    self.applyPendingTurns(snapshot)
                    self.closeIntentPersisted = true
                    self.scheduleRecoveryPulse(after: 0)
                    self.durableCaptureHandoffComplete =
                        snapshot.pendingCloseManifestHandoffCount == 0
                        && self.pendingCanonicalHandoffCount == 0
                        && self.pendingCanonicalRecoveryCount == 0
                    let blockingIssueCount = snapshot.unsealedCanonicalTurnCount
                        + snapshot.canonicalConflictCount
                    self.state = blockingIssueCount > 0
                        ? .coverageGap(
                            unsealedTurnCount: blockingIssueCount
                        )
                        : .saving
                    self.armClosingProgressDeadline(stage: "closeIntentPersisted")
                    self.persistCloseRequestIfReady()
                case .failure(let error):
                    self.recordFirstCaptureFailure(stage: .closeIntent, error: error)
                    self.state = .unavailable
                }
            }
        }
    }

    private func ensureNaturalInputSession() {
        if let naturalInputUseCase {
            guard isFinishing,
                  !didAttemptClosingNaturalInputRecovery else { return }
            if naturalInputUseCase.resumeCurrentSessionReadForClosingIfSafe() {
                didAttemptClosingNaturalInputRecovery = true
                PrivacySafeDiagnostics.log(
                    subsystem: "EchoLiveMemory",
                    event: "closingProgressEvaluated",
                    states: [
                        "phase": "currentSessionReadRecovery",
                        "trigger": "manualFinish",
                        "result": "started",
                    ],
                    counts: [
                        "queueCount": queuedTurns.count,
                        "pendingPersistenceCount": pendingPersistenceCount,
                    ]
                )
                armClosingProgressDeadline(stage: "currentSessionReadRecovery")
            } else if state == .saving {
                PrivacySafeDiagnostics.log(
                    subsystem: "EchoLiveMemory",
                    event: "closingProgressBlocked",
                    states: [
                        "reason": "existingUseCaseNotSafelyResumable",
                        "nextOwner": "closingDeadline",
                    ]
                )
                armClosingProgressDeadline(stage: "existingUseCaseBlocked")
            }
            return
        }
        let useCase = OwnerTruthInterviewNaturalInputUseCase(
            accountLease: accountLease,
            client: client,
            accountLeaseRuntime: accountLeaseRuntime,
            qaGateEnabled: naturalInputPolicyAvailable,
            entryMode: .live,
            allowsEntryModeTransition: true,
            allowStartWhenCurrentMissing: !recoveryAccepted && !isRestoringLegacyClosingOutbox
                && authorizedAuthenticationRetryMessageID == nil,
            productSessionID: productSessionID,
            requestedRecoveryProtocol: preparedStartCommand?.recoveryProtocol
                ?? (recoveryEnabled ? "live-recovery-v1" : nil),
            refreshLiveRequestPolicy: naturalInputPolicyRefresh,
            authorityNow: liveAuthorityNow,
            diagnosticTraceID: "live-natural-input-\(id.uuidString.lowercased())",
            preparedStartCommand: preparedStartCommand,
            preparedStartDispatchState: startDispatchState,
            willPrepareStartCommand: { [weak self, liveTurnOutboxStore, accountLease, productSessionID] command in
                _ = try liveTurnOutboxStore.prepareStart(
                    command,
                    for: accountLease,
                    productSessionID: productSessionID
                )
                self?.preparedStartCommand = command
                self?.startDispatchState = .preparedNotExposed
            },
            willExposeStartCommand: { [weak self, liveTurnOutboxStore, accountLease, productSessionID] command in
                _ = try liveTurnOutboxStore.markStartDispatchState(
                    .mayExpose,
                    command: command,
                    for: accountLease,
                    productSessionID: productSessionID
                )
                self?.preparedStartCommand = command
                self?.startDispatchState = .mayExpose
            },
            willExposeLiveTurnCommand: { [weak self, liveTurnOutboxStore, accountLease, productSessionID] command in
                let isRetry = self?.authorizedAuthenticationRetryMessageID == command.messageID
                if isRetry {
                    _ = try liveTurnOutboxStore.claimAuthenticationRetry(
                        messageID: command.messageID,
                        for: accountLease,
                        productSessionID: productSessionID
                    )
                }
                _ = try liveTurnOutboxStore.prepareAppendExposure(
                    command: command,
                    retry: isRetry,
                    for: accountLease,
                    productSessionID: productSessionID
                )
                guard self?.inFlightTurn?.delivery.messageID == command.messageID else {
                    throw OwnerTruthInterviewLiveTurnOutboxError.storageFailure
                }
                self?.inFlightTurn?.dispatchState = isRetry
                    ? .authenticationRetryExposed
                    : .mayExpose
                self?.inFlightRequestStartedAtUptime = DispatchTime.now().uptimeNanoseconds
                if isRetry {
                    self?.authorizedAuthenticationRetryMessageID = nil
                }
            },
            didClassifyStartCommand: { [weak self, liveTurnOutboxStore, accountLease, productSessionID] command, outcome in
                do {
                    _ = try liveTurnOutboxStore.markStartDispatchState(
                        outcome,
                        command: command,
                        for: accountLease,
                        productSessionID: productSessionID
                    )
                    self?.preparedStartCommand = command
                    self?.startDispatchState = outcome
                } catch {
                    self?.state = .statusUnknown
                }
            },
            willSendEndCommand: { [completionCheckpointStore, accountLease, productSessionID] command in
                try completionCheckpointStore.prepareEnd(
                    command,
                    productSessionID: productSessionID,
                    for: accountLease
                )
            }
        )
        useCase.onPreHandlerAuthenticationRejection = { [weak self] evidence in
            self?.pendingAuthenticationRejectionEvidence = evidence
        }
        useCase.onAppendTransportFailure = { [weak self] error, command, exposure in
            guard let self else { return }
            let statusCode: Int?
            let errorDomain: String
            let errorCode: String
            let reason: String
            if let clientError = error as? DreamJourneyBackendClient.ClientError {
                switch clientError {
                case .backendError(let code, _):
                    statusCode = code
                    errorDomain = "http"
                    errorCode = code.map(String.init) ?? "unknownStatus"
                    reason = "httpFailure"
                case .verifiedPreHandlerAuthenticationRejection:
                    statusCode = 401
                    errorDomain = "authentication"
                    errorCode = "preHandlerRejected"
                    reason = "authenticationRejected"
                default:
                    statusCode = nil
                    errorDomain = "client"
                    errorCode = "requestRejected"
                    reason = "clientRejected"
                }
            } else {
                statusCode = nil
                if let urlErrorCode = DreamJourneyBackendClient.ownerTruthURLFailureCode(error) {
                    errorDomain = "NSURLErrorDomain"
                    errorCode = String(urlErrorCode)
                    reason = urlErrorCode == NSURLErrorTimedOut
                        ? "transportTimeout" : "transportFailure"
                } else {
                    errorDomain = "transport"
                    errorCode = "unclassified"
                    reason = "transportFailure"
                }
            }
            let elapsedMilliseconds = self.inFlightRequestStartedAtUptime.map { started in
                Int((DispatchTime.now().uptimeNanoseconds &- started) / 1_000_000)
            }
            self.criticalDiagnosticsStore.recordFirstRequestFailure(
                accountLease: self.accountLease,
                providerSessionID: self.productSessionID,
                commandID: command.commandID,
                messageID: command.messageID.rawValue.uuidString,
                sequence: command.clientSequenceNumber,
                stage: "appendTransport",
                reason: reason,
                httpStatus: statusCode,
                requestExposure: exposure,
                errorDomain: errorDomain,
                errorCode: errorCode,
                elapsedMilliseconds: elapsedMilliseconds,
                attempt: self.inFlightTurn?.dispatchState == .authenticationRetryExposed ? 2 : 1
            )
        }
        useCase.onViewStateChange = { [weak self, weak useCase] viewState in
            DispatchQueue.main.async {
                guard let self, useCase === self.naturalInputUseCase else { return }
                self.receiveNaturalInputState(viewState)
            }
        }
        naturalInputUseCase = useCase
        useCase.send(.start)
    }

    private func receiveNaturalInputState(_ viewState: OwnerTruthInterviewNaturalInputViewState) {
        switch viewState.phase {
        case .ready:
            if let retryMessageID = authorizedAuthenticationRetryMessageID,
               let retryTurn = inFlightTurn,
               retryTurn.delivery.messageID == retryMessageID {
                let previous = lastBoundNaturalInputReceipt
                let current = viewState.latestReceipt
                let retryBindingAccepted = retryTurn.dispatchState == .authenticationRejected
                    && previous != nil
                    && current != nil
                    && current?.threadID == previous?.threadID
                    && current?.sessionID == previous?.sessionID
                    && current?.threadVersion == previous?.threadVersion
                    && current?.sessionVersion == previous?.sessionVersion
                    && current?.lifecycle == .active
                guard retryBindingAccepted,
                      let current else {
                    PrivacySafeDiagnostics.log(
                        subsystem: "EchoLiveMemory",
                        event: "authenticationRetryRebindRejected",
                        states: [
                            "dispatchStateMatches": String(
                                retryTurn.dispatchState == .authenticationRejected
                            ),
                            "hasPreviousReceipt": String(previous != nil),
                            "hasCurrentReceipt": String(current != nil),
                            "threadMatches": String(current?.threadID == previous?.threadID),
                            "sessionMatches": String(current?.sessionID == previous?.sessionID),
                            "authorityMatches": String(
                                current?.authorityEpoch == previous?.authorityEpoch
                            ),
                            "threadVersionMatches": String(
                                current?.threadVersion == previous?.threadVersion
                            ),
                            "sessionVersionMatches": String(
                                current?.sessionVersion == previous?.sessionVersion
                            ),
                            "lifecycle": current?.lifecycle.rawValue ?? "missing",
                        ],
                        counts: [
                            "previousThreadVersion": previous?.threadVersion ?? -1,
                            "currentThreadVersion": current?.threadVersion ?? -1,
                            "previousSessionVersion": previous?.sessionVersion ?? -1,
                            "currentSessionVersion": current?.sessionVersion ?? -1,
                        ]
                    )
                    authorizedAuthenticationRetryMessageID = nil
                    state = .statusUnknown
                    return
                }
                lastBoundNaturalInputReceipt = current
                state = .syncPaused
                naturalInputUseCase?.send(.submitPersistedLiveTurn(retryTurn.delivery))
                return
            }
            if let receipt = viewState.latestReceipt {
                lastBoundNaturalInputReceipt = receipt
                acceptRecoveryNegotiationIfNeeded(receipt)
            }
            if (state == .unavailable || state == .syncPaused),
               !isRestoringLegacyClosingOutbox,
               !isFinishing {
                state = .live
            }
            if isFinishing, !didBeginOrganization, !recoveryPublicationSettled {
                let blockingIssueCount = unsealedCanonicalTurnCount
                    + canonicalConflictCount
                if blockingIssueCount > 0 {
                    state = .coverageGap(unsealedTurnCount: blockingIssueCount)
                } else {
                    state = .saving
                    armClosingProgressDeadline(stage: "naturalInputReady")
                }
            }
            if let completedTurn = inFlightTurn,
               let receiptMessageID = viewState.latestReceipt?.messageID,
               receiptMessageID == completedTurn.delivery.messageID {
                acknowledgePersistedTurn(completedTurn)
                return
            }
            if !recoveryAccepted, viewState.latestReceipt?.lifecycle == .ended {
                clearCompletedOutboxThenBeginOrganization(receipt: viewState.latestReceipt)
                return
            }
            DispatchQueue.main.async { [weak self] in
                self?.advanceNaturalInputPipeline()
            }
        case .unavailable, .failed:
            // Continuation refresh is advisory once the durable ended receipt
            // has already moved the workflow into acknowledgement/admission.
            guard !didBeginOrganization, !state.isTerminal else { return }
            if let turn = inFlightTurn {
                let elapsedMilliseconds = inFlightRequestStartedAtUptime.map { started in
                    Int((DispatchTime.now().uptimeNanoseconds &- started) / 1_000_000)
                }
                criticalDiagnosticsStore.recordFirstRequestFailure(
                    accountLease: accountLease,
                    providerSessionID: productSessionID,
                    commandID: turn.delivery.commandID,
                    messageID: turn.delivery.messageID.rawValue.uuidString,
                    sequence: turn.delivery.clientSequenceNumber,
                    stage: "append.\(turn.dispatchState.rawValue)",
                    reason: String(describing: viewState.notice),
                    requestExposure: turn.dispatchState.rawValue,
                    errorDomain: "ownerTruth",
                    errorCode: String(describing: viewState.notice),
                    elapsedMilliseconds: elapsedMilliseconds,
                    attempt: turn.dispatchState == .authenticationRetryExposed ? 2 : 1
                )
            }
            if viewState.notice == .authenticationRejectedBeforeApplication,
               let inFlightTurn {
                if inFlightTurn.dispatchState == .authenticationRetryExposed {
                    persistInFlightDispatchState(.serverRejected)
                    state = .syncPaused
                } else if let evidence = pendingAuthenticationRejectionEvidence,
                          evidence.messageID == inFlightTurn.delivery.messageID {
                    pendingAuthenticationRejectionEvidence = nil
                    persistAuthenticationRejection(evidence) { [weak self] in
                        guard let self else { return }
                        self.state = .statusUnknown
                        self.verifyDeliveryStatusIfNeeded()
                    }
                } else {
                    persistInFlightDispatchState(.outcomeUnknown) { [weak self] in
                        guard let self else { return }
                        self.state = .statusUnknown
                        self.verifyDeliveryStatusIfNeeded()
                    }
                }
                return
            }
            if let retryMessageID = authorizedAuthenticationRetryMessageID,
               let turn = inFlightTurn,
               turn.delivery.messageID == retryMessageID,
               turn.dispatchState == .authenticationRejected,
               viewState.notice != .storageFailed {
                // This failure belongs to retry preparation, before the frozen
                // append command can cross the transport boundary.
                authorizedAuthenticationRetryMessageID = nil
                naturalInputUseCase = nil
                state = .statusUnknown
                return
            }
            let transportOutcome: EchoLiveMemoryCompletionTransportOutcome
            switch viewState.notice {
            case .outcomeUnknown:
                transportOutcome = .outcomeUnknown
            case .serverRejected:
                transportOutcome = .serverRejected
            case .requestNotSent:
                transportOutcome = .notSent
            default:
                switch inFlightTurn?.dispatchState {
                case .mayExpose, .authenticationRejected,
                     .authenticationRetryExposed, .outcomeUnknown:
                    transportOutcome = .outcomeUnknown
                case .preparedNotExposed, .serverRejected, .none:
                    transportOutcome = .notSent
                }
            }
            if inFlightTurn != nil {
                let dispatchState: OwnerTruthInterviewLiveTurnDispatchState
                switch transportOutcome {
                case .notSent:
                    if inFlightTurn?.dispatchState == .authenticationRetryExposed {
                        dispatchState = .authenticationRetryExposed
                    } else if inFlightTurn?.dispatchState == .authenticationRejected {
                        dispatchState = .authenticationRejected
                    } else {
                        dispatchState = .preparedNotExposed
                    }
                case .outcomeUnknown: dispatchState = .outcomeUnknown
                case .serverRejected: dispatchState = .serverRejected
                case .committed: dispatchState = .outcomeUnknown
                }
                persistInFlightDispatchState(dispatchState) { [weak self] in
                    self?.scheduleRecoveryPulse(after: 2)
                }
            }
            recordEndTransportOutcome(transportOutcome)
            let hasUnknownExposure = transportOutcome == .outcomeUnknown
                || hasUnknownClosingWriteExposure
            let blockingIssueCount = unsealedCanonicalTurnCount
                + canonicalConflictCount
            if isFinishing, blockingIssueCount > 0 {
                state = .coverageGap(unsealedTurnCount: blockingIssueCount)
            } else if hasUnknownExposure || isRestoringLegacyClosingOutbox {
                state = .statusUnknown
            } else {
                // Network delivery and durable local capture have separate
                // ownership. A read/write transport pause cannot retire the
                // coordinator that still owns this Live transcript.
                state = .syncPaused
            }
            if recoveryAccepted {
                scheduleRecoveryPulse(after: 2)
            } else if hasUnknownExposure || isRestoringLegacyClosingOutbox {
                verifyDeliveryStatusIfNeeded()
            }
        case .idle, .starting, .submitting:
            break
        }
    }

    private func advanceNaturalInputPipeline() {
        if preparedStartCommand?.recoveryProtocol == "live-recovery-v1" && !recoveryAccepted { return }
        guard state.allowsDeliveryPipeline || recoveryAccepted,
              let useCase = naturalInputUseCase,
              useCase.viewState.phase == .ready,
              inFlightTurn == nil,
              !isAcknowledgingInFlightTurn else {
            return
        }
        if let turn = queuedTurns.first {
            switch turn.dispatchState {
            case .preparedNotExposed:
                inFlightTurn = turn
                useCase.send(.submitPersistedLiveTurn(turn.delivery))
            case .authenticationRetryExposed:
                // The one allowed retry may already have crossed the network
                // boundary. Only a command-scoped status read can resolve it.
                state = .statusUnknown
                if recoveryAccepted { scheduleRecoveryPulse(after: 2) }
                else { verifyDeliveryStatusIfNeeded() }
            case .mayExpose, .authenticationRejected, .outcomeUnknown:
                state = .statusUnknown
                if recoveryAccepted { scheduleRecoveryPulse(after: 2) }
                else { verifyDeliveryStatusIfNeeded() }
            case .serverRejected:
                state = .syncPaused
            }
            return
        }
        if recoveryAccepted {
            if isFinishing, !recoveryPublicationSettled, recoveryTimer == nil { scheduleRecoveryPulse(after: 0) }
            return // Recovery close never fabricates a legacy end/ACK/admit.
        }
        guard isFinishing,
              closeRequestPersisted,
              unsealedCanonicalTurnCount == 0,
              canonicalConflictCount == 0,
              !hasCanonicalPersistenceOverflow,
              persistedOwnerTurnCount > 0,
              !didRequestEnd,
              lastClientSequenceNumber > 0 else {
            return
        }
        didRequestEnd = true
        useCase.send(.endLive(lastClientSequenceNumber: lastClientSequenceNumber))
    }

    private func acceptRecoveryNegotiationIfNeeded(_ receipt: OwnerTruthInterviewNaturalInputReceipt) {
        guard !recoveryAccepted, !recoveryNegotiationInFlight,
              let progress = receipt.recoveryProgress,
              preparedStartCommand?.recoveryProtocol == "live-recovery-v1" else { return }
        recoveryNegotiationInFlight = true
        let store = liveTurnOutboxStore, lease = accountLease, session = productSessionID
        persistenceQueue.async { [weak self] in
            let result = Result {
                try store.acceptRecoveryProtocol(progress.protocol, sessionID: receipt.sessionID,
                    for: lease, productSessionID: session)
                try store.saveRecoveryProgress(progress, for: lease, productSessionID: session)
            }
            DispatchQueue.main.async {
                guard let self else { return }
                self.recoveryNegotiationInFlight = false
                guard case .success = result else { self.state = .unavailable; return }
                self.recoveryAccepted = true
                self.recoveryProgress = progress
                self.closingProgressTimeoutWorkItem?.cancel()
                self.scheduleRecoveryPulse(after: 0)
                self.advanceNaturalInputPipeline()
            }
        }
    }

    private var recoveryPublicationSettled: Bool {
        guard isFinishing, queuedTurns.isEmpty, inFlightTurn == nil,
              let publication = recoveryProgress?.publication else { return false }
        return ["published", "noChange", "failed"].contains(publication.state)
    }

    private func scheduleRecoveryPulse(after delay: TimeInterval) {
        guard recoveryAccepted, recoveryOperationID == nil, !recoveryPublicationSettled else { return }
        recoveryTimer?.cancel()
        recoveryTimer = deliveryObservationSchedule(delay) { [weak self] in
            self?.recoveryTimer = nil
            self?.runRecoveryPulse()
        }
    }

    private func runRecoveryPulse() {
        guard recoveryAccepted, recoveryOperationID == nil, !recoveryPublicationSettled,
              let client = client as? OwnerTruthLiveRecoveryClient,
              let sessionID = preparedStartCommand?.sessionID,
              let vaultID = OwnerTruthVaultID(accountLease.vaultId),
              accountLeaseRuntime.validate(accountLease, at: .request).allowed else { return }
        if isFinishing {
            if recoveryObservedAt == nil { recoveryObservedAt = liveAuthorityNow() }
            if liveAuthorityNow().timeIntervalSince(recoveryObservedAt!) >= organizationStatusTimeout {
                state = .statusUnknown; return // Durable server work continues; foreground may read again.
            }
        }
        let operation = UUID(); recoveryOperationID = operation
        recoveryTimeout = deliveryObservationSchedule(15) { [weak self] in
            guard let self, self.recoveryOperationID == operation else { return }
            self.recoveryOperationID = nil
            self.recoveryTimeout = nil
            self.scheduleRecoveryPulse(after: self.isFinishing ? 5 : 20)
        }
        client.prepareOwnerTruthInterviewNaturalInputAuthentication(accountLease: accountLease,
            now: liveAuthorityNow, minimumValidity: 30) { [weak self] ready in
            DispatchQueue.main.async {
                guard let self, self.recoveryOperationID == operation else { return }
                guard ready else { self.finishRecoveryOperation(operation, delay: 5); return }
                self.withRecoveryAuthority(operation: operation) { [weak self] authority in
                    guard let self, self.recoveryOperationID == operation else { return }
                    if !self.recoveryPublicationAuthorized {
                        let authorize = { [weak self] in
                            guard let self, self.recoveryOperationID == operation else { return }
                            client.authorizeOwnerTruthLiveRecoveryPublication(accountLease: self.accountLease,
                                vaultID: vaultID, sessionID: sessionID, generation: 1) { [weak self] result in
                                DispatchQueue.main.async {
                                    guard let self, self.recoveryOperationID == operation else { return }
                                    if case .success = result { self.recoveryPublicationAuthorized = true }
                                    self.sendRecoveryControl(client: client, authority: authority,
                                        vaultID: vaultID, sessionID: sessionID, operation: operation)
                                }
                            }
                        }
                        if self.candidateReviewPolicyAvailable() { authorize() }
                        else { self.candidateReviewPolicyRefresh { ready in
                            DispatchQueue.main.async {
                                if ready { authorize() }
                                else { self.sendRecoveryControl(client: client, authority: authority,
                                    vaultID: vaultID, sessionID: sessionID, operation: operation) }
                            }
                        } }
                    } else {
                        self.sendRecoveryControl(client: client, authority: authority,
                            vaultID: vaultID, sessionID: sessionID, operation: operation)
                    }
                }
            }
        }
    }

    private func withRecoveryAuthority(operation: UUID,
        completion: @escaping (OwnerTruthInterviewNaturalInputRequestAuthority) -> Void) {
        func authority() -> OwnerTruthInterviewNaturalInputRequestAuthority? {
            guard accountLeaseRuntime.validate(accountLease, at: .request).allowed,
                  let decision = client.freshOwnerTruthInterviewNaturalInputDecision() else { return nil }
            return OwnerTruthInterviewNaturalInputRequestAuthority(featureDecision: decision,
                accountLease: accountLease, operationGeneration: 1,
                diagnosticTraceID: "live-recovery-\(id.uuidString.lowercased())", now: liveAuthorityNow())
        }
        if let value = authority() { completion(value); return }
        naturalInputPolicyRefresh { [weak self] refreshed in
            DispatchQueue.main.async {
                guard let self, self.recoveryOperationID == operation else { return }
                guard refreshed, let value = authority() else {
                    self.finishRecoveryOperation(operation, delay: 20); return
                }
                completion(value)
            }
        }
    }

    private func sendRecoveryControl(client: OwnerTruthLiveRecoveryClient,
        authority: OwnerTruthInterviewNaturalInputRequestAuthority, vaultID: OwnerTruthVaultID,
        sessionID: OwnerTruthRecordID, operation: UUID) {
        let final = closeRequestPersisted ? lastClientSequenceNumber : nil
        let needsClose = (closeIntentPersisted || recoveryGracefulStopPersisted) && (recoveryProgress?.state == .collecting
            || recoveryProgress?.state == .disconnected
            || (final != nil && recoveryProgress?.finalSequence == nil))
        let action = needsClose ? "close" : (isFinishing ? "status" : "heartbeat")
        client.controlOwnerTruthLiveRecovery(authority: authority, vaultID: vaultID,
            sessionID: sessionID, generation: 1, action: action, finalSequence: needsClose ? final : nil,
            rangeOffset: 0, expectedVersion: nil) { [weak self] result in
            DispatchQueue.main.async {
                guard let self, self.recoveryOperationID == operation,
                      self.accountLeaseRuntime.validate(self.accountLease, at: .commit).allowed else { return }
                switch result {
                case .failure: self.finishRecoveryOperation(operation, delay: self.isFinishing ? 5 : 20)
                case .success(let progress):
                    let store = self.liveTurnOutboxStore, lease = self.accountLease, session = self.productSessionID
                    self.persistenceQueue.async { [weak self] in
                        let persisted = Result { try store.saveRecoveryProgress(progress, for: lease, productSessionID: session) }
                        DispatchQueue.main.async {
                            guard let self, self.recoveryOperationID == operation else { return }
                            guard case .success = persisted else {
                                self.state = .statusUnknown; self.finishRecoveryOperation(operation, delay: 5); return
                            }
                            self.recoveryProgress = progress
                            if self.inFlightTurn == nil, !self.isAcknowledgingInFlightTurn {
                                _ = self.naturalInputUseCase?.bindRecoverySession(progress)
                            }
                            if self.isFinishing, let publication = progress.publication {
                                switch publication.state {
                                case "published": self.state = .pendingReview
                                case "noChange": self.state = .empty
                                case "failed": self.state = .terminalFailure(code: "recoverySnapshotFailed")
                                default: self.state = .organizing
                                }
                            }
                            self.replayRecoveryHeadIfNeeded(client: client, authority: authority,
                                vaultID: vaultID, operation: operation)
                        }
                    }
                }
            }
        }
    }

    private func replayRecoveryHeadIfNeeded(client: OwnerTruthLiveRecoveryClient,
        authority: OwnerTruthInterviewNaturalInputRequestAuthority, vaultID: OwnerTruthVaultID, operation: UUID) {
        // The append callback may still be in flight. Only a classified unknown
        // write or a cold-restored exposure is eligible for the durable claim.
        guard let head = queuedTurns.first,
              [.outcomeUnknown, .mayExpose, .authenticationRetryExposed].contains(head.dispatchState),
              naturalInputUseCase?.viewState.phase != .submitting,
              !isAcknowledgingInFlightTurn else {
            finishRecoveryOperation(operation, delay: isFinishing ? 5 : 20)
            advanceNaturalInputPipeline(); return
        }
        let store = liveTurnOutboxStore, lease = accountLease, session = productSessionID
        persistenceQueue.async { [weak self] in
            let result = Result {
                _ = try store.markDispatchState(.outcomeUnknown, messageID: head.delivery.messageID,
                    for: lease, productSessionID: session)
                return try store.claimRecoveryReplay(messageID: head.delivery.messageID,
                    for: lease, productSessionID: session)
            }
            DispatchQueue.main.async {
                guard let self, self.recoveryOperationID == operation else { return }
                guard case .success(let command) = result else {
                    self.finishRecoveryOperation(operation, delay: 20); return
                }
                self.inFlightTurn = head
                client.replayOwnerTruthLiveRecoveryWrite(authority: authority, vaultID: vaultID,
                    command: command, generation: 1) { [weak self] outcome in
                    DispatchQueue.main.async {
                        guard let self, self.recoveryOperationID == operation,
                              self.accountLeaseRuntime.validate(self.accountLease, at: .commit).allowed else { return }
                        switch outcome {
                        case .committed(let receipt):
                            if self.naturalInputUseCase?.bindRecoveryAppend(receipt, command: command) != true {
                                self.state = .statusUnknown
                            }
                        case .serverRejected(let error):
                            if case DreamJourneyBackendClient.ClientError.backendError(let code, let context) = error,
                               code == 429 || code == 503 {
                                let until = self.liveAuthorityNow().addingTimeInterval(TimeInterval(max(5, context.retryAfterSeconds ?? 5)))
                                self.persistenceQueue.async {
                                    try? store.deferRecoveryReplay(until: until, for: lease, productSessionID: session)
                                }
                                self.persistInFlightDispatchState(.outcomeUnknown); self.state = .statusUnknown
                            } else {
                                self.persistInFlightDispatchState(.serverRejected); self.state = .syncPaused
                            }
                        case .notSent(let error), .outcomeUnknown(let error):
                            if case DreamJourneyBackendClient.ClientError.backendError(let code, let context) = error,
                               code == 429 || code == 503 {
                                let until = self.liveAuthorityNow().addingTimeInterval(TimeInterval(max(5, context.retryAfterSeconds ?? 5)))
                                self.persistenceQueue.async {
                                    try? store.deferRecoveryReplay(until: until, for: lease, productSessionID: session)
                                }
                            }
                            self.persistInFlightDispatchState(.outcomeUnknown)
                            self.state = .statusUnknown
                        }
                        self.finishRecoveryOperation(operation, delay: 5)
                    }
                }
            }
        }
    }

    private func finishRecoveryOperation(_ operation: UUID, delay: TimeInterval) {
        guard recoveryOperationID == operation else { return }
        recoveryOperationID = nil; recoveryTimeout?.cancel(); recoveryTimeout = nil
        // Unknown writes retain their disk record even after a partial publication.
        if recoveryPublicationSettled {
            recoveryTimer?.cancel(); recoveryTimer = nil
            onCaptureOwnershipReleaseEligibilityChange?(); return
        }
        if !isFinishing, !recoveryDidRequestBackpressureStop {
            let age = queuedTurns.first.map { liveAuthorityNow().timeIntervalSince($0.delivery.capturedAt) }
            if recoveryBackpressureMonitor.observe(now: liveAuthorityNow(),
                acknowledged: recoveryProgress?.continuousSequence ?? 0,
                oldestClientAge: age, backlog: recoveryProgress?.backlog) {
                recoveryDidRequestBackpressureStop = true; onRecoveryBackpressureStop?()
            }
        }
        scheduleRecoveryPulse(after: delay)
    }

    private func persistInFlightDispatchState(
        _ dispatchState: OwnerTruthInterviewLiveTurnDispatchState,
        completion: (() -> Void)? = nil
    ) {
        guard let turn = inFlightTurn else {
            completion?()
            return
        }
        let accountLease = accountLease
        let productSessionID = productSessionID
        let store = liveTurnOutboxStore
        persistenceQueue.async { [weak self] in
            let result = Result {
                try store.markDispatchState(
                    dispatchState,
                    messageID: turn.delivery.messageID,
                    for: accountLease,
                    productSessionID: productSessionID
                )
            }
            DispatchQueue.main.async {
                guard let self,
                      self.inFlightTurn?.delivery.messageID == turn.delivery.messageID else {
                    return
                }
                if case .success = result {
                    self.inFlightTurn?.dispatchState = dispatchState
                } else {
                    self.state = .unavailable
                }
                completion?()
            }
        }
    }

    private func acknowledgePersistedTurn(_ completedTurn: Turn) {
        guard !isAcknowledgingInFlightTurn else { return }
        isAcknowledgingInFlightTurn = true
        let accountLease = accountLease
        let productSessionID = productSessionID
        let store = liveTurnOutboxStore
        persistenceQueue.async { [weak self] in
            let result = Result {
                try store.acknowledge(
                    messageID: completedTurn.delivery.messageID,
                    for: accountLease,
                    productSessionID: productSessionID
                )
            }
            DispatchQueue.main.async {
                guard let self else { return }
                self.isAcknowledgingInFlightTurn = false
                switch result {
                case .success(let snapshot):
                    if let snapshot {
                        self.applyCanonicalCoverage(snapshot, stage: "writeConfirmation")
                    }
                    if self.queuedTurns.first?.delivery.messageID
                        == completedTurn.delivery.messageID {
                        self.queuedTurns.removeFirst()
                    } else {
                        self.queuedTurns.removeAll {
                            $0.delivery.messageID == completedTurn.delivery.messageID
                        }
                    }
                    if completedTurn.role == .owner {
                        self.persistedOwnerTurnCount += 1
                    }
                    self.inFlightTurn = nil
                    self.armClosingProgressDeadline(stage: "turnAcknowledged")
                    self.advanceNaturalInputPipeline()
                case .failure(let error):
                    // Keep the in-flight item in the durable journal. A later
                    // resume will replay the same command instead of guessing
                    // whether the server accepted it.
                    let reason: String
                    switch error {
                    case OwnerTruthInterviewLiveTurnOutboxError.invalidPersistenceEnvelope:
                        reason = "invalidPersistenceEnvelope"
                    case OwnerTruthInterviewLiveTurnOutboxError.storageFailure:
                        reason = "storageFailure"
                    default:
                        reason = "unknown"
                    }
                    PrivacySafeDiagnostics.log(
                        subsystem: "EchoLiveMemory",
                        event: "turnAcknowledgementFailed",
                        states: ["reason": reason]
                    )
                    self.state = .unavailable
                }
            }
        }
    }

    private func finishDeliveryObservationRound() {
        deliveryObservationRetryWorkItem?.cancel()
        deliveryObservationRetryWorkItem = nil
        deliveryObservationRound = nil
    }

    private func scheduleDeliveryObservationRetry(error: Error? = nil) {
        guard let round = deliveryObservationRound,
              deliveryObservationRetryWorkItem == nil else { return }
        let elapsed = deliveryObservationNow() - round.startedAt
        guard round.requestCount < 12, elapsed < 180,
              accountLeaseRuntime.validate(accountLease, at: .request).allowed else {
            finishDeliveryObservationRound()
            state = .statusUnknown
            return
        }
        let delays: [TimeInterval] = [1, 2, 4, 8, 16, 30]
        let backoff = delays[min(max(0, round.requestCount - 1), delays.count - 1)]
        let retryAfter: TimeInterval = {
            guard let error = error as? DreamJourneyBackendClient.ClientError,
                  case .backendError(statusCode: 429, let context) = error,
                  let seconds = context.retryAfterSeconds,
                  seconds >= 0 else { return 0 }
            return TimeInterval(seconds)
        }()
        let delay = max(backoff, retryAfter)
        guard delay <= 180 - elapsed else {
            finishDeliveryObservationRound()
            state = .statusUnknown
            return
        }
        let roundID = round.id
        let expectedGeneration = deliveryStatusReadGeneration
        let expectedSession = productSessionID
        deliveryObservationRetryWorkItem = deliveryObservationSchedule(delay) { [weak self] in
            guard let self,
                  self.deliveryObservationRound?.id == roundID,
                  self.deliveryStatusReadGeneration == expectedGeneration,
                  self.productSessionID == expectedSession else { return }
            self.deliveryObservationRetryWorkItem = nil
            self.verifyDeliveryStatusIfNeeded()
        }
    }

    private func verifyDeliveryStatusIfNeeded() {
        guard !isDeliveryStatusReadInFlight,
              deliveryObservationRetryWorkItem == nil,
              !didBeginOrganization,
              let vaultID = OwnerTruthVaultID(accountLease.vaultId),
              accountLeaseRuntime.validate(accountLease, at: .request).allowed,
              inFlightTurn != nil || !queuedTurns.isEmpty || didRequestEnd
                || startDispatchState == .mayExpose
                || startDispatchState == .outcomeUnknown else {
            return
        }
        let receipt = lastBoundNaturalInputReceipt
        guard let sessionID = receipt?.sessionID ?? preparedStartCommand?.sessionID else { return }
        if deliveryObservationRound == nil {
            deliveryObservationRound = DeliveryObservationRound(
                id: UUID(), startedAt: deliveryObservationNow(), requestCount: 0
            )
        }
        guard let activeRound = deliveryObservationRound,
              activeRound.requestCount < 12,
              deliveryObservationNow() - activeRound.startedAt < 180 else {
            finishDeliveryObservationRound()
            state = .statusUnknown
            return
        }
        guard naturalInputPolicyAvailable() else {
            guard !isDeliveryStatusPolicyRefreshInFlight else { return }
            isDeliveryStatusPolicyRefreshInFlight = true
            deliveryStatusPolicyRefreshGeneration &+= 1
            let refreshGeneration = deliveryStatusPolicyRefreshGeneration
            naturalInputPolicyRefresh { [weak self] refreshed in
                DispatchQueue.main.async {
                    guard let self,
                          refreshGeneration == self.deliveryStatusPolicyRefreshGeneration else {
                        return
                    }
                    self.isDeliveryStatusPolicyRefreshInFlight = false
                    guard refreshed,
                          self.naturalInputPolicyAvailable(),
                          self.accountLeaseRuntime.validate(
                            self.accountLease,
                            at: .request
                          ).allowed else {
                        self.finishDeliveryObservationRound()
                        self.state = .statusUnknown
                        return
                    }
                    self.verifyDeliveryStatusIfNeeded()
                }
            }
            return
        }
        var round = activeRound
        round.requestCount += 1
        deliveryObservationRound = round
        let roundID = round.id
        let remainingObservationTime = max(0, 180 - (deliveryObservationNow() - round.startedAt))
        guard remainingObservationTime > 0 else {
            finishDeliveryObservationRound()
            state = .statusUnknown
            return
        }
        let readTimeout = min(deliveryStatusTimeout, remainingObservationTime)
        isDeliveryStatusReadInFlight = true
        deliveryStatusReadGeneration &+= 1
        let generation = deliveryStatusReadGeneration
        deliveryStatusTimeoutWorkItem?.cancel()
        let timeoutWorkItem = DispatchWorkItem { [weak self] in
            guard let self,
                  generation == self.deliveryStatusReadGeneration,
                  self.isDeliveryStatusReadInFlight else { return }
            self.isDeliveryStatusReadInFlight = false
            self.deliveryStatusReadGeneration &+= 1
            self.deliveryStatusTimeoutWorkItem = nil
            self.state = .statusUnknown
            if readTimeout >= remainingObservationTime {
                self.finishDeliveryObservationRound()
            } else {
                self.scheduleDeliveryObservationRetry()
            }
        }
        deliveryStatusTimeoutWorkItem = timeoutWorkItem
        DispatchQueue.main.asyncAfter(
            deadline: .now() + readTimeout,
            execute: timeoutWorkItem
        )
        let fromSequence = max(
            1,
            inFlightTurn?.delivery.clientSequenceNumber
                ?? queuedTurns.first?.delivery.clientSequenceNumber
                ?? 1
        )
        let statusReadStartedAt = deliveryObservationNow()
        client.fetchOwnerTruthLiveDeliveryStatus(
            accountLease: accountLease,
            vaultID: vaultID,
            sessionID: sessionID,
            productSessionID: productSessionID,
            fromClientSequence: fromSequence
        ) { [weak self] result in
            DispatchQueue.main.async {
                guard let self,
                      generation == self.deliveryStatusReadGeneration,
                      self.deliveryObservationRound?.id == roundID else { return }
                self.deliveryStatusTimeoutWorkItem?.cancel()
                self.deliveryStatusTimeoutWorkItem = nil
                self.isDeliveryStatusReadInFlight = false
                guard self.deliveryObservationNow() - round.startedAt < 180 else {
                    self.finishDeliveryObservationRound()
                    self.state = .statusUnknown
                    return
                }
                guard self.accountLeaseRuntime.validate(self.accountLease, at: .commit).allowed else {
                    self.finishDeliveryObservationRound()
                    self.state = .statusUnknown
                    return
                }
                switch result {
                case .success(let status):
                    let outcome = self.receiveDeliveryStatus(status, boundReceipt: receipt)
                    switch outcome {
                    case .verifiedCommit:
                        self.finishDeliveryObservationRound()
                    case .pendingPersistence:
                        break
                    case .unverified:
                        if case .statusUnknown = self.state,
                           self.inFlightTurn?.dispatchState != .authenticationRejected {
                            self.scheduleDeliveryObservationRetry()
                        } else {
                            self.finishDeliveryObservationRound()
                        }
                    }
                case .failure(let error):
                    let statusCode: Int?
                    if let clientError = error as? DreamJourneyBackendClient.ClientError,
                       case .backendError(let code, _) = clientError {
                        statusCode = code
                    } else {
                        statusCode = nil
                    }
                    self.criticalDiagnosticsStore.recordFirstRequestFailure(
                        accountLease: self.accountLease,
                        providerSessionID: self.productSessionID,
                        commandID: self.inFlightTurn?.delivery.commandID
                            ?? self.preparedStartCommand?.commandID,
                        messageID: self.inFlightTurn?.delivery.messageID.rawValue.uuidString,
                        sequence: fromSequence,
                        stage: "deliveryStatusRead",
                        reason: statusCode == nil ? "transportFailure" : "httpFailure",
                        httpStatus: statusCode,
                        requestExposure: "readOnly",
                        errorDomain: statusCode == nil ? "transport" : "http",
                        errorCode: statusCode == nil ? "unavailable" : "backendError",
                        elapsedMilliseconds: Int(max(0, self.deliveryObservationNow() - statusReadStartedAt) * 1_000),
                        attempt: round.requestCount
                    )
                    self.state = .statusUnknown
                    self.scheduleDeliveryObservationRetry(error: error)
                }
            }
        }
    }

    private enum DeliveryStatusProcessingOutcome {
        case verifiedCommit
        case pendingPersistence
        case unverified
    }

    private func receiveDeliveryStatus(
        _ status: OwnerTruthLiveDeliveryStatus,
        boundReceipt: OwnerTruthInterviewNaturalInputReceipt?
    ) -> DeliveryStatusProcessingOutcome {
        if let boundReceipt {
            let sameSession = status.sessionID == boundReceipt.sessionID
            let sameThread = status.threadID == boundReceipt.threadID
            let threadVersionMonotonic = status.threadVersion >= boundReceipt.threadVersion
            let sessionVersionMonotonic = status.sessionVersion >= boundReceipt.sessionVersion
            let authorityMonotonic = boundReceipt.authorityEpoch.map {
                status.authorityEpoch >= $0
            } ?? false
            guard sameSession,
                  sameThread,
                  threadVersionMonotonic,
                  sessionVersionMonotonic,
                  authorityMonotonic else {
                PrivacySafeDiagnostics.log(
                    subsystem: "EchoLiveMemory",
                    event: "deliveryStatusBindingRejected",
                    states: [
                        "sameSession": sameSession ? "true" : "false",
                        "sameThread": sameThread ? "true" : "false",
                        "threadVersionMonotonic": threadVersionMonotonic ? "true" : "false",
                        "sessionVersionMonotonic": sessionVersionMonotonic ? "true" : "false",
                        "authorityMonotonic": authorityMonotonic ? "true" : "false",
                    ]
                )
                state = .statusUnknown
                return .unverified
            }
        } else {
            guard let command = preparedStartCommand,
                  let verifiedReceipt = status.confirmedStartedReceipt(for: command) else {
                state = .statusUnknown
                return .unverified
            }
            do {
                _ = try liveTurnOutboxStore.markStartDispatchState(
                    .committed,
                    command: command,
                    for: accountLease,
                    productSessionID: productSessionID
                )
            } catch {
                state = .statusUnknown
                return .unverified
            }
            startDispatchState = .committed
            lastBoundNaturalInputReceipt = verifiedReceipt
            state = isFinishing ? .saving : .live
            naturalInputUseCase?.bindReadOnlyVerifiedStart(verifiedReceipt)
            return .verifiedCommit
        }
        let localTurns = ([inFlightTurn].compactMap { $0 } + queuedTurns).reduce(
            into: [OwnerTruthRecordID: Turn]()
        ) { partial, turn in
            partial[turn.delivery.messageID] = turn
        }
        let confirmed = localTurns.values.filter { status.delivery(matching: $0.delivery) != nil }
            .sorted { $0.delivery.clientSequenceNumber < $1.delivery.clientSequenceNumber }
        guard !confirmed.isEmpty else {
            if let local = localTurns.values.sorted(by: {
                $0.delivery.clientSequenceNumber < $1.delivery.clientSequenceNumber
            }).first,
               let remote = status.deliveries.first(where: {
                   $0.clientSequenceNumber == local.delivery.clientSequenceNumber
               }) {
                PrivacySafeDiagnostics.log(
                    subsystem: "EchoLiveMemory",
                    event: "deliveryStatusItemBindingRejected",
                    states: [
                        "sameMessage": remote.messageID == local.delivery.messageID
                            ? "true" : "false",
                        "sameCommand": remote.commandIDHash == local.delivery.commandIDHash
                            ? "true" : "false",
                        "sameRole": remote.role == local.delivery.role ? "true" : "false",
                        "sameCapturedAt": ISO8601DateFormatter().string(from: remote.capturedAt)
                            == ISO8601DateFormatter().string(from: local.delivery.capturedAt)
                            ? "true" : "false",
                        "sameContent": (try? local.delivery.serverContentHash())
                            == remote.contentHash ? "true" : "false",
                    ]
                )
            }
            if didRequestEnd,
               let checkpoint = try? completionCheckpointStore.load(
                    productSessionID: productSessionID,
                    for: accountLease
               ),
               let command = checkpoint.endCommand,
               let endedReceipt = status.confirmedEndedReceipt(for: command) {
                clearCompletedOutboxThenBeginOrganization(receipt: endedReceipt)
                return acceptedEndedReceiptIdentity == endedReceiptIdentity(endedReceipt)
                    ? .verifiedCommit : .unverified
            } else if let retryTurn = inFlightTurn ?? queuedTurns.first,
                      retryTurn.dispatchState == .authenticationRejected,
                      status.fromClientSequence <= retryTurn.delivery.clientSequenceNumber,
                      retryTurn.delivery.clientSequenceNumber
                        < status.fromClientSequence + status.limit,
                      status.missingClientSequences.contains(
                        retryTurn.delivery.clientSequenceNumber
                      ) || retryTurn.delivery.clientSequenceNumber
                        > status.continuousClientSequence {
                prepareVerifiedAuthenticationRetry(retryTurn)
            } else {
                state = .statusUnknown
            }
            return .unverified
        }
        acknowledgeReadOnlyConfirmedTurns(confirmed, status: status)
        return .pendingPersistence
    }

    private func prepareVerifiedAuthenticationRetry(_ turn: Turn) {
        guard authorizedAuthenticationRetryMessageID == nil,
              turn.dispatchState == .authenticationRejected,
              inFlightTurn?.delivery.messageID == turn.delivery.messageID,
              lastBoundNaturalInputReceipt != nil else {
            state = .statusUnknown
            return
        }
        let messageID = turn.delivery.messageID
        let accountLease = accountLease
        let productSessionID = productSessionID
        let store = liveTurnOutboxStore
        persistenceQueue.async { [weak self] in
            let result = Result {
                guard let snapshot = try store.load(
                    for: accountLease,
                    productSessionID: productSessionID
                ), snapshot.pendingDispatchStates[messageID] == .authenticationRejected,
                   !snapshot.authenticationRetryClaimedMessageIDs.contains(messageID),
                   let command = snapshot.frozenAppendCommands[messageID],
                   let evidence = snapshot.authenticationRejectionEvidence[messageID],
                   evidence.matches(command) else {
                    throw OwnerTruthInterviewLiveTurnOutboxError.invalidPersistenceEnvelope
                }
                return snapshot
            }
            DispatchQueue.main.async {
                guard let self,
                      self.inFlightTurn?.delivery.messageID == messageID else { return }
                guard case .success = result else {
                    self.state = .statusUnknown
                    return
                }
                self.inFlightTurn = turn
                self.authorizedAuthenticationRetryMessageID = messageID
                self.naturalInputUseCase = nil
                self.state = .syncPaused
                self.ensureNaturalInputSession()
            }
        }
    }

    private func persistAuthenticationRejection(
        _ evidence: OwnerTruthInterviewPreHandlerAuthenticationRejectionEvidence,
        completion: (() -> Void)? = nil
    ) {
        guard let turn = inFlightTurn,
              turn.delivery.messageID == evidence.messageID else {
            state = .statusUnknown
            return
        }
        let accountLease = accountLease
        let productSessionID = productSessionID
        let store = liveTurnOutboxStore
        persistenceQueue.async { [weak self] in
            let result = Result {
                try store.recordAuthenticationRejection(
                    evidence,
                    messageID: evidence.messageID,
                    for: accountLease,
                    productSessionID: productSessionID
                )
            }
            DispatchQueue.main.async {
                guard let self,
                      self.inFlightTurn?.delivery.messageID == evidence.messageID else { return }
                switch result {
                case .success:
                    self.inFlightTurn?.dispatchState = .authenticationRejected
                    completion?()
                case .failure:
                    self.state = .statusUnknown
                }
            }
        }
    }

    private func acknowledgeReadOnlyConfirmedTurns(
        _ confirmed: [Turn],
        status: OwnerTruthLiveDeliveryStatus
    ) {
        let accountLease = accountLease
        let productSessionID = productSessionID
        let store = liveTurnOutboxStore
        let observationRoundID = deliveryObservationRound?.id
        persistenceQueue.async { [weak self] in
            let result = Result { () -> OwnerTruthInterviewLiveTurnOutboxSnapshot? in
                var snapshot: OwnerTruthInterviewLiveTurnOutboxSnapshot?
                for turn in confirmed {
                    snapshot = try store.acknowledge(
                        messageID: turn.delivery.messageID,
                        for: accountLease,
                        productSessionID: productSessionID
                    )
                }
                return snapshot
            }
            DispatchQueue.main.async {
                guard let self else { return }
                switch result {
                case .success(let snapshot):
                    if self.deliveryObservationRound?.id == observationRoundID {
                        self.finishDeliveryObservationRound()
                    }
                    let confirmedIDs = Set(confirmed.map { $0.delivery.messageID })
                    self.queuedTurns.removeAll { confirmedIDs.contains($0.delivery.messageID) }
                    if let inFlight = self.inFlightTurn,
                       confirmedIDs.contains(inFlight.delivery.messageID) {
                        self.inFlightTurn = nil
                    }
                    self.persistedOwnerTurnCount += confirmed.filter { $0.role == .owner }.count
                    if let snapshot {
                        self.ownerTurnCount = snapshot.ownerTurnCount
                        self.lastClientSequenceNumber = snapshot.lastClientSequenceNumber
                        self.applyCanonicalCoverage(snapshot, stage: "readOnlyConfirmation")
                    }
                    if status.lifecycle == .ended {
                        self.verifyDeliveryStatusIfNeeded()
                    } else if self.inFlightTurn != nil || !self.queuedTurns.isEmpty {
                        let remainingTurns = ([self.inFlightTurn].compactMap { $0 }
                            + self.queuedTurns)
                        guard remainingTurns.allSatisfy({
                            $0.dispatchState == .preparedNotExposed
                        }) else {
                            // A read-only observation can clear only the exact
                            // deliveries it proved committed. Any remaining
                            // exposed command stays read-only until observed.
                            self.state = .statusUnknown
                            return
                        }
                        // Prepared-only tail commands have never crossed the
                        // write boundary. Rebind the exact current session
                        // before allowing the normal FIFO sender to continue.
                        self.naturalInputUseCase = nil
                        self.state = .syncPaused
                        self.ensureNaturalInputSession()
                    } else {
                        self.naturalInputUseCase = nil
                        self.state = .unavailable
                        self.ensureNaturalInputSession()
                    }
                case .failure:
                    self.state = .statusUnknown
                    if self.deliveryObservationRound?.id == observationRoundID {
                        self.scheduleDeliveryObservationRetry()
                    }
                }
            }
        }
    }

    private func clearCompletedOutboxThenBeginOrganization(
        receipt: OwnerTruthInterviewNaturalInputReceipt?
    ) {
        guard let receipt, receipt.lifecycle == .ended else { return }
        let identity = endedReceiptIdentity(receipt)
        guard acceptedEndedReceiptIdentity == nil else {
            PrivacySafeDiagnostics.log(
                subsystem: "EchoLiveMemory",
                event: "endedReceiptDuplicateIgnored",
                states: ["stage": "organizationAlreadyOwned"],
                counts: ["duplicateIgnored": 1]
            )
            return
        }
        guard !state.isTerminal else { return }
        logCompletion(event: "endReceiptBindingAccepted")
        do {
            try completionCheckpointStore.acceptEnd(
                receipt,
                productSessionID: productSessionID,
                for: accountLease
            )
        } catch {
            logCompletion(event: "endCheckpointCommitFailed", reason: "storageFailed")
            recordCompletionRequestFailure(
                stage: "endCheckpointCommit", reason: "storageFailed",
                commandID: (try? completionCheckpointStore.load(
                    productSessionID: productSessionID, for: accountLease
                ))?.endCommand?.commandID,
                exposure: "responseAccepted"
            )
            state = .statusUnknown
            return
        }
        logCompletion(event: "endCheckpointCommitted")
        acceptedEndedReceiptIdentity = identity
        state = .saving
        armClosingProgressDeadline(stage: "endedReceiptCommitted")
        // Keep the closing outbox until the server reaches a durable success
        // state. If the page or app closes during acknowledgement, admission,
        // extraction or retry wait, restoring this journal resumes the same
        // idempotent session instead of losing its progress coordinates.
        beginPendingMemoryOrganization(receipt: receipt)
    }

    private var hasUnknownClosingWriteExposure: Bool {
        if didRequestEnd { return true }
        if startDispatchState == .mayExpose || startDispatchState == .outcomeUnknown {
            return true
        }
        if let inFlightTurn,
           inFlightTurn.dispatchState == .mayExpose
            || inFlightTurn.dispatchState == .authenticationRetryExposed
            || inFlightTurn.dispatchState == .outcomeUnknown {
            return true
        }
        return queuedTurns.contains {
            $0.dispatchState == .mayExpose
                || $0.dispatchState == .authenticationRetryExposed
                || $0.dispatchState == .outcomeUnknown
        }
    }

    private func armClosingProgressDeadline(stage: String) {
        if recoveryAccepted { return }
        guard isFinishing,
              state == .saving,
              !didBeginOrganization else { return }
        closingProgressTimeoutWorkItem?.cancel()
        closingProgressGeneration &+= 1
        let generation = closingProgressGeneration
        let workItem = DispatchWorkItem { [weak self] in
            guard let self,
                  generation == self.closingProgressGeneration,
                  self.state == .saving,
                  self.isFinishing,
                  !self.didBeginOrganization else { return }
            self.closingProgressTimeoutWorkItem = nil
            let outcomeUnknown = self.hasUnknownClosingWriteExposure
            self.naturalInputUseCase?.invalidateClosingOperationAfterDeadline(
                outcomeUnknown: outcomeUnknown
            )
            PrivacySafeDiagnostics.log(
                subsystem: "EchoLiveMemory",
                event: "closingProgressDeadlineExceeded",
                states: [
                    "lastProgressStage": stage,
                    "outcome": outcomeUnknown ? "outcomeUnknown" : "notSent",
                    "coordinates": outcomeUnknown ? "exactOrPending" : "localOnly",
                ],
                counts: [
                    "queueCount": self.queuedTurns.count,
                    "pendingPersistenceCount": self.pendingPersistenceCount,
                    "handoffCount": self.pendingCanonicalHandoffCount,
                ]
            )
            self.state = outcomeUnknown ? .statusUnknown : .syncPaused
        }
        closingProgressTimeoutWorkItem = workItem
        DispatchQueue.main.asyncAfter(
            deadline: .now() + closingProgressTimeout,
            execute: workItem
        )
    }

    private func cancelClosingProgressDeadline() {
        guard closingProgressTimeoutWorkItem != nil else { return }
        closingProgressTimeoutWorkItem?.cancel()
        closingProgressTimeoutWorkItem = nil
        closingProgressGeneration &+= 1
    }

    private func beginPendingMemoryOrganization(
        receipt: OwnerTruthInterviewNaturalInputReceipt?
    ) {
        guard !didBeginOrganization,
              let receipt,
              receipt.lifecycle == .ended else {
            return
        }
        didBeginOrganization = true
        state = .queued
        beginAcknowledgement(receipt: receipt, preparedCommand: nil)
    }

    private func beginAcknowledgement(
        receipt: OwnerTruthInterviewNaturalInputReceipt,
        preparedCommand: OwnerTruthInterviewReviewBatchAcknowledgementCommand?
    ) {
        guard acknowledgementUseCase == nil else { return }
        logCompletion(event: "acknowledgementStarted")
        let useCase = OwnerTruthInterviewReviewBatchAcknowledgementUseCase(
            accountLease: accountLease,
            threadID: receipt.threadID,
            sessionID: receipt.sessionID,
            inboxClient: client,
            acknowledgementClient: client,
            accountLeaseRuntime: accountLeaseRuntime,
            releasePolicyAvailable: naturalInputPolicyAvailable,
            preparedCommand: preparedCommand,
            diagnosticTraceID: completionTraceID,
            requiresFreshRequestAuthority: true,
            refreshRequestPolicy: naturalInputPolicyRefresh,
            authorityNow: liveAuthorityNow,
            willSendCommand: { [completionCheckpointStore, accountLease, productSessionID] command in
                try completionCheckpointStore.prepareAcknowledgement(
                    command,
                    productSessionID: productSessionID,
                    for: accountLease
                )
            }
        )
        useCase.onViewStateChange = { [weak self, weak useCase] viewState in
            DispatchQueue.main.async {
                guard let self, useCase === self.acknowledgementUseCase else { return }
                self.receiveAcknowledgementState(viewState)
            }
        }
        acknowledgementUseCase = useCase
        useCase.send(.acknowledge)
    }

    private func receiveAcknowledgementState(
        _ viewState: OwnerTruthInterviewReviewBatchAcknowledgementViewState
    ) {
        switch viewState.phase {
        case .acknowledged:
            guard admissionUseCase == nil, let receipt = viewState.receipt else { return }
            logCompletion(event: "ackReceiptAccepted")
            do {
                try completionCheckpointStore.acceptAcknowledgement(
                    receipt,
                    productSessionID: productSessionID,
                    for: accountLease
                )
            } catch {
                logCompletion(event: "ackCheckpointCommitFailed", reason: "storageFailed")
                recordCompletionRequestFailure(
                    stage: "ackCheckpointCommit", reason: "storageFailed",
                    commandID: (try? completionCheckpointStore.load(
                        productSessionID: productSessionID, for: accountLease
                    ))?.acknowledgementCommand?.commandID,
                    exposure: "responseAccepted"
                )
                state = .statusUnknown
                return
            }
            logCompletion(event: "ackCheckpointCommitted")
            beginAdmission(receipt: receipt, preparedCommand: nil)
        case .unavailable, .failed:
            let transportOutcome: EchoLiveMemoryCompletionTransportOutcome
            switch viewState.notice {
            case .outcomeUnknown:
                transportOutcome = .outcomeUnknown
            case .serverRejected:
                transportOutcome = .serverRejected
            default:
                transportOutcome = .notSent
            }
            recordAcknowledgementTransportOutcome(transportOutcome)
            recordCompletionRequestFailure(
                stage: "ackTransport", reason: transportOutcome.rawValue,
                commandID: (try? completionCheckpointStore.load(
                    productSessionID: productSessionID, for: accountLease
                ))?.acknowledgementCommand?.commandID,
                exposure: transportOutcome.rawValue
            )
            state = transportOutcome == .outcomeUnknown ? .statusUnknown : .unavailable
        case .idle, .discovering, .acknowledging:
            break
        }
    }

    private func beginAdmission(
        receipt: OwnerTruthInterviewReviewBatchAcknowledgementReceipt,
        preparedCommand: OwnerTruthInterviewCandidateProposalAdmissionCommand?
    ) {
        guard admissionUseCase == nil else { return }
        logCompletion(event: "admissionStarted")
        let useCase = OwnerTruthInterviewCandidateProposalAdmissionUseCase(
            accountLease: accountLease,
            acknowledgementReceipt: receipt,
            client: client,
            accountLeaseRuntime: accountLeaseRuntime,
            releasePolicyAvailable: candidateReviewPolicyAvailable,
            refreshReleasePolicy: candidateReviewPolicyRefresh,
            preparedCommand: preparedCommand,
            diagnosticTraceID: completionTraceID,
            willSendCommand: { [completionCheckpointStore, accountLease, productSessionID] command in
                try completionCheckpointStore.prepareAdmission(
                    command,
                    productSessionID: productSessionID,
                    for: accountLease
                )
            }
        )
        useCase.onViewStateChange = { [weak self, weak useCase] admissionState in
            DispatchQueue.main.async {
                guard let self, useCase === self.admissionUseCase else { return }
                self.receiveAdmissionState(admissionState)
            }
        }
        admissionUseCase = useCase
        useCase.send(.admit)
    }

    private func receiveAdmissionState(
        _ viewState: OwnerTruthInterviewCandidateProposalAdmissionViewState
    ) {
        switch viewState.phase {
        case .admitted:
            guard let receipt = viewState.receipt else {
                state = .unavailable
                return
            }
            logCompletion(event: "admissionReceiptAccepted")
            do {
                try completionCheckpointStore.acceptAdmission(
                    receipt,
                    productSessionID: productSessionID,
                    for: accountLease
                )
            } catch {
                logCompletion(event: "admissionCheckpointCommitFailed", reason: "storageFailed")
                recordCompletionRequestFailure(
                    stage: "admissionCheckpointCommit", reason: "storageFailed",
                    commandID: admissionUseCase?.preparedAdmissionCommand?.commandID,
                    exposure: "responseAccepted"
                )
                state = .statusUnknown
                return
            }
            logCompletion(event: "admissionCheckpointCommitted")
            persistFollowUpThenBeginObservation(reviewBatchID: receipt.reviewBatchID)
        case .outcomeUnknown:
            recordAdmissionTransportOutcome(.outcomeUnknown)
            recordCompletionRequestFailure(
                stage: "admissionTransport", reason: "outcomeUnknown",
                commandID: admissionUseCase?.preparedAdmissionCommand?.commandID,
                exposure: "outcomeUnknown"
            )
            state = .statusUnknown
        case .unavailable, .failed:
            let outcome: EchoLiveMemoryCompletionTransportOutcome
            switch viewState.notice {
            case .outcomeUnknown:
                outcome = .outcomeUnknown
            case .serverRejected:
                outcome = .serverRejected
            default:
                outcome = .notSent
            }
            recordAdmissionTransportOutcome(outcome)
            recordCompletionRequestFailure(
                stage: "admissionTransport", reason: outcome.rawValue,
                commandID: admissionUseCase?.preparedAdmissionCommand?.commandID,
                exposure: outcome.rawValue
            )
            state = outcome == .outcomeUnknown ? .statusUnknown : .unavailable
        case .idle, .waitingForPolicy, .admitting:
            break
        }
    }

    private func recordAdmissionTransportOutcome(
        _ outcome: EchoLiveMemoryCompletionTransportOutcome
    ) {
        guard let command = admissionUseCase?.preparedAdmissionCommand else { return }
        do {
            try completionCheckpointStore.recordAdmissionTransportOutcome(
                outcome,
                command: command,
                productSessionID: productSessionID,
                for: accountLease
            )
        } catch {
            PrivacySafeDiagnostics.log(
                subsystem: "EchoLiveMemory",
                event: "completionOutcomePersistenceFailed",
                states: ["stage": "admission", "outcome": outcome.rawValue]
            )
        }
    }

    private func recordCompletionRequestFailure(
        stage: String,
        reason: String,
        commandID: String?,
        exposure: String
    ) {
        criticalDiagnosticsStore.recordFirstRequestFailure(
            accountLease: accountLease,
            providerSessionID: productSessionID,
            commandID: commandID,
            messageID: nil,
            sequence: nil,
            stage: stage,
            reason: reason,
            requestExposure: exposure,
            errorDomain: reason == "storageFailed" ? "storage" : "ownerTruth",
            errorCode: reason,
            attempt: 1
        )
    }

    private func logCompletion(event: String, reason: String? = nil) {
        PrivacySafeDiagnostics.log(
            subsystem: "EchoLiveMemoryCompletion",
            event: event,
            states: reason.map { ["reason": $0] } ?? [:],
            correlations: ["trace": completionTraceID]
        )
    }

    private func recordEndTransportOutcome(
        _ outcome: EchoLiveMemoryCompletionTransportOutcome
    ) {
        do {
            guard let checkpoint = try completionCheckpointStore.load(
                productSessionID: productSessionID,
                for: accountLease
            ), let command = checkpoint.endCommand else { return }
            try completionCheckpointStore.recordEndTransportOutcome(
                outcome,
                command: command,
                productSessionID: productSessionID,
                for: accountLease
            )
        } catch {
            PrivacySafeDiagnostics.log(
                subsystem: "EchoLiveMemory",
                event: "completionOutcomePersistenceFailed",
                states: ["stage": "end", "outcome": outcome.rawValue]
            )
        }
    }

    private func recordAcknowledgementTransportOutcome(
        _ outcome: EchoLiveMemoryCompletionTransportOutcome
    ) {
        do {
            guard let checkpoint = try completionCheckpointStore.load(
                productSessionID: productSessionID,
                for: accountLease
            ), let command = checkpoint.acknowledgementCommand else { return }
            try completionCheckpointStore.recordAcknowledgementTransportOutcome(
                outcome,
                command: command,
                productSessionID: productSessionID,
                for: accountLease
            )
        } catch {
            PrivacySafeDiagnostics.log(
                subsystem: "EchoLiveMemory",
                event: "completionOutcomePersistenceFailed",
                states: ["stage": "acknowledgement", "outcome": outcome.rawValue]
            )
        }
    }

    private func persistFollowUpThenBeginObservation(reviewBatchID: OwnerTruthRecordID) {
        guard !isClearingCompletedOutbox else { return }
        isClearingCompletedOutbox = true
        let accountLease = accountLease
        let productSessionID = productSessionID
        let followUpStore = followUpStore
        persistenceQueue.async { [weak self] in
            let result = Result {
                try followUpStore.upsert(
                    productSessionID: productSessionID,
                    reviewBatchID: reviewBatchID,
                    for: accountLease
                )
            }
            DispatchQueue.main.async {
                guard let self else { return }
                self.isClearingCompletedOutbox = false
                self.activeReviewBatchID = reviewBatchID
                switch result {
                case .success:
                    self.logCompletion(event: "followUpCoordinateCommitted")
                case .failure:
                    self.logCompletion(event: "followUpCoordinateCommitFailed", reason: "storageFailed")
                    self.state = .statusUnknown
                }
                // Admission is already authoritative. The admitted checkpoint
                // remains available even when the follow-up write failed.
                self.beginCandidateReadinessObservation(reviewBatchID: reviewBatchID)
            }
        }
    }

    private func beginCandidateReadinessObservation(reviewBatchID: OwnerTruthRecordID) {
        if let activeReviewBatchID, activeReviewBatchID != reviewBatchID {
            return
        }
        activeReviewBatchID = reviewBatchID
        guard sameSessionStatusReader == nil else { return }
        guard client is EchoLiveMemoryRecoveryStatusReadClient else {
            state = .statusUnknown
            logCompletion(event: "sameSessionStatusReaderUnavailable", reason: "boundedReaderMissing")
            return
        }
        guard let setup = makeSameSessionRecoverySetup(reviewBatchID: reviewBatchID) else {
            state = .statusUnknown
            logCompletion(event: "sameSessionRecoveryPlanRejected", reason: "bindingUnavailable")
            return
        }
        observerGeneration &+= 1
        let generation = observerGeneration
        let reader = EchoLiveMemoryRecoveryCoordinator(
            plan: setup.plan,
            client: client,
            accountLeaseRuntime: accountLeaseRuntime,
            organizationStatusTimeout: organizationStatusTimeout,
            candidateReviewPolicyAvailable: candidateReviewPolicyAvailable,
            completionObservationRecorder: setup.observationRecorder
        )
        sameSessionStatusReader = reader
        sameSessionStatusSubscriptionToken = reader.subscribe { [weak self, weak reader] childState in
            DispatchQueue.main.async {
                guard let self,
                      let reader,
                      reader === self.sameSessionStatusReader,
                      generation == self.observerGeneration else { return }
                self.receiveSameSessionStatus(childState, reader: reader)
            }
        }
        logCompletion(event: "sameSessionStatusObservationStarted")
        reader.start()
    }

    private func makeSameSessionRecoverySetup(
        reviewBatchID: OwnerTruthRecordID
    ) -> (
        plan: EchoLiveMemoryRecoveryPlan,
        observationRecorder: ((
            EchoLiveMemoryRecoveryObservation,
            String,
            OwnerTruthRecordID,
            AccountLease
        ) throws -> Void)?
    )? {
        let checkpoint: EchoLiveMemoryCompletionCheckpoint?
        do {
            checkpoint = try completionCheckpointStore.load(
                productSessionID: productSessionID,
                for: accountLease
            )
        } catch {
            logCompletion(event: "sameSessionCheckpointReadFailed", reason: "storageFailed")
            checkpoint = nil
        }
        if let checkpoint {
            guard checkpoint.phase == .admitted,
                  checkpoint.admittedReviewBatchID == reviewBatchID else {
                return nil
            }
        }

        let followUpScan = followUpStore.scan(for: accountLease)
        let matchingFollowUps: [EchoLiveMemoryFollowUpRecord]
        switch followUpScan.status {
        case .valid, .absent:
            matchingFollowUps = followUpScan.records.filter {
                $0.productSessionID == productSessionID
            }
        case .unreadable, .decodeInvalid, .schemaUnsupported, .scopeMismatch:
            matchingFollowUps = []
            logCompletion(event: "sameSessionFollowUpReadFailed", reason: followUpScan.status.rawValue)
        }
        guard matchingFollowUps.count <= 1 else { return nil }
        if let followUp = matchingFollowUps.first,
           followUp.reviewBatchID != reviewBatchID.rawValue {
            return nil
        }
        guard checkpoint != nil || !matchingFollowUps.isEmpty else { return nil }

        var sources: Set<EchoLiveMemoryRecoveryPlanSource> = []
        if checkpoint != nil { sources.insert(.completionCheckpoint) }
        if !matchingFollowUps.isEmpty { sources.insert(.followUp) }
        if (try? liveTurnOutboxStore.load(
            for: accountLease,
            productSessionID: productSessionID
        )) != nil {
            sources.insert(.liveTurnOutbox)
        }
        let revisionMaterial = [
            productSessionID,
            checkpoint?.phase.rawValue ?? "none",
            checkpoint?.updatedAt.timeIntervalSince1970.description ?? "none",
            matchingFollowUps.first?.updatedAt.timeIntervalSince1970.description ?? "none",
        ].joined(separator: "|")
        let plan = EchoLiveMemoryRecoveryPlan(
            accountLease: accountLease,
            productSessionID: productSessionID,
            threadID: checkpoint?.endReceipt?.threadID
                ?? checkpoint?.acknowledgementReceipt?.threadID
                ?? checkpoint?.acknowledgementCommand?.threadID
                ?? checkpoint?.endCommand?.threadID,
            sessionID: checkpoint?.endReceipt?.sessionID
                ?? checkpoint?.acknowledgementReceipt?.sessionID
                ?? checkpoint?.acknowledgementCommand?.sessionID
                ?? checkpoint?.endCommand?.sessionID,
            reviewBatchID: reviewBatchID,
            checkpointPhase: checkpoint?.phase,
            sources: sources,
            localRecordRevision: PrivacySafeDiagnostics.correlationHash(revisionMaterial)
        )
        let observationRecorder: ((
            EchoLiveMemoryRecoveryObservation,
            String,
            OwnerTruthRecordID,
            AccountLease
        ) throws -> Void)? = matchingFollowUps.isEmpty ? nil : {
            [followUpStore] observation, productSessionID, reviewBatchID, lease in
            try followUpStore.recordRecoveryObservation(
                observation,
                productSessionID: productSessionID,
                reviewBatchID: reviewBatchID,
                for: lease
            )
        }
        return (plan, observationRecorder)
    }

    private func receiveSameSessionStatus(
        _ childState: EchoLiveMemoryRecoveryState,
        reader: EchoLiveMemoryRecoveryCoordinator
    ) {
        guard reader.plan.productSessionID == productSessionID,
              reader.plan.reviewBatchID == activeReviewBatchID,
              reader.plan.accountLease == accountLease else { return }
        guard accountLeaseRuntime.validate(accountLease, at: .commit).allowed else {
            stopSameSessionStatusObservation(suspend: true)
            state = .statusUnknown
            return
        }
        switch childState {
        case .discovered, .checking:
            if !state.isAwaitingOrganizationStatus { state = .queued }
        case .queued:
            state = .queued
        case .organizing:
            state = .organizing
        case .retryWaiting(let attempt, let maxAttempts):
            state = .retryWaiting(attempt: attempt, maxAttempts: maxAttempts)
        case .waitingForAccount, .waitingForAuthority, .waitingForPolicy,
                .statusUnknown, .actionRequired, .accessBlocked, .contractBlocked:
            state = .statusUnknown
        case .pendingReview:
            finishSameSessionObservation(with: .pendingReview, reader: reader)
        case .empty:
            finishSameSessionObservation(with: .empty, reader: reader)
        case .terminalFailure(let code):
            finishSameSessionObservation(with: .terminalFailure(code: code), reader: reader)
        case .quarantined:
            finishSameSessionObservation(with: .quarantined, reader: reader)
        }
    }

    private func finishSameSessionObservation(
        with terminalState: EchoLiveMemoryCaptureState,
        reader: EchoLiveMemoryRecoveryCoordinator
    ) {
        let observationPersisted = reader.terminalObservationPersisted
        stopSameSessionStatusObservation(suspend: false)
        guard observationPersisted else {
            state = terminalState
            switch terminalState {
            case .terminalFailure, .quarantined:
                cleanupPending = false
                logCompletion(
                    event: "terminalRecoveryCoordinatesRetained",
                    reason: "storageUnavailable"
                )
            default:
                cleanupPending = true
                logCompletion(
                    event: "terminalObservationCleanupDeferred",
                    reason: "storageUnavailable"
                )
            }
            return
        }
        switch terminalState {
        case .pendingReview, .empty:
            clearCompletedOutboxThenFinishOrganization(with: terminalState)
        case .terminalFailure, .quarantined:
            // A failed organization is terminal only for this observation
            // round. Keep the original outbox, follow-up and completion
            // checkpoint so a later cold start can verify the same batch by
            // read-only status lookup. This is intentional retention, not a
            // deferred success cleanup.
            state = terminalState
            cleanupPending = false
            logCompletion(event: "terminalRecoveryCoordinatesRetained", reason: "organizationFailed")
        default:
            state = terminalState
            cleanupPending = false
        }
    }

    private func stopSameSessionStatusObservation(suspend: Bool) {
        observerGeneration &+= 1
        if let token = sameSessionStatusSubscriptionToken {
            sameSessionStatusReader?.unsubscribe(token)
        }
        sameSessionStatusSubscriptionToken = nil
        if suspend {
            sameSessionStatusReader?.suspend()
        }
        sameSessionStatusReader = nil
    }

    private func clearCompletedOutboxThenFinishOrganization(
        with terminalState: EchoLiveMemoryCaptureState
    ) {
        guard !isClearingCompletedOutbox else { return }
        // Business completion belongs to the server status. Local cleanup is
        // maintenance and must never regress a confirmed terminal result.
        state = terminalState
        isClearingCompletedOutbox = true
        let accountLease = accountLease
        let productSessionID = productSessionID
        let store = liveTurnOutboxStore
        let followUpStore = followUpStore
        let completionCheckpointStore = completionCheckpointStore
        persistenceQueue.async { [weak self] in
            let result = Result {
                try store.remove(for: accountLease, productSessionID: productSessionID)
                try followUpStore.remove(
                    productSessionID: productSessionID,
                    for: accountLease
                )
                try completionCheckpointStore.remove(
                    productSessionID: productSessionID,
                    for: accountLease
                )
            }
            DispatchQueue.main.async {
                guard let self else { return }
                self.isClearingCompletedOutbox = false
                switch result {
                case .success:
                    self.cleanupPending = false
                case .failure:
                    self.cleanupPending = true
                    PrivacySafeDiagnostics.log(
                        subsystem: "EchoLiveMemory",
                        event: "terminalCleanupDeferred",
                        states: ["stage": "localCleanup"],
                        counts: ["cleanupPending": 1]
                    )
                }
            }
        }
    }

    private func endedReceiptIdentity(_ receipt: OwnerTruthInterviewNaturalInputReceipt) -> String {
        [
            receipt.threadID.rawValue.uuidString.lowercased(),
            receipt.sessionID.rawValue.uuidString.lowercased(),
            String(receipt.threadVersion),
            String(receipt.sessionVersion),
        ].joined(separator: "|")
    }

    private func receiveLifecycleEvent(_ event: AppLifecycleEvent) {
        switch event {
        case .willResignActive, .didEnterBackground, .didDisconnect:
            isBackgrounded = true
            sameSessionStatusReader?.suspend()
        case .didBecomeActive, .willEnterForeground:
            let wasBackgrounded = isBackgrounded
            isBackgrounded = false
            guard wasBackgrounded else { return }
            if state.isAwaitingOrganizationStatus,
               let reader = sameSessionStatusReader {
                reader.verifyStatus(startsNewRound: true)
            } else if state == .unavailable || state == .statusUnknown {
                verifyDeliveryStatusIfNeeded()
            }
        case .sceneConnected:
            break
        }
    }

    private func normalizedTurn(_ text: String) -> String? {
        let normalized = text.trimmingCharacters(in: .whitespacesAndNewlines)
        return normalized.isEmpty ? nil : normalized
    }

    private func turnSegments(_ text: String) -> [String] {
        var segments: [String] = []
        var start = text.startIndex
        while start < text.endIndex {
            let end = text.index(
                start,
                offsetBy: OwnerTruthInterviewNaturalInputAppendCommand.maximumCharacterCount,
                limitedBy: text.endIndex
            ) ?? text.endIndex
            segments.append(String(text[start..<end]))
            start = end
        }
        return segments
    }
}

#if DEBUG
extension EchoLiveMemoryCaptureCoordinator {
    func flushPersistenceForTesting(_ completion: @escaping () -> Void) {
        persistenceQueue.async {
            DispatchQueue.main.async(execute: completion)
        }
    }
}
#endif

private struct EchoVoiceProfileExitEvidence {
    let evidenceState: String
    let exitState: String?
    let accessRevoked: Bool?
    let localCleanupState: String?
    let providerCleanupState: String?
    let providerCleanupReceiptAvailable: Bool?

    static let notSelected = EchoVoiceProfileExitEvidence(
        evidenceState: "notSelected",
        exitState: nil,
        accessRevoked: nil,
        localCleanupState: nil,
        providerCleanupState: nil,
        providerCleanupReceiptAvailable: nil
    )

    static let unresolved = EchoVoiceProfileExitEvidence(
        evidenceState: "unresolved",
        exitState: nil,
        accessRevoked: nil,
        localCleanupState: nil,
        providerCleanupState: nil,
        providerCleanupReceiptAvailable: nil
    )
}

private struct DeferredDigitalHumanSessionRelease {
    let contract: DigitalHumanSessionContract
    let originatingAccountLease: AccountLease
    let reason: String
}

private struct TencentBackendPCMDriveTrueDeviceTrace {
    var isActive = false
    var startedAt = Date()
    var trigger = ""
    var requestID = ""
    var turnID = ""
    var voiceProfileId = ""
    var outputMode = "tencentAudioDrive"
    var providerLogId = ""
    var providerRequestId = ""
    var providerMode = ""
    var rawByteCount = 0
    var preparedByteCount = 0
    var expectedChunkCount = 0
    var sentChunkCount = 0
    var sentFinalChunk = false
    var providerSpeakingObserved = false
    var providerPlaybackCompleted = false
    var stopProbeFired = false
    var resumedVoiceCapture = false
    var failureReason = ""
    var failureDetail = ""

    mutating func begin(trigger: String, voiceProfileId: String, outputMode: String) {
        self = TencentBackendPCMDriveTrueDeviceTrace()
        self.isActive = true
        self.startedAt = Date()
        self.trigger = trigger
        self.voiceProfileId = voiceProfileId
        self.outputMode = outputMode
    }

    mutating func markSynthesis(_ synthesis: VoiceCloneSynthesisResult) {
        voiceProfileId = synthesis.voiceProfileId
        outputMode = synthesis.outputMode ?? outputMode
        providerLogId = synthesis.providerLogId ?? ""
        providerRequestId = synthesis.providerRequestId ?? ""
        providerMode = synthesis.providerMode
        rawByteCount = synthesis.byteCount
    }

    mutating func markRequest(turnID: String, requestID: String) {
        self.turnID = turnID
        self.requestID = requestID
    }

    mutating func markSignal(preparedByteCount: Int, expectedChunkCount: Int) {
        self.preparedByteCount = preparedByteCount
        self.expectedChunkCount = expectedChunkCount
    }

    mutating func markChunkSent() {
        sentChunkCount += 1
    }

    mutating func markFinalSent() {
        sentFinalChunk = true
    }

    mutating func markFailure(reason: String, detail: String) {
        failureReason = PrivacySafeDiagnostics.safeCode(
            reason,
            fallback: "redactedFailure"
        )
        failureDetail = detail.isEmpty ? "none" : "redacted"
    }

    var completed: Bool {
        failureReason.isEmpty
            && rawByteCount > 0
            && preparedByteCount > 0
            && sentChunkCount > 0
            && sentFinalChunk
            && (providerPlaybackCompleted || stopProbeFired)
            && resumedVoiceCapture
    }

    func jsonLine(audioOwner: EchoDigitalHumanAudioOwner, emitReason: String) -> String {
        let elapsedMilliseconds = Int(Date().timeIntervalSince(startedAt) * 1000)
        let payload: [String: Any] = [
            "schemaVersion": 2,
            "redactionPolicyVersion": PrivacySafeDiagnostics.redactionPolicyVersion,
            "emitReason": PrivacySafeDiagnostics.safeCode(
                emitReason,
                fallback: "redactedEmitReason"
            ),
            "completed": completed,
            "trigger": PrivacySafeDiagnostics.safeCode(
                trigger,
                fallback: "redactedTrigger"
            ),
            "requestIDHash": PrivacySafeDiagnostics.correlationHash(requestID),
            "turnIDHash": PrivacySafeDiagnostics.correlationHash(turnID),
            "voiceProfileIdHash": PrivacySafeDiagnostics.correlationHash(voiceProfileId),
            "outputMode": PrivacySafeDiagnostics.safeCode(
                outputMode,
                fallback: "unknown"
            ),
            "providerLogIdHash": PrivacySafeDiagnostics.correlationHash(providerLogId),
            "providerRequestIdHash": PrivacySafeDiagnostics.correlationHash(providerRequestId),
            "providerMode": PrivacySafeDiagnostics.safeCode(
                providerMode,
                fallback: "unknown"
            ),
            "rawByteCount": rawByteCount,
            "preparedByteCount": preparedByteCount,
            "expectedChunkCount": expectedChunkCount,
            "sentChunkCount": sentChunkCount,
            "sentFinalChunk": sentFinalChunk,
            "providerSpeakingObserved": providerSpeakingObserved,
            "providerPlaybackCompleted": providerPlaybackCompleted,
            "stopProbeFired": stopProbeFired,
            "resumedVoiceCapture": resumedVoiceCapture,
            "audioOwner": PrivacySafeDiagnostics.safeCode(
                audioOwner.rawValue,
                fallback: "unknown"
            ),
            "failureReason": failureReason,
            "failureDetail": failureDetail,
            "elapsedMilliseconds": elapsedMilliseconds
        ]
        guard JSONSerialization.isValidJSONObject(payload),
              let data = try? JSONSerialization.data(withJSONObject: payload, options: [.sortedKeys]),
              let string = String(data: data, encoding: .utf8) else {
            return "{\"schemaVersion\":2,\"redactionPolicyVersion\":\"iosDiagnostics-v1\",\"completed\":false,\"failureReason\":\"jsonEncodingFailed\"}"
        }
        return string
    }
}

private final class EchoTurnKnowledgeContextGate {
    let turnID: String
    let expectedUserID: String
    let expectedPersonaScope: String
    let expectedDigitalHumanID: String
    let lifecycleToken: DigitalHumanLifecycleToken
    let strictOwnerTruthAuthorityRequired: Bool
    var didSubmit = false
    var didFinishWithoutContext = false
    var failedSubmissionCount = 0
    var timeoutWorkItem: DispatchWorkItem?
    var retryWorkItem: DispatchWorkItem?

    init(
        turnID: String,
        expectedIdentity: EchoKnowledgeContextIdentity,
        lifecycleToken: DigitalHumanLifecycleToken,
        strictOwnerTruthAuthorityRequired: Bool
    ) {
        self.turnID = turnID
        self.expectedUserID = expectedIdentity.userId
        self.expectedPersonaScope = expectedIdentity.personaScope
        self.expectedDigitalHumanID = expectedIdentity.digitalHumanId
        self.lifecycleToken = lifecycleToken
        self.strictOwnerTruthAuthorityRequired = strictOwnerTruthAuthorityRequired
    }

    var expectedIdentity: EchoKnowledgeContextIdentity {
        EchoKnowledgeContextIdentity(
            userId: expectedUserID,
            personaScope: expectedPersonaScope,
            digitalHumanId: expectedDigitalHumanID
        )
    }

    func finishWithoutContext() {
        didFinishWithoutContext = true
        cancel()
    }

    func cancel() {
        timeoutWorkItem?.cancel()
        timeoutWorkItem = nil
        retryWorkItem?.cancel()
        retryWorkItem = nil
    }
}

enum EchoLiveMemoryRecoveryBlockReason: String, Equatable {
    case unclosedLegacySession
    case closingOutboxMissingCheckpoint
    case followUpUnreadable
    case followUpDecodeInvalid
    case followUpSchemaUnsupported
    case followUpScopeMismatch
    case checkpointUnreadable
    case checkpointDecodeInvalid
    case checkpointSchemaUnsupported
    case checkpointScopeMismatch
    case bindingMismatch
    case ambiguousSceneOrder
}

struct EchoLiveMemoryRecoveryBlockedRecord: Equatable {
    let productSessionID: String
    let reason: EchoLiveMemoryRecoveryBlockReason
}

enum EchoLiveMemoryRecoveryPlanSource: String, Equatable, Hashable {
    case completionCheckpoint
    case followUp
    case liveTurnOutbox
}

struct EchoLiveMemoryRecoveryPlan: Equatable {
    let accountLease: AccountLease
    let productSessionID: String
    let threadID: OwnerTruthRecordID?
    let sessionID: OwnerTruthRecordID?
    let reviewBatchID: OwnerTruthRecordID?
    let checkpointPhase: EchoLiveMemoryCompletionPhase?
    let sources: Set<EchoLiveMemoryRecoveryPlanSource>
    let localRecordRevision: String
    let deliveryStartCommand: OwnerTruthInterviewNaturalInputStartCommand?
    let deliveryFromSequence: Int?
    let deliveryWatermark: Int?
    let deliveryPendingTurns: [OwnerTruthInterviewLiveTurnDelivery]

    init(
        accountLease: AccountLease,
        productSessionID: String,
        threadID: OwnerTruthRecordID?,
        sessionID: OwnerTruthRecordID?,
        reviewBatchID: OwnerTruthRecordID?,
        checkpointPhase: EchoLiveMemoryCompletionPhase?,
        sources: Set<EchoLiveMemoryRecoveryPlanSource>,
        localRecordRevision: String,
        deliveryStartCommand: OwnerTruthInterviewNaturalInputStartCommand? = nil,
        deliveryFromSequence: Int? = nil,
        deliveryWatermark: Int? = nil,
        deliveryPendingTurns: [OwnerTruthInterviewLiveTurnDelivery] = []
    ) {
        self.accountLease = accountLease
        self.productSessionID = productSessionID
        self.threadID = threadID
        self.sessionID = sessionID
        self.reviewBatchID = reviewBatchID
        self.checkpointPhase = checkpointPhase
        self.sources = sources
        self.localRecordRevision = localRecordRevision
        self.deliveryStartCommand = deliveryStartCommand
        self.deliveryFromSequence = deliveryFromSequence
        self.deliveryWatermark = deliveryWatermark
        self.deliveryPendingTurns = deliveryPendingTurns
    }
}

enum EchoLiveMemoryRecoveryAccessReason: String, Equatable {
    case accountActivating
    case leaseUnavailable
    case staleLease
    case authorityUnresolved
    case scopeMismatch
    case policyMissing
    case policyExpired
    case policyDenied
    case policyRefreshFailed
    case authFailed
    case offline
    case dnsFailure
    case tlsFailure
    case timeout
    case notObserved
    case pendingAcknowledgement
    case readyForAdmission
    case versionConflict
    case resourceInvalidated
    case bindingMismatch
    case schemaInvalid
    case staleAttempt
    case budgetExhausted
    case storageUnavailable
    case unknown
}

enum EchoLiveMemoryRecoveryState: Equatable {
    case discovered
    case waitingForAccount
    case waitingForAuthority
    case waitingForPolicy
    case checking
    case queued
    case organizing
    case retryWaiting(attempt: Int, maxAttempts: Int)
    case statusUnknown(EchoLiveMemoryRecoveryAccessReason)
    case actionRequired(EchoLiveMemoryCompletionPhase?)
    case accessBlocked(EchoLiveMemoryRecoveryAccessReason)
    case contractBlocked(EchoLiveMemoryRecoveryAccessReason)
    case pendingReview
    case empty
    case terminalFailure(code: String?)
    case quarantined

    var isTerminal: Bool {
        switch self {
        case .pendingReview, .empty, .terminalFailure, .quarantined:
            return true
        case .discovered, .waitingForAccount, .waitingForAuthority, .waitingForPolicy,
                .checking, .queued, .organizing, .retryWaiting, .statusUnknown,
                .actionRequired, .accessBlocked, .contractBlocked:
            return false
        }
    }

    var isDeterminateBlock: Bool {
        switch self {
        case .actionRequired, .accessBlocked, .contractBlocked:
            return true
        case .discovered, .waitingForAccount, .waitingForAuthority, .waitingForPolicy,
                .checking, .queued, .organizing, .retryWaiting, .statusUnknown,
                .pendingReview, .empty, .terminalFailure, .quarantined:
            return false
        }
    }
}

protocol EchoLiveMemoryRecoveryStatusReadClient: AnyObject {
    @discardableResult
    func fetchEchoLiveMemoryRecoveryStatus(
        accountLease: AccountLease,
        vaultID: OwnerTruthVaultID,
        reviewBatchID: OwnerTruthRecordID,
        readContext: OwnerTruthReadContext,
        completion: @escaping (
            OwnerTruthReadOutcome<OwnerTruthInterviewCandidateProposalStatus>
        ) -> Void
    ) -> OwnerTruthReadHandle
}

protocol EchoLiveMemoryRecoveryPendingBatchReadClient: AnyObject {
    @discardableResult
    func fetchEchoLiveMemoryRecoveryPendingBatches(
        accountLease: AccountLease,
        vaultID: OwnerTruthVaultID,
        readContext: OwnerTruthReadContext,
        completion: @escaping (
            OwnerTruthReadOutcome<OwnerTruthInterviewPendingReviewBatchInbox>
        ) -> Void
    ) -> OwnerTruthReadHandle
}

final class EchoLiveMemoryRecoveryCoordinator {
    private static let processRunID = UUID().uuidString

    let id = UUID()
    let plan: EchoLiveMemoryRecoveryPlan

    private let client: OwnerTruthInterviewCandidateProposalStatusClient
    private let accountLeaseRuntime: AccountLeaseRuntimePort
    private let candidateReviewPolicyAvailable: () -> Bool
    private let now: () -> Date
    private let schedule: (TimeInterval, @escaping () -> Void) -> DispatchWorkItem
    private let roundDuration: TimeInterval
    private let completionObservationRecorder: ((
        EchoLiveMemoryRecoveryObservation,
        String,
        OwnerTruthRecordID,
        AccountLease
    ) throws -> Void)?
    private var readContext: OwnerTruthReadContext?
    private var activeRoundID: UUID?
    private var activeReadHandle: OwnerTruthReadHandle?
    private var activeRequestID: UUID?
    private var pollWorkItem: DispatchWorkItem?
    private var activePollID: UUID?
    private var deadlineWorkItem: DispatchWorkItem?
    private var resolvedReviewBatchID: OwnerTruthRecordID?
    private var lastKnownPendingState: EchoLiveMemoryRecoveryState?
    private var generation: UInt = 0
    private var subscriptions: [UUID: (EchoLiveMemoryRecoveryState) -> Void] = [:]
    private var subscriptionEpoch: UInt = 0
    private var lastStartedSubscriptionEpoch: UInt = 0

    private(set) var terminalObservationPersisted = false

    private(set) var state: EchoLiveMemoryRecoveryState = .discovered {
        didSet {
            guard oldValue != state else { return }
            let observers = subscriptions.values
            observers.forEach { $0(state) }
            onStateChange?(state)
        }
    }

    var onStateChange: ((EchoLiveMemoryRecoveryState) -> Void)?
    var trackedProductSessionID: String { plan.productSessionID }

    #if DEBUG
    var hasActiveReadForTesting: Bool { activeRequestID != nil || activeReadHandle != nil }
    #endif

    init(
        plan: EchoLiveMemoryRecoveryPlan,
        client: OwnerTruthInterviewCandidateProposalStatusClient,
        accountLeaseRuntime: AccountLeaseRuntimePort,
        organizationStatusTimeout: TimeInterval,
        candidateReviewPolicyAvailable: @escaping () -> Bool,
        completionObservationRecorder: ((
            EchoLiveMemoryRecoveryObservation,
            String,
            OwnerTruthRecordID,
            AccountLease
        ) throws -> Void)? = nil,
        now: @escaping () -> Date = Date.init,
        schedule: @escaping (
            TimeInterval,
            @escaping () -> Void
        ) -> DispatchWorkItem = { delay, action in
            let item = DispatchWorkItem(block: action)
            DispatchQueue.main.asyncAfter(deadline: .now() + delay, execute: item)
            return item
        }
    ) {
        self.plan = plan
        self.client = client
        self.accountLeaseRuntime = accountLeaseRuntime
        self.candidateReviewPolicyAvailable = candidateReviewPolicyAvailable
        self.completionObservationRecorder = completionObservationRecorder
        self.roundDuration = max(0.01, organizationStatusTimeout)
        self.now = now
        self.schedule = schedule
    }

    @discardableResult
    func subscribe(
        _ observer: @escaping (EchoLiveMemoryRecoveryState) -> Void
    ) -> UUID {
        let token = UUID()
        subscriptions[token] = observer
        subscriptionEpoch &+= 1
        observer(state.isTerminal ? .discovered : state)
        return token
    }

    func unsubscribe(_ token: UUID) {
        subscriptions[token] = nil
    }

    func start() {
        guard activeRequestID == nil else { return }
        let startsInitialRound = state == .discovered
        let startsReentryRound = subscriptionEpoch > lastStartedSubscriptionEpoch
        guard startsInitialRound || startsReentryRound else { return }
        lastStartedSubscriptionEpoch = subscriptionEpoch
        verifyStatus(startsNewRound: true)
    }

    func verifyStatus(startsNewRound: Bool = true) {
        guard activeRequestID == nil else { return }
        guard accountLeaseRuntime.validate(plan.accountLease, at: .request).allowed else {
            state = .waitingForAccount
            log(event: "readinessWaiting", reason: .leaseUnavailable)
            return
        }
        guard let vaultID = OwnerTruthVaultID(plan.accountLease.vaultId) else {
            state = .contractBlocked(.scopeMismatch)
            return
        }
        let context: OwnerTruthReadContext
        if startsNewRound {
            deadlineWorkItem?.cancel()
            pollWorkItem?.cancel()
            pollWorkItem = nil
            activePollID = nil
            let startedAt = now()
            let roundID = UUID()
            activeRoundID = roundID
            lastKnownPendingState = nil
            terminalObservationPersisted = false
            context = OwnerTruthReadContext(
                resource: .liveMemoryRecoveryStatus,
                intentStartedAt: startedAt,
                deadline: startedAt.addingTimeInterval(roundDuration)
            )
            armDeadline(for: context, roundID: roundID)
        } else {
            guard activeRoundID != nil, let currentContext = readContext else {
                log(event: "pollDiscarded", reason: .staleAttempt)
                return
            }
            guard now() < currentContext.deadline else {
                finishObservationRound(reason: .timeout)
                return
            }
            context = currentContext.nextAttempt
        }
        readContext = context
        guard let reviewBatchID = resolvedReviewBatchID ?? plan.reviewBatchID else {
            if plan.sources == [.liveTurnOutbox], plan.checkpointPhase == nil,
               plan.deliveryStartCommand != nil {
                beginDeliveryRead(context: context, vaultID: vaultID)
                return
            }
            if (plan.checkpointPhase == .endPrepared
                || plan.checkpointPhase == .ended
                || (plan.checkpointPhase == nil && plan.sources == [.liveTurnOutbox])),
               plan.threadID != nil,
               plan.sessionID != nil {
                discoverPendingBatch(context: context, vaultID: vaultID)
            } else {
                finishRound(
                    as: .actionRequired(plan.checkpointPhase),
                    reason: .notObserved
                )
            }
            return
        }
        beginStatusRead(context: context, vaultID: vaultID, reviewBatchID: reviewBatchID)
    }

    private func beginDeliveryRead(
        context: OwnerTruthReadContext,
        vaultID: OwnerTruthVaultID
    ) {
        guard let reader = client as? OwnerTruthLiveDeliveryStatusClient,
              let sessionID = plan.sessionID,
              let threadID = plan.threadID,
              let start = plan.deliveryStartCommand,
              start.sessionID == sessionID,
              start.threadID == threadID,
              start.productSessionID == plan.productSessionID else {
            finishRound(as: .contractBlocked(.bindingMismatch), reason: .bindingMismatch)
            return
        }
        generation &+= 1
        let requestGeneration = generation
        let requestID = UUID()
        activeRequestID = requestID
        state = .checking
        log(event: "deliveryReadStarted", requestID: requestID)
        reader.fetchOwnerTruthLiveDeliveryStatus(
            accountLease: plan.accountLease,
            vaultID: vaultID,
            sessionID: sessionID,
            productSessionID: plan.productSessionID,
            fromClientSequence: max(1, plan.deliveryFromSequence ?? 1)
        ) { [weak self] result in
            DispatchQueue.main.async {
                guard let self,
                      self.generation == requestGeneration,
                      self.activeRequestID == requestID else { return }
                self.activeRequestID = nil
                guard self.accountLeaseRuntime.validate(self.plan.accountLease, at: .commit).allowed else {
                    self.finishRound(as: .accessBlocked(.staleLease), reason: .staleLease)
                    return
                }
                switch result {
                case .failure:
                    self.finishRound(as: .statusUnknown(.notObserved), reason: .notObserved)
                case .success(let status):
                    guard status.productSessionID == self.plan.productSessionID,
                          status.sessionID == sessionID,
                          status.threadID == threadID,
                          status.confirmedStartedReceipt(for: start) != nil,
                          self.plan.deliveryPendingTurns.allSatisfy({ turn in
                              !status.deliveries.contains(where: {
                                  $0.clientSequenceNumber == turn.clientSequenceNumber
                              }) || status.delivery(matching: turn) != nil
                          }) else {
                        self.finishRound(as: .contractBlocked(.bindingMismatch), reason: .bindingMismatch)
                        return
                    }
                    let complete = status.continuousClientSequence >= (self.plan.deliveryWatermark ?? Int.max)
                    self.finishRound(
                        as: complete ? .actionRequired(self.plan.checkpointPhase) : .statusUnknown(.notObserved),
                        reason: complete ? .pendingAcknowledgement : .notObserved
                    )
                }
            }
        }
    }

    private func beginStatusRead(
        context: OwnerTruthReadContext,
        vaultID: OwnerTruthVaultID,
        reviewBatchID: OwnerTruthRecordID
    ) {
        generation &+= 1
        let requestGeneration = generation
        let requestID = UUID()
        activeRequestID = requestID
        state = .checking
        log(event: "readAttemptStarted", requestID: requestID)

        if let boundedClient = client as? EchoLiveMemoryRecoveryStatusReadClient {
            activeReadHandle = boundedClient.fetchEchoLiveMemoryRecoveryStatus(
                accountLease: plan.accountLease,
                vaultID: vaultID,
                reviewBatchID: reviewBatchID,
                readContext: context
            ) { [weak self] outcome in
                DispatchQueue.main.async {
                    self?.receive(
                        outcome,
                        requestID: requestID,
                        generation: requestGeneration
                    )
                }
            }
            return
        }

        guard candidateReviewPolicyAvailable() else {
            activeRequestID = nil
            state = .waitingForPolicy
            log(event: "requestDenied", reason: .policyExpired)
            return
        }
        client.fetchOwnerTruthInterviewCandidateProposalStatus(
            vaultID: vaultID,
            reviewBatchID: reviewBatchID
        ) { [weak self] result in
            DispatchQueue.main.async {
                guard let self else { return }
                self.receive(
                    OwnerTruthReadOutcome(
                        readContext: context,
                        result: result.map { $0.bound(to: self.plan.accountLease) }
                    ),
                    requestID: requestID,
                    generation: requestGeneration
                )
            }
        }
    }

    func suspend() {
        let preservesDeterminateState = state.isTerminal || state.isDeterminateBlock
        finishRound(
            as: preservesDeterminateState ? state : .statusUnknown(.staleAttempt),
            reason: .staleAttempt,
            event: "roundSuspended"
        )
    }

    private func receive(
        _ outcome: OwnerTruthReadOutcome<OwnerTruthInterviewCandidateProposalStatus>,
        requestID: UUID,
        generation requestGeneration: UInt
    ) {
        guard requestGeneration == generation,
              activeRequestID == requestID else {
            log(event: "resultDiscarded", reason: .staleAttempt, requestID: requestID)
            return
        }
        activeRequestID = nil
        activeReadHandle = nil
        readContext = outcome.readContext
        guard accountLeaseRuntime.validate(plan.accountLease, at: .commit).allowed else {
            finishRound(
                as: .accessBlocked(.staleLease),
                reason: .staleLease,
                requestID: requestID,
                event: "requestDenied"
            )
            return
        }
        switch outcome.result {
        case .success(let status):
            guard status.isBound(to: plan.accountLease),
                  status.vaultID.rawValue == plan.accountLease.vaultId,
                  status.reviewBatchID == (resolvedReviewBatchID ?? plan.reviewBatchID) else {
                finishRound(
                    as: .contractBlocked(.bindingMismatch),
                    reason: .bindingMismatch,
                    requestID: requestID,
                    event: "resultDiscarded"
                )
                return
            }
            log(event: "resultValidated", requestID: requestID)
            receive(status)
        case .failure(let error):
            let reason = Self.safeReason(for: error)
            switch reason {
            case .policyMissing, .policyExpired, .policyRefreshFailed:
                finishRound(as: .waitingForPolicy, reason: reason, requestID: requestID)
            case .leaseUnavailable, .staleLease, .authFailed, .scopeMismatch:
                finishRound(as: .accessBlocked(reason), reason: reason, requestID: requestID)
            case .bindingMismatch, .schemaInvalid, .versionConflict, .resourceInvalidated:
                finishRound(as: .contractBlocked(reason), reason: reason, requestID: requestID)
            default:
                finishRound(as: .statusUnknown(reason), reason: reason, requestID: requestID)
            }
        }
    }

    private func receive(_ status: OwnerTruthInterviewCandidateProposalStatus) {
        if status.reviewBatchState == .pendingAcknowledgement {
            finishRound(as: .actionRequired(.ended), reason: .pendingAcknowledgement)
            return
        }
        if status.candidateProposalState == .readyForAdmission {
            finishRound(as: .actionRequired(.acknowledged), reason: .readyForAdmission)
            return
        }
        if status.candidateProposalState == .invalidated || status.sourceState == .inactive {
            finishTerminalRound(
                as: .terminalFailure(code: status.candidateExtractionFailureCode),
                observationKind: .terminalFailure,
                safeFailureCode: status.candidateExtractionFailureCode
            )
            return
        }
        switch status.candidateReviewState {
        case .reviewReady:
            finishTerminalRound(as: .pendingReview, observationKind: .pendingReview)
        case .noCandidates:
            finishTerminalRound(as: .empty, observationKind: .empty)
        case .extractionFailed:
            finishTerminalRound(
                as: .terminalFailure(code: status.candidateExtractionFailureCode),
                observationKind: .terminalFailure,
                safeFailureCode: status.candidateExtractionFailureCode
            )
        case .extractionQuarantined:
            finishTerminalRound(as: .quarantined, observationKind: .quarantined)
        case .notReady:
            switch status.candidateExtractionJobState {
            case .pending, .notCreated:
                state = .queued
            case .leased:
                state = .organizing
            case .retryWait:
                state = .retryWaiting(
                    attempt: status.candidateExtractionAttempt,
                    maxAttempts: status.candidateExtractionMaxAttempts
                )
            case .failed, .cancelled, .blocked:
                finishTerminalRound(
                    as: .terminalFailure(code: status.candidateExtractionFailureCode),
                    observationKind: .terminalFailure,
                    safeFailureCode: status.candidateExtractionFailureCode
                )
                return
            case .unknown, .succeeded:
                finishRound(as: .statusUnknown(.notObserved), reason: .notObserved)
                return
            }
            lastKnownPendingState = state
            scheduleNextReadIfPossible()
        }
    }

    private func scheduleNextReadIfPossible() {
        pollWorkItem?.cancel()
        activePollID = nil
        guard let context = readContext,
              let roundID = activeRoundID,
              now() < context.deadline,
              context.resourceGETCount < 24 else {
            finishObservationRound(reason: .budgetExhausted)
            return
        }
        let pollID = UUID()
        let pollTraceID = context.traceID
        let pollGeneration = generation
        activePollID = pollID
        let delay: TimeInterval
        switch context.resourceGETCount {
        case 0...1: delay = 1
        case 2: delay = 2
        case 3: delay = 4
        case 4: delay = 8
        default: delay = 10
        }
        pollWorkItem = schedule(delay) { [weak self] in
            guard let self else { return }
            guard self.activePollID == pollID,
                  self.activeRoundID == roundID,
                  self.readContext?.traceID == pollTraceID,
                  self.generation == pollGeneration else {
                self.log(
                    event: "pollDiscarded",
                    reason: .staleAttempt,
                    requestID: pollID,
                    context: context
                )
                return
            }
            self.pollWorkItem = nil
            self.activePollID = nil
            self.verifyStatus(startsNewRound: false)
        }
    }

    private func discoverPendingBatch(
        context: OwnerTruthReadContext,
        vaultID: OwnerTruthVaultID
    ) {
        guard let threadID = plan.threadID,
              let sessionID = plan.sessionID,
              let discoveryClient = client as? EchoLiveMemoryRecoveryPendingBatchReadClient else {
            finishRound(as: .actionRequired(plan.checkpointPhase), reason: .notObserved)
            return
        }
        generation &+= 1
        let requestGeneration = generation
        let requestID = UUID()
        activeRequestID = requestID
        state = .checking
        let discoveryContext = OwnerTruthReadContext(
            resource: .liveMemoryRecoveryHandle,
            traceID: context.traceID,
            attempt: context.attempt,
            intentStartedAt: context.intentStartedAt,
            deadline: context.deadline,
            resourceGETCount: context.resourceGETCount,
            policyFetchCount: context.policyFetchCount,
            authRecoveryCount: context.authRecoveryCount,
            runtimeRecoveryCount: context.runtimeRecoveryCount
        )
        readContext = discoveryContext
        log(event: "handleDiscoveryStarted", requestID: requestID)
        activeReadHandle = discoveryClient.fetchEchoLiveMemoryRecoveryPendingBatches(
            accountLease: plan.accountLease,
            vaultID: vaultID,
            readContext: discoveryContext
        ) { [weak self] outcome in
            DispatchQueue.main.async {
                guard let self,
                      requestGeneration == self.generation,
                      self.activeRequestID == requestID else {
                    return
                }
                self.activeRequestID = nil
                self.activeReadHandle = nil
                self.readContext = outcome.readContext
                guard self.accountLeaseRuntime.validate(
                    self.plan.accountLease,
                    at: .commit
                ).allowed else {
                    self.finishRound(
                        as: .accessBlocked(.staleLease),
                        reason: .staleLease,
                        requestID: requestID
                    )
                    return
                }
                switch outcome.result {
                case .success(let inbox):
                    guard inbox.isBound(to: self.plan.accountLease),
                          inbox.vaultID.rawValue == self.plan.accountLease.vaultId else {
                        self.finishRound(
                            as: .contractBlocked(.scopeMismatch),
                            reason: .scopeMismatch,
                            requestID: requestID
                        )
                        return
                    }
                    let matches = inbox.reviewBatches.filter {
                        $0.threadID == threadID && $0.sessionID == sessionID
                    }
                    guard matches.count == 1, let match = matches.first else {
                        let nextState: EchoLiveMemoryRecoveryState = matches.isEmpty
                            ? .statusUnknown(.notObserved)
                            : .contractBlocked(.bindingMismatch)
                        self.finishRound(
                            as: nextState,
                            reason: matches.isEmpty ? .notObserved : .bindingMismatch,
                            requestID: requestID
                        )
                        return
                    }
                    self.resolvedReviewBatchID = match.reviewBatchID
                    self.log(event: "handleDiscoveryValidated", requestID: requestID)
                    self.verifyStatus(startsNewRound: false)
                case .failure(let error):
                    let reason = Self.safeReason(for: error)
                    self.finishRound(
                        as: .statusUnknown(reason),
                        reason: reason,
                        requestID: requestID
                    )
                }
            }
        }
    }

    private func armDeadline(for context: OwnerTruthReadContext, roundID: UUID) {
        let delay = max(0, context.deadline.timeIntervalSince(now()))
        deadlineWorkItem = schedule(delay) { [weak self] in
            guard let self,
                  self.activeRoundID == roundID,
                  self.readContext?.traceID == context.traceID,
                  !self.state.isTerminal,
                  !self.state.isDeterminateBlock else { return }
            let expiredRequestID = self.activeRequestID
            self.finishObservationRound(
                reason: .timeout,
                requestID: expiredRequestID
            )
        }
    }

    private func finishObservationRound(
        reason: EchoLiveMemoryRecoveryAccessReason,
        requestID: UUID? = nil
    ) {
        finishRound(
            as: lastKnownPendingState ?? .statusUnknown(reason),
            reason: reason,
            requestID: requestID
        )
    }

    private func finishTerminalRound(
        as newState: EchoLiveMemoryRecoveryState,
        observationKind: EchoLiveMemoryRecoveryObservationKind,
        safeFailureCode: String? = nil
    ) {
        terminalObservationPersisted = false
        if let reviewBatchID = resolvedReviewBatchID ?? plan.reviewBatchID,
           let completionObservationRecorder {
            do {
                try completionObservationRecorder(
                    EchoLiveMemoryRecoveryObservation(
                        kind: observationKind,
                        observedAt: now(),
                        safeFailureCode: safeFailureCode.map {
                            PrivacySafeDiagnostics.safeCode($0, fallback: "unknown")
                        }
                    ),
                    plan.productSessionID,
                    reviewBatchID,
                    plan.accountLease
                )
                terminalObservationPersisted = true
                log(event: "completionObservationPersisted")
            } catch {
                log(event: "completionObservationPersistenceFailed", reason: .storageUnavailable)
            }
        }
        finishRound(as: newState)
    }

    private func finishRound(
        as newState: EchoLiveMemoryRecoveryState,
        reason: EchoLiveMemoryRecoveryAccessReason? = nil,
        requestID: UUID? = nil,
        event: String = "roundFinished"
    ) {
        generation &+= 1
        activeRoundID = nil
        activeRequestID = nil
        activeReadHandle?.cancel()
        activeReadHandle = nil
        pollWorkItem?.cancel()
        pollWorkItem = nil
        activePollID = nil
        deadlineWorkItem?.cancel()
        deadlineWorkItem = nil
        state = newState
        log(event: event, reason: reason, requestID: requestID)
    }

    private func log(
        event: String,
        reason: EchoLiveMemoryRecoveryAccessReason? = nil,
        requestID: UUID? = nil,
        context diagnosticContext: OwnerTruthReadContext? = nil
    ) {
        let context = diagnosticContext ?? readContext
        var states = ["readMode": "readOnly"]
        if let reason { states["reason"] = reason.rawValue }
        PrivacySafeDiagnostics.log(
            subsystem: "EchoLiveMemoryRecovery",
            event: event,
            states: states,
            counts: [
                "attempt": context?.attempt ?? 0,
                "recoveryGeneration": Int(generation),
            ],
            correlations: [
                "trace": context?.traceID ?? "notStarted",
                "workflow": PrivacySafeDiagnostics.correlationHash(plan.productSessionID),
                "processRun": Self.processRunID,
                "request": requestID?.uuidString ?? "none",
            ]
        )
    }

    private static func safeReason(for error: Error) -> EchoLiveMemoryRecoveryAccessReason {
        if let clientError = error as? DreamJourneyBackendClient.ClientError {
            switch clientError {
            case .accountScopeChanged:
                return .staleLease
            case .userAuthenticationRequired, .sessionUpgradeRequired:
                return .authFailed
            case .verifiedPreHandlerAuthenticationRejection:
                return .authFailed
            case .featurePolicyDenied(_, let reason):
                switch reason {
                case "expiredPolicyCache", "capturedPolicyExpired", "policyVersionChanged":
                    return .policyExpired
                case "policyRefreshFailed":
                    return .policyRefreshFailed
                case "readDeadlineExceeded":
                    return .timeout
                case "readBudgetExhausted":
                    return .budgetExhausted
                default:
                    return .policyDenied
                }
            case .backendError(let statusCode, _):
                switch statusCode {
                case 401: return .authFailed
                case 403: return .policyDenied
                case 404: return .notObserved
                case 409: return .versionConflict
                case 410: return .resourceInvalidated
                default: return .unknown
                }
            case .invalidJSONResponse, .unsupportedJSONRoot:
                return .schemaInvalid
            case .recoveryAccessDenied:
                return .policyDenied
            }
        }
        if let urlError = error as? URLError {
            switch urlError.code {
            case .notConnectedToInternet, .networkConnectionLost:
                return .offline
            case .cannotFindHost, .dnsLookupFailed:
                return .dnsFailure
            case .secureConnectionFailed, .serverCertificateUntrusted,
                    .serverCertificateHasBadDate, .serverCertificateHasUnknownRoot:
                return .tlsFailure
            case .timedOut:
                return .timeout
            default:
                return .unknown
            }
        }
        return .unknown
    }
}

final class EchoLiveMemoryRecoveryRegistry {
    static let shared = EchoLiveMemoryRecoveryRegistry()

    private var coordinators: [String: EchoLiveMemoryRecoveryCoordinator] = [:]
    private let lock = NSLock()

    func coordinator(
        for plan: EchoLiveMemoryRecoveryPlan,
        client: OwnerTruthInterviewCandidateProposalStatusClient,
        accountLeaseRuntime: AccountLeaseRuntimePort,
        organizationStatusTimeout: TimeInterval,
        candidateReviewPolicyAvailable: @escaping () -> Bool,
        completionObservationRecorder: ((
            EchoLiveMemoryRecoveryObservation,
            String,
            OwnerTruthRecordID,
            AccountLease
        ) throws -> Void)? = nil,
        now: @escaping () -> Date = Date.init,
        schedule: @escaping (
            TimeInterval,
            @escaping () -> Void
        ) -> DispatchWorkItem = { delay, action in
            let item = DispatchWorkItem(block: action)
            DispatchQueue.main.asyncAfter(deadline: .now() + delay, execute: item)
            return item
        }
    ) -> EchoLiveMemoryRecoveryCoordinator {
        let key = PrivacySafeDiagnostics.correlationHash([
            plan.accountLease.subjectId,
            plan.accountLease.vaultId,
            plan.accountLease.authorityEpoch,
            plan.productSessionID,
        ].joined(separator: "|"))
        lock.lock()
        defer { lock.unlock() }
        if let existing = coordinators[key], existing.plan == plan {
            PrivacySafeDiagnostics.log(
                subsystem: "EchoLiveMemoryRecovery",
                event: "recoveryClaimed",
                states: ["ownership": "existing"],
                correlations: [
                    "workflow": PrivacySafeDiagnostics.correlationHash(plan.productSessionID),
                ]
            )
            return existing
        }
        coordinators[key]?.suspend()
        let coordinator = EchoLiveMemoryRecoveryCoordinator(
            plan: plan,
            client: client,
            accountLeaseRuntime: accountLeaseRuntime,
            organizationStatusTimeout: organizationStatusTimeout,
            candidateReviewPolicyAvailable: candidateReviewPolicyAvailable,
            completionObservationRecorder: completionObservationRecorder,
            now: now,
            schedule: schedule
        )
        coordinators[key] = coordinator
        PrivacySafeDiagnostics.log(
            subsystem: "EchoLiveMemoryRecovery",
            event: "recoveryClaimed",
            states: ["ownership": "new"],
            correlations: [
                "workflow": PrivacySafeDiagnostics.correlationHash(plan.productSessionID),
            ]
        )
        return coordinator
    }
}

struct EchoLiveMemoryRecoveryResult {
    let coordinators: [EchoLiveMemoryRecoveryCoordinator]
    let blockedRecords: [EchoLiveMemoryRecoveryBlockedRecord]
    let presentationBlockedRecord: EchoLiveMemoryRecoveryBlockedRecord?
}

/// Cold-start discovery is side-effect free with respect to interview writes.
/// It merges durable coordinates before constructing a read-only coordinator.
final class EchoLiveMemoryRecoveryService {
    private let registry: EchoLiveMemoryRecoveryRegistry

    init(registry: EchoLiveMemoryRecoveryRegistry = .shared) {
        self.registry = registry
    }

    func resumePendingWorkflows(
        accountLease: AccountLease,
        excluding trackedProductSessionIDs: Set<String>,
        client: OwnerTruthInterviewCandidateProposalStatusClient = DreamJourneyBackendClient.shared,
        accountLeaseRuntime: AccountLeaseRuntimePort = AccountLeaseRuntime.shared,
        liveTurnOutboxStore: OwnerTruthInterviewLiveTurnOutboxStore = .shared,
        followUpStore: EchoLiveMemoryFollowUpStore = .shared,
        completionCheckpointStore: EchoLiveMemoryCompletionCheckpointStore = .shared,
        organizationStatusTimeout: TimeInterval = 180,
        now: @escaping () -> Date = Date.init,
        schedule: @escaping (
            TimeInterval,
            @escaping () -> Void
        ) -> DispatchWorkItem = { delay, action in
            let item = DispatchWorkItem(block: action)
            DispatchQueue.main.asyncAfter(deadline: .now() + delay, execute: item)
            return item
        },
        naturalInputPolicyAvailable: @escaping () -> Bool,
        candidateReviewPolicyAvailable: @escaping () -> Bool
    ) -> EchoLiveMemoryRecoveryResult {
        PrivacySafeDiagnostics.log(
            subsystem: "EchoLiveMemoryRecovery",
            event: "scanStarted",
            states: ["readMode": "readOnly"]
        )
        guard accountLeaseRuntime.validate(accountLease, at: .request).allowed else {
            PrivacySafeDiagnostics.log(
                subsystem: "EchoLiveMemoryRecovery",
                event: "scanCompleted",
                states: ["result": "leaseUnavailable"],
                counts: ["planCount": 0, "blockedCount": 0]
            )
            return EchoLiveMemoryRecoveryResult(
                coordinators: [], blockedRecords: [], presentationBlockedRecord: nil
            )
        }

        let checkpoints = completionCheckpointStore.records(for: accountLease)
        let followUpScan = followUpStore.scan(for: accountLease)
        let followUps = followUpScan.records
        let outboxes = liveTurnOutboxStore.snapshots(for: accountLease)
        let checkpointIDs = Set(checkpoints.map(\.productSessionID))
        let followUpIDs = Set(followUps.map(\.productSessionID))
        var sceneCreatedAt: [String: Date] = [:]
        var discoveredIDs = trackedProductSessionIDs
        var coordinators: [EchoLiveMemoryRecoveryCoordinator] = []
        var blocked: [EchoLiveMemoryRecoveryBlockedRecord] = []
        switch followUpScan.status {
        case .valid, .absent:
            break
        case .unreadable:
            blocked.append(EchoLiveMemoryRecoveryBlockedRecord(
                productSessionID: "follow-up-store",
                reason: .followUpUnreadable
            ))
        case .decodeInvalid:
            blocked.append(EchoLiveMemoryRecoveryBlockedRecord(
                productSessionID: "follow-up-store",
                reason: .followUpDecodeInvalid
            ))
        case .schemaUnsupported:
            blocked.append(EchoLiveMemoryRecoveryBlockedRecord(
                productSessionID: "follow-up-store",
                reason: .followUpSchemaUnsupported
            ))
        case .scopeMismatch:
            blocked.append(EchoLiveMemoryRecoveryBlockedRecord(
                productSessionID: "follow-up-store",
                reason: .followUpScopeMismatch
            ))
        }
        var checkpointsByID: [String: [EchoLiveMemoryCompletionCheckpoint]] = [:]
        var followUpsByID: [String: [EchoLiveMemoryFollowUpRecord]] = [:]
        checkpoints.forEach { checkpointsByID[$0.productSessionID, default: []].append($0) }
        followUps.forEach { followUpsByID[$0.productSessionID, default: []].append($0) }

        let workflowIDs = Set(checkpointsByID.keys).union(followUpsByID.keys).sorted()
        for productSessionID in workflowIDs where discoveredIDs.insert(productSessionID).inserted {
            let workflowCheckpoints = checkpointsByID[productSessionID] ?? []
            let workflowFollowUps = followUpsByID[productSessionID] ?? []
            let checkpoint = workflowCheckpoints.sorted { $0.updatedAt > $1.updatedAt }.first
            sceneCreatedAt[productSessionID] = outboxes.first(where: {
                $0.productSessionID == productSessionID
            })?.createdAt ?? checkpoint?.createdAt ?? workflowFollowUps.map(\.createdAt).min()
            let checkpointBatchID: OwnerTruthRecordID? = {
                guard let checkpoint else { return nil }
                switch checkpoint.phase {
                case .endPrepared, .ended:
                    return nil
                case .acknowledgementPrepared:
                    return checkpoint.acknowledgementCommand?.reviewBatchID
                case .acknowledged:
                    return checkpoint.acknowledgementReceipt?.reviewBatchID
                case .admissionPrepared:
                    return checkpoint.admissionCommand?.reviewBatchID
                case .admitted:
                    return checkpoint.admittedReviewBatchID
                }
            }()
            let checkpointThreadID = checkpoint?.endReceipt?.threadID
                ?? checkpoint?.acknowledgementCommand?.threadID
                ?? checkpoint?.acknowledgementReceipt?.threadID
                ?? checkpoint?.endCommand?.threadID
            let checkpointSessionID = checkpoint?.endReceipt?.sessionID
                ?? checkpoint?.acknowledgementCommand?.sessionID
                ?? checkpoint?.acknowledgementReceipt?.sessionID
                ?? checkpoint?.endCommand?.sessionID
            let followUpBatchIDs = Set(workflowFollowUps.map {
                OwnerTruthRecordID(rawValue: $0.reviewBatchID)
            })
            let allBatchIDs = followUpBatchIDs.union(checkpointBatchID.map { [$0] } ?? [])
            guard allBatchIDs.count <= 1 else {
                blocked.append(EchoLiveMemoryRecoveryBlockedRecord(
                    productSessionID: productSessionID,
                    reason: .bindingMismatch
                ))
                continue
            }
            var sources: Set<EchoLiveMemoryRecoveryPlanSource> = []
            if checkpoint != nil { sources.insert(.completionCheckpoint) }
            if !workflowFollowUps.isEmpty { sources.insert(.followUp) }
            if outboxes.contains(where: { $0.productSessionID == productSessionID }) {
                sources.insert(.liveTurnOutbox)
            }
            let revisionMaterial = [
                productSessionID,
                checkpoint?.phase.rawValue ?? "none",
                checkpoint?.updatedAt.timeIntervalSince1970.description ?? "none",
                workflowFollowUps.map { $0.updatedAt.timeIntervalSince1970.description }
                    .sorted().joined(separator: ","),
            ].joined(separator: "|")
            let plan = EchoLiveMemoryRecoveryPlan(
                accountLease: accountLease,
                productSessionID: productSessionID,
                threadID: checkpointThreadID,
                sessionID: checkpointSessionID,
                reviewBatchID: allBatchIDs.first,
                checkpointPhase: checkpoint?.phase,
                sources: sources,
                localRecordRevision: PrivacySafeDiagnostics.correlationHash(revisionMaterial)
            )
            PrivacySafeDiagnostics.log(
                subsystem: "EchoLiveMemoryRecovery",
                event: "planMerged",
                states: [
                    "phase": checkpoint?.phase.rawValue ?? "followUpOnly",
                    "hasBatch": plan.reviewBatchID == nil ? "false" : "true",
                ],
                counts: ["sourceCount": sources.count],
                correlations: [
                    "workflow": PrivacySafeDiagnostics.correlationHash(productSessionID),
                ]
            )
            let observationRecorder: ((
                EchoLiveMemoryRecoveryObservation,
                String,
                OwnerTruthRecordID,
                AccountLease
            ) throws -> Void)? = workflowFollowUps.isEmpty ? nil : {
                observation, productSessionID, reviewBatchID, lease in
                try followUpStore.recordRecoveryObservation(
                    observation,
                    productSessionID: productSessionID,
                    reviewBatchID: reviewBatchID,
                    for: lease
                )
            }
            coordinators.append(registry.coordinator(
                for: plan,
                client: client,
                accountLeaseRuntime: accountLeaseRuntime,
                organizationStatusTimeout: organizationStatusTimeout,
                candidateReviewPolicyAvailable: candidateReviewPolicyAvailable,
                completionObservationRecorder: observationRecorder,
                now: now,
                schedule: schedule
            ))
        }

        for snapshot in outboxes
        where !checkpointIDs.contains(snapshot.productSessionID)
            && !followUpIDs.contains(snapshot.productSessionID)
            && discoveredIDs.insert(snapshot.productSessionID).inserted {
            let scan = completionCheckpointStore.scan(
                productSessionID: snapshot.productSessionID,
                for: accountLease
            )
            let reason: EchoLiveMemoryRecoveryBlockReason
            switch scan.status {
            case .valid:
                // A valid record may have appeared between enumeration and
                // this per-workflow scan. Leave it for the next bounded pass.
                continue
            case .absent:
                if snapshot.isClosing,
                   let start = snapshot.preparedStartCommand,
                   start.entryMode == .live,
                   start.productSessionID == snapshot.productSessionID,
                   snapshot.startDispatchState != nil {
                    let plan = EchoLiveMemoryRecoveryPlan(
                        accountLease: accountLease,
                        productSessionID: snapshot.productSessionID,
                        threadID: start.threadID,
                        sessionID: start.sessionID,
                        reviewBatchID: nil,
                        checkpointPhase: nil,
                        sources: [.liveTurnOutbox],
                        localRecordRevision: PrivacySafeDiagnostics.correlationHash(
                            [snapshot.productSessionID, start.commandID,
                             snapshot.updatedAt.timeIntervalSince1970.description]
                                .joined(separator: "|")
                        ),
                        deliveryStartCommand: start,
                        deliveryFromSequence: snapshot.pendingTurns.map(\.clientSequenceNumber).min() ?? 1,
                        deliveryWatermark: snapshot.closeRequestedLastClientSequenceNumber
                            ?? snapshot.lastClientSequenceNumber,
                        deliveryPendingTurns: snapshot.pendingTurns
                    )
                    sceneCreatedAt[snapshot.productSessionID] = snapshot.createdAt
                    coordinators.append(registry.coordinator(
                        for: plan,
                        client: client,
                        accountLeaseRuntime: accountLeaseRuntime,
                        organizationStatusTimeout: organizationStatusTimeout,
                        candidateReviewPolicyAvailable: candidateReviewPolicyAvailable,
                        now: now,
                        schedule: schedule
                    ))
                    continue
                }
                reason = snapshot.isClosing
                    ? .closingOutboxMissingCheckpoint
                    : .unclosedLegacySession
            case .unreadable:
                reason = .checkpointUnreadable
            case .decodeInvalid:
                reason = .checkpointDecodeInvalid
            case .schemaUnsupported:
                reason = .checkpointSchemaUnsupported
            case .scopeMismatch:
                reason = .checkpointScopeMismatch
            }
            blocked.append(EchoLiveMemoryRecoveryBlockedRecord(
                productSessionID: snapshot.productSessionID,
                reason: reason
            ))
            sceneCreatedAt[snapshot.productSessionID] = snapshot.createdAt
        }

        PrivacySafeDiagnostics.log(
            subsystem: "EchoLiveMemoryRecovery",
            event: "scanCompleted",
            states: ["result": "finished"],
            counts: [
                "planCount": coordinators.count,
                "blockedCount": blocked.count,
            ]
        )
        coordinators.sort { lhs, rhs in
            let left = sceneCreatedAt[lhs.trackedProductSessionID]
            let right = sceneCreatedAt[rhs.trackedProductSessionID]
            if let left, let right, left != right { return left > right }
            if left != nil || right != nil { return left != nil }
            return lhs.trackedProductSessionID < rhs.trackedProductSessionID
        }
        let hasMissingTime = coordinators.contains {
            sceneCreatedAt[$0.trackedProductSessionID] == nil
        }
        let topTimeIsTied = coordinators.count > 1
            && sceneCreatedAt[coordinators[0].trackedProductSessionID]
                == sceneCreatedAt[coordinators[1].trackedProductSessionID]
        if hasMissingTime || topTimeIsTied {
            blocked += coordinators.map {
                EchoLiveMemoryRecoveryBlockedRecord(
                    productSessionID: $0.trackedProductSessionID,
                    reason: .ambiguousSceneOrder
                )
            }
            coordinators.removeAll()
        }
        let allSceneIDs = Set(coordinators.map(\.trackedProductSessionID))
            .union(blocked.map(\.productSessionID))
        let orderedScenes = allSceneIDs.compactMap { id -> (String, Date)? in
            guard let createdAt = sceneCreatedAt[id] else { return nil }
            return (id, createdAt)
        }.sorted { $0.1 > $1.1 }
        let presentationBlockedRecord: EchoLiveMemoryRecoveryBlockedRecord?
        if orderedScenes.count != allSceneIDs.count
            || (orderedScenes.count > 1 && orderedScenes[0].1 == orderedScenes[1].1) {
            presentationBlockedRecord = EchoLiveMemoryRecoveryBlockedRecord(
                productSessionID: "ambiguous-scene", reason: .ambiguousSceneOrder
            )
        } else if let newestID = orderedScenes.first?.0 {
            presentationBlockedRecord = blocked.first { $0.productSessionID == newestID }
        } else {
            presentationBlockedRecord = nil
        }
        return EchoLiveMemoryRecoveryResult(
            coordinators: coordinators,
            blockedRecords: blocked,
            presentationBlockedRecord: presentationBlockedRecord
        )
    }
}

final class EchoViewController: UIViewController {
    private static let echoTurnKnowledgeTimeout: TimeInterval = 0.9

    private let viewModel: EchoViewModel
    private let accountLeaseRuntime = AccountLeaseRuntime.shared
    private let digitalHumanSessionClient: DigitalHumanSessionClientPort
    #if DEBUG
    private var skipAncillaryVoiceCloneFetchForTesting = false
    private var realtimeVoiceLaunchClientForTesting: DreamJourneyBackendClient?
    private var voicePermissionRequestForTesting: ((@escaping (Bool) -> Void) -> Void)?
    private var voiceSDKConfigureForTesting: ((RealtimeVoiceRuntimeConfig) -> Bool)?
    private var voiceSDKStartForTesting: ((@escaping () -> Void) -> Void)?
    private var voiceDelegateEventSchedulerForTesting: ((@escaping () -> Void) -> Void)?
    private var voiceLaunchCaptureFactoryForTesting:
        ((AccountLease, String?) -> EchoLiveMemoryCaptureCoordinator)?
    private var voiceAudioPreparationForTesting: (() -> Bool)?
    private var skipVoiceLaunchMemoryCaptureForTesting = false
    private var voiceListeningCompletionForTesting: (() -> Void)?
    private var voiceLaunchTerminalCompletionForTesting: ((String) -> Void)?
    private var voiceLaunchDiagnosticStoreForTesting: EchoVoiceLaunchDiagnosticStore?
    #endif
    private let dialogEngineOwnerId = UUID()
    private var echoAccountLease: AccountLease?
    private var dialogEngineBindingHandle: DialogEngineBindingHandle?
    private var activeVoiceLaunchAttempt: EchoVoiceLaunchAttempt?
    #if DEBUG
    private var voiceLaunchTimeoutForTesting: TimeInterval?
    private var voiceLaunchClockForTesting: (() -> TimeInterval)?
    private var voiceLaunchSchedulerForTesting: ((TimeInterval, DispatchWorkItem) -> Void)?
    #endif

    private let scenicView = EchoScenicParkView()
    private var digitalHumanLivePanelView: DigitalHumanLivePanelView?
    private var digitalHumanAudioLevelMeter: DigitalHumanAudioLevelMeter?
    private var digitalHumanRuntime: DigitalHumanRuntime?
    private var voiceCloneRuntimeCapability: VoiceCloneRuntimeCapability?
    private var isLoadingVoiceCloneRuntimeCapability = false
    private var lastTencentProviderAudioHandoffAt: Date?
    private var currentEchoAudioOwner: EchoDigitalHumanAudioOwner = .volcengineLocalTTS
    private var activeEchoAudioOwnerLease: AudioOwnerLease?
    private var audioSessionCoordinator = AudioSessionCoordinator.shared
    private var lastEchoTraceRecord: EchoTraceRecord?
    private let echoApplicationCoordinator = EchoApplicationCoordinator()
    private var activeEchoTurnKnowledgeContextGate: EchoTurnKnowledgeContextGate?
    private var lastVoiceCloneProviderLogId: String?
    private var lastVoiceCloneProviderRequestId: String?
    private var lastVoiceCloneProviderMode: String?
    private var lastEchoRuntimeFallbackReason: String?
    private var lastDigitalHumanSessionEvidenceSummary: EchoDigitalHumanSessionEvidenceSummary?
    private var lastVoiceSynthesisEvidenceSummary: EchoVoiceSynthesisEvidenceSummary?
    private var lastOwnerTruthContextCitationEvidence: OwnerTruthContextCitationQAEvidenceReadout?
    private var lastEchoAnswerGroundingEvidence: EchoAnswerGroundingQAEvidence?
    private var lastOwnerTruthContextParityEvidence: EchoOwnerTruthContextParityQAEvidenceReadout?
    private var lastOwnerTruthContextCompareEvidence: EchoOwnerTruthContextShadowCompareQAEvidenceReadout?
    private var trueDeviceBackendPCMDriveTrace = TencentBackendPCMDriveTrueDeviceTrace()
    private var digitalHumanRuntimeContextKey: String?
    private var digitalHumanRuntimeLifecycleGeneration: UInt64?
    private var activeDigitalHumanSessionContract: DigitalHumanSessionContract?
    private var activeDigitalHumanSessionAccountLease: AccountLease?
    private var deferredDigitalHumanSessionReleases: [DeferredDigitalHumanSessionRelease] = []
    private var pendingDigitalHumanSessionRequestID: String?
    private var pendingDigitalHumanSessionContextKey: String?

    private let personaBadgeView: UIView = {
        let view = UIView()
        view.backgroundColor = UIColor(hex: "#FEFEF9").withAlphaComponent(0.9)
        view.layer.cornerRadius = 22
        view.layer.borderWidth = 1
        view.layer.borderColor = DJDesignTokens.Color.divider.withAlphaComponent(0.18).cgColor
        DJDesignTokens.applySoftShadow(to: view)
        return view
    }()

    private let messageCenterBellButton = InAppMessageBellButton(type: .system)

    private let personaAvatarView: UIView = {
        let view = UIView()
        view.backgroundColor = DJDesignTokens.Color.accent.withAlphaComponent(0.14)
        view.layer.cornerRadius = 20
        view.layer.masksToBounds = true
        return view
    }()

    private let personaIconView: UIImageView = {
        let imageView = UIImageView()
        imageView.tintColor = DJDesignTokens.Color.accentDeep
        imageView.contentMode = .scaleAspectFit
        return imageView
    }()

    private let personaNameLabel: UILabel = {
        let label = UILabel()
        label.font = DJDesignTokens.Font.title(15)
        label.textColor = DJDesignTokens.Color.textPrimary
        label.numberOfLines = 1
        return label
    }()

    private let personaSubtitleLabel: UILabel = {
        let label = UILabel()
        label.font = DJDesignTokens.Font.label(11)
        label.textColor = DJDesignTokens.Color.textTertiary
        label.numberOfLines = 1
        return label
    }()

    private let quoteBubble: UIView = {
        let view = UIView()
        view.backgroundColor = UIColor(hex: "#FEFEF9").withAlphaComponent(0.92)
        view.layer.cornerRadius = 18
        view.layer.maskedCorners = [
            .layerMinXMinYCorner,
            .layerMaxXMinYCorner,
            .layerMaxXMaxYCorner,
            .layerMinXMaxYCorner
        ]
        view.layer.borderWidth = 1
        view.layer.borderColor = DJDesignTokens.Color.divider.withAlphaComponent(0.18).cgColor
        DJDesignTokens.applySoftShadow(to: view)
        return view
    }()

    private let quoteLabel = EchoReplyTextView()
    private let cloudOrb = EchoCloudOrbView()
    #if DEBUG
    private(set) var orbAudioSampleForTesting: DialogOrbAudioSample?
    #endif
    private let conversationContent = UIScrollView()
    private var cloudOrbHeightConstraint: NSLayoutConstraint?
    private let composer = EchoComposerView()
    private let expandReplyButton = UIButton(type: .system)
    private let showMemoriesButton = UIButton(type: .system)
    private let finishTextButton = UIButton(type: .system)
    private var micCenterConstraint: NSLayoutConstraint?
    private var micTrailingConstraint: NSLayoutConstraint?
    private var presentationVisible = false
    private var keyboardOverlap: CGFloat = 0
    private var publicationObservers: [String: EchoPublicationObserver] = [:]
    private var observedPublicationSessionID: String?
    private var publicationDiscoveryTimer: DispatchWorkItem?
    private var publicationDiscoveryInFlight = false
    private var lastOrganizationPresentation: EchoOrganizationPresentation?
    private let presentationPersistenceQueue = DispatchQueue(label: "echo.presentation.progress", qos: .utility)
    private weak var conversationSheet: UIViewController?
    private weak var conversationSheetText: UITextView?

    private let archiveContextStatusView: UIView = {
        let archiveContextStatusView = UIView()
        archiveContextStatusView.backgroundColor = UIColor(hex: "#FEFEF9").withAlphaComponent(0.9)
        archiveContextStatusView.layer.cornerRadius = 16
        archiveContextStatusView.layer.borderWidth = 1
        archiveContextStatusView.layer.borderColor = DJDesignTokens.Color.accentDeep.withAlphaComponent(0.16).cgColor
        archiveContextStatusView.isHidden = true
        archiveContextStatusView.alpha = 0
        archiveContextStatusView.isAccessibilityElement = false
        DJDesignTokens.applySoftShadow(to: archiveContextStatusView)
        return archiveContextStatusView
    }()

    private let archiveContextStatusLabel: UILabel = {
        let label = UILabel()
        label.text = "档案线索正在参与回响"
        label.font = DJDesignTokens.Font.label(13)
        label.textColor = DJDesignTokens.Color.accentDeep
        label.numberOfLines = 1
        label.accessibilityIdentifier = "echoArchiveContextStatus"
        label.accessibilityLabel = "档案线索正在参与回响"
        return label
    }()

    private let digitalHumanStatusView: UIView = {
        let view = UIView()
        view.backgroundColor = UIColor(hex: "#FEFEF9").withAlphaComponent(0.88)
        view.layer.cornerRadius = 16
        view.layer.borderWidth = 1
        view.layer.borderColor = DJDesignTokens.Color.divider.withAlphaComponent(0.16).cgColor
        view.clipsToBounds = true
        DJDesignTokens.applySoftShadow(to: view)
        return view
    }()

    private let digitalHumanStatusTitleLabel: UILabel = {
        let label = UILabel()
        label.text = "数字人回响"
        label.font = DJDesignTokens.Font.title(13)
        label.textColor = DJDesignTokens.Color.textPrimary
        label.numberOfLines = 1
        label.accessibilityIdentifier = "echoDigitalHumanStatusTitle"
        return label
    }()

    private let digitalHumanStatusDetailLabel: UILabel = {
        let label = UILabel()
        label.text = "素材已授权，无法加载时自动回到普通回响"
        label.font = DJDesignTokens.Font.label(11)
        label.textColor = DJDesignTokens.Color.textTertiary
        label.numberOfLines = 1
        label.accessibilityIdentifier = "echoDigitalHumanStatusDetail"
        return label
    }()

    private let voiceStatusView: UIView = {
        let view = UIView()
        view.backgroundColor = UIColor(hex: "#FEFEF9").withAlphaComponent(0.84)
        view.layer.cornerRadius = 16
        view.layer.borderWidth = 1
        view.layer.borderColor = DJDesignTokens.Color.divider.withAlphaComponent(0.16).cgColor
        view.clipsToBounds = true
        view.isHidden = true
        view.alpha = 0
        DJDesignTokens.applySoftShadow(to: view)
        return view
    }()

    private let voiceStatusLabel: UILabel = {
        let label = UILabel()
        label.text = "轻点话筒，慢慢说给我听"
        label.font = DJDesignTokens.Font.label(13)
        label.textColor = DJDesignTokens.Color.textSecondary
        label.textAlignment = .center
        label.numberOfLines = 1
        label.accessibilityIdentifier = "echoVoiceStatus"
        return label
    }()

    private let echoRuntimeDiagnosticsPanelView: UIView = {
        let view = UIView()
        view.backgroundColor = UIColor(hex: "#17120B").withAlphaComponent(0.72)
        view.layer.cornerRadius = 12
        view.layer.borderWidth = 1
        view.layer.borderColor = UIColor.white.withAlphaComponent(0.16).cgColor
        view.clipsToBounds = true
        view.isHidden = true
        view.alpha = 0
        view.accessibilityIdentifier = "echoRuntimeDiagnosticsPanel"
        return view
    }()

    private let echoRuntimeDiagnosticsPanelLabel: UILabel = {
        let label = UILabel()
        label.font = .monospacedSystemFont(ofSize: 10, weight: .medium)
        label.textColor = UIColor.white.withAlphaComponent(0.9)
        label.numberOfLines = 0
        label.lineBreakMode = .byWordWrapping
        label.accessibilityIdentifier = "echoRuntimeDiagnosticsPanelLabel"
        return label
    }()

    private let echoRuntimeDiagnosticsScrollView: UIScrollView = {
        let scrollView = UIScrollView()
        scrollView.alwaysBounceVertical = true
        scrollView.showsVerticalScrollIndicator = true
        scrollView.accessibilityIdentifier = "echoRuntimeDiagnosticsScrollView"
        return scrollView
    }()

    private lazy var echoTraceEvidenceExportButton: UIButton = {
        let button = UIButton(type: .system)
        button.setTitle("导出证据包", for: .normal)
        button.titleLabel?.font = DJDesignTokens.Font.label(11)
        button.setTitleColor(.white, for: .normal)
        button.backgroundColor = DJDesignTokens.Color.accentDeep.withAlphaComponent(0.84)
        button.layer.cornerRadius = 11
        button.clipsToBounds = true
        button.accessibilityIdentifier = "echoTraceEvidenceExportButton"
        button.addTarget(self, action: #selector(exportEchoTraceEvidencePackageTapped), for: .touchUpInside)
        return button
    }()

    private lazy var micButton: UIButton = {
        let button = UIButton(type: .custom)
        button.backgroundColor = DJDesignTokens.Color.accentDeep
        button.tintColor = .white
        button.layer.cornerRadius = 28
        button.layer.shadowColor = DJDesignTokens.Color.accentDeep.cgColor
        button.layer.shadowOpacity = 0.24
        button.layer.shadowOffset = CGSize(width: 0, height: 10)
        button.layer.shadowRadius = 18
        button.addTarget(self, action: #selector(micTapped), for: .touchUpInside)
        button.accessibilityLabel = "开始语音"
        return button
    }()

    /// Kept out of every public build. This lets QA exercise the planned M0-A
    /// natural-input surface without changing the released full-screen Echo.
    private lazy var ownerTruthInterviewNaturalInputEntryButton: UIButton = {
        var configuration = UIButton.Configuration.filled()
        configuration.image = UIImage(systemName: "keyboard")
        configuration.baseBackgroundColor = DJDesignTokens.Color.surface.withAlphaComponent(0.94)
        configuration.baseForegroundColor = DJDesignTokens.Color.accentDeep
        configuration.cornerStyle = .capsule
        configuration.contentInsets = NSDirectionalEdgeInsets(top: 8, leading: 8, bottom: 8, trailing: 8)
        let button = UIButton(configuration: configuration)
        button.layer.shadowColor = UIColor.black.cgColor
        button.layer.shadowOpacity = 0.08
        button.layer.shadowOffset = CGSize(width: 0, height: 4)
        button.layer.shadowRadius = 8
        button.accessibilityLabel = "打开自然输入（QA）"
        button.accessibilityIdentifier = "ownerTruthInterviewNaturalInputEntryButton"
        button.addTarget(self, action: #selector(ownerTruthInterviewNaturalInputEntryTapped), for: .touchUpInside)
        return button
    }()

    /// The product entry starts hidden and is shown only after a fresh
    /// release-policy decision permits an Echo text turn.
    private lazy var ownerTruthInterviewNaturalInputProductEntryButton: UIButton = {
        var configuration = UIButton.Configuration.filled()
        configuration.title = "文字回响"
        configuration.image = UIImage(systemName: "keyboard")
        configuration.imagePadding = 8
        configuration.baseBackgroundColor = DJDesignTokens.Color.surface.withAlphaComponent(0.94)
        configuration.baseForegroundColor = DJDesignTokens.Color.accentDeep
        configuration.cornerStyle = .capsule
        configuration.contentInsets = NSDirectionalEdgeInsets(
            top: 10,
            leading: 16,
            bottom: 10,
            trailing: 18
        )
        let button = UIButton(configuration: configuration)
        button.titleLabel?.font = DJDesignTokens.Font.label(14)
        button.layer.shadowColor = UIColor.black.cgColor
        button.layer.shadowOpacity = 0.08
        button.layer.shadowOffset = CGSize(width: 0, height: 4)
        button.layer.shadowRadius = 8
        button.isHidden = true
        button.alpha = 0
        button.accessibilityLabel = "输入文字开始回响"
        button.accessibilityIdentifier = "ownerTruthInterviewNaturalInputProductEntryButton"
        button.addTarget(
            self,
            action: #selector(ownerTruthInterviewNaturalInputProductEntryTapped),
            for: .touchUpInside
        )
        return button
    }()

    private let micRingView: UIView = {
        let view = UIView()
        view.backgroundColor = DJDesignTokens.Color.accentDeep.withAlphaComponent(0.12)
        view.layer.cornerRadius = 38
        view.alpha = 0
        view.isUserInteractionEnabled = false
        return view
    }()

    private var micButtonBottomConstraint: NSLayoutConstraint?
    private var voiceStatusHeightConstraint: NSLayoutConstraint?
    private var quoteBubbleBottomToVoiceStatusConstraint: NSLayoutConstraint?
    private var quoteBubbleBottomToNaturalInputConstraint: NSLayoutConstraint?
    private var isOwnerTruthInterviewNaturalInputProductPolicyPermitted = false
    private var ownerTruthInterviewNaturalInputPolicyRefreshGeneration: UInt = 0
    private var pendingMemoryGapHandoff: EchoMemoryGapHandoff?
    private var currentState: EchoInteractionState = .idle
    private var currentLiveMemoryCapturePresentationState: EchoLiveMemoryCaptureState?
    private var currentLiveMemoryPartialPublication = false
    private var currentLiveMemoryCoverageSummary = OwnerTruthInterviewCanonicalCoverageSummary.empty
    private var currentLiveMemoryCapturePresentationCoordinatorID: UUID?
    private var transcriptEntries: [(text: String, isUser: Bool)] = []
    private var recentEchoConversation = EchoRecentConversationBuffer()
    private var pendingAIText: String? {
        didSet {
            if let text = pendingAIText, !text.isEmpty, isViewLoaded {
                quoteLabel.text = text
                refreshConversationSheet()
            }
        }
    }
    private var digitalHumanReplyPrewarmWorkItem: DispatchWorkItem?
    private var digitalHumanProviderTextOverTimeoutWorkItem: DispatchWorkItem?
    private var digitalHumanRuntimeRecoveryWorkItem: DispatchWorkItem?
    private var digitalHumanBackgroundReleaseWorkItem: DispatchWorkItem?
    private var digitalHumanSessionHeartbeatWorkItem: DispatchWorkItem?
    private var digitalHumanSessionHeartbeatFailureCount = 0
    private var digitalHumanRuntimeRecoveryAttemptsByContext: [String: Int] = [:]
    private let digitalHumanConversation = DigitalHumanConversationCoordinator()
    private let digitalHumanLifecycle = DigitalHumanLifecycleCoordinator()
    private let echoRuntimeSessionCoordinator = EchoRuntimeSessionCoordinator()
    private var activeVoiceInteractionLifecycleToken: DigitalHumanLifecycleToken?
    private var echoTextReplyLifecycleToken: DigitalHumanLifecycleToken?
    private var echoTextReplySpeechRequestID: UUID?
    private var hasRunTencentDigitalHumanTextDriveSmoke = false
    private var hasRunTencentDigitalHumanPCMDriveSmoke = false
    private var hasRunTencentDigitalHumanBackendPCMDriveSmoke = false
    private var isStoppingForDelayedReply = false
    private var isStoppingForNeutralSafety = false
    private var isStoppingVoiceCaptureManually = false
    private var isUserControlledLiveSessionOpen = false {
        didSet {
            if isUserControlledLiveSessionOpen && !oldValue {
                transcriptEntries.removeAll()
                quoteLabel.beginReply()
                quoteLabel.text = nil
                composer.field.resignFirstResponder()
            }
            if isViewLoaded { updateOwnerTruthInterviewNaturalInputProductEntryVisibility() }
            if !isUserControlledLiveSessionOpen {
                cancelLiveSessionLimit()
                cancelLiveUserInactivityTimeout()
                cancelLivePlaybackReceipt(reason: "liveSessionClosed")
                activeLiveAudioRouteLease = nil
                liveProductSessionID = nil
                recentEchoConversation.reset()
            }
        }
    }
    /// The business-level Live conversation stays open while an underlying
    /// recorder/provider transport is recoverable. The next mic tap resumes
    /// transport instead of accidentally committing the whole conversation.
    private var isLiveVoiceTransportSuspended = false
    /// Stable product-level identity reused when a provider connection is
    /// rebuilt. It is cleared only when the user closes the Live session.
    private var liveProductSessionID: String?
    private var activeLiveAudioRouteLease: EchoLiveAudioRouteLease?
    private var pendingLivePlaybackReceipt: EchoLivePlaybackReceipt?
    private var livePlaybackAcceptanceTimeoutWorkItem: DispatchWorkItem?
    private var livePlaybackTerminalWatchdogWorkItem: DispatchWorkItem?
    private var liveMemoryCaptureCoordinator: EchoLiveMemoryCaptureCoordinator?
    private var recoveryUserUtteranceActive = false
    private var recoveryGracefulStopCoordinatorID: UUID?
    private var recoveryGracefulStopDeadline: Date?
    private var recoveryGracefulStopTimer: DispatchWorkItem?

    private let canonicalTranscriptIngressLock = NSLock()
    private var canonicalTranscriptIngress: EchoCanonicalTranscriptIngress?
    private var canonicalTranscriptDeliveryScheduler: EchoCanonicalTranscriptIngress.DeliveryScheduler = {
        delivery in
        if Thread.isMainThread {
            delivery()
        } else {
            DispatchQueue.main.async(execute: delivery)
        }
    }
    private var retainedLiveMemoryCaptureCoordinators: [UUID: EchoLiveMemoryCaptureCoordinator] = [:]
    private var retainedLiveMemoryRecoveryCoordinators: [UUID: EchoLiveMemoryRecoveryCoordinator] = [:]
    private var liveMemoryRecoverySubscriptionTokens: [UUID: UUID] = [:]
    private weak var activeLiveMemoryRecoveryCoordinator: EchoLiveMemoryRecoveryCoordinator?
    private var presentedLiveMemoryProductSessionID: String?
    private var presentedLiveMemoryAccountLease: AccountLease?
    private var liveSessionLimit = EchoLiveSessionLimit()
    private var liveSessionLimitTimer: DispatchWorkItem?
    private var liveSessionLimitIdentity = UUID()
    private var liveLimitAwaitingReply = false
    private var liveFarewellSpeaker: EchoLiveFarewellSpeaker?
    private var liveLimitPauseForTesting: (() -> Bool)?
    private var liveLimitPlaybackForTesting: ((String, @escaping () -> Void) -> Void)?
    private var isLiveFarewellActive: Bool { liveSessionLimit.farewellAt != nil && !liveSessionLimit.closed }
    private var liveUserInactivityWorkItem: DispatchWorkItem?
    private var liveUserInactivityGeneration: UInt64 = 0
    private var showsVoiceSDKReadinessPreview = false
    private var backendRuntimeTokenApplied = false
    private var hasRequestedCloudDigitalHumanRuntime = false
    private var isSuspendedByAppLifecycle = false
    private var isStoppingVoiceCaptureForAppLifecycle = false
    private static let digitalHumanReplyPrewarmShortDelay: TimeInterval = 0.18
    private static let digitalHumanReplyPrewarmDebounceDelay: TimeInterval = 0.24
    private static let tencentDigitalHumanTextOverTimeout: TimeInterval = 30
    private static let tencentDigitalHumanPostTextOverResumeDelay: TimeInterval = 1.2
    private static let tencentDigitalHumanLongReplyExtraResumeDelay: TimeInterval = 0.6
    private static let tencentDigitalHumanLongReplyCharacterThreshold = 56
    private static let tencentDigitalHumanPCMDriveChunkDuration: TimeInterval = 0.02
    private static let tencentDigitalHumanPCMDriveStartDelay: TimeInterval = 0.12
    private static let tencentDigitalHumanPCMDrivePrerollDuration: TimeInterval = 0.16
    private static let tencentDigitalHumanPCMDriveTailSilenceDuration: TimeInterval = 0.08
    private static let tencentDigitalHumanPCMDriveFadeDuration: TimeInterval = 0.06
    private static let tencentDigitalHumanPCMDriveStopProbeDelay: TimeInterval = 1.6
    private static let tencentProviderDialogErrorSuppressionWindow: TimeInterval = 3.0
    private static let tencentDigitalHumanContextSwitchReconnectDelay: TimeInterval = 1.4
    private static let tencentDigitalHumanOpenFailureRecoveryDelay: TimeInterval = 2.0
    private static let tencentDigitalHumanOpenFailureRecoveryLimit = 1
    private static let tencentDigitalHumanBackgroundReleaseGracePeriod: TimeInterval = 8.0
    private static let liveUserInactivityTimeout: TimeInterval = 60
    private static let livePlaybackProviderAcceptanceTimeout: TimeInterval = 6.0
    private static let livePlaybackTerminalWatchdogTimeout: TimeInterval = 45.0

    private var isTypedEchoConversationOpen: Bool {
        liveMemoryCaptureCoordinator != nil && !isUserControlledLiveSessionOpen
    }

    private struct TencentPCMDriveTestSignal {
        let data: Data
        let sampleRate: Int
        let bitsPerSample: Int
        let channelCount: Int
        let formatDescription: String

        var chunkSize: Int {
            max(
                2,
                Int(Double(sampleRate * channelCount * (bitsPerSample / 8)) * EchoViewController.tencentDigitalHumanPCMDriveChunkDuration)
            )
        }

        var preparedByteCount: Int {
            preparedAudioDrivePCMData().count
        }

        var chunkCount: Int {
            Int(ceil(Double(preparedByteCount) / Double(chunkSize)))
        }

        func chunks() -> [Data] {
            let payload = preparedAudioDrivePCMData()
            var chunks: [Data] = []
            var offset = 0
            while offset < payload.count {
                let end = min(payload.count, offset + chunkSize)
                chunks.append(payload.subdata(in: offset..<end))
                offset = end
            }
            return chunks
        }

        func preparedAudioDrivePCMData() -> Data {
            let stripped = strippedRIFFHeaderIfNeeded(data)
            guard bitsPerSample == 16, stripped.count >= MemoryLayout<Int16>.size * 4 else {
                return stripped
            }

            let aligned = stripped.count % 2 == 0 ? stripped : stripped.dropLast()
            var smoothed = Data(aligned)
            smoothed.withUnsafeMutableBytes { rawBuffer in
                guard let base = rawBuffer.baseAddress else { return }
                let sampleCount = rawBuffer.count / MemoryLayout<Int16>.size
                let samples = base.bindMemory(to: Int16.self, capacity: sampleCount)
                let fadeSampleCount = min(
                    max(Int(Double(sampleRate) * EchoViewController.tencentDigitalHumanPCMDriveFadeDuration), 1),
                    sampleCount / 3
                )
                guard fadeSampleCount > 1 else { return }

                for index in 0..<fadeSampleCount {
                    let factor = Double(index) / Double(fadeSampleCount)
                    let value = Int16(littleEndian: samples[index])
                    let scaled = Int16(Double(value) * factor)
                    samples[index] = scaled.littleEndian
                }

                for index in 0..<fadeSampleCount {
                    let sampleIndex = sampleCount - 1 - index
                    let factor = Double(index) / Double(fadeSampleCount)
                    let value = Int16(littleEndian: samples[sampleIndex])
                    let scaled = Int16(Double(value) * factor)
                    samples[sampleIndex] = scaled.littleEndian
                }
            }

            let bytesPerSecond = sampleRate * channelCount * (bitsPerSample / 8)
            let silenceByteCount = alignedPCMByteCount(
                Int(Double(bytesPerSecond) * EchoViewController.tencentDigitalHumanPCMDrivePrerollDuration)
            )
            let tailSilenceByteCount = alignedPCMByteCount(
                Int(Double(bytesPerSecond) * EchoViewController.tencentDigitalHumanPCMDriveTailSilenceDuration)
            )
            var prepared = Data(repeating: 0, count: silenceByteCount)
            prepared.append(smoothed)
            prepared.append(Data(repeating: 0, count: tailSilenceByteCount))
            return prepared
        }

        private func strippedRIFFHeaderIfNeeded(_ payload: Data) -> Data {
            guard payload.count > 44,
                  payload.prefix(4) == Data("RIFF".utf8),
                  let dataRange = payload.range(of: Data("data".utf8)) else {
                return payload
            }
            let dataSizeStart = dataRange.upperBound
            let dataStart = dataSizeStart + 4
            guard dataStart <= payload.count else {
                return payload
            }
            return payload.subdata(in: dataStart..<payload.count)
        }

        private func alignedPCMByteCount(_ count: Int) -> Int {
            let frameSize = max(2, channelCount * (bitsPerSample / 8))
            return max(0, count - (count % frameSize))
        }
    }

    private var shouldShowDigitalHumanLivePanel: Bool {
        if isDigitalHumanQADisableEnabled {
            return false
        }
        if isDigitalHumanQAOverrideEnabled {
            return FeatureGateService.shared.isRouteAllowed(
                .digitalHumanLivePanel,
                risk: .providerEffect,
                localEnabled: true,
                qaSyntheticOverride: true
            )
        }
        return FeatureGateService.shared
            .isServerPolicyManagedRouteAllowed(.digitalHumanLivePanel)
    }

    private var isDigitalHumanQAOverrideEnabled: Bool {
        #if DEBUG || UI_QA_SIMULATOR
        let configuration = QALaunchConfiguration.shared
        return configuration.contains("DJShowDigitalHumanLivePanel")
            || configuration.contains("DJRunDigitalHumanLivePanelSmoke")
            || configuration.contains("DJRunEchoDigitalHumanLifecycleSmoke")
            || configuration.contains("DJRunDigitalHumanRuntimeStubSmoke")
            || configuration.contains("DJRunTencentDigitalHumanTextDriveSmoke")
            || configuration.contains("DJRunTencentDigitalHumanPCMDriveSmoke")
            || configuration.contains("DJRunTencentDigitalHumanBackendPCMDriveSmoke")
            || configuration.contains("DJRunTencentBackendPCMDriveMockSmoke")
            || configuration.contains("DJRunVoiceCloneRuntimeFaultInjectionSmoke")
        #else
        return false
        #endif
    }

    private var isEchoDelayedReplyProductEnabled: Bool {
        if EchoDelayedReplyAnswerReconciliationQAGate.isEnabled {
            return true
        }
        return FeatureGateService.shared
            .isServerPolicyManagedRouteAllowed(.echoDelayedReplies)
    }

    private var isDigitalHumanQADisableEnabled: Bool {
        #if DEBUG || UI_QA_SIMULATOR
        return QALaunchConfiguration.shared.contains("DJDisableDigitalHumanLivePanel")
        #else
        return false
        #endif
    }

    private var shouldShowEchoRuntimeDiagnosticsPanel: Bool {
        #if DEBUG || UI_QA_SIMULATOR
        let configuration = QALaunchConfiguration.shared
        return configuration.contains("DJShowEchoRuntimeDiagnosticsPanel")
            || configuration.contains("DJRunEchoRuntimeDiagnosticsExportSmoke")
            || configuration.contains("DJRunEchoTraceEvidencePackageExportSmoke")
            || configuration.contains("DJRunEchoTraceEvidencePackagePanelExportSmoke")
            || configuration.contains("DJRunEchoQAEvidenceBundleExportSmoke")
        #else
        return false
        #endif
    }

    private var shouldShowOwnerTruthInterviewNaturalInputEntry: Bool {
        #if DEBUG || UI_QA_SIMULATOR
        return OwnerTruthCandidateReviewQAGate.isEnabled
            && QALaunchConfiguration.shared.contains(
                QALaunchFeature.ownerTruthInterviewNaturalInputEntry.rawValue
            )
        #else
        return false
        #endif
    }

    private var shouldRunTencentDigitalHumanTextDriveSmoke: Bool {
        #if DEBUG || UI_QA_SIMULATOR
        return QALaunchConfiguration.shared.contains("DJRunTencentDigitalHumanTextDriveSmoke")
        #else
        return false
        #endif
    }

    private var shouldRunTencentDigitalHumanPCMDriveSmoke: Bool {
        #if DEBUG || UI_QA_SIMULATOR
        return QALaunchConfiguration.shared.contains("DJRunTencentDigitalHumanPCMDriveSmoke")
        #else
        return false
        #endif
    }

    private var shouldRunTencentDigitalHumanBackendPCMDriveSmoke: Bool {
        #if DEBUG || UI_QA_SIMULATOR
        return QALaunchConfiguration.shared.contains("DJRunTencentDigitalHumanBackendPCMDriveSmoke")
        #else
        return false
        #endif
    }

    private var shouldRunTencentBackendPCMDriveMockSmoke: Bool {
        #if DEBUG || UI_QA_SIMULATOR
        return QALaunchConfiguration.shared.contains("DJRunTencentBackendPCMDriveMockSmoke")
        #else
        return false
        #endif
    }

    private var shouldRunVoiceCloneRuntimeFaultInjectionSmoke: Bool {
        #if DEBUG || UI_QA_SIMULATOR
        return QALaunchConfiguration.shared.contains("DJRunVoiceCloneRuntimeFaultInjectionSmoke")
        #else
        return false
        #endif
    }

    private var shouldRunTencentDigitalHumanPCMDriveStopProbe: Bool {
        #if DEBUG || UI_QA_SIMULATOR
        return QALaunchConfiguration.shared.contains("DJRunTencentDigitalHumanPCMDriveStopProbe")
        #else
        return false
        #endif
    }

    private var tencentBackendPCMDriveVoiceProfileId: String? {
        #if DEBUG || UI_QA_SIMULATOR
        launchArgumentValue(prefix: "DJTencentBackendPCMDriveVoiceProfileId=")
            ?? VoiceCloneService.shared.currentUsableSpeakerId
        #else
        nil
        #endif
    }

    private var tencentBackendPCMDriveProfileVersion: Int? {
        #if DEBUG || UI_QA_SIMULATOR
        if let rawValue = launchArgumentValue(prefix: "DJTencentBackendPCMDriveProfileVersion="),
           let value = Int(rawValue),
           value > 0 {
            return value
        }
        let snapshot = VoiceCloneService.shared.voiceCloneShellSnapshot()
        guard snapshot.voiceProfileId == tencentBackendPCMDriveVoiceProfileId,
              snapshot.profileVersion > 0 else {
            return nil
        }
        return snapshot.profileVersion
        #else
        return nil
        #endif
    }

    private var tencentBackendPCMDriveUserId: String {
        #if DEBUG || UI_QA_SIMULATOR
        launchArgumentValue(prefix: "DJTencentBackendPCMDriveUserId=")
            ?? UserManager.shared.currentUser?.id
            ?? "default"
        #else
        return ""
        #endif
    }

    private var tencentBackendPCMDriveText: String {
        #if DEBUG || UI_QA_SIMULATOR
        launchArgumentValue(prefix: "DJTencentBackendPCMDriveText=")
            ?? "腾讯数智人复刻声音测试：如果你能听见这句话，并且口型同步，说明后端 PCM 音频驱动链路已经接通。"
        #else
        return ""
        #endif
    }

    private var tencentBackendPCMDriveMockVoiceProfileId: String {
        #if DEBUG || UI_QA_SIMULATOR
        launchArgumentValue(prefix: "DJTencentBackendPCMDriveMockVoiceProfileId=")
            ?? tencentBackendPCMDriveVoiceProfileId
            ?? "S_uiqa_tencent_pcm_mock"
        #else
        return ""
        #endif
    }

    private func launchArgumentValue(prefix: String) -> String? {
        #if DEBUG || UI_QA_SIMULATOR
        QALaunchConfiguration.shared.value(forPrefix: prefix)
        #else
        return nil
        #endif
    }

    init(
        viewModel: EchoViewModel = EchoViewModel(),
        digitalHumanSessionClient: DigitalHumanSessionClientPort = DreamJourneyBackendClient.shared
    ) {
        self.viewModel = viewModel
        self.digitalHumanSessionClient = digitalHumanSessionClient
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        FeatureGateService.shared.captureServerPolicyManagedRoute(
            .echoTextInput,
            risk: .ownerTextCore
        )
        view.backgroundColor = DJDesignTokens.Color.background
        navigationController?.setNavigationBarHidden(true, animated: false)
        observeDigitalHumanContext()
        observeEchoAccountLifecycle()
        observeEchoAppLifecycle()
        observeEchoAudioSessionEvents()
        observeAuthoritativeMessageCenter()
        let accountLease = captureEchoAccountLease(reason: "viewDidLoad")
        _ = captureDigitalHumanLifecycleToken(reason: "viewDidLoad")
        setupLayout()
        refreshAuthoritativeMessageCenter()
        refreshOwnerTruthInterviewNaturalInputProductEntryPolicy()
        bindViewModel(accountLease: accountLease)
        updatePersonaBadge()
        loadVoiceCloneRuntimeCapabilityIfNeeded()
        seedTranscriptPreview()
        let restoredDelayedReply: Bool
        if isEchoDelayedReplyProductEnabled {
            restoredDelayedReply = accountLease.map {
                viewModel.restoreStoredDelayedReplyIfAvailable(
                    accountLease: $0,
                    resourceOwnerId: $0.subjectId,
                    roleContextKey: digitalHumanRuntimeContextKey(
                        for: DigitalHumanContextStore.shared.current
                    )
                )
            } ?? false
        } else {
            restoredDelayedReply = false
        }
        if !restoredDelayedReply {
            render(state: .idle)
        }
        if isEchoDelayedReplyProductEnabled {
            refreshDelayedReplyAnswerReconciliation(reason: "viewDidLoad")
        }
        renderArchiveContextStatus(viewModel.archiveContextStatus)
    }

    deinit {
        liveSessionLimitTimer?.cancel()
        publicationDiscoveryTimer?.cancel()
        publicationObservers.values.forEach { $0.suspend() }
        liveFarewellSpeaker?.cancel()
        if let id = activeVoiceLaunchAttempt?.id {
            DispatchQueue.main.async {
                DialogEngineManager.shared.cancelPendingVoiceLaunch(id: id)
            }
        }
        activeVoiceLaunchAttempt?.cancelIfPending()
        releaseLiveMemoryRecoveryObservers(suspendsCoordinators: false)
        NotificationCenter.default.removeObserver(self)
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        let accountLease = captureEchoAccountLease(reason: "viewWillAppear")
        bindViewModel(accountLease: accountLease)
        if let accountLease,
           validateEchoAccountLease(at: .request, expected: accountLease, reason: "viewWillAppear"),
           bindDialogEngineToEchoAccountLease(reason: "viewWillAppear") {
            DialogEngineManager.shared.delegate = self
            if shouldShowDigitalHumanLivePanel {
                setDialogEngineLocalTTSPlaybackEnabled(false)
                reconcileDigitalHumanRuntimeWithCurrentContext(reason: "viewWillAppear")
            }
            if !DialogEngineManager.shared.isEngineReady,
               !DreamJourneyBackendClient.shared.isRealtimeVoiceConfigConfigured {
                DialogEngineManager.shared.setup()
            }
        } else {
            DialogEngineManager.shared.delegate = nil
        }
        viewModel.refreshArchiveContextStatus()
        refreshDelayedReplyAnswerReconciliation(reason: "viewWillAppear")
        updatePersonaBadge()
        loadVoiceCloneRuntimeCapabilityIfNeeded()
        refreshOwnerTruthInterviewNaturalInputProductEntryPolicy()
        refreshTranscriptPreviewForCurrentContextIfIdle()
        refreshAuthoritativeMessageCenter()
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        presentationVisible = true
        cloudOrb.active = true
        startAutomaticPublicationObservation()
        guard validateEchoAccountLease(at: .request, reason: "viewDidAppear") else {
            return
        }
        resumePendingLiveMemoryOrganizationsIfNeeded()
        let lifecycleToken = captureDigitalHumanLifecycleToken(reason: "viewDidAppear")
        prepareCloudDigitalHumanRuntimeIfNeeded(lifecycleToken: lifecycleToken)
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        // Reading the transcript is a presentation overlay, not leaving Live.
        if conversationSheet != nil { return }
        presentationVisible = false
        cloudOrb.active = false
        publicationDiscoveryTimer?.cancel()
        publicationObservers.values.forEach { $0.suspend() }
        DialogEngineManager.shared.cancelPendingVoiceLaunch(id: activeVoiceLaunchAttempt?.id)
        activeVoiceLaunchAttempt?.finish("pageLeft")
        activeVoiceLaunchAttempt = nil
        if isUserControlledLiveSessionOpen {
            isUserControlledLiveSessionOpen = false
        }
        finishLiveMemoryCaptureIfNeeded()
        cancelEchoTextReplySpeech(reason: "viewWillDisappear")
        cancelCloudDigitalHumanBackgroundRelease(reason: "viewWillDisappear")
        invalidateDigitalHumanLifecycle(reason: "viewWillDisappear")
        activeVoiceInteractionLifecycleToken = nil
        let ownsDialogDelegate = DialogEngineManager.shared.delegate === self
            && ownsCurrentDialogEngineBinding()
        if ownsDialogDelegate {
            if DialogEngineManager.shared.isDialogActive {
                interruptDigitalHumanPlayback(reason: "viewWillDisappear")
                DialogEngineManager.shared.stopDialog()
                flushPendingAIReplyIfNeeded()
                ConversationMemoryManager.shared.endSession()
                resetEchoViewModelToIdle()
            }
        }
        releaseDigitalHumanRuntime(reason: "viewWillDisappear", resetsAudioOwnerToOrdinaryEcho: true)
        releaseEchoAudioOwnerLease(reason: "viewWillDisappear")
        if ownsDialogDelegate {
            DialogEngineManager.shared.delegate = nil
            releaseDialogEngineBinding()
        }
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        let safeBottom = Self.systemBottomSafeInset
        micButtonBottomConstraint?.constant = -max(WarmTabBarView.tabBarHeight + safeBottom + 40, keyboardOverlap + 12)
        let orbHeight = min(300, max(60, conversationContent.bounds.height - 250))
        if abs((cloudOrbHeightConstraint?.constant ?? 0) - orbHeight) > 0.5 {
            cloudOrbHeightConstraint?.constant = orbHeight
        }
    }

    private static var systemBottomSafeInset: CGFloat {
        UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .flatMap { $0.windows }
            .first(where: { $0.isKeyWindow })?
            .safeAreaInsets.bottom ?? 0
    }

    private func setupLayout() {
        if shouldShowDigitalHumanLivePanel {
            let digitalHumanLivePanelView = DigitalHumanLivePanelView()
            self.digitalHumanLivePanelView = digitalHumanLivePanelView
            digitalHumanAudioLevelMeter = DigitalHumanAudioLevelMeter(panelView: digitalHumanLivePanelView)
        }

        if let digitalHumanLivePanelView {
            view.addSubview(scenicView)
            view.insertSubview(digitalHumanLivePanelView, aboveSubview: scenicView)
            view.addSubview(personaBadgeView)
            view.addSubview(archiveContextStatusView)
            view.addSubview(digitalHumanStatusView)
        } else {
            view.addSubview(scenicView)
            view.addSubview(personaBadgeView)
            view.addSubview(archiveContextStatusView)
        }
        view.addSubview(messageCenterBellButton)
        messageCenterBellButton.addTarget(
            self,
            action: #selector(messageCenterBellTapped),
            for: .touchUpInside
        )
        view.backgroundColor = DJDesignTokens.Color.background
        scenicView.isHidden = true
        digitalHumanLivePanelView?.alpha = 0
        digitalHumanStatusView.alpha = 0
        view.addSubview(conversationContent)
        conversationContent.showsVerticalScrollIndicator = false
        conversationContent.addSubview(cloudOrb)
        view.addSubview(composer)
        composer.onSend = { [weak self] text in
            guard let self, !self.isUserControlledLiveSessionOpen,
                  self.isOwnerTruthInterviewNaturalInputProductPolicyPermitted else { return }
            self.beginEchoTextQuestion(text)
            self.composer.field.text = ""
            self.composer.field.resignFirstResponder()
        }
        conversationContent.addSubview(quoteBubble)
        conversationContent.addSubview(voiceStatusView)
        expandReplyButton.setTitle("展开本场记录", for: .normal)
        expandReplyButton.titleLabel?.font = DJDesignTokens.Font.label(12)
        expandReplyButton.tintColor = DJDesignTokens.Color.accentDeep
        expandReplyButton.accessibilityIdentifier = "echoExpandTranscript"
        expandReplyButton.addTarget(self, action: #selector(expandConversationTapped), for: .touchUpInside)
        quoteBubble.addSubview(expandReplyButton)
        showMemoriesButton.setTitle("查看待确认记忆", for: .normal)
        showMemoriesButton.addTarget(self, action: #selector(showOrganizedMemories), for: .touchUpInside)
        showMemoriesButton.isHidden = true
        conversationContent.addSubview(showMemoriesButton)
        finishTextButton.setTitle("结束文字对话并整理", for: .normal)
        finishTextButton.titleLabel?.font = DJDesignTokens.Font.label(12)
        finishTextButton.addTarget(self, action: #selector(finishTextTapped), for: .touchUpInside)
        view.addSubview(finishTextButton)
        if shouldShowEchoRuntimeDiagnosticsPanel {
            view.addSubview(echoRuntimeDiagnosticsPanelView)
            echoRuntimeDiagnosticsPanelView.addSubview(echoRuntimeDiagnosticsScrollView)
            echoRuntimeDiagnosticsScrollView.addSubview(echoRuntimeDiagnosticsPanelLabel)
            echoRuntimeDiagnosticsPanelView.addSubview(echoTraceEvidenceExportButton)
        }
        view.addSubview(micRingView)
        view.addSubview(micButton)
        // Legacy query button is intentionally not installed on the product page.
        if shouldShowOwnerTruthInterviewNaturalInputEntry {
            view.addSubview(ownerTruthInterviewNaturalInputEntryButton)
        }

        let personaTextStack = UIStackView(arrangedSubviews: [personaNameLabel, personaSubtitleLabel])
        personaTextStack.axis = .vertical
        personaTextStack.alignment = .leading
        personaTextStack.spacing = 2

        personaBadgeView.addSubview(personaAvatarView)
        personaBadgeView.addSubview(personaTextStack)
        personaAvatarView.addSubview(personaIconView)
        archiveContextStatusView.addSubview(archiveContextStatusLabel)
        let digitalHumanStatusStack = UIStackView(arrangedSubviews: [
            digitalHumanStatusTitleLabel,
            digitalHumanStatusDetailLabel
        ])
        digitalHumanStatusStack.axis = .vertical
        digitalHumanStatusStack.alignment = .center
        digitalHumanStatusStack.spacing = 2
        digitalHumanStatusView.addSubview(digitalHumanStatusStack)
        quoteBubble.addSubview(quoteLabel)
        voiceStatusView.addSubview(voiceStatusLabel)

        [
            scenicView, conversationContent, cloudOrb, composer, expandReplyButton, showMemoriesButton, finishTextButton,
            personaBadgeView,
            messageCenterBellButton,
            personaAvatarView,
            personaIconView,
            personaTextStack,
            archiveContextStatusView,
            archiveContextStatusLabel,
            digitalHumanStatusView,
            digitalHumanStatusTitleLabel,
            digitalHumanStatusDetailLabel,
            digitalHumanStatusStack,
            quoteBubble,
            quoteLabel,
            voiceStatusView,
            voiceStatusLabel,
            echoRuntimeDiagnosticsPanelView,
            echoRuntimeDiagnosticsScrollView,
            echoRuntimeDiagnosticsPanelLabel,
            echoTraceEvidenceExportButton,
            micRingView,
            micButton,
            ownerTruthInterviewNaturalInputEntryButton,
            ownerTruthInterviewNaturalInputProductEntryButton
        ].forEach { $0.translatesAutoresizingMaskIntoConstraints = false }
        digitalHumanLivePanelView?.translatesAutoresizingMaskIntoConstraints = false

        let micBottomConstraint = micButton.bottomAnchor.constraint(equalTo: view.bottomAnchor,
            constant: -(WarmTabBarView.tabBarHeight + 40))
        micButtonBottomConstraint = micBottomConstraint
        micCenterConstraint = micButton.centerXAnchor.constraint(equalTo: view.centerXAnchor)
        micTrailingConstraint = micButton.trailingAnchor.constraint(equalTo: composer.trailingAnchor, constant: -4)
        let orbHeight = cloudOrb.heightAnchor.constraint(equalToConstant: 260)
        cloudOrbHeightConstraint = orbHeight
        orbHeight.priority = .defaultLow
        let quoteBottom = quoteBubble.bottomAnchor.constraint(equalTo: conversationContent.contentLayoutGuide.bottomAnchor, constant: -8)
        quoteBottom.priority = .required
        NSLayoutConstraint.activate([
            scenicView.topAnchor.constraint(equalTo: view.topAnchor),
            scenicView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            scenicView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            scenicView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            personaBadgeView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 16),
            personaBadgeView.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: DJDesignTokens.Spacing.page),
            personaBadgeView.trailingAnchor.constraint(lessThanOrEqualTo: messageCenterBellButton.leadingAnchor, constant: -12),
            messageCenterBellButton.centerYAnchor.constraint(equalTo: personaBadgeView.centerYAnchor),
            messageCenterBellButton.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -24),
            messageCenterBellButton.widthAnchor.constraint(equalToConstant: 44),
            messageCenterBellButton.heightAnchor.constraint(equalToConstant: 44),
            personaAvatarView.topAnchor.constraint(equalTo: personaBadgeView.topAnchor, constant: 8),
            personaAvatarView.leadingAnchor.constraint(equalTo: personaBadgeView.leadingAnchor, constant: 8),
            personaAvatarView.bottomAnchor.constraint(equalTo: personaBadgeView.bottomAnchor, constant: -8),
            personaAvatarView.widthAnchor.constraint(equalToConstant: 40),
            personaAvatarView.heightAnchor.constraint(equalToConstant: 40),
            personaIconView.centerXAnchor.constraint(equalTo: personaAvatarView.centerXAnchor),
            personaIconView.centerYAnchor.constraint(equalTo: personaAvatarView.centerYAnchor),
            personaIconView.widthAnchor.constraint(equalToConstant: 22),
            personaIconView.heightAnchor.constraint(equalToConstant: 22),
            personaTextStack.leadingAnchor.constraint(equalTo: personaAvatarView.trailingAnchor, constant: 10),
            personaTextStack.centerYAnchor.constraint(equalTo: personaAvatarView.centerYAnchor),
            personaTextStack.trailingAnchor.constraint(equalTo: personaBadgeView.trailingAnchor, constant: -14),
            conversationContent.topAnchor.constraint(equalTo: personaBadgeView.bottomAnchor, constant: 16),
            conversationContent.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            conversationContent.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            conversationContent.bottomAnchor.constraint(equalTo: finishTextButton.topAnchor, constant: -12),
            conversationContent.contentLayoutGuide.widthAnchor.constraint(equalTo: conversationContent.frameLayoutGuide.widthAnchor),
            cloudOrb.topAnchor.constraint(equalTo: conversationContent.contentLayoutGuide.topAnchor),
            cloudOrb.centerXAnchor.constraint(equalTo: conversationContent.contentLayoutGuide.centerXAnchor),
            cloudOrb.widthAnchor.constraint(equalTo: view.widthAnchor, multiplier: 0.82), orbHeight,
            cloudOrb.heightAnchor.constraint(greaterThanOrEqualToConstant: 60),
            voiceStatusView.topAnchor.constraint(equalTo: cloudOrb.bottomAnchor, constant: 8),
            voiceStatusView.centerXAnchor.constraint(equalTo: conversationContent.contentLayoutGuide.centerXAnchor),
            voiceStatusView.leadingAnchor.constraint(greaterThanOrEqualTo: conversationContent.contentLayoutGuide.leadingAnchor, constant: 24),
            voiceStatusView.trailingAnchor.constraint(lessThanOrEqualTo: conversationContent.contentLayoutGuide.trailingAnchor, constant: -24),
            voiceStatusLabel.topAnchor.constraint(equalTo: voiceStatusView.topAnchor, constant: 8),
            voiceStatusLabel.bottomAnchor.constraint(equalTo: voiceStatusView.bottomAnchor, constant: -8),
            voiceStatusLabel.leadingAnchor.constraint(equalTo: voiceStatusView.leadingAnchor, constant: 16),
            voiceStatusLabel.trailingAnchor.constraint(equalTo: voiceStatusView.trailingAnchor, constant: -16),
            showMemoriesButton.topAnchor.constraint(equalTo: voiceStatusView.bottomAnchor, constant: 2),
            showMemoriesButton.centerXAnchor.constraint(equalTo: conversationContent.contentLayoutGuide.centerXAnchor),
            showMemoriesButton.heightAnchor.constraint(equalToConstant: 28),
            quoteBubble.topAnchor.constraint(equalTo: showMemoriesButton.bottomAnchor, constant: 8),
            quoteBubble.leadingAnchor.constraint(equalTo: conversationContent.contentLayoutGuide.leadingAnchor, constant: 24),
            quoteBubble.trailingAnchor.constraint(equalTo: conversationContent.contentLayoutGuide.trailingAnchor, constant: -24), quoteBottom,
            quoteLabel.topAnchor.constraint(equalTo: quoteBubble.topAnchor, constant: 16),
            quoteLabel.leadingAnchor.constraint(equalTo: quoteBubble.leadingAnchor, constant: 16),
            quoteLabel.trailingAnchor.constraint(equalTo: quoteBubble.trailingAnchor, constant: -16),
            expandReplyButton.topAnchor.constraint(equalTo: quoteLabel.bottomAnchor, constant: 4),
            expandReplyButton.trailingAnchor.constraint(equalTo: quoteBubble.trailingAnchor, constant: -16),
            expandReplyButton.heightAnchor.constraint(equalToConstant: 32),
            expandReplyButton.bottomAnchor.constraint(equalTo: quoteBubble.bottomAnchor, constant: -8),
            composer.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 24),
            composer.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -24),
            composer.heightAnchor.constraint(equalToConstant: 64),
            composer.centerYAnchor.constraint(equalTo: micButton.centerYAnchor),
            finishTextButton.bottomAnchor.constraint(equalTo: composer.topAnchor, constant: -4),
            finishTextButton.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            finishTextButton.heightAnchor.constraint(equalToConstant: 30),
            micBottomConstraint,
            micButton.widthAnchor.constraint(equalToConstant: 56),
            micButton.heightAnchor.constraint(equalToConstant: 56),
            micRingView.centerXAnchor.constraint(equalTo: micButton.centerXAnchor),
            micRingView.centerYAnchor.constraint(equalTo: micButton.centerYAnchor),
            micRingView.widthAnchor.constraint(equalToConstant: 76),
            micRingView.heightAnchor.constraint(equalToConstant: 76),
            archiveContextStatusView.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 24),
            archiveContextStatusView.topAnchor.constraint(equalTo: personaBadgeView.bottomAnchor, constant: 4),
            archiveContextStatusLabel.topAnchor.constraint(equalTo: archiveContextStatusView.topAnchor, constant: 4),
            archiveContextStatusLabel.bottomAnchor.constraint(equalTo: archiveContextStatusView.bottomAnchor, constant: -4),
            archiveContextStatusLabel.leadingAnchor.constraint(equalTo: archiveContextStatusView.leadingAnchor, constant: 8),
            archiveContextStatusLabel.trailingAnchor.constraint(equalTo: archiveContextStatusView.trailingAnchor, constant: -8)
        ])
        voiceStatusLabel.numberOfLines = 0
        voiceStatusLabel.setContentCompressionResistancePriority(.required, for: .vertical)
        NotificationCenter.default.addObserver(self, selector: #selector(echoKeyboardChanged(_:)),
            name: UIResponder.keyboardWillChangeFrameNotification, object: nil)

        if shouldShowOwnerTruthInterviewNaturalInputEntry {
            NSLayoutConstraint.activate([
                ownerTruthInterviewNaturalInputEntryButton.centerYAnchor.constraint(equalTo: micButton.centerYAnchor),
                ownerTruthInterviewNaturalInputEntryButton.trailingAnchor.constraint(equalTo: micButton.leadingAnchor, constant: -18),
                ownerTruthInterviewNaturalInputEntryButton.widthAnchor.constraint(equalToConstant: 40),
                ownerTruthInterviewNaturalInputEntryButton.heightAnchor.constraint(equalToConstant: 40)
            ])
        }

        updateOwnerTruthInterviewNaturalInputProductEntryVisibility()

        if shouldShowEchoRuntimeDiagnosticsPanel {
            NSLayoutConstraint.activate([
                echoRuntimeDiagnosticsPanelView.topAnchor.constraint(
                    equalTo: view.safeAreaLayoutGuide.topAnchor,
                    constant: 84
                ),
                echoRuntimeDiagnosticsPanelView.trailingAnchor.constraint(
                    equalTo: view.trailingAnchor,
                    constant: -DJDesignTokens.Spacing.page
                ),
                echoRuntimeDiagnosticsPanelView.widthAnchor.constraint(
                    lessThanOrEqualTo: view.widthAnchor,
                    multiplier: 0.66
                ),
                echoRuntimeDiagnosticsPanelView.heightAnchor.constraint(equalToConstant: 244),
                echoRuntimeDiagnosticsPanelView.bottomAnchor.constraint(
                    lessThanOrEqualTo: micButton.topAnchor,
                    constant: -16
                ),
                echoRuntimeDiagnosticsScrollView.topAnchor.constraint(
                    equalTo: echoRuntimeDiagnosticsPanelView.topAnchor,
                    constant: 10
                ),
                echoRuntimeDiagnosticsScrollView.leadingAnchor.constraint(
                    equalTo: echoRuntimeDiagnosticsPanelView.leadingAnchor,
                    constant: 10
                ),
                echoRuntimeDiagnosticsScrollView.trailingAnchor.constraint(
                    equalTo: echoRuntimeDiagnosticsPanelView.trailingAnchor,
                    constant: -10
                ),
                echoRuntimeDiagnosticsScrollView.bottomAnchor.constraint(
                    equalTo: echoTraceEvidenceExportButton.topAnchor,
                    constant: -8
                ),
                echoRuntimeDiagnosticsPanelLabel.topAnchor.constraint(
                    equalTo: echoRuntimeDiagnosticsScrollView.contentLayoutGuide.topAnchor
                ),
                echoRuntimeDiagnosticsPanelLabel.leadingAnchor.constraint(
                    equalTo: echoRuntimeDiagnosticsScrollView.contentLayoutGuide.leadingAnchor
                ),
                echoRuntimeDiagnosticsPanelLabel.trailingAnchor.constraint(
                    equalTo: echoRuntimeDiagnosticsScrollView.contentLayoutGuide.trailingAnchor
                ),
                echoRuntimeDiagnosticsPanelLabel.bottomAnchor.constraint(
                    equalTo: echoRuntimeDiagnosticsScrollView.contentLayoutGuide.bottomAnchor
                ),
                echoRuntimeDiagnosticsPanelLabel.widthAnchor.constraint(
                    equalTo: echoRuntimeDiagnosticsScrollView.frameLayoutGuide.widthAnchor
                ),

                echoTraceEvidenceExportButton.leadingAnchor.constraint(
                    equalTo: echoRuntimeDiagnosticsPanelView.leadingAnchor,
                    constant: 10
                ),
                echoTraceEvidenceExportButton.trailingAnchor.constraint(
                    equalTo: echoRuntimeDiagnosticsPanelView.trailingAnchor,
                    constant: -10
                ),
                echoTraceEvidenceExportButton.bottomAnchor.constraint(
                    equalTo: echoRuntimeDiagnosticsPanelView.bottomAnchor,
                    constant: -10
                ),
                echoTraceEvidenceExportButton.heightAnchor.constraint(equalToConstant: 28),
            ])
        }

        if let digitalHumanLivePanelView {
            NSLayoutConstraint.activate([
                digitalHumanLivePanelView.topAnchor.constraint(equalTo: view.topAnchor),
                digitalHumanLivePanelView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
                digitalHumanLivePanelView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
                digitalHumanLivePanelView.bottomAnchor.constraint(equalTo: view.bottomAnchor),

                digitalHumanStatusView.centerXAnchor.constraint(equalTo: view.centerXAnchor),
                digitalHumanStatusView.topAnchor.constraint(equalTo: personaBadgeView.bottomAnchor, constant: 14),
                digitalHumanStatusView.widthAnchor.constraint(lessThanOrEqualTo: view.widthAnchor, multiplier: 0.78),
                digitalHumanStatusStack.topAnchor.constraint(equalTo: digitalHumanStatusView.topAnchor, constant: 8),
                digitalHumanStatusStack.leadingAnchor.constraint(equalTo: digitalHumanStatusView.leadingAnchor, constant: 14),
                digitalHumanStatusStack.trailingAnchor.constraint(equalTo: digitalHumanStatusView.trailingAnchor, constant: -14),
                digitalHumanStatusStack.bottomAnchor.constraint(equalTo: digitalHumanStatusView.bottomAnchor, constant: -8)
            ])
        }
    }

    private func bindViewModel(accountLease: AccountLease?) {
        viewModel.onStateChange = { [weak self] state in
            DispatchQueue.main.async {
                guard let self,
                      let accountLease,
                      self.validateEchoAccountLease(
                        at: .ui,
                        expected: accountLease,
                        reason: "viewModelState"
                      ) else { return }
                self.render(state: state)
            }
        }

        viewModel.onTranscriptAppend = { [weak self] text, isUser in
            DispatchQueue.main.async {
                guard let self,
                      let accountLease,
                      self.validateEchoAccountLease(
                        at: .ui,
                        expected: accountLease,
                        reason: "viewModelTranscript"
                      ) else { return }
                self.appendTranscript(text: text, isUser: isUser)
            }
        }

        viewModel.onArchiveContextStatusChange = { [weak self] status in
            DispatchQueue.main.async {
                guard let self,
                      let accountLease,
                      self.validateEchoAccountLease(
                        at: .ui,
                        expected: accountLease,
                        reason: "viewModelArchiveContext"
                      ) else { return }
                self.renderArchiveContextStatus(status)
            }
        }
    }

    private func observeDigitalHumanContext() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(digitalHumanContextDidChange),
            name: .djDigitalHumanContextDidChange,
            object: nil
        )
    }

    private func observeAuthoritativeMessageCenter() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(authoritativeMessageCenterDidUpdate),
            name: .djInAppMessageCenterDidUpdate,
            object: AuthoritativeInAppMessageCenterStore.shared
        )
    }

    private func refreshAuthoritativeMessageCenter() {
        guard let userId = UserManager.shared.currentUser?.id,
              let accountLease = accountLeaseRuntime.capture(forSubjectId: userId) else {
            messageCenterBellButton.update(unreadCount: 0)
            return
        }
        messageCenterBellButton.update(
            unreadCount: AuthoritativeInAppMessageCenterStore.shared
                .snapshot(for: accountLease)
                .unreadCount
        )
        AuthoritativeInAppMessageCenterStore.shared.refresh(accountLease: accountLease)
    }

    @objc private func authoritativeMessageCenterDidUpdate() {
        guard let userId = UserManager.shared.currentUser?.id,
              let accountLease = accountLeaseRuntime.capture(forSubjectId: userId) else {
            messageCenterBellButton.update(unreadCount: 0)
            return
        }
        messageCenterBellButton.update(
            unreadCount: AuthoritativeInAppMessageCenterStore.shared
                .snapshot(for: accountLease)
                .unreadCount
        )
    }

    @objc private func messageCenterBellTapped() {
        InAppMessageCenterPresentation.present(from: self)
    }

    private func observeEchoAccountLifecycle() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(echoAccountDidChange),
            name: .djUserDidLogin,
            object: nil
        )
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(echoAccountDidChange),
            name: .djUserDidLogout,
            object: nil
        )
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(echoAccountDidChange),
            name: .djAccountLifecycleWillTeardown,
            object: nil
        )
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(echoAuthorityEpochDidChange),
            name: .djRecoveryAuthorityEpochDidChange,
            object: nil
        )
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(echoPrivateAccountReadinessAccepted),
            name: .djPrivateAccountReadinessAccepted,
            object: nil
        )
    }

    @objc private func echoAccountDidChange() {
        performEchoAccountScopeRebindOnMain(reason: "accountDidChange")
    }

    @objc private func echoAuthorityEpochDidChange() {
        performEchoAccountScopeRebindOnMain(reason: "authorityEpochDidChange")
    }

    @objc private func echoPrivateAccountReadinessAccepted() {
        guard Thread.isMainThread else {
            DispatchQueue.main.async { [weak self] in
                self?.echoPrivateAccountReadinessAccepted()
            }
            return
        }
        guard let userID = UserManager.shared.currentUser?.id,
              let currentLease = accountLeaseRuntime.capture(forSubjectId: userID) else {
            return
        }
        guard echoAccountLease == currentLease else {
            rebindEchoAccountScope(reason: "privateAccountReadinessAcceptedScopeChanged")
            return
        }
        resumePendingLiveMemoryOrganizationsIfNeeded()
        retainedLiveMemoryRecoveryCoordinators.values.forEach {
            $0.verifyStatus(startsNewRound: true)
        }
    }

    private func performEchoAccountScopeRebindOnMain(reason: String) {
        guard Thread.isMainThread else {
            DispatchQueue.main.async { [weak self] in
                self?.rebindEchoAccountScope(reason: reason)
            }
            return
        }
        rebindEchoAccountScope(reason: reason)
    }

    private func rebindEchoAccountScope(reason: String) {
        DialogEngineManager.shared.cancelPendingVoiceLaunch(id: activeVoiceLaunchAttempt?.id)
        activeVoiceLaunchAttempt?.cancelIfPending()
        activeVoiceLaunchAttempt = nil
        detachLiveMemoryRecoveryObservers()
        presentedLiveMemoryProductSessionID = nil
        presentedLiveMemoryAccountLease = nil
        ownerTruthInterviewNaturalInputPolicyRefreshGeneration &+= 1
        pendingMemoryGapHandoff = nil
        isOwnerTruthInterviewNaturalInputProductPolicyPermitted = false
        updateOwnerTruthInterviewNaturalInputProductEntryVisibility()
        invalidateDigitalHumanLifecycle(reason: reason)
        activeVoiceInteractionLifecycleToken = nil
        releaseDigitalHumanRuntime(
            reason: reason,
            resetsAudioOwnerToOrdinaryEcho: true,
            removeProviderViewMessage: nil,
            recordsDiagnostics: false
        )
        releaseDialogEngineBinding()
        voiceCloneRuntimeCapability = nil
        isLoadingVoiceCloneRuntimeCapability = false
        lastEchoTraceRecord = nil
        lastDigitalHumanSessionEvidenceSummary = nil
        lastVoiceSynthesisEvidenceSummary = nil
        lastOwnerTruthContextCitationEvidence = nil
        lastEchoAnswerGroundingEvidence = nil
        lastOwnerTruthContextParityEvidence = nil
        lastOwnerTruthContextCompareEvidence = nil
        lastVoiceCloneProviderLogId = nil
        lastVoiceCloneProviderRequestId = nil
        lastVoiceCloneProviderMode = nil
        lastEchoRuntimeFallbackReason = nil
        pendingAIText = nil
        transcriptEntries.removeAll()
        composer.field.text = nil
        publicationObservers.values.forEach { $0.suspend() }
        publicationObservers.removeAll()
        observedPublicationSessionID = nil
        lastOrganizationPresentation = nil
        recentEchoConversation.reset()
        resetDigitalHumanReplyDispatchState()
        echoRuntimeDiagnosticsPanelLabel.text = ""
        let accountLease = captureEchoAccountLease(reason: reason)
        bindViewModel(accountLease: accountLease)
        guard accountLease != nil else {
            quoteLabel.text = nil
            render(state: .idle)
            return
        }
        viewModel.resetTransientStateForAccountRebind()
        if isEchoDelayedReplyProductEnabled, let accountLease {
            _ = viewModel.restoreStoredDelayedReplyIfAvailable(
                accountLease: accountLease,
                resourceOwnerId: accountLease.subjectId,
                roleContextKey: digitalHumanRuntimeContextKey(
                    for: DigitalHumanContextStore.shared.current
                )
            )
        }
        if isEchoDelayedReplyProductEnabled {
            refreshDelayedReplyAnswerReconciliation(reason: reason)
        }
        seedTranscriptPreview()
        if view.window != nil,
           bindDialogEngineToEchoAccountLease(reason: reason) {
            DialogEngineManager.shared.delegate = self
            applyEchoAudioRoutePolicy()
            updatePersonaBadge()
            viewModel.refreshArchiveContextStatus()
            loadVoiceCloneRuntimeCapabilityIfNeeded(force: true)
            refreshOwnerTruthInterviewNaturalInputProductEntryPolicy()
            resumePendingLiveMemoryOrganizationsIfNeeded()
            prepareCloudDigitalHumanRuntimeIfNeeded()
        }
    }

    @objc private func digitalHumanContextDidChange() {
        guard Thread.isMainThread else {
            DispatchQueue.main.async { [weak self] in
                self?.digitalHumanContextDidChange()
            }
            return
        }
        guard validateEchoAccountLease(at: .ui, reason: "digitalHumanContextDidChange") else {
            return
        }
        transcriptEntries.removeAll()
        quoteLabel.text = nil
        composer.field.text = nil
        closeConversationSheet()
        publicationObservers.values.forEach { $0.suspend() }
        publicationObservers.removeAll()
        observedPublicationSessionID = nil
        lastOrganizationPresentation = nil
        recentEchoConversation.reset()
        viewModel.resetTransientStateForAccountRebind()
        if isEchoDelayedReplyProductEnabled, let echoAccountLease {
            _ = viewModel.restoreStoredDelayedReplyIfAvailable(
                accountLease: echoAccountLease,
                resourceOwnerId: echoAccountLease.subjectId,
                roleContextKey: digitalHumanRuntimeContextKey(
                    for: DigitalHumanContextStore.shared.current
                )
            )
        }
        if isEchoDelayedReplyProductEnabled {
            refreshDelayedReplyAnswerReconciliation(reason: "contextDidChange")
        }
        let didReleaseStaleRuntime = reconcileDigitalHumanRuntimeWithCurrentContext(reason: "contextDidChange")
        viewModel.refreshArchiveContextStatus()
        updatePersonaBadge()
        refreshTranscriptPreviewForCurrentContextIfIdle()
        if view.window != nil {
            if didReleaseStaleRuntime {
                scheduleCloudDigitalHumanRuntimeRecovery(
                    reason: "contextDidChange",
                    delay: Self.tencentDigitalHumanContextSwitchReconnectDelay
                )
            } else {
                prepareCloudDigitalHumanRuntimeIfNeeded()
            }
        }
        _ = updateDialogEngineLocalTTSVoiceSelection(reason: "contextDidChange")
    }

    private func observeEchoAppLifecycle() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(echoAppLifecycleEventForwarded(_:)),
            name: .djAppLifecycleEventForwarded,
            object: nil
        )
    }

    @objc private func echoAppLifecycleEventForwarded(_ notification: Notification) {
        guard let event = AppLifecycleEventNotification.event(from: notification.userInfo) else {
            return
        }
        switch event {
        case .willResignActive:
            echoAppWillResignActive()
        case .didEnterBackground:
            echoAppDidEnterBackground()
        case .willEnterForeground:
            echoAppWillEnterForeground()
        case .didBecomeActive:
            echoAppDidBecomeActive()
        case .sceneConnected, .didDisconnect:
            break
        }
    }

    @objc private func echoAppWillResignActive() {
        cloudOrb.active = false
        publicationObservers.values.forEach { $0.suspend() }
        publicationDiscoveryTimer?.cancel()
        suspendEchoForAppLifecycle(reason: "willResignActive")
    }

    @objc private func echoAppDidEnterBackground() {
        retainedLiveMemoryRecoveryCoordinators.values.forEach { $0.suspend() }
        suspendEchoForAppLifecycle(reason: "didEnterBackground")
        scheduleCloudDigitalHumanRuntimeReleaseForBackgroundIfNeeded()
    }

    @objc private func echoAppWillEnterForeground() {
        cancelCloudDigitalHumanBackgroundRelease(reason: "willEnterForeground")
        restoreEchoAfterAppLifecycleIfNeeded(reason: "willEnterForeground")
        resumePendingLiveMemoryOrganizationsIfNeeded()
        retainedLiveMemoryRecoveryCoordinators.values.forEach {
            $0.verifyStatus(startsNewRound: true)
        }
    }

    @objc private func echoAppDidBecomeActive() {
        cloudOrb.active = presentationVisible
        startAutomaticPublicationObservation()
        cancelCloudDigitalHumanBackgroundRelease(reason: "didBecomeActive")
        restoreEchoAfterAppLifecycleIfNeeded(reason: "didBecomeActive")
        refreshDelayedReplyAnswerReconciliation(reason: "didBecomeActive")
        prepareCloudDigitalHumanRuntimeAfterForegroundIfNeeded(reason: "didBecomeActive")
        resumePendingLiveMemoryOrganizationsIfNeeded()
    }

    private func suspendEchoForAppLifecycle(reason: String) {
        guard view.window != nil,
              !isSuspendedByAppLifecycle else {
            return
        }

        let ownsDialogBinding = ownsCurrentDialogEngineBinding()
        let shouldSuspendRuntime = (ownsDialogBinding && DialogEngineManager.shared.isDialogActive)
            || hasTencentDigitalHumanProviderSpeechInFlight
            || digitalHumanConversation.shouldResumeAfterProviderSpeech
            || !isCurrentEchoInteractionIdle

        guard shouldSuspendRuntime else {
            return
        }

        invalidateDigitalHumanInteraction(reason: "appLifecycle:\(reason)")
        activeVoiceInteractionLifecycleToken = nil
        isSuspendedByAppLifecycle = true
        if isUserControlledLiveSessionOpen {
            isLiveVoiceTransportSuspended = true
        }
        interruptDigitalHumanPlayback(reason: "appLifecycle:\(reason)")
        preserveTencentProviderSessionAfterLocalDialogStop(reason: "appLifecycle:\(reason)")
        muteTencentProviderRemoteAudioForUserCapture(reason: "appLifecycle:\(reason)")
        recordEchoRuntimeDiagnosticsSnapshot(reason: "appLifecycleSuspended:\(reason)")
        if ownsDialogBinding,
           DialogEngineManager.shared.isDialogActive {
            isStoppingVoiceCaptureForAppLifecycle = true
            DialogEngineManager.shared.stopDialog()
        } else {
            resetToLifecyclePausedIdle()
        }

        print(
            "[TencentDigitalHuman] app lifecycle suspended reason=\(reason) " +
            "providerPreserved=true \(currentEchoAudioOwner.logLabel)"
        )
    }

    private func scheduleCloudDigitalHumanRuntimeReleaseForBackgroundIfNeeded() {
        guard view.window != nil,
              shouldShowDigitalHumanLivePanel,
              isDigitalHumanRuntimeEligibleForBackgroundRelease else {
            return
        }

        cancelCloudDigitalHumanBackgroundRelease(reason: "reschedule")
        guard let accountLease = echoAccountLease,
              validateEchoAccountLease(
                at: .request,
                expected: accountLease,
                reason: "scheduleBackgroundRelease"
              ) else {
            return
        }
        let contextKey = currentDigitalHumanRuntimeContextKey()
        let lifecycleToken = captureDigitalHumanLifecycleToken(reason: "backgroundReleaseLease")
        let runtimeSessionCallback = echoRuntimeSessionCoordinator.currentSessionCallbackToken()
        guard runtimeSessionCallback != nil || !requiresEchoRuntimeInteractionLease else {
            PrivacySafeDiagnostics.log(
                subsystem: "TencentDigitalHuman",
                event: "backgroundReleaseSkipped",
                states: ["reason": "runtimeSessionLeaseUnavailable"],
                correlations: ["context": contextKey]
            )
            releaseDigitalHumanRuntime(
                reason: "appLifecycle:backgroundLeaseUnavailable",
                resetsAudioOwnerToOrdinaryEcho: true,
                removeProviderViewMessage: "数字人已暂停"
            )
            return
        }
        let lease = digitalHumanLifecycle.beginBackgroundReleaseLease(contextKey: contextKey)
        let workItem = DispatchWorkItem { [weak self] in
            guard let self,
                  self.validateEchoAccountLease(
                    at: .timer,
                    expected: accountLease,
                    reason: "backgroundReleaseLeaseExpired"
                  ),
                  self.digitalHumanLifecycle.isCurrentBackgroundReleaseLease(
                    lease,
                    contextKey: self.currentDigitalHumanRuntimeContextKey()
                  ),
                  self.isCurrentDigitalHumanSessionToken(
                    lifecycleToken,
                    reason: "backgroundReleaseLeaseExpired"
                  ),
                  self.isCurrentEchoRuntimeSessionCallback(
                    runtimeSessionCallback,
                    reason: "backgroundReleaseLeaseExpired"
                  ) else {
                return
            }
            self.digitalHumanBackgroundReleaseWorkItem = nil
            self.invalidateDigitalHumanLifecycle(reason: "backgroundReleaseGraceExpired")
            self.releaseDigitalHumanRuntime(
                reason: "appLifecycle:backgroundGraceExpired",
                resetsAudioOwnerToOrdinaryEcho: true,
                removeProviderViewMessage: "数字人已暂停"
            )
            self.digitalHumanStatusDetailLabel.text = "数字人已暂停"
            self.isSuspendedByAppLifecycle = false
            self.isStoppingVoiceCaptureForAppLifecycle = false
            self.resetToLifecyclePausedIdle()
            self.recordEchoRuntimeDiagnosticsSnapshot(reason: "digitalHumanReleasedAfterBackgroundGrace")
            print("[TencentDigitalHuman] released cloud session after background grace period")
        }
        digitalHumanBackgroundReleaseWorkItem = workItem
        let gracePeriod = digitalHumanBackgroundReleaseGracePeriod
        DispatchQueue.main.asyncAfter(
            deadline: .now() + gracePeriod,
            execute: workItem
        )
        PrivacySafeDiagnostics.log(
            subsystem: "TencentDigitalHuman",
            event: "backgroundReleaseScheduled",
            counts: ["graceMs": Int(gracePeriod * 1_000)],
            correlations: ["context": contextKey]
        )
    }

    private var digitalHumanBackgroundReleaseGracePeriod: TimeInterval {
#if UI_QA_SIMULATOR && targetEnvironment(simulator)
        if QALaunchConfiguration.shared.contains("DJRunEchoDigitalHumanLifecycleSmoke") {
            return 0.45
        }
#endif
        return Self.tencentDigitalHumanBackgroundReleaseGracePeriod
    }

    private var isDigitalHumanRuntimeEligibleForBackgroundRelease: Bool {
        if digitalHumanRuntime is TencentDigitalHumanCloudRuntime {
            return true
        }
#if UI_QA_SIMULATOR && targetEnvironment(simulator)
        return QALaunchConfiguration.shared.contains("DJRunEchoDigitalHumanLifecycleSmoke")
            && digitalHumanRuntime is TencentDigitalHumanRuntimeStub
#else
        return false
#endif
    }

    private func cancelCloudDigitalHumanBackgroundRelease(reason: String) {
        guard let workItem = digitalHumanBackgroundReleaseWorkItem else {
            return
        }
        workItem.cancel()
        digitalHumanBackgroundReleaseWorkItem = nil
        digitalHumanLifecycle.cancelBackgroundReleaseLease()
        print("[TencentDigitalHuman] cancelled background session release reason=\(reason)")
    }

    private func restoreEchoAfterAppLifecycleIfNeeded(reason: String) {
        cancelCloudDigitalHumanBackgroundRelease(reason: "restore:\(reason)")
        guard isSuspendedByAppLifecycle else {
            return
        }

        guard bindDialogEngineToEchoAccountLease(reason: "appLifecycleRestore:\(reason)") else {
            isSuspendedByAppLifecycle = false
            isStoppingVoiceCaptureForAppLifecycle = false
            return
        }

        isSuspendedByAppLifecycle = false
        isStoppingVoiceCaptureForAppLifecycle = false
        DialogEngineManager.shared.delegate = self

        if shouldShowDigitalHumanLivePanel {
            setDialogEngineLocalTTSPlaybackEnabled(false)
            if digitalHumanRuntime == nil {
                hasRequestedCloudDigitalHumanRuntime = false
                prepareCloudDigitalHumanRuntimeIfNeeded()
            } else {
                applyEchoAudioRoutePolicy()
            }
        } else {
            setDialogEngineLocalTTSPlaybackEnabled(true)
        }

        loadVoiceCloneRuntimeCapabilityIfNeeded(force: true)
        resetToLifecyclePausedIdle()
        recordEchoRuntimeDiagnosticsSnapshot(reason: "appLifecycleRestored:\(reason)")
        print(
            "[TencentDigitalHuman] app lifecycle restored reason=\(reason) " +
            "microphoneAutoStart=false \(currentEchoAudioOwner.logLabel)"
        )
    }

    private func prepareCloudDigitalHumanRuntimeAfterForegroundIfNeeded(reason: String) {
        guard view.window != nil,
              shouldShowDigitalHumanLivePanel,
              digitalHumanRuntime == nil,
              hasRequestedCloudDigitalHumanRuntime == false else {
            return
        }

        setDialogEngineLocalTTSPlaybackEnabled(false)
        prepareCloudDigitalHumanRuntimeIfNeeded()
        loadVoiceCloneRuntimeCapabilityIfNeeded(force: true)
        recordEchoRuntimeDiagnosticsSnapshot(reason: "digitalHumanForegroundPrepare:\(reason)")
        print("[TencentDigitalHuman] preparing cloud session after foreground reason=\(reason)")
    }

    private var isCurrentEchoInteractionIdle: Bool {
        if case .idle = currentState {
            return true
        }
        return false
    }

    private func resetToLifecyclePausedIdle() {
        resetEchoViewModelToIdle()
        DispatchQueue.main.async { [weak self] in
            self?.renderVoiceStatus(
                text: "已暂停，轻点话筒继续",
                isVisible: true,
                accessibilityIdentifier: "echoLifecyclePausedStatus"
            )
        }
    }

    private func activateDigitalHumanSessionLease(
        _ contract: DigitalHumanSessionContract,
        lifecycleToken: DigitalHumanLifecycleToken,
        runtimeSessionCallback: EchoRuntimeCallbackToken
    ) {
        guard let accountLease = echoAccountLease,
              validateEchoAccountLease(
                at: .commit,
                expected: accountLease,
                reason: "activateDigitalHumanSessionLease"
              ) else {
            return
        }
        if let activeContract = activeDigitalHumanSessionContract,
           activeContract.sessionId != contract.sessionId {
            let replacedAccountLease = activeDigitalHumanSessionAccountLease
            activeDigitalHumanSessionContract = nil
            activeDigitalHumanSessionAccountLease = nil
            cancelDigitalHumanSessionHeartbeat(reason: "replaceActiveSession")
            releaseDigitalHumanSessionLease(
                activeContract,
                accountLease: replacedAccountLease,
                reason: "replacedByNewSession"
            )
        }

        activeDigitalHumanSessionContract = contract
        activeDigitalHumanSessionAccountLease = accountLease
        digitalHumanSessionHeartbeatFailureCount = 0
        scheduleDigitalHumanSessionHeartbeat(
            for: contract,
            lifecycleToken: lifecycleToken,
            runtimeSessionCallback: runtimeSessionCallback
        )
        if let lease = contract.lease {
            PrivacySafeDiagnostics.log(
                subsystem: "TencentDigitalHuman",
                event: "sessionLeaseActivated",
                states: ["reused": lease.reused ? "true" : "false"],
                counts: ["heartbeatSeconds": lease.heartbeatIntervalSeconds],
                correlations: ["session": contract.sessionId]
            )
        } else {
            PrivacySafeDiagnostics.log(
                subsystem: "TencentDigitalHuman",
                event: "sessionLeaseMissing"
            )
        }
    }

    private func scheduleDigitalHumanSessionHeartbeat(
        for contract: DigitalHumanSessionContract,
        lifecycleToken: DigitalHumanLifecycleToken,
        runtimeSessionCallback: EchoRuntimeCallbackToken,
        delayOverride: TimeInterval? = nil
    ) {
        cancelDigitalHumanSessionHeartbeat(reason: "reschedule")
        guard let accountLease = activeDigitalHumanSessionAccountLease,
              validateEchoAccountLease(
                at: .request,
                expected: accountLease,
                reason: "scheduleDigitalHumanSessionHeartbeat"
              ),
              let lease = contract.lease,
              lease.isUsable(at: Date()) else {
            return
        }

        let delay = delayOverride ?? TimeInterval(max(10, lease.heartbeatIntervalSeconds))
        let sessionId = contract.sessionId
        let workItem = DispatchWorkItem { [weak self] in
            guard let self,
                  self.validateEchoAccountLease(
                    at: .timer,
                    expected: accountLease,
                    reason: "digitalHumanSessionHeartbeat"
                  ),
                  self.activeDigitalHumanSessionContract?.sessionId == sessionId,
                  self.isCurrentDigitalHumanSessionToken(
                    lifecycleToken,
                    reason: "digitalHumanSessionHeartbeat"
                  ),
                  self.isCurrentEchoRuntimeSessionCallback(
                    runtimeSessionCallback,
                    reason: "digitalHumanSessionHeartbeat"
                  ) else {
                return
            }
            self.digitalHumanSessionHeartbeatWorkItem = nil
            let leaseRequest = DigitalHumanSessionLeaseOperationRequest(
                accountLease: accountLease,
                contract: contract
            )
            self.digitalHumanSessionClient.heartbeatDigitalHumanSession(leaseRequest) { [weak self] result in
                guard let self,
                      self.validateEchoAccountLease(
                        at: .ui,
                        expected: accountLease,
                        reason: "digitalHumanSessionHeartbeatResponse"
                      ),
                      self.activeDigitalHumanSessionContract?.sessionId == sessionId,
                      self.isCurrentDigitalHumanSessionToken(
                        lifecycleToken,
                        reason: "digitalHumanSessionHeartbeatResponse"
                      ),
                      self.isCurrentEchoRuntimeSessionCallback(
                        runtimeSessionCallback,
                        reason: "digitalHumanSessionHeartbeatResponse"
                      ) else {
                    return
                }
                switch result {
                case .success(let operation):
                    guard operation.sessionId == sessionId,
                          operation.lease.isUsable(at: Date()),
                          var refreshedContract = self.activeDigitalHumanSessionContract,
                          refreshedContract.sessionId == sessionId else {
                        self.degradeTencentDigitalHumanRoute(
                            reason: "digital_human_session_heartbeat_invalid_lease"
                        )
                        return
                    }
                    refreshedContract.replaceLease(operation.lease)
                    guard self.echoRuntimeSessionCoordinator.renewSession(
                        runtimeSessionCallback,
                        expiresAt: operation.lease.expiresAt
                    ) == .accepted else {
                        self.degradeTencentDigitalHumanRoute(
                            reason: "digital_human_session_heartbeat_renewal_rejected"
                        )
                        return
                    }
                    self.activeDigitalHumanSessionContract = refreshedContract
                    self.digitalHumanSessionHeartbeatFailureCount = 0
                    self.scheduleDigitalHumanSessionHeartbeat(
                        for: refreshedContract,
                        lifecycleToken: lifecycleToken,
                        runtimeSessionCallback: runtimeSessionCallback
                    )
                    PrivacySafeDiagnostics.log(
                        subsystem: "TencentDigitalHuman",
                        event: "sessionLeaseHeartbeatSucceeded",
                        states: ["status": operation.lease.status],
                        correlations: ["session": operation.sessionId]
                    )
                case .failure(let error):
                    self.digitalHumanSessionHeartbeatFailureCount += 1
                    let isInactive = self.isInactiveDigitalHumanSessionLeaseError(error)
                    PrivacySafeDiagnostics.log(
                        subsystem: "TencentDigitalHuman",
                        event: "sessionLeaseHeartbeatFailed",
                        states: ["failure": "transportOrLeaseFailure"],
                        counts: ["attempt": self.digitalHumanSessionHeartbeatFailureCount],
                        correlations: ["session": sessionId]
                    )
                    if isInactive || self.digitalHumanSessionHeartbeatFailureCount >= 3 {
                        self.degradeTencentDigitalHumanRoute(
                            reason: isInactive
                                ? "digital_human_session_lease_inactive"
                                : "digital_human_session_heartbeat_failed"
                        )
                    } else {
                        self.scheduleDigitalHumanSessionHeartbeat(
                            for: contract,
                            lifecycleToken: lifecycleToken,
                            runtimeSessionCallback: runtimeSessionCallback,
                            delayOverride: 5
                        )
                    }
                }
            }
        }
        digitalHumanSessionHeartbeatWorkItem = workItem
        DispatchQueue.main.asyncAfter(deadline: .now() + delay, execute: workItem)
    }

    private func cancelDigitalHumanSessionHeartbeat(reason: String) {
        guard digitalHumanSessionHeartbeatWorkItem != nil else {
            return
        }
        digitalHumanSessionHeartbeatWorkItem?.cancel()
        digitalHumanSessionHeartbeatWorkItem = nil
        PrivacySafeDiagnostics.log(
            subsystem: "TencentDigitalHuman",
            event: "sessionLeaseHeartbeatCancelled",
            states: ["reason": reason]
        )
    }

    private func releaseActiveDigitalHumanSessionLease(reason: String) {
        cancelDigitalHumanSessionHeartbeat(reason: "release:\(reason)")
        digitalHumanSessionHeartbeatFailureCount = 0
        guard let contract = activeDigitalHumanSessionContract else {
            return
        }
        let accountLease = activeDigitalHumanSessionAccountLease
        activeDigitalHumanSessionContract = nil
        activeDigitalHumanSessionAccountLease = nil
        releaseDigitalHumanSessionLease(
            contract,
            accountLease: accountLease,
            reason: reason
        )
    }

    private func releaseDigitalHumanSessionLease(
        _ contract: DigitalHumanSessionContract,
        accountLease: AccountLease?,
        reason: String
    ) {
        guard contract.lease != nil, let accountLease else { return }
        guard activeDigitalHumanSessionContract?.sessionId != contract.sessionId else {
            PrivacySafeDiagnostics.log(
                subsystem: "TencentDigitalHuman",
                event: "sessionLeaseReleaseSkipped",
                states: ["reason": reason],
                correlations: ["session": contract.sessionId]
            )
            return
        }
        guard let authorizationLease = echoAccountLease,
              authorizationLease.subjectId == accountLease.subjectId,
              authorizationLease.vaultId == accountLease.vaultId,
              contract.userId.isEmpty || contract.userId == accountLease.subjectId,
              validateEchoAccountLease(
                at: .request,
                expected: authorizationLease,
                reason: "releaseDigitalHumanSessionLease:\(reason)"
              ) else {
            enqueueDeferredDigitalHumanSessionRelease(
                contract,
                accountLease: accountLease,
                reason: reason
            )
            return
        }
        performDigitalHumanSessionRelease(
            contract,
            accountLease: authorizationLease,
            originatingAccountLease: accountLease,
            reason: reason
        )
    }

    private func performDigitalHumanSessionRelease(
        _ contract: DigitalHumanSessionContract,
        accountLease: AccountLease,
        originatingAccountLease: AccountLease,
        reason: String
    ) {
        let leaseRequest = DigitalHumanSessionLeaseOperationRequest(
            accountLease: accountLease,
            contract: contract,
            reason: reason
        )
        digitalHumanSessionClient.releaseDigitalHumanSession(leaseRequest) { [weak self] result in
            guard let self else { return }
            switch result {
            case .success(let operation):
                self.deferredDigitalHumanSessionReleases.removeAll {
                    $0.contract.sessionId == contract.sessionId
                }
                PrivacySafeDiagnostics.log(
                    subsystem: "TencentDigitalHuman",
                    event: "sessionLeaseReleased",
                    states: [
                        "status": operation.status,
                        "reason": reason,
                    ],
                    correlations: ["session": operation.sessionId]
                )
            case .failure:
                self.enqueueDeferredDigitalHumanSessionRelease(
                    contract,
                    accountLease: originatingAccountLease,
                    reason: "retryAfterFailure:\(reason)"
                )
                PrivacySafeDiagnostics.log(
                    subsystem: "TencentDigitalHuman",
                    event: "sessionLeaseReleaseFailed",
                    states: [
                        "failure": "transportOrLeaseFailure",
                        "reason": reason,
                    ],
                    correlations: [
                        "session": contract.sessionId,
                        "account": accountLease.subjectId,
                    ]
                )
            }
        }
    }

    private func enqueueDeferredDigitalHumanSessionRelease(
        _ contract: DigitalHumanSessionContract,
        accountLease: AccountLease,
        reason: String
    ) {
        guard deferredDigitalHumanSessionReleases.contains(where: {
            $0.contract.sessionId == contract.sessionId
        }) == false else { return }
        if deferredDigitalHumanSessionReleases.count >= 8 {
            deferredDigitalHumanSessionReleases.removeFirst()
        }
        deferredDigitalHumanSessionReleases.append(
            DeferredDigitalHumanSessionRelease(
                contract: contract,
                originatingAccountLease: accountLease,
                reason: reason
            )
        )
        PrivacySafeDiagnostics.log(
            subsystem: "TencentDigitalHuman",
            event: "sessionLeaseReleaseDeferred",
            states: ["reason": reason],
            correlations: [
                "session": contract.sessionId,
                "account": accountLease.subjectId,
            ]
        )
    }

    private func drainDeferredDigitalHumanSessionReleases(
        authorizationLease: AccountLease
    ) {
        guard validateEchoAccountLease(
            at: .request,
            expected: authorizationLease,
            reason: "drainDeferredDigitalHumanSessionReleases"
        ) else { return }
        let matching = deferredDigitalHumanSessionReleases.filter {
            $0.originatingAccountLease.subjectId == authorizationLease.subjectId
                && $0.originatingAccountLease.vaultId == authorizationLease.vaultId
        }
        guard matching.isEmpty == false else { return }
        deferredDigitalHumanSessionReleases.removeAll { deferred in
            matching.contains { $0.contract.sessionId == deferred.contract.sessionId }
        }
        for deferred in matching {
            performDigitalHumanSessionRelease(
                deferred.contract,
                accountLease: authorizationLease,
                originatingAccountLease: deferred.originatingAccountLease,
                reason: "deferred:\(deferred.reason)"
            )
        }
    }

    private func isInactiveDigitalHumanSessionLeaseError(_ error: Error) -> Bool {
        guard let clientError = error as? DreamJourneyBackendClient.ClientError else {
            return false
        }
        guard case .backendError(let statusCode, let context) = clientError else {
            return false
        }
        return statusCode == 404
            || statusCode == 409
            || context.code == "digital_human_session_lease_inactive"
            || context.detail.contains("digital_human_session_lease_inactive")
    }

    private func releaseDigitalHumanRuntime(
        reason: String,
        resetsAudioOwnerToOrdinaryEcho: Bool,
        removeProviderViewMessage: String? = nil,
        recordsDiagnostics: Bool = true
    ) {
        echoRuntimeSessionCoordinator.releaseRuntime()
        cancelCloudDigitalHumanBackgroundRelease(reason: "runtimeRelease:\(reason)")
        cancelDigitalHumanRuntimeRecovery()
        releaseActiveDigitalHumanSessionLease(reason: reason)
        pendingDigitalHumanSessionRequestID = nil
        pendingDigitalHumanSessionContextKey = nil
        cancelDigitalHumanReplyPrewarm()
        cancelTencentDigitalHumanTextOverTimeout()
        resetDigitalHumanReplyDispatchState()
        stopDigitalHumanAudioLevelMetering()

        let runtime = digitalHumanRuntime
        let didReleaseRuntime = runtime != nil
        runtime?.interrupt()
        runtime?.close()
        digitalHumanRuntime = nil
        digitalHumanRuntimeContextKey = nil
        digitalHumanRuntimeLifecycleGeneration = nil
        hasRequestedCloudDigitalHumanRuntime = false

        if let removeProviderViewMessage {
            digitalHumanLivePanelView?.removeHostedProviderView(showFallbackMessage: removeProviderViewMessage)
        }
        // Runtime teardown must retire only Tencent's observed playback lease. This keeps
        // a role switch, fallback, or background release from leaving the old provider
        // session visible as the current audio owner in diagnostics.
        releaseEchoAudioOwnerLease(
            expectedOwner: .tencentDigitalHumanPlayback,
            reason: "runtimeReleased:\(reason)"
        )
        if resetsAudioOwnerToOrdinaryEcho {
            if scopedActiveLiveAudioRoute == .tencentDigitalHuman {
                markPinnedLiveAudioRouteUnavailable(reason: "runtimeReleased:\(reason)")
            } else {
                setDialogEngineLocalTTSPlaybackEnabled(true)
                setEchoAudioOwner(.volcengineLocalTTS, reason: "release:\(reason)")
            }
        }
        if recordsDiagnostics {
            recordEchoRuntimeDiagnosticsSnapshot(reason: "digitalHumanRuntimeReleased:\(reason)")
        }
        if didReleaseRuntime {
            print(
                "[TencentDigitalHuman] released provider session reason=release:\(reason) " +
                "ordinaryEchoFallback=\(resetsAudioOwnerToOrdinaryEcho) \(currentEchoAudioOwner.logLabel)"
            )
        }
    }

    private func currentDigitalHumanRuntimeContextKey() -> String {
        digitalHumanRuntimeContextKey(for: DigitalHumanContextStore.shared.current)
    }

    @discardableResult
    private func captureEchoAccountLease(reason: String) -> AccountLease? {
        let previousAccountLease = echoAccountLease
        guard let subjectId = UserManager.shared.currentUser?.id,
              let accountLease = accountLeaseRuntime.capture(forSubjectId: subjectId) else {
            if previousAccountLease != nil {
                releaseDialogEngineBinding()
            }
            echoAccountLease = nil
            presentedLiveMemoryProductSessionID = nil
            presentedLiveMemoryAccountLease = nil
            activeLiveMemoryRecoveryCoordinator = nil
            print("[Echo][AccountLease] capture rejected reason=\(reason)")
            return nil
        }
        echoAccountLease = accountLease
        if previousAccountLease != accountLease {
            presentedLiveMemoryProductSessionID = nil
            presentedLiveMemoryAccountLease = nil
            activeLiveMemoryRecoveryCoordinator = nil
        }
        guard validateEchoAccountLease(
            at: .request,
            expected: accountLease,
            reason: "capture:\(reason)"
        ) else {
            releaseDialogEngineBinding()
            echoAccountLease = nil
            return nil
        }
        drainDeferredDigitalHumanSessionReleases(authorizationLease: accountLease)
        return accountLease
    }

    private func validateEchoAccountLease(
        at checkpoint: AccountLeaseCheckpoint,
        reason: String
    ) -> Bool {
        guard let accountLease = echoAccountLease else {
            print(
                "[Echo][AccountLease] rejected checkpoint=\(checkpoint.rawValue) " +
                "reason=\(reason) cause=missingLease"
            )
            return false
        }
        return validateEchoAccountLease(
            at: checkpoint,
            expected: accountLease,
            reason: reason
        )
    }

    private func validateEchoAccountLease(
        at checkpoint: AccountLeaseCheckpoint,
        expected accountLease: AccountLease,
        reason: String
    ) -> Bool {
        guard
              accountLease == echoAccountLease,
              accountLease.subjectId == UserManager.shared.currentUser?.id else {
            print(
                "[Echo][AccountLease] rejected checkpoint=\(checkpoint.rawValue) " +
                "reason=\(reason) cause=ownerMismatch"
            )
            return false
        }
        let decision = accountLeaseRuntime.validate(accountLease, at: checkpoint)
        guard decision.allowed else {
            print(
                "[Echo][AccountLease] rejected checkpoint=\(checkpoint.rawValue) " +
                "reason=\(reason) cause=\(decision.reason.rawValue)"
            )
            return false
        }
        return true
    }

    private func validateDelayedReplyCallsiteContext(
        _ callsiteContext: EchoDelayedReplyCallsiteContext,
        at checkpoint: AccountLeaseCheckpoint,
        reason: String
    ) -> Bool {
        guard callsiteContext.accountLease == echoAccountLease,
              callsiteContext.resourceOwnerId == callsiteContext.accountLease.subjectId,
              viewModel.matchesPendingDelayedReplyContext(callsiteContext),
              digitalHumanRuntimeContextKey(for: DigitalHumanContextStore.shared.current)
                == callsiteContext.roleContextKey,
              validateEchoAccountLease(
                  at: checkpoint,
                  expected: callsiteContext.accountLease,
                  reason: "delayedReply:\(reason)"
              ) else {
            print(
                "[Echo][DelayedReply] rejected checkpoint=\(checkpoint.rawValue) " +
                "reason=\(reason) operationId=\(callsiteContext.operationId)"
            )
            return false
        }
        return true
    }

    @discardableResult
    private func markEchoReplyDelivered() -> Bool {
        guard let echoAccountLease,
              validateEchoAccountLease(
                  at: .commit,
                  expected: echoAccountLease,
                  reason: "markReplyDelivered"
              ) else {
            return false
        }
        return viewModel.markReplyDelivered(accountLease: echoAccountLease)
    }

    private func refreshDelayedReplyAnswerReconciliation(reason: String) {
        guard isEchoDelayedReplyProductEnabled,
              let echoAccountLease,
              validateEchoAccountLease(
                at: .request,
                expected: echoAccountLease,
                reason: "delayedReplyAnswerReconciliation:\(reason)"
              ) else {
            return
        }
        let roleContextKey = digitalHumanRuntimeContextKey(
            for: DigitalHumanContextStore.shared.current
        )
        _ = viewModel.restoreStoredDelayedReplyIfAvailable(
            accountLease: echoAccountLease,
            resourceOwnerId: echoAccountLease.subjectId,
            roleContextKey: roleContextKey
        )
        viewModel.reconcilePendingDelayedReplyAnswerIfQAGated(
            accountLease: echoAccountLease,
            roleContextKey: roleContextKey
        ) { [weak self] outcome in
            guard let self,
                  self.validateEchoAccountLease(
                    at: .ui,
                    expected: echoAccountLease,
                    reason: "delayedReplyAnswerReconciliationCompletion:\(reason)"
                  ) else {
                return
            }
            switch outcome {
            case .delivered:
                PrivacySafeDiagnostics.log(
                    subsystem: "Echo",
                    event: "delayedReplyAnswerReconciled",
                    states: ["source": "serverAnswer"]
                )
            case .serverAnswerNotReady, .serverReconciliationRequired, .serverReadFailed,
                    .inboxCommitFailed, .staleScope:
                PrivacySafeDiagnostics.log(
                    subsystem: "Echo",
                    event: "delayedReplyAnswerReconciliationDeferred",
                    states: ["reason": "\(outcome)"]
                )
            case .disabled, .notEligible:
                break
            }
        }
    }

    private func resetEchoViewModelToIdle() {
        guard let echoAccountLease,
              validateEchoAccountLease(
                  at: .commit,
                  expected: echoAccountLease,
                  reason: "resetToIdle"
              ) else {
            return
        }
        viewModel.resetToIdle(accountLease: echoAccountLease)
    }

    @discardableResult
    private func bindDialogEngineToEchoAccountLease(reason: String) -> Bool {
        guard validateEchoAccountLease(at: .request, reason: "dialogEngineBind:\(reason)") else {
            releaseDialogEngineBinding()
            return false
        }
        guard let echoAccountLease,
              let bindingHandle = DialogEngineManager.shared.bindAccountLease(
                echoAccountLease,
                ownerId: dialogEngineOwnerId
              ) else {
            releaseDialogEngineBinding()
            return false
        }
        dialogEngineBindingHandle = bindingHandle
        guard DialogEngineManager.shared.isCurrentBinding(bindingHandle) else {
            return false
        }
        _ = updateDialogEngineLocalTTSVoiceSelection(reason: "dialogEngineBind:\(reason)")
        return true
    }

    private func releaseDialogEngineBinding() {
        guard let bindingHandle = dialogEngineBindingHandle else { return }
        _ = DialogEngineManager.shared.unbindAccountLease(bindingHandle)
        dialogEngineBindingHandle = nil
    }

    private func ownsCurrentDialogEngineBinding() -> Bool {
        DialogEngineManager.shared.isCurrentBinding(dialogEngineBindingHandle)
    }

    @discardableResult
    private func setDialogEngineLocalTTSPlaybackEnabled(_ enabled: Bool) -> Bool {
        guard ownsCurrentDialogEngineBinding() else {
            print("[Echo][DialogEngine] ignored audio-owner mutation from stale binding")
            return false
        }
        return DialogEngineManager.shared.setLocalTTSPlaybackEnabled(enabled)
    }

    /// Keeps ordinary Echo's local TTS bound to the current role. Tencent
    /// audio-drive stays on its existing provider path because that route
    /// disables local SpeechEngine playback.
    @discardableResult
    private func updateDialogEngineLocalTTSVoiceSelection(reason: String) -> Bool {
        guard let bindingHandle = dialogEngineBindingHandle,
              ownsCurrentDialogEngineBinding(),
              validateEchoAccountLease(
                  at: .runtime,
                  expected: bindingHandle.accountLease,
                  reason: "dialogEngineVoiceSelection:\(reason)"
              ) else {
            return false
        }

        let context = DigitalHumanContextStore.shared.current
        let roleSelection = resolveEchoRoleVoiceProfileSelection()
        let isCloneCapabilityUsable = voiceCloneRuntimeCapability?.canSynthesize == true
        let selectedVoiceProfileId = isCloneCapabilityUsable
            ? roleSelection.voiceProfileId
            : nil
        let accepted = DialogEngineManager.shared.setLocalTTSVoiceSelection(
            voiceProfileId: selectedVoiceProfileId,
            contextKey: digitalHumanRuntimeContextKey(for: context),
            lifecycleGeneration: digitalHumanLifecycle.generation,
            for: bindingHandle
        )

        PrivacySafeDiagnostics.log(
            subsystem: "EchoVoiceSelection",
            event: "dialogEngineLocalTTSSelectionUpdated",
            states: [
                "reason": reason,
                "roleVoiceSource": roleSelection.source.rawValue,
                "cloneCapabilityUsable": String(isCloneCapabilityUsable),
                "profileSelected": String(selectedVoiceProfileId != nil),
                "accepted": String(accepted),
            ],
            correlations: ["context": digitalHumanRuntimeContextKey(for: context)]
        )
        return accepted
    }

    private func captureDigitalHumanLifecycleToken(reason: String) -> DigitalHumanLifecycleToken {
        let contextKey = currentDigitalHumanRuntimeContextKey()
        let previousGeneration = digitalHumanLifecycle.generation
        let token = digitalHumanLifecycle.token(for: contextKey)
        if token.generation != previousGeneration {
            isLoadingVoiceCloneRuntimeCapability = false
            PrivacySafeDiagnostics.log(
                subsystem: "TencentDigitalHuman",
                event: "lifecycleGenerationAdvanced",
                states: ["reason": reason],
                counts: [
                    "generation": Int(token.generation),
                    "interactionGeneration": Int(token.interactionGeneration),
                ],
                correlations: ["context": contextKey]
            )
        }
        return token
    }

    private func isCurrentDigitalHumanLifecycleToken(
        _ token: DigitalHumanLifecycleToken,
        reason: String
    ) -> Bool {
        let contextKey = currentDigitalHumanRuntimeContextKey()
        guard validateEchoAccountLease(at: .runtime, reason: reason),
              digitalHumanLifecycle.isCurrent(token, contextKey: contextKey) else {
            print(
                "[TencentDigitalHuman] ignored stale lifecycle callback " +
                "reason=\(reason) tokenGeneration=\(token.generation) " +
                "tokenInteraction=\(token.interactionGeneration) " +
                "currentGeneration=\(digitalHumanLifecycle.generation) " +
                "currentInteraction=\(digitalHumanLifecycle.interactionGeneration)"
            )
            return false
        }
        return true
    }

    private func isCurrentDigitalHumanSessionToken(
        _ token: DigitalHumanLifecycleToken,
        reason: String
    ) -> Bool {
        let contextKey = currentDigitalHumanRuntimeContextKey()
        guard validateEchoAccountLease(at: .runtime, reason: reason),
              digitalHumanLifecycle.isCurrentSession(token, contextKey: contextKey) else {
            print(
                "[TencentDigitalHuman] ignored stale lifecycle callback " +
                "reason=\(reason) sessionGeneration=\(token.generation) " +
                "currentGeneration=\(digitalHumanLifecycle.generation)"
            )
            return false
        }
        return true
    }

    private func isCurrentEchoRuntimeSessionCallback(
        _ callback: EchoRuntimeCallbackToken,
        reason: String
    ) -> Bool {
        let validation = echoRuntimeSessionCoordinator.validate(callback)
        guard validation == .accepted else {
            PrivacySafeDiagnostics.log(
                subsystem: "TencentDigitalHuman",
                event: "runtimeSessionCallbackIgnored",
                states: [
                    "reason": reason,
                    "validation": String(describing: validation),
                ],
                correlations: ["request": callback.requestID]
            )
            return false
        }
        return true
    }

    private func isCurrentEchoRuntimeSessionCallback(
        _ callback: EchoRuntimeCallbackToken?,
        reason: String
    ) -> Bool {
        guard let callback else {
            return true
        }
        return isCurrentEchoRuntimeSessionCallback(callback, reason: reason)
    }

    @discardableResult
    private func invalidateDigitalHumanLifecycle(reason: String) -> DigitalHumanLifecycleToken {
        echoRuntimeSessionCoordinator.invalidatePendingSessionRequest()
        let token = digitalHumanLifecycle.invalidate(
            contextKey: currentDigitalHumanRuntimeContextKey(),
            reason: reason
        )
        pendingDigitalHumanSessionRequestID = nil
        pendingDigitalHumanSessionContextKey = nil
        isLoadingVoiceCloneRuntimeCapability = false
        activeVoiceInteractionLifecycleToken = nil
        cancelActiveEchoContextBuild(reason: "digitalHumanLifecycle:\(reason)")
        cancelDigitalHumanReplyPrewarm()
        cancelTencentDigitalHumanTextOverTimeout()
        print(
            "[TencentDigitalHuman] invalidated lifecycle generation " +
            "reason=\(reason) generation=\(token.generation)"
        )
        return token
    }

    @discardableResult
    private func invalidateDigitalHumanInteraction(reason: String) -> DigitalHumanLifecycleToken {
        echoRuntimeSessionCoordinator.finishInteraction()
        let token = digitalHumanLifecycle.invalidateInteraction(
            contextKey: currentDigitalHumanRuntimeContextKey(),
            reason: reason
        )
        cancelActiveEchoContextBuild(reason: "digitalHumanInteraction:\(reason)")
        cancelDigitalHumanReplyPrewarm()
        cancelTencentDigitalHumanTextOverTimeout()
        print(
            "[TencentDigitalHuman] invalidated interaction generation " +
            "reason=\(reason) generation=\(token.generation) " +
            "interactionGeneration=\(token.interactionGeneration)"
        )
        return token
    }

    private func activeVoiceInteractionToken(reason: String) -> DigitalHumanLifecycleToken? {
        guard let token = activeVoiceInteractionLifecycleToken,
              ownsCurrentDialogEngineBinding(),
              isCurrentDigitalHumanLifecycleToken(token, reason: reason) else {
            print("[TencentDigitalHuman] ignored callback without an active voice interaction reason=\(reason)")
            return nil
        }
        return token
    }

    private func digitalHumanRuntimeContextKey(for context: DigitalHumanContext) -> String {
        [
            context.viewerUserId ?? "",
            context.ownerId.trimmingCharacters(in: .whitespacesAndNewlines),
            context.mode.rawValue,
            context.isSelfAssistant ? "self" : "family",
        ].joined(separator: "|")
    }

    private func isCurrentDigitalHumanSessionRequest(
        requestID: String,
        contextKey: String
    ) -> Bool {
        pendingDigitalHumanSessionRequestID == requestID
            && pendingDigitalHumanSessionContextKey == contextKey
            && currentDigitalHumanRuntimeContextKey() == contextKey
    }

    @discardableResult
    private func reconcileDigitalHumanRuntimeWithCurrentContext(reason: String) -> Bool {
        _ = captureDigitalHumanLifecycleToken(reason: "contextReconcile:\(reason)")
        let desiredContextKey = currentDigitalHumanRuntimeContextKey()
        if let pendingContextKey = pendingDigitalHumanSessionContextKey,
           pendingContextKey != desiredContextKey {
            PrivacySafeDiagnostics.log(
                subsystem: "TencentDigitalHuman",
                event: "staleSessionRequestInvalidated",
                states: ["reason": reason],
                correlations: [
                    "desiredContext": desiredContextKey,
                    "pendingContext": pendingContextKey,
                ]
            )
            pendingDigitalHumanSessionRequestID = nil
            pendingDigitalHumanSessionContextKey = nil
            hasRequestedCloudDigitalHumanRuntime = false
        }

        guard let runtimeContextKey = digitalHumanRuntimeContextKey,
              runtimeContextKey != desiredContextKey else {
            return false
        }

        guard view.window != nil else {
            PrivacySafeDiagnostics.log(
                subsystem: "TencentDigitalHuman",
                event: "staleRuntimeReleaseDeferred",
                states: ["reason": reason],
                correlations: [
                    "desiredContext": desiredContextKey,
                    "runtimeContext": runtimeContextKey,
                ]
            )
            return false
        }

        digitalHumanStatusDetailLabel.text = "正在切换回响对象"
        releaseDigitalHumanRuntime(
            reason: "contextChanged:\(reason)",
            resetsAudioOwnerToOrdinaryEcho: false,
            removeProviderViewMessage: "正在切换回响对象"
        )
        setDialogEngineLocalTTSPlaybackEnabled(false)
        setEchoAudioOwner(.fallbackMuted, reason: "contextChanged")
        lastEchoRuntimeFallbackReason = nil
        digitalHumanRuntimeRecoveryAttemptsByContext[desiredContextKey] = 0
        recordEchoRuntimeDiagnosticsSnapshot(reason: "digitalHumanContextChanged")
        return true
    }

    private func cancelDigitalHumanRuntimeRecovery() {
        digitalHumanRuntimeRecoveryWorkItem?.cancel()
        digitalHumanRuntimeRecoveryWorkItem = nil
    }

    private func scheduleCloudDigitalHumanRuntimeRecovery(reason: String, delay: TimeInterval) {
        guard shouldShowDigitalHumanLivePanel,
              view.window != nil,
              let accountLease = echoAccountLease,
              validateEchoAccountLease(
                at: .request,
                expected: accountLease,
                reason: "scheduleRuntimeRecovery:\(reason)"
              ),
              echoV4IdentityRouteDecision(
                for: DigitalHumanContextStore.shared.current,
                accountLease: accountLease
              ).route == .ownerPrivate else {
            return
        }

        let contextKey = currentDigitalHumanRuntimeContextKey()
        let lifecycleToken = captureDigitalHumanLifecycleToken(reason: "runtimeRecovery:\(reason)")
        cancelDigitalHumanRuntimeRecovery()
        digitalHumanStatusDetailLabel.text = "正在重新连接数字人"
        digitalHumanLivePanelView?.showProviderPlaceholder("正在重新连接数字人")

        let workItem = DispatchWorkItem { [weak self] in
            guard let self,
                  self.validateEchoAccountLease(
                    at: .timer,
                    expected: accountLease,
                    reason: "runtimeRecovery:\(reason)"
                  ),
                  self.isCurrentDigitalHumanSessionToken(
                    lifecycleToken,
                    reason: "runtimeRecovery:\(reason)"
                  ),
                  self.view.window != nil,
                  self.shouldShowDigitalHumanLivePanel,
                  self.digitalHumanRuntime == nil,
                  self.currentDigitalHumanRuntimeContextKey() == contextKey else {
                return
            }
            self.hasRequestedCloudDigitalHumanRuntime = false
            self.prepareCloudDigitalHumanRuntimeIfNeeded(lifecycleToken: lifecycleToken)
            self.recordEchoRuntimeDiagnosticsSnapshot(reason: "digitalHumanRuntimeRecovery:\(reason)")
            PrivacySafeDiagnostics.log(
                subsystem: "TencentDigitalHuman",
                event: "providerSessionRetrying",
                states: ["reason": reason],
                correlations: ["context": contextKey]
            )
        }
        digitalHumanRuntimeRecoveryWorkItem = workItem
        DispatchQueue.main.asyncAfter(deadline: .now() + delay, execute: workItem)
    }

    private func shouldRecoverFromDigitalHumanRuntimeFailure(reason: String) -> Bool {
        guard shouldShowDigitalHumanLivePanel,
              view.window != nil else {
            return false
        }
        guard !isDigitalHumanQuotaFailure(reason),
              reason == "tencent_cloud_open_failed" else {
            return false
        }

        let contextKey = currentDigitalHumanRuntimeContextKey()
        let attempts = digitalHumanRuntimeRecoveryAttemptsByContext[contextKey, default: 0]
        guard attempts < Self.tencentDigitalHumanOpenFailureRecoveryLimit else {
            return false
        }
        digitalHumanRuntimeRecoveryAttemptsByContext[contextKey] = attempts + 1
        return true
    }

    private func isDigitalHumanQuotaFailure(_ reason: String) -> Bool {
        reason == "tencent_cloud_quota_exceeded"
            || reason.localizedCaseInsensitiveContains("digital_human_session_capacity_exhausted")
            || reason.localizedCaseInsensitiveContains("LimitExceeded")
            || reason.localizedCaseInsensitiveContains("AssetConcurrencyQuotaNotFound")
            || reason.contains("超过配额")
            || reason.contains("配额已满")
    }

    private func updatePersonaBadge() {
        let context = DigitalHumanContextStore.shared.current
        if !context.isSelfAssistant {
            finishLiveMemoryCaptureIfNeeded()
        }
        let iconName = context.isSelfAssistant ? "sparkles" : "person.crop.circle.fill"
        let iconConfig = UIImage.SymbolConfiguration(pointSize: 22, weight: .semibold)
        personaIconView.image = UIImage(systemName: iconName, withConfiguration: iconConfig)
        personaAvatarView.backgroundColor = context.isSelfAssistant
            ? DJDesignTokens.Color.accent.withAlphaComponent(0.14)
            : DJDesignTokens.Color.accentDeep.withAlphaComponent(0.12)
        personaNameLabel.text = context.isSelfAssistant
            ? "自己 · AI 助手"
            : "\(context.resolvedDisplayName) · AI 数字分身"
        personaSubtitleLabel.text = EchoAIIdentityDisclosure.persistent.label
        personaBadgeView.accessibilityLabel = "\(personaNameLabel.text ?? "")，\(personaSubtitleLabel.text ?? "")"
        digitalHumanLivePanelView?.setPersona(
            name: personaNameLabel.text ?? context.resolvedDisplayName,
            subtitle: personaSubtitleLabel.text ?? ""
        )
    }

    private func seedTranscriptPreview() {
        if transcriptEntries.isEmpty { quoteLabel.text = makeContextualOpeningLine() }
    }

    private func refreshTranscriptPreviewForCurrentContextIfIdle() {
        guard case .idle = currentState else { return }
        seedTranscriptPreview()
    }

    private func makeContextualOpeningLine() -> String {
        let context = DigitalHumanContextStore.shared.current
        if context.isSelfAssistant {
            return "\"我是你的 AI 助手，不是真人。可以把自己的故事慢慢讲出来。\""
        }
        return "\"我是\(context.resolvedDisplayName)的 AI 数字分身，不是真人本人。想听你继续说说我们的故事。\""
    }

    private func appendTranscript(text: String, isUser: Bool) {
        transcriptEntries.append((text: text, isUser: isUser))
        if !isUser { quoteLabel.beginReply() }
        reloadTranscriptPreview()
        refreshConversationSheet()
    }

    private func reloadTranscriptPreview() {
        guard let latestEntry = transcriptEntries.last(where: { !$0.isUser }) else {
            return
        }
        quoteLabel.text = latestEntry.text
    }

    private func render(state: EchoInteractionState) {
        currentState = state
        switch state { case .speaking, .listening, .thinking: cloudOrb.speaking = true; default: cloudOrb.speaking = false }
        #if DEBUG
        if case .listening = state {
            let completion = voiceListeningCompletionForTesting
            voiceListeningCompletionForTesting = nil
            completion?()
        }
        #endif
        updateOwnerTruthInterviewNaturalInputProductEntryVisibility()
        renderDigitalHumanLivePanel(for: state)

        switch state {
        case .idle:
            renderVoiceStatus(text: nil, isVisible: false)
            configureMicButton(
                systemName: "mic.fill",
                backgroundColor: DJDesignTokens.Color.accentDeep,
                isEnabled: true,
                accessibilityLabel: "开始语音"
            )
            setMicPulse(active: false)
            if let captureState = currentLiveMemoryCapturePresentationState {
                renderLiveMemoryCaptureState(captureState)
            }
        case .starting:
            renderVoiceStatus(text: "正在准备麦克风", isVisible: true)
            configureMicButton(
                systemName: "stop.fill",
                backgroundColor: DJDesignTokens.Color.accentDeep,
                isEnabled: true,
                accessibilityLabel: "取消开启语音"
            )
            setMicPulse(active: false)
        case .listening:
            renderVoiceStatus(text: "我在听，您慢慢说", isVisible: true)
            configureMicButton(
                systemName: "stop.fill",
                backgroundColor: DJDesignTokens.Color.accentDeep,
                isEnabled: true,
                accessibilityLabel: "结束本次实时对话"
            )
            setMicPulse(active: true)
        case .thinking:
            renderVoiceStatus(text: "我在想一想", isVisible: true)
            configureMicButton(
                systemName: "stop.fill",
                backgroundColor: DJDesignTokens.Color.accentDeep,
                isEnabled: true,
                accessibilityLabel: "结束本次实时对话"
            )
            setMicPulse(active: true)
        case .waitingReply(let minutes):
            renderVoiceStatus(text: "先去窗边走走，约 \(minutes) 分钟后我再回信", isVisible: true)
            configureMicButton(
                systemName: "hourglass",
                backgroundColor: DJDesignTokens.Color.surfaceContainer,
                isEnabled: false,
                accessibilityLabel: "先去窗边走走，约 \(minutes) 分钟后我再回信"
            )
            setMicPulse(active: false)
        case .awaitingReplyDelivery:
            renderVoiceStatus(text: "回信生成中，准备好后会提醒您", isVisible: true)
            configureMicButton(
                systemName: "hourglass",
                backgroundColor: DJDesignTokens.Color.surfaceContainer,
                isEnabled: false,
                accessibilityLabel: "回信生成中，准备好后会提醒您"
            )
            setMicPulse(active: false)
        case .neutralSafety(let decision):
            quoteLabel.text = decision.responseText ?? EchoSafetyPolicy.neutralChineseCrisisResponse
            renderVoiceStatus(text: "请立即联系信任的真人", isVisible: true)
            configureMicButton(
                systemName: "mic.fill",
                backgroundColor: DJDesignTokens.Color.accentDeep,
                isEnabled: true,
                accessibilityLabel: "再次开始语音"
            )
            setMicPulse(active: false)
        case .speaking:
            renderVoiceStatus(text: "回响正在抵达", isVisible: true)
            configureMicButton(
                systemName: "stop.fill",
                backgroundColor: DJDesignTokens.Color.accentDeep,
                isEnabled: true,
                accessibilityLabel: "结束本次实时对话"
            )
            setMicPulse(active: true)
        case .replied:
            if isUserControlledLiveSessionOpen {
                renderVoiceStatus(text: "正在恢复聆听", isVisible: true)
                configureMicButton(
                    systemName: "stop.fill",
                    backgroundColor: DJDesignTokens.Color.accentDeep,
                    isEnabled: true,
                    accessibilityLabel: "结束本次实时对话"
                )
                setMicPulse(active: true)
            } else {
                renderVoiceStatus(text: "回信已抵达", isVisible: true)
                configureMicButton(
                    systemName: "mic.fill",
                    backgroundColor: DJDesignTokens.Color.accentDeep,
                    isEnabled: true,
                    accessibilityLabel: "开始语音"
                )
                setMicPulse(active: false)
            }
        case .error(let message):
            renderVoiceStatus(text: message, isVisible: true)
            configureMicButton(
                systemName: "mic.fill",
                backgroundColor: DJDesignTokens.Color.accentDeep,
                isEnabled: true,
                accessibilityLabel: "重新开始语音"
            )
            setMicPulse(active: false)
        }
    }

    private func renderDigitalHumanLivePanel(for state: EchoInteractionState) {
        let liveState: DigitalHumanLiveInteractionState
        switch state {
        case .idle:
            liveState = .idle
        case .starting, .listening:
            liveState = .listening
        case .thinking, .waitingReply, .awaitingReplyDelivery:
            liveState = .thinking
        case .neutralSafety:
            liveState = .idle
        case .speaking, .replied:
            liveState = .speaking
        case .error:
            liveState = .failed
        }
        digitalHumanLivePanelView?.setInteractionState(liveState)
        if liveState == .idle || liveState == .stopped || liveState == .failed {
            stopDigitalHumanAudioLevelMetering()
        }
    }

    private func startSDKTTSPlaybackFallback() {
        guard shouldShowDigitalHumanLivePanel else { return }
        digitalHumanAudioLevelMeter?.startSDKTTSPlaybackFallback()
    }

    private func cachedLipSyncTimelineForEchoReply(_ text: String) -> DigitalHumanLipSyncTimeline? {
        guard shouldShowDigitalHumanLivePanel else { return nil }
        return MemoirTTSService.shared.getCachedLipSyncTimeline(forText: text)
    }

    @discardableResult
    private func applyCachedLipSyncTimelineForEchoReply(_ text: String) -> Bool {
        guard let timeline = cachedLipSyncTimelineForEchoReply(text) else {
            return false
        }
        stopDigitalHumanAudioLevelMetering(resetLevel: false)
        digitalHumanLivePanelView?.applyPlaybackEvent(.visemeTimeline(timeline))
        return true
    }

    private func stopDigitalHumanAudioLevelMetering(resetLevel: Bool = true) {
        digitalHumanAudioLevelMeter?.stop(resetLevel: resetLevel)
    }

    private var tencentCloudRenderProvidesAudibleTTS: Bool {
        // Digital-human mode has a single audio owner: Tencent cloud render.
        // Ordinary Echo keeps the existing local Volcengine TTS path.
        return true
    }

    private var tencentDigitalHumanProviderCanOwnAudio: Bool {
        guard let digitalHumanRuntime,
              digitalHumanRuntimeLifecycleGeneration == digitalHumanLifecycle.generation,
              digitalHumanRuntime is TencentDigitalHumanCloudRuntime
                || ((shouldRunTencentBackendPCMDriveMockSmoke
                    || shouldRunVoiceCloneRuntimeFaultInjectionSmoke)
                    && digitalHumanRuntime is TencentDigitalHumanRuntimeStub),
              digitalHumanRuntime.profile != nil else {
            return false
        }
        switch digitalHumanRuntime.state {
        case .ready, .buffering, .speaking, .completed:
            return true
        default:
            return false
        }
    }

    private var tencentDigitalHumanAudioRouteReserved: Bool {
        guard shouldShowDigitalHumanLivePanel,
              let digitalHumanRuntime,
              digitalHumanRuntimeLifecycleGeneration == digitalHumanLifecycle.generation,
              digitalHumanRuntime is TencentDigitalHumanCloudRuntime
                || ((shouldRunTencentBackendPCMDriveMockSmoke
                    || shouldRunVoiceCloneRuntimeFaultInjectionSmoke)
                    && digitalHumanRuntime is TencentDigitalHumanRuntimeStub),
              digitalHumanRuntime.profile != nil,
              tencentCloudRenderProvidesAudibleTTS else {
            return false
        }
        switch digitalHumanRuntime.state {
        case .preparing, .connecting, .ready, .buffering, .speaking, .completed:
            return true
        default:
            return false
        }
    }

    private var scopedActiveLiveAudioRoute: EchoLiveAudioRoute? {
        guard isUserControlledLiveSessionOpen,
              let lease = activeLiveAudioRouteLease else {
            return nil
        }
        guard lease.accountGeneration == echoAccountLease?.generation,
              lease.contextKey == currentDigitalHumanRuntimeContextKey() else {
            return .unavailable(reason: "liveAudioRouteScopeChanged")
        }
        return lease.route
    }

    @discardableResult
    private func pinLiveAudioRouteIfNeeded(reason: String) -> EchoLiveAudioRoute {
        if let route = scopedActiveLiveAudioRoute {
            return route
        }
        guard isUserControlledLiveSessionOpen,
              let accountGeneration = echoAccountLease?.generation else {
            return .unavailable(reason: "liveAudioRouteSessionClosed")
        }

        let selectedRoute = EchoLiveAudioRoutePolicy.select(
            wantsDigitalHuman: shouldShowDigitalHumanLivePanel,
            providerCanOwnAudio: tencentDigitalHumanProviderCanOwnAudio
        )
        let localPlaybackEnabled = selectedRoute == .volcengineLocalTTS
        let committedRoute: EchoLiveAudioRoute
        if setDialogEngineLocalTTSPlaybackEnabled(localPlaybackEnabled) {
            committedRoute = selectedRoute
        } else {
            committedRoute = .unavailable(reason: "dialogPlayerConfigurationRejected")
        }
        activeLiveAudioRouteLease = EchoLiveAudioRouteLease(
            id: UUID(),
            route: committedRoute,
            accountGeneration: accountGeneration,
            contextKey: currentDigitalHumanRuntimeContextKey()
        )
        PrivacySafeDiagnostics.log(
            subsystem: "Echo",
            event: "liveAudioRoutePinned",
            states: [
                "route": committedRoute.diagnosticCode,
                "reason": reason,
                "providerReady": String(tencentDigitalHumanProviderCanOwnAudio),
                "localPlaybackEnabled": String(localPlaybackEnabled),
            ],
            correlations: ["routeLease": activeLiveAudioRouteLease?.id.uuidString]
        )
        return committedRoute
    }

    private func markPinnedLiveAudioRouteUnavailable(reason: String) {
        guard let lease = activeLiveAudioRouteLease else { return }
        activeLiveAudioRouteLease = EchoLiveAudioRouteLease(
            id: lease.id,
            route: .unavailable(reason: reason),
            accountGeneration: lease.accountGeneration,
            contextKey: lease.contextKey
        )
        setEchoAudioOwner(.fallbackMuted, reason: reason)
        PrivacySafeDiagnostics.log(
            subsystem: "Echo",
            event: "liveAudioRouteUnavailable",
            states: ["reason": reason],
            correlations: ["routeLease": lease.id.uuidString]
        )
    }

    private func beginLivePlaybackReceipt(
        route: EchoLiveAudioRoute,
        turnID: String,
        lifecycleToken: DigitalHumanLifecycleToken,
        answerCharacterCount: Int
    ) {
        switch route {
        case .volcengineLocalTTS, .tencentDigitalHuman:
            break
        case .unavailable:
            return
        }

        cancelLivePlaybackReceipt(reason: "superseded")
        let receipt = EchoLivePlaybackReceipt(
            id: UUID(),
            state: EchoLivePlaybackReceiptState(route: route),
            turnID: turnID,
            lifecycleToken: lifecycleToken,
            submittedAt: Date(),
            answerCharacterCount: max(0, answerCharacterCount)
        )
        pendingLivePlaybackReceipt = receipt
        scheduleLivePlaybackAcceptanceTimeout(receiptID: receipt.id)
        PrivacySafeDiagnostics.log(
            subsystem: "Echo",
            event: "liveAnswerSubmitted",
            states: ["route": route.diagnosticCode],
            counts: [
                "providerAcceptanceTimeoutMs": Int(Self.livePlaybackProviderAcceptanceTimeout * 1_000),
                "answerCharacterCount": receipt.answerCharacterCount,
                "elapsedMsSinceSubmit": 0,
            ],
            correlations: [
                "receiptID": receipt.id.uuidString,
                "turnID": turnID,
                "replyID": nil,
                "lifecycleGeneration": String(lifecycleToken.generation),
            ]
        )
    }

    private func cancelLivePlaybackReceipt(reason: String) {
        livePlaybackAcceptanceTimeoutWorkItem?.cancel()
        livePlaybackAcceptanceTimeoutWorkItem = nil
        livePlaybackTerminalWatchdogWorkItem?.cancel()
        livePlaybackTerminalWatchdogWorkItem = nil
        guard let receipt = pendingLivePlaybackReceipt else { return }
        pendingLivePlaybackReceipt = nil
        PrivacySafeDiagnostics.log(
            subsystem: "Echo",
            event: "livePlaybackReceiptCancelled",
            states: [
                "route": receipt.state.route.diagnosticCode,
                "reason": reason,
            ],
            correlations: [
                "receiptID": receipt.id.uuidString,
                "turnID": receipt.turnID,
                "replyID": receipt.state.replyID,
                "lifecycleGeneration": String(receipt.lifecycleToken.generation),
            ]
        )
    }

    private func scheduleLivePlaybackAcceptanceTimeout(receiptID: UUID) {
        livePlaybackAcceptanceTimeoutWorkItem?.cancel()
        let workItem = DispatchWorkItem { [weak self] in
            self?.handleLivePlaybackAcceptanceTimeout(receiptID: receiptID)
        }
        livePlaybackAcceptanceTimeoutWorkItem = workItem
        DispatchQueue.main.asyncAfter(
            deadline: .now() + Self.livePlaybackProviderAcceptanceTimeout,
            execute: workItem
        )
    }

    private func scheduleLivePlaybackTerminalWatchdog(receiptID: UUID) {
        livePlaybackAcceptanceTimeoutWorkItem?.cancel()
        livePlaybackAcceptanceTimeoutWorkItem = nil
        livePlaybackTerminalWatchdogWorkItem?.cancel()
        let workItem = DispatchWorkItem { [weak self] in
            self?.handleLivePlaybackTerminalWatchdog(receiptID: receiptID)
        }
        livePlaybackTerminalWatchdogWorkItem = workItem
        DispatchQueue.main.asyncAfter(
            deadline: .now() + Self.livePlaybackTerminalWatchdogTimeout,
            execute: workItem
        )
    }

    private func acknowledgeLivePlaybackStarted(route: EchoLiveAudioRoute) {
        guard var receipt = pendingLivePlaybackReceipt,
              receipt.state.acknowledgeStart(for: route),
              isCurrentDigitalHumanLifecycleToken(
                receipt.lifecycleToken,
                reason: "livePlaybackStarted"
              ) else {
            return
        }
        pendingLivePlaybackReceipt = receipt
        scheduleLivePlaybackTerminalWatchdog(receiptID: receipt.id)
        PrivacySafeDiagnostics.log(
            subsystem: "Echo",
            event: "livePlaybackStarted",
            states: ["route": route.diagnosticCode],
            correlations: [
                "receipt": receipt.id.uuidString,
                "turn": receipt.turnID,
            ]
        )
        PrivacySafeDiagnostics.log(
            subsystem: "Echo",
            event: "livePlaybackWatchdogAdvanced",
            states: ["stage": "terminal", "route": route.diagnosticCode],
            correlations: ["receipt": receipt.id.uuidString]
        )
    }

    @discardableResult
    private func completeLivePlaybackReceipt(route: EchoLiveAudioRoute) -> Bool {
        guard let receipt = pendingLivePlaybackReceipt else { return false }
        guard receipt.state.route == route else {
            PrivacySafeDiagnostics.log(
                subsystem: "Echo",
                event: "livePlaybackCompletionIgnored",
                states: [
                    "callbackRoute": route.diagnosticCode,
                    "pendingRoute": receipt.state.route.diagnosticCode,
                    "reason": "routeMismatch",
                ],
                correlations: ["receipt": receipt.id.uuidString]
            )
            return false
        }
        guard receipt.state.canComplete(for: route) else {
            PrivacySafeDiagnostics.log(
                subsystem: "Echo",
                event: "livePlaybackCompletionIgnored",
                states: ["reason": "terminalReceiptNotReached"],
                correlations: ["receipt": receipt.id.uuidString]
            )
            return false
        }

        livePlaybackAcceptanceTimeoutWorkItem?.cancel()
        livePlaybackAcceptanceTimeoutWorkItem = nil
        livePlaybackTerminalWatchdogWorkItem?.cancel()
        livePlaybackTerminalWatchdogWorkItem = nil
        pendingLivePlaybackReceipt = nil
        PrivacySafeDiagnostics.log(
            subsystem: "Echo",
            event: "livePlaybackCompleted",
            states: [
                "route": route.diagnosticCode,
                "terminalCause": EchoLivePlaybackTerminalCause.finished.diagnosticCode,
            ],
            counts: [
                "answerCharacterCount": receipt.answerCharacterCount,
                "elapsedMsSinceSubmit": Int(Date().timeIntervalSince(receipt.submittedAt) * 1_000),
            ],
            correlations: [
                "receiptID": receipt.id.uuidString,
                "turnID": receipt.turnID,
                "replyID": receipt.state.replyID,
                "lifecycleGeneration": String(receipt.lifecycleToken.generation),
            ]
        )
        return true
    }

    private func handleDelegatedPlaybackProgress(
        _ progress: DialogEngineDelegatedPlaybackProgress,
        route: EchoLiveAudioRoute
    ) {
        guard var receipt = pendingLivePlaybackReceipt,
              receipt.state.route == route,
              isCurrentDigitalHumanLifecycleToken(
                receipt.lifecycleToken,
                reason: "delegatedPlaybackProgress"
              ) else {
            PrivacySafeDiagnostics.log(
                subsystem: "Echo",
                event: "delegatedPlaybackProgressIgnored",
                states: [
                    "route": route.diagnosticCode,
                    "reason": "receiptOrLifecycleMismatch",
                ],
                correlations: ["reply": progress.replyID]
            )
            return
        }

        guard receipt.state.apply(progress, callbackRoute: route) else {
            PrivacySafeDiagnostics.log(
                subsystem: "Echo",
                event: "delegatedPlaybackProgressIgnored",
                states: [
                    "route": route.diagnosticCode,
                    "phase": String(describing: receipt.state.phase),
                    "reason": "phaseOrReplyMismatch",
                ],
                counts: [
                    "answerCharacterCount": receipt.answerCharacterCount,
                    "elapsedMsSinceSubmit": Int(Date().timeIntervalSince(receipt.submittedAt) * 1_000),
                ],
                correlations: [
                    "receipt": receipt.id.uuidString,
                    "reply": progress.replyID,
                ]
            )
            return
        }
        pendingLivePlaybackReceipt = receipt

        switch progress {
        case .providerAccepted,
             .audioActivityObserved,
             .audioStarted,
             .synthesisEnded:
            scheduleLivePlaybackTerminalWatchdog(receiptID: receipt.id)
            logDelegatedPlaybackDiagnostic(progress, receipt: receipt)
            PrivacySafeDiagnostics.log(
                subsystem: "Echo",
                event: "livePlaybackWatchdogAdvanced",
                states: ["stage": "terminal", "route": route.diagnosticCode],
                counts: [
                    "answerCharacterCount": receipt.answerCharacterCount,
                    "elapsedMsSinceSubmit": Int(Date().timeIntervalSince(receipt.submittedAt) * 1_000),
                ],
                correlations: [
                    "receiptID": receipt.id.uuidString,
                    "turnID": receipt.turnID,
                    "replyID": receipt.state.replyID,
                    "lifecycleGeneration": String(receipt.lifecycleToken.generation),
                ]
            )
        case .audioFinished:
            logDelegatedPlaybackDiagnostic(progress, receipt: receipt)
            logLivePlaybackTerminalWon(
                receipt: receipt,
                cause: .finished
            )
            guard completeLivePlaybackReceipt(route: route) else { return }
            finishLiveEchoPlaybackAfterReceipt(
                route: route,
                lifecycleToken: receipt.lifecycleToken,
                receipt: receipt
            )
        case .interrupted(let replyID):
            logDelegatedPlaybackDiagnostic(progress, receipt: receipt)
            handleLivePlaybackFailure(
                receiptID: receipt.id,
                route: route,
                lifecycleToken: receipt.lifecycleToken,
                reason: "interrupted",
                replyID: replyID
            )
        case .failed(let replyID, let code):
            logDelegatedPlaybackDiagnostic(progress, receipt: receipt)
            handleLivePlaybackFailure(
                receiptID: receipt.id,
                route: route,
                lifecycleToken: receipt.lifecycleToken,
                reason: "providerFailed:\(code)",
                replyID: replyID
            )
        }
    }

    private func logDelegatedPlaybackDiagnostic(
        _ progress: DialogEngineDelegatedPlaybackProgress,
        receipt: EchoLivePlaybackReceipt
    ) {
        let event: String
        switch progress {
        case .providerAccepted:
            event = "delegatedTTSProviderAccepted"
        case .audioActivityObserved:
            event = "delegatedTTSAudioActivityObserved"
        case .audioStarted:
            event = "delegatedTTSPlayerStarted"
        case .synthesisEnded:
            event = "delegatedTTSSynthesisEnded"
        case .audioFinished:
            event = "delegatedTTSPlayerFinished"
        case .interrupted:
            event = "delegatedTTSInterrupted"
        case .failed:
            event = "delegatedTTSFailed"
        }
        PrivacySafeDiagnostics.log(
            subsystem: "Echo",
            event: event,
            states: ["route": receipt.state.route.diagnosticCode],
            counts: [
                "answerCharacterCount": receipt.answerCharacterCount,
                "elapsedMsSinceSubmit": Int(Date().timeIntervalSince(receipt.submittedAt) * 1_000),
            ],
            correlations: [
                "receiptID": receipt.id.uuidString,
                "turnID": receipt.turnID,
                "replyID": progress.replyID,
                "lifecycleGeneration": String(receipt.lifecycleToken.generation),
            ]
        )
    }

    private func logLivePlaybackTerminalWon(
        receipt: EchoLivePlaybackReceipt,
        cause: EchoLivePlaybackTerminalCause
    ) {
        PrivacySafeDiagnostics.log(
            subsystem: "Echo",
            event: "livePlaybackTerminalWon",
            states: [
                "route": receipt.state.route.diagnosticCode,
                "terminalCause": cause.diagnosticCode,
            ],
            counts: [
                "answerCharacterCount": receipt.answerCharacterCount,
                "elapsedMsSinceSubmit": Int(Date().timeIntervalSince(receipt.submittedAt) * 1_000),
            ],
            correlations: [
                "receiptID": receipt.id.uuidString,
                "turnID": receipt.turnID,
                "replyID": receipt.state.replyID,
                "lifecycleGeneration": String(receipt.lifecycleToken.generation),
            ]
        )
    }

    private func logLiveTurnPhaseTransition(
        receipt: EchoLivePlaybackReceipt,
        cause: EchoLivePlaybackTerminalCause,
        phaseBefore: EchoTurnPhase,
        phaseAfter: EchoTurnPhase
    ) {
        var states = [
            "route": receipt.state.route.diagnosticCode,
            "terminalCause": cause.diagnosticCode,
            "phaseBefore": phaseBefore.rawValue,
            "phaseAfter": phaseAfter.rawValue,
        ]
        if let detail = cause.detail {
            states["terminalDetail"] = detail
        }
        PrivacySafeDiagnostics.log(
            subsystem: "Echo",
            event: "liveTurnPhaseTransitioned",
            states: states,
            counts: [
                "answerCharacterCount": receipt.answerCharacterCount,
                "elapsedMsSinceSubmit": Int(Date().timeIntervalSince(receipt.submittedAt) * 1_000),
            ],
            correlations: [
                "receiptID": receipt.id.uuidString,
                "turnID": receipt.turnID,
                "replyID": receipt.state.replyID,
                "lifecycleGeneration": String(receipt.lifecycleToken.generation),
            ]
        )
    }

    private func requestLiveRecorderResume(
        receipt: EchoLivePlaybackReceipt,
        route: EchoLiveAudioRoute,
        lifecycleToken: DigitalHumanLifecycleToken,
        reason: String
    ) -> DialogRecorderResumeOutcome {
        guard !isLiveFarewellActive else { return .sessionInactive }
        let phaseBefore = viewModel.turnPhase
        PrivacySafeDiagnostics.log(
            subsystem: "Echo",
            event: "liveRecorderResumeRequested",
            states: [
                "route": route.diagnosticCode,
                "reason": reason,
                "phaseBefore": phaseBefore.rawValue,
            ],
            counts: [
                "answerCharacterCount": receipt.answerCharacterCount,
                "elapsedMsSinceSubmit": Int(Date().timeIntervalSince(receipt.submittedAt) * 1_000),
            ],
            correlations: [
                "receiptID": receipt.id.uuidString,
                "turnID": receipt.turnID,
                "replyID": receipt.state.replyID,
                "lifecycleGeneration": String(lifecycleToken.generation),
            ]
        )

        let outcome = DialogEngineManager.shared.resumeRecorderOutcome()
        PrivacySafeDiagnostics.log(
            subsystem: "Echo",
            event: "liveRecorderResumeOutcome",
            states: [
                "route": route.diagnosticCode,
                "reason": reason,
                "phaseBefore": phaseBefore.rawValue,
                "outcome": outcome.diagnosticCode,
            ],
            counts: [
                "answerCharacterCount": receipt.answerCharacterCount,
                "elapsedMsSinceSubmit": Int(Date().timeIntervalSince(receipt.submittedAt) * 1_000),
            ],
            correlations: [
                "receiptID": receipt.id.uuidString,
                "turnID": receipt.turnID,
                "replyID": receipt.state.replyID,
                "lifecycleGeneration": String(lifecycleToken.generation),
            ]
        )
        return outcome
    }

    private func failLiveCaptureRecovery(
        receipt: EchoLivePlaybackReceipt,
        route: EchoLiveAudioRoute,
        lifecycleToken: DigitalHumanLifecycleToken,
        cause: EchoLivePlaybackTerminalCause,
        reason: String
    ) {
        guard isUserControlledLiveSessionOpen,
              isCurrentDigitalHumanLifecycleToken(
                lifecycleToken,
                reason: "failLiveCaptureRecovery"
              ) else {
            return
        }
        let phaseBefore = viewModel.turnPhase
        viewModel.fail("本轮语音播放未完成，请结束本轮后重试")
        let phaseAfter = viewModel.turnPhase
        var states = [
            "route": route.diagnosticCode,
            "terminalCause": cause.diagnosticCode,
            "reason": reason,
            "phaseBefore": phaseBefore.rawValue,
            "phaseAfter": phaseAfter.rawValue,
        ]
        if let detail = cause.detail {
            states["terminalDetail"] = detail
        }
        PrivacySafeDiagnostics.log(
            subsystem: "Echo",
            event: "liveRecoveryFailed",
            states: states,
            counts: [
                "answerCharacterCount": receipt.answerCharacterCount,
                "elapsedMsSinceSubmit": Int(Date().timeIntervalSince(receipt.submittedAt) * 1_000),
            ],
            correlations: [
                "receiptID": receipt.id.uuidString,
                "turnID": receipt.turnID,
                "replyID": receipt.state.replyID,
                "lifecycleGeneration": String(lifecycleToken.generation),
            ]
        )
        renderVoiceStatus(
            text: "本轮语音播放未完成，请结束本轮后重试",
            isVisible: true,
            accessibilityIdentifier: "echoLivePlaybackRecoveryFailed"
        )
    }

    private func handleLivePlaybackAcceptanceTimeout(receiptID: UUID) {
        guard let receipt = pendingLivePlaybackReceipt,
              receipt.id == receiptID,
              receipt.state.phase == .submitted,
              isUserControlledLiveSessionOpen,
              isCurrentDigitalHumanLifecycleToken(
                receipt.lifecycleToken,
                reason: "livePlaybackAcceptanceTimeout"
              ) else {
            return
        }
            PrivacySafeDiagnostics.log(
                subsystem: "Echo",
                event: "livePlaybackWatchdogExpired",
            states: [
                    "route": receipt.state.route.diagnosticCode,
                    "stage": "providerAcceptance",
                ],
                counts: [
                    "answerCharacterCount": receipt.answerCharacterCount,
                    "elapsedMsSinceSubmit": Int(Date().timeIntervalSince(receipt.submittedAt) * 1_000),
                ],
                correlations: [
                    "receiptID": receipt.id.uuidString,
                    "turnID": receipt.turnID,
                    "replyID": receipt.state.replyID,
                    "lifecycleGeneration": String(receipt.lifecycleToken.generation),
                ]
            )
        switch receipt.state.route {
        case .volcengineLocalTTS:
            let interruptAccepted = DialogEngineManager.shared.interruptAI()
            handleLivePlaybackFailure(
                receiptID: receipt.id,
                route: receipt.state.route,
                lifecycleToken: receipt.lifecycleToken,
                reason: interruptAccepted
                    ? "providerAcceptanceTimeout"
                    : "providerAcceptanceInterruptRejected",
                replyID: nil
            )
        case .tencentDigitalHuman:
            digitalHumanRuntime?.interrupt()
            handleLivePlaybackFailure(
                receiptID: receipt.id,
                route: receipt.state.route,
                lifecycleToken: receipt.lifecycleToken,
                reason: "providerAcceptanceTimeout",
                replyID: nil
            )
        case .unavailable:
            handleLivePlaybackFailure(
                receiptID: receipt.id,
                route: receipt.state.route,
                lifecycleToken: receipt.lifecycleToken,
                reason: "routeUnavailable",
                replyID: nil
            )
        }
    }

    private func handleLivePlaybackTerminalWatchdog(receiptID: UUID) {
        guard let receipt = pendingLivePlaybackReceipt,
              receipt.id == receiptID,
              receipt.state.phase != .submitted,
              receipt.state.phase != .audioFinished,
              receipt.state.phase != .interrupted,
              receipt.state.phase != .failed,
              isUserControlledLiveSessionOpen,
              isCurrentDigitalHumanLifecycleToken(
                receipt.lifecycleToken,
                reason: "livePlaybackTerminalWatchdog"
              ) else {
            return
        }
        PrivacySafeDiagnostics.log(
            subsystem: "Echo",
            event: "livePlaybackWatchdogExpired",
            states: [
                "route": receipt.state.route.diagnosticCode,
                "stage": "terminal",
            ],
            counts: [
                "answerCharacterCount": receipt.answerCharacterCount,
                "elapsedMsSinceSubmit": Int(Date().timeIntervalSince(receipt.submittedAt) * 1_000),
            ],
            correlations: [
                "receiptID": receipt.id.uuidString,
                "turnID": receipt.turnID,
                "replyID": receipt.state.replyID,
                "lifecycleGeneration": String(receipt.lifecycleToken.generation),
            ]
        )
        switch receipt.state.route {
        case .volcengineLocalTTS:
            let interruptAccepted = DialogEngineManager.shared.interruptAI()
            handleLivePlaybackFailure(
                receiptID: receipt.id,
                route: receipt.state.route,
                lifecycleToken: receipt.lifecycleToken,
                reason: interruptAccepted
                    ? "terminalTimeout"
                    : "terminalInterruptRejected",
                replyID: receipt.state.replyID
            )
        case .tencentDigitalHuman:
            digitalHumanRuntime?.interrupt()
            handleLivePlaybackFailure(
                receiptID: receipt.id,
                route: receipt.state.route,
                lifecycleToken: receipt.lifecycleToken,
                reason: "terminalTimeout",
                replyID: receipt.state.replyID
            )
        case .unavailable:
            handleLivePlaybackFailure(
                receiptID: receipt.id,
                route: receipt.state.route,
                lifecycleToken: receipt.lifecycleToken,
                reason: "routeUnavailable",
                replyID: receipt.state.replyID
            )
        }
    }

    private func handleLivePlaybackFailure(
        receiptID: UUID,
        route: EchoLiveAudioRoute,
        lifecycleToken: DigitalHumanLifecycleToken,
        reason: String,
        replyID: String?
    ) {
        guard var receipt = pendingLivePlaybackReceipt,
              receipt.id == receiptID,
              receipt.state.route == route,
              isUserControlledLiveSessionOpen,
              isCurrentDigitalHumanLifecycleToken(
                lifecycleToken,
                reason: "livePlaybackFailure"
              ) else {
            return
        }
        let cause: EchoLivePlaybackTerminalCause
        if reason == "interrupted" {
            cause = .userInterrupted
        } else if reason.hasPrefix("providerFailed:") {
            cause = .providerFailed(
                code: String(reason.dropFirst("providerFailed:".count))
            )
        } else {
            cause = .watchdogInterrupted
        }
        let phaseBefore = viewModel.turnPhase
        if receipt.state.phase != .interrupted,
           receipt.state.phase != .failed {
            let progress: DialogEngineDelegatedPlaybackProgress
            switch cause {
            case .userInterrupted:
                progress = .interrupted(replyID: replyID)
            case .finished, .providerFailed, .watchdogInterrupted:
                progress = .failed(replyID: replyID, code: reason)
            }
            _ = receipt.state.apply(progress, callbackRoute: route)
        }
        logLivePlaybackTerminalWon(receipt: receipt, cause: cause)
        let phaseAfterTerminal = viewModel.turnPhase
        cancelLivePlaybackReceipt(reason: "playbackFailure:\(reason)")
        pendingAIText = nil
        var states = [
            "route": route.diagnosticCode,
            "reason": reason,
            "terminalCause": cause.diagnosticCode,
            "phaseBefore": phaseBefore.rawValue,
            "phaseAfter": phaseAfterTerminal.rawValue,
        ]
        if let detail = cause.detail {
            states["terminalDetail"] = detail
        }
        PrivacySafeDiagnostics.log(
            subsystem: "Echo",
            event: "livePlaybackFailed",
            states: states,
            counts: [
                "answerCharacterCount": receipt.answerCharacterCount,
                "elapsedMsSinceSubmit": Int(Date().timeIntervalSince(receipt.submittedAt) * 1_000),
            ],
            correlations: [
                "receiptID": receiptID.uuidString,
                "turnID": receipt.turnID,
                "replyID": replyID,
                "lifecycleGeneration": String(receipt.lifecycleToken.generation),
            ]
        )
        PrivacySafeDiagnostics.log(
            subsystem: "Echo",
            event: "liveRecoveryStarted",
            states: [
                "route": route.diagnosticCode,
                "terminalCause": cause.diagnosticCode,
                "phaseBefore": phaseAfterTerminal.rawValue,
            ],
            counts: [
                "answerCharacterCount": receipt.answerCharacterCount,
                "elapsedMsSinceSubmit": Int(Date().timeIntervalSince(receipt.submittedAt) * 1_000),
            ],
            correlations: [
                "receiptID": receipt.id.uuidString,
                "turnID": receipt.turnID,
                "replyID": receipt.state.replyID,
                "lifecycleGeneration": String(receipt.lifecycleToken.generation),
            ]
        )
        recoverLiveCaptureAfterPlaybackFailure(
            route: route,
            lifecycleToken: lifecycleToken,
            receipt: receipt,
            cause: cause
        )
    }

    private func recoverLiveCaptureAfterPlaybackFailure(
        route: EchoLiveAudioRoute,
        lifecycleToken: DigitalHumanLifecycleToken,
        receipt: EchoLivePlaybackReceipt,
        cause: EchoLivePlaybackTerminalCause
    ) {
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) { [weak self] in
            guard let self,
                  self.isUserControlledLiveSessionOpen,
                  self.isCurrentDigitalHumanLifecycleToken(
                    lifecycleToken,
                    reason: "recoverLiveCaptureAfterPlaybackFailure"
                  ),
                  let accountLease = self.echoAccountLease,
                  self.validateEchoAccountLease(
                    at: .runtime,
                    expected: accountLease,
                    reason: "recoverLiveCaptureAfterPlaybackFailure"
                  ) else {
                return
            }

            if route == .tencentDigitalHuman {
                self.releaseEchoAudioOwnerLease(
                    expectedOwner: .tencentDigitalHumanPlayback,
                    reason: "livePlaybackFailureRecovery"
                )
            }
            guard DialogEngineManager.shared.isDialogActive else {
                self.failLiveCaptureRecovery(
                    receipt: receipt,
                    route: route,
                    lifecycleToken: lifecycleToken,
                    cause: cause,
                    reason: "dialogInactive"
                )
                return
            }

            let phaseBeforeListening = self.viewModel.turnPhase
            guard self.viewModel.resumeVoiceInteractionAfterReplyInterruption(
                accountLease: accountLease
            ) else {
                self.failLiveCaptureRecovery(
                    receipt: receipt,
                    route: route,
                    lifecycleToken: lifecycleToken,
                    cause: cause,
                    reason: "listeningTransitionRejected"
                )
                return
            }
            self.logLiveTurnPhaseTransition(
                receipt: receipt,
                cause: cause,
                phaseBefore: phaseBeforeListening,
                phaseAfter: self.viewModel.turnPhase
            )
            guard self.prepareEchoCaptureAudioSession(reason: "livePlaybackFailureRecovery") else {
                self.failLiveCaptureRecovery(
                    receipt: receipt,
                    route: route,
                    lifecycleToken: lifecycleToken,
                    cause: cause,
                    reason: "audioSessionPreparationFailed"
                )
                return
            }
            let recorderOutcome = self.requestLiveRecorderResume(
                receipt: receipt,
                route: route,
                lifecycleToken: lifecycleToken,
                reason: "livePlaybackFailureRecovery"
            )
            guard recorderOutcome.isSuccess else {
                self.failLiveCaptureRecovery(
                    receipt: receipt,
                    route: route,
                    lifecycleToken: lifecycleToken,
                    cause: cause,
                    reason: "recorderResumeFailed"
                )
                return
            }
            guard self.viewModel.turnPhase == .listening else {
                self.failLiveCaptureRecovery(
                    receipt: receipt,
                    route: route,
                    lifecycleToken: lifecycleToken,
                    cause: cause,
                    reason: "listeningPhaseNotReached"
                )
                return
            }
            self.armLiveUserInactivityTimeout(reason: "playbackStartTimeoutRecovery")
            self.renderVoiceStatus(
                text: "正在聆听",
                isVisible: true,
                accessibilityIdentifier: "echoLiveListeningAfterPlaybackRecovery"
            )
            PrivacySafeDiagnostics.log(
                subsystem: "Echo",
                event: "liveCaptureResumed",
                states: [
                    "route": route.diagnosticCode,
                    "terminalCause": cause.diagnosticCode,
                    "phaseBefore": phaseBeforeListening.rawValue,
                    "phaseAfter": self.viewModel.turnPhase.rawValue,
                ],
                counts: [
                    "answerCharacterCount": receipt.answerCharacterCount,
                    "elapsedMsSinceSubmit": Int(Date().timeIntervalSince(receipt.submittedAt) * 1_000),
                ],
                correlations: [
                    "receiptID": receipt.id.uuidString,
                    "turnID": receipt.turnID,
                    "replyID": receipt.state.replyID,
                    "lifecycleGeneration": String(lifecycleToken.generation),
                ]
            )
        }
    }

    private var routeEchoAudioThroughDigitalHuman: Bool {
        if isUserControlledLiveSessionOpen {
            return scopedActiveLiveAudioRoute == .tencentDigitalHuman
        }
        guard shouldShowDigitalHumanLivePanel,
              tencentDigitalHumanAudioRouteReserved,
              tencentCloudRenderProvidesAudibleTTS else {
            return false
        }
        return true
    }

    private var shouldDriveTencentVisualLipSync: Bool {
        guard shouldShowDigitalHumanLivePanel,
              let digitalHumanRuntime,
              digitalHumanRuntimeLifecycleGeneration == digitalHumanLifecycle.generation,
              digitalHumanRuntime is TencentDigitalHumanCloudRuntime,
              digitalHumanRuntime.profile != nil else {
            return false
        }
        return true
    }

    private var shouldDispatchEchoReplyToTencentProvider: Bool {
        routeEchoAudioThroughDigitalHuman && tencentDigitalHumanProviderCanOwnAudio
    }

    private func loadVoiceCloneRuntimeCapabilityIfNeeded(force: Bool = false) {
        #if DEBUG
        if skipAncillaryVoiceCloneFetchForTesting { return }
        #endif
        guard !viewModel.isNeutralSafetyMode,
              let accountLease = echoAccountLease,
              validateEchoAccountLease(
                at: .request,
                expected: accountLease,
                reason: "voiceCloneRuntimeCapability"
              ) else { return }
        let lifecycleToken = captureDigitalHumanLifecycleToken(reason: "voiceCloneRuntimeCapability")
        if !force, voiceCloneRuntimeCapability != nil {
            return
        }
        guard !isLoadingVoiceCloneRuntimeCapability else {
            return
        }
        isLoadingVoiceCloneRuntimeCapability = true
        DreamJourneyBackendClient.shared.fetchVoiceCloneRuntimeCapability { [weak self] result in
            DispatchQueue.main.async {
                guard let self,
                      self.validateEchoAccountLease(
                        at: .ui,
                        expected: accountLease,
                        reason: "voiceCloneRuntimeCapabilityResponse"
                      ),
                      self.isCurrentDigitalHumanSessionToken(
                        lifecycleToken,
                        reason: "voiceCloneRuntimeCapabilityResponse"
                      ) else { return }
                self.isLoadingVoiceCloneRuntimeCapability = false
                switch result {
                case .success(let capability):
                    self.voiceCloneRuntimeCapability = capability
                    PrivacySafeDiagnostics.log(
                        subsystem: "TencentDigitalHuman",
                        event: "voiceCloneRuntimeCapabilityLoaded",
                        states: [
                            "canSynthesize": String(capability.canSynthesize),
                            "provider": capability.provider,
                            "tencentAudioDriveSupported": String(capability.tencentAudioDrive.supported),
                        ]
                    )
                case .failure:
                    self.voiceCloneRuntimeCapability = VoiceCloneRuntimeCapability.localFallback(isBackendConfigured: false)
                    PrivacySafeDiagnostics.log(
                        subsystem: "TencentDigitalHuman",
                        event: "voiceCloneRuntimeCapabilityFailed",
                        states: ["reason": "backendFailure"]
                    )
                }
                _ = self.updateDialogEngineLocalTTSVoiceSelection(
                    reason: "voiceCloneRuntimeCapabilityResponse"
                )
            }
        }
    }

    private func applyEchoAudioRoutePolicy() {
        let shouldRouteThroughDigitalHuman = routeEchoAudioThroughDigitalHuman
        if shouldRouteThroughDigitalHuman {
            guard setDialogEngineLocalTTSPlaybackEnabled(false) else {
                markPinnedLiveAudioRouteUnavailable(reason: "dialogPlayerDisableRejected")
                digitalHumanStatusDetailLabel.text = "数字人声音暂不可用，请结束本轮后重试"
                return
            }
            digitalHumanStatusDetailLabel.text = "腾讯数智人负责声音与口型同步"
            setEchoAudioOwner(.tencentDigitalHuman, reason: "routePolicy")
        } else {
            if case .unavailable(let reason) = scopedActiveLiveAudioRoute {
                setEchoAudioOwner(.fallbackMuted, reason: reason)
                digitalHumanStatusDetailLabel.text = "本轮语音播放不可用，请结束后重试"
                return
            }
            let shouldEnableLocalPlayback = isUserControlledLiveSessionOpen
                || !tencentDigitalHumanAudioRouteReserved
            if shouldEnableLocalPlayback,
               !setDialogEngineLocalTTSPlaybackEnabled(true) {
                markPinnedLiveAudioRouteUnavailable(reason: "dialogPlayerEnableRejected")
                digitalHumanStatusDetailLabel.text = "普通回响声音暂不可用，请结束后重试"
                return
            }
            if shouldShowDigitalHumanLivePanel,
               let digitalHumanRuntime,
               digitalHumanRuntime is TencentDigitalHumanCloudRuntime,
               digitalHumanRuntime.profile != nil {
                digitalHumanStatusDetailLabel.text = "数字人暂未接管声音，已回到普通回响"
            }
            setEchoAudioOwner(.volcengineLocalTTS, reason: "routePolicy")
        }
    }

    private func resolveEchoRoleVoiceProfileSelection() -> EchoRoleVoiceProfileSelection {
        let context = DigitalHumanContextStore.shared.current
        if context.isSelfAssistant {
            return EchoRoleVoiceProfileSelection(
                voiceProfileId: nil,
                source: .selfAssistantDefault,
                contextOwnerId: context.ownerId,
                displayName: context.resolvedDisplayName
            )
        }
        if isCurrentUserPersonaContext(context) {
            let voiceProfileId = VoiceCloneService.shared.currentUsableSpeakerId
            return EchoRoleVoiceProfileSelection(
                voiceProfileId: voiceProfileId,
                source: voiceProfileId == nil ? .personalOwnerVoiceProfileMissing : .personalOwner,
                contextOwnerId: context.ownerId,
                displayName: context.resolvedDisplayName
            )
        }

        // A family relationship does not grant authority to synthesize with a
        // family member's cloned voice. Preserve the role context for ordinary
        // Echo, but force the voice path to the neutral provider fallback.
        return EchoRoleVoiceProfileSelection(
            voiceProfileId: nil,
            source: .familyVoiceNotPermitted,
            contextOwnerId: context.ownerId,
            displayName: context.resolvedDisplayName
        )
    }

    /// QA evidence must not infer provider cleanup from role selection alone.
    /// The selected profile has to match the current account-scoped snapshot
    /// before local lifecycle state is exported. Provider cleanup remains a
    /// separate, explicitly reported receipt boundary.
    private func resolveVoiceProfileExitEvidence(
        for selection: EchoRoleVoiceProfileSelection
    ) -> EchoVoiceProfileExitEvidence {
        guard let voiceProfileId = selection.voiceProfileId?
            .trimmingCharacters(in: .whitespacesAndNewlines),
              !voiceProfileId.isEmpty else {
            return .notSelected
        }

        let snapshot = VoiceCloneService.shared.voiceCloneShellSnapshot()
        guard snapshot.voiceProfileId == voiceProfileId else {
            return .unresolved
        }

        return EchoVoiceProfileExitEvidence(
            evidenceState: "localResolved",
            exitState: snapshot.exitState,
            accessRevoked: snapshot.accessRevoked,
            localCleanupState: snapshot.localCleanupState,
            providerCleanupState: snapshot.providerCleanupState,
            providerCleanupReceiptAvailable: snapshot.providerCleanupReceiptAvailable
        )
    }

    private func isCurrentUserPersonaContext(_ context: DigitalHumanContext) -> Bool {
        KBLiteManager.resolveAuthorizedPersonaIdentity(for: context)?.isPersonal == true
    }

    private func setEchoAudioOwner(_ owner: EchoDigitalHumanAudioOwner, reason: String) {
        let previousOwner = currentEchoAudioOwner
        currentEchoAudioOwner = owner
        if owner == .fallbackMuted {
            releaseEchoAudioOwnerLease(reason: "desiredMuted:\(reason)")
        }
        PrivacySafeDiagnostics.log(
            subsystem: "TencentDigitalHuman",
            event: "audioOwnerUpdated",
            states: [
                "previousAudioOwner": previousOwner.rawValue,
                "audioOwner": owner.rawValue,
                "reason": reason,
                "providerSpeechInFlight": hasTencentDigitalHumanProviderSpeechInFlight ? "true" : "false",
            ]
        )
    }

    /// Route preference is deliberately separate from a runtime lease. A Tencent route can
    /// be ready while the microphone is still listening; only actual capture/playback events
    /// below acquire the system AudioSession through the coordinator.
    @discardableResult
    private func acquireEchoRuntimeAudioOwner(
        _ owner: AudioOwnerLeaseOwner,
        priority: AudioOwnerLeasePriority,
        reason: String
    ) -> Bool {
        guard let scope = currentEchoAudioOwnerLeaseScope() else {
            releaseEchoAudioOwnerLease(reason: "missingScope:\(reason)")
            return false
        }

        let result = audioSessionCoordinator.acquire(
            owner,
            priority: priority,
            scope: scope
        )
        let accepted: Bool
        switch result {
        case let .unchanged(lease), let .acquired(lease), let .preempted(_, lease):
            activeEchoAudioOwnerLease = lease
            accepted = true
        case let .activationFailed(_, active, _):
            activeEchoAudioOwnerLease = active
            accepted = false
        case .deniedByActiveOwner, .deniedStaleGeneration,
                .released, .ignoredStaleRelease, .deactivationFailed,
                .ignoredStaleEvent, .ignoredNotInterrupted:
            activeEchoAudioOwnerLease = nil
            accepted = false
        case .interrupted, .alreadyInterrupted, .resumed, .routeChanged:
            accepted = false
        }
        recordEchoAudioSessionCoordinatorTransition(
            result,
            requestedOwner: owner.rawValue,
            reason: reason
        )
        return accepted
    }

    private func releaseEchoAudioOwnerLease(
        expectedOwner: AudioOwnerLeaseOwner? = nil,
        reason: String
    ) {
        guard let activeLease = activeEchoAudioOwnerLease else {
            return
        }
        guard expectedOwner == nil || activeLease.owner == expectedOwner else {
            recordEchoAudioSessionCoordinatorTransition(
                .ignoredStaleEvent(active: activeLease),
                requestedOwner: expectedOwner?.rawValue ?? "none",
                reason: "ownerMismatch:\(reason)"
            )
            return
        }
        let result = audioSessionCoordinator.release(activeLease)
        switch result {
        case .released, .ignoredStaleRelease:
            activeEchoAudioOwnerLease = nil
        case let .deactivationFailed(active):
            activeEchoAudioOwnerLease = active
        case .unchanged, .acquired, .preempted, .deniedByActiveOwner,
                .deniedStaleGeneration, .interrupted, .alreadyInterrupted,
                .resumed, .routeChanged, .ignoredStaleEvent,
                .ignoredNotInterrupted, .activationFailed:
            break
        }
        recordEchoAudioSessionCoordinatorTransition(
            result,
            requestedOwner: activeLease.owner.rawValue,
            reason: reason
        )
    }

    private func currentEchoAudioOwnerLeaseScope() -> AudioOwnerLeaseScope? {
        guard let echoAccountLease else {
            return nil
        }
        let runtimeGeneration = echoRuntimeSessionCoordinator.activeLease?.runtimeGeneration
            ?? digitalHumanRuntimeLifecycleGeneration
            ?? digitalHumanLifecycle.generation
        return AudioOwnerLeaseScope(
            accountGeneration: echoAccountLease.generation,
            runtimeGeneration: runtimeGeneration
        )
    }

    private func recordEchoAudioSessionCoordinatorTransition(
        _ result: AudioSessionCoordinatorResult,
        requestedOwner: String,
        reason: String
    ) {
        let snapshot = audioSessionCoordinator.diagnosticsSnapshot()
        PrivacySafeDiagnostics.log(
            subsystem: "AudioOwnerLease",
            event: "echoAudioSessionCoordinatorTransition",
            states: [
                "result": result.diagnosticCode,
                "requestedOwner": requestedOwner,
                "activeOwner": snapshot.activeLease?.owner.rawValue ?? "none",
                "transitionCount": String(snapshot.transitionCount),
                "reasonHash": PrivacySafeDiagnostics.correlationHash(reason),
            ]
        )
    }

    @discardableResult
    private func prepareEchoCaptureAudioSession(reason: String) -> Bool {
        #if DEBUG
        if let voiceAudioPreparationForTesting { return voiceAudioPreparationForTesting() }
        #endif
        guard acquireEchoRuntimeAudioOwner(
            .echoCapture,
            priority: .echoCapture,
            reason: reason
        ), let lease = activeEchoAudioOwnerLease,
           lease.owner == .echoCapture,
           DialogEngineManager.shared.adoptExternallyManagedAudioSessionLease(lease) else {
            releaseEchoAudioOwnerLease(
                expectedOwner: .echoCapture,
                reason: "dialogEngineLeaseRejected:\(reason)"
            )
            return false
        }
        return true
    }

    private func observeEchoAudioSessionEvents() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(echoAudioSessionInterrupted(_:)),
            name: AVAudioSession.interruptionNotification,
            object: nil
        )
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(echoAudioSessionRouteDidChange(_:)),
            name: AVAudioSession.routeChangeNotification,
            object: nil
        )
    }

    @objc private func echoAudioSessionInterrupted(_ notification: Notification) {
        guard let activeLease = activeEchoAudioOwnerLease,
              let rawType = notification.userInfo?[AVAudioSessionInterruptionTypeKey] as? UInt,
              let type = AVAudioSession.InterruptionType(rawValue: rawType) else {
            return
        }

        let result: AudioSessionCoordinatorResult
        switch type {
        case .began:
            result = audioSessionCoordinator.interrupt(activeLease)
        case .ended:
            let rawOptions = notification.userInfo?[AVAudioSessionInterruptionOptionKey] as? UInt ?? 0
            let options = AVAudioSession.InterruptionOptions(rawValue: rawOptions)
            guard options.contains(.shouldResume) else {
                PrivacySafeDiagnostics.log(
                    subsystem: "AudioOwnerLease",
                    event: "echoAudioSessionInterruptionEndedWithoutResume",
                    states: ["activeOwner": activeLease.owner.rawValue]
                )
                return
            }
            result = audioSessionCoordinator.resume(activeLease)
        @unknown default:
            return
        }

        switch result {
        case let .interrupted(lease), let .alreadyInterrupted(lease), let .resumed(lease),
                let .routeChanged(lease), let .unchanged(lease), let .acquired(lease),
                let .preempted(_, lease):
            activeEchoAudioOwnerLease = lease
        case let .activationFailed(_, active, _):
            activeEchoAudioOwnerLease = active
        case .deniedByActiveOwner, .deniedStaleGeneration,
                .released, .ignoredStaleRelease, .deactivationFailed,
                .ignoredStaleEvent, .ignoredNotInterrupted:
            activeEchoAudioOwnerLease = nil
        }
        recordEchoAudioSessionCoordinatorTransition(
            result,
            requestedOwner: activeLease.owner.rawValue,
            reason: "audioSessionInterruption:\(type.rawValue)"
        )
    }

    @objc private func echoAudioSessionRouteDidChange(_ notification: Notification) {
        guard let activeLease = activeEchoAudioOwnerLease else {
            return
        }
        let result = audioSessionCoordinator.routeDidChange(for: activeLease)
        switch result {
        case let .routeChanged(lease), let .unchanged(lease), let .acquired(lease),
                let .preempted(_, lease), let .interrupted(lease), let .alreadyInterrupted(lease),
                let .resumed(lease):
            activeEchoAudioOwnerLease = lease
        case let .activationFailed(_, active, _):
            activeEchoAudioOwnerLease = active
        case .deniedByActiveOwner, .deniedStaleGeneration,
                .released, .ignoredStaleRelease, .deactivationFailed,
                .ignoredStaleEvent, .ignoredNotInterrupted:
            activeEchoAudioOwnerLease = nil
        }
        let routeReason = notification.userInfo?[AVAudioSessionRouteChangeReasonKey] as? UInt
        recordEchoAudioSessionCoordinatorTransition(
            result,
            requestedOwner: activeLease.owner.rawValue,
            reason: "audioSessionRouteChange:\(routeReason.map(String.init) ?? "unknown")"
        )
    }

    private var shouldTraceTrueDeviceBackendPCMDrive: Bool {
        shouldRunTencentDigitalHumanBackendPCMDriveSmoke && trueDeviceBackendPCMDriveTrace.isActive
    }

    private var currentEchoEvidenceOwnerUserId: String {
        EchoTraceOwnerScope.normalizedOwnerUserId(UserManager.shared.currentUser?.id)
            ?? EchoTraceOwnerScope.normalizedOwnerUserId(lastEchoTraceRecord?.userId)
            ?? "unknown"
    }

    private func emitTencentBackendPCMDriveTrueDeviceQAResult(reason: String) {
        guard shouldTraceTrueDeviceBackendPCMDrive else {
            return
        }
        let json = trueDeviceBackendPCMDriveTrace.jsonLine(
            audioOwner: currentEchoAudioOwner,
            emitReason: reason
        )
        print("[TencentDigitalHuman][QA_RESULT] \(json)")
    }

    private func diagnosticDigitalHumanRuntimeState(
        _ state: DigitalHumanSessionState?
    ) -> String {
        guard let state else {
            return "none"
        }
        switch state {
        case .idle:
            return "idle"
        case .preparing:
            return "preparing"
        case .connecting:
            return "connecting"
        case .ready:
            return "ready"
        case .listening:
            return "listening"
        case .thinking:
            return "thinking"
        case .buffering:
            return "buffering"
        case .speaking:
            return "speaking"
        case .completed:
            return "completed"
        case .interrupting:
            return "interrupting"
        case .reconnecting:
            return "reconnecting"
        case .degraded:
            return "degraded"
        case .failed(let code):
            return "failed:" + PrivacySafeDiagnostics.safeCode(
                code,
                fallback: "redacted"
            )
        case .closed:
            return "closed"
        }
    }

    private func makeEchoRuntimeDiagnosticsSnapshot(reason: String) -> EchoRuntimeDiagnosticsSnapshot {
        let ownerUserId = EchoTraceOwnerScope.normalizedOwnerUserId(UserManager.shared.currentUser?.id)
            ?? EchoTraceOwnerScope.normalizedOwnerUserId(lastEchoTraceRecord?.userId)
        let ownerTrace = lastEchoTraceRecord.flatMap { trace in
            EchoTraceOwnerScope.normalizedOwnerUserId(trace.userId) == ownerUserId ? trace : nil
        }
        let runtime = digitalHumanRuntime
        let runtimeState = diagnosticDigitalHumanRuntimeState(runtime?.state)
        let profile = runtime?.profile
        let providerMode = profile?.driveMode ?? ownerTrace?.digitalHumanProviderMode ?? "unknown"
        let fallbackReason = lastEchoRuntimeFallbackReason ?? ownerTrace?.fallbacks.first
        let voiceSelection = resolveEchoRoleVoiceProfileSelection()
        let voiceExitEvidence = resolveVoiceProfileExitEvidence(for: voiceSelection)
        let policyDecisions = FeatureGateService.shared.qaEvidenceSnapshot(features: [
            .echoTextInput,
            .voiceCloneShell,
            .digitalHumanLivePanel,
        ])
        return EchoRuntimeDiagnosticsSnapshot(
            trace: ownerTrace,
            ownerUserId: ownerUserId,
            audioOwner: currentEchoAudioOwner.rawValue,
            selectedVoiceProfileId: voiceSelection.voiceProfileId,
            roleVoiceSource: voiceSelection.source.rawValue,
            roleVoiceDisplayName: voiceSelection.displayName,
            roleVoiceContextOwnerId: voiceSelection.contextOwnerId,
            voiceProfileExitEvidenceState: voiceExitEvidence.evidenceState,
            voiceProfileExitState: voiceExitEvidence.exitState,
            voiceProfileAccessRevoked: voiceExitEvidence.accessRevoked,
            voiceProfileLocalCleanupState: voiceExitEvidence.localCleanupState,
            voiceProfileProviderCleanupState: voiceExitEvidence.providerCleanupState,
            voiceProfileProviderCleanupReceiptAvailable: voiceExitEvidence.providerCleanupReceiptAvailable,
            digitalHumanRuntimeState: runtimeState,
            digitalHumanSessionReady: profile != nil || ownerTrace?.digitalHumanSessionReady == true,
            digitalHumanProviderMode: providerMode,
            providerLogId: lastVoiceCloneProviderLogId,
            providerRequestId: lastVoiceCloneProviderRequestId,
            providerMode: lastVoiceCloneProviderMode,
            fallbackReason: fallbackReason,
            featurePolicyDecisions: policyDecisions,
            source: reason
        )
    }

    @discardableResult
    private func recordEchoRuntimeDiagnosticsSnapshot(reason: String) -> EchoRuntimeDiagnosticsSnapshot {
        let snapshot = makeEchoRuntimeDiagnosticsSnapshot(reason: reason)
        let package = makeEchoTraceEvidencePackage(snapshot: snapshot, source: reason)
        if let ownerUserId = package.derivedOwnerUserId {
            EchoRuntimeDiagnosticsStore.shared.record(snapshot, ownerUserId: ownerUserId)
            EchoTraceEvidencePackageStore.shared.record(package, ownerUserId: ownerUserId)
        }
        renderEchoRuntimeDiagnosticsPanel(snapshot: snapshot)
        PrivacySafeDiagnostics.log(
            subsystem: "CFLite",
            event: "runtimeDiagnosticsSnapshotRecorded",
            states: [
                "audioOwner": snapshot.audioOwner,
                "digitalHumanState": snapshot.digitalHumanRuntimeState,
                "outputMode": snapshot.voiceOutputMode,
                "roleVoiceSource": snapshot.roleVoiceSource ?? "unknown",
                "voiceExitEvidence": snapshot.voiceProfileExitEvidenceState ?? "unknown",
                "voiceExitState": snapshot.voiceProfileExitState ?? "unknown",
                "fallbackReason": snapshot.fallbackReason ?? "none",
                "source": snapshot.source,
            ],
            correlations: [
                "snapshot": snapshot.snapshotId,
                "turn": snapshot.turnID,
                "trace": snapshot.traceId,
                "voiceProfile": snapshot.voiceProfileId,
                "roleVoiceContextOwner": snapshot.roleVoiceContextOwnerId,
                "providerLog": snapshot.providerLogId,
            ]
        )
        return snapshot
    }

    private func makeEchoTraceEvidencePackage(
        snapshot: EchoRuntimeDiagnosticsSnapshot?,
        source: String
    ) -> EchoTraceEvidencePackage {
        let ownerUserId = EchoTraceOwnerScope.normalizedOwnerUserId(snapshot?.userId)
            ?? EchoTraceOwnerScope.normalizedOwnerUserId(UserManager.shared.currentUser?.id)
            ?? EchoTraceOwnerScope.normalizedOwnerUserId(lastEchoTraceRecord?.userId)
            ?? "unknown"
        let ownerTrace = lastEchoTraceRecord.flatMap { trace in
            EchoTraceOwnerScope.normalizedOwnerUserId(trace.userId) == ownerUserId ? trace : nil
        }
        let ownerSession = lastDigitalHumanSessionEvidenceSummary.flatMap { summary in
            EchoTraceOwnerScope.normalizedOwnerUserId(summary.ownerUserId) == ownerUserId ? summary : nil
        }
        let ownerSynthesis = lastVoiceSynthesisEvidenceSummary.flatMap { summary in
            EchoTraceOwnerScope.normalizedOwnerUserId(summary.ownerUserId) == ownerUserId ? summary : nil
        }
        return EchoTraceEvidencePackage(
            ownerUserId: ownerUserId,
            traceRecord: ownerTrace,
            runtimeDiagnostics: snapshot,
            digitalHumanSession: ownerSession,
            voiceSynthesis: ownerSynthesis,
            source: source
        )
    }

    private func makeEchoQAEvidenceBundle(
        snapshot: EchoRuntimeDiagnosticsSnapshot?,
        source: String
    ) -> EchoQAEvidenceBundle {
        let package = makeEchoTraceEvidencePackage(snapshot: snapshot, source: source)
        return EchoQAEvidenceBundle(
            evidencePackage: package,
            answerGrounding: lastEchoAnswerGroundingEvidence,
            ownerTruthContextCitationEvidence: lastOwnerTruthContextCitationEvidence,
            ownerTruthContextParityEvidence: lastOwnerTruthContextParityEvidence,
            ownerTruthContextCompareEvidence: lastOwnerTruthContextCompareEvidence
        )
    }

    @discardableResult
    private func recordOwnerTruthContextCitationQAEvidence(
        _ summary: OwnerTruthContextCitationTraceSummary
    ) -> Bool {
        guard OwnerTruthContextCitationQAGate.isEnabled else {
            lastOwnerTruthContextCitationEvidence = nil
            return false
        }
        lastOwnerTruthContextCitationEvidence = OwnerTruthContextCitationQAEvidenceReadout(summary: summary)
        return true
    }

    @discardableResult
    private func recordOwnerTruthContextParityQAEvidence(
        _ evidence: EchoOwnerTruthContextParityQAEvidenceReadout
    ) -> Bool {
        guard OwnerTruthContextCitationQAGate.isEnabled,
              OwnerTruthMigrationParityQAGate.isEnabled else {
            lastOwnerTruthContextParityEvidence = nil
            return false
        }
        lastOwnerTruthContextParityEvidence = evidence
        return true
    }

    @discardableResult
    private func recordOwnerTruthContextCompareQAEvidence(
        _ evidence: EchoOwnerTruthContextShadowCompareQAEvidenceReadout
    ) -> Bool {
        guard OwnerTruthContextCitationQAGate.isEnabled,
              OwnerTruthMigrationParityQAGate.isEnabled else {
            lastOwnerTruthContextCompareEvidence = nil
            return false
        }
        lastOwnerTruthContextCompareEvidence = evidence
        return true
    }

    private func renderEchoRuntimeDiagnosticsPanel(snapshot: EchoRuntimeDiagnosticsSnapshot) {
        guard shouldShowEchoRuntimeDiagnosticsPanel else {
            return
        }
        let contextClues = EchoContextV2ClueSummary(record: lastEchoTraceRecord)
        let archiveIDHashes = snapshot.archiveItemIDs.isEmpty
            ? "none"
            : snapshot.archiveItemIDs
                .prefix(3)
                .map { PrivacySafeDiagnostics.correlationHash($0) }
                .joined(separator: ",")
        let fallback = PrivacySafeDiagnostics.safeCode(
            snapshot.fallbackReason,
            fallback: "none"
        )
        let voiceProfileHash = PrivacySafeDiagnostics.correlationHash(snapshot.voiceProfileId)
        let voiceExitEvidenceState = PrivacySafeDiagnostics.safeCode(
            snapshot.voiceProfileExitEvidenceState,
            fallback: "unknown"
        )
        let voiceExitState = PrivacySafeDiagnostics.safeCode(
            snapshot.voiceProfileExitState,
            fallback: "notApplicable"
        )
        let voiceLocalCleanupState = PrivacySafeDiagnostics.safeCode(
            snapshot.voiceProfileLocalCleanupState,
            fallback: "notApplicable"
        )
        let voiceProviderCleanupState = PrivacySafeDiagnostics.safeCode(
            snapshot.voiceProfileProviderCleanupState,
            fallback: "notApplicable"
        )
        let voiceAccessRevoked = snapshot.voiceProfileAccessRevoked.map(String.init) ?? "unknown"
        let voiceProviderCleanupReceipt = snapshot.voiceProfileProviderCleanupReceiptAvailable.map(String.init) ?? "unknown"
        let policyLines = (snapshot.featurePolicyDecisions ?? []).map { decision in
            let revision = decision.validatedPolicyRevision ?? decision.capturedPolicyRevision ?? 0
            return "policy.\(decision.feature): \(decision.allowed ? "allow" : "deny") "
                + "v=\(PrivacySafeDiagnostics.safeCode(decision.policyVersion, fallback: "none")) "
                + "r=\(revision) reason=\(PrivacySafeDiagnostics.safeCode(decision.reason, fallback: "redacted"))"
        }
        let capabilityLines = [
            RuntimeCapabilitySnapshotStore.shared.snapshot(for: .voiceCloneShell),
            RuntimeCapabilitySnapshotStore.shared.snapshot(for: .digitalHumanLivePanel),
        ].compactMap { capability in
            capability.map { "capability.\($0.diagnosticSummary)" }
        }
        let ownerTruthContextLines = lastOwnerTruthContextCitationEvidence?.panelLines() ?? []
        let answerGroundingLines = lastEchoAnswerGroundingEvidence?.panelLines() ?? []
        let ownerTruthContextParityLines = lastOwnerTruthContextParityEvidence?.panelLines() ?? []
        let ownerTruthContextCompareLines = lastOwnerTruthContextCompareEvidence?.panelLines() ?? []
        let baseLines = [
            "Echo QA clues",
            "turnHash: \(PrivacySafeDiagnostics.correlationHash(snapshot.turnID))",
            "档案: \(snapshot.archiveItemsIncluded)/\(snapshot.archiveItemsAvailable) [\(archiveIDHashes)]",
            "KBLite facts: \(snapshot.kbFactCount)",
            "personaHash: \(PrivacySafeDiagnostics.correlationHash(snapshot.privacyScopeLabel))",
            "family: \(snapshot.canUseFamilyData) cross: \(snapshot.crossScopeArchiveIncluded)",
            "voiceHash: \(voiceProfileHash) \(PrivacySafeDiagnostics.safeCode(snapshot.voiceOutputMode, fallback: "unknown"))",
            "outputMode: \(PrivacySafeDiagnostics.safeCode(snapshot.voiceOutputMode, fallback: "unknown"))",
            "roleVoiceSource: \(PrivacySafeDiagnostics.safeCode(snapshot.roleVoiceSource, fallback: "unknown"))",
            "roleVoiceDisplayNameHash: \(PrivacySafeDiagnostics.correlationHash(snapshot.roleVoiceDisplayName))",
            "roleVoiceContextOwnerHash: \(PrivacySafeDiagnostics.correlationHash(snapshot.roleVoiceContextOwnerId))",
            "voiceExit: evidence=\(voiceExitEvidenceState) state=\(voiceExitState) accessRevoked=\(voiceAccessRevoked) local=\(voiceLocalCleanupState) provider=\(voiceProviderCleanupState) receipt=\(voiceProviderCleanupReceipt)",
            "audioOwner: \(PrivacySafeDiagnostics.safeCode(snapshot.audioOwner, fallback: "unknown"))",
            "digitalHuman: \(PrivacySafeDiagnostics.safeCode(snapshot.digitalHumanRuntimeState, fallback: "redacted")) / \(PrivacySafeDiagnostics.safeCode(snapshot.digitalHumanProviderMode, fallback: "unknown"))",
            "providerLogIdHash: \(PrivacySafeDiagnostics.correlationHash(snapshot.providerLogId))",
            "fallback: \(fallback)",
            "latencyMs: \(snapshot.contextLatencyMs)"
        ]
        echoRuntimeDiagnosticsPanelLabel.text = (
            [baseLines[0]]
                + ownerTruthContextLines
                + answerGroundingLines
                + ownerTruthContextParityLines
                + ownerTruthContextCompareLines
                + Array(baseLines.dropFirst())
                + capabilityLines
                + policyLines
                + contextClues.panelLines(prefix: "ctx")
        )
            .joined(separator: "\n")
        echoRuntimeDiagnosticsScrollView.setContentOffset(.zero, animated: false)
        echoRuntimeDiagnosticsPanelView.isHidden = false
        echoRuntimeDiagnosticsPanelView.alpha = 1
        echoRuntimeDiagnosticsPanelView.accessibilityLabel = echoRuntimeDiagnosticsPanelLabel.text
    }

    @objc private func exportEchoTraceEvidencePackageTapped() {
        do {
            let exportURL = try exportEchoQAEvidenceBundleForQA(source: "qaPanelManualExport")
            echoTraceEvidenceExportButton.setTitle("已生成证据包", for: .normal)
            presentEchoTraceEvidencePackageShareSheet(fileURL: exportURL)
        } catch {
            echoTraceEvidenceExportButton.setTitle("导出失败", for: .normal)
            let alert = UIAlertController(
                title: "证据包导出失败",
                message: error.localizedDescription,
                preferredStyle: .alert
            )
            alert.addAction(UIAlertAction(title: "知道了", style: .default))
            present(alert, animated: true)
        }
    }

    @discardableResult
    private func exportEchoTraceEvidencePackageForQA(source: String) throws -> URL {
        let snapshot = recordEchoRuntimeDiagnosticsSnapshot(reason: source)
        let package = makeEchoTraceEvidencePackage(snapshot: snapshot, source: source)
        guard let ownerUserId = package.derivedOwnerUserId else {
            throw EchoTraceStorageError.invalidEvidenceOwner
        }
        return try EchoTraceEvidencePackageStore.shared.exportRecentPackages(ownerUserId: ownerUserId)
    }

    @discardableResult
    private func exportEchoQAEvidenceBundleForQA(source: String) throws -> URL {
        let snapshot = recordEchoRuntimeDiagnosticsSnapshot(reason: source)
        let bundle = makeEchoQAEvidenceBundle(snapshot: snapshot, source: source)
        guard let ownerUserId = bundle.derivedOwnerUserId else {
            throw EchoTraceStorageError.invalidEvidenceOwner
        }
        EchoQAEvidenceBundleStore.shared.record(bundle, ownerUserId: ownerUserId)
        let exportURL = try EchoQAEvidenceBundleStore.shared.exportLatestBundle(ownerUserId: ownerUserId)
        let artifactData = try Data(contentsOf: exportURL)
        guard EchoQAEvidenceManifestStore.shared.record(
            bundle: bundle,
            ownerUserId: ownerUserId,
            artifactData: artifactData
        ) != nil else {
            throw EchoTraceStorageError.invalidEvidenceOwner
        }
        return exportURL
    }

    private func presentEchoTraceEvidencePackageShareSheet(fileURL: URL) {
        let activityViewController = UIActivityViewController(activityItems: [fileURL], applicationActivities: nil)
        if let popover = activityViewController.popoverPresentationController {
            popover.sourceView = echoTraceEvidenceExportButton
            popover.sourceRect = echoTraceEvidenceExportButton.bounds
        }
        present(activityViewController, animated: true)
    }

    private func prepareCloudDigitalHumanRuntimeIfNeeded(
        lifecycleToken providedLifecycleToken: DigitalHumanLifecycleToken? = nil
    ) {
        guard !viewModel.isNeutralSafetyMode,
              let accountLease = echoAccountLease,
              validateEchoAccountLease(
                at: .request,
                expected: accountLease,
                  reason: "prepareCloudRuntime"
              ) else { return }
        let context = DigitalHumanContextStore.shared.current
        let routeDecision = echoV4IdentityRouteDecision(
            for: context,
            accountLease: accountLease
        )
        guard routeDecision.route == .ownerPrivate else {
            releaseDigitalHumanRuntime(
                reason: "identityRoute:\(routeDecision.route.rawValue)",
                resetsAudioOwnerToOrdinaryEcho: true,
                recordsDiagnostics: false
            )
            digitalHumanLivePanelView?.isHidden = true
            lastEchoRuntimeFallbackReason = routeDecision.reason
            recordEchoRuntimeDiagnosticsSnapshot(reason: routeDecision.reason)
            PrivacySafeDiagnostics.log(
                subsystem: "TencentDigitalHuman",
                event: "providerSessionSkipped",
                states: [
                    "identityRoute": routeDecision.route.rawValue,
                    "reason": routeDecision.reason,
                ]
            )
            return
        }
        digitalHumanLivePanelView?.isHidden = false
        if reconcileDigitalHumanRuntimeWithCurrentContext(reason: "prepare") {
            scheduleCloudDigitalHumanRuntimeRecovery(
                reason: "prepareContextChanged",
                delay: Self.tencentDigitalHumanContextSwitchReconnectDelay
            )
            return
        }
        let contextKey = digitalHumanRuntimeContextKey(for: context)
        let requestOwnerUserId = accountLease.subjectId
        let lifecycleToken = providedLifecycleToken
            ?? captureDigitalHumanLifecycleToken(reason: "prepareCloudRuntime")
        guard isCurrentDigitalHumanSessionToken(
            lifecycleToken,
            reason: "prepareCloudRuntime"
        ) else {
            return
        }
        guard shouldShowDigitalHumanLivePanel,
              digitalHumanRuntime == nil,
              hasRequestedCloudDigitalHumanRuntime == false || pendingDigitalHumanSessionContextKey != contextKey else {
            return
        }
        hasRequestedCloudDigitalHumanRuntime = true
        let requestID = UUID().uuidString
        pendingDigitalHumanSessionRequestID = requestID
        pendingDigitalHumanSessionContextKey = contextKey
        let runtimeSessionCallback = echoRuntimeSessionCoordinator.beginSessionRequest(
            accountLease: accountLease,
            lifecycleToken: lifecycleToken,
            contextKey: contextKey,
            requestID: requestID
        )

        guard DreamJourneyBackendClient.shared.isDigitalHumanSessionConfigured else {
            echoRuntimeSessionCoordinator.releaseRuntime()
            pendingDigitalHumanSessionRequestID = nil
            pendingDigitalHumanSessionContextKey = nil
            hasRequestedCloudDigitalHumanRuntime = false
            digitalHumanStatusDetailLabel.text = "数字人暂不可用，已回到普通回响"
            digitalHumanLivePanelView?.removeHostedProviderView(showFallbackMessage: "数字人暂不可用")
            lastDigitalHumanSessionEvidenceSummary = .unavailable(
                ownerUserId: requestOwnerUserId,
                reason: "digitalHumanBackendNotConfigured"
            )
            lastEchoRuntimeFallbackReason = "digitalHumanBackendNotConfigured"
            recordEchoRuntimeDiagnosticsSnapshot(reason: "digitalHumanBackendNotConfigured")
            applyEchoAudioRoutePolicy()
            print("[TencentDigitalHuman] skipped cloud runtime; backend not configured")
            return
        }

        digitalHumanStatusDetailLabel.text = "正在连接腾讯数智人"
        digitalHumanLivePanelView?.showProviderPlaceholder("正在连接腾讯数智人")

        DreamJourneyBackendClient.shared.fetchDigitalHumanRuntimeCapability { [weak self] result in
            switch result {
            case .success(let capability):
                DispatchQueue.main.async {
                    guard let self,
                          self.isCurrentDigitalHumanSessionToken(
                            lifecycleToken,
                            reason: "runtimeCapabilitySuccess"
                          ),
                          self.isCurrentEchoRuntimeSessionCallback(
                            runtimeSessionCallback,
                            reason: "runtimeCapabilitySuccess"
                          ),
                          self.isCurrentDigitalHumanSessionRequest(requestID: requestID, contextKey: contextKey) else {
                        PrivacySafeDiagnostics.log(
                            subsystem: "TencentDigitalHuman",
                            event: "runtimeCapabilityIgnored",
                            states: ["reason": "staleResponse"],
                            correlations: ["request": requestID]
                        )
                        return
                    }
                    guard capability.allowsClientSessionRequest else {
                        self.failClosedDigitalHumanRuntimePreparation(
                            requestOwnerUserId: requestOwnerUserId,
                            reason: "digitalHumanRuntimeCapabilityUnavailable",
                            detail: capability.axisSnapshot.diagnosticSummary
                        )
                        return
                    }
                    self.createCloudDigitalHumanSession(
                        capability: capability,
                        context: context,
                        contextKey: contextKey,
                        requestID: requestID,
                        lifecycleToken: lifecycleToken,
                        runtimeSessionCallback: runtimeSessionCallback,
                        accountLease: accountLease,
                        requestOwnerUserId: requestOwnerUserId
                    )
                }
            case .failure(let error):
                DispatchQueue.main.async {
                    guard let self,
                          self.isCurrentDigitalHumanSessionToken(
                            lifecycleToken,
                            reason: "runtimeCapabilityFailure"
                          ),
                          self.isCurrentEchoRuntimeSessionCallback(
                            runtimeSessionCallback,
                            reason: "runtimeCapabilityFailure"
                          ),
                          self.isCurrentDigitalHumanSessionRequest(requestID: requestID, contextKey: contextKey) else {
                        PrivacySafeDiagnostics.log(
                            subsystem: "TencentDigitalHuman",
                            event: "runtimeCapabilityIgnored",
                            states: ["reason": "staleFailure"],
                            correlations: ["request": requestID]
                        )
                        return
                    }
                    self.echoRuntimeSessionCoordinator.releaseRuntime()
                    self.pendingDigitalHumanSessionRequestID = nil
                    self.pendingDigitalHumanSessionContextKey = nil
                    self.hasRequestedCloudDigitalHumanRuntime = false
                    self.digitalHumanStatusDetailLabel.text = "数字人配置读取失败，已回到普通回响"
                    self.digitalHumanLivePanelView?.removeHostedProviderView(showFallbackMessage: "数字人暂不可用")
                    self.lastDigitalHumanSessionEvidenceSummary = .failed(
                        ownerUserId: requestOwnerUserId,
                        reason: "digitalHumanRuntimeCapabilityFailed",
                        detail: error.localizedDescription
                    )
                    self.lastEchoRuntimeFallbackReason = "digitalHumanRuntimeCapabilityFailed"
                    self.recordEchoRuntimeDiagnosticsSnapshot(reason: "digitalHumanRuntimeCapabilityFailed")
                    self.applyEchoAudioRoutePolicy()
                    PrivacySafeDiagnostics.log(
                        subsystem: "TencentDigitalHuman",
                        event: "runtimeCapabilityFailed",
                        states: ["reason": "backendFailure"]
                    )
                }
            }
        }
    }

    private func failClosedDigitalHumanRuntimePreparation(
        requestOwnerUserId: String,
        reason: String,
        detail: String? = nil
    ) {
        echoRuntimeSessionCoordinator.releaseRuntime()
        pendingDigitalHumanSessionRequestID = nil
        pendingDigitalHumanSessionContextKey = nil
        hasRequestedCloudDigitalHumanRuntime = false
        digitalHumanStatusDetailLabel.text = "数字人暂不可用，已回到普通回响"
        digitalHumanLivePanelView?.removeHostedProviderView(showFallbackMessage: "数字人暂不可用")
        lastDigitalHumanSessionEvidenceSummary = .unavailable(
            ownerUserId: requestOwnerUserId,
            reason: reason,
            detail: detail
        )
        lastEchoRuntimeFallbackReason = reason
        recordEchoRuntimeDiagnosticsSnapshot(reason: reason)
        applyEchoAudioRoutePolicy()
        PrivacySafeDiagnostics.log(
            subsystem: "TencentDigitalHuman",
            event: "runtimeCapabilityRejected",
            states: ["reason": reason]
        )
    }

    private func createCloudDigitalHumanSession(
        capability: DigitalHumanRuntimeCapability,
        context: DigitalHumanContext,
        contextKey: String,
        requestID: String,
        lifecycleToken: DigitalHumanLifecycleToken,
        runtimeSessionCallback: EchoRuntimeCallbackToken,
        accountLease: AccountLease,
        requestOwnerUserId: String
    ) {
        guard capability.allowsClientSessionRequest else {
            failClosedDigitalHumanRuntimePreparation(
                requestOwnerUserId: requestOwnerUserId,
                reason: "digitalHumanRuntimeCapabilityRejectedBeforeSession",
                detail: capability.axisSnapshot.diagnosticSummary
            )
            return
        }
        let deviceId = UIDevice.current.identifierForVendor?.uuidString ?? "ios-device"
        guard let scope = VoiceDigitalHumanOperationScope(
            accountLease: accountLease,
            personaOwnerId: context.ownerId,
            roleKey: context.mode.rawValue,
            runtimeGeneration: runtimeSessionCallback.runtimeGeneration
        ), let request = DigitalHumanSessionRequest(
            scope: scope,
            scene: "echo",
            deviceId: deviceId,
            lifecycleMode: context.mode
        ) else {
            PrivacySafeDiagnostics.log(
                subsystem: "TencentDigitalHuman",
                event: "sessionRequestRejected",
                states: ["reason": "typedScopeInvalid"]
            )
            return
        }
        digitalHumanSessionClient.createDigitalHumanSession(request) { [weak self] result in
            DispatchQueue.main.async {
                self?.handleCloudDigitalHumanSession(
                    result,
                    capability: capability,
                    context: context,
                    contextKey: contextKey,
                    requestID: requestID,
                    lifecycleToken: lifecycleToken,
                    runtimeSessionCallback: runtimeSessionCallback,
                    accountLease: accountLease,
                    requestOwnerUserId: requestOwnerUserId
                )
            }
        }
    }

    private func handleCloudDigitalHumanSession(
        _ result: Result<DigitalHumanSessionContract, Error>,
        capability: DigitalHumanRuntimeCapability,
        context: DigitalHumanContext,
        contextKey: String,
        requestID: String,
        lifecycleToken: DigitalHumanLifecycleToken,
        runtimeSessionCallback: EchoRuntimeCallbackToken,
        accountLease: AccountLease,
        requestOwnerUserId: String
    ) {
        let activeOwnerUserId = EchoTraceOwnerScope.normalizedOwnerUserId(UserManager.shared.currentUser?.id)
        guard activeOwnerUserId == EchoTraceOwnerScope.normalizedOwnerUserId(requestOwnerUserId),
              validateEchoAccountLease(
                at: .ui,
                expected: accountLease,
                reason: "digitalHumanSessionResponse"
              ),
              isCurrentDigitalHumanSessionToken(
                lifecycleToken,
                reason: "digitalHumanSessionResponse"
              ),
              isCurrentEchoRuntimeSessionCallback(
                runtimeSessionCallback,
                reason: "digitalHumanSessionResponse"
              ),
              isCurrentDigitalHumanSessionRequest(requestID: requestID, contextKey: contextKey) else {
            if case .success(let staleContract) = result {
                releaseDigitalHumanSessionLease(
                    staleContract,
                    accountLease: accountLease,
                    reason: "staleSessionResponse"
                )
            }
            PrivacySafeDiagnostics.log(
                subsystem: "TencentDigitalHuman",
                event: "sessionResponseIgnored",
                states: ["reason": "staleResponse"],
                correlations: ["request": requestID]
            )
            return
        }
        pendingDigitalHumanSessionRequestID = nil
        pendingDigitalHumanSessionContextKey = nil
        hasRequestedCloudDigitalHumanRuntime = false

        switch result {
        case .success(let contract):
            guard capability.allowsClientSessionRequest else {
                releaseDigitalHumanSessionLease(
                    contract,
                    accountLease: accountLease,
                    reason: "runtimeCapabilityRejectedAfterSession"
                )
                failClosedDigitalHumanRuntimePreparation(
                    requestOwnerUserId: requestOwnerUserId,
                    reason: "digitalHumanRuntimeCapabilityRejectedAfterSession",
                    detail: capability.axisSnapshot.diagnosticSummary
                )
                return
            }
            guard contract.isUsableForClientRuntime else {
                releaseDigitalHumanSessionLease(
                    contract,
                    accountLease: accountLease,
                    reason: "expiredOrMalformedSessionContract"
                )
                failClosedDigitalHumanRuntimePreparation(
                    requestOwnerUserId: requestOwnerUserId,
                    reason: "digitalHumanSessionContractExpiredOrMalformed"
                )
                return
            }
            let activation = echoRuntimeSessionCoordinator.activateSession(
                runtimeSessionCallback,
                sessionID: contract.sessionId,
                providerAssetID: contract.assetKey ?? contract.providerAssetId,
                expiresAt: contract.lease?.expiresAt ?? contract.credential.expiresAt
            )
            guard activation == .accepted else {
                releaseDigitalHumanSessionLease(
                    contract,
                    accountLease: accountLease,
                    reason: "runtimeSessionActivationRejected"
                )
                PrivacySafeDiagnostics.log(
                    subsystem: "TencentDigitalHuman",
                    event: "sessionResponseIgnored",
                    states: ["reason": "runtimeSessionActivationRejected"],
                    correlations: ["request": requestID]
                )
                return
            }
            guard let activeRuntimeSessionCallback = echoRuntimeSessionCoordinator.currentSessionCallbackToken() else {
                releaseDigitalHumanSessionLease(
                    contract,
                    accountLease: accountLease,
                    reason: "runtimeSessionCallbackMissing"
                )
                echoRuntimeSessionCoordinator.releaseRuntime()
                PrivacySafeDiagnostics.log(
                    subsystem: "TencentDigitalHuman",
                    event: "sessionResponseIgnored",
                    states: ["reason": "runtimeSessionCallbackMissing"],
                    correlations: ["request": requestID]
                )
                return
            }
            activateDigitalHumanSessionLease(
                contract,
                lifecycleToken: lifecycleToken,
                runtimeSessionCallback: activeRuntimeSessionCallback
            )
            let profile = contract.toDigitalHumanProfile(displayName: context.resolvedDisplayName)
            lastDigitalHumanSessionEvidenceSummary = EchoDigitalHumanSessionEvidenceSummary(
                contract: contract,
                ownerUserId: requestOwnerUserId
            )
            PrivacySafeDiagnostics.log(
                subsystem: "TencentDigitalHuman",
                event: "sessionContractReceived",
                states: [
                    "assetSource": contract.assetSource,
                    "hasAsset": String((contract.assetKey ?? contract.providerAssetId) != nil),
                    "hasProject": String(contract.providerProjectId != nil),
                    "provider": contract.provider,
                    "providerMode": contract.providerMode,
                ],
                correlations: [
                    "asset": contract.assetKey ?? contract.providerAssetId,
                    "project": contract.providerProjectId,
                ]
            )
            let runtimeSelection = DigitalHumanRuntimeFactory.makeRuntime(
                for: contract,
                capability: capability
            )
            let runtime = runtimeSelection.runtime
            if let existingRuntime = digitalHumanRuntime,
               existingRuntime !== runtime {
                existingRuntime.interrupt()
                existingRuntime.close()
                print("[TencentDigitalHuman] closed duplicate runtime before binding current session")
            }
            digitalHumanRuntime = runtime
            digitalHumanRuntimeContextKey = contextKey
            digitalHumanRuntimeLifecycleGeneration = lifecycleToken.generation
            bindDigitalHumanRuntimeState(
                runtime,
                lifecycleToken: lifecycleToken,
                runtimeSessionCallback: activeRuntimeSessionCallback
            )

            guard runtimeSelection.isRealSDKBacked else {
                runtime.interrupt()
                runtime.close()
                digitalHumanRuntime = nil
                digitalHumanRuntimeContextKey = nil
                digitalHumanRuntimeLifecycleGeneration = nil
                releaseActiveDigitalHumanSessionLease(reason: "runtimeNotSDKBacked")
                echoRuntimeSessionCoordinator.releaseRuntime()
                digitalHumanStatusDetailLabel.text = "腾讯 SDK 暂不可用，已回到普通回响"
                digitalHumanLivePanelView?.removeHostedProviderView(showFallbackMessage: "数字人暂不可用")
                lastEchoRuntimeFallbackReason = runtimeSelection.fallbackReason ?? "digitalHumanRuntimeNotSDKBacked"
                recordEchoRuntimeDiagnosticsSnapshot(reason: "digitalHumanRuntimeNotSDKBacked")
                applyEchoAudioRoutePolicy()
                PrivacySafeDiagnostics.log(
                    subsystem: "TencentDigitalHuman",
                    event: "runtimeFallback",
                    states: ["reason": runtimeSelection.fallbackReason ?? "unknown"]
                )
                return
            }

            digitalHumanLivePanelView?.hostProviderView(runtime.contentView)
            do {
                try runtime.configure(profile)
                lastEchoRuntimeFallbackReason = nil
                applyEchoAudioRoutePolicy()
                try runtime.open()
                digitalHumanStatusDetailLabel.text = "腾讯云渲染连接中"
                applyEchoAudioRoutePolicy()
            } catch {
                runtime.interrupt()
                runtime.close()
                digitalHumanRuntime = nil
                digitalHumanRuntimeContextKey = nil
                digitalHumanRuntimeLifecycleGeneration = nil
                releaseActiveDigitalHumanSessionLease(reason: "digitalHumanOpenFailed")
                echoRuntimeSessionCoordinator.releaseRuntime()
                digitalHumanStatusDetailLabel.text = "腾讯数智人打开失败，已回到普通回响"
                digitalHumanLivePanelView?.removeHostedProviderView(showFallbackMessage: "数字人暂不可用")
                lastEchoRuntimeFallbackReason = "digitalHumanOpenFailed"
                recordEchoRuntimeDiagnosticsSnapshot(reason: "digitalHumanOpenFailed")
                applyEchoAudioRoutePolicy()
                PrivacySafeDiagnostics.log(
                    subsystem: "TencentDigitalHuman",
                    event: "runtimeOpenFailed",
                    states: ["reason": "openFailed"]
                )
            }
        case .failure(let error):
            echoRuntimeSessionCoordinator.releaseRuntime()
            let reason = error.localizedDescription
            let quotaFailure = isDigitalHumanQuotaFailure(reason)
            digitalHumanStatusDetailLabel.text = quotaFailure
                ? "腾讯数智人并发配额已满，已回到普通回响"
                : "数字人会话创建失败，已回到普通回响"
            digitalHumanLivePanelView?.removeHostedProviderView(
                showFallbackMessage: quotaFailure ? "数智人配额已满" : "数字人暂不可用"
            )
            lastDigitalHumanSessionEvidenceSummary = .failed(
                ownerUserId: requestOwnerUserId,
                reason: quotaFailure
                    ? "digital_human_session_capacity_exhausted"
                    : "digitalHumanSessionFailed",
                detail: reason
            )
            lastEchoRuntimeFallbackReason = quotaFailure
                ? "digital_human_session_capacity_exhausted"
                : "digitalHumanSessionFailed"
            recordEchoRuntimeDiagnosticsSnapshot(reason: "digitalHumanSessionFailed")
            applyEchoAudioRoutePolicy()
            PrivacySafeDiagnostics.log(
                subsystem: "TencentDigitalHuman",
                event: "sessionFailed",
                states: [
                    "reason": quotaFailure
                        ? "digital_human_session_capacity_exhausted"
                        : "digitalHumanSessionFailed",
                ]
            )
        }
    }

    private func normalizedDigitalHumanReplyText(_ text: String) -> String {
        text.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func digitalHumanReplyLooksComplete(_ text: String) -> Bool {
        guard let lastCharacter = text.last else { return false }
        return ["。", "！", "？", ".", "!", "?"].contains(String(lastCharacter))
    }

    private func tencentDigitalHumanDialogResumeDelay(for text: String?) -> TimeInterval {
        let characterCount = text?.trimmingCharacters(in: .whitespacesAndNewlines).count ?? 0
        guard characterCount > Self.tencentDigitalHumanLongReplyCharacterThreshold else {
            return Self.tencentDigitalHumanPostTextOverResumeDelay
        }
        return Self.tencentDigitalHumanPostTextOverResumeDelay + Self.tencentDigitalHumanLongReplyExtraResumeDelay
    }

    private func scheduleDigitalHumanReplyPrewarm(_ text: String) {
        let normalizedText = normalizedDigitalHumanReplyText(text)
        guard shouldShowDigitalHumanLivePanel,
              shouldDispatchEchoReplyToTencentProvider,
              !viewModel.isWaitingForDelayedReply,
              !normalizedText.isEmpty else {
            return
        }

        cancelDigitalHumanReplyPrewarm()
        let delay = digitalHumanReplyLooksComplete(normalizedText)
            ? Self.digitalHumanReplyPrewarmShortDelay
            : Self.digitalHumanReplyPrewarmDebounceDelay
        let lifecycleToken = captureDigitalHumanLifecycleToken(reason: "replyPrewarm")
        let workItem = DispatchWorkItem { [weak self] in
            guard let self,
                  self.isCurrentDigitalHumanLifecycleToken(
                    lifecycleToken,
                    reason: "replyPrewarm"
                  ) else { return }
            self.digitalHumanReplyPrewarmWorkItem = nil
            self.sendEchoReplyToDigitalHumanRuntimeIfReady(normalizedText, source: "chatStreamingPrewarm")
        }
        digitalHumanReplyPrewarmWorkItem = workItem
        DispatchQueue.main.asyncAfter(deadline: .now() + delay, execute: workItem)
        PrivacySafeDiagnostics.log(
            subsystem: "TencentDigitalHuman",
            event: "replyPrewarmScheduled",
            states: ["source": "chatStreamingPrewarm"],
            counts: [
                "delayMs": Int(delay * 1_000),
                "textLength": normalizedText.count,
            ]
        )
    }

    private func cancelDigitalHumanReplyPrewarm() {
        digitalHumanReplyPrewarmWorkItem?.cancel()
        digitalHumanReplyPrewarmWorkItem = nil
    }

    private func resetDigitalHumanReplyDispatchState() {
        cancelLivePlaybackReceipt(reason: "digitalHumanDispatchReset")
        digitalHumanConversation.reset(
            cancelPrewarm: cancelDigitalHumanReplyPrewarm,
            cancelTextOverTimeout: cancelTencentDigitalHumanTextOverTimeout
        )
    }

    @discardableResult
    private func prepareAudioSessionForTencentProviderPlayback(
        preserveRecordingCategory: Bool
    ) -> Bool {
        let acquired = acquireEchoRuntimeAudioOwner(
            .tencentDigitalHumanPlayback,
            priority: .tencentDigitalHumanPlayback,
            reason: "prepareTencentProviderPlayback"
        )
        if acquired {
            PrivacySafeDiagnostics.log(
                subsystem: "TencentDigitalHuman",
                event: "audioSessionCoordinatorPrepared",
                states: [
                    "category": "playAndRecord",
                    "preserveRecordingCategory": String(preserveRecordingCategory),
                ]
            )
        } else {
            PrivacySafeDiagnostics.log(
                subsystem: "TencentDigitalHuman",
                event: "audioSessionCoordinatorPrepareFailed",
                states: ["reason": "leaseActivationFailed"]
            )
        }
        return acquired
    }

    private func markTencentProviderAudioHandoff(reason: String) {
        lastTencentProviderAudioHandoffAt = Date()
        print("[TencentDigitalHuman] provider audio handoff marked reason=\(reason)")
    }

    @discardableResult
    private func pauseDialogEngineForTencentProviderSpeechIfNeeded() -> Bool {
        guard routeEchoAudioThroughDigitalHuman,
              ownsCurrentDialogEngineBinding(),
              DialogEngineManager.shared.isDialogActive else {
            return false
        }
        digitalHumanConversation.markPausingForProviderSpeech()
        cancelLiveUserInactivityTimeout()
        markTencentProviderAudioHandoff(reason: "pauseDialogEngineForProviderSpeech")
        guard DialogEngineManager.shared.pauseRecorder() else {
            digitalHumanConversation.clearResumeState()
            PrivacySafeDiagnostics.log(
                subsystem: "TencentDigitalHuman",
                event: "dialogRecorderPauseFailed",
                states: ["reason": "providerSpeechHandoff"]
            )
            return false
        }
        print("[TencentDigitalHuman] paused recorder in existing Live session before provider speech")
        return true
    }

    private func shouldSuppressDialogEngineErrorDuringTencentProviderSpeech(_ error: Error) -> Bool {
        guard routeEchoAudioThroughDigitalHuman else {
            return false
        }

        if isTransientDialogEngineAudioRouteError(error) {
            return true
        }

        let isSDKError: Bool
        if let dialogEngineError = error as? DialogEngineError,
           case .sdkError = dialogEngineError {
            isSDKError = true
        } else {
            let description = error.localizedDescription.lowercased()
            isSDKError = description.contains("sami error") || description.contains("sdk")
        }
        guard isSDKError else {
            return false
        }

        if hasTencentDigitalHumanProviderSpeechInFlight || digitalHumanConversation.isPausingForProviderSpeech {
            return true
        }

        if let lastTencentProviderAudioHandoffAt,
           Date().timeIntervalSince(lastTencentProviderAudioHandoffAt) <= Self.tencentProviderDialogErrorSuppressionWindow {
            return true
        }

        return false
    }

    private func isTransientDialogEngineAudioRouteError(_ error: Error) -> Bool {
        let description = error.localizedDescription.lowercased()
        return description.contains("opus encode input audio size")
            || (description.contains("未知错误") && description.contains("error domain"))
            || (description.contains("err_msg") && description.contains("error domain"))
    }

    private func sanitizedDialogEngineErrorMessage(_ error: Error) -> String {
        if isTransientDialogEngineAudioRouteError(error) {
            return "音频正在切换，请再说一次"
        }
        let message = error.localizedDescription
        if message.contains("Error Domain") || message.contains("err_msg") {
            return "语音服务暂时不稳定，请再试一次"
        }
        return message
    }

    @discardableResult
    private func resumeDialogEngineAfterTencentProviderSpeechIfNeeded(
        reason: String,
        lifecycleToken providedLifecycleToken: DigitalHumanLifecycleToken? = nil
    ) -> Bool {
        guard !isLiveFarewellActive else { return false }
        let lifecycleToken = providedLifecycleToken
            ?? captureDigitalHumanLifecycleToken(reason: "resumeDialog:\(reason)")
        guard isCurrentDigitalHumanLifecycleToken(
            lifecycleToken,
            reason: "resumeDialog:\(reason)"
        ) else {
            return false
        }
        guard digitalHumanConversation.consumeResumeAfterProviderSpeech() else {
            return false
        }
        guard shouldShowDigitalHumanLivePanel,
              view.window != nil else {
            return true
        }
        guard bindDialogEngineToEchoAccountLease(reason: "resumeDialog:\(reason)") else {
            return false
        }
        DialogEngineManager.shared.delegate = self
        if ownsCurrentDialogEngineBinding(),
           DialogEngineManager.shared.isDialogActive {
            muteTencentProviderRemoteAudioForUserCapture(reason: reason)
            guard prepareEchoCaptureAudioSession(reason: "resumeDialog:\(reason)"),
                  DialogEngineManager.shared.resumeRecorder() else {
                resumeVoiceCaptureAfterTencentProviderSpeech(
                    reason: "transportRecovery:\(reason)",
                    lifecycleToken: lifecycleToken
                )
                return true
            }
            activeVoiceInteractionLifecycleToken = lifecycleToken
            viewModel.beginVoiceInteraction()
            armLiveUserInactivityTimeout(reason: "resumeDialogAfterProviderSpeech")
            PrivacySafeDiagnostics.log(
                subsystem: "TencentDigitalHuman",
                event: "dialogRecorderResumed",
                states: ["reason": reason]
            )
            print("[TencentDigitalHuman] resumed recorder in existing Live session reason=\(reason)")
            return true
        }
        resumeVoiceCaptureAfterTencentProviderSpeech(
            reason: reason,
            lifecycleToken: lifecycleToken
        )
        print("[TencentDigitalHuman] resumed DialogEngine listening after provider speech reason=\(reason)")
        return true
    }

    private func resumeVoiceCaptureAfterTencentProviderSpeech(
        reason: String,
        lifecycleToken providedLifecycleToken: DigitalHumanLifecycleToken? = nil
    ) {
        let lifecycleToken = providedLifecycleToken
            ?? captureDigitalHumanLifecycleToken(reason: "resumeVoiceCapture:\(reason)")
        guard isCurrentDigitalHumanLifecycleToken(
            lifecycleToken,
            reason: "resumeVoiceCapture:\(reason)"
        ) else {
            return
        }
        guard bindDialogEngineToEchoAccountLease(reason: "resumeVoiceCapture:\(reason)") else {
            return
        }
        activeVoiceInteractionLifecycleToken = lifecycleToken
        DialogEngineManager.shared.delegate = self
        resetDigitalHumanReplyDispatchState()
        muteTencentProviderRemoteAudioForUserCapture(reason: reason)
        viewModel.beginVoiceInteraction()
        let liveAudioRoute = pinLiveAudioRouteIfNeeded(reason: "resumeVoiceCapture:\(reason)")
        if case .unavailable = liveAudioRoute {
            handleBlockedRealtimeVoice(reason: "liveAudioRouteUnavailable")
            return
        }
        applyEchoAudioRoutePolicy()
        if DialogEngineManager.shared.isEngineReady {
            guard prepareEchoCaptureAudioSession(reason: "resumeVoiceCapture:\(reason)") else {
                handleBlockedRealtimeVoice(reason: "audioSessionCoordinatorActivationFailed")
                return
            }
            DialogEngineManager.shared.startDialog(
                sendsGreeting: false,
                usesTurnScopedKnowledgeContext: true,
                lifetimePolicy: .userControlledLive,
                answerAuthority: .dreamJourneyBackend
            )
        } else {
            configureVoiceRuntimeThenStart(lifecycleToken: lifecycleToken)
        }
        if shouldTraceTrueDeviceBackendPCMDrive {
            trueDeviceBackendPCMDriveTrace.resumedVoiceCapture = true
            emitTencentBackendPCMDriveTrueDeviceQAResult(reason: "voiceCaptureResumed:\(reason)")
        }
        PrivacySafeDiagnostics.log(
            subsystem: "TencentDigitalHuman",
            event: "voiceCaptureResumed",
            states: ["reason": reason]
        )
    }

    @discardableResult
    private func muteTencentProviderRemoteAudioForUserCapture(reason: String) -> Bool {
        guard tencentDigitalHumanAudioRouteReserved,
              let cloudRuntime = digitalHumanRuntime as? TencentDigitalHumanCloudRuntime else {
            return false
        }
        stopDigitalHumanAudioLevelMetering()
        cloudRuntime.setRemoteAudioMuted(true)
        setEchoAudioOwner(.fallbackMuted, reason: reason)
        PrivacySafeDiagnostics.log(
            subsystem: "TencentDigitalHuman",
            event: "providerRemoteAudioMuted",
            states: ["reason": reason]
        )
        return true
    }

    private func sendEchoReplyToDigitalHumanRuntimeIfReady(_ text: String, source: String) {
        let normalizedText = normalizedDigitalHumanReplyText(text)
        guard shouldShowDigitalHumanLivePanel,
              shouldDispatchEchoReplyToTencentProvider,
              let digitalHumanRuntime,
              digitalHumanRuntime.profile != nil,
              !normalizedText.isEmpty else {
            return
        }
        guard !digitalHumanConversation.isDuplicateReply(normalizedText) else {
            print("[TencentDigitalHuman] skipped duplicate reply text source=\(source) textLength=\(normalizedText.count)")
            return
        }
        if let activeTencentDigitalHumanRequestID = digitalHumanConversation.activeRequestID {
            print(
                "[TencentDigitalHuman] skipped new request while provider is speaking " +
                "source=\(source) activeRequestID=\(activeTencentDigitalHumanRequestID) " +
                "newLength=\(normalizedText.count)"
            )
            return
        }

        if sendEchoReplyViaTencentVoiceClonePCMDrive(
            normalizedText,
            source: source
        ) {
            return
        }

        showVoiceCloneNotEnabledStatusIfNeeded(source: source)
        sendEchoReplyToTencentTextRuntime(normalizedText, source: source)
    }

    @discardableResult
    private func sendEchoReplyViaTencentVoiceClonePCMDrive(
        _ normalizedText: String,
        source: String
    ) -> Bool {
        let voiceSelection = resolveEchoRoleVoiceProfileSelection()
        guard source != "chatStreamingPrewarm",
              let voiceProfileId = voiceSelection.voiceProfileId else {
            return false
        }
        guard voiceSelection.source == .personalOwner,
              let userId = UserManager.shared.currentUser?.id.trimmingCharacters(in: .whitespacesAndNewlines),
              !userId.isEmpty,
              voiceSelection.contextOwnerId == userId else {
            renderVoiceStatus(
                text: "复刻声音身份状态已变化，本轮未使用默认音色",
                isVisible: true,
                accessibilityIdentifier: "echoVoiceClonePCMDriveStatus"
            )
            lastVoiceSynthesisEvidenceSummary = .unavailable(
                ownerUserId: currentEchoEvidenceOwnerUserId,
                reason: "voiceCloneRoleOwnerMismatch"
            )
            lastEchoRuntimeFallbackReason = "voiceCloneRoleOwnerMismatch"
            recordEchoRuntimeDiagnosticsSnapshot(reason: "voiceCloneRoleOwnerMismatch")
            return true
        }
        guard let voiceCloneUseTicket = VoiceCloneService.shared.capturePersonalSynthesisUseTicket(
            forOwnerId: userId
        ),
        voiceCloneUseTicket.voiceProfileId == voiceProfileId else {
            renderVoiceStatus(
                text: "复刻声音授权状态已变化，本轮不会使用默认音色",
                isVisible: true,
                accessibilityIdentifier: "echoVoiceClonePCMDriveStatus"
            )
            lastVoiceCloneProviderLogId = nil
            lastVoiceCloneProviderRequestId = nil
            lastVoiceCloneProviderMode = nil
            lastVoiceSynthesisEvidenceSummary = .unavailable(
                ownerUserId: currentEchoEvidenceOwnerUserId,
                reason: "voiceCloneUseTicketUnavailable"
            )
            lastEchoRuntimeFallbackReason = "voiceCloneUseTicketUnavailable"
            recordEchoRuntimeDiagnosticsSnapshot(reason: "voiceCloneUseTicketUnavailable")
            return true
        }
        let roleKey = voiceSelection.source.rawValue
        guard DreamJourneyBackendClient.shared.isVoiceCloneSynthesisConfigured else {
            renderVoiceStatus(text: "复刻声音服务暂不可用", isVisible: true, accessibilityIdentifier: "echoVoiceClonePCMDriveStatus")
            lastVoiceCloneProviderLogId = nil
            lastVoiceCloneProviderRequestId = nil
            lastVoiceCloneProviderMode = nil
            lastVoiceSynthesisEvidenceSummary = .unavailable(
                ownerUserId: currentEchoEvidenceOwnerUserId,
                reason: "voiceCloneBackendNotConfigured"
            )
            lastEchoRuntimeFallbackReason = "voiceCloneBackendNotConfigured"
            recordEchoRuntimeDiagnosticsSnapshot(reason: "voiceCloneBackendNotConfigured")
            PrivacySafeDiagnostics.log(
                subsystem: "TencentDigitalHuman",
                event: "voiceClonePCMDriveUnavailable",
                states: [
                    "audioOwner": currentEchoAudioOwner.rawValue,
                    "outputMode": "tencentAudioDrive",
                    "reason": "backendNotConfigured",
                    "voiceSource": voiceSelection.source.rawValue,
                ],
                correlations: [
                    "voiceProfile": voiceProfileId,
                    "contextOwner": voiceSelection.contextOwnerId,
                ]
            )
            return true
        }
        guard let capability = voiceCloneRuntimeCapability else {
            renderVoiceStatus(text: "复刻声音能力读取中，暂不使用默认音色", isVisible: true, accessibilityIdentifier: "echoVoiceClonePCMDriveStatus")
            lastVoiceCloneProviderLogId = nil
            lastVoiceCloneProviderRequestId = nil
            lastVoiceCloneProviderMode = nil
            lastVoiceSynthesisEvidenceSummary = .unavailable(
                ownerUserId: currentEchoEvidenceOwnerUserId,
                reason: "voiceCloneRuntimeCapabilityUnknown"
            )
            lastEchoRuntimeFallbackReason = "voiceCloneRuntimeCapabilityUnknown"
            recordEchoRuntimeDiagnosticsSnapshot(reason: "voiceCloneRuntimeCapabilityUnknown")
            PrivacySafeDiagnostics.log(
                subsystem: "TencentDigitalHuman",
                event: "voiceClonePCMDriveUnavailable",
                states: [
                    "audioOwner": currentEchoAudioOwner.rawValue,
                    "outputMode": "tencentAudioDrive",
                    "reason": "runtimeCapabilityUnknown",
                    "voiceSource": voiceSelection.source.rawValue,
                ],
                correlations: [
                    "voiceProfile": voiceProfileId,
                    "contextOwner": voiceSelection.contextOwnerId,
                ]
            )
            return true
        }
        guard capability.canSynthesize,
              capability.tencentAudioDrive.supported else {
            renderVoiceStatus(text: "复刻声音服务暂不可用", isVisible: true, accessibilityIdentifier: "echoVoiceClonePCMDriveStatus")
            lastVoiceCloneProviderLogId = nil
            lastVoiceCloneProviderRequestId = nil
            lastVoiceCloneProviderMode = nil
            lastVoiceSynthesisEvidenceSummary = .unavailable(
                ownerUserId: currentEchoEvidenceOwnerUserId,
                reason: "voiceCloneRuntimeUnsupported"
            )
            lastEchoRuntimeFallbackReason = "voiceCloneRuntimeUnsupported"
            recordEchoRuntimeDiagnosticsSnapshot(reason: "voiceCloneRuntimeUnsupported")
            PrivacySafeDiagnostics.log(
                subsystem: "TencentDigitalHuman",
                event: "voiceClonePCMDriveUnavailable",
                states: [
                    "audioOwner": currentEchoAudioOwner.rawValue,
                    "canSynthesize": capability.canSynthesize ? "true" : "false",
                    "outputMode": "tencentAudioDrive",
                    "reason": "runtimeUnsupported",
                    "tencentAudioDriveSupported": capability.tencentAudioDrive.supported ? "true" : "false",
                    "voiceSource": voiceSelection.source.rawValue,
                ],
                correlations: [
                    "voiceProfile": voiceProfileId,
                    "contextOwner": voiceSelection.contextOwnerId,
                ]
            )
            return true
        }

        let lifecycleToken = captureDigitalHumanLifecycleToken(reason: "voiceClonePCMDrive")
        let contextKey = currentDigitalHumanRuntimeContextKey()
        let requestID = makeTencentDigitalHumanRequestID()
        let turnID = ensureCurrentEchoTurnID()
        let runtimeInteractionCallback = beginEchoRuntimeInteraction(
            requestID: requestID,
            turnID: turnID,
            source: "voiceClonePCMDrive"
        )
        guard runtimeInteractionCallback != nil || !requiresEchoRuntimeInteractionLease else {
            degradeTencentDigitalHumanRoute(reason: "runtimeInteractionLeaseUnavailable")
            return true
        }
        let pausedDialogEngine = pauseDialogEngineForTencentProviderSpeechIfNeeded()
        guard prepareAudioSessionForTencentProviderPlayback(
            preserveRecordingCategory: pausedDialogEngine
        ) else {
            if runtimeInteractionCallback != nil {
                echoRuntimeSessionCoordinator.finishInteraction()
            }
            degradeTencentDigitalHumanRoute(reason: "audioSessionCoordinatorActivationFailed")
            return true
        }
        digitalHumanConversation.beginProviderRequest(
            requestID: requestID,
            replyText: normalizedText,
            turnID: turnID,
            keepsPendingReply: routeEchoAudioThroughDigitalHuman
        )
        scheduleTencentDigitalHumanTextOverTimeout(
            requestID: requestID,
            source: "voiceClonePCMDrive",
            runtimeInteractionCallback: runtimeInteractionCallback
        )
        renderVoiceStatus(text: "正在生成复刻声音", isVisible: true, accessibilityIdentifier: "echoVoiceClonePCMDriveStatus")

        PrivacySafeDiagnostics.log(
            subsystem: "TencentDigitalHuman",
            event: "voiceClonePCMDriveRequested",
            states: [
                "audioOwner": currentEchoAudioOwner.rawValue,
                "outputMode": "tencentAudioDrive",
                "source": source,
                "voiceSource": voiceSelection.source.rawValue,
            ],
            correlations: [
                "context": contextKey,
                "contextOwner": voiceSelection.contextOwnerId,
                "request": requestID,
                "turn": turnID,
                "user": userId,
                "voiceProfile": voiceProfileId,
            ]
        )
        DreamJourneyBackendClient.shared.requestVoiceCloneSynthesis(
            userId: userId,
            voiceProfileId: voiceProfileId,
            text: normalizedText,
            audioFormat: "wav",
            sampleRate: 16_000,
            speechRate: -10,
            loudnessRate: 10,
            outputMode: "tencentAudioDrive",
            requestPurpose: "echo",
            roleKey: roleKey,
            roleSubjectId: userId,
            personaScope: "personal",
            digitalHumanId: userId,
            expectedProfileVersion: voiceCloneUseTicket.profileVersion
        ) { [weak self] result in
            DispatchQueue.main.async {
                guard let self else { return }
                let activeOwnerUserId = EchoTraceOwnerScope.normalizedOwnerUserId(UserManager.shared.currentUser?.id)
                guard activeOwnerUserId == EchoTraceOwnerScope.normalizedOwnerUserId(userId),
                      self.isCurrentDigitalHumanLifecycleToken(
                        lifecycleToken,
                        reason: "voiceClonePCMDriveResponse"
                      ),
                      self.isCurrentEchoRuntimeSessionCallback(
                        runtimeInteractionCallback,
                        reason: "voiceClonePCMDriveResponse"
                      ),
                      self.digitalHumanConversation.activeRequestID == requestID,
                      self.currentDigitalHumanRuntimeContextKey() == contextKey else {
                    PrivacySafeDiagnostics.log(
                        subsystem: "TencentDigitalHuman",
                        event: "voiceClonePCMDriveResponseIgnored",
                        states: ["reason": "staleLifecycle"],
                        correlations: [
                            "context": contextKey,
                            "currentContext": self.currentDigitalHumanRuntimeContextKey(),
                            "request": requestID,
                        ]
                    )
                    return
                }

                guard !self.rejectInvalidVoiceCloneSynthesisUseTicketIfNeeded(
                    voiceCloneUseTicket,
                    requestID: requestID,
                    turnID: turnID,
                    outputMode: "tencentAudioDrive",
                    providerLogId: nil,
                    providerRequestId: nil,
                    lifecycleToken: lifecycleToken,
                    runtimeInteractionCallback: runtimeInteractionCallback,
                    source: "voiceClonePCMDriveResponse"
                ) else {
                    return
                }

                switch result {
                case .success(let synthesis):
                    guard synthesis.voiceProfileId == voiceProfileId,
                          synthesis.isBound(
                            toOwnerUserId: userId,
                            voiceProfileId: voiceProfileId,
                            profileVersion: voiceCloneUseTicket.profileVersion,
                            roleSubjectId: userId,
                            roleKey: roleKey,
                            personaScope: "personal",
                            digitalHumanId: userId,
                            requestPurpose: "echo",
                            outputMode: "tencentAudioDrive",
                            audioOwner: "tencentDigitalHuman",
                            textHash: VoiceCloneSynthesisBinding.textHash(for: normalizedText)
                          ),
                          synthesis.isTencentAudioDrivePCMCompatible,
                          let signal = self.makeTencentDigitalHumanPCMDriveSignal(from: synthesis) else {
                        self.handleVoiceClonePCMDriveFailureWithoutDefaultVoice(
                            requestID: requestID,
                            turnID: turnID,
                            voiceProfileId: synthesis.voiceProfileId,
                            outputMode: synthesis.outputMode ?? "none",
                            providerLogId: synthesis.providerLogId,
                            providerRequestId: synthesis.providerRequestId,
                            ownerUserId: userId,
                            reason: synthesis.voiceProfileId == voiceProfileId
                                && synthesis.isBound(
                                    toOwnerUserId: userId,
                                    voiceProfileId: voiceProfileId,
                                    profileVersion: voiceCloneUseTicket.profileVersion,
                                    roleSubjectId: userId,
                                    roleKey: roleKey,
                                    personaScope: "personal",
                                    digitalHumanId: userId,
                                    requestPurpose: "echo",
                                    outputMode: "tencentAudioDrive",
                                    audioOwner: "tencentDigitalHuman",
                                    textHash: VoiceCloneSynthesisBinding.textHash(for: normalizedText)
                                ) ? "incompatibleAudioFormat" : "synthesisBindingMismatch",
                            detail: "Echo only accepts a PCM response bound to the current owner, profile, role, purpose, and output mode.",
                            lifecycleToken: lifecycleToken,
                            runtimeInteractionCallback: runtimeInteractionCallback
                        )
                        PrivacySafeDiagnostics.log(
                            subsystem: "TencentDigitalHuman",
                            event: "voiceClonePCMDriveIncompatible",
                            states: [
                                "audioFormat": synthesis.audioFormat,
                                "audioOwner": self.currentEchoAudioOwner.rawValue,
                                "outputMode": synthesis.outputMode ?? "none",
                            ],
                            counts: [
                                "bitsPerSample": synthesis.bitsPerSample ?? 0,
                                "channelCount": synthesis.channelCount ?? 0,
                                "sampleRate": synthesis.sampleRate ?? 0,
                            ],
                            correlations: [
                                "providerLog": synthesis.providerLogId,
                                "request": requestID,
                                "voiceProfile": synthesis.voiceProfileId,
                            ]
                        )
                        return
                    }

                    self.lastVoiceCloneProviderLogId = synthesis.providerLogId
                    self.lastVoiceCloneProviderRequestId = synthesis.providerRequestId
                    self.lastVoiceCloneProviderMode = synthesis.providerMode
                    self.lastVoiceSynthesisEvidenceSummary = EchoVoiceSynthesisEvidenceSummary(
                        synthesis: synthesis,
                        ownerUserId: userId
                    )
                    self.lastEchoRuntimeFallbackReason = nil
                    self.recordEchoRuntimeDiagnosticsSnapshot(reason: "voiceClonePCMDriveReady")
                    self.renderVoiceStatus(text: "复刻声音正在回响", isVisible: true, accessibilityIdentifier: "echoVoiceClonePCMDriveStatus")
                    self.startPCMDriveSignalToDigitalHumanRuntime(
                        signal: signal,
                        requestID: requestID,
                        turnID: turnID,
                        contextKey: contextKey,
                        source: "voiceClonePCMDrive",
                        lifecycleToken: lifecycleToken,
                        runtimeInteractionCallback: runtimeInteractionCallback,
                        voiceCloneUseTicket: voiceCloneUseTicket
                    )
                    PrivacySafeDiagnostics.log(
                        subsystem: "TencentDigitalHuman",
                        event: "voiceClonePCMDriveReady",
                        states: [
                            "audioOwner": self.currentEchoAudioOwner.rawValue,
                            "outputMode": synthesis.outputMode ?? "none",
                            "providerMode": synthesis.providerMode,
                        ],
                        counts: ["byteCount": synthesis.byteCount],
                        correlations: [
                            "providerLog": synthesis.providerLogId,
                            "providerRequest": synthesis.providerRequestId,
                            "request": requestID,
                            "turn": turnID,
                            "voiceProfile": synthesis.voiceProfileId,
                        ]
                    )
                case .failure(let error):
                    self.handleVoiceClonePCMDriveFailureWithoutDefaultVoice(
                        requestID: requestID,
                        turnID: turnID,
                        voiceProfileId: voiceProfileId,
                        outputMode: "tencentAudioDrive",
                        providerLogId: nil,
                        providerRequestId: nil,
                        ownerUserId: userId,
                        reason: "providerRequestFailed",
                        detail: error.localizedDescription,
                        lifecycleToken: lifecycleToken,
                        runtimeInteractionCallback: runtimeInteractionCallback
                    )
                    PrivacySafeDiagnostics.log(
                        subsystem: "TencentDigitalHuman",
                        event: "voiceClonePCMDriveRequestFailed",
                        states: [
                            "audioOwner": self.currentEchoAudioOwner.rawValue,
                            "failure": "providerRequestFailed",
                            "outputMode": "tencentAudioDrive",
                        ],
                        correlations: [
                            "request": requestID,
                            "voiceProfile": voiceProfileId,
                        ]
                    )
                }
            }
        }
        return true
    }

    private func showVoiceCloneNotEnabledStatusIfNeeded(source: String) {
        let voiceSelection = resolveEchoRoleVoiceProfileSelection()
        guard source != "chatStreamingPrewarm",
              shouldDispatchEchoReplyToTencentProvider,
              voiceSelection.voiceProfileId == nil,
              voiceSelection.shouldShowMissingStatus else {
            return
        }
        renderVoiceStatus(text: voiceSelection.statusText, isVisible: true, accessibilityIdentifier: "echoVoiceCloneNotEnabledStatus")
        lastVoiceCloneProviderLogId = nil
        lastVoiceCloneProviderRequestId = nil
        lastVoiceCloneProviderMode = nil
        lastVoiceSynthesisEvidenceSummary = .unavailable(
            ownerUserId: currentEchoEvidenceOwnerUserId,
            reason: voiceSelection.source.rawValue
        )
        lastEchoRuntimeFallbackReason = voiceSelection.source.rawValue
        recordEchoRuntimeDiagnosticsSnapshot(reason: voiceSelection.source.rawValue)
        PrivacySafeDiagnostics.log(
            subsystem: "TencentDigitalHuman",
            event: "voiceCloneNotEnabled",
            states: [
                "audioOwner": currentEchoAudioOwner.rawValue,
                "outputMode": "tencentText",
                "source": source,
                "voiceSource": voiceSelection.source.rawValue,
            ],
            correlations: ["contextOwner": voiceSelection.contextOwnerId]
        )
    }

    private func echoKnowledgeContextIdentity(
        for context: DigitalHumanContext
    ) -> EchoKnowledgeContextIdentity? {
        KBLiteManager.resolveAuthorizedPersonaIdentity(for: context)
    }

    private func echoV4IdentityRouteDecision(
        for context: DigitalHumanContext,
        accountLease: AccountLease
    ) -> EchoV4IdentityRouteDecision {
        let member = context.isSelfAssistant
            ? nil
            : FamilyRepository.shared.acceptedMembers(for: accountLease.subjectId)
                .first(where: { $0.id == context.ownerId })
        let visitorSession = PublicationVisitorRuntime.shared.snapshot().session
        return EchoV4IdentityRoutingPolicy.evaluate(
            viewerSubjectID: accountLease.subjectId,
            targetOwnerSubjectID: context.isSelfAssistant
                ? accountLease.subjectId
                : member?.memberSubjectId,
            isSelfAssistant: context.isSelfAssistant,
            relationshipAccepted: member != nil,
            visitorSessionOwnerSubjectID: visitorSession.ownerSubjectID,
            visitorSessionActive: visitorSession.isActive
        )
    }

    private func cancelActiveEchoContextBuild(reason: String) {
        activeEchoTurnKnowledgeContextGate?.cancel()
        activeEchoTurnKnowledgeContextGate = nil
        // Shadow evidence belongs to one Echo turn only.  It must not survive a
        // cancellation, account/context switch, or a later turn.
        lastOwnerTruthContextCitationEvidence = nil
        lastEchoAnswerGroundingEvidence = nil
        lastOwnerTruthContextParityEvidence = nil
        lastOwnerTruthContextCompareEvidence = nil
        guard let lease = echoApplicationCoordinator.invalidateContextBuild() else {
            return
        }
        PrivacySafeDiagnostics.log(
            subsystem: "CFLite",
            event: "contextBuildInvalidated",
            states: ["reason": reason],
            counts: ["generation": Int(lease.generation)],
            correlations: ["turn": lease.turnID]
        )
    }

    private func recordEchoContextPacketForUserTurn(
        text: String,
        turnID: String,
        lifecycleToken: DigitalHumanLifecycleToken,
        allowsGeneration: Bool
    ) {
        let context = DigitalHumanContextStore.shared.current
        guard let accountLease = echoAccountLease,
              validateEchoAccountLease(
                  at: .request,
                  expected: accountLease,
                  reason: "contextBuildRequest"
              ) else {
            cancelActiveEchoContextBuild(reason: "contextBuildAccountLeaseUnavailable")
            lastEchoRuntimeFallbackReason = "contextBuildAccountLeaseUnavailable"
            recordEchoRuntimeDiagnosticsSnapshot(reason: "contextBuildAccountLeaseUnavailable")
            return
        }

        let routeDecision = echoV4IdentityRouteDecision(
            for: context,
            accountLease: accountLease
        )
        guard routeDecision.route == .ownerPrivate else {
            cancelActiveEchoContextBuild(reason: routeDecision.reason)
            lastEchoRuntimeFallbackReason = routeDecision.reason
            recordEchoRuntimeDiagnosticsSnapshot(reason: routeDecision.reason)
            PrivacySafeDiagnostics.log(
                subsystem: "CFLite",
                event: "contextBuildSkipped",
                states: [
                    "reason": routeDecision.reason,
                    "route": routeDecision.route.rawValue,
                    "legacyFallback": "denied",
                ],
                correlations: ["turn": turnID]
            )
            return
        }
        guard let expectedIdentity = echoKnowledgeContextIdentity(for: context) else {
            cancelActiveEchoContextBuild(reason: "ownerIdentityUnavailable")
            lastEchoRuntimeFallbackReason = "ownerIdentityUnavailable"
            recordEchoRuntimeDiagnosticsSnapshot(reason: "ownerIdentityUnavailable")
            return
        }

        cancelActiveEchoContextBuild(reason: "newEchoTurn")
        let contextParityLease: EchoOwnerTruthContextParityLease?
        if context.isSelfAssistant,
           validateEchoAccountLease(
               at: .request,
               expected: accountLease,
               reason: "ownerTruthContextParityRequest"
           ) {
            contextParityLease = echoApplicationCoordinator.beginOwnerTruthContextParity(
                turnID: turnID,
                query: text,
                accountLease: accountLease,
                expectedIdentity: expectedIdentity
            )
        } else {
            contextParityLease = nil
        }
        let gate: EchoTurnKnowledgeContextGate?
        if allowsGeneration {
            let strictOwnerTruthAuthorityRequired = echoApplicationCoordinator
                .requiresStrictContextAuthority(for: expectedIdentity)
            let turnGate = EchoTurnKnowledgeContextGate(
                turnID: turnID,
                expectedIdentity: expectedIdentity,
                lifecycleToken: lifecycleToken,
                strictOwnerTruthAuthorityRequired: strictOwnerTruthAuthorityRequired
            )
            gate = turnGate
            activeEchoTurnKnowledgeContextGate = turnGate
            if !strictOwnerTruthAuthorityRequired {
                let timeoutWorkItem = DispatchWorkItem { [weak self, weak turnGate] in
                    guard let self, let turnGate else { return }
                    self.submitLocalEchoTurnKnowledgeContext(
                        text: text,
                        gate: turnGate,
                        source: "localKBLiteTimeout"
                    )
                }
                turnGate.timeoutWorkItem = timeoutWorkItem
                DispatchQueue.main.asyncAfter(
                    deadline: .now() + Self.echoTurnKnowledgeTimeout,
                    execute: timeoutWorkItem
                )
            }
        } else {
            gate = nil
        }

        let contextBuildLease = echoApplicationCoordinator.requestContextBuild(
            turnID: turnID,
            query: text,
            expectedIdentity: expectedIdentity,
            accountLease: accountLease,
            lifecycleMode: context.mode,
            viewerFamilyMemberID: nil
        ) { [weak self] contextBuildLease, delivery in
            switch delivery {
            case .success(let packet):
                let record = EchoTraceRecord(turnID: turnID, packet: packet)
                guard let self,
                      self.isCurrentDigitalHumanLifecycleToken(
                        lifecycleToken,
                        reason: "contextPacketResponse"
                      ) else { return }
                if let contextParityLease,
                   let parityEvidence = self.echoApplicationCoordinator.recordOwnerTruthContextParityLegacy(
                    packet,
                    contextBuildLease: contextBuildLease,
                    parityLease: contextParityLease
                   ) {
                    _ = self.recordOwnerTruthContextParityQAEvidence(parityEvidence)
                }
                EchoTraceStore.shared.record(record, ownerUserId: expectedIdentity.userId)
                self.lastEchoTraceRecord = record
                self.recordEchoRuntimeDiagnosticsSnapshot(reason: "contextPacketBuilt")
                if let gate {
                    if packet.generationContextContentHash != nil {
                        self.submitEchoTurnKnowledgeContext(
                            packet.generationContextText,
                            traceID: packet.traceId,
                            source: "backendContextPacket",
                            gate: gate
                        )
                    } else {
                        self.submitLocalEchoTurnKnowledgeContext(
                            text: text,
                            gate: gate,
                            source: "localKBLiteBackendContractMissing"
                        )
                    }
                }
                PrivacySafeDiagnostics.log(
                    subsystem: "CFLite",
                    event: "contextBuilt",
                    states: [
                        "cloneReady": String(packet.cloneReady),
                        "digitalHumanReady": String(packet.digitalHumanSessionReady),
                        "digitalHumanProviderMode": packet.digitalHumanProviderMode,
                        "generationTruncated": String(packet.generationContextTruncated),
                        "outputMode": packet.voiceOutputMode,
                        "privacyScope": packet.privacyScopeLabel,
                    ],
                    counts: [
                        "archiveItemsAvailable": packet.archiveItemsAvailable,
                        "archiveItemsIncluded": packet.archiveItemsIncluded,
                        "fallbackCount": packet.fallbacks.count,
                        "generationRefCount": packet.generationContextSourceRefs.count,
                        "kbFactCount": packet.kbFactCount,
                        "latencyMs": packet.latencyMs,
                        "schemaVersion": packet.schemaVersion,
                    ],
                    correlations: [
                        "digitalHuman": packet.digitalHumanId,
                        "generation": packet.generationContextContentHash,
                        "persona": packet.personaScope,
                        "trace": packet.traceId,
                        "turn": turnID,
                        "voiceProfile": packet.voiceProfileId,
                    ]
                )
                print(record.logLine)
            case .authorityInvalidated(let invalidation):
                guard let self else { return }
                self.cancelActiveEchoContextBuild(reason: "contextPacketAuthorityInvalidated")
                self.lastEchoRuntimeFallbackReason = "contextPacketAuthorityInvalidated"
                self.recordEchoRuntimeDiagnosticsSnapshot(reason: "contextPacketAuthorityInvalidated")
                PrivacySafeDiagnostics.log(
                    subsystem: "CFLite",
                    event: "contextPacketIgnored",
                    states: [
                        "reason": "authorityInvalidated",
                        "checkpoint": invalidation.checkpoint.rawValue,
                        "validation": invalidation.reason.rawValue,
                    ],
                    correlations: ["turn": turnID]
                )
            case .identityMismatch(let mismatch):
                guard let self,
                      self.isCurrentDigitalHumanLifecycleToken(
                        lifecycleToken,
                        reason: "contextPacketIdentityMismatch"
                      ) else { return }
                if let contextParityLease {
                    _ = self.echoApplicationCoordinator.invalidateOwnerTruthContextParity(
                        matching: contextParityLease
                    )
                }
                if let gate {
                    self.submitLocalEchoTurnKnowledgeContext(
                        text: text,
                        gate: gate,
                        source: "localKBLitePacketIdentityMismatch"
                    )
                }
                PrivacySafeDiagnostics.log(
                    subsystem: "CFLite",
                    event: "contextPacketIgnored",
                    states: ["reason": "identityMismatch"],
                    correlations: [
                        "turn": turnID,
                        "expectedUser": mismatch.expectedIdentity.userId,
                        "expectedPersona": mismatch.expectedIdentity.personaScope,
                        "expectedDigitalHuman": mismatch.expectedIdentity.digitalHumanId,
                        "actualUser": mismatch.responseUserId,
                        "actualPersona": mismatch.responsePersonaScope,
                        "actualDigitalHuman": mismatch.responseDigitalHumanId,
                    ]
                )
            case .failure:
                guard let self,
                      self.isCurrentDigitalHumanLifecycleToken(
                        lifecycleToken,
                        reason: "contextPacketFailure"
                      ) else { return }
                if let contextParityLease {
                    _ = self.echoApplicationCoordinator.invalidateOwnerTruthContextParity(
                        matching: contextParityLease
                    )
                }
                if let gate {
                    self.submitLocalEchoTurnKnowledgeContext(
                        text: text,
                        gate: gate,
                        source: "localKBLiteBackendFailure"
                    )
                }
                PrivacySafeDiagnostics.log(
                    subsystem: "CFLite",
                    event: "contextBuildFailed",
                    states: ["reason": "backendFailure"],
                    correlations: ["turn": turnID]
                )
            }
        }
        observeOwnerTruthContextShadowForEchoTurn(
            text: text,
            turnID: turnID,
            lifecycleToken: lifecycleToken,
            expectedIdentity: expectedIdentity,
            context: context,
            contextParityLease: contextParityLease
        )
        guard contextBuildLease != nil else {
            if let contextParityLease {
                _ = echoApplicationCoordinator.invalidateOwnerTruthContextParity(
                    matching: contextParityLease
                )
            }
            if let gate {
                submitLocalEchoTurnKnowledgeContext(
                    text: text,
                    gate: gate,
                    source: "localKBLiteBackendNotConfigured"
                )
            }
            PrivacySafeDiagnostics.log(
                subsystem: "CFLite",
                event: "contextBuildSkipped",
                states: ["reason": "backendNotConfigured"],
                correlations: ["turn": turnID]
            )
            return
        }
    }

    /// Observes the typed Owner Truth Context path for a live Echo turn without
    /// contributing any text to the public reply path.  This is deliberately
    /// QA-only while Projection-to-Context remains in shadow mode.
    private func observeOwnerTruthContextShadowForEchoTurn(
        text: String,
        turnID: String,
        lifecycleToken: DigitalHumanLifecycleToken,
        expectedIdentity: EchoKnowledgeContextIdentity,
        context: DigitalHumanContext,
        contextParityLease: EchoOwnerTruthContextParityLease?
    ) {
        guard OwnerTruthContextCitationQAGate.isEnabled else {
            lastOwnerTruthContextCitationEvidence = nil
            lastOwnerTruthContextParityEvidence = nil
            lastOwnerTruthContextCompareEvidence = nil
            return
        }
        guard context.isSelfAssistant,
              let accountLease = echoAccountLease,
              expectedIdentity.userId == accountLease.subjectId,
              validateEchoAccountLease(
                  at: .request,
                  expected: accountLease,
                  reason: "ownerTruthContextShadowRequest"
              ) else {
            PrivacySafeDiagnostics.log(
                subsystem: "CFLite",
                event: "ownerTruthContextShadowSkipped",
                states: ["reason": "ineligibleOwnerScope"],
                correlations: ["turn": turnID]
            )
            if let contextParityLease {
                _ = echoApplicationCoordinator.invalidateOwnerTruthContextParity(
                    matching: contextParityLease
                )
            }
            return
        }

        observeOwnerTruthContextShadowCompareForEchoTurn(
            text: text,
            turnID: turnID,
            lifecycleToken: lifecycleToken,
            expectedIdentity: expectedIdentity,
            accountLease: accountLease
        )

        let shadowLease = echoApplicationCoordinator.requestOwnerTruthContextShadow(
            turnID: turnID,
            query: text,
            accountLease: accountLease,
            expectedIdentity: expectedIdentity
        ) { [weak self] shadowLease, delivery in
            guard let self,
                  self.isCurrentDigitalHumanLifecycleToken(
                      lifecycleToken,
                      reason: "ownerTruthContextShadowResponse"
                  ),
                  self.validateEchoAccountLease(
                      at: .runtime,
                      expected: accountLease,
                      reason: "ownerTruthContextShadowResponse"
                  ) else {
                return
            }

            switch delivery {
            case .success(let summary):
                guard self.recordOwnerTruthContextCitationQAEvidence(summary) else {
                    return
                }
                if let contextParityLease,
                   shadowLease.turnID == contextParityLease.turnID,
                   shadowLease.expectedIdentity == contextParityLease.expectedIdentity,
                   let parityEvidence = self.echoApplicationCoordinator.recordOwnerTruthContextParityShadow(
                    summary,
                    parityLease: contextParityLease
                   ) {
                    _ = self.recordOwnerTruthContextParityQAEvidence(parityEvidence)
                }
                self.recordEchoRuntimeDiagnosticsSnapshot(reason: "ownerTruthContextShadowObserved")
                PrivacySafeDiagnostics.log(
                    subsystem: "CFLite",
                    event: "ownerTruthContextShadowObserved",
                    states: [
                        "authority": summary.authorityState.rawValue,
                        "selectionMode": summary.selectionMode.rawValue,
                    ],
                    counts: [
                        "selected": summary.selectedContextCount,
                        "filtered": summary.filteredContextCount,
                        "ranking": summary.rankingTraceCount,
                        "citation": summary.citationCount,
                    ],
                    correlations: [
                        "context": summary.contextHash,
                        "turn": turnID,
                    ]
                )
            case .failure:
                self.lastOwnerTruthContextCitationEvidence = nil
                if let contextParityLease {
                    _ = self.echoApplicationCoordinator.invalidateOwnerTruthContextParity(
                        matching: contextParityLease
                    )
                }
                PrivacySafeDiagnostics.log(
                    subsystem: "CFLite",
                    event: "ownerTruthContextShadowUnavailable",
                    states: ["reason": "shadowRequestFailed"],
                    correlations: ["turn": turnID]
                )
            }
        }
        guard shadowLease != nil else {
            if let contextParityLease {
                _ = echoApplicationCoordinator.invalidateOwnerTruthContextParity(
                    matching: contextParityLease
                )
            }
            PrivacySafeDiagnostics.log(
                subsystem: "CFLite",
                event: "ownerTruthContextShadowSkipped",
                states: ["reason": "notConfiguredOrIneligible"],
                correlations: ["turn": turnID]
            )
            return
        }
    }

    /// Captures the server-side same-request V1/V4 comparison as QA evidence.
    /// It has no completion dependency with the public Context Packet, typed
    /// shadow observation, or DialogEngine, so compare failures stay diagnostic.
    private func observeOwnerTruthContextShadowCompareForEchoTurn(
        text: String,
        turnID: String,
        lifecycleToken: DigitalHumanLifecycleToken,
        expectedIdentity: EchoKnowledgeContextIdentity,
        accountLease: AccountLease
    ) {
        guard OwnerTruthContextCitationQAGate.isEnabled,
              OwnerTruthMigrationParityQAGate.isEnabled else {
            lastOwnerTruthContextCompareEvidence = nil
            return
        }
        let compareLease = echoApplicationCoordinator.requestOwnerTruthContextShadowCompare(
            turnID: turnID,
            query: text,
            accountLease: accountLease,
            expectedIdentity: expectedIdentity
        ) { [weak self] _, delivery in
            guard let self,
                  self.isCurrentDigitalHumanLifecycleToken(
                      lifecycleToken,
                      reason: "ownerTruthContextShadowCompareResponse"
                  ),
                  self.validateEchoAccountLease(
                      at: .runtime,
                      expected: accountLease,
                      reason: "ownerTruthContextShadowCompareResponse"
                  ) else {
                return
            }
            switch delivery {
            case .success(let comparison):
                let evidence = EchoOwnerTruthContextShadowCompareQAEvidenceReadout(
                    comparison: comparison
                )
                guard self.recordOwnerTruthContextCompareQAEvidence(evidence) else {
                    return
                }
                self.recordEchoRuntimeDiagnosticsSnapshot(reason: "ownerTruthContextShadowCompareObserved")
                PrivacySafeDiagnostics.log(
                    subsystem: "CFLite",
                    event: "ownerTruthContextShadowCompareObserved",
                    states: [
                        "disposition": comparison.disposition.rawValue,
                        "v4State": comparison.v4.state.rawValue,
                    ],
                    counts: [
                        "legacySelected": comparison.legacy.selectedContextCount,
                        "v4Selected": comparison.v4.selectedContextCount,
                        "v4Fallback": comparison.v4.fallbackCount,
                    ],
                    correlations: ["turn": turnID]
                )
            case .failure:
                self.lastOwnerTruthContextCompareEvidence = nil
                PrivacySafeDiagnostics.log(
                    subsystem: "CFLite",
                    event: "ownerTruthContextShadowCompareUnavailable",
                    states: ["reason": "compareRequestFailed"],
                    correlations: ["turn": turnID]
                )
            }
        }
        guard compareLease != nil else {
            lastOwnerTruthContextCompareEvidence = nil
            PrivacySafeDiagnostics.log(
                subsystem: "CFLite",
                event: "ownerTruthContextShadowCompareSkipped",
                states: ["reason": "notConfiguredOrIneligible"],
                correlations: ["turn": turnID]
            )
            return
        }
    }

    private func submitLocalEchoTurnKnowledgeContext(
        text: String,
        gate: EchoTurnKnowledgeContextGate,
        source: String
    ) {
        guard activeEchoTurnKnowledgeContextGate === gate,
              !gate.didSubmit,
              !gate.didFinishWithoutContext else {
            return
        }
        guard EchoKnowledgeContextPolicy.allowsLocalKBLiteFallback(
            for: gate.expectedIdentity,
            strictOwnerTruthAuthorityRequired: gate.strictOwnerTruthAuthorityRequired
        ) else {
            gate.finishWithoutContext()
            if activeEchoTurnKnowledgeContextGate === gate {
                activeEchoTurnKnowledgeContextGate = nil
            }
            PrivacySafeDiagnostics.log(
                subsystem: "CFLite",
                event: "localFallbackForbidden",
                states: ["source": source],
                correlations: [
                    "digitalHuman": gate.expectedDigitalHumanID,
                    "persona": gate.expectedPersonaScope,
                    "turn": gate.turnID,
                ]
            )
            return
        }
        let localContext = KBLiteManager.shared.buildGenerationAllowedContextString(
            query: text,
            expectedIdentity: gate.expectedIdentity
        )
        guard !localContext.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            gate.finishWithoutContext()
            if activeEchoTurnKnowledgeContextGate === gate {
                activeEchoTurnKnowledgeContextGate = nil
            }
            PrivacySafeDiagnostics.log(
                subsystem: "CFLite",
                event: "localContextUnavailable",
                states: ["source": source],
                correlations: ["turn": gate.turnID]
            )
            return
        }
        submitEchoTurnKnowledgeContext(
            localContext,
            traceID: nil,
            source: source,
            gate: gate
        )
    }

    private func submitEchoTurnKnowledgeContext(
        _ content: String,
        traceID: String?,
        source: String,
        gate: EchoTurnKnowledgeContextGate
    ) {
        dispatchPrecondition(condition: .onQueue(.main))
        let normalizedContent = content.trimmingCharacters(in: .whitespacesAndNewlines)
        if normalizedContent.isEmpty,
           activeEchoTurnKnowledgeContextGate === gate,
           !gate.didSubmit,
           !gate.didFinishWithoutContext {
            gate.finishWithoutContext()
            activeEchoTurnKnowledgeContextGate = nil
            PrivacySafeDiagnostics.log(
                subsystem: "CFLite",
                event: "contextUnavailable",
                states: ["source": source],
                correlations: ["turn": gate.turnID]
            )
            return
        }
        guard activeEchoTurnKnowledgeContextGate === gate,
              !gate.didSubmit,
              !gate.didFinishWithoutContext,
              !normalizedContent.isEmpty,
              !viewModel.isWaitingForDelayedReply,
              isCurrentDigitalHumanLifecycleToken(
                gate.lifecycleToken,
                reason: "submitTurnKnowledgeContext"
              ) else {
            return
        }
        guard let currentIdentity = echoKnowledgeContextIdentity(
            for: DigitalHumanContextStore.shared.current
        ) else {
            PrivacySafeDiagnostics.log(
                subsystem: "CFLite",
                event: "contextIgnored",
                states: ["reason": "familyRelationshipUnauthorized"],
                correlations: ["turn": gate.turnID]
            )
            return
        }
        guard currentIdentity == gate.expectedIdentity else {
            PrivacySafeDiagnostics.log(
                subsystem: "CFLite",
                event: "contextIgnored",
                states: ["reason": "staleIdentity"],
                correlations: [
                    "currentDigitalHuman": currentIdentity.digitalHumanId,
                    "currentPersona": currentIdentity.personaScope,
                    "currentUser": currentIdentity.userId,
                    "expectedDigitalHuman": gate.expectedDigitalHumanID,
                    "expectedPersona": gate.expectedPersonaScope,
                    "expectedUser": gate.expectedUserID,
                    "turn": gate.turnID,
                ]
            )
            return
        }
        guard let accountLease = echoAccountLease,
              validateEchoAccountLease(
                at: .runtime,
                expected: accountLease,
                reason: "submitTurnKnowledgeContext"
              ),
              ownsCurrentDialogEngineBinding() else {
            return
        }

        let submitted = DialogEngineManager.shared.submitTurnKnowledgeContext(
            normalizedContent,
            traceID: traceID,
            source: source
        )
        if submitted {
            gate.didSubmit = true
            gate.cancel()
        } else {
            scheduleEchoTurnKnowledgeContextRetry(
                normalizedContent,
                traceID: traceID,
                source: source,
                gate: gate
            )
        }
        PrivacySafeDiagnostics.log(
            subsystem: "CFLite",
            event: "contextSubmission",
            states: [
                "source": source,
                "submitted": String(submitted),
            ],
            counts: ["byteCount": normalizedContent.utf8.count],
            correlations: [
                "trace": traceID,
                "turn": gate.turnID,
            ]
        )
    }

    private func scheduleEchoTurnKnowledgeContextRetry(
        _ content: String,
        traceID: String?,
        source: String,
        gate: EchoTurnKnowledgeContextGate
    ) {
        guard gate.failedSubmissionCount < 2 else {
            PrivacySafeDiagnostics.log(
                subsystem: "CFLite",
                event: "contextRetryExhausted",
                states: ["source": source],
                correlations: ["turn": gate.turnID]
            )
            return
        }
        gate.failedSubmissionCount += 1
        gate.retryWorkItem?.cancel()
        let retryWorkItem = DispatchWorkItem { [weak self, weak gate] in
            guard let self, let gate else { return }
            self.submitEchoTurnKnowledgeContext(
                content,
                traceID: traceID,
                source: "\(source)Retry\(gate.failedSubmissionCount)",
                gate: gate
            )
        }
        gate.retryWorkItem = retryWorkItem
        DispatchQueue.main.asyncAfter(
            deadline: .now() + (0.12 * Double(gate.failedSubmissionCount)),
            execute: retryWorkItem
        )
    }

    /// A synthesis response may arrive after the user has paused, deleted, or
    /// otherwise lost access to the selected profile. Do not let that late
    /// response, or any of its queued PCM chunks, enter the Tencent runtime.
    @discardableResult
    private func rejectInvalidVoiceCloneSynthesisUseTicketIfNeeded(
        _ ticket: VoiceCloneSynthesisUseTicket?,
        requestID: String,
        turnID: String,
        outputMode: String,
        providerLogId: String?,
        providerRequestId: String?,
        lifecycleToken: DigitalHumanLifecycleToken,
        runtimeInteractionCallback: EchoRuntimeCallbackToken?,
        source: String
    ) -> Bool {
        guard let ticket,
              !VoiceCloneService.shared.validatesPersonalSynthesisUseTicket(ticket) else {
            return false
        }
        handleVoiceClonePCMDriveFailureWithoutDefaultVoice(
            requestID: requestID,
            turnID: turnID,
            voiceProfileId: ticket.voiceProfileId,
            outputMode: outputMode,
            providerLogId: providerLogId,
            providerRequestId: providerRequestId,
            ownerUserId: ticket.ownerUserId,
            reason: "voiceCloneUseTicketRevoked",
            detail: "The accepted voice-profile revision changed before the queued synthesis audio could be delivered.",
            lifecycleToken: lifecycleToken,
            runtimeInteractionCallback: runtimeInteractionCallback
        )
        PrivacySafeDiagnostics.log(
            subsystem: "TencentDigitalHuman",
            event: "voiceClonePCMDriveUseTicketRejected",
            states: [
                "audioOwner": currentEchoAudioOwner.rawValue,
                "outputMode": outputMode,
                "source": source,
            ],
            correlations: [
                "request": requestID,
                "turn": turnID,
                "voiceProfile": ticket.voiceProfileId,
            ]
        )
        return true
    }

    private func handleVoiceClonePCMDriveFailureWithoutDefaultVoice(
        requestID: String,
        turnID: String,
        voiceProfileId: String,
        outputMode: String,
        providerLogId: String?,
        providerRequestId: String?,
        ownerUserId: String,
        reason: String,
        detail: String,
        lifecycleToken: DigitalHumanLifecycleToken,
        runtimeInteractionCallback: EchoRuntimeCallbackToken?
    ) {
        cancelTencentDigitalHumanTextOverTimeout()
        digitalHumanConversation.clearProviderRequest()
        if runtimeInteractionCallback != nil {
            echoRuntimeSessionCoordinator.finishInteraction()
        }
        let runtimeSessionCallback = echoRuntimeSessionCoordinator.currentSessionCallbackToken()
        stopDigitalHumanAudioLevelMetering()
        releaseEchoAudioOwnerLease(
            expectedOwner: .tencentDigitalHumanPlayback,
            reason: "voiceClonePCMDriveFailed:\(reason)"
        )
        setEchoAudioOwner(.fallbackMuted, reason: "voiceClonePCMDriveFailed:\(reason)")
        markEchoReplyDelivered()
        lastVoiceCloneProviderLogId = providerLogId
        lastVoiceCloneProviderRequestId = providerRequestId
        lastVoiceCloneProviderMode = outputMode
        lastVoiceSynthesisEvidenceSummary = .failed(
            ownerUserId: ownerUserId,
            voiceProfileId: voiceProfileId,
            outputMode: outputMode,
            providerLogId: providerLogId,
            providerRequestId: providerRequestId,
            reason: reason,
            detail: detail
        )
        lastEchoRuntimeFallbackReason = reason
        recordEchoRuntimeDiagnosticsSnapshot(reason: "voiceClonePCMDriveFailed")
        renderVoiceStatus(text: "复刻声音生成失败，请稍后重试", isVisible: true, accessibilityIdentifier: "echoVoiceClonePCMDriveStatus")
        digitalHumanStatusDetailLabel.text = "复刻声音生成失败，未切换默认音色"
        PrivacySafeDiagnostics.log(
            subsystem: "TencentDigitalHuman",
            event: "voiceClonePCMDriveFailed",
            states: [
                "audioOwner": currentEchoAudioOwner.rawValue,
                "outputMode": outputMode,
                "reason": reason,
            ],
            correlations: [
                "providerLog": providerLogId,
                "providerRequest": providerRequestId,
                "request": requestID,
                "turn": turnID,
                "voiceProfile": voiceProfileId,
            ]
        )
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) { [weak self] in
            guard let self,
                  self.isCurrentDigitalHumanLifecycleToken(
                    lifecycleToken,
                    reason: "voiceClonePCMDriveFailureResume"
                  ),
                  self.isCurrentEchoRuntimeSessionCallback(
                    runtimeSessionCallback,
                    reason: "voiceClonePCMDriveFailureResume"
                  ) else { return }
            if self.resumeDialogEngineAfterTencentProviderSpeechIfNeeded(
                reason: "voiceClonePCMDriveFailed",
                lifecycleToken: lifecycleToken
            ) {
                return
            }
            if DialogEngineManager.shared.isDialogActive {
                self.viewModel.beginVoiceInteraction()
            } else {
                self.resetEchoViewModelToIdle()
            }
        }
    }

    private func sendEchoReplyToTencentTextRuntime(_ normalizedText: String, source: String) {
        guard let digitalHumanRuntime,
              digitalHumanRuntime.profile != nil else {
            return
        }

        let requestID = makeTencentDigitalHumanRequestID()
        let turnID = ensureCurrentEchoTurnID()
        let runtimeInteractionCallback = beginEchoRuntimeInteraction(
            requestID: requestID,
            turnID: turnID,
            source: source
        )
        guard runtimeInteractionCallback != nil || !requiresEchoRuntimeInteractionLease else {
            degradeTencentDigitalHumanRoute(reason: "runtimeInteractionLeaseUnavailable")
            return
        }

        do {
            let pausedDialogEngine = pauseDialogEngineForTencentProviderSpeechIfNeeded()
            guard prepareAudioSessionForTencentProviderPlayback(
                preserveRecordingCategory: pausedDialogEngine
            ) else {
                if runtimeInteractionCallback != nil {
                    echoRuntimeSessionCoordinator.finishInteraction()
                }
                degradeTencentDigitalHumanRoute(reason: "audioSessionCoordinatorActivationFailed")
                return
            }
            try digitalHumanRuntime.sendTextChunk(normalizedText, requestID: requestID, sequence: 1, isFinal: true)
            digitalHumanConversation.beginProviderRequest(
                requestID: requestID,
                replyText: normalizedText,
                turnID: turnID,
                keepsPendingReply: routeEchoAudioThroughDigitalHuman
            )
            scheduleTencentDigitalHumanTextOverTimeout(
                requestID: requestID,
                source: source,
                runtimeInteractionCallback: runtimeInteractionCallback
            )
            PrivacySafeDiagnostics.log(
                subsystem: "TencentDigitalHuman",
                event: "textReplySent",
                states: ["source": source],
                counts: ["textLength": normalizedText.count],
                correlations: [
                    "request": requestID,
                    "turn": turnID,
                ]
            )
        } catch {
            if runtimeInteractionCallback != nil {
                echoRuntimeSessionCoordinator.finishInteraction()
            }
            resumeDialogEngineAfterTencentProviderSpeechIfNeeded(reason: "sendTextFailed")
            PrivacySafeDiagnostics.log(
                subsystem: "TencentDigitalHuman",
                event: "textReplyFailed",
                states: [
                    "reason": "sendTextFailed",
                    "source": source,
                ]
            )
        }
    }

    private func ensureCurrentEchoTurnID() -> String {
        digitalHumanConversation.ensureTurnID(makeID: makeTencentDigitalHumanRequestID)
    }

    private var requiresEchoRuntimeInteractionLease: Bool {
        digitalHumanRuntime is TencentDigitalHumanCloudRuntime
    }

    private func beginEchoRuntimeInteraction(
        requestID: String,
        turnID: String,
        source: String
    ) -> EchoRuntimeCallbackToken? {
        let callback = echoRuntimeSessionCoordinator.beginInteraction(
            conversationID: turnID,
            requestID: requestID
        )
        guard callback == nil,
              requiresEchoRuntimeInteractionLease else {
            return callback
        }
        PrivacySafeDiagnostics.log(
            subsystem: "TencentDigitalHuman",
            event: "runtimeInteractionLeaseUnavailable",
            states: ["source": source],
            correlations: [
                "request": requestID,
                "turn": turnID,
            ]
        )
        return nil
    }

    private func makeTencentDigitalHumanRequestID() -> String {
        UUID().uuidString.replacingOccurrences(of: "-", with: "")
    }

    private func scheduleTencentDigitalHumanTextOverTimeout(
        requestID: String,
        source: String,
        runtimeInteractionCallback: EchoRuntimeCallbackToken?
    ) {
        cancelTencentDigitalHumanTextOverTimeout()
        let turnID = ensureCurrentEchoTurnID()
        let lifecycleToken = captureDigitalHumanLifecycleToken(reason: "textOverTimeout:\(source)")
        let workItem = DispatchWorkItem { [weak self] in
            self?.handleTencentDigitalHumanTextOverTimeout(
                requestID: requestID,
                lifecycleToken: lifecycleToken,
                runtimeInteractionCallback: runtimeInteractionCallback
            )
        }
        digitalHumanProviderTextOverTimeoutWorkItem = workItem
        DispatchQueue.main.asyncAfter(
            deadline: .now() + Self.tencentDigitalHumanTextOverTimeout,
            execute: workItem
        )
        PrivacySafeDiagnostics.log(
            subsystem: "TencentDigitalHuman",
            event: "textOverTimeoutScheduled",
            states: ["source": source],
            counts: ["timeoutMs": Int(Self.tencentDigitalHumanTextOverTimeout * 1_000)],
            correlations: [
                "request": requestID,
                "turn": turnID,
            ]
        )
    }

    private func cancelTencentDigitalHumanTextOverTimeout() {
        digitalHumanProviderTextOverTimeoutWorkItem?.cancel()
        digitalHumanProviderTextOverTimeoutWorkItem = nil
    }

    private func handleTencentDigitalHumanTextOverTimeout(
        requestID: String,
        lifecycleToken: DigitalHumanLifecycleToken,
        runtimeInteractionCallback: EchoRuntimeCallbackToken?
    ) {
        guard isCurrentDigitalHumanLifecycleToken(
                lifecycleToken,
                reason: "textOverTimeout"
              ),
              isCurrentEchoRuntimeSessionCallback(
                runtimeInteractionCallback,
                reason: "textOverTimeout"
              ),
              digitalHumanConversation.activeRequestID == requestID else {
            PrivacySafeDiagnostics.log(
                subsystem: "TencentDigitalHuman",
                event: "textOverTimeoutIgnored",
                states: ["reason": "stale"],
                correlations: [
                    "activeRequest": digitalHumanConversation.activeRequestID,
                    "request": requestID,
                    "turn": digitalHumanConversation.currentTurnID,
                ]
            )
            return
        }

        cancelTencentDigitalHumanTextOverTimeout()
        let turnID = digitalHumanConversation.currentTurnID ?? "unknown"
        digitalHumanConversation.clearProviderRequest()
        if runtimeInteractionCallback != nil {
            echoRuntimeSessionCoordinator.finishInteraction()
        }
        let runtimeSessionCallback = echoRuntimeSessionCoordinator.currentSessionCallbackToken()
        stopDigitalHumanAudioLevelMetering()
        digitalHumanRuntime?.interrupt()
        releaseEchoAudioOwnerLease(
            expectedOwner: .tencentDigitalHumanPlayback,
            reason: "providerTextOverTimeout"
        )
        markEchoReplyDelivered()
        PrivacySafeDiagnostics.log(
            subsystem: "TencentDigitalHuman",
            event: "textOverTimeoutRecovered",
            correlations: [
                "request": requestID,
                "turn": turnID,
            ]
        )

        DispatchQueue.main.asyncAfter(deadline: .now() + Self.tencentDigitalHumanPostTextOverResumeDelay) { [weak self] in
            guard let self,
                  self.isCurrentDigitalHumanLifecycleToken(
                    lifecycleToken,
                    reason: "textOverTimeoutResume"
                  ),
                  self.isCurrentEchoRuntimeSessionCallback(
                    runtimeSessionCallback,
                    reason: "textOverTimeoutResume"
                  ) else { return }
            if self.resumeDialogEngineAfterTencentProviderSpeechIfNeeded(
                reason: "providerTextOverTimeout",
                lifecycleToken: lifecycleToken
            ) {
                return
            }
            if DialogEngineManager.shared.isDialogActive {
                self.viewModel.beginVoiceInteraction()
            } else {
                self.resetEchoViewModelToIdle()
            }
        }
    }

    @discardableResult
    private func interruptDigitalHumanPlayback(reason: String) -> Bool {
        let lifecycleToken = captureDigitalHumanLifecycleToken(reason: "interruptPlayback:\(reason)")
        cancelDigitalHumanReplyPrewarm()
        cancelTencentDigitalHumanTextOverTimeout()
        echoRuntimeSessionCoordinator.finishInteraction()
        digitalHumanConversation.clearProviderRequestAndResumeState()
        if let cloudRuntime = digitalHumanRuntime as? TencentDigitalHumanCloudRuntime {
            cloudRuntime.interruptPlaybackIfNeeded(reason: reason)
        } else {
            digitalHumanRuntime?.interrupt()
        }
        stopDigitalHumanAudioLevelMetering()
        releaseEchoAudioOwnerLease(
            expectedOwner: .tencentDigitalHumanPlayback,
            reason: "providerPlaybackInterrupted:\(reason)"
        )
        PrivacySafeDiagnostics.log(
            subsystem: "TencentDigitalHuman",
            event: "providerPlaybackInterrupted",
            states: ["reason": reason],
            correlations: ["turn": digitalHumanConversation.currentTurnID]
        )

        guard reason == "pcmDriveSmokeStopProbe",
              shouldRunTencentDigitalHumanBackendPCMDriveSmoke || shouldRunTencentDigitalHumanPCMDriveSmoke,
              shouldShowDigitalHumanLivePanel,
              view.window != nil else {
            return false
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.45) { [weak self] in
            guard let self,
                  self.isCurrentDigitalHumanLifecycleToken(
                    lifecycleToken,
                    reason: "pcmDriveStopProbeResume"
                  ) else { return }
            self.activeVoiceInteractionLifecycleToken = lifecycleToken
            self.resumeVoiceCaptureAfterTencentProviderSpeech(
                reason: reason,
                lifecycleToken: lifecycleToken
            )
        }
        return true
    }

    @discardableResult
    private func interruptDigitalHumanPlaybackForUserBargeIn() -> Bool {
        guard shouldShowDigitalHumanLivePanel,
              view.window != nil else {
            return false
        }

        let lifecycleToken = invalidateDigitalHumanInteraction(reason: "userBargeIn")
        activeVoiceInteractionLifecycleToken = lifecycleToken
        interruptDigitalHumanPlayback(reason: "userBargeIn")
        renderVoiceStatus(text: "正在恢复聆听", isVisible: true)

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.45) { [weak self] in
            guard let self,
                  self.view.window != nil,
                  self.isCurrentDigitalHumanLifecycleToken(
                    lifecycleToken,
                    reason: "userBargeInResume"
                  ) else {
                return
            }
            self.resumeVoiceCaptureAfterTencentProviderSpeech(
                reason: "userBargeIn",
                lifecycleToken: lifecycleToken
            )
        }
        return true
    }

    private var hasTencentDigitalHumanProviderSpeechInFlight: Bool {
        digitalHumanConversation.hasProviderSpeechInFlight
    }

    private var shouldInterruptTencentDigitalHumanOnUserStop: Bool {
        digitalHumanConversation.shouldInterruptOnUserStop(routeEchoAudioThroughDigitalHuman: routeEchoAudioThroughDigitalHuman)
    }

    private func preserveTencentProviderSessionAfterLocalDialogStop(reason: String) {
        cancelDigitalHumanReplyPrewarm()
        digitalHumanConversation.clearResumeState()
        stopDigitalHumanAudioLevelMetering()
        PrivacySafeDiagnostics.log(
            subsystem: "TencentDigitalHuman",
            event: "providerSessionPreserved",
            states: [
                "providerSpeechInFlight": String(hasTencentDigitalHumanProviderSpeechInFlight),
                "reason": reason,
            ],
            correlations: ["turn": digitalHumanConversation.currentTurnID]
        )
    }

    @discardableResult
    private func startUIQAMeteredPlayback() -> Bool {
        guard shouldShowDigitalHumanLivePanel else { return false }
        do {
            try digitalHumanAudioLevelMeter?.startUIQAMeteredPlayback()
            return true
        } catch {
            PrivacySafeDiagnostics.log(
                subsystem: "Echo",
                event: "uiqaMeteredPlaybackFailed",
                states: ["reason": "audioSessionFailure"]
            )
            return false
        }
    }

    @discardableResult
    private func startUIQAMockVisemeTimeline() -> Bool {
        guard shouldShowDigitalHumanLivePanel else { return false }
        guard let synthesis = makeUIQAMockSynthesisResultWithVisemeTimeline(),
              let event = synthesis.lipSyncPlaybackEvent else {
            digitalHumanLivePanelView?.setMouthShape("neutral", intensity: 0, source: .providerVisemeTimeline)
            return false
        }
        digitalHumanLivePanelView?.applyPlaybackEvent(event)
        return true
    }

    private func makeUIQAMockSynthesisResultWithVisemeTimeline() -> VoiceCloneSynthesisResult? {
        let timeline = DigitalHumanLipSyncTimeline.makeUIQAMockProviderTimeline()
        guard let timelineData = try? JSONEncoder().encode(timeline),
              let timelineJSON = try? JSONSerialization.jsonObject(with: timelineData) as? [String: Any] else {
            return nil
        }

        return VoiceCloneSynthesisResult(json: [
            "voiceProfileId": "S_mock_digital_human_viseme",
            "providerMode": "mockProviderVisemeTimeline",
            "visemeTimeline": timelineJSON,
            "audio": [
                "encoding": "base64",
                "format": "mp3",
                "data": "TU9DS19BVURJTw==",
                "byteCount": 10
            ]
        ])
    }

    private func renderVoiceStatus(
        text: String?,
        isVisible: Bool,
        accessibilityIdentifier: String = "echoVoiceStatus"
    ) {
        let displayText: String?
        let identifier = accessibilityIdentifier
        if identifier.hasPrefix("echoLiveMemory"),
           let state = currentLiveMemoryCapturePresentationState,
           !identifier.hasPrefix("echoLiveMemoryRecovery") {
            if case .coverageGap = state {
                displayText = "正在整理\n" + (text ?? "")
            } else {
                displayText = EchoOrganizationPresentation.capture(state, partial: currentLiveMemoryPartialPublication)?.text ?? text
            }
        } else { displayText = text }
        voiceStatusLabel.text = displayText
        voiceStatusLabel.accessibilityLabel = displayText
        voiceStatusLabel.accessibilityIdentifier = accessibilityIdentifier
        voiceStatusHeightConstraint?.constant = isVisible ? 32 : 0
        voiceStatusView.isHidden = !isVisible
        voiceStatusView.alpha = isVisible ? 1 : 0
    }

    private func renderArchiveContextStatus(_ status: EchoArchiveContextStatus) {
        archiveContextStatusView.isHidden = !status.shouldShowArchiveContextIndicator
        archiveContextStatusView.alpha = status.shouldShowArchiveContextIndicator ? 1 : 0
        guard let text = status.indicatorText else {
            archiveContextStatusLabel.text = nil
            archiveContextStatusLabel.accessibilityLabel = nil
            return
        }
        archiveContextStatusLabel.text = text
        archiveContextStatusLabel.accessibilityLabel = text
    }

    private func configureMicButton(
        systemName: String,
        backgroundColor: UIColor,
        isEnabled: Bool,
        accessibilityLabel: String
    ) {
        let config = UIImage.SymbolConfiguration(pointSize: 28, weight: .semibold)
        micButton.setImage(UIImage(systemName: systemName, withConfiguration: config), for: .normal)
        micButton.backgroundColor = backgroundColor
        micButton.tintColor = isEnabled || backgroundColor == DJDesignTokens.Color.accentDeep
            ? .white
            : DJDesignTokens.Color.textSecondary
        micButton.isEnabled = isEnabled
        micButton.alpha = isEnabled ? 1 : 0.86
        micButton.accessibilityLabel = accessibilityLabel
    }

    private func setMicPulse(active: Bool) {
        micRingView.layer.removeAnimation(forKey: "echoPulse")

        guard active else {
            micRingView.transform = .identity
            micRingView.alpha = 0
            return
        }

        micRingView.alpha = 1
        let pulse = CABasicAnimation(keyPath: "transform.scale")
        pulse.fromValue = 0.92
        pulse.toValue = 1.08
        pulse.duration = 1.2
        pulse.autoreverses = true
        pulse.repeatCount = .infinity
        pulse.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
        micRingView.layer.add(pulse, forKey: "echoPulse")
    }

    @objc private func micTapped() {
        if activeVoiceLaunchAttempt?.isActive == true {
            stopVoiceCapture(); return
        }
        if isUserControlledLiveSessionOpen, isLiveVoiceTransportSuspended {
            isLiveVoiceTransportSuspended = false
            startVoiceCapture()
            return
        }
        if isUserControlledLiveSessionOpen {
            stopVoiceCapture()
            return
        }
        switch currentState {
        case .listening, .thinking, .speaking:
            stopVoiceCapture()
        case .replied where digitalHumanConversation.shouldResumeAfterProviderSpeech:
            stopVoiceCapture()
        case .error:
            viewModel.retryAfterError()
            startVoiceCapture()
        default:
            startVoiceCapture()
        }
    }

    @objc private func ownerTruthInterviewNaturalInputEntryTapped() {
        presentOwnerTruthInterviewNaturalInputSheet(presentation: .qa)
    }

    @objc private func ownerTruthInterviewNaturalInputProductEntryTapped() {
        guard isOwnerTruthInterviewNaturalInputProductEntryVisible else { return }
        if let handoff = pendingMemoryGapHandoff,
           handoff.contextKey == currentDigitalHumanRuntimeContextKey() {
            pendingMemoryGapHandoff = nil
            updateOwnerTruthInterviewNaturalInputProductEntryVisibility()
            switch handoff.destination {
            case .ownerInterview:
                echoTextQuestionTapped()
            case .familyContribution:
                presentFamilyContributionForMemoryGap(topic: handoff.question)
            }
            return
        }
        pendingMemoryGapHandoff = nil
        echoTextQuestionTapped()
    }

    @objc private func echoTextQuestionTapped() {
        guard isOwnerTruthInterviewNaturalInputProductEntryVisible,
              presentedViewController == nil else {
            return
        }

        let alert = UIAlertController(
            title: "文字回响",
            message: "输入想问 AI 助手或家人的话。回答只会使用当前身份有权访问的记忆。",
            preferredStyle: .alert
        )
        alert.addTextField { textField in
            textField.placeholder = "例如：我在哪里读的大学？"
            textField.clearButtonMode = .whileEditing
            textField.returnKeyType = .send
            textField.accessibilityIdentifier = "echoTextQuestionField"
        }
        alert.addAction(UIAlertAction(title: "取消", style: .cancel))
        if isTypedEchoConversationOpen {
            alert.addAction(UIAlertAction(title: "结束并整理", style: .default) { [weak self] _ in
                self?.finishTypedEchoConversation()
            })
        }
        alert.addAction(UIAlertAction(title: "发送", style: .default) { [weak self, weak alert] _ in
            let question = alert?.textFields?.first?.text ?? ""
            self?.beginEchoTextQuestion(question)
        })
        present(alert, animated: true)
    }

    private func beginEchoTextQuestion(_ rawQuestion: String) {
        guard !isUserControlledLiveSessionOpen else { return }
        let question = rawQuestion.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !question.isEmpty else {
            renderVoiceStatus(
                text: "请输入想问的内容",
                isVisible: true,
                accessibilityIdentifier: "echoTextQuestionEmpty"
            )
            return
        }
        if !isTypedEchoConversationOpen {
            transcriptEntries.removeAll(); quoteLabel.text = ""; quoteLabel.beginReply()
            refreshConversationSheet()
            recentEchoConversation.reset()
        }
        guard let accountLease = echoAccountLease,
              validateEchoAccountLease(
                  at: .request,
                  expected: accountLease,
                  reason: "textEchoQuestion"
              ),
              bindDialogEngineToEchoAccountLease(reason: "textEchoQuestion") else {
            viewModel.fail("账号状态已变化，请重新进入回响")
            return
        }

        pendingMemoryGapHandoff = nil
        updateOwnerTruthInterviewNaturalInputProductEntryVisibility()

        if case .error = currentState {
            viewModel.retryAfterError()
        }
        let lifecycleToken = invalidateDigitalHumanInteraction(reason: "textEchoQuestion")
        activeVoiceInteractionLifecycleToken = lifecycleToken
        pendingAIText = nil
        resetDigitalHumanReplyDispatchState()
        viewModel.prepareVoiceInteraction()
        viewModel.beginVoiceInteraction()
        submitEchoQuestion(
            question,
            source: "typed",
            lifecycleToken: lifecycleToken
        )
    }

    private func submitEchoQuestion(
        _ rawQuestion: String,
        source: String,
        lifecycleToken: DigitalHumanLifecycleToken
    ) {
        cancelLiveUserInactivityTimeout()
        let question = rawQuestion.trimmingCharacters(in: .whitespacesAndNewlines)
        let context = DigitalHumanContextStore.shared.current
        guard !question.isEmpty,
              let accountLease = echoAccountLease,
              validateEchoAccountLease(
                  at: .request,
                  expected: accountLease,
                  reason: "echoAnswerRequest"
              ),
              isCurrentDigitalHumanLifecycleToken(
                  lifecycleToken,
                  reason: "echoAnswerRequest"
              ) else {
            activeVoiceInteractionLifecycleToken = nil
            viewModel.fail("当前身份无权访问这份记忆")
            return
        }
        let routeDecision = echoV4IdentityRouteDecision(
            for: context,
            accountLease: accountLease
        )
        guard routeDecision.route != .denied else {
            activeVoiceInteractionLifecycleToken = nil
            viewModel.fail("当前家庭关系不可用于回响")
            return
        }

        pendingMemoryGapHandoff = nil
        updateOwnerTruthInterviewNaturalInputProductEntryVisibility()

        let acceptedUserTurn = viewModel.finishUserVoice(
            text: question,
            accountLease: accountLease,
            resourceOwnerId: accountLease.subjectId,
            roleContextKey: digitalHumanRuntimeContextKey(for: context),
            allowsDelayedReply: isEchoDelayedReplyProductEnabled
        )
        releaseEchoAudioOwnerLease(
            expectedOwner: .echoCapture,
            reason: "echoQuestionCaptured"
        )
        if let safetyDecision = viewModel.neutralSafetyDecision {
            activeVoiceInteractionLifecycleToken = nil
            enterNeutralSafetyMode(safetyDecision)
            return
        }
        guard acceptedUserTurn else {
            activeVoiceInteractionLifecycleToken = nil
            return
        }
        if source == "typed", routeDecision.route == .ownerPrivate {
            beginLiveMemoryCaptureIfNeeded(accountLease: accountLease)
            captureLiveOwnerTurn(question)
            updateOwnerTruthInterviewNaturalInputProductEntryVisibility()
        }

        let turnID = digitalHumanConversation.startUserTurn(
            makeID: makeTencentDigitalHumanRequestID
        )
        PrivacySafeDiagnostics.log(
            subsystem: "Echo",
            event: "backendAnswerRequested",
            states: [
                "source": source,
                "identityRoute": routeDecision.route.rawValue,
            ],
            counts: ["questionLength": question.count],
            correlations: ["turn": turnID]
        )

        switch routeDecision.route {
        case .visitorPublic:
            requestVisitorPublicEchoAnswer(
                question: question,
                context: context,
                routeDecision: routeDecision,
                lifecycleToken: lifecycleToken,
                accountLease: accountLease,
                turnID: turnID
            )
            return
        case .familyContribution:
            presentFamilyContributionEchoBoundary(
                question: question,
                context: context,
                lifecycleToken: lifecycleToken,
                accountLease: accountLease,
                turnID: turnID
            )
            return
        case .ownerPrivate:
            break
        case .denied:
            activeVoiceInteractionLifecycleToken = nil
            viewModel.fail("当前身份无权访问这份记忆")
            return
        }

        guard let expectedIdentity = echoKnowledgeContextIdentity(for: context) else {
            activeVoiceInteractionLifecycleToken = nil
            viewModel.fail("本人记忆身份暂不可用")
            return
        }

        if viewModel.isWaitingForDelayedReply {
            scheduleDelayedReplyNotificationIfNeeded(rawTranscript: question)
            beginDelayedReplyWait()
            activeVoiceInteractionLifecycleToken = nil
            return
        }

        renderVoiceStatus(
            text: "正在从记忆中寻找回答",
            isVisible: true,
            accessibilityIdentifier: "echoBackendAnswerLoading"
        )
        let recentTurns = recentEchoConversation.startUserTurn(question)
        let productSessionID = recentEchoConversation.productSessionID
        let clientTurnID = UUID().uuidString
        DreamJourneyBackendClient.shared.requestEchoAnswer(
            userId: expectedIdentity.userId,
            query: question,
            personaScope: expectedIdentity.personaScope,
            digitalHumanId: expectedIdentity.digitalHumanId,
            personaName: context.resolvedDisplayName,
            lifecycleMode: context.mode,
            viewerFamilyMemberID: nil,
            recentTurns: recentTurns,
            productSessionID: productSessionID,
            clientTurnID: clientTurnID
        ) { [weak self] result in
            DispatchQueue.main.async {
                guard let self,
                      self.validateEchoAccountLease(
                          at: .ui,
                          expected: accountLease,
                          reason: "echoAnswerResponse"
                      ),
                      self.isCurrentDigitalHumanLifecycleToken(
                          lifecycleToken,
                          reason: "echoAnswerResponse"
                      ),
                      self.echoKnowledgeContextIdentity(
                          for: DigitalHumanContextStore.shared.current
                      ) == expectedIdentity else {
                    return
                }

                switch result {
                case .success(let answer):
                    self.lastEchoAnswerGroundingEvidence = OwnerTruthContextCitationQAGate.isEnabled
                        ? EchoAnswerGroundingQAEvidence(answer: answer)
                        : nil
                    let memoryGapHandoff = self.memoryGapHandoff(
                        for: answer,
                        question: question,
                        context: context
                    )
                    self.pendingMemoryGapHandoff = memoryGapHandoff
                    let replyText = self.replyText(
                        for: answer,
                        memoryGapHandoff: memoryGapHandoff,
                        context: context
                    )
                    self.captureLiveAssistantTurn(replyText)
                    guard self.viewModel.receiveAIReply(replyText) else {
                        self.activeVoiceInteractionLifecycleToken = nil
                        self.viewModel.fail("本轮回响状态已变化，请重新提问")
                        return
                    }
                    self.recentEchoConversation.appendAssistantTurn(replyText)
                    PrivacySafeDiagnostics.log(
                        subsystem: "Echo",
                        event: "backendAnswerReceived",
                        states: [
                            "provider": answer.provider,
                            "memoryGrounding": answer.memoryGrounding.outcome.rawValue,
                            "memoryHandoff": memoryGapHandoff?.destination.rawValue ?? "none",
                        ],
                        counts: [
                            "answerLength": replyText.count,
                            "citationCount": answer.citations.count,
                        ],
                        correlations: ["turn": turnID]
                    )
                    self.completeTypedEchoReplyWithoutAudio(
                        lifecycleToken: lifecycleToken,
                        accountLease: accountLease,
                        source: "backendEchoAnswer"
                    )
                case .failure:
                    self.activeVoiceInteractionLifecycleToken = nil
                    self.viewModel.fail("回响连接失败，请稍后重试")
                    self.renderVoiceStatus(
                        text: "回响连接失败，请稍后重试",
                        isVisible: true,
                        accessibilityIdentifier: "echoBackendAnswerFailed"
                    )
                }
            }
        }
    }

    private func requestVisitorPublicEchoAnswer(
        question: String,
        context: DigitalHumanContext,
        routeDecision: EchoV4IdentityRouteDecision,
        lifecycleToken: DigitalHumanLifecycleToken,
        accountLease: AccountLease,
        turnID: String
    ) {
        let expectedContextKey = digitalHumanRuntimeContextKey(for: context)
        renderVoiceStatus(
            text: "正在公开回忆中寻找回答",
            isVisible: true,
            accessibilityIdentifier: "echoVisitorPublicAnswerLoading"
        )
        PublicationVisitorRuntime.shared.makeReadUseCase().answer(question) { [weak self] result in
            DispatchQueue.main.async {
                guard let self,
                      self.validateEchoAccountLease(
                        at: .ui,
                        expected: accountLease,
                        reason: "visitorPublicAnswerResponse"
                      ),
                      self.isCurrentDigitalHumanLifecycleToken(
                        lifecycleToken,
                        reason: "visitorPublicAnswerResponse"
                      ),
                      self.currentDigitalHumanRuntimeContextKey() == expectedContextKey,
                      self.echoV4IdentityRouteDecision(
                        for: DigitalHumanContextStore.shared.current,
                        accountLease: accountLease
                      ) == routeDecision else {
                    return
                }

                switch result {
                case .success(let response):
                    let replyText = response.answer.text
                    self.captureLiveAssistantTurn(replyText)
                    guard self.viewModel.receiveAIReply(replyText) else {
                        self.activeVoiceInteractionLifecycleToken = nil
                        self.viewModel.fail("本轮公开回响状态已变化，请重新提问")
                        return
                    }
                    PrivacySafeDiagnostics.log(
                        subsystem: "Echo",
                        event: "visitorPublicAnswerReceived",
                        states: [
                            "identityRoute": EchoV4IdentityRoute.visitorPublic.rawValue,
                            "answerKind": response.answer.kind.rawValue,
                            "privateContext": "denied",
                            "digitalHuman": "disabled",
                        ],
                        counts: ["answerLength": replyText.count],
                        correlations: ["turn": turnID]
                    )
                    self.completeTypedEchoReplyWithoutAudio(
                        lifecycleToken: lifecycleToken,
                        accountLease: accountLease,
                        source: "visitorPublicAnswer"
                    )
                case .failure:
                    self.activeVoiceInteractionLifecycleToken = nil
                    self.viewModel.fail("公开回忆暂不可访问，请重新获取分享授权")
                    self.renderVoiceStatus(
                        text: "公开回忆授权已失效",
                        isVisible: true,
                        accessibilityIdentifier: "echoVisitorPublicAnswerFailed"
                    )
                }
            }
        }
    }

    /// Explicit delegated/one-shot fallback used outside normal provider-owned
    /// Live. Production Live answers in the native sessionSnapshot session and
    /// returns before this method from `onASRResult`.
    private func requestLiveEchoAnswer(
        question: String,
        turnID: String,
        lifecycleToken: DigitalHumanLifecycleToken,
        accountLease: AccountLease
    ) {
        let context = DigitalHumanContextStore.shared.current
        pendingMemoryGapHandoff = nil
        updateOwnerTruthInterviewNaturalInputProductEntryVisibility()
        let routeDecision = echoV4IdentityRouteDecision(
            for: context,
            accountLease: accountLease
        )

        switch routeDecision.route {
        case .ownerPrivate:
            guard let expectedIdentity = echoKnowledgeContextIdentity(for: context) else {
                viewModel.fail("本人记忆身份暂不可用")
                return
            }
            renderVoiceStatus(
                text: "正在从正式记忆中组织回答",
                isVisible: true,
                accessibilityIdentifier: "echoLiveBackendAnswerLoading"
            )
            let recentTurns = recentEchoConversation.startUserTurn(question)
            let productSessionID = recentEchoConversation.productSessionID
            let clientTurnID = UUID().uuidString
            DreamJourneyBackendClient.shared.requestEchoAnswer(
                userId: expectedIdentity.userId,
                query: question,
                personaScope: expectedIdentity.personaScope,
                digitalHumanId: expectedIdentity.digitalHumanId,
                personaName: context.resolvedDisplayName,
                lifecycleMode: context.mode,
                viewerFamilyMemberID: nil,
                recentTurns: recentTurns,
                productSessionID: productSessionID,
                clientTurnID: clientTurnID
            ) { [weak self] result in
                DispatchQueue.main.async {
                    guard let self,
                          self.validateEchoAccountLease(
                            at: .ui,
                            expected: accountLease,
                            reason: "liveEchoAnswerResponse"
                          ),
                          self.isCurrentDigitalHumanLifecycleToken(
                            lifecycleToken,
                            reason: "liveEchoAnswerResponse"
                          ),
                          self.echoKnowledgeContextIdentity(
                            for: DigitalHumanContextStore.shared.current
                          ) == expectedIdentity else {
                        return
                    }
                    switch result {
                    case .success(let answer):
                        self.lastEchoAnswerGroundingEvidence = OwnerTruthContextCitationQAGate.isEnabled
                            ? EchoAnswerGroundingQAEvidence(answer: answer)
                            : nil
                        let memoryGapHandoff = self.memoryGapHandoff(
                            for: answer,
                            question: question,
                            context: context
                        )
                        self.pendingMemoryGapHandoff = memoryGapHandoff
                        let replyText = self.replyText(
                            for: answer,
                            memoryGapHandoff: memoryGapHandoff,
                            context: context
                        )
                        self.deliverLiveEchoAnswer(
                            replyText,
                            traceID: answer.contextTraceId,
                            turnID: turnID,
                            lifecycleToken: lifecycleToken,
                            accountLease: accountLease,
                            source: "backendEchoAnswer"
                        )
                        PrivacySafeDiagnostics.log(
                            subsystem: "Echo",
                            event: "liveBackendAnswerReceived",
                            states: [
                                "provider": answer.provider,
                                "memoryGrounding": answer.memoryGrounding.outcome.rawValue,
                                "memoryHandoff": memoryGapHandoff?.destination.rawValue ?? "none",
                            ],
                            counts: [
                                "answerLength": replyText.count,
                                "citationCount": answer.citations.count,
                            ],
                            correlations: ["turn": turnID]
                        )
                    case .failure:
                        self.failLiveEchoAnswer(
                            message: "回响连接失败，请稍后重试",
                            lifecycleToken: lifecycleToken
                        )
                    }
                }
            }

        case .visitorPublic:
            let expectedContextKey = digitalHumanRuntimeContextKey(for: context)
            renderVoiceStatus(
                text: "正在公开回忆中寻找回答",
                isVisible: true,
                accessibilityIdentifier: "echoLiveVisitorAnswerLoading"
            )
            PublicationVisitorRuntime.shared.makeReadUseCase().answer(question) { [weak self] result in
                DispatchQueue.main.async {
                    guard let self,
                          self.validateEchoAccountLease(
                            at: .ui,
                            expected: accountLease,
                            reason: "liveVisitorAnswerResponse"
                          ),
                          self.isCurrentDigitalHumanLifecycleToken(
                            lifecycleToken,
                            reason: "liveVisitorAnswerResponse"
                          ),
                          self.currentDigitalHumanRuntimeContextKey() == expectedContextKey,
                          self.echoV4IdentityRouteDecision(
                            for: DigitalHumanContextStore.shared.current,
                            accountLease: accountLease
                          ) == routeDecision else {
                        return
                    }
                    switch result {
                    case .success(let response):
                        self.deliverLiveEchoAnswer(
                            response.answer.text,
                            traceID: nil,
                            turnID: turnID,
                            lifecycleToken: lifecycleToken,
                            accountLease: accountLease,
                            source: "visitorPublicAnswer"
                        )
                    case .failure:
                        self.failLiveEchoAnswer(
                            message: "公开回忆暂不可访问，请重新获取分享授权",
                            lifecycleToken: lifecycleToken
                        )
                    }
                }
            }

        case .familyContribution:
            let handoff = EchoMemoryGapHandoff(
                question: String(question.prefix(200)),
                destination: .familyContribution,
                contextKey: digitalHumanRuntimeContextKey(for: context)
            )
            pendingMemoryGapHandoff = handoff
            updateOwnerTruthInterviewNaturalInputProductEntryVisibility()
            deliverLiveEchoAnswer(
                "这位家人尚未向你发布可查询的回忆。如果你愿意，可以分享一段相关故事，交给档案所有者确认。",
                traceID: nil,
                turnID: turnID,
                lifecycleToken: lifecycleToken,
                accountLease: accountLease,
                source: "familyContributionBoundary"
            )

        case .denied:
            failLiveEchoAnswer(
                message: "当前身份无权访问这份记忆",
                lifecycleToken: lifecycleToken
            )
        }
    }

    private func deliverLiveEchoAnswer(
        _ rawText: String,
        traceID: String?,
        turnID: String,
        lifecycleToken: DigitalHumanLifecycleToken,
        accountLease: AccountLease,
        source: String
    ) {
        let replyText = rawText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !replyText.isEmpty,
              validateEchoAccountLease(
                at: .runtime,
                expected: accountLease,
                reason: "deliverLiveEchoAnswer"
              ),
              isCurrentDigitalHumanLifecycleToken(
                lifecycleToken,
                reason: "deliverLiveEchoAnswer"
              ),
              isUserControlledLiveSessionOpen else {
            return
        }
        cancelLiveUserInactivityTimeout()

        guard let liveAudioRoute = scopedActiveLiveAudioRoute else {
            failLiveEchoAnswer(
                message: "本轮语音路由尚未准备完成，请重新开始",
                lifecycleToken: lifecycleToken
            )
            return
        }

        if liveAudioRoute == .tencentDigitalHuman {
            guard shouldDispatchEchoReplyToTencentProvider else {
                markPinnedLiveAudioRouteUnavailable(reason: "tencentRouteLostBeforePlayback")
                failLiveEchoAnswer(
                    message: "数字人声音暂不可用，请结束本轮后重试",
                    lifecycleToken: lifecycleToken
                )
                return
            }
            captureLiveAssistantTurn(replyText)
            guard viewModel.receiveAIReply(replyText) else {
                failLiveEchoAnswer(
                    message: "本轮回响状态已变化，请重新提问",
                    lifecycleToken: lifecycleToken
                )
                return
            }
            recentEchoConversation.appendAssistantTurn(replyText)
            beginLivePlaybackReceipt(
                route: .tencentDigitalHuman,
                turnID: turnID,
                lifecycleToken: lifecycleToken,
                answerCharacterCount: replyText.count
            )
            sendEchoReplyToDigitalHumanRuntimeIfReady(replyText, source: source)
            return
        }

        if case .unavailable = liveAudioRoute {
            failLiveEchoAnswer(
                message: "本轮语音播放不可用，请结束后重试",
                lifecycleToken: lifecycleToken
            )
            return
        }

        pendingAIText = replyText
        guard DialogEngineManager.shared.submitLiveAnswerText(
            replyText,
            traceID: traceID,
            source: source
        ) else {
            pendingAIText = nil
            failLiveEchoAnswer(
                message: "回响语音暂不可用，请稍后重试",
                lifecycleToken: lifecycleToken
            )
            return
        }
        beginLivePlaybackReceipt(
            route: .volcengineLocalTTS,
            turnID: turnID,
            lifecycleToken: lifecycleToken,
            answerCharacterCount: replyText.count
        )
        recentEchoConversation.appendAssistantTurn(replyText)
        renderVoiceStatus(
            text: "正在回响",
            isVisible: true,
            accessibilityIdentifier: "echoLiveBackendAnswerSpeaking"
        )
        PrivacySafeDiagnostics.log(
            subsystem: "Echo",
            event: "liveBackendAnswerSubmitted",
            states: ["source": source],
            counts: ["answerLength": replyText.count],
            correlations: ["turn": turnID]
        )
    }

    private func failLiveEchoAnswer(
        message: String,
        lifecycleToken: DigitalHumanLifecycleToken
    ) {
        guard isCurrentDigitalHumanLifecycleToken(
            lifecycleToken,
            reason: "liveEchoAnswerFailure"
        ) else {
            return
        }
        cancelLivePlaybackReceipt(reason: "liveEchoAnswerFailed")
        pendingAIText = nil
        viewModel.fail(message)
        renderVoiceStatus(
            text: message,
            isVisible: true,
            accessibilityIdentifier: "echoLiveBackendAnswerFailed"
        )
    }

    private func presentFamilyContributionEchoBoundary(
        question: String,
        context: DigitalHumanContext,
        lifecycleToken: DigitalHumanLifecycleToken,
        accountLease: AccountLease,
        turnID: String
    ) {
        let handoff = EchoMemoryGapHandoff(
            question: String(question.prefix(200)),
            destination: .familyContribution,
            contextKey: digitalHumanRuntimeContextKey(for: context)
        )
        pendingMemoryGapHandoff = handoff
        updateOwnerTruthInterviewNaturalInputProductEntryVisibility()
        let replyText = "这位家人尚未向你发布可查询的回忆。"
            + "如果你愿意，可以分享一段相关故事，交给档案所有者确认。"
        captureLiveAssistantTurn(replyText)
        guard viewModel.receiveAIReply(replyText) else {
            activeVoiceInteractionLifecycleToken = nil
            viewModel.fail("本轮家庭贡献状态已变化，请重新提问")
            return
        }
        PrivacySafeDiagnostics.log(
            subsystem: "Echo",
            event: "familyContributionBoundaryPresented",
            states: [
                "identityRoute": EchoV4IdentityRoute.familyContribution.rawValue,
                "privateContext": "denied",
                "legacyFallback": "denied",
            ],
            counts: ["questionLength": question.count],
            correlations: ["turn": turnID]
        )
        completeTypedEchoReplyWithoutAudio(
            lifecycleToken: lifecycleToken,
            accountLease: accountLease,
            source: "familyContributionBoundary"
        )
    }

    private func completeTypedEchoReplyWithoutAudio(
        lifecycleToken: DigitalHumanLifecycleToken,
        accountLease: AccountLease,
        source: String
    ) {
        guard validateEchoAccountLease(
            at: .ui,
            expected: accountLease,
            reason: "typedEchoTextOnlyCompletion"
        ),
        isCurrentDigitalHumanLifecycleToken(
            lifecycleToken,
            reason: "typedEchoTextOnlyCompletion"
        ) else {
            return
        }
        pendingAIText = nil
        cancelLivePlaybackReceipt(reason: "typedEchoTextOnly")
        _ = markEchoReplyDelivered()
        activeVoiceInteractionLifecycleToken = nil
        renderVoiceStatus(
            text: "回响已送达",
            isVisible: true,
            accessibilityIdentifier: "echoTextOnlyFinished"
        )
        PrivacySafeDiagnostics.log(
            subsystem: "Echo",
            event: "typedEchoTextOnlyCompleted",
            states: ["source": source]
        )
    }

    private func playEchoAnswerWithVolcSpeech(
        _ text: String,
        lifecycleToken: DigitalHumanLifecycleToken,
        accountLease: AccountLease
    ) {
        cancelLiveUserInactivityTimeout()
        cancelEchoTextReplySpeech(reason: "newTextEchoReply")
        let requestID = UUID()
        echoTextReplySpeechRequestID = requestID
        echoTextReplyLifecycleToken = lifecycleToken
        renderVoiceStatus(
            text: "正在连接实时回响语音",
            isVisible: true,
            accessibilityIdentifier: "echoVolcSpeechLoading"
        )
        guard bindDialogEngineToEchoAccountLease(reason: "textEchoRealtimePlayback"),
              setDialogEngineLocalTTSPlaybackEnabled(true),
              acquireEchoRuntimeAudioOwner(
                .echoLocalPlayback,
                priority: .playback,
                reason: "textEchoRealtimePlayback"
              ),
              let audioLease = activeEchoAudioOwnerLease,
              audioLease.owner == .echoLocalPlayback else {
            completeEchoTextReplyWithoutAudio(
                lifecycleToken: lifecycleToken,
                reason: "realtimePlaybackPreparationFailed"
            )
            return
        }

        DreamJourneyBackendClient.shared.fetchRealtimeVoiceConfig(
            userId: accountLease.subjectId
        ) { [weak self] result in
            DispatchQueue.main.async {
                guard let self,
                      self.echoTextReplySpeechRequestID == requestID,
                      self.echoTextReplyLifecycleToken == lifecycleToken,
                      self.validateEchoAccountLease(
                          at: .ui,
                          expected: accountLease,
                          reason: "echoTextReplySpeechResponse"
                      ),
                      self.isCurrentDigitalHumanLifecycleToken(
                          lifecycleToken,
                          reason: "echoTextReplySpeechResponse"
                      ) else {
                    return
                }

                switch result {
                case .success(let runtimeConfig):
                    guard DialogEngineManager.shared.configure(
                        runtimeConfig: runtimeConfig
                    ), DialogEngineManager.shared.adoptExternallyManagedAudioSessionLease(
                        audioLease
                    ) else {
                        self.completeEchoTextReplyWithoutAudio(
                            lifecycleToken: lifecycleToken,
                            reason: "realtimeRuntimeRejected"
                        )
                        return
                    }
                    DialogEngineManager.shared.delegate = self
                    _ = DialogEngineManager.shared.startTextReplyPlayback(
                        text: text,
                        onStarted: { [weak self] in
                            DispatchQueue.main.async {
                                guard let self,
                                      self.echoTextReplySpeechRequestID == requestID,
                                      self.echoTextReplyLifecycleToken == lifecycleToken else {
                                    return
                                }
                                self.renderVoiceStatus(
                                    text: "正在朗读回响",
                                    isVisible: true,
                                    accessibilityIdentifier: "echoVolcSpeechPlayback"
                                )
                            }
                        },
                        completion: { [weak self] playbackResult in
                            DispatchQueue.main.async {
                                self?.completeEchoTextReplyPlayback(
                                    playbackResult,
                                    requestID: requestID,
                                    lifecycleToken: lifecycleToken,
                                    accountLease: accountLease
                                )
                            }
                        }
                    )
                case .failure:
                    self.completeEchoTextReplyWithoutAudio(
                        lifecycleToken: lifecycleToken,
                        reason: "realtimeRuntimeUnavailable"
                    )
                }
            }
        }
    }

    private func cancelEchoTextReplySpeech(reason: String) {
        if ownsCurrentDialogEngineBinding() {
            DialogEngineManager.shared.cancelTextReplyPlayback()
        }
        echoTextReplySpeechRequestID = nil
        echoTextReplyLifecycleToken = nil
        releaseEchoAudioOwnerLease(
            expectedOwner: .echoLocalPlayback,
            reason: reason
        )
    }

    private func completeEchoTextReplyWithoutAudio(
        lifecycleToken: DigitalHumanLifecycleToken,
        reason: String
    ) {
        guard echoTextReplyLifecycleToken == lifecycleToken else { return }
        echoTextReplySpeechRequestID = nil
        echoTextReplyLifecycleToken = nil
        if ownsCurrentDialogEngineBinding() {
            DialogEngineManager.shared.cancelTextReplyPlayback()
        }
        releaseEchoAudioOwnerLease(
            expectedOwner: .echoLocalPlayback,
            reason: reason
        )
        _ = markEchoReplyDelivered()
        activeVoiceInteractionLifecycleToken = nil
        renderVoiceStatus(
            text: "回响语音暂不可用，已显示文字",
            isVisible: true,
            accessibilityIdentifier: "echoVolcSpeechTextOnly"
        )
    }

    private func completeEchoTextReplyPlayback(
        _ result: Result<Void, Error>,
        requestID: UUID,
        lifecycleToken: DigitalHumanLifecycleToken,
        accountLease: AccountLease
    ) {
        guard echoTextReplySpeechRequestID == requestID,
              echoTextReplyLifecycleToken == lifecycleToken,
              validateEchoAccountLease(
                at: .ui,
                expected: accountLease,
                reason: "echoTextReplyRealtimeCompletion"
              ) else {
            return
        }
        echoTextReplySpeechRequestID = nil
        echoTextReplyLifecycleToken = nil
        releaseEchoAudioOwnerLease(
            expectedOwner: .echoLocalPlayback,
            reason: "echoTextReplyRealtimeCompletion"
        )
        _ = markEchoReplyDelivered()
        activeVoiceInteractionLifecycleToken = nil
        let succeeded: Bool
        switch result {
        case .success:
            succeeded = true
        case .failure:
            succeeded = false
        }
        renderVoiceStatus(
            text: succeeded ? "回响已送达" : "回响语音暂不可用，已显示文字",
            isVisible: true,
            accessibilityIdentifier: succeeded
                ? "echoVolcSpeechFinished"
                : "echoVolcSpeechPlaybackFailed"
        )
    }

    private func presentOwnerTruthInterviewNaturalInputSheet(
        presentation: OwnerTruthInterviewNaturalInputPresentation,
        initialTopic: String? = nil
    ) {
        let isEntryAvailable: Bool
        switch presentation {
        case .qa:
            isEntryAvailable = shouldShowOwnerTruthInterviewNaturalInputEntry
        case .product:
            isEntryAvailable = isOwnerTruthInterviewNaturalInputProductEntryVisible
        }
        guard isEntryAvailable,
              let accountLease = captureEchoAccountLease(reason: "ownerTruthNaturalInputEntry"),
              validateEchoAccountLease(
                at: .request,
                expected: accountLease,
                reason: "ownerTruthNaturalInputEntry"
              ),
              presentedViewController == nil else {
            return
        }

        let controller = OwnerTruthInterviewNaturalInputViewController(
            accountLease: accountLease,
            presentation: presentation,
            initialTopic: initialTopic,
            reviewBatchAcknowledgementPolicyAvailable: { [weak self] in
                guard let self else { return false }
                switch presentation {
                case .qa:
                    return self.shouldShowOwnerTruthInterviewNaturalInputEntry
                case .product:
                    return self.isOwnerTruthInterviewNaturalInputProductEntryVisible
                }
            },
            qaGateEnabled: { [weak self] in
                guard let self else { return false }
                switch presentation {
                case .qa:
                    return self.shouldShowOwnerTruthInterviewNaturalInputEntry
                case .product:
                    return self.isOwnerTruthInterviewNaturalInputProductEntryVisible
                }
            }
        )
        let navigationController = UINavigationController(rootViewController: controller)
        navigationController.modalPresentationStyle = .pageSheet
        if let sheet = navigationController.sheetPresentationController {
            sheet.detents = [.medium(), .large()]
            sheet.prefersGrabberVisible = true
        }
        present(navigationController, animated: true)
    }

    private func memoryGapHandoff(
        for answer: EchoAnswer,
        question: String,
        context: DigitalHumanContext
    ) -> EchoMemoryGapHandoff? {
        guard answer.signalsMemoryGap else { return nil }
        let destination: EchoMemoryGapHandoff.Destination = context.isSelfAssistant
            ? .ownerInterview
            : .familyContribution
        return EchoMemoryGapHandoff(
            question: String(question.prefix(200)),
            destination: destination,
            contextKey: digitalHumanRuntimeContextKey(for: context)
        )
    }

    private func replyText(
        for answer: EchoAnswer,
        memoryGapHandoff: EchoMemoryGapHandoff?,
        context: DigitalHumanContext
    ) -> String {
        guard let memoryGapHandoff else { return answer.text }
        switch memoryGapHandoff.destination {
        case .ownerInterview:
            return "这段记忆我还不了解。那我们来聊一聊吧，你最先想到的是什么？"
        case .familyContribution:
            return "我还没有从\(context.resolvedDisplayName)已确认的记忆中找到这个答案。"
                + "如果你愿意，可以分享一段相关的故事，交给档案所有者确认。"
        }
    }

    private func presentFamilyContributionForMemoryGap(topic: String) {
        let context = DigitalHumanContextStore.shared.current
        guard !context.isSelfAssistant,
              let accountLease = echoAccountLease,
              validateEchoAccountLease(
                at: .request,
                expected: accountLease,
                reason: "memoryGapFamilyContribution"
              ),
              let member = FamilyRepository.shared.acceptedMembers(for: accountLease.subjectId)
                .first(where: { $0.id == context.ownerId }) else {
            showFamilyContributionUnavailable()
            return
        }
        let expectedContextKey = digitalHumanRuntimeContextKey(for: context)
        renderVoiceStatus(
            text: "正在准备家庭记忆贡献",
            isVisible: true,
            accessibilityIdentifier: "echoMemoryGapFamilyContributionLoading"
        )
        DreamJourneyBackendClient.shared.listContributorFamilyContributionGrants(
            accountLease: accountLease
        ) { [weak self] result in
            DispatchQueue.main.async {
                guard let self,
                      self.validateEchoAccountLease(
                        at: .ui,
                        expected: accountLease,
                        reason: "memoryGapFamilyContributionResponse"
                      ),
                      self.currentDigitalHumanRuntimeContextKey() == expectedContextKey else {
                    return
                }
                switch result {
                case .success(let grants):
                    guard let grant = grants.first(where: {
                        $0.isActive && $0.relationshipId == member.relationshipId
                    }) else {
                        self.showFamilyContributionUnavailable()
                        return
                    }
                    let controller = FamilyContributionComposerViewController(
                        grant: grant,
                        accountLease: accountLease,
                        initialTopic: topic
                    )
                    if let navigationController = self.navigationController {
                        navigationController.pushViewController(controller, animated: true)
                    } else {
                        let navigationController = UINavigationController(rootViewController: controller)
                        navigationController.modalPresentationStyle = .pageSheet
                        self.present(navigationController, animated: true)
                    }
                case .failure:
                    self.showFamilyContributionUnavailable()
                }
            }
        }
    }

    private func showFamilyContributionUnavailable() {
        let alert = UIAlertController(
            title: "需要家庭贡献授权",
            message: "这段故事属于当前家人的档案。请先在家人管理中取得贡献授权，再提交给档案所有者确认。",
            preferredStyle: .alert
        )
        alert.addAction(UIAlertAction(title: "稍后", style: .cancel))
        alert.addAction(UIAlertAction(title: "进入家人管理", style: .default) { [weak self] _ in
            let controller = FamilyCircleViewController()
            if let navigationController = self?.navigationController {
                navigationController.pushViewController(controller, animated: true)
            } else if let self {
                let navigationController = UINavigationController(rootViewController: controller)
                navigationController.modalPresentationStyle = .pageSheet
                self.present(navigationController, animated: true)
            }
        })
        present(alert, animated: true)
    }

    private var isOwnerTruthInterviewNaturalInputProductEntryVisible: Bool {
        !isUserControlledLiveSessionOpen && isOwnerTruthInterviewNaturalInputProductPolicyPermitted
            && !shouldShowOwnerTruthInterviewNaturalInputEntry
            && canShowOwnerTruthInterviewNaturalInputProductEntry(for: currentState)
    }

    private func canShowOwnerTruthInterviewNaturalInputProductEntry(
        for state: EchoInteractionState
    ) -> Bool {
        switch state {
        case .idle, .replied, .error:
            return true
        case .starting, .listening, .thinking, .waitingReply, .awaitingReplyDelivery, .neutralSafety, .speaking:
            return false
        }
    }

    private func refreshOwnerTruthInterviewNaturalInputProductEntryPolicy() {
        ownerTruthInterviewNaturalInputPolicyRefreshGeneration &+= 1
        let refreshGeneration = ownerTruthInterviewNaturalInputPolicyRefreshGeneration

        guard !shouldShowOwnerTruthInterviewNaturalInputEntry,
              DreamJourneyBackendClient.shared.isReleasePolicyConfigured else {
            isOwnerTruthInterviewNaturalInputProductPolicyPermitted = false
            updateOwnerTruthInterviewNaturalInputProductEntryVisibility()
            return
        }

        FeatureGateService.shared.refreshPolicy { [weak self] result in
            DispatchQueue.main.async {
                guard let self,
                      self.ownerTruthInterviewNaturalInputPolicyRefreshGeneration == refreshGeneration,
                      !self.shouldShowOwnerTruthInterviewNaturalInputEntry else {
                    return
                }
                switch result {
                case .success:
                    let surfaceDecision = FeatureGateService.shared
                        .captureServerPolicyManagedRoute(
                            .echoTextInput,
                            risk: .ownerTextCore
                        )
                    let writeDecision = FeatureGateService.shared
                        .requestServerPolicyManagedDecision(for: .echoTextInput)
                    self.isOwnerTruthInterviewNaturalInputProductPolicyPermitted = surfaceDecision.allowed
                        && writeDecision.allowed
                case .failure:
                    self.isOwnerTruthInterviewNaturalInputProductPolicyPermitted = false
                }
                self.updateOwnerTruthInterviewNaturalInputProductEntryVisibility()
                self.resumePendingLiveMemoryOrganizationsIfNeeded()
                self.retainedLiveMemoryRecoveryCoordinators.values.forEach {
                    $0.verifyStatus(startsNewRound: true)
                }
            }
        }
    }

    private func updateOwnerTruthInterviewNaturalInputProductEntryVisibility() {
        let starting: Bool
        if case .starting = currentState { starting = true } else { starting = false }
        let live = isUserControlledLiveSessionOpen || starting
        composer.isHidden = live
        composer.isUserInteractionEnabled = isOwnerTruthInterviewNaturalInputProductEntryVisible
        composer.alpha = composer.isUserInteractionEnabled ? 1 : 0.65
        if live { composer.field.resignFirstResponder() }
        ownerTruthInterviewNaturalInputProductEntryButton.isHidden = true
        ownerTruthInterviewNaturalInputProductEntryButton.isUserInteractionEnabled = false
        micCenterConstraint?.isActive = false
        micTrailingConstraint?.isActive = false
        if live { micCenterConstraint?.isActive = true } else { micTrailingConstraint?.isActive = true }
        finishTextButton.isHidden = live || !isTypedEchoConversationOpen
        if live { showMemoriesButton.isHidden = true }
        view.setNeedsLayout()
    }

    private func beginLiveMemoryCaptureIfNeeded(
        accountLease: AccountLease,
        productSessionID: String? = nil
    ) {
        guard DigitalHumanContextStore.shared.current.isSelfAssistant else {
            closeCanonicalTranscriptIngress()
            liveMemoryCaptureCoordinator = nil
            return
        }
        guard liveMemoryCaptureCoordinator == nil else { return }
        #if DEBUG
        if let voiceLaunchCaptureFactoryForTesting {
            let coordinator = voiceLaunchCaptureFactoryForTesting(
                accountLease, productSessionID
            )
            retainLiveMemoryCaptureCoordinator(coordinator, asActive: true)
            return
        }
        #endif
        let coordinator = EchoLiveMemoryCaptureCoordinator(
            accountLease: accountLease,
            productSessionID: productSessionID,
            naturalInputPolicyAvailable: {
                FeatureGateService.shared
                    .requestServerPolicyManagedDecision(for: .echoTextInput)
                    .allowed
            },
            naturalInputPolicyRefresh: { completion in
                FeatureGateService.shared.refreshPolicy(for: .echoTextInput) { result in
                    completion((try? result.get()) != nil)
                }
            },
            candidateReviewPolicyAvailable: {
                FeatureGateService.shared
                    .requestServerPolicyManagedDecision(for: .ownerTruthCandidateReview)
                    .allowed
            },
            candidateReviewPolicyRefresh: { completion in
                FeatureGateService.shared.refreshPolicy(
                    for: .ownerTruthCandidateReview
                ) { result in
                    switch result {
                    case .success:
                        // This Bool only reports that the bounded refresh
                        // completed. The coordinator's admission use case
                        // captures and binds a fresh request decision after it.
                        completion(true)
                    case .failure:
                        completion(false)
                    }
                }
            }
        )
        retainLiveMemoryCaptureCoordinator(coordinator, asActive: true)
    }

    private func beginRecoveryGracefulStop(_ coordinator: EchoLiveMemoryCaptureCoordinator) {
        guard liveMemoryCaptureCoordinator === coordinator,
              recoveryGracefulStopCoordinatorID != coordinator.id else { return }
        recoveryGracefulStopCoordinatorID = coordinator.id
        recoveryGracefulStopDeadline = Date().addingTimeInterval(5)
        coordinator.persistRecoveryGracefulStop()
        evaluateRecoveryGracefulStop(coordinator)
    }

    private func evaluateRecoveryGracefulStop(_ coordinator: EchoLiveMemoryCaptureCoordinator) {
        guard liveMemoryCaptureCoordinator === coordinator,
              recoveryGracefulStopCoordinatorID == coordinator.id else { return }
        let expired = Date() >= (recoveryGracefulStopDeadline ?? .distantPast)
        if expired || (!recoveryUserUtteranceActive && coordinator.recoveryGracefulStopPersistenceFinished) {
            recoveryGracefulStopTimer?.cancel(); recoveryGracefulStopTimer = nil
            recoveryGracefulStopCoordinatorID = nil; recoveryGracefulStopDeadline = nil
            finishLiveMemoryCaptureIfNeeded()
            stopVoiceCapture()
            return
        }
        let work = DispatchWorkItem { [weak self, weak coordinator] in
            guard let coordinator else { return }
            self?.evaluateRecoveryGracefulStop(coordinator)
        }
        recoveryGracefulStopTimer?.cancel(); recoveryGracefulStopTimer = work
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.05, execute: work)
    }

    private func retainLiveMemoryCaptureCoordinator(
        _ coordinator: EchoLiveMemoryCaptureCoordinator,
        asActive: Bool
    ) {
        let coordinatorID = coordinator.id
        coordinator.onStateChange = { [weak self, weak coordinator] state in
            DispatchQueue.main.async {
                guard let self, let coordinator,
                      self.currentLiveMemoryCapturePresentationCoordinatorID == coordinatorID else {
                    return
                }
                self.currentLiveMemoryCapturePresentationState = state
                self.currentLiveMemoryCoverageSummary = coordinator.canonicalCoverageSummary
                self.currentLiveMemoryPartialPublication = coordinator.isPartialRecoveryPublication
                self.renderLiveMemoryCaptureState(state)
                self.releaseLiveMemoryCaptureCoordinatorIfSafe(
                    coordinator,
                    coordinatorID: coordinatorID
                )
            }
        }
        coordinator.onRecoveryBackpressureStop = { [weak self, weak coordinator] in
            guard let self, let coordinator,
                  self.liveMemoryCaptureCoordinator === coordinator else { return }
            self.beginRecoveryGracefulStop(coordinator)
            let notice = UIAlertController(title: "先休息一下", message:
                "我们聊了不少，我这边整理有些跟不上了。我们先休息一下，我把已经收到的内容整理好，再继续聊。", preferredStyle: .alert)
            notice.addAction(UIAlertAction(title: "好的", style: .default))
            if self.presentedViewController == nil { self.present(notice, animated: true) }
        }
        coordinator.onCoverageSummaryChange = { [weak self, weak coordinator] summary in
            DispatchQueue.main.async {
                guard let self, let coordinator,
                      self.currentLiveMemoryCapturePresentationCoordinatorID == coordinatorID else {
                    return
                }
                let state = coordinator.state
                self.currentLiveMemoryCapturePresentationState = state
                self.currentLiveMemoryCoverageSummary = summary
                self.renderLiveMemoryCaptureState(state)
                self.releaseLiveMemoryCaptureCoordinatorIfSafe(
                    coordinator,
                    coordinatorID: coordinatorID
                )
            }
        }
        coordinator.onCaptureOwnershipReleaseEligibilityChange = {
            [weak self, weak coordinator] in
            DispatchQueue.main.async {
                guard let self, let coordinator,
                      self.retainedLiveMemoryCaptureCoordinators[coordinatorID] === coordinator else {
                    return
                }
                self.releaseLiveMemoryCaptureCoordinatorIfSafe(
                    coordinator,
                    coordinatorID: coordinatorID
                )
            }
        }
        if asActive {
            currentLiveMemoryCapturePresentationCoordinatorID = coordinatorID
            presentedLiveMemoryProductSessionID = coordinator.trackedProductSessionID
            presentedLiveMemoryAccountLease = echoAccountLease
            activeLiveMemoryRecoveryCoordinator = nil
            PrivacySafeDiagnostics.log(
                subsystem: "EchoLiveMemoryRecovery",
                event: "uiOwnerSelected",
                states: ["source": "activeCapture"],
                correlations: [
                    "workflow": PrivacySafeDiagnostics.correlationHash(
                        coordinator.trackedProductSessionID
                    ),
                ]
            )
            liveMemoryCaptureCoordinator = coordinator
            replaceCanonicalTranscriptIngress(
                EchoCanonicalTranscriptIngress(
                    coordinator: coordinator,
                    scheduler: canonicalTranscriptDeliveryScheduler
                )
            )
            updateOwnerTruthInterviewNaturalInputProductEntryVisibility()
        }
        retainedLiveMemoryCaptureCoordinators[coordinatorID] = coordinator
    }

    private func releaseLiveMemoryCaptureCoordinatorIfSafe(
        _ coordinator: EchoLiveMemoryCaptureCoordinator,
        coordinatorID: UUID
    ) {
        guard coordinator.canReleaseCaptureOwnership,
              retainedLiveMemoryCaptureCoordinators[coordinatorID] === coordinator else {
            return
        }
        if liveMemoryCaptureCoordinator === coordinator {
            closeCanonicalTranscriptIngress()
            liveMemoryCaptureCoordinator = nil
            updateOwnerTruthInterviewNaturalInputProductEntryVisibility()
        }
        coordinator.releaseCaptureOwnership()
        retainedLiveMemoryCaptureCoordinators[coordinatorID] = nil
    }

    private func replaceCanonicalTranscriptIngress(
        _ ingress: EchoCanonicalTranscriptIngress?
    ) {
        canonicalTranscriptIngressLock.lock()
        let previous = canonicalTranscriptIngress
        canonicalTranscriptIngress = ingress
        canonicalTranscriptIngressLock.unlock()
        previous?.close()
    }

    private func currentCanonicalTranscriptIngress() -> EchoCanonicalTranscriptIngress? {
        canonicalTranscriptIngressLock.lock()
        defer { canonicalTranscriptIngressLock.unlock() }
        return canonicalTranscriptIngress
    }

    private func closeCanonicalTranscriptIngress() {
        canonicalTranscriptIngressLock.lock()
        let ingress = canonicalTranscriptIngress
        canonicalTranscriptIngress = nil
        canonicalTranscriptIngressLock.unlock()
        ingress?.close()
    }

    private func retainLiveMemoryRecoveryCoordinator(
        _ coordinator: EchoLiveMemoryRecoveryCoordinator
    ) {
        let coordinatorID = coordinator.id
        if presentedLiveMemoryProductSessionID == nil {
            presentedLiveMemoryProductSessionID = coordinator.trackedProductSessionID
            presentedLiveMemoryAccountLease = coordinator.plan.accountLease
            PrivacySafeDiagnostics.log(
                subsystem: "EchoLiveMemoryRecovery",
                event: "uiOwnerSelected",
                states: ["source": "readOnlyRecovery"],
                correlations: [
                    "workflow": PrivacySafeDiagnostics.correlationHash(
                        coordinator.trackedProductSessionID
                    ),
                ]
            )
        }
        guard retainedLiveMemoryRecoveryCoordinators[coordinatorID] == nil else {
            if !coordinator.state.isTerminal && ownsLiveMemoryPresentation(coordinator) {
                activeLiveMemoryRecoveryCoordinator = coordinator
                updateOwnerTruthInterviewNaturalInputProductEntryVisibility()
            }
            coordinator.start()
            return
        }
        retainedLiveMemoryRecoveryCoordinators[coordinatorID] = coordinator
        let token = coordinator.subscribe { [weak self, weak coordinator] state in
            DispatchQueue.main.async {
                guard let self, let coordinator,
                      self.retainedLiveMemoryRecoveryCoordinators[coordinatorID] === coordinator,
                      self.echoAccountLease == coordinator.plan.accountLease else {
                    return
                }
                let ownsPresentation = self.ownsLiveMemoryPresentation(coordinator)
                if ownsPresentation {
                    self.renderLiveMemoryRecoveryState(state)
                } else {
                    PrivacySafeDiagnostics.log(
                        subsystem: "EchoLiveMemoryRecovery",
                        event: "uiCallbackDropped",
                        states: ["reason": "differentScene"],
                        correlations: [
                            "workflow": PrivacySafeDiagnostics.correlationHash(
                                coordinator.trackedProductSessionID
                            ),
                        ]
                    )
                }
                if state.isTerminal {
                    if self.activeLiveMemoryRecoveryCoordinator === coordinator {
                        self.activeLiveMemoryRecoveryCoordinator = nil
                    }
                    if let token = self.liveMemoryRecoverySubscriptionTokens.removeValue(
                        forKey: coordinatorID
                    ) {
                        coordinator.unsubscribe(token)
                    }
                    self.retainedLiveMemoryRecoveryCoordinators[coordinatorID] = nil
                } else if ownsPresentation {
                    self.activeLiveMemoryRecoveryCoordinator = coordinator
                }
                if ownsPresentation {
                    self.updateOwnerTruthInterviewNaturalInputProductEntryVisibility()
                }
            }
        }
        liveMemoryRecoverySubscriptionTokens[coordinatorID] = token
        coordinator.start()
    }

    private func ownsLiveMemoryPresentation(
        _ coordinator: EchoLiveMemoryRecoveryCoordinator
    ) -> Bool {
        presentedLiveMemoryProductSessionID == coordinator.trackedProductSessionID
            && presentedLiveMemoryAccountLease == coordinator.plan.accountLease
    }

    private func detachLiveMemoryRecoveryObservers() {
        releaseLiveMemoryRecoveryObservers(suspendsCoordinators: true)
    }

    private func releaseLiveMemoryRecoveryObservers(suspendsCoordinators: Bool) {
        for (coordinatorID, coordinator) in retainedLiveMemoryRecoveryCoordinators {
            if let token = liveMemoryRecoverySubscriptionTokens[coordinatorID] {
                coordinator.unsubscribe(token)
            }
            if suspendsCoordinators {
                coordinator.suspend()
            }
        }
        liveMemoryRecoverySubscriptionTokens.removeAll()
        retainedLiveMemoryRecoveryCoordinators.removeAll()
        activeLiveMemoryRecoveryCoordinator = nil
    }

    private func resumePendingLiveMemoryOrganizationsIfNeeded() {
        guard let accountLease = echoAccountLease,
              validateEchoAccountLease(
                at: .request,
                expected: accountLease,
                reason: "resumeLiveMemoryOrganizations"
              ) else {
            return
        }
        // New-protocol queues have explicit original-message replay authority.
        // They must not enter the legacy read-only end/admit recovery lane.
        let recoverySnapshots = OwnerTruthInterviewLiveTurnOutboxStore.shared.snapshots(for: accountLease)
            .filter { $0.acceptedRecoveryProtocol == "live-recovery-v1" }
        let recoveryIDs = Set(recoverySnapshots.map(\.productSessionID))
        let existing = Set(retainedLiveMemoryCaptureCoordinators.values.map(\.trackedProductSessionID))
        let foregroundCycleID = UUID()
        for snapshot in recoverySnapshots.filter({ !existing.contains($0.productSessionID)
            && (!$0.pendingTurns.isEmpty || $0.recoveryProgress?.publication == nil
                || $0.recoveryProgress?.publication?.state == "pending") }).prefix(2) {
            _ = try? OwnerTruthInterviewLiveTurnOutboxStore.shared.beginForegroundRecoveryCycle(
                id: foregroundCycleID, for: accountLease, productSessionID: snapshot.productSessionID)
            let coordinator = EchoLiveMemoryCaptureCoordinator(accountLease: accountLease,
                productSessionID: snapshot.productSessionID, recoveryEnabled: true,
                naturalInputPolicyAvailable: { FeatureGateService.shared.requestServerPolicyManagedDecision(for: .echoTextInput).allowed },
                naturalInputPolicyRefresh: { done in FeatureGateService.shared.refreshPolicy(for: .echoTextInput) { done((try? $0.get()) != nil) } },
                candidateReviewPolicyAvailable: { FeatureGateService.shared.requestServerPolicyManagedDecision(for: .ownerTruthCandidateReview).allowed },
                candidateReviewPolicyRefresh: { done in FeatureGateService.shared.refreshPolicy(for: .ownerTruthCandidateReview) { done((try? $0.get()) != nil) } })
            retainLiveMemoryCaptureCoordinator(coordinator, asActive: false)
            // An unclosed queue discovered after a process restart is an old
            // scene, not a newly opened microphone. Persist its close intent.
            coordinator.finish()
        }
        let trackedProductSessionIDs = Set(
            retainedLiveMemoryCaptureCoordinators.values.map(\.trackedProductSessionID)
        ).union(retainedLiveMemoryRecoveryCoordinators.values.map(\.trackedProductSessionID)).union(recoveryIDs)
        let result = EchoLiveMemoryRecoveryService().resumePendingWorkflows(
            accountLease: accountLease,
            excluding: trackedProductSessionIDs,
            client: liveMemoryRecoveryReadClient,
            naturalInputPolicyAvailable: {
                FeatureGateService.shared
                    .requestServerPolicyManagedDecision(for: .echoTextInput)
                    .allowed
            },
            candidateReviewPolicyAvailable: {
                FeatureGateService.shared
                    .requestServerPolicyManagedDecision(for: .ownerTruthCandidateReview)
                    .allowed
            }
        )
        presentLiveMemoryRecoveryResult(result, accountLease: accountLease)
    }

    private func presentLiveMemoryRecoveryResult(
        _ result: EchoLiveMemoryRecoveryResult,
        accountLease: AccountLease
    ) {
        if let blocked = result.presentationBlockedRecord,
           liveMemoryCaptureCoordinator == nil {
            presentedLiveMemoryProductSessionID = blocked.productSessionID
            presentedLiveMemoryAccountLease = accountLease
            activeLiveMemoryRecoveryCoordinator = nil
            renderLiveMemoryRecoveryState(.contractBlocked(.bindingMismatch))
        }
        for coordinator in result.coordinators {
            retainLiveMemoryRecoveryCoordinator(coordinator)
        }
        for record in result.blockedRecords {
            PrivacySafeDiagnostics.log(
                subsystem: "EchoLiveMemory",
                event: "recoveryBlocked",
                states: ["reason": record.reason.rawValue],
                correlations: [
                    "workflow": PrivacySafeDiagnostics.correlationHash(record.productSessionID),
                ]
            )
        }
    }

    private var liveMemoryRecoveryReadClient: OwnerTruthInterviewCandidateProposalStatusClient {
        #if UI_QA_SIMULATOR && targetEnvironment(simulator)
        if QALaunchConfiguration.shared.contains("DJRunEchoLiveMemoryColdStartRecoverySmoke"),
           QALaunchConfiguration.shared.value(forPrefix: "DJB6ColdStartPhase=") == "recover" {
            if let accountLease = echoAccountLease {
                EchoLiveMemoryRecoveryUIQAReadClient.shared.configure(for: accountLease)
            }
            return EchoLiveMemoryRecoveryUIQAReadClient.shared
        }
        #endif
        return DreamJourneyBackendClient.shared
    }

    private func captureLiveOwnerTurn(_ text: String) {
        guard DigitalHumanContextStore.shared.current.isSelfAssistant else { return }
        liveMemoryCaptureCoordinator?.appendOwnerTurn(text)
    }

    private func captureLiveAssistantTurn(_ text: String) {
        guard DigitalHumanContextStore.shared.current.isSelfAssistant else { return }
        liveMemoryCaptureCoordinator?.appendAssistantTurn(text)
    }

    private func finishLiveMemoryCaptureIfNeeded() {
        guard let coordinator = liveMemoryCaptureCoordinator else { return }
        closeCanonicalTranscriptIngress()
        coordinator.finish()
        // The current scene continues to own its drain/close work until the
        // coordinator reports a state that is safe to hand off. Clearing it
        // here allowed a delayed provider callback to lose its original scene
        // and a new Live session to start over the unfinished close.
        updateOwnerTruthInterviewNaturalInputProductEntryVisibility()
    }

    private func finishTypedEchoConversation() {
        guard isTypedEchoConversationOpen else { return }
        pendingMemoryGapHandoff = nil
        finishLiveMemoryCaptureIfNeeded()
        recentEchoConversation.reset()
        finishTypedEchoInteractionState()
        renderVoiceStatus(
            text: "正在整理本次文字对话",
            isVisible: true,
            accessibilityIdentifier: "echoTypedMemoryOrganizing"
        )
    }

    private func finishTypedEchoInteractionState() {
        _ = invalidateDigitalHumanInteraction(reason: "typedEchoConversationFinished")
        activeVoiceInteractionLifecycleToken = nil
        resetEchoViewModelToIdle()
    }

    private func startLiveSessionLimitIfNeeded() {
        guard isUserControlledLiveSessionOpen else { return }
        if liveSessionLimit.closed { liveSessionLimit = EchoLiveSessionLimit() }
        liveSessionLimit.start(now: ProcessInfo.processInfo.systemUptime)
        scheduleLiveSessionLimitTick()
    }

    private func cancelLiveSessionLimit() {
        liveSessionLimitIdentity = UUID()
        liveSessionLimitTimer?.cancel(); liveSessionLimitTimer = nil
        liveSessionLimit.cancel()
        liveFarewellSpeaker?.cancel(); liveFarewellSpeaker = nil
        liveLimitAwaitingReply = false
    }

    private func scheduleLiveSessionLimitTick() {
        liveSessionLimitTimer?.cancel()
        let identity = liveSessionLimitIdentity
        let lease = echoAccountLease
        let session = liveProductSessionID
        let work = DispatchWorkItem { [weak self] in
            guard let self, self.isUserControlledLiveSessionOpen,
                  self.liveSessionLimitIdentity == identity,
                  self.echoAccountLease == lease, self.liveProductSessionID == session,
                  self.validateEchoAccountLease(at: .timer, reason: "liveDurationLimit") else { return }
            self.evaluateLiveSessionLimit()
            if self.isUserControlledLiveSessionOpen { self.scheduleLiveSessionLimitTick() }
        }
        liveSessionLimitTimer = work
        DispatchQueue.main.asyncAfter(deadline: .now() + 1, execute: work)
    }

    private func evaluateLiveSessionLimit() {
        guard isUserControlledLiveSessionOpen else { return }
        let busy = recoveryUserUtteranceActive || liveLimitAwaitingReply
            || hasTencentDigitalHumanProviderSpeechInFlight
            || viewModel.turnPhase != .listening
        applyLiveSessionLimitAction(liveSessionLimit.tick(now: ProcessInfo.processInfo.systemUptime, busy: busy))
    }

    private func applyLiveSessionLimitAction(_ action: EchoLiveSessionLimit.Action) {
        switch action {
        case .none: break
        case .farewell:
            cancelLiveUserInactivityTimeout()
            let text = "我们已经聊了好一会儿，我有点累啦，也想把你刚才说的好好记下来。我们先休息一下，待会儿再聊。"
            renderVoiceStatus(text: text, isVisible: true, accessibilityIdentifier: "echoLiveTenMinuteFarewell")
            // Prevent our own farewell being captured as an Owner utterance.
            let paused = liveLimitPauseForTesting?()
                ?? (ownsCurrentDialogEngineBinding() && DialogEngineManager.shared.pauseRecorder())
            guard paused else {
                stopVoiceCapture(); return
            }
            let identity = liveSessionLimitIdentity
            let session = liveProductSessionID
            let lease = echoAccountLease
            let complete: () -> Void = { [weak self] in
                guard let self, self.liveSessionLimitIdentity == identity,
                      self.liveProductSessionID == session, self.echoAccountLease == lease,
                      self.isUserControlledLiveSessionOpen else { return }
                self.stopVoiceCapture()
            }
            if let playback = liveLimitPlaybackForTesting { playback(text, complete) }
            else {
                let speaker = EchoLiveFarewellSpeaker(); liveFarewellSpeaker = speaker
                speaker.speak(text, completion: complete)
            }
        case .stalledClose:
            renderVoiceStatus(text: "语音暂时未能继续，我先把已收到的内容保存下来，我们稍后再聊。",
                isVisible: true, accessibilityIdentifier: "echoLiveTenMinuteStalledClose")
            stopVoiceCapture()
        case .farewellTimeout:
            stopVoiceCapture()
        }
    }

    private func armLiveUserInactivityTimeout(reason: String) {
        cancelLiveUserInactivityTimeout()
        guard isUserControlledLiveSessionOpen, !isLiveFarewellActive,
              viewModel.turnPhase == .listening else { return }
        liveUserInactivityGeneration &+= 1
        let timerGeneration = liveUserInactivityGeneration
        let accountLease = echoAccountLease
        let lifecycleToken = activeVoiceInteractionLifecycleToken
        let workItem = DispatchWorkItem { [weak self] in
            guard let self,
                  self.isUserControlledLiveSessionOpen,
                  self.echoAccountLease == accountLease,
                  self.activeVoiceInteractionLifecycleToken == lifecycleToken,
                  self.liveUserInactivityGeneration == timerGeneration,
                  self.viewModel.turnPhase == .listening else {
                return
            }
            PrivacySafeDiagnostics.log(
                subsystem: "Echo",
                event: "liveUserInactivityTimeout",
                states: ["reason": reason],
                counts: ["timeoutSeconds": Int(Self.liveUserInactivityTimeout)]
            )
            self.endLiveSessionAfterUserInactivity()
        }
        liveUserInactivityWorkItem = workItem
        DispatchQueue.main.asyncAfter(
            deadline: .now() + Self.liveUserInactivityTimeout,
            execute: workItem
        )
    }

    private func noteLiveUserVoiceActivity(_ text: String, reason: String) {
        guard isUserControlledLiveSessionOpen,
              !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return
        }
        cancelLiveUserInactivityTimeout()
    }

    private func cancelLiveUserInactivityTimeout() {
        liveUserInactivityGeneration &+= 1
        liveUserInactivityWorkItem?.cancel()
        liveUserInactivityWorkItem = nil
    }

    private func endLiveSessionAfterUserInactivity() {
        guard isUserControlledLiveSessionOpen else { return }
        renderVoiceStatus(
            text: "一分钟未检测到语音，正在整理本次对话",
            isVisible: true,
            accessibilityIdentifier: "echoLiveUserInactivityFinishing"
        )
        stopVoiceCapture()
    }

    #if DEBUG
    func configureRedesignedPresentationForTesting(live: Bool, replies: [String]) {
        loadViewIfNeeded()
        isOwnerTruthInterviewNaturalInputProductPolicyPermitted = true
        isUserControlledLiveSessionOpen = live
        for reply in replies { appendTranscript(text: reply, isUser: false) }
        updateOwnerTruthInterviewNaturalInputProductEntryVisibility()
    }
    func renderRedesignedLayoutForTesting(size: CGSize, live: Bool) -> UIImage {
        configureRedesignedPresentationForTesting(live: live, replies: [String(repeating: "今天我们聊到了家人的旅行，还有那些值得记住的小事。", count: 12)])
        view.frame = CGRect(origin: .zero, size: size)
        render(state: live ? .listening : .idle)
        view.setNeedsLayout(); view.layoutIfNeeded()
        let navigation = WarmTabBarView()
        navigation.updateSelection(1)
        navigation.frame = CGRect(x: 24, y: size.height - WarmTabBarView.tabBarHeight - 16,
            width: size.width - 48, height: WarmTabBarView.tabBarHeight)
        view.addSubview(navigation); navigation.layoutIfNeeded()
        defer { navigation.removeFromSuperview() }
        return UIGraphicsImageRenderer(size: size).image { view.layer.render(in: $0.cgContext) }
    }
    var redesignedLayoutFramesForTesting: (reply: CGRect, mic: CGRect, orb: CGRect) {
        (quoteBubble.convert(quoteBubble.bounds, to: view).intersection(conversationContent.frame), micButton.frame, cloudOrb.convert(cloudOrb.bounds, to: view))
    }
    var redesignedPresentationForTesting: (inputHidden: Bool, recordCount: Int, reply: String, hasVerifyButton: Bool) {
        (composer.isHidden, transcriptEntries.count, quoteLabel.text ?? "", ownerTruthInterviewNaturalInputProductEntryButton.superview != nil)
    }
    #endif

    @objc private func finishTextTapped() { finishTypedEchoConversation() }

    @objc private func echoKeyboardChanged(_ notification: Notification) {
        guard !isUserControlledLiveSessionOpen,
              let frame = notification.userInfo?[UIResponder.keyboardFrameEndUserInfoKey] as? CGRect else { return }
        let local = view.convert(frame, from: nil)
        let overlap = max(0, view.bounds.maxY - local.minY)
        keyboardOverlap = overlap
        micButtonBottomConstraint?.constant = -max(WarmTabBarView.tabBarHeight + Self.systemBottomSafeInset + 40, overlap + 12)
        UIView.animate(withDuration: 0.25) { self.view.layoutIfNeeded() }
    }

    @objc private func expandConversationTapped() {
        guard presentedViewController == nil else { return }
        let sheet = UIViewController()
        sheet.title = "本场对话"
        sheet.view.backgroundColor = DJDesignTokens.Color.background
        let text = UITextView()
        text.isEditable = false; text.backgroundColor = .clear
        text.font = UIFontMetrics.default.scaledFont(for: DJDesignTokens.Font.body(17))
        text.adjustsFontForContentSizeCategory = true
        text.textColor = DJDesignTokens.Color.textPrimary
        text.translatesAutoresizingMaskIntoConstraints = false
        sheet.view.addSubview(text)
        NSLayoutConstraint.activate([
            text.topAnchor.constraint(equalTo: sheet.view.safeAreaLayoutGuide.topAnchor, constant: 12),
            text.leadingAnchor.constraint(equalTo: sheet.view.leadingAnchor, constant: 24),
            text.trailingAnchor.constraint(equalTo: sheet.view.trailingAnchor, constant: -24),
            text.bottomAnchor.constraint(equalTo: sheet.view.safeAreaLayoutGuide.bottomAnchor)
        ])
        sheet.navigationItem.rightBarButtonItem = UIBarButtonItem(title: "收起", style: .done,
            target: self, action: #selector(closeConversationSheet))
        if isUserControlledLiveSessionOpen {
            sheet.navigationItem.leftBarButtonItem = UIBarButtonItem(title: "结束 Live", style: .plain,
                target: self, action: #selector(stopFromConversationSheet))
        }
        let nav = UINavigationController(rootViewController: sheet)
        nav.modalPresentationStyle = .pageSheet
        if let presentation = nav.sheetPresentationController {
            presentation.detents = [.medium(), .large()]; presentation.prefersGrabberVisible = true
        }
        conversationSheet = nav; conversationSheetText = text
        refreshConversationSheet()
        present(nav, animated: true)
    }

    private func refreshConversationSheet() {
        guard let textView = conversationSheetText else { return }
        var lines = transcriptEntries.map { ($0.isUser ? "我：\n" : "回响：\n") + $0.text }
        if let pendingAIText, !pendingAIText.isEmpty,
           transcriptEntries.last?.text != pendingAIText { lines.append("回响：\n" + pendingAIText) }
        let offset = textView.contentOffset
        textView.text = lines.isEmpty ? "本场还没有对话记录" : lines.joined(separator: "\n\n")
        textView.setContentOffset(offset, animated: false)
    }
    @objc private func closeConversationSheet() {
        conversationSheet?.dismiss(animated: true)
        conversationSheet = nil; conversationSheetText = nil
    }
    @objc private func stopFromConversationSheet() {
        stopVoiceCapture()
        (conversationSheet as? UINavigationController)?.topViewController?.navigationItem.leftBarButtonItem = nil
    }
    @objc private func showOrganizedMemories() {
        guard !isUserControlledLiveSessionOpen, let lease = echoAccountLease,
              validateEchoAccountLease(at: .ui, expected: lease, reason: "showOrganizedMemories") else { return }
        let controller = OwnerTruthCandidateInboxViewController(accountLease: lease)
        navigationController?.pushViewController(controller, animated: true)
    }

    private func startAutomaticPublicationObservation() {
        publicationDiscoveryTimer?.cancel()
        guard presentationVisible, UIApplication.shared.applicationState == .active,
              DigitalHumanContextStore.shared.current.isSelfAssistant,
              let lease = echoAccountLease,
              validateEchoAccountLease(at: .request, expected: lease, reason: "publicationObservation") else { return }
        guard !publicationDiscoveryInFlight else { return }
        publicationDiscoveryInFlight = true
        presentationPersistenceQueue.async { [weak self] in
            let snapshots = OwnerTruthInterviewLiveTurnOutboxStore.shared.snapshots(for: lease)
                .filter { $0.acceptedRecoveryProtocol == "live-recovery-v1" && $0.isClosing }
                .sorted { $0.createdAt > $1.createdAt }
            DispatchQueue.main.async {
                guard let self else { return }
                self.publicationDiscoveryInFlight = false
                guard self.presentationVisible, UIApplication.shared.applicationState == .active,
                      self.echoAccountLease == lease else { return }
                self.applyPublicationSnapshots(Array(snapshots.prefix(2)), lease: lease)
            }
        }
    }

    private func applyPublicationSnapshots(_ snapshots: [OwnerTruthInterviewLiveTurnOutboxSnapshot], lease: AccountLease) {
        verifyRetainedRecoveryReadOnly()
        let kept = Set(snapshots.map(\.productSessionID))
        for key in Array(publicationObservers.keys) where !kept.contains(key) {
            publicationObservers.removeValue(forKey: key)?.suspend()
        }
        if presentedLiveMemoryProductSessionID == nil, let newest = snapshots.first {
            presentedLiveMemoryProductSessionID = newest.productSessionID
            presentedLiveMemoryAccountLease = lease
        }
        for snapshot in snapshots.prefix(2) {
            let productID = snapshot.productSessionID
            guard let start = snapshot.preparedStartCommand, let vault = OwnerTruthVaultID(lease.vaultId) else { continue }
            if productID == presentedLiveMemoryProductSessionID { observedPublicationSessionID = productID }
            if let existing = publicationObservers[productID] { existing.start(); continue }
            let observer = EchoPublicationObserver(initial: snapshot.recoveryProgress, request: { [weak self] done in
                guard let self, self.presentationVisible, self.echoAccountLease == lease,
                      self.validateEchoAccountLease(at: .request, expected: lease, reason: "publicationRead") else {
                    done(.failure(DreamJourneyBackendClient.ClientError.accountScopeChanged)); return
                }
                let client = DreamJourneyBackendClient.shared
                client.prepareOwnerTruthInterviewNaturalInputAuthentication(accountLease: lease,
                    now: Date.init, minimumValidity: 30) { [weak self] ready in
                    DispatchQueue.main.async {
                        guard let self, ready, self.presentationVisible, self.echoAccountLease == lease,
                              let decision = client.freshOwnerTruthInterviewNaturalInputDecision() else {
                            done(.failure(DreamJourneyBackendClient.ClientError.accountScopeChanged)); return
                        }
                        guard let authority = OwnerTruthInterviewNaturalInputRequestAuthority(featureDecision: decision,
                            accountLease: lease, operationGeneration: 1,
                            diagnosticTraceID: "echo-publication-observation", now: Date()) else {
                            done(.failure(DreamJourneyBackendClient.ClientError.accountScopeChanged)); return
                        }
                        // This action is a read in the server route. Never authorize/replay/close here.
                        client.controlOwnerTruthLiveRecovery(authority: authority, vaultID: vault,
                            sessionID: start.sessionID, generation: 1, action: "status") { result in
                            DispatchQueue.main.async {
                                done(result.flatMap { progress in Result {
                                    guard progress.sessionBinding?.productSessionId == productID,
                                          progress.sessionBinding?.threadId == start.threadID.rawValue,
                                          self.echoAccountLease == lease,
                                          self.validateEchoAccountLease(at: .commit, expected: lease, reason: "publicationCommit") else {
                                        throw DreamJourneyBackendClient.ClientError.accountScopeChanged
                                    }
                                    return progress
                                } })
                            }
                        }
                    }
                }
            })
            observer.onUnavailable = { [weak self] in
                guard let self, self.echoAccountLease == lease,
                      self.presentedLiveMemoryProductSessionID == productID,
                      !self.isUserControlledLiveSessionOpen, !self.isTypedEchoConversationOpen,
                      self.activeVoiceLaunchAttempt?.isActive != true else { return }
                self.currentLiveMemoryCapturePresentationState = .statusUnknown
                self.renderVoiceStatus(text: EchoOrganizationPresentation.capture(.statusUnknown)?.text,
                    isVisible: true, accessibilityIdentifier: "echoLiveMemoryStatusUnknown")
            }
            observer.onProgress = { [weak self] (progress: OwnerTruthLiveRecoveryProgress) in
                guard let self, self.echoAccountLease == lease else { return }
                // The existing store enforces monotonic progress and the original scene binding.
                self.presentationPersistenceQueue.async {
                    do {
                        try OwnerTruthInterviewLiveTurnOutboxStore.shared.saveRecoveryProgress(progress,
                            for: lease, productSessionID: productID)
                    } catch {
                        PrivacySafeDiagnostics.log(subsystem: "EchoPublicationObservation",
                            event: "progressPersistenceFailed", states: ["source": "statusRead"])
                    }
                }
                if self.presentedLiveMemoryProductSessionID == productID,
                   self.presentedLiveMemoryAccountLease == lease {
                    self.renderObservedPublication(progress)
                }
            }
            publicationObservers[productID] = observer
            observer.start()
        }
        // Re-scan only coordinates, so a newly closed scene is picked up without a button.
        let item = DispatchWorkItem { [weak self] in self?.startAutomaticPublicationObservation() }
        publicationDiscoveryTimer = item
        DispatchQueue.main.asyncAfter(deadline: .now() + 15, execute: item)
    }

    private func verifyRetainedRecoveryReadOnly() {
        // Old protocol only. The coordinator coalesces its in-flight read and owns
        // its bounded round; never reset a live round or replay a business write.
        for coordinator in retainedLiveMemoryRecoveryCoordinators.values {
            guard publicationObservers[coordinator.trackedProductSessionID] == nil else { continue }
            switch coordinator.state {
            case .statusUnknown, .waitingForAccount, .waitingForAuthority, .waitingForPolicy:
                coordinator.verifyStatus(startsNewRound: true)
            default: break
            }
        }
    }

    private func renderObservedPublication(_ progress: OwnerTruthLiveRecoveryProgress) {
        guard !isUserControlledLiveSessionOpen, !isTypedEchoConversationOpen,
              activeVoiceLaunchAttempt?.isActive != true else { return }
        let state: EchoLiveMemoryCaptureState
        switch progress.publication?.state {
        case "published": state = .pendingReview
        case "noChange": state = .empty
        case "failed": state = .terminalFailure(code: "recoverySnapshotFailed")
        default: state = .organizing
        }
        guard let presentation = EchoOrganizationPresentation.capture(state, partial: progress.publication?.isPartial == true) else { return }
        lastOrganizationPresentation = presentation
        currentLiveMemoryCapturePresentationState = state
        currentLiveMemoryPartialPublication = progress.publication?.isPartial == true
        let identifier: String
        switch state {
        case .pendingReview: identifier = "echoLiveMemoryPendingReview"
        case .empty: identifier = "echoLiveMemoryEmpty"
        case .terminalFailure: identifier = "echoLiveMemoryTerminalFailure"
        default: identifier = "echoLiveMemoryOrganizing"
        }
        renderVoiceStatus(text: presentation.text, isVisible: true, accessibilityIdentifier: identifier)
        showMemoriesButton.isHidden = state != .pendingReview
    }

    private func renderLiveMemoryCaptureState(_ state: EchoLiveMemoryCaptureState) {
        if let session = observedPublicationSessionID, session == presentedLiveMemoryProductSessionID,
           let progress = publicationObservers[session]?.latest {
            renderObservedPublication(progress)
            return
        }
        guard !isUserControlledLiveSessionOpen else { return }
        showMemoriesButton.isHidden = state != .pendingReview
        switch state {
        case .live:
            break
        case .syncPaused:
            renderVoiceStatus(
                text: "本次对话仍在本机保存，联网后会继续同步",
                isVisible: true,
                accessibilityIdentifier: "echoLiveMemorySyncPaused"
            )
        case .saving:
            renderVoiceStatus(
                text: "正在保存本次对话",
                isVisible: true,
                accessibilityIdentifier: "echoLiveMemorySaving"
            )
        case .coverageGap(let unsealedTurnCount):
            let summary = currentLiveMemoryCoverageSummary
            renderVoiceStatus(
                text: summary.hasPersistedLocalText
                    ? "已保存收到的内容，部分内容尚未完整记录"
                    : "尚无法确认本次内容已完整保存",
                isVisible: true,
                accessibilityIdentifier: "echoLiveMemoryCoverageGap"
            )
            PrivacySafeDiagnostics.log(
                subsystem: "EchoLiveMemory",
                event: "coverageGapPresented",
                states: [
                    "firstGapRole": summary.firstGapRole?.rawValue ?? "none",
                    "firstGapReason": summary.firstGapReason?.rawValue ?? "none",
                    "firstGapIngressKind": summary.firstGapIngressKind?.rawValue ?? "unknown",
                    "hasPersistedLocalText": summary.hasPersistedLocalText ? "true" : "false",
                ],
                counts: [
                    "unsealedTurnCount": unsealedTurnCount,
                    "registeredMembers": summary.registeredMemberCount,
                    "membersWithoutBody": summary.memberWithoutBodyCount,
                    "partialTurns": summary.partialTurnCount,
                    "completeBlockedTurns": summary.completeBlockedTurnCount,
                    "deliveryCount": summary.deliveryCount,
                    "serverConfirmedCount": summary.serverConfirmedCount,
                    "firstGapOrdinal": summary.firstGapOrdinal ?? 0,
                    "firstGapIngressOrdinal": Int(summary.firstGapIngressOrdinal ?? 0),
                ]
            )
        case .queued:
            renderVoiceStatus(
                text: "对话已保存，等待整理",
                isVisible: true,
                accessibilityIdentifier: "echoLiveMemoryQueued"
            )
        case .organizing:
            renderVoiceStatus(
                text: "正在整理本次对话",
                isVisible: true,
                accessibilityIdentifier: "echoLiveMemoryOrganizing"
            )
        case .retryWaiting(let attempt, let maxAttempts):
            renderVoiceStatus(
                text: "整理暂时未完成，正在自动重试（\(attempt)/\(maxAttempts)）",
                isVisible: true,
                accessibilityIdentifier: "echoLiveMemoryRetryWaiting"
            )
        case .pendingReview:
            renderVoiceStatus(
                text: currentLiveMemoryPartialPublication ? "已整理部分内容，仍有少量内容未完成；可在待确认记忆查看" : "已进入待确认记忆，可在记忆档案查看",
                isVisible: true,
                accessibilityIdentifier: "echoLiveMemoryPendingReview"
            )
        case .empty:
            renderVoiceStatus(
                text: "本次没有需要整理的表达",
                isVisible: true,
                accessibilityIdentifier: "echoLiveMemoryEmpty"
            )
        case .statusUnknown:
            renderVoiceStatus(
                text: "暂时无法确认整理状态，联网后会继续查询",
                isVisible: true,
                accessibilityIdentifier: "echoLiveMemoryStatusUnknown"
            )
        case .terminalFailure:
            renderVoiceStatus(
                text: "本次整理失败，原对话已保留，可稍后重试",
                isVisible: true,
                accessibilityIdentifier: "echoLiveMemoryTerminalFailure"
            )
        case .quarantined:
            renderVoiceStatus(
                text: "本次整理需要人工处理，原对话已安全保留",
                isVisible: true,
                accessibilityIdentifier: "echoLiveMemoryQuarantined"
            )
        case .unavailable:
            renderVoiceStatus(
                text: "当前无法继续整理，原对话已保留",
                isVisible: true,
                accessibilityIdentifier: "echoLiveMemoryUnavailable"
            )
        }
    }

    private func renderLiveMemoryRecoveryState(_ state: EchoLiveMemoryRecoveryState) {
        if observedPublicationSessionID == presentedLiveMemoryProductSessionID,
           observedPublicationSessionID != nil { return }
        guard !isUserControlledLiveSessionOpen else { return }
        PrivacySafeDiagnostics.log(
            subsystem: "EchoLiveMemoryRecovery",
            event: "uiCommitted",
            states: ["state": Self.safeLiveMemoryRecoveryStateCode(state)]
        )
        let displayState: EchoLiveMemoryCaptureState
        switch state {
        case .pendingReview: displayState = .pendingReview
        case .empty: displayState = .empty
        case .terminalFailure(let code): displayState = .terminalFailure(code: code)
        case .quarantined: displayState = .quarantined
        case .statusUnknown, .accessBlocked, .contractBlocked, .waitingForAccount, .waitingForAuthority, .waitingForPolicy:
            displayState = .statusUnknown
        default: displayState = .organizing
        }
        defer {
            if let presentation = EchoOrganizationPresentation.capture(displayState) {
                voiceStatusLabel.text = presentation.text
                voiceStatusLabel.accessibilityLabel = presentation.text
                showMemoriesButton.isHidden = displayState != .pendingReview
            }
        }
        switch state {
        case .discovered, .checking:
            renderVoiceStatus(
                text: "正在核实上次对话的整理状态",
                isVisible: true,
                accessibilityIdentifier: "echoLiveMemoryRecoveryChecking"
            )
        case .waitingForAccount, .waitingForAuthority, .waitingForPolicy:
            renderVoiceStatus(
                text: "账号准备完成后将继续核实上次对话",
                isVisible: true,
                accessibilityIdentifier: "echoLiveMemoryRecoveryWaiting"
            )
        case .queued:
            renderVoiceStatus(
                text: "上次对话已保存，等待整理",
                isVisible: true,
                accessibilityIdentifier: "echoLiveMemoryRecoveryQueued"
            )
        case .organizing:
            renderVoiceStatus(
                text: "正在整理上次对话",
                isVisible: true,
                accessibilityIdentifier: "echoLiveMemoryRecoveryOrganizing"
            )
        case .retryWaiting(let attempt, let maxAttempts):
            renderVoiceStatus(
                text: "上次整理正在重试（\(attempt)/\(maxAttempts)）",
                isVisible: true,
                accessibilityIdentifier: "echoLiveMemoryRecoveryRetryWaiting"
            )
        case .statusUnknown:
            renderVoiceStatus(
                text: "暂时无法确认上次整理状态，可再次核实",
                isVisible: true,
                accessibilityIdentifier: "echoLiveMemoryRecoveryStatusUnknown"
            )
        case .actionRequired(let phase):
            let text: String
            if phase == .acknowledged {
                text = "上次对话已保存，尚未确认开始整理，可再次核实"
            } else if phase == .ended {
                text = "上次对话已保存，尚未完成关闭确认，可再次核实"
            } else {
                text = "上次对话尚未完成关闭，原记录已保留"
            }
            renderVoiceStatus(
                text: text,
                isVisible: true,
                accessibilityIdentifier: "echoLiveMemoryRecoveryActionRequired"
            )
        case .accessBlocked:
            renderVoiceStatus(
                text: "当前账号暂时无法核实上次整理状态",
                isVisible: true,
                accessibilityIdentifier: "echoLiveMemoryRecoveryAccessBlocked"
            )
        case .contractBlocked:
            renderVoiceStatus(
                text: "上次整理记录无法安全核对，原记录已保留",
                isVisible: true,
                accessibilityIdentifier: "echoLiveMemoryRecoveryContractBlocked"
            )
        case .pendingReview:
            renderVoiceStatus(
                text: "上次对话已进入待确认记忆",
                isVisible: true,
                accessibilityIdentifier: "echoLiveMemoryRecoveryPendingReview"
            )
        case .empty:
            renderVoiceStatus(
                text: "上次对话没有需要整理的表达",
                isVisible: true,
                accessibilityIdentifier: "echoLiveMemoryRecoveryEmpty"
            )
        case .terminalFailure:
            renderVoiceStatus(
                text: "上次整理失败，原对话已保留",
                isVisible: true,
                accessibilityIdentifier: "echoLiveMemoryRecoveryTerminalFailure"
            )
        case .quarantined:
            renderVoiceStatus(
                text: "上次整理需要人工处理，原对话已保留",
                isVisible: true,
                accessibilityIdentifier: "echoLiveMemoryRecoveryQuarantined"
            )
        }
    }

    private static func safeLiveMemoryRecoveryStateCode(
        _ state: EchoLiveMemoryRecoveryState
    ) -> String {
        switch state {
        case .discovered: return "discovered"
        case .waitingForAccount: return "waitingForAccount"
        case .waitingForAuthority: return "waitingForAuthority"
        case .waitingForPolicy: return "waitingForPolicy"
        case .checking: return "checking"
        case .queued: return "queued"
        case .organizing: return "organizing"
        case .retryWaiting: return "retryWaiting"
        case .statusUnknown: return "statusUnknown"
        case .actionRequired: return "actionRequired"
        case .accessBlocked: return "accessBlocked"
        case .contractBlocked: return "contractBlocked"
        case .pendingReview: return "pendingReview"
        case .empty: return "empty"
        case .terminalFailure: return "terminalFailure"
        case .quarantined: return "quarantined"
        }
    }

    private func startVoiceCapture() {
        guard let accountLease = echoAccountLease,
              validateEchoAccountLease(
                at: .request,
                expected: accountLease,
                reason: "startVoiceCapture"
              ),
              bindDialogEngineToEchoAccountLease(reason: "startVoiceCapture") else {
            viewModel.fail("账号状态已变化，请重新进入回响")
            return
        }
        if activeVoiceLaunchAttempt?.isActive == true { return }
        let launchAttempt = EchoVoiceLaunchAttempt(
            ownerID: accountLease.subjectId,
            accountLease: accountLease,
            initialCaptureID: liveMemoryCaptureCoordinator?.id,
            initialAudioLeaseID: activeEchoAudioOwnerLease?.leaseId,
            timeout: voiceLaunchTimeout,
            now: voiceLaunchClock,
            scheduleTimeout: voiceLaunchScheduler,
            store: voiceLaunchDiagnosticStore
        )
        activeVoiceLaunchAttempt = launchAttempt
        launchAttempt.note(.permissionStart)
        currentLiveMemoryCapturePresentationState = nil
        currentLiveMemoryCoverageSummary = .empty
        currentLiveMemoryCapturePresentationCoordinatorID = nil
        let lifecycleToken = invalidateDigitalHumanInteraction(reason: "userStartedVoiceCapture")
        activeVoiceInteractionLifecycleToken = lifecycleToken
        #if DEBUG
        let requestPermission = voicePermissionRequestForTesting
            ?? MicrophonePermissionManager.shared.requestPermission
        #else
        let requestPermission = MicrophonePermissionManager.shared.requestPermission
        #endif
        requestPermission { [weak self] granted in
            guard let self = self else { return }
            DispatchQueue.main.async {
                guard self.activeVoiceLaunchAttempt === launchAttempt,
                      launchAttempt.isActive else { return }
                guard launchAttempt.claimPermissionResponse() else { return }
                guard self.validateEchoAccountLease(
                    at: .ui,
                    expected: accountLease,
                    reason: "microphonePermissionResponse"
                ),
                self.ownsCurrentDialogEngineBinding(),
                self.isCurrentDigitalHumanLifecycleToken(
                    lifecycleToken,
                    reason: "microphonePermissionResponse"
                ) else {
                    return
                }
                guard granted else {
                    launchAttempt.finish("permissionDenied")
                    self.activeVoiceLaunchAttempt = nil
                    self.isUserControlledLiveSessionOpen = false
                    self.activeVoiceInteractionLifecycleToken = nil
                    MicrophonePermissionManager.shared.showPermissionDeniedAlert(on: self)
                    self.viewModel.fail("需要麦克风权限，才能听见您的声音")
                    return
                }
                launchAttempt.note(.permissionEnd)
                launchAttempt.beginBudget { [weak self, weak launchAttempt] in
                    DispatchQueue.main.async {
                        guard let self, let launchAttempt,
                              self.activeVoiceLaunchAttempt === launchAttempt else { return }
                        guard self.validateEchoAccountLease(
                            at: .timer, expected: accountLease, reason: "voiceLaunchDeadline"
                        ) else {
                            self.handleBlockedRealtimeVoice(
                                reason: "accountLeaseInvalid", launchAttempt: launchAttempt
                            )
                            return
                        }
                        self.handleBlockedRealtimeVoice(
                            reason: "voiceLaunchTimeout", launchAttempt: launchAttempt
                        )
                    }
                }
                DialogEngineManager.shared.delegate = self
                if !self.isUserControlledLiveSessionOpen {
                    self.recentEchoConversation.reset()
                }
                self.isUserControlledLiveSessionOpen = true
                self.isLiveVoiceTransportSuspended = false
                self.pendingAIText = nil
                self.resetDigitalHumanReplyDispatchState()
                self.viewModel.prepareVoiceInteraction()
                if self.prepareTencentProviderForUserCaptureIfNeeded() {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) { [weak self] in
                        guard let self,
                              self.validateEchoAccountLease(
                                at: .timer,
                                expected: accountLease,
                                reason: "providerCaptureHandoff"
                              ),
                              self.isCurrentDigitalHumanLifecycleToken(
                                lifecycleToken,
                                reason: "providerCaptureHandoff"
                              ) else { return }
                        self.configureVoiceRuntimeThenStart(
                            lifecycleToken: lifecycleToken, launchAttempt: launchAttempt
                        )
                    }
                } else {
                    self.configureVoiceRuntimeThenStart(
                        lifecycleToken: lifecycleToken, launchAttempt: launchAttempt
                    )
                }
            }
        }
    }

    private func bindDigitalHumanRuntimeState(
        _ runtime: DigitalHumanRuntime,
        lifecycleToken: DigitalHumanLifecycleToken,
        runtimeSessionCallback: EchoRuntimeCallbackToken? = nil
    ) {
        runtime.onStateChange = { [weak self, weak runtime] state in
            DispatchQueue.main.async {
                guard let self,
                      runtime === self.digitalHumanRuntime,
                      self.digitalHumanRuntimeLifecycleGeneration == lifecycleToken.generation,
                      self.isCurrentDigitalHumanSessionToken(
                        lifecycleToken,
                        reason: "runtimeStateChange"
                      ),
                      self.isCurrentEchoRuntimeSessionCallback(
                        runtimeSessionCallback,
                        reason: "runtimeStateChange"
                      ) else {
                    return
                }
                self.handleDigitalHumanRuntimeStateChange(state)
            }
        }
    }

    private func handleDigitalHumanRuntimeStateChange(_ state: DigitalHumanSessionState) {
        guard !viewModel.isNeutralSafetyMode else {
            stopDigitalHumanAudioLevelMetering()
            return
        }
        switch state {
        case .speaking(let requestID):
            guard digitalHumanConversation.activeRequestID == requestID else {
                PrivacySafeDiagnostics.log(
                    subsystem: "TencentDigitalHuman",
                    event: "providerSpeakingIgnored",
                    states: ["reason": "requestMismatch"],
                    correlations: [
                        "activeRequest": digitalHumanConversation.activeRequestID,
                        "providerRequest": requestID,
                    ]
                )
                return
            }
            if shouldTraceTrueDeviceBackendPCMDrive {
                trueDeviceBackendPCMDriveTrace.providerSpeakingObserved = true
            }
            guard acquireEchoRuntimeAudioOwner(
                .tencentDigitalHumanPlayback,
                priority: .tencentDigitalHumanPlayback,
                reason: "digitalHumanRuntimeSpeaking"
            ) else {
                degradeTencentDigitalHumanRoute(reason: "audioSessionCoordinatorActivationFailed")
                return
            }
            acknowledgeLivePlaybackStarted(route: .tencentDigitalHuman)
            digitalHumanLivePanelView?.setInteractionState(.speaking)
            if case .speaking = currentState {
                renderVoiceStatus(text: "腾讯数智人正在回响", isVisible: true)
            }
        case .completed(let requestID):
            guard completeLivePlaybackReceipt(route: .tencentDigitalHuman) else {
                return
            }
            completeTencentDigitalHumanReplyIfNeeded(requestID: requestID)
        case .ready:
            cancelDigitalHumanRuntimeRecovery()
            digitalHumanRuntimeRecoveryAttemptsByContext[currentDigitalHumanRuntimeContextKey()] = 0
            applyEchoAudioRoutePolicy()
            runTencentDigitalHumanTextDriveSmokeIfNeeded(trigger: "runtimeReady")
            runTencentDigitalHumanPCMDriveSmokeIfNeeded(trigger: "runtimeReady")
            runTencentDigitalHumanBackendPCMDriveSmokeIfNeeded(trigger: "runtimeReady")
        case .interrupting, .closed:
            releaseEchoAudioOwnerLease(
            expectedOwner: .tencentDigitalHumanPlayback,
            reason: "digitalHumanRuntimeStopped"
            )
            stopDigitalHumanAudioLevelMetering()
        case .failed(let code):
            degradeTencentDigitalHumanRoute(reason: code)
        default:
            break
        }
    }

    @discardableResult
    private func prepareTencentProviderForUserCaptureIfNeeded() -> Bool {
        guard tencentDigitalHumanAudioRouteReserved,
              let digitalHumanRuntime,
              digitalHumanRuntime is TencentDigitalHumanCloudRuntime else {
            return false
        }

        cancelDigitalHumanReplyPrewarm()
        cancelTencentDigitalHumanTextOverTimeout()
        digitalHumanConversation.clearProviderRequestAndResumeState()
        stopDigitalHumanAudioLevelMetering()
        (digitalHumanRuntime as? TencentDigitalHumanCloudRuntime)?.setRemoteAudioMuted(true)
        digitalHumanRuntime.interrupt()
        releaseEchoAudioOwnerLease(
            expectedOwner: .tencentDigitalHumanPlayback,
            reason: "prepareUserCapture"
        )
        setEchoAudioOwner(.fallbackMuted, reason: "prepareUserCapture")
        print("[TencentDigitalHuman] muted provider audio before user capture; provider view preserved")
        return true
    }

    private func degradeTencentDigitalHumanRoute(reason: String) {
        let isQuotaFailure = isDigitalHumanQuotaFailure(reason)
        cancelLivePlaybackReceipt(reason: "digitalHumanRouteFailure")
        if scopedActiveLiveAudioRoute == .tencentDigitalHuman {
            markPinnedLiveAudioRouteUnavailable(reason: reason)
        }
        let shouldRecover = !isQuotaFailure
            && shouldRecoverFromDigitalHumanRuntimeFailure(reason: reason)
        invalidateDigitalHumanLifecycle(reason: "routeFailure:\(reason)")
        activeVoiceInteractionLifecycleToken = nil
        digitalHumanConversation.clearForRouteFailure()
        lastEchoRuntimeFallbackReason = reason
        let message = shouldRecover
            ? (
                detail: "数字人正在重新连接，请稍候",
                panel: "正在重新连接数字人"
            )
            : digitalHumanRouteFailureMessage(for: reason)
        digitalHumanStatusDetailLabel.text = message.detail
        releaseDigitalHumanRuntime(
            reason: "routeFailure:\(reason)",
            resetsAudioOwnerToOrdinaryEcho: true,
            removeProviderViewMessage: message.panel
        )
        if shouldRecover {
            scheduleCloudDigitalHumanRuntimeRecovery(
                reason: "runtimeFailure:\(reason)",
                delay: Self.tencentDigitalHumanOpenFailureRecoveryDelay
            )
        }
        PrivacySafeDiagnostics.log(
            subsystem: "TencentDigitalHuman",
            event: "routeFallback",
            states: ["reason": reason],
            correlations: ["turn": digitalHumanConversation.currentTurnID]
        )
    }

    private func digitalHumanRouteFailureMessage(for reason: String) -> (detail: String, panel: String) {
        if isDigitalHumanQuotaFailure(reason) {
            return (
                detail: "腾讯数智人并发配额已满，已回到普通回响",
                panel: "数智人配额已满"
            )
        }
        return (
            detail: "数字人声音暂不可用，已回到普通回响",
            panel: "数字人暂不可用"
        )
    }

    private func completeTencentDigitalHumanReplyIfNeeded(requestID: String) {
        guard routeEchoAudioThroughDigitalHuman,
              let completion = digitalHumanConversation.completeProviderRequest(matching: requestID) else {
            PrivacySafeDiagnostics.log(
                subsystem: "TencentDigitalHuman",
                event: "providerCompletionIgnored",
                states: ["reason": "requestMismatchOrNoActiveRequest"],
                correlations: [
                    "activeRequest": digitalHumanConversation.activeRequestID,
                    "providerRequest": requestID,
                ]
            )
            return
        }

        let resumeDelay = tencentDigitalHumanDialogResumeDelay(for: completion.replyText)
        let lifecycleToken = captureDigitalHumanLifecycleToken(reason: "providerTextOver")
        cancelTencentDigitalHumanTextOverTimeout()
        echoRuntimeSessionCoordinator.finishInteraction()
        let runtimeSessionCallback = echoRuntimeSessionCoordinator.currentSessionCallbackToken()
        stopDigitalHumanAudioLevelMetering()
        releaseEchoAudioOwnerLease(
            expectedOwner: .tencentDigitalHumanPlayback,
            reason: "providerPlaybackCompleted"
        )
        markEchoReplyDelivered()
        if shouldTraceTrueDeviceBackendPCMDrive,
           trueDeviceBackendPCMDriveTrace.requestID == completion.requestID {
            trueDeviceBackendPCMDriveTrace.providerPlaybackCompleted = true
            emitTencentBackendPCMDriveTrueDeviceQAResult(reason: "providerPlaybackCompleted")
        }
        PrivacySafeDiagnostics.log(
            subsystem: "TencentDigitalHuman",
            event: "providerPlaybackCompleted",
            counts: [
                "resumeDelayMs": Int(resumeDelay * 1_000),
                "textLength": completion.replyText?.count ?? 0,
            ],
            correlations: [
                "request": completion.requestID,
                "turn": completion.turnID,
            ]
        )
        DispatchQueue.main.asyncAfter(deadline: .now() + resumeDelay) { [weak self] in
            guard let self,
                  self.isCurrentDigitalHumanLifecycleToken(
                    lifecycleToken,
                    reason: "providerTextOverResume"
                  ),
                  self.isCurrentEchoRuntimeSessionCallback(
                    runtimeSessionCallback,
                    reason: "providerTextOverResume"
                  ) else { return }
            if self.resumeDialogEngineAfterTencentProviderSpeechIfNeeded(
                reason: "providerTextOver",
                lifecycleToken: lifecycleToken
            ) {
                self.armLiveUserInactivityTimeout(reason: "providerTextOverResume")
                return
            }
            if DialogEngineManager.shared.isDialogActive {
                self.viewModel.beginVoiceInteraction()
                self.armLiveUserInactivityTimeout(reason: "providerTextOverResume")
            } else {
                self.resetEchoViewModelToIdle()
            }
        }
    }

    private func runTencentDigitalHumanTextDriveSmokeIfNeeded(trigger: String) {
        guard shouldRunTencentDigitalHumanTextDriveSmoke,
              !hasRunTencentDigitalHumanTextDriveSmoke,
              routeEchoAudioThroughDigitalHuman,
              digitalHumanRuntime?.profile != nil,
              digitalHumanConversation.activeRequestID == nil else {
            return
        }
        hasRunTencentDigitalHumanTextDriveSmoke = true
        let text = "真机数字人文本驱动测试。请用腾讯数智人说出这句话。"
        viewModel.prepareVoiceInteraction()
        guard viewModel.receiveAIReply(text) else {
            PrivacySafeDiagnostics.log(
                subsystem: "TencentDigitalHuman",
                event: "textDriveSmokeReplyRejected",
                states: ["reason": "turnIntentRejected"]
            )
            return
        }
        sendEchoReplyToDigitalHumanRuntimeIfReady(text, source: "trueDeviceTextDriveSmoke")
        PrivacySafeDiagnostics.log(
            subsystem: "TencentDigitalHuman",
            event: "textDriveSmokeTriggered",
            states: ["trigger": trigger]
        )
    }

    private func runTencentDigitalHumanPCMDriveSmokeIfNeeded(trigger: String) {
        guard shouldRunTencentDigitalHumanPCMDriveSmoke,
              !hasRunTencentDigitalHumanPCMDriveSmoke,
              routeEchoAudioThroughDigitalHuman,
              digitalHumanRuntime?.profile != nil,
              digitalHumanConversation.activeRequestID == nil else {
            return
        }

        hasRunTencentDigitalHumanPCMDriveSmoke = true
        let text = "腾讯音频驱动 POC：正在用本地标准 PCM 测试声音和口型。"
        viewModel.prepareVoiceInteraction()
        guard viewModel.receiveAIReply(text) else {
            PrivacySafeDiagnostics.log(
                subsystem: "TencentDigitalHuman",
                event: "pcmDriveSmokeReplyRejected",
                states: ["reason": "turnIntentRejected"]
            )
            return
        }
        sendPCMDriveTestSignalToDigitalHumanRuntime(
            source: "trueDevicePCMDriveSmoke",
            replyText: text
        )
        PrivacySafeDiagnostics.log(
            subsystem: "TencentDigitalHuman",
            event: "pcmDriveSmokeTriggered",
            states: ["trigger": trigger]
        )
    }

    private func runTencentDigitalHumanBackendPCMDriveSmokeIfNeeded(trigger: String) {
        guard shouldRunTencentDigitalHumanBackendPCMDriveSmoke,
              !hasRunTencentDigitalHumanBackendPCMDriveSmoke,
              routeEchoAudioThroughDigitalHuman,
              digitalHumanRuntime?.profile != nil,
              digitalHumanConversation.activeRequestID == nil else {
            return
        }

        hasRunTencentDigitalHumanBackendPCMDriveSmoke = true
        viewModel.prepareVoiceInteraction()
        trueDeviceBackendPCMDriveTrace.begin(
            trigger: trigger,
            voiceProfileId: tencentBackendPCMDriveVoiceProfileId ?? "",
            outputMode: "tencentAudioDrive"
        )
        guard DreamJourneyBackendClient.shared.isVoiceCloneSynthesisConfigured else {
            let message = "后端复刻合成未配置，无法运行腾讯数智人 PCM 真机链路。"
            viewModel.receiveAIReply(message)
            trueDeviceBackendPCMDriveTrace.markFailure(
                reason: "backendNotConfigured",
                detail: "DreamJourneyBackendClient voice synthesis endpoint is not configured"
            )
            emitTencentBackendPCMDriveTrueDeviceQAResult(reason: "backendNotConfigured")
            print("[TencentDigitalHuman][QA] backend PCM-drive smoke failed reason=backendNotConfigured")
            return
        }
        guard let voiceProfileId = tencentBackendPCMDriveVoiceProfileId else {
            let message = "复刻音色未准备好，无法运行腾讯数智人 PCM 真机链路。"
            viewModel.receiveAIReply(message)
            trueDeviceBackendPCMDriveTrace.markFailure(
                reason: "missingVoiceProfileId",
                detail: "No accepted/ready voiceProfileId or launch override was available"
            )
            emitTencentBackendPCMDriveTrueDeviceQAResult(reason: "missingVoiceProfileId")
            print("[TencentDigitalHuman][QA] backend PCM-drive smoke failed reason=missingVoiceProfileId")
            return
        }
        guard let profileVersion = tencentBackendPCMDriveProfileVersion else {
            let message = "复刻音色版本不可用，无法运行腾讯数智人 PCM 真机链路。"
            viewModel.receiveAIReply(message)
            trueDeviceBackendPCMDriveTrace.markFailure(
                reason: "missingVoiceProfileVersion",
                detail: "No accepted profile version or launch override was available"
            )
            emitTencentBackendPCMDriveTrueDeviceQAResult(reason: "missingVoiceProfileVersion")
            print("[TencentDigitalHuman][QA] backend PCM-drive smoke failed reason=missingVoiceProfileVersion")
            return
        }

        let text = tencentBackendPCMDriveText
        let userId = tencentBackendPCMDriveUserId
        renderVoiceStatus(text: "正在请求复刻音频", isVisible: true, accessibilityIdentifier: "echoBackendPCMDriveStatus")
        PrivacySafeDiagnostics.log(
            subsystem: "TencentDigitalHuman",
            event: "backendPCMDriveRequested",
            states: [
                "outputMode": "tencentAudioDrive",
                "trigger": trigger,
            ],
            correlations: [
                "user": userId,
                "voiceProfile": voiceProfileId,
            ]
        )
        DreamJourneyBackendClient.shared.requestVoiceCloneSynthesis(
            userId: userId,
            voiceProfileId: voiceProfileId,
            text: text,
            audioFormat: "wav",
            sampleRate: 16_000,
            speechRate: -10,
            loudnessRate: 10,
            outputMode: "tencentAudioDrive",
            requestPurpose: "echo",
            roleKey: "personalOwner",
            roleSubjectId: userId,
            personaScope: "personal",
            digitalHumanId: userId,
            expectedProfileVersion: profileVersion
        ) { [weak self] result in
            DispatchQueue.main.async {
                guard let self else { return }
                switch result {
                case .success(let synthesis):
                    self.trueDeviceBackendPCMDriveTrace.markSynthesis(synthesis)
                    guard synthesis.isBound(
                        toOwnerUserId: userId,
                        voiceProfileId: voiceProfileId,
                        profileVersion: profileVersion,
                        roleSubjectId: userId,
                        roleKey: "personalOwner",
                        personaScope: "personal",
                        digitalHumanId: userId,
                        requestPurpose: "echo",
                        outputMode: "tencentAudioDrive",
                        audioOwner: "tencentDigitalHuman",
                        textHash: VoiceCloneSynthesisBinding.textHash(for: text)
                    ) else {
                        self.renderVoiceStatus(text: nil, isVisible: false)
                        self.viewModel.receiveAIReply("后端复刻音频与当前音色或文本不匹配，已拒绝播放。")
                        self.trueDeviceBackendPCMDriveTrace.markFailure(
                            reason: "synthesisBindingMismatch",
                            detail: "The synthesis response was not bound to the active profile version and text hash"
                        )
                        self.emitTencentBackendPCMDriveTrueDeviceQAResult(reason: "synthesisBindingMismatch")
                        return
                    }
                    guard synthesis.isTencentAudioDrivePCMCompatible else {
                        self.renderVoiceStatus(text: nil, isVisible: false)
                        self.viewModel.receiveAIReply("后端复刻音频格式不兼容腾讯数智人，已回到普通回响。")
                        self.trueDeviceBackendPCMDriveTrace.markFailure(
                            reason: "incompatibleAudio",
                            detail: "format=\(synthesis.audioFormat),sampleRate=\(synthesis.sampleRate ?? 0),bits=\(synthesis.bitsPerSample ?? 0),channels=\(synthesis.channelCount ?? 0)"
                        )
                        self.emitTencentBackendPCMDriveTrueDeviceQAResult(reason: "incompatibleAudio")
                        print(
                            "[TencentDigitalHuman][QA] backend PCM-drive smoke failed " +
                            "reason=incompatibleAudio format=\(synthesis.audioFormat) " +
                            "sampleRate=\(synthesis.sampleRate ?? 0) bits=\(synthesis.bitsPerSample ?? 0) " +
                            "channels=\(synthesis.channelCount ?? 0)"
                        )
                        return
                    }
                    self.renderVoiceStatus(text: nil, isVisible: false)
                    guard self.viewModel.receiveAIReply(text) else {
                        self.trueDeviceBackendPCMDriveTrace.markFailure(
                            reason: "turnIntentRejected",
                            detail: "Echo reducer rejected the asynchronous synthesis reply"
                        )
                        self.emitTencentBackendPCMDriveTrueDeviceQAResult(reason: "turnIntentRejected")
                        PrivacySafeDiagnostics.log(
                            subsystem: "TencentDigitalHuman",
                            event: "backendPCMDriveReplyRejected",
                            states: ["reason": "turnIntentRejected"]
                        )
                        return
                    }
                    let sent = self.sendTencentAudioDriveSynthesisToDigitalHumanRuntime(
                        synthesis,
                        source: "trueDeviceBackendPCMDriveSmoke",
                        replyText: text
                    )
                    if !sent {
                        self.trueDeviceBackendPCMDriveTrace.markFailure(
                            reason: "sendSynthesisFailed",
                            detail: "makeTencentDigitalHumanPCMDriveSignal returned nil"
                        )
                        self.emitTencentBackendPCMDriveTrueDeviceQAResult(reason: "sendSynthesisFailed")
                    }
                    PrivacySafeDiagnostics.log(
                        subsystem: "TencentDigitalHuman",
                        event: "backendPCMDriveReady",
                        states: ["providerMode": synthesis.providerMode],
                        counts: ["byteCount": synthesis.byteCount],
                        correlations: ["voiceProfile": synthesis.voiceProfileId]
                    )
                case .failure(let error):
                    self.renderVoiceStatus(text: nil, isVisible: false)
                    self.viewModel.receiveAIReply("后端复刻音频请求失败，已回到普通回响。")
                    self.trueDeviceBackendPCMDriveTrace.markFailure(
                        reason: "requestFailed",
                        detail: error.localizedDescription
                    )
                    self.emitTencentBackendPCMDriveTrueDeviceQAResult(reason: "requestFailed")
                    PrivacySafeDiagnostics.log(
                        subsystem: "TencentDigitalHuman",
                        event: "backendPCMDriveFailed",
                        states: ["reason": "requestFailed"]
                    )
                }
            }
        }
    }

    private func sendPCMDriveTestSignalToDigitalHumanRuntime(source: String, replyText: String) {
        let signal = makeTencentDigitalHumanPCMDriveTestSignal()
        sendPCMDriveSignalToDigitalHumanRuntime(
            signal: signal,
            source: source,
            replyText: replyText
        )
    }

    @discardableResult
    private func sendTencentAudioDriveSynthesisToDigitalHumanRuntime(
        _ synthesis: VoiceCloneSynthesisResult,
        source: String,
        replyText: String
    ) -> Bool {
        guard let signal = makeTencentDigitalHumanPCMDriveSignal(from: synthesis) else {
            PrivacySafeDiagnostics.log(
                subsystem: "TencentDigitalHuman",
                event: "backendPCMDriveSkipped",
                states: [
                    "audioFormat": synthesis.audioFormat,
                    "reason": "incompatibleAudioFormat",
                    "source": source,
                ],
                counts: [
                    "bitsPerSample": synthesis.bitsPerSample ?? 0,
                    "channelCount": synthesis.channelCount ?? 0,
                    "sampleRate": synthesis.sampleRate ?? 0,
                ]
            )
            return false
        }
        sendPCMDriveSignalToDigitalHumanRuntime(
            signal: signal,
            source: source,
            replyText: replyText
        )
        return true
    }

    private func makeTencentDigitalHumanPCMDriveSignal(from synthesis: VoiceCloneSynthesisResult) -> TencentPCMDriveTestSignal? {
        guard let data = synthesis.tencentAudioDrivePCMData else {
            return nil
        }
        return TencentPCMDriveTestSignal(
            data: data,
            sampleRate: synthesis.sampleRate ?? 16_000,
            bitsPerSample: synthesis.bitsPerSample ?? 16,
            channelCount: synthesis.channelCount ?? 1,
            formatDescription: "backend pcm16kMono(sampleRate: 16_000,bitsPerSample: 16,channelCount: 1)"
        )
    }

    private func sendPCMDriveSignalToDigitalHumanRuntime(
        signal: TencentPCMDriveTestSignal,
        source: String,
        replyText: String
    ) {
        let lifecycleToken = captureDigitalHumanLifecycleToken(reason: "pcmDrive:\(source)")
        guard shouldShowDigitalHumanLivePanel,
              shouldDispatchEchoReplyToTencentProvider,
              let digitalHumanRuntime,
              digitalHumanRuntime.profile != nil else {
            if source == "trueDeviceBackendPCMDriveSmoke" {
                trueDeviceBackendPCMDriveTrace.markFailure(
                    reason: "runtimeNotReady",
                    detail: "Digital human runtime/profile was not ready"
                )
                emitTencentBackendPCMDriveTrueDeviceQAResult(reason: "runtimeNotReady")
            }
            PrivacySafeDiagnostics.log(
                subsystem: "TencentDigitalHuman",
                event: "pcmDriveSkipped",
                states: [
                    "reason": "runtimeNotReady",
                    "source": source,
                ]
            )
            return
        }
        guard digitalHumanConversation.activeRequestID == nil else {
            if source == "trueDeviceBackendPCMDriveSmoke" {
                trueDeviceBackendPCMDriveTrace.markFailure(
                    reason: "providerBusy",
                    detail: "A Tencent provider request was already active"
                )
                emitTencentBackendPCMDriveTrueDeviceQAResult(reason: "providerBusy")
            }
            PrivacySafeDiagnostics.log(
                subsystem: "TencentDigitalHuman",
                event: "pcmDriveSkipped",
                states: [
                    "reason": "providerBusy",
                    "source": source,
                ]
            )
            return
        }

        let requestID = makeTencentDigitalHumanRequestID()
        let turnID = ensureCurrentEchoTurnID()
        let runtimeInteractionCallback = beginEchoRuntimeInteraction(
            requestID: requestID,
            turnID: turnID,
            source: source
        )
        guard runtimeInteractionCallback != nil || !requiresEchoRuntimeInteractionLease else {
            if source == "trueDeviceBackendPCMDriveSmoke" {
                trueDeviceBackendPCMDriveTrace.markFailure(
                    reason: "runtimeInteractionLeaseUnavailable",
                    detail: "A real Tencent runtime had no active RuntimeLease interaction token"
                )
                emitTencentBackendPCMDriveTrueDeviceQAResult(reason: "runtimeInteractionLeaseUnavailable")
            }
            PrivacySafeDiagnostics.log(
                subsystem: "TencentDigitalHuman",
                event: "pcmDriveSkipped",
                states: [
                    "reason": "runtimeInteractionLeaseUnavailable",
                    "source": source,
                ],
                correlations: ["request": requestID]
            )
            degradeTencentDigitalHumanRoute(reason: "runtimeInteractionLeaseUnavailable")
            return
        }
        let pausedDialogEngine = pauseDialogEngineForTencentProviderSpeechIfNeeded()
        guard prepareAudioSessionForTencentProviderPlayback(
            preserveRecordingCategory: pausedDialogEngine
        ) else {
            if runtimeInteractionCallback != nil {
                echoRuntimeSessionCoordinator.finishInteraction()
            }
            if source == "trueDeviceBackendPCMDriveSmoke" {
                trueDeviceBackendPCMDriveTrace.markFailure(
                    reason: "audioSessionCoordinatorActivationFailed",
                    detail: "The Echo audio-session coordinator could not activate Tencent playback"
                )
                emitTencentBackendPCMDriveTrueDeviceQAResult(reason: "audioSessionCoordinatorActivationFailed")
            }
            degradeTencentDigitalHumanRoute(reason: "audioSessionCoordinatorActivationFailed")
            return
        }
        if source == "trueDeviceBackendPCMDriveSmoke" {
            trueDeviceBackendPCMDriveTrace.markRequest(turnID: turnID, requestID: requestID)
            trueDeviceBackendPCMDriveTrace.markSignal(
                preparedByteCount: signal.preparedByteCount,
                expectedChunkCount: signal.chunkCount
            )
        }

        digitalHumanConversation.beginProviderRequest(
            requestID: requestID,
            replyText: replyText,
            turnID: turnID,
            keepsPendingReply: routeEchoAudioThroughDigitalHuman
        )
        scheduleTencentDigitalHumanTextOverTimeout(
            requestID: requestID,
            source: source,
            runtimeInteractionCallback: runtimeInteractionCallback
        )
        startPCMDriveSignalToDigitalHumanRuntime(
            signal: signal,
            requestID: requestID,
            turnID: turnID,
            contextKey: currentDigitalHumanRuntimeContextKey(),
            source: source,
            lifecycleToken: lifecycleToken,
            runtimeInteractionCallback: runtimeInteractionCallback,
            voiceCloneUseTicket: nil
        )

        if shouldRunTencentDigitalHumanPCMDriveStopProbe {
            DispatchQueue.main.asyncAfter(deadline: .now() + Self.tencentDigitalHumanPCMDriveStopProbeDelay) { [weak self] in
                guard let self,
                      self.isCurrentDigitalHumanLifecycleToken(
                        lifecycleToken,
                        reason: "pcmDriveStopProbe"
                      ),
                      self.isCurrentEchoRuntimeSessionCallback(
                        runtimeInteractionCallback,
                        reason: "pcmDriveStopProbe"
                      ),
                      self.shouldRunTencentDigitalHumanPCMDriveSmoke
                        || self.shouldRunTencentDigitalHumanBackendPCMDriveSmoke
                        || self.shouldRunTencentBackendPCMDriveMockSmoke,
                      self.digitalHumanConversation.activeRequestID == requestID else {
                    return
                }
                let resumedVoiceCapture = self.interruptDigitalHumanPlayback(reason: "pcmDriveSmokeStopProbe")
                if source == "trueDeviceBackendPCMDriveSmoke" {
                    self.trueDeviceBackendPCMDriveTrace.stopProbeFired = true
                    self.trueDeviceBackendPCMDriveTrace.resumedVoiceCapture = resumedVoiceCapture
                    if !resumedVoiceCapture {
                        self.trueDeviceBackendPCMDriveTrace.markFailure(
                            reason: "stopProbeResumeFailed",
                            detail: "interruptDigitalHumanPlayback returned false"
                        )
                    }
                    self.emitTencentBackendPCMDriveTrueDeviceQAResult(reason: "stopProbeFired")
                }
                if !resumedVoiceCapture {
                    self.resetEchoViewModelToIdle()
                }
                PrivacySafeDiagnostics.log(
                    subsystem: "TencentDigitalHuman",
                    event: "pcmDriveStopProbeFired",
                    states: ["resumedVoiceCapture": String(resumedVoiceCapture)],
                    correlations: ["request": requestID]
                )
            }
        }
    }

    private func startPCMDriveSignalToDigitalHumanRuntime(
        signal: TencentPCMDriveTestSignal,
        requestID: String,
        turnID: String,
        contextKey: String,
        source: String,
        lifecycleToken: DigitalHumanLifecycleToken,
        runtimeInteractionCallback: EchoRuntimeCallbackToken?,
        voiceCloneUseTicket: VoiceCloneSynthesisUseTicket?
    ) {
        guard isCurrentDigitalHumanLifecycleToken(
            lifecycleToken,
            reason: "pcmDriveStart:\(source)"
        ),
        isCurrentEchoRuntimeSessionCallback(
            runtimeInteractionCallback,
            reason: "pcmDriveStart:\(source)"
        ) else {
            return
        }
        digitalHumanLivePanelView?.setInteractionState(.speaking)
        scheduleTencentDigitalHumanPCMDriveChunks(
            signal: signal,
            requestID: requestID,
            turnID: turnID,
            contextKey: contextKey,
            source: source,
            lifecycleToken: lifecycleToken,
            runtimeInteractionCallback: runtimeInteractionCallback,
            voiceCloneUseTicket: voiceCloneUseTicket
        )
        PrivacySafeDiagnostics.log(
            subsystem: "TencentDigitalHuman",
            event: "pcmDriveSignalSent",
            states: [
                "format": signal.formatDescription,
                "source": source,
            ],
            counts: [
                "byteCount": signal.data.count,
                "chunkCount": signal.chunkCount,
            ],
            correlations: [
                "request": requestID,
                "turn": digitalHumanConversation.currentTurnID,
            ]
        )
    }

    private func scheduleTencentDigitalHumanPCMDriveChunks(
        signal: TencentPCMDriveTestSignal,
        requestID: String,
        turnID: String,
        contextKey: String,
        source: String,
        lifecycleToken: DigitalHumanLifecycleToken,
        runtimeInteractionCallback: EchoRuntimeCallbackToken?,
        voiceCloneUseTicket: VoiceCloneSynthesisUseTicket?
    ) {
        let chunks = signal.chunks()
        for (index, chunk) in chunks.enumerated() {
            let sequence = index + 1
            DispatchQueue.main.asyncAfter(
                deadline: .now() + Double(index) * Self.tencentDigitalHumanPCMDriveChunkDuration + Self.tencentDigitalHumanPCMDriveStartDelay
            ) { [weak self] in
                guard let self,
                      self.isCurrentDigitalHumanLifecycleToken(
                        lifecycleToken,
                        reason: "pcmChunk:\(source):\(sequence)"
                      ),
                      self.isCurrentEchoRuntimeSessionCallback(
                        runtimeInteractionCallback,
                        reason: "pcmChunk:\(source):\(sequence)"
                      ),
                      self.digitalHumanConversation.activeRequestID == requestID,
                      self.currentDigitalHumanRuntimeContextKey() == contextKey,
                      let digitalHumanRuntime = self.digitalHumanRuntime else {
                    return
                }
                guard !self.rejectInvalidVoiceCloneSynthesisUseTicketIfNeeded(
                    voiceCloneUseTicket,
                    requestID: requestID,
                    turnID: turnID,
                    outputMode: "tencentAudioDrive",
                    providerLogId: nil,
                    providerRequestId: nil,
                    lifecycleToken: lifecycleToken,
                    runtimeInteractionCallback: runtimeInteractionCallback,
                    source: "pcmChunk:\(source):\(sequence)"
                ) else {
                    return
                }
                do {
                    try digitalHumanRuntime.sendPCMChunk(chunk, requestID: requestID, sequence: sequence, isFinal: false)
                    if source == "trueDeviceBackendPCMDriveSmoke" {
                        self.trueDeviceBackendPCMDriveTrace.markChunkSent()
                    }
                    PrivacySafeDiagnostics.log(
                        subsystem: "TencentDigitalHuman",
                        event: "pcmChunkSent",
                        states: ["source": source],
                        counts: [
                            "byteCount": chunk.count,
                            "sequence": sequence,
                        ],
                        correlations: ["request": requestID]
                    )
                } catch {
                    self.digitalHumanConversation.clearProviderRequest()
                    if runtimeInteractionCallback != nil {
                        self.echoRuntimeSessionCoordinator.finishInteraction()
                    }
                    self.resumeDialogEngineAfterTencentProviderSpeechIfNeeded(
                        reason: "sendPCMChunkFailed",
                        lifecycleToken: lifecycleToken
                    )
                    if source == "trueDeviceBackendPCMDriveSmoke" {
                        self.trueDeviceBackendPCMDriveTrace.markFailure(
                            reason: "sendPCMChunkFailed",
                            detail: "sequence=\(sequence),error=\(error.localizedDescription)"
                        )
                        self.emitTencentBackendPCMDriveTrueDeviceQAResult(reason: "sendPCMChunkFailed")
                    }
                    PrivacySafeDiagnostics.log(
                        subsystem: "TencentDigitalHuman",
                        event: "pcmChunkFailed",
                        states: [
                            "reason": "sendPCMChunkFailed",
                            "source": source,
                        ],
                        counts: ["sequence": sequence],
                        correlations: ["request": requestID]
                    )
                }
            }
        }

        DispatchQueue.main.asyncAfter(
            deadline: .now() + Double(chunks.count) * Self.tencentDigitalHumanPCMDriveChunkDuration + Self.tencentDigitalHumanPCMDriveStartDelay
        ) { [weak self] in
            guard let self,
                  self.isCurrentDigitalHumanLifecycleToken(
                    lifecycleToken,
                    reason: "pcmFinal:\(source)"
                  ),
                  self.isCurrentEchoRuntimeSessionCallback(
                    runtimeInteractionCallback,
                    reason: "pcmFinal:\(source)"
                  ),
                  self.digitalHumanConversation.activeRequestID == requestID,
                  self.currentDigitalHumanRuntimeContextKey() == contextKey,
                  let digitalHumanRuntime = self.digitalHumanRuntime else {
                return
            }
            guard !self.rejectInvalidVoiceCloneSynthesisUseTicketIfNeeded(
                voiceCloneUseTicket,
                requestID: requestID,
                turnID: turnID,
                outputMode: "tencentAudioDrive",
                providerLogId: nil,
                providerRequestId: nil,
                lifecycleToken: lifecycleToken,
                runtimeInteractionCallback: runtimeInteractionCallback,
                source: "pcmFinal:\(source)"
            ) else {
                return
            }
            do {
                let sequence = chunks.count + 1
                try digitalHumanRuntime.sendPCMChunk(Data(), requestID: requestID, sequence: sequence, isFinal: true)
                if source == "trueDeviceBackendPCMDriveSmoke" {
                    self.trueDeviceBackendPCMDriveTrace.markFinalSent()
                }
                PrivacySafeDiagnostics.log(
                    subsystem: "TencentDigitalHuman",
                    event: "pcmFinalSent",
                    states: ["source": source],
                    counts: ["sequence": sequence],
                    correlations: ["request": requestID]
                )
            } catch {
                self.digitalHumanConversation.clearProviderRequest()
                if runtimeInteractionCallback != nil {
                    self.echoRuntimeSessionCoordinator.finishInteraction()
                }
                self.resumeDialogEngineAfterTencentProviderSpeechIfNeeded(
                    reason: "sendPCMFinalFailed",
                    lifecycleToken: lifecycleToken
                )
                if source == "trueDeviceBackendPCMDriveSmoke" {
                    self.trueDeviceBackendPCMDriveTrace.markFailure(
                        reason: "sendPCMFinalFailed",
                        detail: error.localizedDescription
                    )
                    self.emitTencentBackendPCMDriveTrueDeviceQAResult(reason: "sendPCMFinalFailed")
                }
                PrivacySafeDiagnostics.log(
                    subsystem: "TencentDigitalHuman",
                    event: "pcmFinalFailed",
                    states: [
                        "reason": "sendPCMFinalFailed",
                        "source": source,
                    ],
                    correlations: ["request": requestID]
                )
            }
        }
    }

    private func makeTencentDigitalHumanPCMDriveTestSignal() -> TencentPCMDriveTestSignal {
        let sampleRate: Int = 16_000
        let bitsPerSample = 16
        let channelCount = 1
        let duration: TimeInterval = 3.2
        let totalSamples = Int(duration * Double(sampleRate))
        var data = Data(capacity: totalSamples * MemoryLayout<Int16>.size)

        for sampleIndex in 0..<totalSamples {
            let time = Double(sampleIndex) / Double(sampleRate)
            let syllableEnvelope = 0.5 + 0.5 * sin(2 * Double.pi * 4.0 * time)
            let taperedEnvelope = min(1.0, time / 0.12) * min(1.0, (duration - time) / 0.18)
            let carrier = sin(2 * Double.pi * 220.0 * time)
            let overtone = 0.34 * sin(2 * Double.pi * 440.0 * time)
            let sample = (carrier + overtone) * syllableEnvelope * taperedEnvelope * 0.36
            let clamped = max(-1.0, min(1.0, sample))
            var pcmSample = Int16(clamped * Double(Int16.max)).littleEndian
            withUnsafeBytes(of: &pcmSample) { buffer in
                data.append(contentsOf: buffer)
            }
        }

        return TencentPCMDriveTestSignal(
            data: data,
            sampleRate: sampleRate,
            bitsPerSample: bitsPerSample,
            channelCount: channelCount,
            formatDescription: "pcm16kMono(sampleRate: 16_000,bitsPerSample: 16,channelCount: 1)"
        )
    }

    private func configureVoiceRuntimeThenStart(
        lifecycleToken providedLifecycleToken: DigitalHumanLifecycleToken? = nil,
        launchAttempt providedLaunchAttempt: EchoVoiceLaunchAttempt? = nil
    ) {
        guard let accountLease = echoAccountLease,
              validateEchoAccountLease(
                at: .request,
                expected: accountLease,
                reason: "configureVoiceRuntime"
              ),
              bindDialogEngineToEchoAccountLease(reason: "configureVoiceRuntime") else {
            handleBlockedRealtimeVoice(reason: "accountLeaseInvalid")
            return
        }
        let launchAttempt: EchoVoiceLaunchAttempt
        if let providedLaunchAttempt {
            launchAttempt = providedLaunchAttempt
        } else {
            if activeVoiceLaunchAttempt?.isActive == true { return }
            launchAttempt = EchoVoiceLaunchAttempt(
                ownerID: accountLease.subjectId,
                accountLease: accountLease,
                initialCaptureID: liveMemoryCaptureCoordinator?.id,
                initialAudioLeaseID: activeEchoAudioOwnerLease?.leaseId,
                timeout: voiceLaunchTimeout,
                now: voiceLaunchClock,
                scheduleTimeout: voiceLaunchScheduler,
                store: voiceLaunchDiagnosticStore
            )
            activeVoiceLaunchAttempt = launchAttempt
            launchAttempt.beginBudget { [weak self, weak launchAttempt] in
                DispatchQueue.main.async {
                    guard let self, let launchAttempt,
                          self.activeVoiceLaunchAttempt === launchAttempt else { return }
                    guard self.validateEchoAccountLease(
                        at: .timer, expected: accountLease, reason: "voiceLaunchDeadline"
                    ) else {
                        self.handleBlockedRealtimeVoice(
                            reason: "accountLeaseInvalid", launchAttempt: launchAttempt
                        )
                        return
                    }
                    self.handleBlockedRealtimeVoice(
                        reason: "voiceLaunchTimeout", launchAttempt: launchAttempt
                    )
                }
            }
        }
        guard activeVoiceLaunchAttempt === launchAttempt,
              launchAttempt.isActive else { return }
        launchAttempt.note(.lease)
        let lifecycleToken = providedLifecycleToken
            ?? captureDigitalHumanLifecycleToken(reason: "configureVoiceRuntime")
        guard isCurrentDigitalHumanLifecycleToken(
            lifecycleToken,
            reason: "configureVoiceRuntimeStart"
        ) else {
            return
        }
        #if DEBUG
        let realtimeVoiceClient = realtimeVoiceLaunchClientForTesting
            ?? DreamJourneyBackendClient.shared
        #else
        let realtimeVoiceClient = DreamJourneyBackendClient.shared
        #endif
        guard realtimeVoiceClient.isRealtimeVoiceConfigConfigured else {
            backendRuntimeTokenApplied = false
            renderVoiceSDKReadinessPreviewIfNeeded()
            handleBlockedRealtimeVoice(reason: "backendVoiceRuntimeUnavailable")
            return
        }

        let context = DigitalHumanContextStore.shared.current
        resumePendingLiveMemoryOrganizationsIfNeeded()
        guard launchAttempt.isActive else {
            handleBlockedRealtimeVoice(reason: "voiceLaunchTimeout", launchAttempt: launchAttempt)
            return
        }
        let personaScope = context.isSelfAssistant ? "personal" : "family"
        let targetPersonaId = context.isSelfAssistant
            ? accountLease.subjectId
            : (FamilyRepository.shared.acceptedMembers(for: accountLease.subjectId)
                .first(where: { $0.id == context.ownerId })?.memberSubjectId ?? context.ownerId)
        let viewerFamilyMemberID = context.isSelfAssistant
            ? nil
            : context.ownerId
        realtimeVoiceClient.fetchRealtimeVoiceConfig(
            userId: accountLease.subjectId,
            purpose: "echoLive",
            personaScope: personaScope,
            targetPersonaId: targetPersonaId,
            viewerFamilyMemberID: viewerFamilyMemberID,
            clientSessionId: liveProductSessionID,
            launchAttempt: launchAttempt
        ) { [weak self] result in
            guard let self = self else { return }
            guard self.activeVoiceLaunchAttempt === launchAttempt else { return }
            guard launchAttempt.isActive else {
                self.handleBlockedRealtimeVoice(
                    reason: "voiceLaunchTimeout", launchAttempt: launchAttempt
                )
                return
            }
            guard self.validateEchoAccountLease(
                at: .ui,
                expected: accountLease,
                reason: "realtimeVoiceConfigResponse"
            ),
            self.ownsCurrentDialogEngineBinding(),
            self.isCurrentDigitalHumanLifecycleToken(
                lifecycleToken,
                reason: "realtimeVoiceConfigResponse"
            ) else {
                return
            }
            switch result {
            case .success(let runtimeConfig):
                launchAttempt.note(.sdkConfigure)
                #if DEBUG
                let sdkConfigured = self.voiceSDKConfigureForTesting?(runtimeConfig)
                    ?? DialogEngineManager.shared.configure(runtimeConfig: runtimeConfig)
                #else
                let sdkConfigured = DialogEngineManager.shared.configure(runtimeConfig: runtimeConfig)
                #endif
                if sdkConfigured {
                    guard launchAttempt.isActive else {
                        self.handleBlockedRealtimeVoice(
                            reason: "voiceLaunchTimeout", launchAttempt: launchAttempt
                        )
                        return
                    }
                    let requestedProductSessionID = self.liveProductSessionID
                    let resolvedProductSessionID = runtimeConfig.productSessionID
                        ?? requestedProductSessionID
                    if let requestedProductSessionID,
                       let runtimeProductSessionID = runtimeConfig.productSessionID,
                       requestedProductSessionID != runtimeProductSessionID {
                        // Never attach a locally durable transcript to a
                        // provider runtime that was issued for another product
                        // session. Keep the local journal for an explicit
                        // recovery rather than mixing two conversations.
                        self.handleBlockedRealtimeVoice(reason: "productSessionMismatch")
                        return
                    }
                    self.liveProductSessionID = resolvedProductSessionID
                    self.backendRuntimeTokenApplied = true
                    self.renderVoiceSDKReadinessPreviewIfNeeded()
                    let liveAudioRoute = self.pinLiveAudioRouteIfNeeded(
                        reason: "configureVoiceRuntimeThenStart"
                    )
                    if case .unavailable = liveAudioRoute {
                        self.handleBlockedRealtimeVoice(reason: "liveAudioRouteUnavailable")
                        return
                    }
                    self.applyEchoAudioRoutePolicy()
                    guard self.prepareEchoCaptureAudioSession(reason: "configureVoiceRuntimeThenStart") else {
                        self.handleBlockedRealtimeVoice(reason: "audioSessionCoordinatorActivationFailed")
                        return
                    }
                    launchAttempt.note(.audioActivation)
                    guard launchAttempt.isActive else {
                        self.handleBlockedRealtimeVoice(
                            reason: "voiceLaunchTimeout", launchAttempt: launchAttempt
                        )
                        return
                    }
                    #if DEBUG
                    if !self.skipVoiceLaunchMemoryCaptureForTesting {
                        self.beginLiveMemoryCaptureIfNeeded(
                            accountLease: accountLease,
                            productSessionID: resolvedProductSessionID
                        )
                    }
                    #else
                    self.beginLiveMemoryCaptureIfNeeded(
                        accountLease: accountLease,
                        productSessionID: resolvedProductSessionID
                    )
                    #endif
                    let groundingPlan = DialogLiveGroundingPlan.sessionSnapshot
                    launchAttempt.note(.sdkStart)
                    #if DEBUG
                    if let voiceSDKStartForTesting = self.voiceSDKStartForTesting {
                        voiceSDKStartForTesting { [weak self, weak launchAttempt] in
                            guard let self,
                                  let launchAttempt,
                                  self.activeVoiceLaunchAttempt === launchAttempt,
                                  launchAttempt.isActive else { return }
                            self.onDialogStarted()
                        }
                    } else {
                        DialogEngineManager.shared.startDialog(
                            sendsGreeting: true,
                            usesTurnScopedKnowledgeContext: groundingPlan.usesTurnScopedKnowledgeContext,
                            lifetimePolicy: groundingPlan.lifetimePolicy,
                            answerAuthority: groundingPlan.answerAuthority,
                            voiceLaunchID: launchAttempt.id,
                            voiceLaunchIsValid: { [weak launchAttempt] in
                                launchAttempt?.isActive == true
                            }
                        )
                    }
                    #else
                    DialogEngineManager.shared.startDialog(
                        sendsGreeting: true,
                        usesTurnScopedKnowledgeContext: groundingPlan.usesTurnScopedKnowledgeContext,
                        lifetimePolicy: groundingPlan.lifetimePolicy,
                        answerAuthority: groundingPlan.answerAuthority,
                        voiceLaunchID: launchAttempt.id,
                        voiceLaunchIsValid: { [weak launchAttempt] in
                            launchAttempt?.isActive == true
                        }
                    )
                    #endif
                    if !launchAttempt.isActive {
                        self.handleBlockedRealtimeVoice(
                            reason: "voiceLaunchTimeout", launchAttempt: launchAttempt
                        )
                    }
                } else {
                    self.backendRuntimeTokenApplied = false
                    self.renderVoiceSDKReadinessPreviewIfNeeded()
                    self.handleBlockedRealtimeVoice(reason: "providerCredentialBlocked")
                }
            case .failure(let error):
                let diagnostic = EchoRealtimeVoiceRuntimeFailureDiagnostic(error: error)
                var counts: [String: Int] = [:]
                if let httpStatus = diagnostic.httpStatus {
                    counts["httpStatus"] = httpStatus
                }
                PrivacySafeDiagnostics.log(
                    subsystem: "Echo",
                    event: "voiceRuntimeConfigUnavailable",
                    states: [
                        "reason": "backendFailure",
                        "stage": diagnostic.stage,
                        "businessCode": diagnostic.businessCode,
                    ],
                    counts: counts
                )
                self.backendRuntimeTokenApplied = false
                self.renderVoiceSDKReadinessPreviewIfNeeded()
                self.handleBlockedRealtimeVoice(
                    reason: "backendVoiceRuntimeRequestFailed",
                    launchAttempt: launchAttempt,
                    error: error
                )
            }
        }
    }

    private var voiceLaunchDiagnosticStore: EchoVoiceLaunchDiagnosticStore {
        #if DEBUG
        return voiceLaunchDiagnosticStoreForTesting ?? .shared
        #else
        return .shared
        #endif
    }

    private var voiceLaunchTimeout: TimeInterval {
        #if DEBUG
        return voiceLaunchTimeoutForTesting ?? EchoVoiceLaunchAttempt.defaultTimeout
        #else
        return EchoVoiceLaunchAttempt.defaultTimeout
        #endif
    }

    private var voiceLaunchClock: () -> TimeInterval {
        #if DEBUG
        return voiceLaunchClockForTesting
            ?? { ProcessInfo.processInfo.systemUptime }
        #else
        return { ProcessInfo.processInfo.systemUptime }
        #endif
    }

    private var voiceLaunchScheduler: (TimeInterval, DispatchWorkItem) -> Void {
        #if DEBUG
        if let voiceLaunchSchedulerForTesting { return voiceLaunchSchedulerForTesting }
        #endif
        return { delay, work in
            DispatchQueue.global(qos: .userInitiated).asyncAfter(
                deadline: .now() + delay, execute: work
            )
        }
    }

    private func scheduleVoiceDelegateEvent(_ event: @escaping () -> Void) {
        #if DEBUG
        if let voiceDelegateEventSchedulerForTesting {
            voiceDelegateEventSchedulerForTesting(event)
            return
        }
        #endif
        DispatchQueue.main.async(execute: event)
    }

    private func handleBlockedRealtimeVoice(
        reason: String,
        launchAttempt providedAttempt: EchoVoiceLaunchAttempt? = nil,
        error: Error? = nil
    ) {
        // A synchronous SDK failure or a competing terminal callback may already
        // have closed this launch. It must not close or relabel a successor.
        if let providedAttempt, activeVoiceLaunchAttempt !== providedAttempt { return }
        let launchAttempt = providedAttempt ?? activeVoiceLaunchAttempt
        if reason == "voiceLaunchTimeout" {
            _ = launchAttempt?.finishIfTimedOut()
        }
        if activeVoiceLaunchAttempt === launchAttempt {
            activeVoiceLaunchAttempt = nil
        }
        if reason != "voiceLaunchTimeout" {
            if launchAttempt?.finish(reason, error: error) == false {
                _ = launchAttempt?.finishIfTimedOut()
            }
        }
        let shouldFinishCapture: Bool
        if let launchAttempt {
            shouldFinishCapture = liveMemoryCaptureCoordinator != nil
                && liveMemoryCaptureCoordinator?.id != launchAttempt.initialCaptureID
        } else {
            shouldFinishCapture = isUserControlledLiveSessionOpen
                && liveMemoryCaptureCoordinator != nil
        }
        backendRuntimeTokenApplied = false
        DialogEngineManager.shared.cancelPendingVoiceLaunch(id: launchAttempt?.id)
        if ownsCurrentDialogEngineBinding(),
           DialogEngineManager.shared.isDialogActive,
           launchAttempt?.sdkStartSubmitted ?? true {
            DialogEngineManager.shared.stopDialog()
        }
        lastEchoRuntimeFallbackReason = reason
        isUserControlledLiveSessionOpen = false
        isLiveVoiceTransportSuspended = false
        if shouldFinishCapture { finishLiveMemoryCaptureIfNeeded() }
        if launchAttempt == nil
            || activeEchoAudioOwnerLease?.leaseId != launchAttempt?.initialAudioLeaseID {
            releaseEchoAudioOwnerLease(reason: "realtimeVoiceUnavailable")
        }
        activeVoiceInteractionLifecycleToken = nil
        let displayText: String
        if reason == "voiceLaunchTimeout" {
            displayText = "语音启动超时，请稍后重试"
        } else if let clientError = error as? DreamJourneyBackendClient.ClientError {
            switch clientError {
            case .featurePolicyDenied, .recoveryAccessDenied:
                displayText = "当前账号暂不能使用语音功能"
            case .userAuthenticationRequired, .sessionUpgradeRequired,
                 .accountScopeChanged, .verifiedPreHandlerAuthenticationRejection:
                displayText = "登录状态已变化，请重新登录后再试"
            default:
                displayText = "语音暂不可用，请使用文字回响"
            }
        } else if error.map({
            DreamJourneyBackendClient.ownerTruthURLFailureCode($0) != nil
        }) == true {
            displayText = "网络暂不可用，请稍后再试"
        } else {
            displayText = "语音暂不可用，请使用文字回响"
        }
        viewModel.fail(displayText)
        renderVoiceStatus(
            text: displayText,
            isVisible: true,
            accessibilityIdentifier: "echoRealtimeVoiceCredentialBlocked"
        )
        #if DEBUG
        voiceLaunchTerminalCompletionForTesting?(reason)
        #endif
        recordEchoRuntimeDiagnosticsSnapshot(reason: reason)
        print("[Echo] providerCredentialBlocked reason=\(reason)")
    }

    private func currentVoiceSDKReadinessSummary() -> VoiceSDKReadinessSummary {
        VoiceSDKReadinessSummary.current(
            backendRuntimeConfigured: DreamJourneyBackendClient.shared.isRealtimeVoiceConfigConfigured,
            backendRuntimeTokenApplied: backendRuntimeTokenApplied,
            localConfigReady: DialogEngineManager.shared.currentConfigurationIsProductionReady,
            productionVoiceSDKQualityVerified: false
        )
    }

    private func renderVoiceSDKReadinessPreviewIfNeeded() {
        guard showsVoiceSDKReadinessPreview else { return }
        let summary = currentVoiceSDKReadinessSummary()
        renderVoiceStatus(
            text: summary.title,
            isVisible: true,
            accessibilityIdentifier: "echoVoiceSDKReadinessStatus"
        )
    }

    private func stopVoiceCapture() {
        DialogEngineManager.shared.cancelPendingVoiceLaunch(id: activeVoiceLaunchAttempt?.id)
        activeVoiceLaunchAttempt?.cancelIfPending()
        activeVoiceLaunchAttempt = nil
        isLiveVoiceTransportSuspended = false
        if echoTextReplySpeechRequestID != nil {
            isUserControlledLiveSessionOpen = false
            finishLiveMemoryCaptureIfNeeded()
            cancelEchoTextReplySpeech(reason: "userStoppedTextEchoSpeech")
            invalidateDigitalHumanInteraction(reason: "userStoppedTextEchoSpeech")
            activeVoiceInteractionLifecycleToken = nil
            resetEchoViewModelToIdle()
            return
        }

        isUserControlledLiveSessionOpen = false
        if case .error = currentState,
           !(ownsCurrentDialogEngineBinding() && DialogEngineManager.shared.isDialogActive) {
            finishLiveMemoryCaptureIfNeeded()
            activeVoiceInteractionLifecycleToken = nil
            resetEchoViewModelToIdle()
            return
        }
        releaseEchoAudioOwnerLease(reason: "userStoppedVoiceCapture")
        invalidateDigitalHumanInteraction(reason: "userStoppedVoiceCapture")
        activeVoiceInteractionLifecycleToken = nil
        isStoppingVoiceCaptureManually = true
        if shouldInterruptTencentDigitalHumanOnUserStop {
            interruptDigitalHumanPlayback(reason: "userStop")
        } else {
            preserveTencentProviderSessionAfterLocalDialogStop(reason: "userStop")
        }
        if ownsCurrentDialogEngineBinding(),
           DialogEngineManager.shared.isDialogActive {
            DialogEngineManager.shared.stopDialog()
        } else {
            isStoppingVoiceCaptureManually = false
            flushPendingAIReplyIfNeeded()
            finishLiveMemoryCaptureIfNeeded()
            if !hasTencentDigitalHumanProviderSpeechInFlight {
                resetDigitalHumanReplyDispatchState()
            }
            resetEchoViewModelToIdle()
        }
    }

    private func flushPendingAIReplyIfNeeded() {
        guard !viewModel.isNeutralSafetyMode else {
            pendingAIText = nil
            return
        }
        guard let aiText = pendingAIText,
              !aiText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return
        }
        captureLiveAssistantTurn(aiText)
        _ = viewModel.receiveAIReply(aiText)
        pendingAIText = nil
    }

    private func enterNeutralSafetyMode(_ decision: EchoSafetyDecision) {
        guard decision.isCrisis else { return }

        pendingAIText = nil
        isStoppingForDelayedReply = false
        isStoppingVoiceCaptureForAppLifecycle = false
        isStoppingVoiceCaptureManually = false
        _ = invalidateDigitalHumanLifecycle(reason: "neutralSafety")
        resetDigitalHumanReplyDispatchState()
        interruptDigitalHumanPlayback(reason: "neutralSafety")
        stopDigitalHumanAudioLevelMetering()

        guard ownsCurrentDialogEngineBinding() else {
            isStoppingForNeutralSafety = false
            return
        }
        DialogEngineManager.shared.interruptAI()
        guard DialogEngineManager.shared.isDialogActive else {
            isStoppingForNeutralSafety = false
            return
        }
        isStoppingForNeutralSafety = true
        DialogEngineManager.shared.stopDialog()
    }

    private func beginDelayedReplyWait() {
        pendingAIText = nil
        resetDigitalHumanReplyDispatchState()
        preserveTencentProviderSessionAfterLocalDialogStop(reason: "delayedReplyWait")
        guard ownsCurrentDialogEngineBinding(),
              DialogEngineManager.shared.isDialogActive else { return }
        isStoppingForDelayedReply = true
        DialogEngineManager.shared.stopDialog()
    }

    private func scheduleDelayedReplyNotificationIfNeeded(rawTranscript: String) {
        guard isEchoDelayedReplyProductEnabled,
              !viewModel.isNeutralSafetyMode,
              let delayedReply = viewModel.pendingDelayedReply,
              let callsiteContext = viewModel.pendingDelayedReplyContext,
              delayedReply.id == callsiteContext.operationId,
              validateDelayedReplyCallsiteContext(
                  callsiteContext,
                  at: .request,
                  reason: "schedule"
              ) else {
            return
        }
        let userId = callsiteContext.resourceOwnerId

        EchoDelayedReplyNotificationScheduler.shared.requestAuthorizationIfNeeded(
            resourceOwnerId: callsiteContext.resourceOwnerId,
            operationId: callsiteContext.operationId,
            accountLease: callsiteContext.accountLease
        ) { [weak self] granted in
            guard let self,
                  granted,
                  self.validateDelayedReplyCallsiteContext(
                      callsiteContext,
                      at: .ui,
                      reason: "authorization"
                  ),
                  !self.viewModel.isNeutralSafetyMode,
                  self.viewModel.pendingDelayedReply?.id == delayedReply.id else { return }
            EchoDelayedReplyNotificationScheduler.shared.schedule(
                delayedReply,
                resourceOwnerId: callsiteContext.resourceOwnerId,
                operationId: callsiteContext.operationId,
                accountLease: callsiteContext.accountLease
            ) { error in
                guard self.validateDelayedReplyCallsiteContext(
                    callsiteContext,
                    at: .runtime,
                    reason: "localNotificationCompletion"
                ) else {
                    return
                }
                if error != nil {
                    PrivacySafeDiagnostics.log(
                        subsystem: "Echo",
                        event: "delayedReplyLocalNotificationFailed",
                        states: ["reason": "notificationFailure"]
                    )
                }
            }
        }

        guard DreamJourneyBackendClient.shared.isEchoDelayedReplyPushConfigured else {
            return
        }

        let tokenStore = PushDeviceTokenStore.shared
        if tokenStore.registration(for: userId) == nil,
           DreamJourneyBackendClient.shared.isPushDeviceTokenRegistrationConfigured,
           let deviceToken = tokenStore.loadDeviceToken() {
            DreamJourneyBackendClient.shared.registerPushDeviceToken(
                userId: userId,
                deviceToken: deviceToken,
                environment: PushDeviceTokenEnvironment.current,
                deviceId: UIDevice.current.identifierForVendor?.uuidString ?? "ios-device"
            ) { [weak self] result in
                guard let self,
                      self.validateDelayedReplyCallsiteContext(
                          callsiteContext,
                          at: .commit,
                          reason: "pushTokenRegistration"
                      ) else {
                    return
                }
                if case .success(let object) = result,
                   let item = object["item"] as? [String: Any],
                   let registration = PushDeviceTokenRegistration(json: item) {
                    _ = tokenStore.saveRegistration(
                        registration,
                        accountLease: callsiteContext.accountLease
                    )
                }
                self.submitDelayedReplyPush(
                    userId: userId,
                    delayedReply: delayedReply,
                    rawTranscript: rawTranscript,
                    callsiteContext: callsiteContext
                )
            }
            return
        }
        submitDelayedReplyPush(
            userId: userId,
            delayedReply: delayedReply,
            rawTranscript: rawTranscript,
            callsiteContext: callsiteContext
        )
    }

    private func submitDelayedReplyPush(
        userId: String,
        delayedReply: EchoDelayedReply,
        rawTranscript: String,
        callsiteContext: EchoDelayedReplyCallsiteContext
    ) {
        guard callsiteContext.resourceOwnerId == userId,
              validateDelayedReplyCallsiteContext(
                  callsiteContext,
                  at: .request,
                  reason: "pushSubmit"
              ),
              !viewModel.isNeutralSafetyMode,
              viewModel.pendingDelayedReply?.id == delayedReply.id else {
            return
        }
        DreamJourneyBackendClient.shared.scheduleEchoDelayedReplyPush(
            userId: userId,
            delayedReply: delayedReply,
            rawTranscript: rawTranscript
        ) { [weak self] result in
            guard let self,
                  self.validateDelayedReplyCallsiteContext(
                      callsiteContext,
                      at: .runtime,
                      reason: "pushCompletion"
                  ) else {
                return
            }
            if case .failure = result {
                PrivacySafeDiagnostics.log(
                    subsystem: "Echo",
                    event: "delayedReplyPushContractFailed",
                    states: ["reason": "backendFailure"]
                )
            }
        }
    }
}

extension EchoViewController: DialogEngineDelegate {
    func onOrbAudioLevel(_ sample: DialogOrbAudioSample) {
        // Manager has already checked callback ownership and account/session identity.
        // Do not enqueue another task or mutate conversation/persistence state here.
        #if DEBUG
        orbAudioSampleForTesting = sample
        #endif
        cloudOrb.receiveAudioLevel(sample.level, channel: sample.channel, capturedAt: sample.capturedAt)
    }

    func onDialogStarted() {
        let receivedAttempt = activeVoiceLaunchAttempt
        let receivedToken = activeVoiceInteractionLifecycleToken
        let receivedLease = echoAccountLease
        scheduleVoiceDelegateEvent { [weak self] in
            guard let self,
                  let receivedAttempt,
                  let receivedToken,
                  let receivedLease,
                  self.activeVoiceLaunchAttempt === receivedAttempt,
                  self.activeVoiceInteractionLifecycleToken == receivedToken,
                  self.echoAccountLease == receivedLease,
                  self.validateEchoAccountLease(at: .ui, reason: "dialogStarted"),
                  self.activeVoiceInteractionToken(reason: "dialogStarted") != nil else { return }
            if let launchAttempt = self.activeVoiceLaunchAttempt {
                guard launchAttempt.isActive else {
                    self.handleBlockedRealtimeVoice(
                        reason: "voiceLaunchTimeout", launchAttempt: launchAttempt
                    )
                    return
                }
                launchAttempt.note(.sessionStarted)
            }
            self.resetDigitalHumanReplyDispatchState()
            guard self.prepareEchoCaptureAudioSession(reason: "dialogStarted") else {
                self.handleBlockedRealtimeVoice(reason: "audioSessionCoordinatorActivationFailed")
                return
            }
            if let launchAttempt = self.activeVoiceLaunchAttempt {
                guard launchAttempt.finish("listening") else {
                    self.handleBlockedRealtimeVoice(
                        reason: "voiceLaunchTimeout", launchAttempt: launchAttempt
                    )
                    return
                }
                DialogEngineManager.shared.completeVoiceLaunch(id: launchAttempt.id)
                self.activeVoiceLaunchAttempt = nil
            }
            self.viewModel.beginVoiceInteraction()
            self.startLiveSessionLimitIfNeeded()
            self.armLiveUserInactivityTimeout(reason: "dialogStarted")
        }
    }

    func onASRResult(text: String, isFinal: Bool) {
        DispatchQueue.main.async { [weak self] in
            guard let self,
                  self.validateEchoAccountLease(at: .ui, reason: "asrFinal"),
                  !self.isLiveFarewellActive,
                  let lifecycleToken = self.activeVoiceInteractionToken(reason: "asrFinal"),
                  let accountLease = self.echoAccountLease else { return }
            if !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                self.liveSessionLimit.progress(now: ProcessInfo.processInfo.systemUptime)
                self.liveLimitAwaitingReply = true
                self.recoveryUserUtteranceActive = !isFinal
            }
            self.noteLiveUserVoiceActivity(
                text,
                reason: isFinal ? "dialogASRFinal" : "dialogASRPartial"
            )
            guard isFinal else { return }
            self.cancelLiveUserInactivityTimeout()
            let acceptedUserTurn = self.viewModel.finishUserVoice(
                text: text,
                accountLease: accountLease,
                resourceOwnerId: accountLease.subjectId,
                roleContextKey: self.digitalHumanRuntimeContextKey(
                    for: DigitalHumanContextStore.shared.current
                ),
                allowsDelayedReply: self.isEchoDelayedReplyProductEnabled
                    && !self.isUserControlledLiveSessionOpen
            )
            if let safetyDecision = self.viewModel.neutralSafetyDecision {
                self.releaseEchoAudioOwnerLease(
                    expectedOwner: .echoCapture,
                    reason: "asrFinalNeutralSafety"
                )
                self.enterNeutralSafetyMode(safetyDecision)
                return
            }
            // Live transcript persistence is independent from the legacy
            // one-question/one-answer presentation state. The provider can
            // complete a valid ASR turn while that UI state rejects a second
            // turn, but the complete Live conversation must still enter the
            // V4 interview and pending-memory pipeline.
            if DialogEngineManager.shared.answerAuthority != .provider {
                self.captureLiveOwnerTurn(text)
            }
            if !DialogLiveAnswerDispatchPolicy.shouldRequestBackendAnswer(
                isUserControlledLiveSessionOpen: self.isUserControlledLiveSessionOpen,
                lifetimePolicy: DialogEngineManager.shared.sessionLifetimePolicy,
                answerAuthority: DialogEngineManager.shared.answerAuthority
            ) {
                PrivacySafeDiagnostics.log(
                    subsystem: "Echo",
                    event: "providerOwnedLiveTurnAccepted",
                    states: ["answerAuthority": "provider"]
                )
                // Volcengine owns the continuous S2S turn. Do not dispatch a
                // second request through /echo/answers for the same speech.
                return
            }
            guard acceptedUserTurn else {
                PrivacySafeDiagnostics.log(
                    subsystem: "Echo",
                    event: "userTurnRejectedBeforeRuntimeDispatch",
                    states: ["reason": "turnIntentRejected"]
                )
                return
            }
            // A user-controlled Live session keeps one play-and-record lease
            // across recognition, reasoning and local SDK playback. Deactivating
            // AVAudioSession here leaves the provider websocket alive while its
            // RemoteIO recorder can no longer deliver PCM frames.
            if !self.isUserControlledLiveSessionOpen {
                self.releaseEchoAudioOwnerLease(
                    expectedOwner: .echoCapture,
                    reason: "asrFinal"
                )
            }
            if self.routeEchoAudioThroughDigitalHuman,
               self.hasTencentDigitalHumanProviderSpeechInFlight {
                self.preserveTencentProviderSessionAfterLocalDialogStop(reason: "userSpeechFinal")
            }
            self.resetDigitalHumanReplyDispatchState()
            let turnID = self.digitalHumanConversation.startUserTurn(makeID: self.makeTencentDigitalHumanRequestID)
            PrivacySafeDiagnostics.log(
                subsystem: "TencentDigitalHuman",
                event: "userTurnStarted",
                correlations: ["turn": turnID]
            )
            if self.viewModel.isWaitingForDelayedReply {
                self.scheduleDelayedReplyNotificationIfNeeded(rawTranscript: text)
                self.beginDelayedReplyWait()
            } else {
                self.requestLiveEchoAnswer(
                    question: text,
                    turnID: turnID,
                    lifecycleToken: lifecycleToken,
                    accountLease: accountLease
                )
            }
        }
    }

    func onTTSStarted(text: String) {
        DispatchQueue.main.async { [weak self] in
            guard let self,
                  self.validateEchoAccountLease(at: .ui, reason: "ttsStarted"),
                  !self.isLiveFarewellActive,
                  self.activeVoiceInteractionToken(reason: "ttsStarted") != nil,
                  !self.viewModel.isNeutralSafetyMode,
                  !self.viewModel.isWaitingForDelayedReply else { return }
            self.liveSessionLimit.progress(now: ProcessInfo.processInfo.systemUptime)
            self.cancelLiveUserInactivityTimeout()
            self.pendingAIText = nil
            self.cancelDigitalHumanReplyPrewarm()
            // Keep assistant context for the Live organizer even when the
            // legacy presentation state has already advanced. Assistant turns
            // remain context-only and can never become Owner evidence.
            if DialogEngineManager.shared.answerAuthority != .provider {
                self.captureLiveAssistantTurn(text)
            }
            guard self.viewModel.receiveAIReply(text) else {
                PrivacySafeDiagnostics.log(
                    subsystem: "Echo",
                    event: "aiReplyRejectedBeforeRuntimePlayback",
                    states: ["reason": "turnIntentRejected"]
                )
                return
            }
            if self.shouldDispatchEchoReplyToTencentProvider {
                self.sendEchoReplyToDigitalHumanRuntimeIfReady(text, source: "ttsStartedFallback")
            }
            if self.routeEchoAudioThroughDigitalHuman {
                print("[TencentDigitalHuman] skipped SDK TTS fallback; Tencent cloud render owns audio/lip-sync")
                return
            }
            let audioOwnerReady: Bool
            if self.isUserControlledLiveSessionOpen {
                // SpeechEngine owns both recorder and player in this route. Keep
                // the existing playAndRecord/voiceChat session continuously active
                // instead of deactivating RemoteIO between greeting and capture.
                audioOwnerReady = self.prepareEchoCaptureAudioSession(
                    reason: "dialogTTSStartedLive"
                )
            } else {
                audioOwnerReady = self.acquireEchoRuntimeAudioOwner(
                    .echoLocalPlayback,
                    priority: .playback,
                    reason: "dialogTTSStarted"
                )
            }
            guard audioOwnerReady else {
                self.viewModel.fail("音频正在切换，请稍后重试")
                return
            }
            if self.applyCachedLipSyncTimelineForEchoReply(text) != true {
                self.startSDKTTSPlaybackFallback()
            }
        }
    }

    func onTTSPlaybackStarted() {
        DispatchQueue.main.async { [weak self] in
            guard let self,
                  self.validateEchoAccountLease(at: .ui, reason: "ttsPlaybackStarted"),
                  self.isUserControlledLiveSessionOpen else { return }
            self.acknowledgeLivePlaybackStarted(route: .volcengineLocalTTS)
        }
    }

    func onCanonicalTranscriptEvent(_ event: NativeLiveCanonicalTranscriptEvent) {
        _ = currentCanonicalTranscriptIngress()?.submit(event)
    }

    func onCanonicalTranscriptMemberRegistered(_ member: NativeLiveCanonicalTranscriptMember) {
        _ = currentCanonicalTranscriptIngress()?.submitMember(member)
    }

    func makeCanonicalTranscriptDeliveryBinding() -> DialogCanonicalTranscriptDeliveryBinding {
        let frozenIngress = currentCanonicalTranscriptIngress()
        return DialogCanonicalTranscriptDeliveryBinding(
            reserve: { member in
                frozenIngress?.reserveFrozen(member) == true
            },
            deliver: { member, event in
                _ = frozenIngress?.submitFrozen(member: member, event: event)
            }
        )
    }

    func onDelegatedPlaybackProgress(_ progress: DialogEngineDelegatedPlaybackProgress) {
        DispatchQueue.main.async { [weak self] in
            guard let self,
                  self.validateEchoAccountLease(
                    at: .ui,
                    reason: "delegatedPlaybackProgress"
                  ),
                  self.isUserControlledLiveSessionOpen else { return }
            self.handleDelegatedPlaybackProgress(
                progress,
                route: .volcengineLocalTTS
            )
        }
    }

    func onTTSPlaybackInterruptedByUser() {
        DispatchQueue.main.async { [weak self] in
            guard let self,
                  self.validateEchoAccountLease(at: .ui, reason: "ttsPlaybackInterrupted"),
                  !self.isLiveFarewellActive,
                  self.activeVoiceInteractionToken(reason: "ttsPlaybackInterrupted") != nil,
                  self.isUserControlledLiveSessionOpen else { return }
            if let receipt = self.pendingLivePlaybackReceipt {
                self.handleLivePlaybackFailure(
                    receiptID: receipt.id,
                    route: receipt.state.route,
                    lifecycleToken: receipt.lifecycleToken,
                    reason: "interrupted",
                    replyID: receipt.state.replyID
                )
                return
            }
            guard let accountLease = self.echoAccountLease else { return }
            self.cancelLivePlaybackReceipt(reason: "userBargeIn")
            self.pendingAIText = nil
            self.stopDigitalHumanAudioLevelMetering()
            guard self.viewModel.resumeVoiceInteractionAfterReplyInterruption(
                accountLease: accountLease
            ) else {
                PrivacySafeDiagnostics.log(
                    subsystem: "Echo",
                    event: "replyInterruptionStateRecoveryRejected",
                    states: ["reason": "turnIntentRejected"]
                )
                return
            }
            guard self.prepareEchoCaptureAudioSession(reason: "ttsPlaybackInterrupted") else {
                self.viewModel.fail("本轮语音播放未完成，请结束本轮后重试")
                return
            }
            let recorderOutcome = DialogEngineManager.shared.resumeRecorderOutcome()
            guard recorderOutcome.isSuccess,
                  self.viewModel.turnPhase == .listening else {
                self.viewModel.fail("本轮语音播放未完成，请结束本轮后重试")
                return
            }
            self.renderVoiceStatus(
                text: "正在聆听",
                isVisible: true,
                accessibilityIdentifier: "echoLiveListeningAfterBargeIn"
            )
            self.armLiveUserInactivityTimeout(reason: "ttsPlaybackInterrupted")
        }
    }

    func onTTSFinished() {
        DispatchQueue.main.async { [weak self] in
            guard let self,
                  self.validateEchoAccountLease(at: .ui, reason: "ttsFinished"),
                  !self.isLiveFarewellActive,
                  let lifecycleToken = self.activeVoiceInteractionToken(reason: "ttsFinished") else { return }
            guard !self.viewModel.isNeutralSafetyMode,
                  !self.viewModel.isWaitingForDelayedReply else { return }
            if DialogEngineManager.shared.answerAuthority == .provider,
               self.isUserControlledLiveSessionOpen,
               let accountLease = self.echoAccountLease {
                _ = self.viewModel.markReplyDelivered(accountLease: accountLease)
                _ = self.viewModel.beginVoiceInteraction()
                self.liveLimitAwaitingReply = false
                self.liveSessionLimit.progress(now: ProcessInfo.processInfo.systemUptime)
                self.evaluateLiveSessionLimit()
                if self.isLiveFarewellActive || !self.isUserControlledLiveSessionOpen { return }
                self.armLiveUserInactivityTimeout(reason: "providerOwnedTTSFinished")
                self.renderVoiceStatus(
                    text: "正在聆听",
                    isVisible: true,
                    accessibilityIdentifier: "echoLiveListeningAfterProviderReply"
                )
                PrivacySafeDiagnostics.log(
                    subsystem: "Echo",
                    event: "providerOwnedLiveReplyFinished",
                    states: ["answerAuthority": "provider"]
                )
                return
            }
            guard let receipt = self.pendingLivePlaybackReceipt else { return }
            guard self.completeLivePlaybackReceipt(route: .volcengineLocalTTS) else {
                return
            }
            self.finishLiveEchoPlaybackAfterReceipt(
                route: .volcengineLocalTTS,
                lifecycleToken: lifecycleToken,
                receipt: receipt
            )
        }
    }

    private func finishLiveEchoPlaybackAfterReceipt(
        route: EchoLiveAudioRoute,
        lifecycleToken: DigitalHumanLifecycleToken,
        receipt: EchoLivePlaybackReceipt
    ) {
        guard !viewModel.isNeutralSafetyMode,
              !viewModel.isWaitingForDelayedReply else { return }
        guard activeVoiceInteractionToken(reason: "playbackFinished") != nil else {
            return
        }
        if routeEchoAudioThroughDigitalHuman,
           hasTencentDigitalHumanProviderSpeechInFlight {
            print("[TencentDigitalHuman] waiting for provider TextOver before finishing Echo reply")
            return
        }
        if !isUserControlledLiveSessionOpen {
            releaseEchoAudioOwnerLease(
                expectedOwner: .echoLocalPlayback,
                reason: "dialogTTSFinished"
            )
        }
        stopDigitalHumanAudioLevelMetering()
        let phaseBeforeDelivery = viewModel.turnPhase
        guard markEchoReplyDelivered() else {
            PrivacySafeDiagnostics.log(
                subsystem: "Echo",
                event: "replyDeliveryRejectedBeforeCaptureResume",
                states: ["reason": "turnIntentRejected"]
            )
            return
        }
        liveLimitAwaitingReply = false
        liveSessionLimit.progress(now: ProcessInfo.processInfo.systemUptime)
        logLiveTurnPhaseTransition(
            receipt: receipt,
            cause: .finished,
            phaseBefore: phaseBeforeDelivery,
            phaseAfter: viewModel.turnPhase
        )
        PrivacySafeDiagnostics.log(
            subsystem: "Echo",
            event: "liveRecoveryStarted",
            states: [
                "route": route.diagnosticCode,
                "terminalCause": EchoLivePlaybackTerminalCause.finished.diagnosticCode,
                "phaseBefore": viewModel.turnPhase.rawValue,
            ],
            counts: [
                "answerCharacterCount": receipt.answerCharacterCount,
                "elapsedMsSinceSubmit": Int(Date().timeIntervalSince(receipt.submittedAt) * 1_000),
            ],
            correlations: [
                "receiptID": receipt.id.uuidString,
                "turnID": receipt.turnID,
                "replyID": receipt.state.replyID,
                "lifecycleGeneration": String(receipt.lifecycleToken.generation),
            ]
        )
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) { [weak self] in
            guard let self,
                  self.validateEchoAccountLease(at: .timer, reason: "ttsFinishedResume"),
                  !self.isLiveFarewellActive,
                  self.isCurrentDigitalHumanLifecycleToken(
                    lifecycleToken,
                    reason: "ttsFinishedResume"
                  ) else { return }
            guard DialogEngineManager.shared.isDialogActive else {
                self.failLiveCaptureRecovery(
                    receipt: receipt,
                    route: route,
                    lifecycleToken: lifecycleToken,
                    cause: .finished,
                    reason: "dialogInactive"
                )
                return
            }
            guard self.prepareEchoCaptureAudioSession(reason: "dialogTTSFinishedResume") else {
                self.failLiveCaptureRecovery(
                    receipt: receipt,
                    route: route,
                    lifecycleToken: lifecycleToken,
                    cause: .finished,
                    reason: "audioSessionPreparationFailed"
                )
                return
            }
            let recorderOutcome = self.requestLiveRecorderResume(
                receipt: receipt,
                route: route,
                lifecycleToken: lifecycleToken,
                reason: "dialogTTSFinishedResume"
            )
            guard recorderOutcome.isSuccess else {
                self.failLiveCaptureRecovery(
                    receipt: receipt,
                    route: route,
                    lifecycleToken: lifecycleToken,
                    cause: .finished,
                    reason: "recorderResumeFailed"
                )
                return
            }
            let phaseBeforeCapture = self.viewModel.turnPhase
            guard self.viewModel.beginVoiceInteraction() else {
                self.failLiveCaptureRecovery(
                    receipt: receipt,
                    route: route,
                    lifecycleToken: lifecycleToken,
                    cause: .finished,
                    reason: "listeningTransitionRejected"
                )
                return
            }
            self.logLiveTurnPhaseTransition(
                receipt: receipt,
                cause: .finished,
                phaseBefore: phaseBeforeCapture,
                phaseAfter: self.viewModel.turnPhase
            )
            self.evaluateLiveSessionLimit()
            if self.isLiveFarewellActive || !self.isUserControlledLiveSessionOpen { return }
            self.armLiveUserInactivityTimeout(reason: "dialogTTSFinishedResume")
            self.renderVoiceStatus(
                text: "正在聆听",
                isVisible: true,
                accessibilityIdentifier: "echoLiveListeningAfterPlayback"
            )
            PrivacySafeDiagnostics.log(
                subsystem: "Echo",
                event: "liveCaptureResumed",
                states: [
                    "route": route.diagnosticCode,
                    "phaseBefore": phaseBeforeCapture.rawValue,
                    "phaseAfter": self.viewModel.turnPhase.rawValue,
                ],
                counts: [
                    "answerCharacterCount": receipt.answerCharacterCount,
                    "elapsedMsSinceSubmit": Int(Date().timeIntervalSince(receipt.submittedAt) * 1_000),
                ],
                correlations: [
                    "receiptID": receipt.id.uuidString,
                    "turnID": receipt.turnID,
                    "replyID": receipt.state.replyID,
                    "lifecycleGeneration": String(lifecycleToken.generation),
                ]
            )
        }
    }

    func onChatStreaming(text: String) {
        DispatchQueue.main.async { [weak self] in
            guard let self,
                  self.validateEchoAccountLease(at: .ui, reason: "chatStreaming"),
                  !self.isLiveFarewellActive,
                  self.activeVoiceInteractionToken(reason: "chatStreaming") != nil,
                  !self.viewModel.isNeutralSafetyMode,
                  !self.viewModel.isWaitingForDelayedReply else {
                return
            }
            self.liveSessionLimit.progress(now: ProcessInfo.processInfo.systemUptime)
            self.pendingAIText = text
            if self.shouldDispatchEchoReplyToTencentProvider {
                if self.routeEchoAudioThroughDigitalHuman {
                    self.cancelDigitalHumanReplyPrewarm()
                    print("[TencentDigitalHuman] skipped streaming prewarm; waiting for SDK TTS sentence text")
                    return
                }
                self.scheduleDigitalHumanReplyPrewarm(text)
            } else {
                self.cancelDigitalHumanReplyPrewarm()
            }
        }
    }

    func onError(error: Error) {
        let receivedAttempt = activeVoiceLaunchAttempt
        let receivedToken = activeVoiceInteractionLifecycleToken
        let receivedLease = echoAccountLease
        scheduleVoiceDelegateEvent { [weak self] in
            guard let self,
                  let receivedToken,
                  let receivedLease,
                  self.activeVoiceLaunchAttempt === receivedAttempt,
                  self.activeVoiceInteractionLifecycleToken == receivedToken,
                  self.echoAccountLease == receivedLease,
                  self.validateEchoAccountLease(at: .ui, reason: "dialogError"),
                  self.activeVoiceInteractionToken(reason: "dialogError") != nil else { return }
            if let launchAttempt = self.activeVoiceLaunchAttempt {
                self.handleBlockedRealtimeVoice(
                    reason: "voiceSDKStartFailed",
                    launchAttempt: launchAttempt,
                    error: error
                )
                return
            }
            if self.shouldSuppressDialogEngineErrorDuringTencentProviderSpeech(error) {
                if self.hasTencentDigitalHumanProviderSpeechInFlight {
                    self.preserveTencentProviderSessionAfterLocalDialogStop(reason: "dialogErrorSuppressedDuringProviderSpeech")
                }
                PrivacySafeDiagnostics.log(
                    subsystem: "TencentDigitalHuman",
                    event: "dialogEngineErrorSuppressed",
                    states: ["reason": "providerAudioHandoff"]
                )
                return
            }

            self.releaseEchoAudioOwnerLease(
                expectedOwner: .echoCapture,
                reason: "dialogError"
            )
            self.stopDigitalHumanAudioLevelMetering()
            if self.hasTencentDigitalHumanProviderSpeechInFlight {
                self.preserveTencentProviderSessionAfterLocalDialogStop(reason: "dialogError")
            } else {
                self.resetDigitalHumanReplyDispatchState()
            }
            if self.isUserControlledLiveSessionOpen {
                self.isLiveVoiceTransportSuspended = true
                self.armLiveUserInactivityTimeout(reason: "dialogErrorSuspended")
            }
            self.viewModel.fail(self.sanitizedDialogEngineErrorMessage(error))
        }
    }

    func onDialogEnded(reason: DialogEndReason) {
        DispatchQueue.main.async { [weak self] in
            guard let self,
                  self.validateEchoAccountLease(at: .ui, reason: "dialogEnded") else { return }
            self.releaseEchoAudioOwnerLease(
                expectedOwner: .echoCapture,
                reason: "dialogEnded"
            )
            if self.isStoppingForNeutralSafety || self.viewModel.isNeutralSafetyMode {
                self.isStoppingForNeutralSafety = false
                self.pendingAIText = nil
                self.resetDigitalHumanReplyDispatchState()
                self.stopDigitalHumanAudioLevelMetering()
                ConversationMemoryManager.shared.endSession()
                return
            }
            if self.digitalHumanConversation.consumePausingForProviderSpeech() {
                print("[TencentDigitalHuman] DialogEngine paused for provider speech")
                return
            }
            if self.isStoppingForDelayedReply {
                self.isStoppingForDelayedReply = false
                ConversationMemoryManager.shared.endSession()
                return
            }
            if self.isStoppingVoiceCaptureForAppLifecycle {
                self.isStoppingVoiceCaptureForAppLifecycle = false
                ConversationMemoryManager.shared.endSession()
                self.preserveTencentProviderSessionAfterLocalDialogStop(reason: "dialogEndedAfterAppLifecycle")
                self.resetDigitalHumanReplyDispatchState()
                self.resetToLifecyclePausedIdle()
                return
            }
            if self.isStoppingVoiceCaptureManually {
                self.isStoppingVoiceCaptureManually = false
                self.flushPendingAIReplyIfNeeded()
                self.finishLiveMemoryCaptureIfNeeded()
                ConversationMemoryManager.shared.endSession()
                self.preserveTencentProviderSessionAfterLocalDialogStop(reason: "dialogEndedAfterUserStop")
                if !self.hasTencentDigitalHumanProviderSpeechInFlight {
                    self.resetDigitalHumanReplyDispatchState()
                }
                self.resetEchoViewModelToIdle()
                return
            }
            self.flushPendingAIReplyIfNeeded()
            ConversationMemoryManager.shared.endSession()
            self.stopDigitalHumanAudioLevelMetering()
            if self.hasTencentDigitalHumanProviderSpeechInFlight {
                self.preserveTencentProviderSessionAfterLocalDialogStop(reason: "dialogEnded")
            } else {
                self.resetDigitalHumanReplyDispatchState()
            }
            if self.isUserControlledLiveSessionOpen {
                self.isLiveVoiceTransportSuspended = true
                self.armLiveUserInactivityTimeout(reason: "dialogEndedUnexpectedly")
            }
            self.resetEchoViewModelToIdle()
        }
    }
}

#if DEBUG
extension EchoViewController {
    func installVoiceLaunchBoundariesForTesting(
        accountLease: AccountLease,
        client: DreamJourneyBackendClient,
        timeout: TimeInterval = EchoVoiceLaunchAttempt.defaultTimeout,
        clock: (() -> TimeInterval)? = nil,
        scheduler: ((TimeInterval, DispatchWorkItem) -> Void)? = nil,
        permission: @escaping (@escaping (Bool) -> Void) -> Void,
        configureSDK: ((RealtimeVoiceRuntimeConfig) -> Bool)?,
        startSDK: ((@escaping () -> Void) -> Void)?,
        prepareAudio: (() -> Bool)?,
        capturesMemory: Bool = false
    ) {
        skipAncillaryVoiceCloneFetchForTesting = true
        loadViewIfNeeded()
        echoAccountLease = accountLease
        bindViewModel(accountLease: accountLease)
        _ = bindDialogEngineToEchoAccountLease(reason: "voiceLaunchTestSetup")
        realtimeVoiceLaunchClientForTesting = client
        voiceLaunchTimeoutForTesting = timeout
        voiceLaunchClockForTesting = clock
        voiceLaunchSchedulerForTesting = scheduler
        voicePermissionRequestForTesting = permission
        voiceSDKConfigureForTesting = configureSDK
        voiceSDKStartForTesting = startSDK
        voiceAudioPreparationForTesting = prepareAudio
        skipVoiceLaunchMemoryCaptureForTesting = !capturesMemory
    }

    func setVoiceLaunchDiagnosticStoreForTesting(_ store: EchoVoiceLaunchDiagnosticStore?) {
        voiceLaunchDiagnosticStoreForTesting = store
    }

    func cancelVoiceLaunchForTesting() { stopVoiceCapture() }

    var isVoiceIdleForTesting: Bool {
        if case .idle = currentState { return true }
        return false
    }

    var hasEchoAudioLeaseForTesting: Bool { activeEchoAudioOwnerLease != nil }

    func tapMicrophoneForTesting() {
        micTapped()
    }

    func rebindAccountScopeForVoiceLaunchTesting() {
        rebindEchoAccountScope(reason: "voiceLaunchAccountRebindTest")
    }

    var isVoiceListeningForTesting: Bool {
        if case .listening = currentState { return true }
        return false
    }

    func onVoiceListeningForTesting(_ completion: @escaping () -> Void) {
        voiceListeningCompletionForTesting = completion
    }

    func onVoiceLaunchTerminalForTesting(_ completion: @escaping (String) -> Void) {
        voiceLaunchTerminalCompletionForTesting = completion
    }

    func setVoiceDelegateEventSchedulerForTesting(
        _ scheduler: ((@escaping () -> Void) -> Void)?
    ) {
        voiceDelegateEventSchedulerForTesting = scheduler
    }

    func setVoiceLaunchCaptureFactoryForTesting(
        _ factory: ((AccountLease, String?) -> EchoLiveMemoryCaptureCoordinator)?
    ) {
        voiceLaunchCaptureFactoryForTesting = factory
    }

    var activeVoiceLaunchAttemptForTesting: EchoVoiceLaunchAttempt? {
        activeVoiceLaunchAttempt
    }

    func setCanonicalTranscriptDeliverySchedulerForTesting(
        _ scheduler: @escaping EchoCanonicalTranscriptIngress.DeliveryScheduler
    ) {
        canonicalTranscriptDeliveryScheduler = scheduler
    }

    func installLiveMemoryCaptureForTesting(
        accountLease: AccountLease,
        coordinator: EchoLiveMemoryCaptureCoordinator
    ) {
        skipAncillaryVoiceCloneFetchForTesting = true
        echoAccountLease = accountLease
        loadViewIfNeeded()
        retainLiveMemoryCaptureCoordinator(coordinator, asActive: true)
    }

    func beginLiveLimitForTesting(now: TimeInterval, pause: @escaping () -> Bool,
        playback: @escaping (String, @escaping () -> Void) -> Void) {
        cancelLiveSessionLimit()
        liveSessionLimit = EchoLiveSessionLimit(); liveSessionLimit.start(now: now)
        isUserControlledLiveSessionOpen = true
        liveProductSessionID = UUID().uuidString
        liveLimitPauseForTesting = pause; liveLimitPlaybackForTesting = playback
    }

    func tickLiveLimitForTesting(now: TimeInterval, busy: Bool) {
        applyLiveSessionLimitAction(liveSessionLimit.tick(now: now, busy: busy))
    }
    var liveLimitSessionOpenForTesting: Bool { isUserControlledLiveSessionOpen }

    func requestRecoveryPressureStopForTesting(utteranceActive: Bool) {
        recoveryUserUtteranceActive = utteranceActive
        if let coordinator = liveMemoryCaptureCoordinator { beginRecoveryGracefulStop(coordinator) }
    }

    func finishRecoveryUtteranceForTesting() { recoveryUserUtteranceActive = false }

    func finishLiveMemoryCaptureForTesting() {
        finishLiveMemoryCaptureIfNeeded()
    }

    func renderInteractionIdleForTesting() {
        render(state: .idle)
    }

    func liveMemoryCapturePresentationForTesting() -> (
        statusText: String?,
        statusIdentifier: String?,
        statusVisible: Bool
    ) {
        (
            voiceStatusLabel.text,
            voiceStatusLabel.accessibilityIdentifier,
            !voiceStatusView.isHidden
        )
    }

    func hasActiveLiveMemoryCaptureForTesting(
        _ coordinator: EchoLiveMemoryCaptureCoordinator
    ) -> Bool {
        liveMemoryCaptureCoordinator === coordinator
            && retainedLiveMemoryCaptureCoordinators[coordinator.id] === coordinator
    }

    func enableOwnerTruthTextEntryForTesting() {
        isOwnerTruthInterviewNaturalInputProductPolicyPermitted = true
        updateOwnerTruthInterviewNaturalInputProductEntryVisibility()
    }

    func tapOwnerTruthTextEntryForTesting() {
        ownerTruthInterviewNaturalInputProductEntryTapped()
    }

    func presentedOwnerTruthTextEntryForTesting() -> (
        title: String?,
        textFieldIdentifier: String?
    ) {
        let alert = presentedViewController as? UIAlertController
        return (
            alert?.title,
            alert?.textFields?.first?.accessibilityIdentifier
        )
    }

    func installLiveMemoryRecoveryForTesting(
        accountLease: AccountLease,
        coordinator: EchoLiveMemoryRecoveryCoordinator
    ) {
        echoAccountLease = accountLease
        loadViewIfNeeded()
        detachLiveMemoryRecoveryObservers()
        echoAccountLease = accountLease
        retainLiveMemoryRecoveryCoordinator(coordinator)
    }

    /// End a test page's recovery ownership without cancelling an issued read.
    func detachLiveMemoryRecoveryForTesting() {
        ownerTruthInterviewNaturalInputPolicyRefreshGeneration &+= 1
        releaseLiveMemoryRecoveryObservers(suspendsCoordinators: false)
    }

    func addLiveMemoryRecoveryForTesting(
        accountLease: AccountLease,
        coordinator: EchoLiveMemoryRecoveryCoordinator
    ) {
        echoAccountLease = accountLease
        loadViewIfNeeded()
        retainLiveMemoryRecoveryCoordinator(coordinator)
    }

    func liveMemoryRecoveryPresentationForTesting() -> (
        statusText: String?,
        statusIdentifier: String?,
        actionTitle: String?,
        actionIdentifier: String?,
        actionVisible: Bool
    ) {
        (
            voiceStatusLabel.text,
            voiceStatusLabel.accessibilityIdentifier,
            ownerTruthInterviewNaturalInputProductEntryButton.configuration?.title,
            ownerTruthInterviewNaturalInputProductEntryButton.accessibilityIdentifier,
            ownerTruthInterviewNaturalInputProductEntryButton.superview != nil
                && !ownerTruthInterviewNaturalInputProductEntryButton.isHidden
        )
    }

    func tapLiveMemoryRecoveryVerificationForTesting() {
        // Compatibility seam for old tests: drive the automatic read, not a UI button.
        verifyRetainedRecoveryReadOnly()
    }

    func presentLiveMemoryRecoveryResultForTesting(
        _ result: EchoLiveMemoryRecoveryResult,
        accountLease: AccountLease
    ) {
        echoAccountLease = accountLease
        loadViewIfNeeded()
        echoAccountLease = accountLease
        presentLiveMemoryRecoveryResult(result, accountLease: accountLease)
    }
}
#endif

#if UI_QA_SIMULATOR && targetEnvironment(simulator)
extension InterviewNaturalInputUIQAClient: EchoLiveMemoryCaptureClient {}

private final class EchoLiveMemoryRecoveryUIQAReadClient:
    OwnerTruthInterviewCandidateProposalStatusClient,
    EchoLiveMemoryRecoveryStatusReadClient {
    static let shared = EchoLiveMemoryRecoveryUIQAReadClient()

    private(set) var statusReadCount = 0
    private(set) var lastTraceID: String?
    private(set) var lastAttempt: Int?
    private var backendClient: DreamJourneyBackendClient?
    private var configuredScope: String?

    private let reviewBatchID = OwnerTruthRecordID(
        rawValue: UUID(uuidString: "00000000-0000-0000-0000-0000000000b7")!
    )

    private init() {}

    func configure(for accountLease: AccountLease) {
        let scope = [
            accountLease.subjectId,
            accountLease.vaultId,
            accountLease.sessionId,
            accountLease.authorityEpoch,
        ].joined(separator: "|")
        guard configuredScope != scope else { return }
        guard let authSession = BackendAuthSessionContract(json: [
            "sessionId": accountLease.sessionId,
            "userId": accountLease.subjectId,
            "subjectId": accountLease.subjectId,
            "tokenType": "Bearer",
            "accessToken": "dja_b6_uiqa_access",
            "refreshToken": "djr_b6_uiqa_refresh",
            "accessExpiresInSeconds": 3600,
            "refreshExpiresInSeconds": 86400,
            "accessExpiresAt": "2099-01-01T00:00:00Z",
            "refreshExpiresAt": "2099-01-02T00:00:00Z",
            "contractVersion": 2,
            "tokenFamilyId": "b6-uiqa-token-family",
            "sessionVersion": 1,
        ]) else {
            backendClient = nil
            configuredScope = nil
            return
        }
        let evaluator = FeatureGateEvaluator()
        let policy = FeatureGatePolicySnapshot(
            accessMode: .useCachedPolicy,
            policyVersion: "b6-uiqa-read-policy-v1",
            policyRevision: 1,
            emergencyRevision: 1,
            expiresAt: Date().addingTimeInterval(300),
            featureEnabled: true,
            releaseVisible: true,
            reason: "candidateReviewEnabled"
        )
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [EchoLiveMemoryRecoveryUIQAURLProtocol.self]
        EchoLiveMemoryRecoveryUIQAURLProtocol.configure(
            accountLease: accountLease,
            reviewBatchID: reviewBatchID
        )
        backendClient = DreamJourneyBackendClient.makeQATestClient(
            baseURL: URL(string: "https://b6-recovery-uiqa.invalid")!,
            session: Session(configuration: configuration),
            authenticatedSession: { authSession },
            currentUserID: { accountLease.subjectId },
            privateAccessAllowed: { true },
            featureDecision: { feature in
                evaluator.capture(
                    feature: feature,
                    risk: .ownerTextCore,
                    purpose: .request,
                    localEnabled: true,
                    qaSyntheticOverride: false,
                    accountGeneration: authSession.sessionId,
                    policy: policy
                )
            },
            featureDecisionRevalidator: { decision in
                evaluator.revalidateForRequest(
                    captured: decision,
                    localEnabled: true,
                    accountGeneration: authSession.sessionId,
                    currentPolicy: policy
                )
            },
            accountLeaseRuntime: .shared,
            ownerTruthReadDiagnosticSink: { event in
                guard event.resource == .liveMemoryRecoveryStatus else { return }
                self.lastTraceID = event.traceID
                self.lastAttempt = event.attempt
            }
        )
        statusReadCount = 0
        lastTraceID = nil
        lastAttempt = nil
        configuredScope = scope
    }

    func fetchOwnerTruthInterviewCandidateProposalStatus(
        vaultID: OwnerTruthVaultID,
        reviewBatchID: OwnerTruthRecordID,
        completion: @escaping (Result<OwnerTruthInterviewCandidateProposalStatus, Error>) -> Void
    ) {
        guard let backendClient else {
            completion(.failure(URLError(.resourceUnavailable)))
            return
        }
        backendClient.fetchOwnerTruthInterviewCandidateProposalStatus(
            vaultID: vaultID,
            reviewBatchID: reviewBatchID,
            completion: completion
        )
    }

    @discardableResult
    func fetchEchoLiveMemoryRecoveryStatus(
        accountLease: AccountLease,
        vaultID: OwnerTruthVaultID,
        reviewBatchID: OwnerTruthRecordID,
        readContext: OwnerTruthReadContext,
        completion: @escaping (
            OwnerTruthReadOutcome<OwnerTruthInterviewCandidateProposalStatus>
        ) -> Void
    ) -> OwnerTruthReadHandle {
        guard let backendClient else {
            completion(OwnerTruthReadOutcome(
                readContext: readContext,
                result: .failure(URLError(.resourceUnavailable))
            ))
            return OwnerTruthReadHandle()
        }
        statusReadCount += 1
        return backendClient.fetchEchoLiveMemoryRecoveryStatus(
            accountLease: accountLease,
            vaultID: vaultID,
            reviewBatchID: reviewBatchID,
            readContext: readContext
        ) { outcome in
            self.lastTraceID = outcome.readContext.traceID
            self.lastAttempt = outcome.readContext.attempt
            completion(outcome)
        }
    }
}

private final class EchoLiveMemoryRecoveryUIQAURLProtocol: URLProtocol {
    private static let lock = NSLock()
    private static var accountLease: AccountLease?
    private static var reviewBatchID: OwnerTruthRecordID?

    static func configure(accountLease: AccountLease, reviewBatchID: OwnerTruthRecordID) {
        lock.lock()
        self.accountLease = accountLease
        self.reviewBatchID = reviewBatchID
        lock.unlock()
    }

    override class func canInit(with request: URLRequest) -> Bool {
        request.url?.host == "b6-recovery-uiqa.invalid"
    }

    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }

    override func startLoading() {
        Self.lock.lock()
        let lease = Self.accountLease
        let batchID = Self.reviewBatchID
        Self.lock.unlock()
        guard request.httpMethod == "GET",
              let lease,
              let batchID,
              request.url?.path.hasSuffix(
                "/interview-review-batches/\(batchID.rawValue.uuidString)/candidate-proposal/status"
              ) == true,
              let url = request.url,
              let response = HTTPURLResponse(
                url: url,
                statusCode: 200,
                httpVersion: "HTTP/1.1",
                headerFields: ["Content-Type": "application/json"]
              ),
              let body = try? JSONSerialization.data(withJSONObject: [
                "schemaVersion": OwnerTruthInterviewCandidateProposalStatus.schemaVersion,
                "vaultId": lease.vaultId,
                "reviewBatch": [
                    "reviewBatchId": batchID.rawValue.uuidString,
                    "state": OwnerTruthInterviewCandidateProposalReviewBatchState.acknowledged.rawValue,
                ],
                "candidateProposal": [
                    "status": OwnerTruthInterviewCandidateProposalAdmissionState.admitted.rawValue,
                ],
                "source": [
                    "status": OwnerTruthInterviewCandidateProposalSourceState.admitted.rawValue,
                ],
                "candidateExtraction": [
                    "status": OwnerTruthInterviewCandidateProposalExtractionState.succeeded.rawValue,
                    "jobState": OwnerTruthInterviewCandidateProposalExtractionJobState.succeeded.rawValue,
                    "attempt": 1,
                    "maxAttempts": 3,
                    "retryAvailableAt": NSNull(),
                    "firstFailureCode": NSNull(),
                    "failureCode": NSNull(),
                    "failureCategory": NSNull(),
                    "terminationCode": NSNull(),
                    "retryable": false,
                    "deadLetterState": NSNull(),
                ],
                "effectExecution": [
                    "status": OwnerTruthInterviewCandidateProposalEffectState.disabled.rawValue,
                ],
                "candidateReview": [
                    "status": OwnerTruthInterviewCandidateProposalReviewState.reviewReady.rawValue,
                ],
              ]) else {
            client?.urlProtocol(self, didFailWithError: URLError(.badServerResponse))
            return
        }
        client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
        client?.urlProtocol(self, didLoad: body)
        client?.urlProtocolDidFinishLoading(self)
    }

    override func stopLoading() {}
}

extension EchoViewController {
    func runUIQAEchoLiveMemoryColdStartRecoverySmoke(
        phase: String,
        completion: @escaping ([String: Any]) -> Void
    ) {
        guard let accountLease = captureEchoAccountLease(reason: "uiqaB6ColdStart"),
              let vaultID = OwnerTruthVaultID(accountLease.vaultId) else {
            completion(["completed": false, "failureReason": "accountLeaseUnavailable"])
            return
        }

        let productSessionID = "b6-cold-start-uiqa-workflow"
        let workflowHash = PrivacySafeDiagnostics.correlationHash(productSessionID)
        let processID = ProcessInfo.processInfo.processIdentifier

        switch phase {
        case "seed":
            let isolatedRuntime = AccountLeaseRuntime(
                authorityEpoch: accountLease.authorityEpoch
            )
            isolatedRuntime.publish(session: AccountSession(
                subjectId: accountLease.subjectId,
                vaultId: accountLease.vaultId,
                sessionId: accountLease.sessionId,
                tokenFamilyId: "b6-uiqa-token-family",
                sessionVersion: 1,
                generation: accountLease.generation,
                generationId: accountLease.generationId,
                state: .active,
                activatedAt: Date()
            ))
            let featureGate = FeatureGateService.makeQATestService(
                clientBuild: 1,
                accountGeneration: { accountLease.generationId.uuidString },
                policy: { _, _ in
                    FeatureGatePolicySnapshot(
                        accessMode: .useCachedPolicy,
                        policyVersion: "b6-uiqa-policy-v1",
                        policyRevision: 1,
                        emergencyRevision: 0,
                        expiresAt: Date().addingTimeInterval(3_600),
                        featureEnabled: true,
                        releaseVisible: true,
                        reason: "b6UIQAFixtureAllowed"
                    )
                }
            )
            let client = InterviewNaturalInputUIQAClient(
                vaultID: vaultID,
                candidateProposalReviewState: .notReady,
                featureGateService: featureGate
            )
            let coordinator = EchoLiveMemoryCaptureCoordinator(
                accountLease: accountLease,
                client: client,
                accountLeaseRuntime: isolatedRuntime,
                productSessionID: productSessionID,
                organizationStatusTimeout: 30,
                naturalInputPolicyAvailable: {
                    featureGate.requestServerPolicyManagedDecision(for: .echoTextInput).allowed
                },
                candidateReviewPolicyAvailable: {
                    featureGate.requestServerPolicyManagedDecision(
                        for: .ownerTruthCandidateReview
                    ).allowed
                },
                candidateReviewPolicyRefresh: { completion in
                    completion(
                        featureGate.requestServerPolicyManagedDecision(
                            for: .ownerTruthCandidateReview
                        ).allowed
                    )
                }
            )
            retainLiveMemoryCaptureCoordinator(coordinator, asActive: false)
            coordinator.appendOwnerTurn("隔离合成的冷启动恢复验收内容。")
            waitForB6UIQAState(attempt: 0) {
                client.appendRequestCount == 1 && coordinator.isTurnDrainCompleteForUIQA
                    ? ["appendAccepted": true]
                    : nil
            } completion: { appendPayload in
                guard appendPayload != nil else {
                    completion([
                        "completed": false,
                        "phase": "seed",
                        "failureReason": "appendNotAccepted",
                        "processIdentifier": processID,
                        "workflowHash": workflowHash,
                        "captureState": String(describing: coordinator.state),
                        "appendPOSTCount": client.appendRequestCount,
                    ])
                    return
                }
                coordinator.finish()
                self.waitForB6UIQAState(attempt: 0) {
                let followUps = EchoLiveMemoryFollowUpStore.shared.records(for: accountLease)
                guard followUps.contains(where: {
                    $0.productSessionID == productSessionID
                        && $0.reviewBatchID == client.reviewBatchIDForUIQA.rawValue
                }) else {
                    return nil
                }
                return [
                    "completed": true,
                    "phase": "seed",
                    "processIdentifier": processID,
                    "workflowHash": workflowHash,
                    "captureState": String(describing: coordinator.state),
                    "followUpRecordPresent": true,
                    "appendPOSTCount": client.appendRequestCount,
                    "endPOSTCount": client.endRequestCount,
                    "ackPOSTCount": client.acknowledgementRequestCount,
                    "admitPOSTCount": client.admissionRequestCount,
                ]
                } completion: { payload in
                    completion(payload ?? [
                        "completed": false,
                        "phase": "seed",
                        "failureReason": "durableCoordinateNotCreated",
                        "processIdentifier": processID,
                        "workflowHash": workflowHash,
                        "captureState": String(describing: coordinator.state),
                        "appendPOSTCount": client.appendRequestCount,
                        "endPOSTCount": client.endRequestCount,
                        "ackPOSTCount": client.acknowledgementRequestCount,
                        "admitPOSTCount": client.admissionRequestCount,
                        "statusGETCount": client.candidateProposalStatusRequestCount,
                    ])
                }
            }
        case "recover":
            waitForB6UIQAState(attempt: 0) {
                let presentation = self.liveMemoryRecoveryPresentationForTesting()
                guard presentation.statusIdentifier == "echoLiveMemoryRecoveryPendingReview" else {
                    return nil
                }
                let readClient = EchoLiveMemoryRecoveryUIQAReadClient.shared
                return [
                    "completed": true,
                    "phase": "recover",
                    "processIdentifier": processID,
                    "workflowHash": workflowHash,
                    "statusIdentifier": presentation.statusIdentifier ?? "",
                    "statusText": presentation.statusText ?? "",
                    "statusGETCount": readClient.statusReadCount,
                    "tracePresent": readClient.lastTraceID?.isEmpty == false,
                    "attempt": readClient.lastAttempt ?? 0,
                    "recoveryClientIsReadOnly": true,
                    "recoveryAdapter": "DreamJourneyBackendClient",
                    "microphoneStarted": self.isUserControlledLiveSessionOpen,
                    "newCaptureCreated": self.liveMemoryCaptureCoordinator != nil,
                ]
            } completion: { payload in
                completion(payload ?? [
                    "completed": false,
                    "phase": "recover",
                    "failureReason": "automaticRecoveryDidNotReachPendingReview",
                    "processIdentifier": processID,
                    "workflowHash": workflowHash,
                    "statusGETCount": EchoLiveMemoryRecoveryUIQAReadClient.shared.statusReadCount,
                ])
            }
        default:
            completion([
                "completed": false,
                "failureReason": "invalidPhase",
                "processIdentifier": processID,
            ])
        }
    }

    private func waitForB6UIQAState(
        attempt: Int,
        value: @escaping () -> [String: Any]?,
        completion: @escaping ([String: Any]?) -> Void
    ) {
        if let payload = value() {
            completion(payload)
            return
        }
        guard attempt < 80 else {
            completion(nil)
            return
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { [weak self] in
            self?.waitForB6UIQAState(
                attempt: attempt + 1,
                value: value,
                completion: completion
            )
        }
    }

    func runUIQAMicrophoneSmoke() {
        guard bindDialogEngineToEchoAccountLease(reason: "uiqaMicrophoneSmoke") else {
            return
        }
        DialogEngineManager.shared.delegate = self
        DialogEngineManager.shared.setup()
        viewModel.prepareVoiceInteraction()
        guard prepareEchoCaptureAudioSession(reason: "uiqaMicrophoneSmoke") else {
            return
        }
        DialogEngineManager.shared.startDialog(
            sendsGreeting: false,
            usesTurnScopedKnowledgeContext: true,
            lifetimePolicy: .userControlledLive,
            answerAuthority: .dreamJourneyBackend
        )
    }

    func runUIQAEchoVoiceStatePreview() {
        guard let echoAccountLease else { return }
        let roleContextKey = digitalHumanRuntimeContextKey(
            for: DigitalHumanContextStore.shared.current
        )
        for turn in 1..<EchoReplyPacingPolicy.waitAfterUserTurnCount {
            viewModel.beginVoiceInteraction()
            guard viewModel.finishUserVoice(
                text: "第 \(turn) 次想起爸爸小时候的故事",
                accountLease: echoAccountLease,
                resourceOwnerId: echoAccountLease.subjectId,
                roleContextKey: roleContextKey
            ) else { return }
            viewModel.receiveAIReply("我在听，慢慢说。")
        }
        viewModel.beginVoiceInteraction()
        guard viewModel.finishUserVoice(
            text: "第十次想起这件事",
            accountLease: echoAccountLease,
            resourceOwnerId: echoAccountLease.subjectId,
            roleContextKey: roleContextKey
        ) else { return }
        if viewModel.isWaitingForDelayedReply {
            beginDelayedReplyWait()
        }
    }

    func runUIQAEchoListeningStatePreview() {
        viewModel.beginVoiceInteraction()
    }

    func runUIQAEchoSpeakingStatePreview() {
        viewModel.prepareVoiceInteraction()
        viewModel.receiveAIReply("我在这里，慢慢听你说。")
    }

    func runUIQAVoiceSDKReadinessPreview() {
        showsVoiceSDKReadinessPreview = true
        renderVoiceSDKReadinessPreviewIfNeeded()
    }

    func runUIQADigitalHumanLivePanelSmoke(completion: @escaping ([String: Any]) -> Void) {
        guard let panel = digitalHumanLivePanelView else {
            completion([
                "completed": false,
                "panelVisible": false,
                "failureReason": "digitalHumanLivePanelNotCreated"
            ])
            return
        }

        updatePersonaBadge()
        panel.setLocalPreviewEnabled(true)
        viewModel.beginVoiceInteraction()
        let usesProviderVisemeTimeline = QALaunchConfiguration.shared.contains("DJDigitalHumanLipSyncProviderVisemeTimeline")

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) { [weak self] in
            self?.render(state: .thinking)
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.7) { [weak self] in
            self?.viewModel.receiveAIReply("我在这里，慢慢听你说。")
            if usesProviderVisemeTimeline {
                _ = self?.startUIQAMockVisemeTimeline()
            } else {
                _ = self?.startUIQAMeteredPlayback()
            }
        }
        func finishWhenRealAssetReady(attemptsRemaining: Int) {
            panel.snapshot { [weak self] snapshot in
                let audioLevel = snapshot?.audioLevel ?? 0
                let audioLevelSource = snapshot?.audioLevelSource ?? ""
                let lipSyncSource = snapshot?.lipSyncSource ?? ""
                let currentMouthShape = snapshot?.currentMouthShape ?? ""
                let lipSyncFrameCount = snapshot?.lipSyncFrameCount ?? 0
                let panelReady = snapshot?.ready == true
                let hasRealDigitalHumanAsset = snapshot?.hasRealDigitalHumanAsset == true
                let assetVideoReady = snapshot?.assetVideoReady == true
                let hasFallbackAvatar = snapshot?.hasFallbackAvatar == true
                let speaking = snapshot?.stateName == DigitalHumanLiveInteractionState.speaking.rawValue
                let meteringSampleCount = self?.digitalHumanAudioLevelMeter?.meteringSampleCount ?? 0
                let lipSyncReady = usesProviderVisemeTimeline
                    ? audioLevelSource == DigitalHumanPlaybackSource.providerVisemeTimeline.rawValue
                        && lipSyncSource == DigitalHumanPlaybackSource.providerVisemeTimeline.rawValue
                        && lipSyncFrameCount > 0
                        && currentMouthShape != "neutral"
                    : audioLevelSource == DigitalHumanAudioLevelSource.avAudioPlayerMetering.rawValue
                        && meteringSampleCount > 0
                if panelReady && hasRealDigitalHumanAsset && !hasFallbackAvatar && !assetVideoReady && attemptsRemaining > 0 {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
                        finishWhenRealAssetReady(attemptsRemaining: attemptsRemaining - 1)
                    }
                    return
                }
                completion([
                    "completed": panelReady && speaking && audioLevel > 0 && lipSyncReady && hasRealDigitalHumanAsset && assetVideoReady && !hasFallbackAvatar,
                    "panelVisible": !panel.isHidden && panel.alpha > 0,
                    "panelReady": panelReady,
                    "rendererReady": snapshot?.rendererReady ?? false,
                    "hasRealDigitalHumanAsset": hasRealDigitalHumanAsset,
                    "assetVideoReady": assetVideoReady,
                    "hasFallbackAvatar": hasFallbackAvatar,
                    "panelFailed": snapshot?.failed ?? panel.didFail,
                    "stateName": snapshot?.stateName ?? "missing",
                    "audioLevel": audioLevel,
                    "audioLevelSource": audioLevelSource,
                    "lipSyncMode": usesProviderVisemeTimeline ? "providerVisemeTimeline" : "avAudioPlayerMetering",
                    "lipSyncSource": lipSyncSource,
                    "currentMouthShape": currentMouthShape,
                    "lipSyncFrameCount": lipSyncFrameCount,
                    "meteringSampleCount": meteringSampleCount,
                    "personaName": snapshot?.personaName ?? "",
                    "personaSubtitle": snapshot?.personaSubtitle ?? "",
                    "voiceStatusText": self?.voiceStatusLabel.text ?? "",
                    "quoteText": self?.quoteLabel.text ?? ""
                ])
            }
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.45) {
            finishWhenRealAssetReady(attemptsRemaining: 14)
        }
    }

    func runUIQAEchoDigitalHumanLifecycleSmoke(completion: @escaping ([String: Any]) -> Void) {
        guard let panel = digitalHumanLivePanelView else {
            completion([
                "completed": false,
                "failureReason": "digitalHumanLivePanelNotCreated"
            ])
            return
        }

        func forwardUIQALifecycleEvent(
            _ event: AppLifecycleEvent,
            sequence: UInt64
        ) {
            let receipt = AppLifecycleEventReceipt(
                event: event,
                sequence: sequence,
                runtimeContext: nil
            )
            NotificationCenter.default.post(
                name: .djAppLifecycleEventForwarded,
                object: nil,
                userInfo: AppLifecycleEventNotification.userInfo(for: receipt)
            )
        }

        invalidateDigitalHumanLifecycle(reason: "uiqaLifecycleSmokeSetup")
        releaseDigitalHumanRuntime(
            reason: "uiqaLifecycleSmokeSetup",
            resetsAudioOwnerToOrdinaryEcho: true
        )
        let stub = TencentDigitalHumanRuntimeStub(contentView: UIView())
        let profile = DigitalHumanProfile(
            provider: "tencent",
            personaId: "uiqa_lifecycle",
            displayName: "UIQA 生命周期数字人",
            lifecycleMode: .sunlight,
            driveMode: "streamText",
            alphaEnabled: true,
            smartActionEnabled: false,
            assetKey: "uiqa-lifecycle-provider"
        )

        do {
            try stub.configure(profile)
            try stub.open()
        } catch {
            completion([
                "completed": false,
                "failureReason": "stubRuntimeSetupFailed",
                "error": error.localizedDescription
            ])
            return
        }

        digitalHumanRuntime = stub
        digitalHumanRuntimeContextKey = currentDigitalHumanRuntimeContextKey()
        let lifecycleToken = captureDigitalHumanLifecycleToken(reason: "uiqaLifecycleRuntimeBind")
        digitalHumanRuntimeLifecycleGeneration = lifecycleToken.generation
        hasRequestedCloudDigitalHumanRuntime = true
        bindDigitalHumanRuntimeState(stub, lifecycleToken: lifecycleToken)
        panel.hostProviderView(stub.contentView)
        render(state: .listening)
        renderVoiceStatus(text: "正在聆听", isVisible: true)

        let providerViewBefore = panel.subviews.contains {
            $0.accessibilityIdentifier == "digitalHumanLiveProviderView"
        }

        forwardUIQALifecycleEvent(.willResignActive, sequence: 1)
        forwardUIQALifecycleEvent(.didEnterBackground, sequence: 2)
        let backgroundLeaseScheduled = digitalHumanBackgroundReleaseWorkItem != nil
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) { [weak self, weak panel] in
            guard let self,
                  let panel else {
                completion([
                    "completed": false,
                    "failureReason": "lifecycleSmokeReleased"
                ])
                return
            }

            let providerViewAfterSuspend = panel.subviews.contains {
                $0.accessibilityIdentifier == "digitalHumanLiveProviderView"
            }
            let appLifecycleSuspended = self.isSuspendedByAppLifecycle
            let lifecycleSuspended = appLifecycleSuspended
                && self.currentStateIsIdleForUIQA
                && self.voiceStatusLabel.text == "已暂停，轻点话筒继续"

            forwardUIQALifecycleEvent(.willEnterForeground, sequence: 3)
            forwardUIQALifecycleEvent(.didBecomeActive, sequence: 4)

            DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) { [weak self, weak panel] in
                guard let self,
                      let panel else {
                    completion([
                        "completed": false,
                        "failureReason": "lifecycleSmokeReleasedAfterRestore"
                    ])
                    return
                }

                let providerViewAfterRestore = panel.subviews.contains {
                    $0.accessibilityIdentifier == "digitalHumanLiveProviderView"
                }
                let appLifecycleRestored = !self.isSuspendedByAppLifecycle
                let microphoneAutoStart = DialogEngineManager.shared.isDialogActive
                let backgroundLeaseCancelled = self.digitalHumanBackgroundReleaseWorkItem == nil
                let providerViewPreserved = providerViewBefore && providerViewAfterSuspend && providerViewAfterRestore
                let lifecycleRestored = appLifecycleRestored
                    && self.currentStateIsIdleForUIQA
                    && self.voiceStatusLabel.text == "已暂停，轻点话筒继续"

                self.scheduleCloudDigitalHumanRuntimeReleaseForBackgroundIfNeeded()
                let expiryLeaseScheduled = self.digitalHumanBackgroundReleaseWorkItem != nil
                DispatchQueue.main.asyncAfter(
                    deadline: .now() + self.digitalHumanBackgroundReleaseGracePeriod + 0.25
                ) { [weak self, weak panel] in
                    guard let self,
                          let panel else {
                        completion([
                            "completed": false,
                            "failureReason": "lifecycleSmokeReleasedAfterExpiry"
                        ])
                        return
                    }

                    let runtimeReleasedAfterGrace = self.digitalHumanRuntime == nil
                    let backgroundLeaseExpired = self.digitalHumanBackgroundReleaseWorkItem == nil
                        && runtimeReleasedAfterGrace
                    completion([
                        "completed": lifecycleSuspended
                            && lifecycleRestored
                            && backgroundLeaseScheduled
                            && backgroundLeaseCancelled
                            && providerViewPreserved
                            && expiryLeaseScheduled
                            && backgroundLeaseExpired
                            && microphoneAutoStart == false,
                        "appLifecycleSuspended": appLifecycleSuspended,
                        "appLifecycleRestored": appLifecycleRestored,
                        "lifecycleSuspended": lifecycleSuspended,
                        "lifecycleRestored": lifecycleRestored,
                        "backgroundLeaseScheduled": backgroundLeaseScheduled,
                        "backgroundLeaseCancelled": backgroundLeaseCancelled,
                        "backgroundLeaseExpired": backgroundLeaseExpired,
                        "runtimeReleasedAfterGrace": runtimeReleasedAfterGrace,
                        "providerViewPreserved": providerViewPreserved,
                        "providerViewBefore": providerViewBefore,
                        "providerViewAfterSuspend": providerViewAfterSuspend,
                        "providerViewAfterRestore": providerViewAfterRestore,
                        "microphoneAutoStart": microphoneAutoStart,
                        "audioOwner": self.currentEchoAudioOwner.rawValue,
                        "voiceStatusText": self.voiceStatusLabel.text ?? "",
                        "selectedRuntimeState": String(describing: self.digitalHumanRuntime?.state),
                        "panelVisible": !panel.isHidden && panel.alpha > 0,
                    ])
                }
            }
        }
    }

    #if UI_QA_SIMULATOR && targetEnvironment(simulator)
    /// Exercises the actual Echo audio-owner integration with an injected driver.
    /// This deliberately avoids microphone, local TTS, and provider calls; it is
    /// a simulator-only regression for lease ordering after G0 enforcement.
    func runUIQAEchoAudioOwnerCoordinatorSmoke(completion: @escaping ([String: Any]) -> Void) {
        guard let echoAccountLease,
              validateEchoAccountLease(
                at: .request,
                expected: echoAccountLease,
                reason: "uiqaEchoAudioOwnerCoordinatorSmoke"
              ) else {
            completion([
                "completed": false,
                "failureReason": "missingEchoAccountLease",
            ])
            return
        }

        let previousCoordinator = audioSessionCoordinator
        let previousLease = activeEchoAudioOwnerLease
        let previousAudioOwner = currentEchoAudioOwner
        let driver = AudioOwnerLeaseQASupport.EchoAudioOwnerDriver()
        let coordinator = AudioSessionCoordinator(driver: driver)
        audioSessionCoordinator = coordinator
        activeEchoAudioOwnerLease = nil

        defer {
            if let activeLease = activeEchoAudioOwnerLease {
                _ = audioSessionCoordinator.release(activeLease)
            }
            audioSessionCoordinator = previousCoordinator
            activeEchoAudioOwnerLease = previousLease
            currentEchoAudioOwner = previousAudioOwner
        }

        let captureAcquired = acquireEchoRuntimeAudioOwner(
            .echoCapture,
            priority: .echoCapture,
            reason: "uiqaCapture"
        )
        guard captureAcquired,
              let firstCaptureLease = activeEchoAudioOwnerLease,
              firstCaptureLease.owner == .echoCapture else {
            completion([
                "completed": false,
                "captureAcquired": false,
                "failureReason": "captureLeaseNotAcquired",
            ])
            return
        }

        let tencentAcquired = acquireEchoRuntimeAudioOwner(
            .tencentDigitalHumanPlayback,
            priority: .tencentDigitalHumanPlayback,
            reason: "uiqaTencentPreempt"
        )
        guard tencentAcquired,
              let firstTencentLease = activeEchoAudioOwnerLease,
              firstTencentLease.owner == .tencentDigitalHumanPlayback else {
            completion([
                "completed": false,
                "captureAcquired": true,
                "tencentPreemptedCapture": false,
                "failureReason": "tencentLeaseNotAcquired",
            ])
            return
        }

        let staleCaptureReleaseIgnored: Bool
        switch coordinator.release(firstCaptureLease) {
        case let .ignoredStaleRelease(active):
            staleCaptureReleaseIgnored = active?.leaseId == firstTencentLease.leaseId
        default:
            staleCaptureReleaseIgnored = false
        }

        releaseEchoAudioOwnerLease(
            expectedOwner: .tencentDigitalHumanPlayback,
            reason: "uiqaTencentPlaybackFinished"
        )
        let captureRestored = acquireEchoRuntimeAudioOwner(
            .echoCapture,
            priority: .echoCapture,
            reason: "uiqaCaptureRestored"
        )
        guard captureRestored,
              let restoredCaptureLease = activeEchoAudioOwnerLease,
              restoredCaptureLease.owner == .echoCapture else {
            completion([
                "completed": false,
                "captureAcquired": true,
                "tencentPreemptedCapture": true,
                "staleCaptureReleaseIgnored": staleCaptureReleaseIgnored,
                "captureRestored": false,
                "failureReason": "captureLeaseNotRestored",
            ])
            return
        }

        driver.rejectedOwners.insert(.tencentDigitalHumanPlayback)
        let tencentFailureRejected = !acquireEchoRuntimeAudioOwner(
            .tencentDigitalHumanPlayback,
            priority: .tencentDigitalHumanPlayback,
            reason: "uiqaTencentActivationFailure"
        )
        let tencentFailurePreservedCapture = tencentFailureRejected
            && activeEchoAudioOwnerLease?.leaseId == restoredCaptureLease.leaseId
        driver.rejectedOwners.remove(.tencentDigitalHumanPlayback)

        let roleSwitchCoordinator = AudioSessionCoordinator(driver: driver)
        let oldRoleScope = AudioOwnerLeaseScope(
            accountGeneration: echoAccountLease.generation,
            runtimeGeneration: 10_001
        )
        let newRoleScope = AudioOwnerLeaseScope(
            accountGeneration: echoAccountLease.generation,
            runtimeGeneration: 10_002
        )
        let staleRoleReleaseIgnored: Bool
        switch roleSwitchCoordinator.acquire(
            .echoCapture,
            priority: .echoCapture,
            scope: oldRoleScope
        ) {
        case let .acquired(oldRoleLease):
            switch roleSwitchCoordinator.acquire(
                .tencentDigitalHumanPlayback,
                priority: .tencentDigitalHumanPlayback,
                scope: newRoleScope
            ) {
            case let .preempted(_, currentRoleLease):
                switch roleSwitchCoordinator.release(oldRoleLease) {
                case let .ignoredStaleRelease(active):
                    staleRoleReleaseIgnored = active?.leaseId == currentRoleLease.leaseId
                default:
                    staleRoleReleaseIgnored = false
                }
                _ = roleSwitchCoordinator.release(currentRoleLease)
            default:
                staleRoleReleaseIgnored = false
            }
        default:
            staleRoleReleaseIgnored = false
        }

        releaseEchoAudioOwnerLease(
            expectedOwner: .echoCapture,
            reason: "uiqaCaptureStop"
        )
        let snapshot = coordinator.diagnosticsSnapshot()
        let finalOwner = snapshot.activeLease?.owner.rawValue ?? "none"
        let completed = captureAcquired
            && tencentAcquired
            && staleCaptureReleaseIgnored
            && captureRestored
            && tencentFailurePreservedCapture
            && staleRoleReleaseIgnored
            && finalOwner == "none"

        renderVoiceStatus(
            text: completed ? "音频归属校验完成" : "音频归属校验失败",
            isVisible: true
        )
        completion([
            "completed": completed,
            "captureAcquired": captureAcquired,
            "tencentPreemptedCapture": tencentAcquired,
            "staleCaptureReleaseIgnored": staleCaptureReleaseIgnored,
            "captureRestored": captureRestored,
            "tencentFailurePreservedCapture": tencentFailurePreservedCapture,
            "staleRoleReleaseIgnored": staleRoleReleaseIgnored,
            "transitionCount": snapshot.transitionCount,
            "driverActivationCount": driver.activationCount,
            "driverDeactivationCount": driver.deactivationCount,
            "finalOwner": finalOwner,
            "voiceStatusText": voiceStatusLabel.text ?? "",
        ])
    }
    #endif

    /// Verifies the explicitly QA-only natural-input entry without starting a
    /// voice turn, Digital Human session, or private interview write.
    func runUIQAOwnerTruthInterviewNaturalInputEchoSurfaceSmoke(
        retryCount: Int = 0,
        completion: @escaping ([String: Any]) -> Void
    ) {
        guard shouldShowOwnerTruthInterviewNaturalInputEntry else {
            completion([
                "completed": false,
                "entryVisible": false,
                "sheetPresented": false,
                "failureReason": "entryGateDisabled"
            ])
            return
        }

        guard let accountLease = echoAccountLease,
              validateEchoAccountLease(
                at: .request,
                expected: accountLease,
                reason: "uiqaOwnerTruthNaturalInputEchoSurface"
              ) else {
            guard retryCount < 12 else {
                completion([
                    "completed": false,
                    "entryVisible": false,
                    "sheetPresented": false,
                    "failureReason": "accountLeaseUnavailable"
                ])
                return
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) { [weak self] in
                self?.runUIQAOwnerTruthInterviewNaturalInputEchoSurfaceSmoke(
                    retryCount: retryCount + 1,
                    completion: completion
                )
            }
            return
        }

        guard presentedViewController == nil else {
            completion([
                "completed": false,
                "entryVisible": false,
                "sheetPresented": false,
                "failureReason": "unexpectedPresentedViewController"
            ])
            return
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) { [weak self] in
            guard let self else {
                completion([
                    "completed": false,
                    "entryVisible": false,
                    "sheetPresented": false,
                    "failureReason": "echoReleased"
                ])
                return
            }

            let entryVisible = self.ownerTruthInterviewNaturalInputEntryButton.window != nil
                && !self.ownerTruthInterviewNaturalInputEntryButton.isHidden
                && self.ownerTruthInterviewNaturalInputEntryButton.alpha > 0.01
            guard entryVisible else {
                completion([
                    "completed": false,
                    "entryVisible": false,
                    "sheetPresented": false,
                    "failureReason": "entryNotVisible"
                ])
                return
            }

            let controller = OwnerTruthInterviewNaturalInputUIQASmoke.makePreviewViewController(
                accountLease: accountLease
            )
            let navigationController = UINavigationController(rootViewController: controller)
            navigationController.modalPresentationStyle = .pageSheet
            if let sheet = navigationController.sheetPresentationController {
                sheet.detents = [.medium(), .large()]
                sheet.prefersGrabberVisible = true
            }
            self.present(navigationController, animated: false) {
                let sheetPresented = self.presentedViewController === navigationController
                    && navigationController.topViewController === controller
                var result: [String: Any] = [
                    "completed": sheetPresented,
                    "entryVisible": entryVisible,
                    "sheetPresented": sheetPresented,
                    "entryAccessibilityIdentifier": self.ownerTruthInterviewNaturalInputEntryButton.accessibilityIdentifier ?? "",
                    "voiceTurnStarted": false,
                    "digitalHumanSessionStarted": false,
                    "backendNetworkStarted": false,
                    "persistentInterviewWriteStarted": false,
                    "publicRouteChanged": false,
                    "launchArguments": [
                        QALaunchScenario.ownerTruthInterviewNaturalInputEchoSurfaceSmoke.rawValue,
                        OwnerTruthCandidateReviewQAGate.launchArgument,
                        QALaunchFeature.ownerTruthInterviewNaturalInputEntry.rawValue
                    ]
                ]
                if !sheetPresented {
                    result["failureReason"] = "sheetNotPresented"
                }
                completion(result)
            }
        }
    }

    /// Verifies only the product presentation under the UIQA simulator. The
    /// harness uses an in-memory client and never treats this as a release
    /// policy grant or a backend write.
    func runUIQAOwnerTruthInterviewNaturalInputProductSurfaceSmoke(
        retryCount: Int = 0,
        candidateProposalReviewState: OwnerTruthInterviewCandidateProposalReviewState = .notReady,
        launchScenario: QALaunchScenario = .ownerTruthInterviewNaturalInputProductSurfaceSmoke,
        completion: @escaping ([String: Any]) -> Void
    ) {
        guard !shouldShowOwnerTruthInterviewNaturalInputEntry else {
            completion([
                "completed": false,
                "productEntryVisible": false,
                "sheetPresented": false,
                "failureReason": "qaEntryMustRemainDisabled"
            ])
            return
        }

        guard let accountLease = echoAccountLease,
              validateEchoAccountLease(
                at: .request,
                expected: accountLease,
                reason: "uiqaOwnerTruthNaturalInputProductSurface"
              ) else {
            guard retryCount < 12 else {
                completion([
                    "completed": false,
                    "productEntryVisible": false,
                    "sheetPresented": false,
                    "failureReason": "accountLeaseUnavailable"
                ])
                return
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) { [weak self] in
                self?.runUIQAOwnerTruthInterviewNaturalInputProductSurfaceSmoke(
                    retryCount: retryCount + 1,
                    candidateProposalReviewState: candidateProposalReviewState,
                    launchScenario: launchScenario,
                    completion: completion
                )
            }
            return
        }

        guard presentedViewController == nil else {
            completion([
                "completed": false,
                "productEntryVisible": false,
                "sheetPresented": false,
                "failureReason": "unexpectedPresentedViewController"
            ])
            return
        }

        // Cancel any asynchronous policy refresh from normal controller setup.
        // The preview below is explicitly marked UIQA-only and does not replace
        // the production fresh-policy requirement.
        ownerTruthInterviewNaturalInputPolicyRefreshGeneration &+= 1
        isOwnerTruthInterviewNaturalInputProductPolicyPermitted = true
        updateOwnerTruthInterviewNaturalInputProductEntryVisibility()

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) { [weak self] in
            guard let self else {
                completion([
                    "completed": false,
                    "productEntryVisible": false,
                    "sheetPresented": false,
                    "failureReason": "echoReleased"
                ])
                return
            }

            let productEntryVisible = self.ownerTruthInterviewNaturalInputProductEntryButton.window != nil
                && !self.ownerTruthInterviewNaturalInputProductEntryButton.isHidden
                && self.ownerTruthInterviewNaturalInputProductEntryButton.alpha > 0.01
            let qaEntryVisible = self.ownerTruthInterviewNaturalInputEntryButton.window != nil
                && !self.ownerTruthInterviewNaturalInputEntryButton.isHidden
                && self.ownerTruthInterviewNaturalInputEntryButton.alpha > 0.01
            guard productEntryVisible, !qaEntryVisible else {
                completion([
                    "completed": false,
                    "productEntryVisible": productEntryVisible,
                    "qaEntryVisible": qaEntryVisible,
                    "sheetPresented": false,
                    "failureReason": "productEntryVisibilityMismatch"
                ])
                return
            }

            let reviewReadyScenario = candidateProposalReviewState == .reviewReady
                ? OwnerTruthInterviewCandidateProposalReviewReadyUIQAScenario(
                    accountLease: accountLease
                )
                : nil
            let controller = reviewReadyScenario?.makePreviewViewController()
                ?? OwnerTruthInterviewNaturalInputUIQASmoke.makePreviewViewController(
                    accountLease: accountLease,
                    presentation: .product,
                    postNarrativeContinuationState: .reviewPending,
                    reviewBatchAcknowledgementPolicyAvailable: { true },
                    candidateProposalAdmissionPolicyAvailable: { true },
                    candidateProposalStatusPolicyAvailable: { true }
                )
            let navigationController = UINavigationController(rootViewController: controller)
            navigationController.modalPresentationStyle = .pageSheet
            if let sheet = navigationController.sheetPresentationController {
                sheet.detents = [.medium(), .large()]
                sheet.prefersGrabberVisible = true
            }
            self.present(navigationController, animated: false) {
                let sheetPresented = self.presentedViewController === navigationController
                    && navigationController.topViewController === controller
                if !sheetPresented {
                    completion([
                        "completed": false,
                        "productEntryVisible": productEntryVisible,
                        "qaEntryVisible": qaEntryVisible,
                        "sheetPresented": false,
                        "failureReason": "sheetNotPresented"
                    ])
                    return
                }

                // The in-memory client lets the product-only UIQA surface
                // exercise a complete private-interview exit while preserving
                // the invariant that no network, voice, Digital Human, or
                // persistent interview write is started.
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.08) {
                    let endActionHiddenBeforeNarrative = !controller
                        .isEndSessionActionVisibleForUIQA
                    controller.submitQAFixture(
                        OwnerTruthInterviewNaturalInputUIQASmoke.fixtureText
                    )
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.08) {
                        let inputRecorded = controller.renderedStateForUIQA
                            .latestReceipt?.messageSequence == 1
                        let endActionVisibleAfterNarrative = controller
                            .isEndSessionActionVisibleForUIQA
                        let productBoundaryControlsVisible = controller
                            .areProductBoundaryActionsVisibleForUIQA
                        let qaOnlyBoundaryControlsHidden = controller
                            .areQAOnlyBoundaryActionsHiddenForProductUIQA
                        controller.endQAFixture()
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.08) {
                            let finalState = controller.renderedStateForUIQA
                            let continuation = finalState.continuation
                            let summaryState = continuation?.state.rawValue ?? ""
                            let summaryStatus = controller.renderedStatusTextForUIQA
                            let summaryDetail = controller.renderedDetailTextForUIQA
                            let reviewBatchAcknowledgementEntryVisible = controller
                                .isReviewBatchAcknowledgementEntryVisibleForUIQA
                            let endActionHiddenAfterEnd = !controller
                                .isEndSessionActionVisibleForUIQA
                            let endedSession = finalState.latestReceipt?.lifecycle == .ended
                                && finalState.latestReceipt?.messageSequence == nil
                            let summaryRendered = summaryState == "reviewPending"
                                && summaryStatus == "这段分享等待整理"
                                && summaryDetail == "确认本次分享后，你可以选择是否开始整理。"
                            controller.acknowledgeReviewBatchForUIQA()
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.08) {
                                let acknowledgementState = controller
                                    .reviewBatchAcknowledgementStateForUIQA
                                let acknowledgementRendered = acknowledgementState.phase == .acknowledged
                                    && controller.renderedStatusTextForUIQA == "这段分享已确认"
                                    && controller.renderedDetailTextForUIQA
                                        == "你可以开始整理本次内容；整理完成后，仍由你确认是否保存为记忆。"
                                    && !controller.isReviewBatchAcknowledgementEntryVisibleForUIQA
                                let candidateProposalAdmissionEntryVisible = controller
                                    .isCandidateProposalAdmissionEntryVisibleForUIQA
                                controller.startCandidateProposalAdmissionForUIQA()
                                DispatchQueue.main.asyncAfter(deadline: .now() + 0.08) {
                                    let admissionState = controller
                                        .candidateProposalAdmissionStateForUIQA
                                    let candidateProposalStatusState = controller
                                        .candidateProposalStatusStateForUIQA
                                    let candidateProposalStatusEntryVisible = controller
                                        .isCandidateProposalStatusEntryVisibleForUIQA
                                    let expectedCandidateProposalStatusText = candidateProposalReviewState
                                        == .reviewReady
                                        ? "整理完成，等待你确认"
                                        : "这段分享正在整理"
                                    let expectedCandidateProposalDetailText = candidateProposalReviewState
                                        == .reviewReady
                                        ? "候选记忆仍需由你逐项确认，未确认不会写入正式记忆。"
                                        : "整理完成后，仍会等待你确认是否保存为记忆。"
                                    let admissionRendered = admissionState.phase == .admitted
                                        && candidateProposalStatusState.phase == .ready
                                        && candidateProposalStatusState.status?.candidateReviewState
                                            == candidateProposalReviewState
                                        && controller.renderedStatusTextForUIQA
                                            == expectedCandidateProposalStatusText
                                        && controller.renderedDetailTextForUIQA
                                            == expectedCandidateProposalDetailText
                                        && !controller.isCandidateProposalAdmissionEntryVisibleForUIQA
                                        && candidateProposalStatusEntryVisible
                                    let candidateProposalStatusEntryTitle = controller
                                        .candidateProposalStatusEntryTitleForUIQA
                                    controller.revealProductBoundaryActionsForUIQA()
                                    let productBoundaryActionsReachable = controller
                                        .areProductBoundaryActionsReachableForUIQA

                                    func complete(
                                        confirmationInboxPresented: Bool,
                                        focusedReviewBatchMatches: Bool,
                                        focusedInboxVisibleItemCount: Int,
                                        otherReviewBatchHidden: Bool,
                                        confirmationDetailPresented: Bool
                                    ) {
                                        let reviewReadyHandoffRendered = candidateProposalReviewState
                                            != .reviewReady
                                            || (
                                                confirmationInboxPresented
                                                    && focusedReviewBatchMatches
                                                    && focusedInboxVisibleItemCount == 1
                                                    && otherReviewBatchHidden
                                                    && !confirmationDetailPresented
                                                    && candidateProposalStatusEntryTitle == "查看待确认内容"
                                                    && reviewReadyScenario?.confirmationInboxReadCount == 1
                                            )
                                        var result: [String: Any] = [
                                        "completed": controller.title == "今天想聊点什么？"
                                            && endActionHiddenBeforeNarrative
                                            && inputRecorded
                                            && endActionVisibleAfterNarrative
                                            && endedSession
                                            && endActionHiddenAfterEnd
                                            && summaryRendered
                                            && controller.isTranscriptClearForQA
                                            && productBoundaryControlsVisible
                                            && productBoundaryActionsReachable
                                            && qaOnlyBoundaryControlsHidden
                                            && reviewBatchAcknowledgementEntryVisible
                                            && acknowledgementRendered
                                            && candidateProposalAdmissionEntryVisible
                                            && admissionRendered
                                            && reviewReadyHandoffRendered,
                                        "productEntryVisible": productEntryVisible,
                                        "qaEntryVisible": qaEntryVisible,
                                        "sheetPresented": true,
                                        "entryAccessibilityIdentifier": self.ownerTruthInterviewNaturalInputProductEntryButton.accessibilityIdentifier ?? "",
                                        "sheetTitle": controller.title ?? "",
                                        "inputRecorded": inputRecorded,
                                        "endActionHiddenBeforeNarrative": endActionHiddenBeforeNarrative,
                                        "endActionVisibleAfterNarrative": endActionVisibleAfterNarrative,
                                        "endedSession": endedSession,
                                        "endActionHiddenAfterEnd": endActionHiddenAfterEnd,
                                        "summaryState": summaryState,
                                        "summaryStatus": summaryStatus,
                                        "summaryDetail": summaryDetail,
                                        "transcriptCleared": controller.isTranscriptClearForQA,
                                        "productBoundaryControlsVisible": productBoundaryControlsVisible,
                                        "productBoundaryActionsReachable": productBoundaryActionsReachable,
                                        "qaOnlyBoundaryControlsHidden": qaOnlyBoundaryControlsHidden,
                                        "reviewBatchAcknowledgementEntryVisible": reviewBatchAcknowledgementEntryVisible,
                                        "reviewBatchAcknowledgementPhase": String(describing: acknowledgementState.phase),
                                        "reviewBatchAcknowledgementRendered": acknowledgementRendered,
                                        "candidateProposalAdmissionEntryVisible": candidateProposalAdmissionEntryVisible,
                                        "candidateProposalAdmissionPhase": String(describing: admissionState.phase),
                                        "candidateProposalAdmissionRendered": admissionRendered,
                                        "candidateProposalStatusPhase": String(describing: candidateProposalStatusState.phase),
                                        "candidateProposalReviewState": candidateProposalStatusState.status?.candidateReviewState.rawValue ?? "",
                                        "candidateProposalStatusEntryVisible": candidateProposalStatusEntryVisible,
                                        "candidateProposalStatusEntryTitle": candidateProposalStatusEntryTitle,
                                        "candidateProposalStatusRequestCount": reviewReadyScenario?
                                            .candidateProposalStatusRequestCount ?? 0,
                                        "candidateProposalConfirmationInboxPresented": confirmationInboxPresented,
                                        "candidateProposalFocusedReviewBatchMatches": focusedReviewBatchMatches,
                                        "candidateProposalFocusedInboxVisibleItemCount": focusedInboxVisibleItemCount,
                                        "candidateProposalOtherReviewBatchHidden": otherReviewBatchHidden,
                                        "candidateProposalConfirmationInboxReadCount": reviewReadyScenario?
                                            .confirmationInboxReadCount ?? 0,
                                        "candidateProposalConfirmationDetailPresented": confirmationDetailPresented,
                                        "candidateProposalConfirmationActionTriggered": false,
                                        "inMemoryPreview": true,
                                        "releasePolicyBypassedForPreview": true,
                                        "voiceTurnStarted": false,
                                        "digitalHumanSessionStarted": false,
                                        "backendNetworkStarted": false,
                                        "persistentInterviewWriteStarted": false,
                                        "launchArguments": [
                                            launchScenario.rawValue
                                        ]
                                    ]
                                    if !(result["completed"] as? Bool ?? false) {
                                        result["failureReason"] = candidateProposalReviewState == .reviewReady
                                            ? "reviewReadyFocusedConfirmationInboxNotRendered"
                                            : "productEndFlowNotRendered"
                                    }
                                    completion(result)
                                    }

                                    guard candidateProposalReviewState == .reviewReady else {
                                        complete(
                                            confirmationInboxPresented: false,
                                            focusedReviewBatchMatches: false,
                                            focusedInboxVisibleItemCount: 0,
                                            otherReviewBatchHidden: true,
                                            confirmationDetailPresented: false
                                        )
                                        return
                                    }

                                    controller.checkCandidateProposalStatusForUIQA()
                                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.12) {
                                        let handoffObservation = reviewReadyScenario?
                                            .observeHandoff(in: navigationController)
                                        complete(
                                            confirmationInboxPresented: handoffObservation?
                                                .confirmationInboxPresented ?? false,
                                            focusedReviewBatchMatches: handoffObservation?
                                                .focusedReviewBatchMatches ?? false,
                                            focusedInboxVisibleItemCount: handoffObservation?
                                                .focusedInboxVisibleItemCount ?? 0,
                                            otherReviewBatchHidden: handoffObservation?
                                                .otherReviewBatchHidden ?? false,
                                            confirmationDetailPresented: handoffObservation?
                                                .confirmationDetailPresented ?? false
                                        )
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
    }

    func runUIQAOwnerTruthInterviewCandidateProposalReviewReadySmoke(
        completion: @escaping ([String: Any]) -> Void
    ) {
        runUIQAOwnerTruthInterviewNaturalInputProductSurfaceSmoke(
            candidateProposalReviewState: .reviewReady,
            launchScenario: .ownerTruthInterviewCandidateProposalReviewReadySmoke,
            completion: completion
        )
    }

    /// Exercises the ordinary Echo controller path without starting a microphone,
    /// local TTS, or Digital Human provider. The shell runner starts the app
    /// twice, so this method only owns one deterministic in-process turn flow.
    func runUIQAEchoContinuousTurnSmoke(completion: @escaping ([String: Any]) -> Void) {
        guard let echoAccountLease,
              validateEchoAccountLease(
                at: .request,
                expected: echoAccountLease,
                reason: "uiqaContinuousTurnSmoke"
              ) else {
            completion([
                "completed": false,
                "failureReason": "missingEchoAccountLease",
            ])
            return
        }

        let roleContextKey = digitalHumanRuntimeContextKey(
            for: DigitalHumanContextStore.shared.current
        )
        transcriptEntries.removeAll()
        quoteLabel.text = nil
        resetEchoViewModelToIdle()

        func stateName() -> String {
            switch currentState {
            case .idle:
                return "idle"
            case .starting:
                return "starting"
            case .listening:
                return "listening"
            case .thinking:
                return "thinking"
            case .waitingReply:
                return "waitingReply"
            case .awaitingReplyDelivery:
                return "awaitingReplyDelivery"
            case .neutralSafety:
                return "neutralSafety"
            case .speaking:
                return "speaking"
            case .replied:
                return "replied"
            case .error:
                return "error"
            }
        }

        func runTurn(
            userText: String,
            replyText: String,
            completion: @escaping (_ completed: Bool) -> Void
        ) {
            viewModel.prepareVoiceInteraction()
            DispatchQueue.main.async { [weak self] in
                guard let self else {
                    completion(false)
                    return
                }
                let prepared = stateName() == "starting"
                self.viewModel.beginVoiceInteraction()

                DispatchQueue.main.async { [weak self] in
                    guard let self else {
                        completion(false)
                        return
                    }
                    let listening = stateName() == "listening"
                    let acceptedUserTurn = self.viewModel.finishUserVoice(
                        text: userText,
                        accountLease: echoAccountLease,
                        resourceOwnerId: echoAccountLease.subjectId,
                        roleContextKey: roleContextKey
                    )

                    DispatchQueue.main.async { [weak self] in
                        guard let self else {
                            completion(false)
                            return
                        }
                        let thinking = acceptedUserTurn && stateName() == "thinking"
                        self.viewModel.receiveAIReply(replyText)

                        DispatchQueue.main.async { [weak self] in
                            guard let self else {
                                completion(false)
                                return
                            }
                            let speaking = stateName() == "speaking"
                            let delivered = self.viewModel.markReplyDelivered(
                                accountLease: echoAccountLease
                            )

                            DispatchQueue.main.async { [weak self] in
                                guard let self else {
                                    completion(false)
                                    return
                                }
                                completion(
                                    prepared
                                        && listening
                                        && thinking
                                        && speaking
                                        && delivered
                                        && stateName() == "replied"
                                )
                            }
                        }
                    }
                }
            }
        }

        func runTypedFinishCycles(
            remaining: Int,
            completedCount: Int,
            allMicButtonsEnabled: Bool,
            completion: @escaping (_ completedCount: Int, _ allMicButtonsEnabled: Bool) -> Void
        ) {
            guard remaining > 0 else {
                completion(completedCount, allMicButtonsEnabled)
                return
            }
            runTurn(
                userText: "UIQA 文字会话结束状态测试。",
                replyText: "这是一条不会发送给服务端的 UIQA 回答。"
            ) { [weak self] turnCompleted in
                guard let self else {
                    completion(completedCount, false)
                    return
                }
                self.finishTypedEchoInteractionState()
                DispatchQueue.main.async {
                    let resetToIdle = stateName() == "idle"
                    let micEnabled = self.micButton.isEnabled
                    runTypedFinishCycles(
                        remaining: remaining - 1,
                        completedCount: completedCount + (turnCompleted && resetToIdle ? 1 : 0),
                        allMicButtonsEnabled: allMicButtonsEnabled && micEnabled,
                        completion: completion
                    )
                }
            }
        }

        DispatchQueue.main.async { [weak self] in
            guard let self else {
                completion([
                    "completed": false,
                    "failureReason": "controllerReleasedBeforeFirstTurn",
                ])
                return
            }

            runTurn(
                userText: "今天想起了小时候一起散步的事。",
                replyText: "我记得这份温柔的回忆。"
            ) { [weak self] firstTurnCompleted in
                guard let self else {
                    completion([
                        "completed": false,
                        "failureReason": "controllerReleasedBeforeSecondTurn",
                    ])
                    return
                }

                runTurn(
                    userText: "我还想再说一点那天的心情。",
                    replyText: "好的，我会继续认真听你说。"
                ) { [weak self] secondTurnCompleted in
                    guard let self else {
                        completion([
                            "completed": false,
                            "failureReason": "controllerReleasedBeforeStop",
                        ])
                        return
                    }

                    // Use the same controller stop semantics as the mic button.
                    // No dialog is active in this local scenario, so it must
                    // safely return the reducer to idle without touching a provider.
                    self.stopVoiceCapture()
                    DispatchQueue.main.async { [weak self] in
                        guard let self else {
                            completion([
                                "completed": false,
                                "failureReason": "controllerReleasedAfterStop",
                            ])
                            return
                        }

                        let stoppedToIdle = stateName() == "idle"
                        runTypedFinishCycles(
                            remaining: 10,
                            completedCount: 0,
                            allMicButtonsEnabled: true
                        ) { [weak self] typedFinishCycleCount, micEnabledAfterTypedFinish in
                            guard let self,
                                  let tabBarController = self.tabBarController,
                                  (tabBarController.viewControllers?.count ?? 0) > 1 else {
                                completion([
                                    "completed": false,
                                    "failureReason": "missingRootTabAfterTypedFinishCycles",
                                ])
                                return
                            }
                            let transcriptCountBeforeStaleReply = self.transcriptEntries.count
                            self.viewModel.receiveAIReply("这是一条结束后的旧回信，不应显示。")

                            DispatchQueue.main.async { [weak self] in
                                guard let self else {
                                    completion([
                                        "completed": false,
                                        "failureReason": "controllerReleasedAfterTypedFinish",
                                    ])
                                    return
                                }
                                let staleReplyRejected = stateName() == "idle"
                                    && self.transcriptEntries.count == transcriptCountBeforeStaleReply
                                let transcriptCountBeforeLeave = self.transcriptEntries.count
                                tabBarController.selectedIndex = 0

                                DispatchQueue.main.async { [weak self] in
                                    guard let self else {
                                        completion([
                                            "completed": false,
                                            "failureReason": "controllerReleasedAfterLeave",
                                        ])
                                        return
                                    }
                                    let leftEchoTab = tabBarController.selectedIndex == 0
                                    tabBarController.selectedIndex = 1

                                    DispatchQueue.main.async { [weak self] in
                                        guard let self else {
                                            completion([
                                                "completed": false,
                                                "failureReason": "controllerReleasedAfterReentry",
                                            ])
                                            return
                                        }
                                        let reenteredEchoTab = tabBarController.selectedIndex == 1
                                            && self.view.window != nil
                                            && stateName() == "idle"
                                        completion([
                                            "completed": firstTurnCompleted
                                                && secondTurnCompleted
                                                && stoppedToIdle
                                                && typedFinishCycleCount == 10
                                                && micEnabledAfterTypedFinish
                                                && staleReplyRejected
                                                && leftEchoTab
                                                && reenteredEchoTab
                                                && transcriptCountBeforeLeave == 4,
                                            "firstTurnCompleted": firstTurnCompleted,
                                            "secondTurnCompleted": secondTurnCompleted,
                                            "stoppedToIdle": stoppedToIdle,
                                            "typedFinishCycleCount": typedFinishCycleCount,
                                            "micEnabledAfterTypedFinish": micEnabledAfterTypedFinish,
                                            "staleReplyRejected": staleReplyRejected,
                                            "leftEchoTab": leftEchoTab,
                                            "reenteredEchoTab": reenteredEchoTab,
                                            "finalState": stateName(),
                                            "transcriptEntryCountBeforeLeave": transcriptCountBeforeLeave,
                                            "transcriptEntryCount": self.transcriptEntries.count,
                                            "digitalHumanPanelVisible": self.digitalHumanLivePanelView != nil,
                                            "audioOwner": self.currentEchoAudioOwner.rawValue,
                                        ])
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
    }

    private var currentStateIsIdleForUIQA: Bool {
        if case .idle = currentState {
            return true
        }
        return false
    }

    private func prepareEchoTraceUIQAOwner(fallbackOwnerUserId: String) -> (ownerUserId: String, isTemporary: Bool) {
        if let ownerUserId = UserManager.shared.currentUser?.id {
            return (ownerUserId, false)
        }
        EchoTraceAccountLifecycle.activate(ownerUserId: fallbackOwnerUserId)
        return (fallbackOwnerUserId, true)
    }

    private func restoreEchoTraceUIQAOwner(_ context: (ownerUserId: String, isTemporary: Bool)) {
        guard context.isTemporary else { return }
        EchoTraceAccountLifecycle.invalidateAndClear(ownerUserId: context.ownerUserId)
    }

    private func preserveTemporaryEchoTraceUIQAExport(
        _ sourceURL: URL,
        ownerContext: (ownerUserId: String, isTemporary: Bool)
    ) throws -> URL {
        guard ownerContext.isTemporary,
              let documentsURL = FileManager.default.urls(
                for: .documentDirectory,
                in: .userDomainMask
              ).first else {
            return sourceURL
        }
        let destinationURL = documentsURL.appendingPathComponent(sourceURL.lastPathComponent)
        try? FileManager.default.removeItem(at: destinationURL)
        try FileManager.default.copyItem(at: sourceURL, to: destinationURL)
        return destinationURL
    }

    private func readRedactedEchoExportArray(from data: Data) throws -> [[String: Any]] {
        guard let values = try JSONSerialization.jsonObject(with: data) as? [[String: Any]] else {
            throw EchoTraceStorageError.noEvidenceBundle
        }
        return values
    }

    private func readRedactedEchoExportObject(from data: Data) throws -> [String: Any] {
        guard let value = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw EchoTraceStorageError.noEvidenceBundle
        }
        return value
    }

    private func redactedEchoExportString(
        _ object: [String: Any]?,
        key: String
    ) -> String {
        object?[key] as? String ?? "missing"
    }

    private func redactedEchoExportStrings(
        _ object: [String: Any]?,
        key: String
    ) -> [String] {
        object?[key] as? [String] ?? []
    }

    func runUIQAEchoTraceExportSmoke(completion: @escaping ([String: Any]) -> Void) {
        let ownerContext = prepareEchoTraceUIQAOwner(fallbackOwnerUserId: "uiqa_echo_trace_user")
        let ownerUserId = ownerContext.ownerUserId
        defer { restoreEchoTraceUIQAOwner(ownerContext) }
        EchoTraceStore.shared.clear(ownerUserId: ownerUserId)
        for index in 0..<22 {
            EchoTraceStore.shared.record(
                EchoTraceRecord(
                    turnID: "uiqa-turn-\(index)",
                    traceId: "ctx_uiqa_\(index)",
                    userId: ownerUserId,
                    archiveItemIDs: ["archive_\(index)"],
                    archiveItemsIncluded: 1,
                    archiveItemsAvailable: 22,
                    kbFactCount: index,
                    voiceProfileId: index.isMultiple(of: 2) ? "S_uiqa_echo_trace" : nil,
                    voiceCloneReady: index.isMultiple(of: 2),
                    voiceOutputMode: "tencentAudioDrive",
                    digitalHumanSessionReady: true,
                    digitalHumanProviderMode: "tencent-cloud-digital-human",
                    privacyScopeLabel: "personal:uiqa_echo_trace_user",
                    canUseFamilyData: false,
                    crossScopeArchiveIncluded: false,
                    fallbacks: index.isMultiple(of: 2) ? [] : ["voice_clone_not_ready"],
                    latencyMs: index
                ),
                ownerUserId: ownerUserId
            )
        }

        do {
            let scopedExportURL = try EchoTraceStore.shared.exportRecentRecords(ownerUserId: ownerUserId)
            let exportURL = try preserveTemporaryEchoTraceUIQAExport(
                scopedExportURL,
                ownerContext: ownerContext
            )
            let data = try Data(contentsOf: exportURL)
            let records = try readRedactedEchoExportArray(from: data)
            let oldestTurnIDHash = redactedEchoExportString(records.first, key: "turnIDHash")
            let latestTurnIDHash = redactedEchoExportString(records.last, key: "turnIDHash")
            let serialized = String(data: data, encoding: .utf8) ?? ""
            completion([
                "completed": records.count == 20
                    && oldestTurnIDHash == PrivacySafeDiagnostics.correlationHash("uiqa-turn-2")
                    && latestTurnIDHash == PrivacySafeDiagnostics.correlationHash("uiqa-turn-21")
                    && records.allSatisfy {
                        redactedEchoExportString($0, key: "redactionPolicyVersion")
                            == PrivacySafeDiagnostics.redactionPolicyVersion
                    }
                    && !serialized.contains("uiqa-turn-21")
                    && !serialized.contains("archive_21"),
                "recordCount": records.count,
                "oldestRetainedTurnIDHash": oldestTurnIDHash,
                "latestTurnIDHash": latestTurnIDHash,
                "exportPath": exportURL.path,
                "fileExists": FileManager.default.fileExists(atPath: exportURL.path),
            ])
        } catch {
            completion([
                "completed": false,
                "failureReason": "exportFailed",
                "error": "redacted",
            ])
        }
    }

    func runUIQAEchoRuntimeDiagnosticsExportSmoke(completion: @escaping ([String: Any]) -> Void) {
        let ownerContext = prepareEchoTraceUIQAOwner(fallbackOwnerUserId: "uiqa_echo_runtime_user")
        let ownerUserId = ownerContext.ownerUserId
        defer { restoreEchoTraceUIQAOwner(ownerContext) }
        EchoTraceStore.shared.clear(ownerUserId: ownerUserId)
        EchoRuntimeDiagnosticsStore.shared.clear(ownerUserId: ownerUserId)

        for index in 0..<22 {
            let record = EchoTraceRecord(
                turnID: "uiqa-runtime-turn-\(index)",
                traceId: "ctx_uiqa_runtime_\(index)",
                userId: ownerUserId,
                archiveItemIDs: ["archive_runtime_\(index)"],
                archiveItemsIncluded: 1,
                archiveItemsAvailable: 22,
                kbFactCount: index + 1,
                voiceProfileId: "S_uiqa_runtime_diagnostics",
                voiceCloneReady: true,
                voiceOutputMode: "tencentAudioDrive",
                digitalHumanSessionReady: true,
                digitalHumanProviderMode: "tencent-cloud-digital-human",
                privacyScopeLabel: "personal:uiqa_echo_runtime_user",
                canUseFamilyData: false,
                crossScopeArchiveIncluded: false,
                fallbacks: index.isMultiple(of: 3) ? ["uiqa_fallback_probe"] : [],
                latencyMs: 12 + index
            )
            lastEchoTraceRecord = record
            EchoTraceStore.shared.record(record, ownerUserId: ownerUserId)
            lastVoiceCloneProviderLogId = "uiqa-provider-log-\(index)"
            lastVoiceCloneProviderRequestId = "uiqa-provider-request-\(index)"
            lastVoiceCloneProviderMode = "volcengineVoiceCloneV3"
            lastEchoRuntimeFallbackReason = index.isMultiple(of: 3) ? "uiqa_fallback_probe" : nil
            recordEchoRuntimeDiagnosticsSnapshot(reason: "uiqaEchoRuntimeDiagnosticsExport")
        }

        do {
            let scopedExportURL = try EchoRuntimeDiagnosticsStore.shared.exportRecentSnapshots(ownerUserId: ownerUserId)
            let exportURL = try preserveTemporaryEchoTraceUIQAExport(
                scopedExportURL,
                ownerContext: ownerContext
            )
            let data = try Data(contentsOf: exportURL)
            let snapshots = try readRedactedEchoExportArray(from: data)
            let oldestTurnIDHash = redactedEchoExportString(snapshots.first, key: "turnIDHash")
            let latestTurnIDHash = redactedEchoExportString(snapshots.last, key: "turnIDHash")
            let latestVoiceProfileIdHash = redactedEchoExportString(
                snapshots.last,
                key: "voiceProfileIdHash"
            )
            let latestProviderLogIdHash = redactedEchoExportString(
                snapshots.last,
                key: "providerLogIdHash"
            )
            let latestAudioOwner = redactedEchoExportString(snapshots.last, key: "audioOwner")
            let latestProviderMode = redactedEchoExportString(
                snapshots.last,
                key: "digitalHumanProviderMode"
            )
            let serialized = String(data: data, encoding: .utf8) ?? ""
            completion([
                "completed": snapshots.count == 20
                    && oldestTurnIDHash == PrivacySafeDiagnostics.correlationHash("uiqa-runtime-turn-2")
                    && latestTurnIDHash == PrivacySafeDiagnostics.correlationHash("uiqa-runtime-turn-21")
                    && latestVoiceProfileIdHash == PrivacySafeDiagnostics.correlationHash("S_uiqa_runtime_diagnostics")
                    && latestAudioOwner == currentEchoAudioOwner.rawValue
                    && latestProviderLogIdHash == PrivacySafeDiagnostics.correlationHash("uiqa-provider-log-21")
                    && !serialized.contains("uiqa-provider-log-21")
                    && !serialized.contains("S_uiqa_runtime_diagnostics"),
                "snapshotCount": snapshots.count,
                "oldestRetainedTurnIDHash": oldestTurnIDHash,
                "latestTurnIDHash": latestTurnIDHash,
                "latestVoiceProfileIdHash": latestVoiceProfileIdHash,
                "latestAudioOwner": latestAudioOwner,
                "latestProviderLogIdHash": latestProviderLogIdHash,
                "latestDigitalHumanProviderMode": latestProviderMode,
                "diagnosticsPanelText": echoRuntimeDiagnosticsPanelLabel.text ?? "",
                "exportPath": exportURL.path,
                "fileExists": FileManager.default.fileExists(atPath: exportURL.path),
            ])
        } catch {
            completion([
                "completed": false,
                "failureReason": "exportFailed",
                "error": "redacted",
            ])
        }
    }

    func runUIQAEchoTraceEvidencePackageExportSmoke(completion: @escaping ([String: Any]) -> Void) {
        let ownerContext = prepareEchoTraceUIQAOwner(fallbackOwnerUserId: "uiqa_echo_evidence_user")
        let ownerUserId = ownerContext.ownerUserId
        defer { restoreEchoTraceUIQAOwner(ownerContext) }
        EchoTraceStore.shared.clear(ownerUserId: ownerUserId)
        EchoRuntimeDiagnosticsStore.shared.clear(ownerUserId: ownerUserId)
        EchoTraceEvidencePackageStore.shared.clear(ownerUserId: ownerUserId)

        for index in 0..<22 {
            let record = EchoTraceRecord(
                turnID: "uiqa-evidence-turn-\(index)",
                traceId: "ctx_uiqa_evidence_\(index)",
                userId: ownerUserId,
                archiveItemIDs: ["archive_evidence_\(index)"],
                archiveItemsIncluded: 1,
                archiveItemsAvailable: 22,
                kbFactCount: index + 2,
                voiceProfileId: "S_uiqa_trace_evidence",
                voiceCloneReady: true,
                voiceOutputMode: "tencentAudioDrive",
                digitalHumanSessionReady: true,
                digitalHumanProviderMode: "tencent-cloud-digital-human",
                privacyScopeLabel: "personal:uiqa_echo_evidence_user",
                canUseFamilyData: false,
                crossScopeArchiveIncluded: false,
                fallbacks: [],
                latencyMs: 20 + index
            )
            lastEchoTraceRecord = record
            EchoTraceStore.shared.record(record, ownerUserId: ownerUserId)
            lastDigitalHumanSessionEvidenceSummary = .unavailable(
                ownerUserId: ownerUserId,
                reason: "uiqaSessionSummary"
            )
            lastVoiceCloneProviderLogId = "uiqa-evidence-provider-log-\(index)"
            lastVoiceCloneProviderRequestId = "uiqa-evidence-provider-request-\(index)"
            lastVoiceCloneProviderMode = "volcengineVoiceCloneV3"
            lastVoiceSynthesisEvidenceSummary = .failed(
                ownerUserId: ownerUserId,
                voiceProfileId: "S_uiqa_trace_evidence",
                outputMode: "tencentAudioDrive",
                providerLogId: "uiqa-evidence-provider-log-\(index)",
                providerRequestId: "uiqa-evidence-provider-request-\(index)",
                reason: "uiqaSynthesisSummary",
                detail: "UIQA stores provider metadata only"
            )
            let snapshot = recordEchoRuntimeDiagnosticsSnapshot(reason: "uiqaEchoTraceEvidencePackageExport")
            _ = makeEchoTraceEvidencePackage(snapshot: snapshot, source: "uiqaEchoTraceEvidencePackageExport")
        }

        do {
            let scopedExportURL = try EchoTraceEvidencePackageStore.shared.exportRecentPackages(ownerUserId: ownerUserId)
            let exportURL = try preserveTemporaryEchoTraceUIQAExport(
                scopedExportURL,
                ownerContext: ownerContext
            )
            let data = try Data(contentsOf: exportURL)
            let packages = try readRedactedEchoExportArray(from: data)
            let latestPackage = packages.last
            let runtimeDiagnostics = latestPackage?["runtimeDiagnostics"] as? [String: Any]
            let contextBuild = latestPackage?["contextBuild"] as? [String: Any]
            let voiceSynthesis = latestPackage?["voiceSynthesis"] as? [String: Any]
            let oldestTurnIDHash = redactedEchoExportString(packages.first, key: "turnIDHash")
            let latestTurnIDHash = redactedEchoExportString(latestPackage, key: "turnIDHash")
            let latestTraceIdHash = redactedEchoExportString(latestPackage, key: "traceIdHash")
            let latestVoiceProfileIdHash = redactedEchoExportString(
                voiceSynthesis,
                key: "voiceProfileIdHash"
            )
            let latestProviderLogIdHash = redactedEchoExportString(
                voiceSynthesis,
                key: "providerLogIdHash"
            )
            let latestAudioOwner = redactedEchoExportString(runtimeDiagnostics, key: "audioOwner")
            completion([
                "completed": packages.count == 20
                    && oldestTurnIDHash == PrivacySafeDiagnostics.correlationHash("uiqa-evidence-turn-2")
                    && latestTurnIDHash == PrivacySafeDiagnostics.correlationHash("uiqa-evidence-turn-21")
                    && latestAudioOwner == currentEchoAudioOwner.rawValue
                    && contextBuild?["kbFactCount"] as? Int == 23
                    && (latestPackage?["digitalHumanSession"] as? [String: Any])?["status"] as? String == "unavailable"
                    && latestProviderLogIdHash
                        == PrivacySafeDiagnostics.correlationHash("uiqa-evidence-provider-log-21"),
                "packageCount": packages.count,
                "oldestRetainedTurnIDHash": oldestTurnIDHash,
                "latestTurnIDHash": latestTurnIDHash,
                "latestTraceIdHash": latestTraceIdHash,
                "latestVoiceProfileIdHash": latestVoiceProfileIdHash,
                "latestProviderLogIdHash": latestProviderLogIdHash,
                "latestAudioOwner": latestAudioOwner,
                "latestContextKBFacts": contextBuild?["kbFactCount"] as? Int ?? -1,
                "redactionPolicyCount": redactedEchoExportStrings(
                    latestPackage,
                    key: "redactionPolicy"
                ).count,
                "exportPath": exportURL.path,
                "fileExists": FileManager.default.fileExists(atPath: exportURL.path),
            ])
        } catch {
            completion([
                "completed": false,
                "failureReason": "exportFailed",
                "error": "redacted",
            ])
        }
    }

    func runUIQAEchoTraceEvidencePackagePanelExportSmoke(completion: @escaping ([String: Any]) -> Void) {
        let ownerContext = prepareEchoTraceUIQAOwner(fallbackOwnerUserId: "uiqa_echo_panel_evidence_user")
        let ownerUserId = ownerContext.ownerUserId
        defer { restoreEchoTraceUIQAOwner(ownerContext) }
        EchoTraceStore.shared.clear(ownerUserId: ownerUserId)
        EchoRuntimeDiagnosticsStore.shared.clear(ownerUserId: ownerUserId)
        EchoTraceEvidencePackageStore.shared.clear(ownerUserId: ownerUserId)

        let previousContext = DigitalHumanContextStore.shared.current
        let previousAudioOwner = currentEchoAudioOwner
        let qaFamilyMember = FamilyMember(
            id: "uiqa_family_voice_panel_member",
            name: "UIQA 家人角色",
            relation: "家人",
            isOnline: true,
            lastUpdated: "刚刚",
            relationshipOwnerUserId: UserManager.shared.currentUser?.id ?? "user_001",
            relationshipAuthoritySource: .qaFixture,
            accessStatus: "active",
            invitationStatus: "accepted",
            voiceProfileId: "S_uiqa_family_profile_must_not_route",
            voiceSampleStatus: "ready",
            voiceEnabled: true
        )
        FamilyRepository.shared.add(qaFamilyMember)
        DigitalHumanContextStore.shared.current = DigitalHumanContext(
            viewerUserId: UserManager.shared.currentUser?.id ?? "user_001",
            ownerId: qaFamilyMember.id,
            displayName: qaFamilyMember.name,
            relation: qaFamilyMember.relation,
            mode: qaFamilyMember.digitalHumanMode,
            isSelfAssistant: false
        )
        updatePersonaBadge()
        setEchoAudioOwner(.tencentDigitalHuman, reason: "uiqaPanelFamilyVoiceSelection")
        lastEchoRuntimeFallbackReason = nil
        let familyVoiceProfileBlocked = resolveEchoRoleVoiceProfileSelection().source == .familyVoiceNotPermitted
        defer {
            DigitalHumanContextStore.shared.current = previousContext
            updatePersonaBadge()
            setEchoAudioOwner(previousAudioOwner, reason: "uiqaPanelRestore")
        }

        let record = EchoTraceRecord(
            turnID: "uiqa-panel-evidence-turn",
            traceId: "ctx_uiqa_panel_evidence",
            userId: ownerUserId,
            archiveItemIDs: ["archive_panel_evidence"],
            archiveItemsIncluded: 1,
            archiveItemsAvailable: 1,
            contextVersion: "echo-context-v2",
            selectedContextRefs: [
                "archive_panel_evidence",
                "fact_panel_evidence",
                "persona:personal:uiqa_echo_panel_evidence_user",
                "care:latest"
            ],
            selectedContextRefsBySource: [
                "archive": ["archive_panel_evidence"],
                "kbFact": ["fact_panel_evidence"],
                "persona": ["persona:personal:uiqa_echo_panel_evidence_user"],
                "care": ["care:latest"]
            ],
            filteredContextReasons: ["archive_panel_filtered:analysis_failed_empty_context"],
            selectedContextCount: 4,
            filteredContextCount: 1,
            rankingTraceCount: 5,
            selectedContextSourceCounts: [
                "archive": 1,
                "kbFact": 1,
                "persona": 1,
                "care": 1
            ],
            kbFactCount: 3,
            voiceProfileId: nil,
            voiceCloneReady: false,
            voiceOutputMode: "tencentText",
            digitalHumanSessionReady: true,
            digitalHumanProviderMode: "tencent-cloud-digital-human",
            privacyScopeLabel: "family:uiqa_family_voice_panel_member",
            canUseFamilyData: true,
            crossScopeArchiveIncluded: false,
            fallbacks: ["familyVoiceNotPermitted"],
            latencyMs: 18
        )
        lastEchoTraceRecord = record
        EchoTraceStore.shared.record(record, ownerUserId: ownerUserId)
        lastDigitalHumanSessionEvidenceSummary = .unavailable(
            ownerUserId: ownerUserId,
            reason: "uiqaPanelSessionSummary"
        )
        lastVoiceCloneProviderLogId = nil
        lastVoiceCloneProviderRequestId = nil
        lastVoiceCloneProviderMode = nil
        lastVoiceSynthesisEvidenceSummary = .unavailable(
            ownerUserId: ownerUserId,
            reason: "familyVoiceNotPermitted"
        )

        do {
            let scopedExportURL = try exportEchoTraceEvidencePackageForQA(source: "uiqaPanelEvidenceExport")
            let exportURL = try preserveTemporaryEchoTraceUIQAExport(
                scopedExportURL,
                ownerContext: ownerContext
            )
            let data = try Data(contentsOf: exportURL)
            let packages = try readRedactedEchoExportArray(from: data)
            let serialized = String(data: data, encoding: .utf8) ?? ""
            let latestPackage = packages.last
            let runtimeDiagnostics = latestPackage?["runtimeDiagnostics"] as? [String: Any]
            let voiceSynthesis = latestPackage?["voiceSynthesis"] as? [String: Any]
            let contextBuild = latestPackage?["contextBuild"] as? [String: Any]
            let clueSummary = contextBuild?["clueSummary"] as? [String: Any]
            let latestTurnIDHash = redactedEchoExportString(latestPackage, key: "turnIDHash")
            let latestProviderLogIdHash = redactedEchoExportString(
                voiceSynthesis,
                key: "providerLogIdHash"
            )
            let latestRoleVoiceSource = redactedEchoExportString(
                runtimeDiagnostics,
                key: "roleVoiceSource"
            )
            let latestRoleVoiceDisplayNameHash = redactedEchoExportString(
                runtimeDiagnostics,
                key: "roleVoiceDisplayNameHash"
            )
            let latestRoleVoiceContextOwnerIdHash = redactedEchoExportString(
                runtimeDiagnostics,
                key: "roleVoiceContextOwnerIdHash"
            )
            let latestRuntimeVoiceProfileIdHash = redactedEchoExportString(
                runtimeDiagnostics,
                key: "voiceProfileIdHash"
            )
            let latestRuntimeAudioOwner = redactedEchoExportString(
                runtimeDiagnostics,
                key: "audioOwner"
            )
            let archiveClueHashes = redactedEchoExportStrings(
                clueSummary,
                key: "archiveRefsHashes"
            )
            let kbFactClueHashes = redactedEchoExportStrings(
                clueSummary,
                key: "kbFactRefsHashes"
            )
            let personaClueHashes = redactedEchoExportStrings(
                clueSummary,
                key: "personaRefsHashes"
            )
            let careClueHashes = redactedEchoExportStrings(
                clueSummary,
                key: "careRefsHashes"
            )
            let filteredReasons = redactedEchoExportStrings(
                clueSummary,
                key: "filteredContextReasons"
            )
            let personaBadgeName = personaNameLabel.text ?? ""
            let personaBadgeMatchesFamily = personaBadgeName
                == "\(qaFamilyMember.name) · AI 数字分身"
            completion([
                "completed": echoTraceEvidenceExportButton.superview === echoRuntimeDiagnosticsPanelView
                    && echoTraceEvidenceExportButton.title(for: .normal) == "导出证据包"
                    && personaBadgeMatchesFamily
                    && familyVoiceProfileBlocked
                    && latestTurnIDHash
                        == PrivacySafeDiagnostics.correlationHash("uiqa-panel-evidence-turn")
                    && latestProviderLogIdHash == "missing"
                    && latestRoleVoiceSource == "familyVoiceNotPermitted"
                    && latestRoleVoiceDisplayNameHash
                        == PrivacySafeDiagnostics.correlationHash("UIQA 家人角色")
                    && latestRoleVoiceContextOwnerIdHash
                        == PrivacySafeDiagnostics.correlationHash("uiqa_family_voice_panel_member")
                    && latestRuntimeVoiceProfileIdHash == "missing"
                    && latestRuntimeAudioOwner == "tencentDigitalHuman"
                    && archiveClueHashes == [PrivacySafeDiagnostics.correlationHash("archive_panel_evidence")]
                    && kbFactClueHashes == [PrivacySafeDiagnostics.correlationHash("fact_panel_evidence")]
                    && personaClueHashes
                        == [PrivacySafeDiagnostics.correlationHash("persona:personal:uiqa_echo_panel_evidence_user")]
                    && careClueHashes == [PrivacySafeDiagnostics.correlationHash("care:latest")]
                    && redactedEchoExportString(clueSummary, key: "contextVersion") == "echo-context-v2"
                    && filteredReasons == ["archive_panel_filtered:analysis_failed_empty_context"]
                    && ((clueSummary?["rankingTraceCount"] as? Int) == 5)
                    && !serialized.localizedCaseInsensitiveContains("audioBase64")
                    && !serialized.localizedCaseInsensitiveContains("appkey")
                    && !serialized.localizedCaseInsensitiveContains("accesstoken")
                    && !serialized.contains("UIQA 家人音色")
                    && !serialized.contains("uiqa-panel-provider-log")
                    && !serialized.contains("archive_panel_evidence"),
                "buttonVisible": echoTraceEvidenceExportButton.superview === echoRuntimeDiagnosticsPanelView,
                "buttonTitle": echoTraceEvidenceExportButton.title(for: .normal) ?? "",
                "personaBadgeName": personaBadgeName,
                "personaBadgeMatchesFamily": personaBadgeMatchesFamily,
                "familyVoiceProfileBlocked": familyVoiceProfileBlocked,
                "packageCount": packages.count,
                "latestTurnIDHash": latestTurnIDHash,
                "latestProviderLogIdHash": latestProviderLogIdHash,
                "latestRuntimeRoleVoiceSource": latestRoleVoiceSource,
                "latestRuntimeRoleVoiceDisplayNameHash": latestRoleVoiceDisplayNameHash,
                "latestRuntimeRoleVoiceContextOwnerIdHash": latestRoleVoiceContextOwnerIdHash,
                "latestRuntimeVoiceProfileIdHash": latestRuntimeVoiceProfileIdHash,
                "latestRuntimeAudioOwner": latestRuntimeAudioOwner,
                "latestArchiveClueHashes": archiveClueHashes.joined(separator: ","),
                "latestKbFactClueHashes": kbFactClueHashes.joined(separator: ","),
                "latestPersonaClueHashes": personaClueHashes.joined(separator: ","),
                "latestCareClueHashes": careClueHashes.joined(separator: ","),
                "latestContextVersion": redactedEchoExportString(clueSummary, key: "contextVersion"),
                "latestFilteredReasons": filteredReasons.joined(separator: ","),
                "latestRankingTraceCount": clueSummary?["rankingTraceCount"] as? Int ?? -1,
                "exportPath": exportURL.path,
                "fileExists": FileManager.default.fileExists(atPath: exportURL.path),
            ])
        } catch {
            completion([
                "completed": false,
                "failureReason": "panelExportFailed",
                "error": "redacted",
            ])
        }
    }

    func runUIQAEchoQAEvidenceBundleExportSmoke(completion: @escaping ([String: Any]) -> Void) {
        let ownerContext = prepareEchoTraceUIQAOwner(fallbackOwnerUserId: "uiqa_echo_qa_bundle_user")
        let ownerUserId = ownerContext.ownerUserId
        let previousOwnerTruthContextCitationEvidence = lastOwnerTruthContextCitationEvidence
        let previousOwnerTruthContextParityEvidence = lastOwnerTruthContextParityEvidence
        let previousOwnerTruthContextCompareEvidence = lastOwnerTruthContextCompareEvidence
        let previousAnswerGroundingEvidence = lastEchoAnswerGroundingEvidence
        defer {
            lastOwnerTruthContextCitationEvidence = previousOwnerTruthContextCitationEvidence
            lastOwnerTruthContextParityEvidence = previousOwnerTruthContextParityEvidence
            lastOwnerTruthContextCompareEvidence = previousOwnerTruthContextCompareEvidence
            lastEchoAnswerGroundingEvidence = previousAnswerGroundingEvidence
            restoreEchoTraceUIQAOwner(ownerContext)
        }
        EchoTraceStore.shared.clear(ownerUserId: ownerUserId)
        EchoRuntimeDiagnosticsStore.shared.clear(ownerUserId: ownerUserId)
        EchoTraceEvidencePackageStore.shared.clear(ownerUserId: ownerUserId)
        EchoQAEvidenceBundleStore.shared.clear(ownerUserId: ownerUserId)
        EchoQAEvidenceManifestStore.shared.clear(ownerUserId: ownerUserId)

        let record = EchoTraceRecord(
            turnID: "uiqa-qa-bundle-turn",
            traceId: "ctx_uiqa_qa_bundle",
            userId: ownerUserId,
            archiveItemIDs: ["archive_qa_bundle"],
            archiveItemsIncluded: 1,
            archiveItemsAvailable: 2,
            contextVersion: "echo-context-v2",
            selectedContextRefs: [
                "archive_qa_bundle",
                "fact_qa_bundle",
                "persona:personal:uiqa_echo_qa_bundle_user",
                "care:latest"
            ],
            selectedContextRefsBySource: [
                "archive": ["archive_qa_bundle"],
                "kbFact": ["fact_qa_bundle"],
                "persona": ["persona:personal:uiqa_echo_qa_bundle_user"],
                "care": ["care:latest"]
            ],
            filteredContextReasons: [
                "archive_filtered:analysis_failed_empty_context",
                "timeLetter_filtered:not_open_for_recipient"
            ],
            selectedContextCount: 4,
            filteredContextCount: 2,
            rankingTraceCount: 6,
            selectedContextSourceCounts: [
                "archive": 1,
                "kbFact": 1,
                "persona": 1,
                "care": 1
            ],
            kbFactCount: 4,
            voiceProfileId: "S_uiqa_qa_bundle",
            voiceCloneReady: true,
            voiceOutputMode: "tencentAudioDrive",
            digitalHumanSessionReady: true,
            digitalHumanProviderMode: "tencent-cloud-digital-human",
            privacyScopeLabel: "personal:uiqa_echo_qa_bundle_user",
            canUseFamilyData: false,
            crossScopeArchiveIncluded: false,
            fallbacks: ["voice_clone_provider_retry"],
            latencyMs: 24
        )
        lastEchoTraceRecord = record
        EchoTraceStore.shared.record(record, ownerUserId: ownerUserId)
        lastDigitalHumanSessionEvidenceSummary = .unavailable(
            ownerUserId: ownerUserId,
            reason: "uiqaBundleSessionSummary"
        )
        lastVoiceCloneProviderLogId = "uiqa-bundle-provider-log"
        lastVoiceCloneProviderRequestId = "uiqa-bundle-provider-request"
        lastVoiceCloneProviderMode = "volcengineVoiceCloneV3"
        lastVoiceSynthesisEvidenceSummary = .failed(
            ownerUserId: ownerUserId,
            voiceProfileId: "S_uiqa_qa_bundle",
            outputMode: "tencentAudioDrive",
            providerLogId: "uiqa-bundle-provider-log",
            providerRequestId: "uiqa-bundle-provider-request",
            reason: "uiqaBundleSynthesisSummary",
            detail: "UIQA bundle stores provider metadata only"
        )

        let groundingTraceID = "ctx_uiqa_grounding_trace"
        let groundingCitationRef = "memory-version:uiqa-grounding-reference"
        let groundingContentHash = String(repeating: "a", count: 64)
        guard let groundingAnswer = EchoAnswer(json: [
            "schemaVersion": EchoAnswer.schemaVersion,
            "answerId": "ans_uiqa_grounding",
            "text": "已使用确认记忆生成回响。",
            "provider": "uiqa",
            "contextTraceId": groundingTraceID,
            "contextVersion": "echo-context-v4-owner",
            "citations": [[
                "source": "ownerTruthMemoryProjection",
                "refId": groundingCitationRef,
                "kind": "memoryVersion",
                "contentHash": groundingContentHash,
            ]],
            "memoryGrounding": [
                "schemaVersion": EchoMemoryGrounding.schemaVersion,
                "outcome": "grounded",
                "handoff": "none",
            ],
        ]) else {
            completion([
                "completed": false,
                "failureReason": "answerGroundingFixtureInvalid",
                "error": "redacted",
            ])
            return
        }
        lastEchoAnswerGroundingEvidence = EchoAnswerGroundingQAEvidence(answer: groundingAnswer)

        let ownerTruthContextReference = "memory-version:00000000-0000-0000-0000-000000000901"
        let ownerTruthContextQueryFingerprint = OwnerTruthContextCitationTraceSummary
            .queryFingerprint(for: "uiqa echo context evidence")
        let ownerTruthContextSummary = OwnerTruthContextCitationTraceSummary(
            contextVersion: "echo-context-v4-shadow",
            policyVersion: "owner-truth-context-shadow-build-policy-v1",
            selectionMode: .projectionCitationOrder,
            queryHash: ownerTruthContextQueryFingerprint.hash,
            queryLength: ownerTruthContextQueryFingerprint.length,
            contextHash: "uiqa-owner-truth-context-hash",
            authorityState: .ready,
            authorityEpoch: 7,
            projectionCheckpoint: "uiqa-owner-truth-projection-checkpoint",
            selectedContextRefs: [ownerTruthContextReference],
            selectedContextRefsBySource: [
                "owner-truth-memory-projection": [ownerTruthContextReference]
            ],
            filteredContextReasons: ["sensitivity_not_context_eligible"],
            selectedContextCount: 1,
            filteredContextCount: 1,
            rankingTraceCount: 1,
            citationCount: 1,
            answerCitationCount: 1,
            selectedContextSourceCounts: ["owner-truth-memory-projection": 1],
            fallbacks: []
        )
        guard recordOwnerTruthContextCitationQAEvidence(ownerTruthContextSummary) else {
            completion([
                "completed": false,
                "failureReason": "ownerTruthContextCitationQADisabled",
                "error": "redacted",
            ])
            return
        }

        let ownerTruthContextParityQuery = "uiqa echo context parity evidence"
        let ownerTruthContextParityFingerprint = OwnerTruthContextCitationTraceSummary
            .queryFingerprint(for: ownerTruthContextParityQuery)
        guard let ownerTruthContextParityQueryHash = ownerTruthContextParityFingerprint.hash,
              let legacyParityPacket = EchoContextPacket(json: [
                "traceId": "ctx_uiqa_owner_truth_parity",
                "intent": "echo_chat",
                "userId": ownerUserId,
                "requestCorrelation": [
                    "schemaVersion": EchoContextPacketRequestCorrelation.schemaVersion,
                    "intent": "echo_chat",
                    "queryHash": ownerTruthContextParityQueryHash,
                    "queryLength": ownerTruthContextParityFingerprint.length,
                ],
                "personaScope": "self",
                "digitalHumanId": ownerUserId,
                "contextVersion": "echo-context-v1",
                "trace": [
                    "selectedContextCount": 1,
                    "filteredContextCount": 0,
                    "rankingTraceCount": 1,
                    "selectedContextSourceCounts": ["owner-truth-memory-projection": 1],
                ],
                "selectedContext": [[
                    "refId": ownerTruthContextReference,
                    "source": "owner-truth-memory-projection",
                ]],
                "filteredContext": [],
                "rankingTrace": [["rank": 1]],
                "fallbacks": [],
              ]) else {
            completion([
                "completed": false,
                "failureReason": "ownerTruthContextParityFixtureInvalid",
                "error": "redacted",
            ])
            return
        }
        let ownerTruthContextParitySummary = OwnerTruthContextCitationTraceSummary(
            contextVersion: ownerTruthContextSummary.contextVersion,
            policyVersion: ownerTruthContextSummary.policyVersion,
            selectionMode: ownerTruthContextSummary.selectionMode,
            queryHash: ownerTruthContextParityQueryHash,
            queryLength: ownerTruthContextParityFingerprint.length,
            contextHash: ownerTruthContextSummary.contextHash,
            authorityState: ownerTruthContextSummary.authorityState,
            authorityEpoch: ownerTruthContextSummary.authorityEpoch,
            projectionCheckpoint: ownerTruthContextSummary.projectionCheckpoint,
            selectedContextRefs: ownerTruthContextSummary.selectedContextRefs,
            selectedContextRefsBySource: ownerTruthContextSummary.selectedContextRefsBySource,
            filteredContextReasons: ownerTruthContextSummary.filteredContextReasons,
            selectedContextCount: ownerTruthContextSummary.selectedContextCount,
            filteredContextCount: ownerTruthContextSummary.filteredContextCount,
            rankingTraceCount: ownerTruthContextSummary.rankingTraceCount,
            citationCount: ownerTruthContextSummary.citationCount,
            answerCitationCount: ownerTruthContextSummary.answerCitationCount,
            selectedContextSourceCounts: ownerTruthContextSummary.selectedContextSourceCounts,
            fallbacks: ownerTruthContextSummary.fallbacks
        )
        let ownerTruthContextParityLease = EchoOwnerTruthContextParityLease(
            generation: 1,
            turnID: "uiqa-owner-truth-context-parity-turn",
            expectedIdentity: EchoKnowledgeContextIdentity(
                userId: ownerUserId,
                personaScope: "self",
                digitalHumanId: ownerUserId
            ),
            accountSubjectID: ownerUserId,
            vaultID: "vault-uiqa-owner-truth-context-parity",
            requestIntent: "echo_chat",
            queryHash: ownerTruthContextParityQueryHash,
            queryLength: ownerTruthContextParityFingerprint.length
        )
        guard let ownerTruthContextParityEvidence = try? EchoOwnerTruthContextParityAdapter.compare(
            lease: ownerTruthContextParityLease,
            legacy: EchoOwnerTruthContextParityLegacyObservation(packet: legacyParityPacket),
            ownerTruth: EchoOwnerTruthContextParityShadowObservation(
                summary: ownerTruthContextParitySummary
            ),
            qaGateEnabled: OwnerTruthContextCitationQAGate.isEnabled
                && OwnerTruthMigrationParityQAGate.isEnabled
        ), recordOwnerTruthContextParityQAEvidence(ownerTruthContextParityEvidence) else {
            completion([
                "completed": false,
                "failureReason": "ownerTruthContextParityQADisabled",
                "error": "redacted",
            ])
            return
        }

        let ownerTruthContextCompareQuery = "uiqa same request context compare evidence"
        let ownerTruthContextCompareFingerprint = OwnerTruthContextCitationTraceSummary
            .queryFingerprint(for: ownerTruthContextCompareQuery)
        guard let ownerTruthContextCompareQueryHash = ownerTruthContextCompareFingerprint.hash,
              let ownerTruthContextCompare = try? OwnerTruthContextShadowCompare(
                backendJSONObject: [
                    "schemaVersion": "owner-truth-context-shadow-compare-response-v1",
                    "contextComparison": [
                        "schemaVersion": "owner-truth-context-shadow-compare-v1",
                        "policyVersion": "owner-truth-context-shadow-compare-policy-v1",
                        "shadowOnly": true,
                        "legacyContextUnchanged": true,
                        "legacyContextRead": true,
                        "requestCorrelation": [
                            "schemaVersion": "echo-context-request-correlation-v1",
                            "intent": "echo_chat",
                            "queryHash": ownerTruthContextCompareQueryHash,
                            "queryLength": ownerTruthContextCompareFingerprint.length,
                        ],
                        "requestCorrelationMatches": true,
                        "disposition": "observed",
                        "legacy": [
                            "schemaVersion": 1,
                            "contextVersion": "echo-context-v1",
                            "selectedContextCount": 2,
                            "filteredContextCount": 1,
                            "fallbackCount": 0,
                        ],
                        "v4": [
                            "schemaVersion": "owner-truth-context-shadow-build-v1",
                            "contextVersion": "echo-context-v4-shadow",
                            "policyVersion": "owner-truth-context-shadow-build-policy-v1",
                            "state": "ready",
                            "selectedContextCount": 2,
                            "filteredContextCount": 1,
                            "fallbackCount": 0,
                            "allSelectedItemsHaveTypedCitation": true,
                            "authorityEpochPresent": true,
                            "projectionCheckpointPresent": true,
                        ],
                    ],
                ],
                expectedIntent: "echo_chat",
                expectedQuery: ownerTruthContextCompareQuery
              ), recordOwnerTruthContextCompareQAEvidence(
                EchoOwnerTruthContextShadowCompareQAEvidenceReadout(
                    comparison: ownerTruthContextCompare
                )
              ) else {
            completion([
                "completed": false,
                "failureReason": "ownerTruthContextCompareQADisabled",
                "error": "redacted",
            ])
            return
        }

        do {
            let scopedExportURL = try exportEchoQAEvidenceBundleForQA(source: "uiqaQAEvidenceBundleExport")
            let exportURL = try preserveTemporaryEchoTraceUIQAExport(
                scopedExportURL,
                ownerContext: ownerContext
            )
            let scopedManifestExportURL = try EchoQAEvidenceManifestStore.shared.exportLatestManifest(
                ownerUserId: ownerUserId
            )
            let manifestExportURL = try preserveTemporaryEchoTraceUIQAExport(
                scopedManifestExportURL,
                ownerContext: ownerContext
            )
            let data = try Data(contentsOf: exportURL)
            let bundle = try readRedactedEchoExportObject(from: data)
            let manifestData = try Data(contentsOf: manifestExportURL)
            let manifest = try readRedactedEchoExportObject(from: manifestData)
            let serialized = String(data: data, encoding: .utf8) ?? ""
            let manifestSerialized = String(data: manifestData, encoding: .utf8) ?? ""
            let evidencePackage = bundle["evidencePackage"] as? [String: Any]
            let clueSummary = bundle["contextClues"] as? [String: Any]
            let answerGrounding = bundle["answerGrounding"] as? [String: Any]
            let ownerTruthContextEvidence = bundle["ownerTruthContextCitationEvidence"] as? [String: Any]
            let ownerTruthContextParityEvidence = bundle["ownerTruthContextParityEvidence"] as? [String: Any]
            let ownerTruthContextCompareEvidence = bundle["ownerTruthContextCompareEvidence"] as? [String: Any]
            let voiceSynthesis = bundle["voiceSynthesis"] as? [String: Any]
            let fallbackSummary = bundle["fallbackSummary"] as? [String: Any]
            let latestTurnIDHash = redactedEchoExportString(bundle, key: "turnIDHash")
            let latestTraceIdHash = redactedEchoExportString(bundle, key: "traceIdHash")
            let latestProviderLogIdHash = redactedEchoExportString(
                voiceSynthesis,
                key: "providerLogIdHash"
            )
            let archiveClueHashes = redactedEchoExportStrings(
                clueSummary,
                key: "archiveRefsHashes"
            )
            let kbFactClueHashes = redactedEchoExportStrings(
                clueSummary,
                key: "kbFactRefsHashes"
            )
            let personaClueHashes = redactedEchoExportStrings(
                clueSummary,
                key: "personaRefsHashes"
            )
            let careClueHashes = redactedEchoExportStrings(
                clueSummary,
                key: "careRefsHashes"
            )
            let ownerTruthContextRefDigests = redactedEchoExportStrings(
                ownerTruthContextEvidence,
                key: "selectedContextRefDigests"
            )
            let ownerTruthContextParityMismatchCodes = redactedEchoExportStrings(
                ownerTruthContextParityEvidence,
                key: "mismatchCodes"
            )
            let manifestArtifactHashes = redactedEchoExportStrings(manifest, key: "artifactHashes")
            let manifestSourceCommit = redactedEchoExportString(manifest, key: "sourceCommit")
            let manifestStatus = redactedEchoExportString(manifest, key: "manifestStatus")
            let expectedManifestSourceCommit = EchoQAEvidenceManifestIdentity.configuredSourceCommit()
            let localManifest = EchoQAEvidenceManifestStore.shared
                .recentManifests(ownerUserId: ownerUserId)
                .last
            let manifestCurrent = localManifest?.validity() == "current"
            let manifestOwnerIsolation = EchoQAEvidenceManifestStore.shared
                .recentManifests(ownerUserId: "uiqa_foreign_owner")
                .isEmpty
            let manifestExpiryObserved = localManifest?.validity(
                at: Date().addingTimeInterval(EchoQAEvidenceManifest.localBundleTTL + 1)
            ) == "expired"
            completion([
                "completed": bundle["schemaVersion"] as? Int == 4
                    && evidencePackage?["schemaVersion"] as? Int == 1
                    && answerGrounding?["schemaVersion"] as? Int == 1
                    && answerGrounding?["outcome"] as? String == "grounded"
                    && answerGrounding?["citationCount"] as? Int == 1
                    && redactedEchoExportStrings(answerGrounding, key: "citationSources")
                        == ["ownerTruthMemoryProjection"]
                    && redactedEchoExportStrings(answerGrounding, key: "citationRefDigests").count == 1
                    && redactedEchoExportStrings(answerGrounding, key: "citationContentHashDigests").count == 1
                    && !serialized.contains(groundingTraceID)
                    && !serialized.contains(groundingCitationRef)
                    && !serialized.contains(groundingContentHash)
                    && latestTurnIDHash
                        == PrivacySafeDiagnostics.correlationHash("uiqa-qa-bundle-turn")
                    && redactedEchoExportString(clueSummary, key: "contextVersion") == "echo-context-v2"
                    && archiveClueHashes == [PrivacySafeDiagnostics.correlationHash("archive_qa_bundle")]
                    && kbFactClueHashes == [PrivacySafeDiagnostics.correlationHash("fact_qa_bundle")]
                    && personaClueHashes
                        == [PrivacySafeDiagnostics.correlationHash("persona:personal:uiqa_echo_qa_bundle_user")]
                    && careClueHashes == [PrivacySafeDiagnostics.correlationHash("care:latest")]
                    && redactedEchoExportStrings(clueSummary, key: "filteredContextReasons").count == 2
                    && ((clueSummary?["rankingTraceCount"] as? Int) == 6)
                    && ownerTruthContextEvidence?["schemaVersion"] as? String
                        == OwnerTruthContextCitationQAEvidenceReadout.schemaVersion
                    && ownerTruthContextEvidence?["contextVersion"] as? String == "echo-context-v4-shadow"
                    && ownerTruthContextEvidence?["authorityState"] as? String == "ready"
                    && ownerTruthContextEvidence?["authorityEpoch"] as? Int == 7
                    && ownerTruthContextRefDigests.count == 1
                    && ownerTruthContextRefDigests.allSatisfy {
                        $0.range(of: "^[0-9a-f]{64}$", options: .regularExpression) != nil
                    }
                    && !serialized.contains(ownerTruthContextReference)
                    && echoRuntimeDiagnosticsPanelLabel.text?.contains("ownerCtx schema") == true
                    && ownerTruthContextParityEvidence?["schemaVersion"] as? String
                        == EchoOwnerTruthContextParityQAEvidenceReadout.schemaVersion
                    && ownerTruthContextParityEvidence?["comparisonState"] as? String
                        == "observedNonPromoting"
                    && ownerTruthContextParityEvidence?["promotionDecision"] as? String
                        == "notEvaluated"
                    && ownerTruthContextParityMismatchCodes.contains("M04")
                    && echoRuntimeDiagnosticsPanelLabel.text?.contains("ctxParity schema") == true
                    && !serialized.contains(ownerTruthContextParityQuery)
                    && ownerTruthContextCompareEvidence?["schemaVersion"] as? String
                        == EchoOwnerTruthContextShadowCompareQAEvidenceReadout.schemaVersion
                    && ownerTruthContextCompareEvidence?["disposition"] as? String == "observed"
                    && ownerTruthContextCompareEvidence?["requestCorrelationMatches"] as? Bool == true
                    && ownerTruthContextCompareEvidence?["legacySchemaVersion"] as? Int == 1
                    && ownerTruthContextCompareEvidence?["allSelectedItemsHaveTypedCitation"] as? Bool == true
                    && echoRuntimeDiagnosticsPanelLabel.text?.contains("ctxCompare schema") == true
                    && !serialized.contains(ownerTruthContextCompareQuery)
                    && (bundle["digitalHumanSession"] as? [String: Any])?["status"] as? String == "unavailable"
                    && latestProviderLogIdHash
                        == PrivacySafeDiagnostics.correlationHash("uiqa-bundle-provider-log")
                    && redactedEchoExportString(voiceSynthesis, key: "outputMode") == "tencentAudioDrive"
                    && redactedEchoExportStrings(fallbackSummary, key: "contextFallbacks")
                        == ["voice_clone_provider_retry"]
                    && redactedEchoExportStrings(fallbackSummary, key: "inferredFallbacks")
                        .contains("voiceSynthesis:uiqaBundleSynthesisSummary")
                    && !serialized.localizedCaseInsensitiveContains("audioBase64")
                    && !serialized.localizedCaseInsensitiveContains("appkey")
                    && !serialized.localizedCaseInsensitiveContains("accesstoken")
                    && !serialized.contains("uiqa-bundle-provider-log")
                    && !serialized.contains("archive_qa_bundle")
                    && manifest["schemaVersion"] as? Int == 1
                    && redactedEchoExportString(manifest, key: "manifestType") == "echoQaEvidenceBundle"
                    && manifestStatus == "passed"
                    && expectedManifestSourceCommit.map { manifestSourceCommit == $0 } == true
                    && manifestArtifactHashes == [EchoQAEvidenceManifestIdentity.sha256(data)]
                    && manifestCurrent
                    && manifestOwnerIsolation
                    && manifestExpiryObserved
                    && expectedManifestSourceCommit != nil
                    && !manifestSerialized.contains("uiqa_echo_qa_bundle_user")
                    && !manifestSerialized.contains("uiqa-bundle-provider-log")
                    && !manifestSerialized.contains("archive_qa_bundle"),
                "schemaVersion": bundle["schemaVersion"] as? Int ?? -1,
                "answerGroundingOutcome": redactedEchoExportString(answerGrounding, key: "outcome"),
                "answerGroundingCitationCount": answerGrounding?["citationCount"] as? Int ?? -1,
                "latestTurnIDHash": latestTurnIDHash,
                "latestTraceIdHash": latestTraceIdHash,
                "latestVoiceOutputMode": redactedEchoExportString(voiceSynthesis, key: "outputMode"),
                "latestProviderLogIdHash": latestProviderLogIdHash,
                "latestDigitalHumanStatus": redactedEchoExportString(
                    bundle["digitalHumanSession"] as? [String: Any],
                    key: "status"
                ),
                "latestFallbacks": redactedEchoExportStrings(
                    fallbackSummary,
                    key: "contextFallbacks"
                ).joined(separator: ","),
                "latestInferredFallbacks": redactedEchoExportStrings(
                    fallbackSummary,
                    key: "inferredFallbacks"
                ).joined(separator: ","),
                "latestClueSummaryArchiveRefHashes": archiveClueHashes.joined(separator: ","),
                "latestClueSummaryKbFactRefHashes": kbFactClueHashes.joined(separator: ","),
                "latestClueSummaryPersonaRefHashes": personaClueHashes.joined(separator: ","),
                "latestClueSummaryCareRefHashes": careClueHashes.joined(separator: ","),
                "ownerTruthContextEvidenceSchemaVersion": ownerTruthContextEvidence?["schemaVersion"] as? String ?? "",
                "ownerTruthContextReferenceDigestCount": ownerTruthContextRefDigests.count,
                "ownerTruthContextPanelVisible": echoRuntimeDiagnosticsPanelLabel.text?.contains("ownerCtx schema") == true,
                "ownerTruthContextParityEvidenceSchemaVersion": ownerTruthContextParityEvidence?["schemaVersion"] as? String ?? "",
                "ownerTruthContextParityMismatchCodes": ownerTruthContextParityMismatchCodes.joined(separator: ","),
                "ownerTruthContextParityPromotionDecision": ownerTruthContextParityEvidence?["promotionDecision"] as? String ?? "",
                "ownerTruthContextParityPanelVisible": echoRuntimeDiagnosticsPanelLabel.text?.contains("ctxParity schema") == true,
                "ownerTruthContextCompareEvidenceSchemaVersion": ownerTruthContextCompareEvidence?["schemaVersion"] as? String ?? "",
                "ownerTruthContextCompareDisposition": ownerTruthContextCompareEvidence?["disposition"] as? String ?? "",
                "ownerTruthContextComparePanelVisible": echoRuntimeDiagnosticsPanelLabel.text?.contains("ctxCompare schema") == true,
                "latestFilteredReasons": redactedEchoExportStrings(
                    clueSummary,
                    key: "filteredContextReasons"
                ).joined(separator: ","),
                "latestRankingTraceCount": clueSummary?["rankingTraceCount"] as? Int ?? -1,
                "manifestSchemaVersion": manifest["schemaVersion"] as? Int ?? -1,
                "manifestStatus": manifestStatus,
                "manifestSourceCommit": manifestSourceCommit,
                "manifestArtifactHash": manifestArtifactHashes.first ?? "",
                "manifestCurrent": manifestCurrent,
                "manifestOwnerIsolation": manifestOwnerIsolation,
                "manifestExpiryObserved": manifestExpiryObserved,
                "manifestExportPath": manifestExportURL.path,
                "manifestFileExists": FileManager.default.fileExists(atPath: manifestExportURL.path),
                "exportPath": exportURL.path,
                "fileExists": FileManager.default.fileExists(atPath: exportURL.path),
            ])
        } catch {
            completion([
                "completed": false,
                "failureReason": "qaEvidenceBundleExportFailed",
                "error": "redacted",
            ])
        }
    }

    func runUIQAVoiceCloneRuntimeFaultInjectionSmoke(
        completion: @escaping ([String: Any]) -> Void
    ) {
        guard let accountLease = echoAccountLease ?? captureEchoAccountLease(
            reason: "uiqaVoiceCloneRuntimeFault"
        ),
        validateEchoAccountLease(
            at: .request,
            expected: accountLease,
            reason: "uiqaVoiceCloneRuntimeFault"
        ) else {
            completion([
                "completed": false,
                "failureReason": "accountLeaseUnavailable",
            ])
            return
        }

        let ownerUserId = accountLease.subjectId
        let originalSnapshot = VoiceCloneService.shared.voiceCloneShellSnapshot()
        let profileId = "S_uiqa_voice_runtime_fault"

        func profileSnapshot(
            lifecycleState: VoiceProfileLifecycleState,
            sampleStatus: VoiceCloneSampleStatus,
            profileVersion: Int,
            expiresAt: String,
            isEnabled: Bool,
            allowedOperations: Set<String>
        ) -> VoiceCloneProfileSnapshot {
            VoiceCloneProfileSnapshot(
                voiceProfileId: profileId,
                sampleStatus: sampleStatus,
                authorizationCopy: "UIQA only: runtime fault-injection voice profile.",
                isEnabled: isEnabled,
                realCloneProviderReady: lifecycleState == .accepted,
                qualityAcceptanceRequired: false,
                disableContract: "",
                deleteContract: "",
                providerMode: "mockProvider",
                providerStatus: lifecycleState.rawValue,
                providerMessage: "",
                contractVersion: 2,
                defaultReleaseVisible: false,
                exitState: lifecycleState == .deleted ? "partial" : "active",
                accessRevoked: lifecycleState == .paused || lifecycleState == .deleted,
                localCleanupState: lifecycleState == .deleted ? "tombstoned" : "notRequested",
                providerCleanupState: "notRequested",
                providerCleanupReceiptAvailable: false,
                lifecycleSchemaVersion: "voice-profile-lifecycle-v1",
                lifecycleState: lifecycleState,
                profileVersion: profileVersion,
                retryGeneration: 0,
                stateChangedAt: "2026-08-08T00:00:00Z",
                eligibilityAllowed: lifecycleState == .accepted,
                eligibilityReasonCode: lifecycleState == .accepted
                    ? "eligibleLivingAdultSelf"
                    : "profileUnavailable",
                consentPurpose: "private_synthesis",
                consentState: "active",
                consentExpiresAt: expiresAt,
                allowedOperations: allowedOperations
            )
        }

        func mockSynthesis(
            bindingAudioOwner: String = "tencentDigitalHuman",
            audioFormat: String = "pcm16kMono",
            text: String = "UIQA voice clone runtime fault"
        ) -> VoiceCloneSynthesisResult? {
            let pcmData = Data(repeating: 23, count: 3_200)
            return VoiceCloneSynthesisResult(json: [
                "voiceProfileId": profileId,
                "providerMode": "mockVoiceCloneProvider",
                "outputMode": "tencentAudioDrive",
                "providerLogIdHash": "redacted-uiqa-provider-log",
                "providerRequestIdHash": "redacted-uiqa-provider-request",
                "audio": [
                    "data": pcmData.base64EncodedString(),
                    "format": audioFormat,
                    "byteCount": pcmData.count,
                    "sampleRate": 16_000,
                    "bitsPerSample": 16,
                    "channelCount": 1,
                    "durationSeconds": 0.1,
                ],
                "synthesisBinding": [
                    "schemaVersion": VoiceCloneSynthesisBinding.currentSchemaVersion,
                    "ownerUserId": ownerUserId,
                    "voiceProfileId": profileId,
                    "profileVersion": 1,
                    "roleSubjectId": ownerUserId,
                    "roleKey": "personalOwner",
                    "personaScope": "personal",
                    "digitalHumanId": ownerUserId,
                    "requestPurpose": "echo",
                    "outputMode": "tencentAudioDrive",
                    "audioOwner": bindingAudioOwner,
                    "textHash": VoiceCloneSynthesisBinding.textHash(for: text),
                ],
            ])
        }

        func installStubRuntime(
            _ label: String
        ) -> (stub: TencentDigitalHumanRuntimeStub, token: DigitalHumanLifecycleToken)? {
            invalidateDigitalHumanLifecycle(reason: "uiqaVoiceCloneRuntimeFault:\(label)")
            releaseDigitalHumanRuntime(
                reason: "uiqaVoiceCloneRuntimeFault:\(label)",
                resetsAudioOwnerToOrdinaryEcho: true
            )
            let token = captureDigitalHumanLifecycleToken(
                reason: "uiqaVoiceCloneRuntimeFault:\(label):bind"
            )
            let stub = TencentDigitalHumanRuntimeStub(contentView: UIView())
            let profile = DigitalHumanProfile(
                provider: "tencent",
                personaId: "uiqa_voice_runtime_fault",
                displayName: "UIQA 运行时故障注入",
                lifecycleMode: .sunlight,
                driveMode: "pcmAudio",
                alphaEnabled: true,
                smartActionEnabled: false,
                assetKey: "uiqa-voice-runtime-fault"
            )
            do {
                try stub.configure(profile)
                try stub.open()
            } catch {
                return nil
            }
            digitalHumanRuntime = stub
            digitalHumanRuntimeContextKey = currentDigitalHumanRuntimeContextKey()
            digitalHumanRuntimeLifecycleGeneration = token.generation
            hasRequestedCloudDigitalHumanRuntime = true
            digitalHumanLivePanelView?.hostProviderView(stub.contentView)
            applyEchoAudioRoutePolicy()
            return (stub, token)
        }

        func finish(_ result: [String: Any]) {
            VoiceCloneService.shared.persistSnapshot(originalSnapshot)
            releaseDigitalHumanRuntime(
                reason: "uiqaVoiceCloneRuntimeFaultFinished",
                resetsAudioOwnerToOrdinaryEcho: true
            )
            completion(result)
        }

        let acceptedSnapshot = profileSnapshot(
            lifecycleState: .accepted,
            sampleStatus: .ready,
            profileVersion: 1,
            expiresAt: "2099-01-01T00:00:00Z",
            isEnabled: true,
            allowedOperations: ["preview", "synthesize", "pause", "delete"]
        )
        VoiceCloneService.shared.persistSnapshot(acceptedSnapshot)
        guard let acceptedTicket = VoiceCloneService.shared.capturePersonalSynthesisUseTicket(
            forOwnerId: ownerUserId
        ),
        let validSynthesis = mockSynthesis(),
        let signal = makeTencentDigitalHumanPCMDriveSignal(from: validSynthesis),
        let pausedRuntime = installStubRuntime("paused") else {
            finish([
                "completed": false,
                "failureReason": "faultRuntimeSetupFailed",
            ])
            return
        }

        let bindingMismatchRejected = mockSynthesis(bindingAudioOwner: "volcengineLocalTTS")?.isBound(
            toOwnerUserId: ownerUserId,
            voiceProfileId: profileId,
            profileVersion: acceptedTicket.profileVersion,
            roleSubjectId: ownerUserId,
            roleKey: "personalOwner",
            personaScope: "personal",
            digitalHumanId: ownerUserId,
            requestPurpose: "echo",
            outputMode: "tencentAudioDrive",
            audioOwner: "tencentDigitalHuman",
            textHash: VoiceCloneSynthesisBinding.textHash(for: "UIQA voice clone runtime fault")
        ) == false
        let invalidPCMRejected = mockSynthesis(audioFormat: "wav")?.isTencentAudioDrivePCMCompatible == false

        let pauseRequestID = "uiqa-voice-runtime-pause"
        let pauseTurnID = ensureCurrentEchoTurnID()
        digitalHumanConversation.beginProviderRequest(
            requestID: pauseRequestID,
            replyText: "UIQA pause fence",
            turnID: pauseTurnID,
            keepsPendingReply: routeEchoAudioThroughDigitalHuman
        )
        startPCMDriveSignalToDigitalHumanRuntime(
            signal: signal,
            requestID: pauseRequestID,
            turnID: pauseTurnID,
            contextKey: currentDigitalHumanRuntimeContextKey(),
            source: "uiqaVoiceClonePaused",
            lifecycleToken: pausedRuntime.token,
            runtimeInteractionCallback: nil,
            voiceCloneUseTicket: acceptedTicket
        )
        VoiceCloneService.shared.persistSnapshot(profileSnapshot(
            lifecycleState: .paused,
            sampleStatus: .disabled,
            profileVersion: 2,
            expiresAt: "2099-01-01T00:00:00Z",
            isEnabled: false,
            allowedOperations: ["delete"]
        ))

        let pausedStub = pausedRuntime.stub
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.55) { [weak self, weak pausedStub] in
            guard let self,
                  let pausedStub else {
                return
            }
            let pausedPCMRejected = pausedStub.sentPCMChunks.isEmpty
                && self.digitalHumanConversation.activeRequestID == nil
                && self.lastEchoRuntimeFallbackReason == "voiceCloneUseTicketRevoked"
                && self.currentEchoAudioOwner == .fallbackMuted

            VoiceCloneService.shared.persistSnapshot(self.profileSnapshotForVoiceCloneRuntimeFault(
                voiceProfileId: profileId,
                lifecycleState: .accepted,
                sampleStatus: .ready,
                profileVersion: 3,
                expiresAt: "2099-01-01T00:00:00Z",
                isEnabled: true,
                allowedOperations: ["preview", "synthesize", "pause", "delete"]
            ))
            let deletedTicket = VoiceCloneService.shared.capturePersonalSynthesisUseTicket(
                forOwnerId: ownerUserId
            )
            VoiceCloneService.shared.persistSnapshot(self.profileSnapshotForVoiceCloneRuntimeFault(
                voiceProfileId: profileId,
                lifecycleState: .deleted,
                sampleStatus: .deleted,
                profileVersion: 4,
                expiresAt: "2099-01-01T00:00:00Z",
                isEnabled: false,
                allowedOperations: []
            ))
            let deletedTicketRejected = deletedTicket.map {
                !VoiceCloneService.shared.validatesPersonalSynthesisUseTicket($0)
            } ?? false

            VoiceCloneService.shared.persistSnapshot(self.profileSnapshotForVoiceCloneRuntimeFault(
                voiceProfileId: profileId,
                lifecycleState: .accepted,
                sampleStatus: .ready,
                profileVersion: 5,
                expiresAt: "2099-01-01T00:00:00Z",
                isEnabled: true,
                allowedOperations: ["preview", "synthesize", "pause", "delete"]
            ))
            let expiringTicket = VoiceCloneService.shared.capturePersonalSynthesisUseTicket(
                forOwnerId: ownerUserId
            )
            VoiceCloneService.shared.persistSnapshot(self.profileSnapshotForVoiceCloneRuntimeFault(
                voiceProfileId: profileId,
                lifecycleState: .accepted,
                sampleStatus: .ready,
                profileVersion: 5,
                expiresAt: "2000-01-01T00:00:00Z",
                isEnabled: true,
                allowedOperations: ["preview", "synthesize", "pause", "delete"]
            ))
            let expiredTicketRejected = expiringTicket.map {
                !VoiceCloneService.shared.validatesPersonalSynthesisUseTicket($0)
            } ?? false

            VoiceCloneService.shared.persistSnapshot(self.profileSnapshotForVoiceCloneRuntimeFault(
                voiceProfileId: profileId,
                lifecycleState: .accepted,
                sampleStatus: .ready,
                profileVersion: 6,
                expiresAt: "2099-01-01T00:00:00Z",
                isEnabled: true,
                allowedOperations: ["preview", "synthesize", "pause", "delete"]
            ))
            guard let staleTicket = VoiceCloneService.shared.capturePersonalSynthesisUseTicket(
                forOwnerId: ownerUserId
            ),
            let staleRuntime = installStubRuntime("roleSwitch") else {
                finish([
                    "completed": false,
                    "failureReason": "staleRuntimeSetupFailed",
                ])
                return
            }
            let staleRequestID = "uiqa-voice-runtime-stale"
            let staleTurnID = self.ensureCurrentEchoTurnID()
            self.digitalHumanConversation.beginProviderRequest(
                requestID: staleRequestID,
                replyText: "UIQA stale generation",
                turnID: staleTurnID,
                keepsPendingReply: self.routeEchoAudioThroughDigitalHuman
            )
            self.startPCMDriveSignalToDigitalHumanRuntime(
                signal: signal,
                requestID: staleRequestID,
                turnID: staleTurnID,
                contextKey: self.currentDigitalHumanRuntimeContextKey(),
                source: "uiqaVoiceCloneRoleSwitch",
                lifecycleToken: staleRuntime.token,
                runtimeInteractionCallback: nil,
                voiceCloneUseTicket: staleTicket
            )
            self.invalidateDigitalHumanLifecycle(reason: "uiqaVoiceCloneRoleSwitch")
            self.digitalHumanConversation.clearProviderRequestAndResumeState()

            let staleStub = staleRuntime.stub
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self, weak staleStub] in
                guard let self,
                      let staleStub else {
                    return
                }
                let staleGenerationPCMRejected = staleStub.sentPCMChunks.isEmpty

                let accountSwitchSnapshot = self.profileSnapshotForVoiceCloneRuntimeFault(
                    voiceProfileId: profileId,
                    lifecycleState: .accepted,
                    sampleStatus: .ready,
                    profileVersion: 7,
                    expiresAt: "2099-01-01T00:00:00Z",
                    isEnabled: true,
                    allowedOperations: ["preview", "synthesize", "pause", "delete"]
                )
                VoiceCloneService.shared.persistSnapshot(accountSwitchSnapshot)
                let switchedAccountLease = AccountLease(
                    subjectId: ownerUserId,
                    vaultId: staleTicket.accountLease.vaultId,
                    sessionId: "uiqa-voice-runtime-switched-account",
                    generation: staleTicket.accountLease.generation + 1,
                    generationId: UUID(),
                    authorityEpoch: staleTicket.accountLease.authorityEpoch
                )
                guard let accountSwitchTicket = VoiceCloneSynthesisUseTicket(
                    ownerUserId: ownerUserId,
                    accountLease: switchedAccountLease,
                    snapshot: accountSwitchSnapshot
                ),
                let accountSwitchRuntime = installStubRuntime("accountSwitch") else {
                    finish([
                        "completed": false,
                        "failureReason": "accountSwitchRuntimeSetupFailed",
                    ])
                    return
                }
                let accountSwitchRequestID = "uiqa-voice-runtime-account-switch"
                let accountSwitchTurnID = self.ensureCurrentEchoTurnID()
                self.digitalHumanConversation.beginProviderRequest(
                    requestID: accountSwitchRequestID,
                    replyText: "UIQA account switch fence",
                    turnID: accountSwitchTurnID,
                    keepsPendingReply: self.routeEchoAudioThroughDigitalHuman
                )
                self.startPCMDriveSignalToDigitalHumanRuntime(
                    signal: signal,
                    requestID: accountSwitchRequestID,
                    turnID: accountSwitchTurnID,
                    contextKey: self.currentDigitalHumanRuntimeContextKey(),
                    source: "uiqaVoiceCloneAccountSwitch",
                    lifecycleToken: accountSwitchRuntime.token,
                    runtimeInteractionCallback: nil,
                    voiceCloneUseTicket: accountSwitchTicket
                )

                let accountSwitchStub = accountSwitchRuntime.stub
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self, weak accountSwitchStub] in
                    guard let self,
                          let accountSwitchStub else {
                        return
                    }
                    let accountSwitchPCMRejected = accountSwitchStub.sentPCMChunks.isEmpty
                        && self.digitalHumanConversation.activeRequestID == nil
                        && self.lastEchoRuntimeFallbackReason == "voiceCloneUseTicketRevoked"
                        && self.currentEchoAudioOwner == .fallbackMuted

                    VoiceCloneService.shared.persistSnapshot(self.profileSnapshotForVoiceCloneRuntimeFault(
                        voiceProfileId: profileId,
                        lifecycleState: .accepted,
                        sampleStatus: .ready,
                        profileVersion: 8,
                        expiresAt: "2099-01-01T00:00:00Z",
                        isEnabled: true,
                        allowedOperations: ["preview", "synthesize", "pause", "delete"]
                    ))
                guard let stopTicket = VoiceCloneService.shared.capturePersonalSynthesisUseTicket(
                    forOwnerId: ownerUserId
                ),
                let stopRuntime = installStubRuntime("stop") else {
                    finish([
                        "completed": false,
                        "failureReason": "stopRuntimeSetupFailed",
                    ])
                    return
                }
                let stopRequestID = "uiqa-voice-runtime-stop"
                let stopTurnID = self.ensureCurrentEchoTurnID()
                self.digitalHumanConversation.beginProviderRequest(
                    requestID: stopRequestID,
                    replyText: "UIQA stop fence",
                    turnID: stopTurnID,
                    keepsPendingReply: self.routeEchoAudioThroughDigitalHuman
                )
                self.startPCMDriveSignalToDigitalHumanRuntime(
                    signal: signal,
                    requestID: stopRequestID,
                    turnID: stopTurnID,
                    contextKey: self.currentDigitalHumanRuntimeContextKey(),
                    source: "uiqaVoiceCloneStop",
                    lifecycleToken: stopRuntime.token,
                    runtimeInteractionCallback: nil,
                    voiceCloneUseTicket: stopTicket
                )
                _ = self.interruptDigitalHumanPlayback(reason: "uiqaVoiceCloneRuntimeFaultStop")

                let stopStub = stopRuntime.stub
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self, weak stopStub] in
                    guard let self,
                          let stopStub else {
                        return
                    }
                    let stoppedPCMRejected = stopStub.sentPCMChunks.isEmpty
                        && stopStub.interruptCount == 1
                        && self.digitalHumanConversation.activeRequestID == nil

                    guard let timeoutRuntime = installStubRuntime("providerTimeout") else {
                        finish([
                            "completed": false,
                            "failureReason": "timeoutRuntimeSetupFailed",
                        ])
                        return
                    }
                    let timeoutRequestID = "uiqa-voice-runtime-timeout"
                    let timeoutTurnID = self.ensureCurrentEchoTurnID()
                    self.digitalHumanConversation.beginProviderRequest(
                        requestID: timeoutRequestID,
                        replyText: "UIQA provider timeout",
                        turnID: timeoutTurnID,
                        keepsPendingReply: self.routeEchoAudioThroughDigitalHuman
                    )
                    self.handleVoiceClonePCMDriveFailureWithoutDefaultVoice(
                        requestID: timeoutRequestID,
                        turnID: timeoutTurnID,
                        voiceProfileId: profileId,
                        outputMode: "tencentAudioDrive",
                        providerLogId: nil,
                        providerRequestId: nil,
                        ownerUserId: ownerUserId,
                        reason: "providerTimeout",
                        detail: "UIQA injected provider timeout",
                        lifecycleToken: timeoutRuntime.token,
                        runtimeInteractionCallback: nil
                    )

                    let timeoutStub = timeoutRuntime.stub
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self, weak timeoutStub] in
                        guard let self,
                              let timeoutStub else {
                            return
                        }
                        let providerFailureRejected = timeoutStub.sentPCMChunks.isEmpty
                            && self.digitalHumanConversation.activeRequestID == nil
                            && self.lastEchoRuntimeFallbackReason == "providerTimeout"
                            && self.currentEchoAudioOwner == .fallbackMuted
                            && self.lastVoiceSynthesisEvidenceSummary?.status == "failed"
                        let evidencePayload: [String: Any] = [
                            "voiceProfileId": profileId,
                            "profileVersion": acceptedTicket.profileVersion,
                            "role": "personalOwner",
                            "outputMode": "tencentAudioDrive",
                            "audioOwner": self.currentEchoAudioOwner.rawValue,
                            "fallbackReason": self.lastEchoRuntimeFallbackReason ?? "none",
                            "textHash": VoiceCloneSynthesisBinding.textHash(for: "UIQA provider timeout"),
                            "bindingResult": bindingMismatchRejected ? "mismatchRejected" : "unknown",
                            "providerLogId": "redacted",
                            "rawAudioOmitted": true,
                        ]
                        let evidenceRedacted = (evidencePayload["providerLogId"] as? String) == "redacted"
                            && (evidencePayload["rawAudioOmitted"] as? Bool) == true
                            && (evidencePayload["textHash"] as? String)?.count == 64
                            && (evidencePayload["bindingResult"] as? String) == "mismatchRejected"
                        let completed = pausedPCMRejected
                            && deletedTicketRejected
                            && expiredTicketRejected
                            && staleGenerationPCMRejected
                            && accountSwitchPCMRejected
                            && stoppedPCMRejected
                            && bindingMismatchRejected
                            && invalidPCMRejected
                            && providerFailureRejected
                            && evidenceRedacted
                        self.renderVoiceStatus(
                            text: completed ? "复刻声音运行时故障注入校验完成" : "复刻声音运行时故障注入校验失败",
                            isVisible: true,
                            accessibilityIdentifier: "echoVoiceCloneRuntimeFaultStatus"
                        )
                        finish([
                            "completed": completed,
                            "pausedPCMRejected": pausedPCMRejected,
                            "deletedTicketRejected": deletedTicketRejected,
                            "expiredTicketRejected": expiredTicketRejected,
                            "staleGenerationPCMRejected": staleGenerationPCMRejected,
                            "accountSwitchPCMRejected": accountSwitchPCMRejected,
                            "stoppedPCMRejected": stoppedPCMRejected,
                            "bindingMismatchRejected": bindingMismatchRejected,
                            "invalidPCMRejected": invalidPCMRejected,
                            "providerFailureRejected": providerFailureRejected,
                            "evidenceRedacted": evidenceRedacted,
                            "evidence": evidencePayload,
                            "audioOwner": self.currentEchoAudioOwner.rawValue,
                            "voiceStatusText": self.voiceStatusLabel.text ?? "",
                        ])
                    }
                }
                }
            }
        }
    }

    private func profileSnapshotForVoiceCloneRuntimeFault(
        voiceProfileId: String,
        lifecycleState: VoiceProfileLifecycleState,
        sampleStatus: VoiceCloneSampleStatus,
        profileVersion: Int,
        expiresAt: String,
        isEnabled: Bool,
        allowedOperations: Set<String>
    ) -> VoiceCloneProfileSnapshot {
        VoiceCloneProfileSnapshot(
            voiceProfileId: voiceProfileId,
            sampleStatus: sampleStatus,
            authorizationCopy: "UIQA only: runtime fault-injection voice profile.",
            isEnabled: isEnabled,
            realCloneProviderReady: lifecycleState == .accepted,
            qualityAcceptanceRequired: false,
            disableContract: "",
            deleteContract: "",
            providerMode: "mockProvider",
            providerStatus: lifecycleState.rawValue,
            providerMessage: "",
            contractVersion: 2,
            defaultReleaseVisible: false,
            exitState: lifecycleState == .deleted ? "partial" : "active",
            accessRevoked: lifecycleState == .paused || lifecycleState == .deleted,
            localCleanupState: lifecycleState == .deleted ? "tombstoned" : "notRequested",
            providerCleanupState: "notRequested",
            providerCleanupReceiptAvailable: false,
            lifecycleSchemaVersion: "voice-profile-lifecycle-v1",
            lifecycleState: lifecycleState,
            profileVersion: profileVersion,
            retryGeneration: 0,
            stateChangedAt: "2026-08-08T00:00:00Z",
            eligibilityAllowed: lifecycleState == .accepted,
            eligibilityReasonCode: lifecycleState == .accepted
                ? "eligibleLivingAdultSelf"
                : "profileUnavailable",
            consentPurpose: "private_synthesis",
            consentState: "active",
            consentExpiresAt: expiresAt,
            allowedOperations: allowedOperations
        )
    }

    func runUIQATencentBackendPCMDriveMockSmoke(
        voiceProfileId: String,
        userId: String,
        completion: @escaping ([String: Any]) -> Void
    ) {
        invalidateDigitalHumanLifecycle(reason: "uiqaPCMDriveMockSetup")
        releaseDigitalHumanRuntime(
            reason: "uiqaPCMDriveMockSetup",
            resetsAudioOwnerToOrdinaryEcho: true
        )
        let lifecycleToken = captureDigitalHumanLifecycleToken(reason: "uiqaPCMDriveMockRuntimeBind")
        let stub = TencentDigitalHumanRuntimeStub(contentView: UIView())
        let profile = DigitalHumanProfile(
            provider: "tencent",
            personaId: "uiqa_pcm_drive",
            displayName: "UIQA 腾讯数智人",
            lifecycleMode: .sunlight,
            driveMode: "pcmAudio",
            alphaEnabled: true,
            smartActionEnabled: false,
            assetKey: "uiqa-tencent-backend-pcm"
        )

        do {
            try stub.configure(profile)
            try stub.open()
        } catch {
            completion([
                "completed": false,
                "failureReason": "stubRuntimeSetupFailed",
                "error": error.localizedDescription,
            ])
            return
        }

        digitalHumanRuntime = stub
        digitalHumanRuntimeContextKey = currentDigitalHumanRuntimeContextKey()
        digitalHumanRuntimeLifecycleGeneration = lifecycleToken.generation
        hasRequestedCloudDigitalHumanRuntime = true
        digitalHumanLivePanelView?.hostProviderView(stub.contentView)
        applyEchoAudioRoutePolicy()

        DreamJourneyBackendClient.shared.fetchVoiceCloneRuntimeCapability { [weak self] capabilityResult in
            DispatchQueue.main.async {
                guard let self,
                      self.isCurrentDigitalHumanLifecycleToken(
                        lifecycleToken,
                        reason: "uiqaPCMDriveCapabilityResponse"
                      ) else { return }
                switch capabilityResult {
                case .failure(let error):
                    completion([
                        "completed": false,
                        "failureReason": "runtimeFetchFailed",
                        "error": error.localizedDescription,
                        "voiceProfileId": voiceProfileId,
                        "userId": userId,
                    ])
                case .success(let capability):
                    guard capability.canSynthesize,
                          capability.tencentAudioDrive.supported else {
                        completion([
                            "completed": false,
                            "failureReason": "runtimeCapabilityUnavailable",
                            "voiceProfileId": voiceProfileId,
                            "userId": userId,
                            "synthesisProviderReady": capability.synthesisProviderReady,
                            "tencentAudioDriveSupported": capability.tencentAudioDrive.supported,
                        ])
                        return
                    }

                    let text = "UIQA 腾讯数智人 PCM 模拟链路：请验证后端复刻音频能被切块发送。"
                    DreamJourneyBackendClient.shared.requestVoiceCloneSynthesis(
                        userId: userId,
                        voiceProfileId: voiceProfileId,
                        text: text,
                        audioFormat: "wav",
                        sampleRate: capability.tencentAudioDrive.sampleRate,
                        speechRate: -10,
                        loudnessRate: 10,
                        outputMode: capability.tencentAudioDrive.requestOutputMode,
                        requestPurpose: "echo",
                        roleKey: "personalOwner",
                        roleSubjectId: userId,
                        personaScope: "personal",
                        digitalHumanId: userId,
                        expectedProfileVersion: 1
                    ) { [weak self] synthesisResult in
                        DispatchQueue.main.async {
                            guard let self,
                                  self.isCurrentDigitalHumanLifecycleToken(
                                    lifecycleToken,
                                    reason: "uiqaPCMDriveSynthesisResponse"
                                  ) else { return }
                            switch synthesisResult {
                            case .failure(let error):
                                completion([
                                    "completed": false,
                                    "failureReason": "synthesisFailed",
                                    "error": error.localizedDescription,
                                    "voiceProfileId": voiceProfileId,
                                    "userId": userId,
                                ])
                            case .success(let synthesis):
                                guard synthesis.isBound(
                                    toOwnerUserId: userId,
                                    voiceProfileId: voiceProfileId,
                                    profileVersion: 1,
                                    roleSubjectId: userId,
                                    roleKey: "personalOwner",
                                    personaScope: "personal",
                                    digitalHumanId: userId,
                                    requestPurpose: "echo",
                                    outputMode: "tencentAudioDrive",
                                    audioOwner: "tencentDigitalHuman",
                                    textHash: VoiceCloneSynthesisBinding.textHash(for: text)
                                ) else {
                                    completion([
                                        "completed": false,
                                        "failureReason": "synthesisBindingMismatch",
                                        "voiceProfileId": synthesis.voiceProfileId,
                                        "userId": userId,
                                    ])
                                    return
                                }
                                guard let signal = self.makeTencentDigitalHumanPCMDriveSignal(from: synthesis) else {
                                    completion([
                                        "completed": false,
                                        "failureReason": "pcmContractMismatch",
                                        "voiceProfileId": voiceProfileId,
                                        "userId": userId,
                                        "audioFormat": synthesis.audioFormat,
                                        "sampleRate": synthesis.sampleRate ?? 0,
                                        "bitsPerSample": synthesis.bitsPerSample ?? 0,
                                        "channelCount": synthesis.channelCount ?? 0,
                                        "byteCount": synthesis.byteCount,
                                    ])
                                    return
                                }

                                let expectedChunkCount = signal.chunkCount + 1
                                let preparedByteCount = signal.preparedByteCount
                                let started = self.sendTencentAudioDriveSynthesisToDigitalHumanRuntime(
                                    synthesis,
                                    source: "uiqaTencentBackendPCMDriveMockSmoke",
                                    replyText: text
                                )
                                guard started else {
                                    completion([
                                        "completed": false,
                                        "failureReason": "sendPCMDriveSignalRejected",
                                        "voiceProfileId": voiceProfileId,
                                        "userId": userId,
                                        "expectedChunkCount": expectedChunkCount,
                                    ])
                                    return
                                }

                                let wait = (Double(expectedChunkCount) * Self.tencentDigitalHumanPCMDriveChunkDuration) + 0.55
                                DispatchQueue.main.asyncAfter(deadline: .now() + wait) { [weak self, weak stub] in
                                    guard let self,
                                          let stub,
                                          self.isCurrentDigitalHumanLifecycleToken(
                                            lifecycleToken,
                                            reason: "uiqaPCMDriveResult"
                                          ) else {
                                        completion([
                                            "completed": false,
                                            "failureReason": "stubReleased",
                                        ])
                                        return
                                    }

                                    let records = stub.sentPCMChunks
                                    let sequences = records.map(\.sequence)
                                    let expectedSequences = records.isEmpty ? [] : Array(1...records.count)
                                    let sequenceIsContiguous = !records.isEmpty && sequences == expectedSequences
                                    let finalChunkObserved = records.last?.isFinal == true
                                    let nonFinalByteCount = records
                                        .filter { !$0.isFinal }
                                        .map(\.byteCount)
                                        .reduce(0, +)

                                    self.interruptDigitalHumanPlayback(reason: "backendPCMDriveMockStopProbe")
                                    let interruptProbeCompleted = stub.interruptCount > 0
                                        && self.digitalHumanConversation.activeRequestID == nil

                                    completion([
                                        "completed": started
                                            && synthesis.isTencentAudioDrivePCMCompatible
                                            && records.count == expectedChunkCount
                                            && sequenceIsContiguous
                                            && finalChunkObserved
                                            && nonFinalByteCount == preparedByteCount
                                            && interruptProbeCompleted,
                                        "voiceProfileId": synthesis.voiceProfileId,
                                        "userId": userId,
                                        "providerMode": synthesis.providerMode,
                                        "outputMode": synthesis.outputMode ?? "",
                                        "bindingVerified": true,
                                        "audioFormat": synthesis.audioFormat,
                                        "byteCount": synthesis.byteCount,
                                        "preparedByteCount": preparedByteCount,
                                        "decodedByteCount": synthesis.tencentAudioDrivePCMData?.count ?? 0,
                                        "pcmCompatible": synthesis.isTencentAudioDrivePCMCompatible,
                                        "expectedChunkCount": expectedChunkCount,
                                        "pcmChunkCount": records.count,
                                        "sentPCMByteCount": nonFinalByteCount,
                                        "finalChunkObserved": finalChunkObserved,
                                        "sequenceIsContiguous": sequenceIsContiguous,
                                        "interruptCount": stub.interruptCount,
                                        "interruptProbeCompleted": interruptProbeCompleted,
                                        "audioDataOmitted": true,
                                    ])
                                }
                            }
                        }
                    }
                }
            }
        }
    }

    func runUIQADigitalHumanRuntimeStubSmoke(completion: @escaping ([String: Any]) -> Void) {
        let context = DigitalHumanContextStore.shared.current
        guard let accountLease = echoAccountLease ?? captureEchoAccountLease(reason: "uiqaRuntimeStub"),
              validateEchoAccountLease(
                at: .request,
                expected: accountLease,
                reason: "uiqaRuntimeStub"
              ) else {
            completion([
                "completed": false,
                "failureReason": "accountLeaseUnavailable",
            ])
            return
        }
        let lifecycleToken = captureDigitalHumanLifecycleToken(reason: "uiqaRuntimeStub")
        DreamJourneyBackendClient.shared.createDigitalHumanSession(
            userId: accountLease.subjectId,
            personaId: context.ownerId,
            scene: "echo",
            deviceId: "ios-uiqa-simulator",
            lifecycleMode: context.mode,
            subjectEligibility: [
                "subjectKind": "self",
                "ageStatus": "adult",
                "livingStatus": "living",
                "ageVerified": true,
                "livenessVerified": true,
                "subjectMatchesActor": true,
                "consentVerified": true,
                "consentPurpose": "digitalHuman",
            ]
        ) { [weak self] result in
            guard let self else { return }
            guard self.validateEchoAccountLease(
                at: .ui,
                expected: accountLease,
                reason: "uiqaRuntimeStubSessionResponse"
            ),
            self.isCurrentDigitalHumanSessionToken(
                lifecycleToken,
                reason: "uiqaRuntimeStubSessionResponse"
            ) else {
                if case .success(let staleContract) = result {
                    self.releaseDigitalHumanSessionLease(
                        staleContract,
                        accountLease: accountLease,
                        reason: "uiqaStaleSessionResponse"
                    )
                }
                completion([
                    "completed": false,
                    "failureReason": "staleLifecycle",
                ])
                return
            }
            switch result {
            case .success(let contract):
                let profile = contract.toDigitalHumanProfile(displayName: context.resolvedDisplayName)
                let runtimeSelection = DigitalHumanRuntimeFactory.makeRuntime(for: contract)
                let runtime = runtimeSelection.runtime
                if let existingRuntime = self.digitalHumanRuntime,
                   existingRuntime !== runtime {
                    existingRuntime.interrupt()
                    existingRuntime.close()
                }
                self.digitalHumanRuntime = runtime
                self.digitalHumanRuntimeContextKey = lifecycleToken.contextKey
                self.digitalHumanRuntimeLifecycleGeneration = lifecycleToken.generation
                self.bindDigitalHumanRuntimeState(runtime, lifecycleToken: lifecycleToken)
                do {
                    try runtime.configure(profile)
                    try runtime.open()
                    try runtime.sendTextChunk("我在这里。", requestID: contract.sessionId, sequence: 1, isFinal: false)
                    let speakingState = runtime.state
                    try runtime.sendTextChunk("", requestID: contract.sessionId, sequence: 2, isFinal: true)

                    let audioOnlyRuntime = AudioOnlyDigitalHumanRuntime()
                    try audioOnlyRuntime.configure(profile)
                    try audioOnlyRuntime.open()

                    let payload: [String: Any] = [
                        "completed": true,
                        "provider": contract.provider,
                        "providerMode": contract.providerMode,
                        "sessionId": contract.sessionId,
                        "driveMode": contract.driveMode,
                        "runtimeProvider": runtimeSelection.selectedProvider,
                        "runtimeProviderMode": runtimeSelection.selectedMode,
                        "runtimeFactoryFallbackReason": runtimeSelection.fallbackReason ?? "",
                        "runtimeIsRealSDKBacked": runtimeSelection.isRealSDKBacked,
                        "runtimeStateAfterFinal": "\(runtime.state)",
                        "runtimeSpeakingState": "\(speakingState)",
                        "audioOnlyFallbackState": "\(audioOnlyRuntime.state)",
                        "fallbackMode": contract.fallbackMode,
                        "allowInterrupt": contract.sessionPolicy.allowInterrupt,
                        "proactiveSpeechAllowed": contract.sessionPolicy.proactiveSpeechAllowed,
                        "credentialMode": contract.credential.mode,
                        "leaseStatus": contract.lease?.status ?? "unsupported",
                        "leaseReused": contract.lease?.reused ?? false,
                        "defaultReleaseVisible": FeatureFlagService.shared.isEnabled(.digitalHumanLivePanel),
                    ]
                    self.completeUIQADigitalHumanRuntimeStubLeaseSmoke(
                        contract: contract,
                        payload: payload,
                        completion: completion
                    )
                } catch {
                    runtime.interrupt()
                    runtime.close()
                    if self.digitalHumanRuntime === runtime {
                        self.digitalHumanRuntime = nil
                        self.digitalHumanRuntimeContextKey = nil
                        self.digitalHumanRuntimeLifecycleGeneration = nil
                    }
                    self.completeUIQADigitalHumanRuntimeStubLeaseSmoke(
                        contract: contract,
                        payload: [
                        "completed": false,
                        "failureReason": "runtimeError",
                        "error": error.localizedDescription,
                        ],
                        completion: completion
                    )
                }
            case .failure(let error):
                let message = error.localizedDescription
                let isExpectedBrokerBlock = message.contains(
                    "revocable scoped session credential broker"
                )
                if isExpectedBrokerBlock {
                    self.failClosedDigitalHumanRuntimePreparation(
                        requestOwnerUserId: accountLease.subjectId,
                        reason: "uiqaScopedBrokerRequired",
                        detail: message
                    )
                }
                let visibleFallbackDetail = self.digitalHumanStatusDetailLabel.text ?? ""
                let visibleFallback = isExpectedBrokerBlock
                    && visibleFallbackDetail == "数字人暂不可用，已回到普通回响"
                completion([
                    "completed": isExpectedBrokerBlock && visibleFallback,
                    "failureReason": isExpectedBrokerBlock ? "" : "backendSessionError",
                    "boundaryState": isExpectedBrokerBlock ? "scopedBrokerRequired" : "unexpectedBackendError",
                    "provider": "tencent",
                    "providerMode": "blockedUntilScopedBroker",
                    "runtimeProvider": "none",
                    "runtimeIsRealSDKBacked": false,
                    "fallbackMode": "textOnly",
                    "visibleFallback": visibleFallback,
                    "visibleFallbackDetail": visibleFallbackDetail,
                    "audioOwner": self.currentEchoAudioOwner.rawValue,
                    "error": message,
                ])
            }
        }
    }

    private func completeUIQADigitalHumanRuntimeStubLeaseSmoke(
        contract: DigitalHumanSessionContract,
        payload: [String: Any],
        completion: @escaping ([String: Any]) -> Void
    ) {
        guard contract.lease != nil else {
            completion(payload.merging([
                "leaseHeartbeatStatus": "unsupported",
                "leaseReleaseStatus": "unsupported",
            ]) { _, new in new })
            return
        }

        DreamJourneyBackendClient.shared.heartbeatDigitalHumanSession(contract) { heartbeatResult in
            let heartbeatStatus: String
            switch heartbeatResult {
            case .success(let operation):
                heartbeatStatus = operation.lease.status
            case .failure(let error):
                heartbeatStatus = "failed:\(error.localizedDescription)"
            }

            DreamJourneyBackendClient.shared.releaseDigitalHumanSession(
                contract,
                reason: "uiqaRuntimeStubCompleted"
            ) { releaseResult in
                let releaseStatus: String
                switch releaseResult {
                case .success(let operation):
                    releaseStatus = operation.status
                case .failure(let error):
                    releaseStatus = "failed:\(error.localizedDescription)"
                }
                completion(payload.merging([
                    "leaseHeartbeatStatus": heartbeatStatus,
                    "leaseReleaseStatus": releaseStatus,
                ]) { _, new in new })
            }
        }
    }
}
#endif

private final class EchoScenicParkView: UIView {
    private let backgroundImageLayer = CALayer()
    private let skyLayer = CAGradientLayer()
    private let meadowLayer = CAShapeLayer()
    private let pathLayer = CAShapeLayer()
    private let treeBackLayer = CAShapeLayer()
    private let treeFrontLayer = CAShapeLayer()
    private let lightLayer = CAShapeLayer()
    private let overlayLayer = CAGradientLayer()

    override init(frame: CGRect) {
        super.init(frame: frame)
        isUserInteractionEnabled = false
        clipsToBounds = true
        layer.addSublayer(backgroundImageLayer)
        layer.addSublayer(skyLayer)
        layer.addSublayer(lightLayer)
        layer.addSublayer(treeBackLayer)
        layer.addSublayer(meadowLayer)
        layer.addSublayer(pathLayer)
        layer.addSublayer(treeFrontLayer)
        layer.addSublayer(overlayLayer)
        configureLayers()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        backgroundImageLayer.frame = bounds
        skyLayer.frame = bounds
        overlayLayer.frame = bounds

        let width = bounds.width
        let height = bounds.height

        let lightPath = UIBezierPath(ovalIn: CGRect(x: width * 0.58, y: height * 0.08, width: 150, height: 150))
        lightLayer.path = lightPath.cgPath

        let meadowPath = UIBezierPath()
        meadowPath.move(to: CGPoint(x: 0, y: height * 0.45))
        meadowPath.addCurve(
            to: CGPoint(x: width, y: height * 0.42),
            controlPoint1: CGPoint(x: width * 0.28, y: height * 0.36),
            controlPoint2: CGPoint(x: width * 0.72, y: height * 0.55)
        )
        meadowPath.addLine(to: CGPoint(x: width, y: height))
        meadowPath.addLine(to: CGPoint(x: 0, y: height))
        meadowPath.close()
        meadowLayer.path = meadowPath.cgPath

        let path = UIBezierPath()
        path.move(to: CGPoint(x: width * 0.42, y: height))
        path.addCurve(
            to: CGPoint(x: width * 0.55, y: height * 0.48),
            controlPoint1: CGPoint(x: width * 0.50, y: height * 0.82),
            controlPoint2: CGPoint(x: width * 0.38, y: height * 0.60)
        )
        path.addCurve(
            to: CGPoint(x: width * 0.66, y: height),
            controlPoint1: CGPoint(x: width * 0.72, y: height * 0.62),
            controlPoint2: CGPoint(x: width * 0.74, y: height * 0.82)
        )
        path.close()
        pathLayer.path = path.cgPath

        treeBackLayer.path = makeTreeLine(
            bounds: bounds,
            baseY: height * 0.39,
            radius: 58,
            count: 6,
            xOffset: -30
        ).cgPath
        treeFrontLayer.path = makeTreeLine(
            bounds: bounds,
            baseY: height * 0.49,
            radius: 72,
            count: 5,
            xOffset: 18
        ).cgPath
    }

    private func configureLayers() {
        let backgroundImage = UIImage(named: "echo_park_background")
        backgroundImageLayer.contents = backgroundImage?.cgImage
        backgroundImageLayer.contentsGravity = .resizeAspectFill
        backgroundImageLayer.isHidden = backgroundImage == nil

        let shouldUseVectorFallback = backgroundImage == nil
        [skyLayer, lightLayer, treeBackLayer, meadowLayer, pathLayer, treeFrontLayer].forEach {
            $0.isHidden = !shouldUseVectorFallback
        }

        skyLayer.colors = [
            UIColor(hex: "#fff9f0").cgColor,
            UIColor(hex: "#f7dfbd").cgColor,
            UIColor(hex: "#d8c89d").cgColor
        ]
        skyLayer.startPoint = CGPoint(x: 0.5, y: 0)
        skyLayer.endPoint = CGPoint(x: 0.5, y: 1)

        lightLayer.fillColor = UIColor(hex: "#fff2c6").withAlphaComponent(0.72).cgColor

        treeBackLayer.fillColor = UIColor(hex: "#b8aa78").withAlphaComponent(0.82).cgColor
        treeFrontLayer.fillColor = UIColor(hex: "#7f8d5d").withAlphaComponent(0.78).cgColor
        meadowLayer.fillColor = UIColor(hex: "#c8b982").withAlphaComponent(0.86).cgColor
        pathLayer.fillColor = UIColor(hex: "#e8cfa8").withAlphaComponent(0.9).cgColor

        overlayLayer.colors = [
            UIColor.clear.cgColor,
            UIColor(hex: "#fff9f0").withAlphaComponent(backgroundImage == nil ? 0.34 : 0.12).cgColor,
            UIColor(hex: "#fff9f0").withAlphaComponent(backgroundImage == nil ? 0.82 : 0.72).cgColor
        ]
        overlayLayer.locations = [0, 0.58, 1]
        overlayLayer.startPoint = CGPoint(x: 0.5, y: 0)
        overlayLayer.endPoint = CGPoint(x: 0.5, y: 1)
    }

    private func makeTreeLine(
        bounds: CGRect,
        baseY: CGFloat,
        radius: CGFloat,
        count: Int,
        xOffset: CGFloat
    ) -> UIBezierPath {
        let path = UIBezierPath()
        let spacing = bounds.width / CGFloat(max(count - 1, 1))

        for index in 0..<count {
            let centerX = CGFloat(index) * spacing + xOffset
            let rect = CGRect(
                x: centerX - radius,
                y: baseY - radius,
                width: radius * 2,
                height: radius * 1.45
            )
            path.append(UIBezierPath(ovalIn: rect))
        }

        let ground = CGRect(x: -40, y: baseY + radius * 0.28, width: bounds.width + 80, height: radius)
        path.append(UIBezierPath(roundedRect: ground, cornerRadius: radius * 0.5))
        return path
    }
}
