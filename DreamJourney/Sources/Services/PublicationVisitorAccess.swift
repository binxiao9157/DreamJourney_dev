import Foundation

/// Narrow QA-only boundary for the closed M2 visitor reader contract.
///
/// Release artifacts always evaluate this as disabled. The first iOS slice
/// deliberately has no public entry point, persisted credential, or runtime
/// activation path.
enum PublicationVisitorM2QAGate {
    static let launchArgument = "DJEnablePublicationVisitorM2QA"

    static var isEnabled: Bool {
        #if DEBUG || UI_QA_SIMULATOR
        ProcessInfo.processInfo.arguments.contains(launchArgument)
        #else
        false
        #endif
    }
}

enum PublicationVisitorM2AccessGate {
    static var isRouteAllowed: Bool {
        PublicationVisitorM2QAGate.isEnabled
            || FeatureGateService.shared.isServerPolicyManagedRouteAllowed(
                .publicationVisitorM2
            )
    }
}

enum PublicationVisitorAccessError: LocalizedError, Equatable {
    case disabled
    case invalidInvitation
    case adultVerificationRequired
    case invalidScope
    case expired
    case accountLeaseInvalid
    case malformedResponse
    case responseScopeMismatch
    case accessRevoked
    case sessionUnavailable
    case invalidQuestion

    var errorDescription: String? {
        switch self {
        case .disabled:
            return "受邀访问当前未启用"
        case .invalidInvitation:
            return "受邀访问链接无效"
        case .adultVerificationRequired:
            return "该受邀访问需要先完成成年身份校验"
        case .invalidScope:
            return "受邀访问范围无效"
        case .expired:
            return "受邀访问已过期"
        case .accountLeaseInvalid:
            return "当前账户状态已变更"
        case .malformedResponse:
            return "公开副本响应无效"
        case .responseScopeMismatch:
            return "公开副本与当前访问范围不一致"
        case .accessRevoked:
            return "该公开内容已撤回或当前访问已被撤销"
        case .sessionUnavailable:
            return "该受邀访问当前不可用"
        case .invalidQuestion:
            return "问题内容无效"
        }
    }
}

/// A process-memory-only invitation. Grant credentials are never persisted,
/// encoded, logged, or exposed back to UI code.
struct PublicationVisitorInvitation: Equatable {
    let grantID: String
    private let grantCredential: String

    init?(grantID: String, grantCredential: String) {
        let normalizedGrantID = grantID.trimmingCharacters(in: .whitespacesAndNewlines)
        let normalizedCredential = grantCredential.trimmingCharacters(in: .whitespacesAndNewlines)
        guard UUID(uuidString: normalizedGrantID) != nil,
              (24...256).contains(normalizedCredential.count) else {
            return nil
        }
        self.grantID = normalizedGrantID.lowercased()
        self.grantCredential = normalizedCredential
    }

    init?(deepLinkURL: URL) {
        guard let components = URLComponents(url: deepLinkURL, resolvingAgainstBaseURL: false) else {
            return nil
        }
        let normalizedScheme = components.scheme?.lowercased() ?? ""
        let normalizedHost = components.host?.lowercased() ?? ""
        let normalizedPath = components.path.lowercased()
        let isAppLink = normalizedScheme == "dreamjourney"
            && normalizedHost == "publication"
            && normalizedPath == "/visitor"
        let isUniversalLink = ["http", "https"].contains(normalizedScheme)
            && normalizedPath.hasSuffix("/publication/visitor")
        guard isAppLink || isUniversalLink else { return nil }

        let items = components.queryItems ?? []
        guard items.filter({ $0.name == "grantId" }).count == 1,
              items.filter({ $0.name == "grantCredential" }).count == 1,
              let grantID = items.first(where: { $0.name == "grantId" })?.value,
              let grantCredential = items.first(where: { $0.name == "grantCredential" })?.value else {
            return nil
        }
        self.init(grantID: grantID, grantCredential: grantCredential)
    }

    func requestPayload(sessionCredential: String) -> [String: Any] {
        [
            "commandId": UUID().uuidString.lowercased(),
            "grantCredential": grantCredential,
            "sessionCredential": sessionCredential,
        ]
    }
}

struct PublicationVisitorAdmission: Equatable {
    static let schemaVersion = "publication-visitor-access-v1"

    let grantID: String
    let visitorSessionID: String
    let publicationID: String
    let publicationVersionID: String
    let expiresAt: Date
    let useRemaining: Int

    init?(json: [String: Any]) {
        guard json["schemaVersion"] as? String == Self.schemaVersion,
              let grantID = Self.identifier(json["grantId"] as? String),
              let visitorSessionID = Self.identifier(json["visitorSessionId"] as? String),
              let publicationID = Self.identifier(json["publicationId"] as? String),
              let publicationVersionID = Self.identifier(json["publicationVersionId"] as? String),
              let expiresAt = Self.date(json["expiresAt"] as? String),
              let useRemaining = json["useRemaining"] as? Int,
              useRemaining >= 0 else {
            return nil
        }
        self.grantID = grantID
        self.visitorSessionID = visitorSessionID
        self.publicationID = publicationID
        self.publicationVersionID = publicationVersionID
        self.expiresAt = expiresAt
        self.useRemaining = useRemaining
    }

    func sessionScope(
        sessionCredential: String,
        accountLease: AccountLease,
        now: Date = Date()
    ) -> PublicationVisitorSessionScope? {
        PublicationVisitorSessionScope(
            visitorSessionID: visitorSessionID,
            publicationID: publicationID,
            publicationVersionID: publicationVersionID,
            expiresAt: expiresAt,
            sessionCredential: sessionCredential,
            accountLease: accountLease,
            now: now
        )
    }

    private static func identifier(_ value: String?) -> String? {
        let normalized = value?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return normalized.isEmpty ? nil : normalized
    }

    private static func date(_ value: String?) -> Date? {
        guard let value = identifier(value) else { return nil }
        let base = ISO8601DateFormatter()
        let fractional = ISO8601DateFormatter()
        fractional.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return fractional.date(from: value) ?? base.date(from: value)
    }
}

protocol PublicationVisitorAdmissionClient {
    func admitVisitor(
        invitation: PublicationVisitorInvitation,
        sessionCredential: String,
        accountLease: AccountLease,
        completion: @escaping (Result<PublicationVisitorAdmission, Error>) -> Void
    )
}

/// An in-memory visitor capability. It is intentionally not Codable and does
/// not expose the credential to callers outside this module.
struct PublicationVisitorSessionScope: Equatable {
    let visitorSessionID: String
    let publicationID: String
    let publicationVersionID: String
    let expiresAt: Date
    let accountLease: AccountLease
    private let sessionCredential: String

    init?(
        visitorSessionID: String,
        publicationID: String,
        publicationVersionID: String,
        expiresAt: Date,
        sessionCredential: String,
        accountLease: AccountLease,
        now: Date = Date()
    ) {
        guard let normalizedVisitorSessionID = Self.normalized(visitorSessionID),
              let normalizedPublicationID = Self.normalized(publicationID),
              let normalizedPublicationVersionID = Self.normalized(publicationVersionID),
              let normalizedCredential = Self.normalized(sessionCredential),
              normalizedCredential.count >= 24,
              expiresAt > now,
              Self.normalized(accountLease.subjectId) != nil,
              Self.normalized(accountLease.vaultId) != nil,
              Self.normalized(accountLease.authorityEpoch) != nil else {
            return nil
        }
        self.visitorSessionID = normalizedVisitorSessionID
        self.publicationID = normalizedPublicationID
        self.publicationVersionID = normalizedPublicationVersionID
        self.expiresAt = expiresAt
        self.sessionCredential = normalizedCredential
        self.accountLease = accountLease
    }

    func isUsable(
        at instant: Date = Date(),
        accountLeaseRuntime: AccountLeaseRuntimePort = AccountLeaseRuntime.shared
    ) -> Bool {
        guard expiresAt > instant else { return false }
        return AccountLeaseCheckpoint.allCases.allSatisfy {
            accountLeaseRuntime.validate(accountLease, at: $0).allowed
        }
    }

    func requestPayload() -> [String: Any] {
        ["sessionCredential": sessionCredential]
    }

    private static func normalized(_ value: String) -> String? {
        let normalizedValue = value.trimmingCharacters(in: .whitespacesAndNewlines)
        return normalizedValue.isEmpty ? nil : normalizedValue
    }
}

struct PublicationVisitorProjectionSource: Equatable {
    let kind: String
    let projectionHash: String
    let publicCitationHash: String

    init?(json: [String: Any]) {
        guard let kind = Self.normalized(json["kind"] as? String),
              let projectionHash = Self.sha256(json["projectionHash"] as? String),
              let publicCitationHash = Self.sha256(json["publicCitationHash"] as? String) else {
            return nil
        }
        self.kind = kind
        self.projectionHash = projectionHash
        self.publicCitationHash = publicCitationHash
    }

    private static func normalized(_ value: String?) -> String? {
        let normalizedValue = value?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return normalizedValue.isEmpty ? nil : normalizedValue
    }

    private static func sha256(_ value: String?) -> String? {
        guard let normalizedValue = normalized(value),
              normalizedValue.count == 64,
              normalizedValue.allSatisfy({ $0.isHexDigit }) else {
            return nil
        }
        return normalizedValue.lowercased()
    }
}

struct PublicationVisitorAnswerBoundary: Equatable {
    let identityDisclosureRequired: Bool
    let privateContextAllowed: Bool
    let providerCallAllowed: Bool
    let unknownFallbackRequired: Bool

    init?(json: [String: Any]) {
        guard let identityDisclosureRequired = json["identityDisclosureRequired"] as? Bool,
              let privateContextAllowed = json["privateContextAllowed"] as? Bool,
              let providerCallAllowed = json["providerCallAllowed"] as? Bool,
              let unknownFallbackRequired = json["unknownFallbackRequired"] as? Bool,
              identityDisclosureRequired,
              !privateContextAllowed,
              !providerCallAllowed,
              unknownFallbackRequired else {
            return nil
        }
        self.identityDisclosureRequired = identityDisclosureRequired
        self.privateContextAllowed = privateContextAllowed
        self.providerCallAllowed = providerCallAllowed
        self.unknownFallbackRequired = unknownFallbackRequired
    }
}

struct PublicationVisitorProjection: Equatable {
    static let schemaVersion = "publication-visitor-reader-v1"

    let visitorSessionID: String
    let publicationID: String
    let publicationVersionID: String
    let expiresAt: Date
    let title: String
    let body: String
    let aiDisclosure: String
    let source: PublicationVisitorProjectionSource
    let answerBoundary: PublicationVisitorAnswerBoundary

    init?(json: [String: Any]) {
        guard json["schemaVersion"] as? String == Self.schemaVersion,
              let visitorSessionID = Self.normalized(json["visitorSessionId"] as? String),
              let publicationID = Self.normalized(json["publicationId"] as? String),
              let publicationVersionID = Self.normalized(json["publicationVersionId"] as? String),
              let expiresAt = Self.date(json["expiresAt"] as? String),
              let title = Self.text(json["title"] as? String, maximumLength: 120),
              let body = Self.text(json["body"] as? String, maximumLength: 12_000),
              let aiDisclosure = Self.text(json["aiDisclosure"] as? String, maximumLength: 300),
              let source = PublicationVisitorProjectionSource(json: json["source"] as? [String: Any] ?? [:]),
              let answerBoundary = PublicationVisitorAnswerBoundary(json: json["answerBoundary"] as? [String: Any] ?? [:]) else {
            return nil
        }
        self.visitorSessionID = visitorSessionID
        self.publicationID = publicationID
        self.publicationVersionID = publicationVersionID
        self.expiresAt = expiresAt
        self.title = title
        self.body = body
        self.aiDisclosure = aiDisclosure
        self.source = source
        self.answerBoundary = answerBoundary
    }

    func matches(_ scope: PublicationVisitorSessionScope) -> Bool {
        visitorSessionID == scope.visitorSessionID
            && publicationID == scope.publicationID
            && publicationVersionID == scope.publicationVersionID
            && abs(expiresAt.timeIntervalSince(scope.expiresAt)) < 1
    }

    private static func normalized(_ value: String?) -> String? {
        let normalizedValue = value?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return normalizedValue.isEmpty ? nil : normalizedValue
    }

    private static func text(_ value: String?, maximumLength: Int) -> String? {
        guard let normalizedValue = normalized(value), normalizedValue.count <= maximumLength else {
            return nil
        }
        return normalizedValue
    }

    private static func date(_ value: String?) -> Date? {
        guard let value = normalized(value) else { return nil }
        let formatters: [ISO8601DateFormatter] = [
            ISO8601DateFormatter(),
            ISO8601DateFormatter(),
        ]
        formatters[0].formatOptions = [.withInternetDateTime]
        formatters[1].formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatters.lazy.compactMap { $0.date(from: value) }.first
    }
}

struct PublicationVisitorAnswer: Equatable {
    enum Kind: String {
        case excerpt
        case unknown
    }

    let kind: Kind
    let text: String
    let identityDisclosure: String
    let source: String
    let publicCitationHash: String
    let uncertainty: String
    let reasonCode: String

    init?(json: [String: Any]) {
        guard let kindRaw = json["kind"] as? String,
              let kind = Kind(rawValue: kindRaw),
              let text = Self.text(json["text"] as? String, maximumLength: 12_400),
              let identityDisclosure = Self.text(json["identityDisclosure"] as? String, maximumLength: 300),
              let source = Self.text(json["source"] as? String, maximumLength: 128),
              let publicCitationHash = Self.sha256(json["publicCitationHash"] as? String),
              let uncertainty = Self.text(json["uncertainty"] as? String, maximumLength: 128),
              let reasonCode = Self.text(json["reasonCode"] as? String, maximumLength: 128) else {
            return nil
        }
        self.kind = kind
        self.text = text
        self.identityDisclosure = identityDisclosure
        self.source = source
        self.publicCitationHash = publicCitationHash
        self.uncertainty = uncertainty
        self.reasonCode = reasonCode
    }

    private static func text(_ value: String?, maximumLength: Int) -> String? {
        let normalizedValue = value?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        guard !normalizedValue.isEmpty, normalizedValue.count <= maximumLength else {
            return nil
        }
        return normalizedValue
    }

    private static func sha256(_ value: String?) -> String? {
        let normalizedValue = value?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        guard normalizedValue.count == 64,
              normalizedValue.allSatisfy({ $0.isHexDigit }) else {
            return nil
        }
        return normalizedValue.lowercased()
    }
}

struct PublicationVisitorAnswerResponse: Equatable {
    let projection: PublicationVisitorProjection
    let answer: PublicationVisitorAnswer

    init?(json: [String: Any]) {
        guard let projection = PublicationVisitorProjection(json: json),
              let answer = PublicationVisitorAnswer(json: json["answer"] as? [String: Any] ?? [:]),
              answer.publicCitationHash == projection.source.publicCitationHash else {
            return nil
        }
        self.projection = projection
        self.answer = answer
    }
}

protocol PublicationVisitorReaderClient {
    func fetchProjection(
        scope: PublicationVisitorSessionScope,
        completion: @escaping (Result<PublicationVisitorProjection, Error>) -> Void
    )

    func answer(
        scope: PublicationVisitorSessionScope,
        question: String,
        completion: @escaping (Result<PublicationVisitorAnswerResponse, Error>) -> Void
    )
}

enum PublicationVisitorSessionInvalidationReason: String, Equatable {
    case none
    case expired
    case accountLeaseInvalid
    case responseScopeMismatch
    case accessRevoked
    case sessionUnavailable
    case policyDenied
    case manuallyReleased
}

struct PublicationVisitorSessionSnapshot: Equatable {
    let isActive: Bool
    let visitorSessionID: String?
    let publicationID: String?
    let publicationVersionID: String?
    let expiresAt: Date?
    let invalidationReason: PublicationVisitorSessionInvalidationReason
}

/// Holds exactly one active visitor scope in memory. Clearing this coordinator
/// drops the credential and the projection together; no visitor content is
/// written to app storage or shared with another account lifecycle.
final class PublicationVisitorSessionCoordinator {
    private let lock = NSLock()
    private let accountLeaseRuntime: AccountLeaseRuntimePort
    private var activeScope: PublicationVisitorSessionScope?
    private var activeProjection: PublicationVisitorProjection?
    private var invalidationReason: PublicationVisitorSessionInvalidationReason = .none

    init(accountLeaseRuntime: AccountLeaseRuntimePort = AccountLeaseRuntime.shared) {
        self.accountLeaseRuntime = accountLeaseRuntime
    }

    @discardableResult
    func activate(_ scope: PublicationVisitorSessionScope, at instant: Date = Date()) -> Bool {
        guard scope.isUsable(at: instant, accountLeaseRuntime: accountLeaseRuntime) else {
            invalidate(scope.expiresAt <= instant ? .expired : .accountLeaseInvalid)
            return false
        }
        lock.lock()
        activeScope = scope
        activeProjection = nil
        invalidationReason = .none
        lock.unlock()
        return true
    }

    func currentScope(at instant: Date = Date()) -> PublicationVisitorSessionScope? {
        lock.lock()
        let scope = activeScope
        lock.unlock()
        guard let scope else { return nil }
        guard scope.isUsable(at: instant, accountLeaseRuntime: accountLeaseRuntime) else {
            invalidate(scope.expiresAt <= instant ? .expired : .accountLeaseInvalid)
            return nil
        }
        return scope
    }

    @discardableResult
    func accept(
        _ projection: PublicationVisitorProjection,
        for scope: PublicationVisitorSessionScope,
        at instant: Date = Date()
    ) -> Bool {
        guard currentScope(at: instant) == scope else { return false }
        guard projection.matches(scope) else {
            invalidate(.responseScopeMismatch)
            return false
        }
        lock.lock()
        activeProjection = projection
        lock.unlock()
        return true
    }

    func currentProjection(at instant: Date = Date()) -> PublicationVisitorProjection? {
        guard currentScope(at: instant) != nil else { return nil }
        lock.lock()
        defer { lock.unlock() }
        return activeProjection
    }

    func invalidate(_ reason: PublicationVisitorSessionInvalidationReason) {
        lock.lock()
        activeScope = nil
        activeProjection = nil
        invalidationReason = reason
        lock.unlock()
    }

    func snapshot() -> PublicationVisitorSessionSnapshot {
        lock.lock()
        defer { lock.unlock() }
        return PublicationVisitorSessionSnapshot(
            isActive: activeScope != nil,
            visitorSessionID: activeScope?.visitorSessionID,
            publicationID: activeScope?.publicationID,
            publicationVersionID: activeScope?.publicationVersionID,
            expiresAt: activeScope?.expiresAt,
            invalidationReason: invalidationReason
        )
    }
}

struct PublicationVisitorRuntimeSnapshot: Equatable {
    let hasPendingInvitation: Bool
    let session: PublicationVisitorSessionSnapshot
}

/// Owns the one process-local Visitor invitation and session. A generation
/// fence prevents an admission callback from a previous account or invitation
/// from reactivating cleared access.
final class PublicationVisitorRuntime {
    static let shared = PublicationVisitorRuntime()

    private let lock = NSLock()
    private let client: PublicationVisitorAdmissionClient
    private let sessionCoordinator: PublicationVisitorSessionCoordinator
    private let accountLeaseRuntime: AccountLeaseRuntimePort
    private let routeAllowed: () -> Bool
    private var pendingInvitation: PublicationVisitorInvitation?
    private var admissionGeneration = UUID()

    init(
        client: PublicationVisitorAdmissionClient = DreamJourneyBackendClient.shared,
        sessionCoordinator: PublicationVisitorSessionCoordinator = PublicationVisitorSessionCoordinator(),
        accountLeaseRuntime: AccountLeaseRuntimePort = AccountLeaseRuntime.shared,
        routeAllowed: @escaping () -> Bool = { PublicationVisitorM2AccessGate.isRouteAllowed }
    ) {
        self.client = client
        self.sessionCoordinator = sessionCoordinator
        self.accountLeaseRuntime = accountLeaseRuntime
        self.routeAllowed = routeAllowed
    }

    @discardableResult
    func stage(deepLinkURL: URL) -> Bool {
        guard let invitation = PublicationVisitorInvitation(deepLinkURL: deepLinkURL) else {
            return false
        }
        stage(invitation)
        return true
    }

    func stage(_ invitation: PublicationVisitorInvitation) {
        lock.lock()
        pendingInvitation = invitation
        admissionGeneration = UUID()
        lock.unlock()
        sessionCoordinator.invalidate(.manuallyReleased)
    }

    var hasPendingInvitation: Bool {
        lock.lock()
        defer { lock.unlock() }
        return pendingInvitation != nil
    }

    var hasPendingOrActiveAccess: Bool {
        hasPendingInvitation || sessionCoordinator.currentScope() != nil
    }

    func open(
        accountLease: AccountLease,
        completion: @escaping (Result<PublicationVisitorSessionScope, Error>) -> Void
    ) {
        if let scope = sessionCoordinator.currentScope(), scope.accountLease == accountLease {
            completion(.success(scope))
            return
        }
        guard routeAllowed() else {
            clear(reason: .policyDenied)
            completion(.failure(PublicationVisitorAccessError.disabled))
            return
        }
        guard accountLeaseRuntime.validate(accountLease, at: .request).allowed else {
            clear(reason: .accountLeaseInvalid)
            completion(.failure(PublicationVisitorAccessError.accountLeaseInvalid))
            return
        }

        lock.lock()
        let invitation = pendingInvitation
        let generation = admissionGeneration
        lock.unlock()
        guard let invitation else {
            completion(.failure(PublicationVisitorAccessError.sessionUnavailable))
            return
        }

        let sessionCredential = Self.makeSessionCredential()
        client.admitVisitor(
            invitation: invitation,
            sessionCredential: sessionCredential,
            accountLease: accountLease
        ) { [weak self] result in
            guard let self else { return }
            self.lock.lock()
            let isCurrent = self.admissionGeneration == generation
            self.lock.unlock()
            guard isCurrent,
                  self.accountLeaseRuntime.validate(accountLease, at: .commit).allowed else {
                completion(.failure(PublicationVisitorAccessError.accountLeaseInvalid))
                return
            }

            switch result {
            case .success(let admission):
                guard admission.grantID == invitation.grantID,
                      let scope = admission.sessionScope(
                        sessionCredential: sessionCredential,
                        accountLease: accountLease
                      ),
                      self.sessionCoordinator.activate(scope) else {
                    self.clear(reason: .responseScopeMismatch)
                    completion(.failure(PublicationVisitorAccessError.malformedResponse))
                    return
                }
                self.lock.lock()
                if self.admissionGeneration == generation {
                    self.pendingInvitation = nil
                }
                self.lock.unlock()
                completion(.success(scope))
            case .failure(let error):
                let mapped = Self.admissionError(error)
                self.clear(reason: mapped.reason)
                completion(.failure(mapped.error))
            }
        }
    }

    func makeReadUseCase(
        client: PublicationVisitorReaderClient = DreamJourneyBackendClient.shared
    ) -> PublicationVisitorReadUseCase {
        PublicationVisitorReadUseCase(client: client, sessionCoordinator: sessionCoordinator)
    }

    func clear(reason: PublicationVisitorSessionInvalidationReason) {
        lock.lock()
        pendingInvitation = nil
        admissionGeneration = UUID()
        lock.unlock()
        sessionCoordinator.invalidate(reason)
    }

    func snapshot() -> PublicationVisitorRuntimeSnapshot {
        PublicationVisitorRuntimeSnapshot(
            hasPendingInvitation: hasPendingInvitation,
            session: sessionCoordinator.snapshot()
        )
    }

    private static func makeSessionCredential() -> String {
        UUID().uuidString.replacingOccurrences(of: "-", with: "").lowercased()
            + UUID().uuidString.replacingOccurrences(of: "-", with: "").lowercased()
    }

    private static func admissionError(
        _ error: Error
    ) -> (reason: PublicationVisitorSessionInvalidationReason, error: Error) {
        guard case let DreamJourneyBackendClient.ClientError.backendError(_, context) = error else {
            return (.sessionUnavailable, error)
        }
        switch context.code {
        case "publicationVisitorAdultVerificationRequired":
            return (.sessionUnavailable, PublicationVisitorAccessError.adultVerificationRequired)
        case "publicationVisitorAccessDenied", "publicationVisitorAccessUnavailable":
            return (.accessRevoked, PublicationVisitorAccessError.accessRevoked)
        default:
            return (.sessionUnavailable, error)
        }
    }
}

final class PublicationVisitorReadUseCase {
    private let client: PublicationVisitorReaderClient
    private let sessionCoordinator: PublicationVisitorSessionCoordinator

    init(
        client: PublicationVisitorReaderClient,
        sessionCoordinator: PublicationVisitorSessionCoordinator
    ) {
        self.client = client
        self.sessionCoordinator = sessionCoordinator
    }

    func loadProjection(
        completion: @escaping (Result<PublicationVisitorProjection, Error>) -> Void
    ) {
        guard let scope = sessionCoordinator.currentScope() else {
            completion(.failure(PublicationVisitorAccessError.sessionUnavailable))
            return
        }
        client.fetchProjection(scope: scope) { [weak self] result in
            switch result {
            case .success(let projection):
                guard self?.sessionCoordinator.accept(projection, for: scope) == true else {
                    completion(.failure(PublicationVisitorAccessError.responseScopeMismatch))
                    return
                }
                completion(.success(projection))
            case .failure(let error):
                let resolution = Self.resolveFailure(error)
                self?.sessionCoordinator.invalidate(resolution.invalidationReason)
                completion(.failure(resolution.error))
            }
        }
    }

    func answer(
        _ question: String,
        completion: @escaping (Result<PublicationVisitorAnswerResponse, Error>) -> Void
    ) {
        let normalizedQuestion = question.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !normalizedQuestion.isEmpty, normalizedQuestion.count <= 800 else {
            completion(.failure(PublicationVisitorAccessError.invalidQuestion))
            return
        }
        guard let scope = sessionCoordinator.currentScope() else {
            completion(.failure(PublicationVisitorAccessError.sessionUnavailable))
            return
        }
        client.answer(scope: scope, question: normalizedQuestion) { [weak self] result in
            switch result {
            case .success(let response):
                guard self?.sessionCoordinator.accept(response.projection, for: scope) == true else {
                    completion(.failure(PublicationVisitorAccessError.responseScopeMismatch))
                    return
                }
                completion(.success(response))
            case .failure(let error):
                let resolution = Self.resolveFailure(error)
                self?.sessionCoordinator.invalidate(resolution.invalidationReason)
                completion(.failure(resolution.error))
            }
        }
    }

    func release() {
        sessionCoordinator.invalidate(.manuallyReleased)
    }

    private static func resolveFailure(
        _ error: Error
    ) -> (invalidationReason: PublicationVisitorSessionInvalidationReason, error: Error) {
        guard case let DreamJourneyBackendClient.ClientError.backendError(statusCode, context) = error,
              let code = context.code else {
            return (.sessionUnavailable, error)
        }

        let isRevokedAccess = (statusCode == 409 && code == "publicationVisitorAccessUnavailable")
            || (statusCode == 403 && code == "publicationVisitorAccessDenied")
        guard isRevokedAccess else {
            return (.sessionUnavailable, error)
        }
        return (.accessRevoked, PublicationVisitorAccessError.accessRevoked)
    }
}
