import Foundation

/// Compile-time and launch-time boundary for the internal M2 publication
/// management surface. This capability is never enabled in a release build.
enum PublicationManagementM2QAGate {
    static let launchArgument = "DJEnablePublicationManagementM2QA"

    static var isEnabled: Bool {
        #if DEBUG || UI_QA_SIMULATOR
        QALaunchConfiguration.shared.contains(launchArgument)
        #else
        false
        #endif
    }
}

/// A narrower gate for the destructive lifecycle command. It composes the
/// owner-management and visitor-access QA boundaries so this command cannot
/// appear in an ordinary debug session by accident.
enum PublicationLifecycleM2QAGate {
    static let launchArgument = "DJEnablePublicationLifecycleM2QA"

    static var isEnabled: Bool {
        #if DEBUG || UI_QA_SIMULATOR
        QALaunchConfiguration.shared.contains(launchArgument)
            && PublicationManagementM2QAGate.isEnabled
            && PublicationVisitorM2QAGate.isEnabled
        #else
        false
        #endif
    }
}

enum PublicationManagementM2AccessGate {
    static var isPublicationRouteAllowed: Bool {
        PublicationManagementM2QAGate.isEnabled
            || FeatureGateService.shared.isServerPolicyManagedRouteAllowed(
                .publicationManagementM2
            )
    }

    static var isManagementRouteAllowed: Bool {
        if PublicationManagementM2QAGate.isEnabled {
            return true
        }
        return FeatureGateService.shared.isServerPolicyManagedRouteAllowed(
            .publicationManagementM2
        ) && FeatureGateService.shared.isServerPolicyManagedRouteAllowed(
            .publicationGrantManagementM2
        )
    }

    static var isLifecycleRouteAllowed: Bool {
        PublicationLifecycleM2QAGate.isEnabled
            || FeatureGateService.shared.isServerPolicyManagedRouteAllowed(
                .publicationManagementM2
            )
    }
}

enum PublicationManagementAccessError: LocalizedError, Equatable {
    case disabled
    case accountLeaseInvalid
    case malformedResponse
    case responseScopeMismatch
    case unavailable

    var errorDescription: String? {
        switch self {
        case .disabled:
            return "发布管理当前未启用"
        case .accountLeaseInvalid:
            return "当前账户状态已变更"
        case .malformedResponse:
            return "发布管理响应无效"
        case .responseScopeMismatch:
            return "发布管理范围与当前账户不一致"
        case .unavailable:
            return "发布管理暂时不可用"
        }
    }
}

struct PublicationManagementPublication: Equatable {
    let publicationID: String
    let publicationVersionID: String?
    let publicationState: String
    let projectionState: String?
    let lifecycleAuthorityEpoch: Int?
    let previewTitle: String
    let previewBody: String
    let requiresSecondConfirmation: Bool
    let thirdPartyReviewRequired: Bool
    let aiDisclosureRequired: Bool

    init?(json: [String: Any]) {
        guard let publicationID = Self.identifier(json["publicationId"] as? String),
              let publicationState = Self.state(json["publicationState"] as? String),
              let preview = json["preview"] as? [String: Any],
              let previewTitle = Self.text(preview["title"] as? String, maximumLength: 120),
              let previewBody = Self.text(preview["body"] as? String, maximumLength: 12_000),
              let requiresSecondConfirmation = json["requiresSecondConfirmation"] as? Bool,
              let thirdPartyReviewRequired = json["thirdPartyReviewRequired"] as? Bool,
              let aiDisclosureRequired = json["aiDisclosureRequired"] as? Bool else {
            return nil
        }

        let publicationVersionID = Self.optionalIdentifier(json["publicationVersionId"] as? String)
        let projectionState = Self.optionalState(json["projectionState"] as? String)
        let lifecycleAuthorityEpoch = Self.nonnegativeInt(json["lifecycleAuthorityEpoch"])
        self.publicationID = publicationID
        self.publicationVersionID = publicationVersionID
        self.publicationState = publicationState
        self.projectionState = projectionState
        self.lifecycleAuthorityEpoch = lifecycleAuthorityEpoch
        self.previewTitle = previewTitle
        self.previewBody = previewBody
        self.requiresSecondConfirmation = requiresSecondConfirmation
        self.thirdPartyReviewRequired = thirdPartyReviewRequired
        self.aiDisclosureRequired = aiDisclosureRequired
    }

    private static func identifier(_ value: String?) -> String? {
        let normalized = value?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return normalized.isEmpty ? nil : normalized
    }

    private static func optionalIdentifier(_ value: String?) -> String? {
        let normalized = value?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return normalized.isEmpty ? nil : normalized
    }

    private static func state(_ value: String?) -> String? {
        guard let value = optionalIdentifier(value), value.count <= 64 else { return nil }
        return value
    }

    private static func optionalState(_ value: String?) -> String? {
        guard let value = optionalIdentifier(value) else { return nil }
        return value.count <= 64 ? value : nil
    }

    private static func text(_ value: String?, maximumLength: Int) -> String? {
        let normalized = value?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        guard !normalized.isEmpty, normalized.count <= maximumLength else { return nil }
        return normalized
    }

    private static func nonnegativeInt(_ value: Any?) -> Int? {
        guard let value = value as? Int, value >= 0 else { return nil }
        return value
    }

    var isWithdrawable: Bool {
        publicationState == "confirmed"
            && projectionState == "active"
            && lifecycleAuthorityEpoch != nil
    }
}

enum PublicationWithdrawalPresentationPolicy {
    static func isAvailable(
        for publication: PublicationManagementPublication,
        routeAllowed: Bool
    ) -> Bool {
        routeAllowed && publication.isWithdrawable
    }
}

struct PublicationManagementGrant: Equatable {
    let grantID: String
    let publicationID: String
    let publicationVersionID: String
    let state: String
    let expiresAt: Date
    let useRemaining: Int

    init?(json: [String: Any]) {
        guard let grantID = Self.identifier(json["grantId"] as? String),
              let publicationID = Self.identifier(json["publicationId"] as? String),
              let publicationVersionID = Self.identifier(json["publicationVersionId"] as? String),
              let state = Self.state(json["state"] as? String),
              let expiresAt = Self.date(json["expiresAt"] as? String),
              let useRemaining = json["useRemaining"] as? Int,
              useRemaining >= 0 else {
            return nil
        }

        self.grantID = grantID
        self.publicationID = publicationID
        self.publicationVersionID = publicationVersionID
        self.state = state
        self.expiresAt = expiresAt
        self.useRemaining = useRemaining
    }

    var isUsable: Bool {
        state == "active" && useRemaining > 0 && expiresAt > Date()
    }

    private static func identifier(_ value: String?) -> String? {
        let normalized = value?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return normalized.isEmpty ? nil : normalized
    }

    private static func state(_ value: String?) -> String? {
        guard let value = identifier(value), value.count <= 64 else { return nil }
        return value
    }

    private static func date(_ value: String?) -> Date? {
        let normalized = value?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        guard !normalized.isEmpty else { return nil }
        let formatters: [ISO8601DateFormatter] = [
            ISO8601DateFormatter(),
            ISO8601DateFormatter(),
        ]
        formatters[0].formatOptions = [.withInternetDateTime]
        formatters[1].formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatters.lazy.compactMap { $0.date(from: normalized) }.first
    }
}

struct PublicationManagementPublicationList: Equatable {
    static let schemaVersion = "publication-owner-management-v1"

    let vaultID: String
    let publications: [PublicationManagementPublication]

    init?(json: [String: Any]) {
        guard json["schemaVersion"] as? String == Self.schemaVersion,
              let vaultID = Self.identifier(json["vaultId"] as? String),
              let rawPublications = json["publications"] as? [[String: Any]] else {
            return nil
        }
        let publications = rawPublications.compactMap(PublicationManagementPublication.init(json:))
        guard publications.count == rawPublications.count else { return nil }
        self.vaultID = vaultID
        self.publications = publications
    }

    private static func identifier(_ value: String?) -> String? {
        let normalized = value?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return normalized.isEmpty ? nil : normalized
    }
}

struct PublicationManagementGrantList: Equatable {
    static let schemaVersion = "publication-owner-grant-list-v1"

    let vaultID: String
    let grants: [PublicationManagementGrant]

    init?(json: [String: Any]) {
        guard json["schemaVersion"] as? String == Self.schemaVersion,
              let vaultID = Self.identifier(json["vaultId"] as? String),
              let rawGrants = json["grants"] as? [[String: Any]] else {
            return nil
        }
        let grants = rawGrants.compactMap(PublicationManagementGrant.init(json:))
        guard grants.count == rawGrants.count else { return nil }
        self.vaultID = vaultID
        self.grants = grants
    }

    private static func identifier(_ value: String?) -> String? {
        let normalized = value?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return normalized.isEmpty ? nil : normalized
    }
}

/// The page-level data is intentionally value-minimized and transient. It is
/// never persisted, indexed, added to Echo context, or shared with a visitor.
struct PublicationManagementSnapshot: Equatable {
    let vaultID: String
    let publications: [PublicationManagementPublication]
    let grants: [PublicationManagementGrant]
}

enum PublicationDraftAccessError: LocalizedError, Equatable {
    case disabled
    case accountLeaseInvalid
    case invalidInput
    case malformedResponse
    case responseScopeMismatch
    case thirdPartyReviewRequired
    case unavailable

    var errorDescription: String? {
        switch self {
        case .disabled:
            return "记忆发布当前未启用"
        case .accountLeaseInvalid:
            return "当前账户状态已变更"
        case .invalidInput:
            return "请检查公开标题、正文和记忆顺序"
        case .malformedResponse:
            return "记忆发布响应无效"
        case .responseScopeMismatch:
            return "记忆发布范围与当前账户不一致"
        case .thirdPartyReviewRequired:
            return "所选记忆需要先完成隐私确认"
        case .unavailable:
            return "记忆发布暂时不可用"
        }
    }
}

struct PublicationDraftItemInput: Equatable {
    let memoryVersionID: String
    let publicTitle: String
    let publicBody: String

    init(memoryVersionID: String, publicTitle: String, publicBody: String) throws {
        guard let memoryVersionID = PublicationDraftContract.uuid(memoryVersionID),
              let publicTitle = PublicationDraftContract.text(publicTitle, maximumLength: 120),
              let publicBody = PublicationDraftContract.text(publicBody, maximumLength: 12_000) else {
            throw PublicationDraftAccessError.invalidInput
        }
        self.memoryVersionID = memoryVersionID
        self.publicTitle = publicTitle
        self.publicBody = publicBody
    }

    var requestPayload: [String: Any] {
        [
            "memoryVersionId": memoryVersionID,
            "publicTitle": publicTitle,
            "publicBody": publicBody,
        ]
    }
}

struct PublicationDraftCreateCommand: Equatable {
    static let maximumItemCount = 20

    let commandID: UUID
    let items: [PublicationDraftItemInput]

    init(commandID: UUID = UUID(), items: [PublicationDraftItemInput]) throws {
        let memoryVersionIDs = items.map(\.memoryVersionID)
        guard (1...Self.maximumItemCount).contains(items.count),
              Set(memoryVersionIDs).count == memoryVersionIDs.count else {
            throw PublicationDraftAccessError.invalidInput
        }
        self.commandID = commandID
        self.items = items
    }

    var requestPayload: [String: Any] {
        [
            "commandId": commandID.uuidString.lowercased(),
            "items": items.map(\.requestPayload),
        ]
    }
}

struct PublicationDraftReceiptItem: Equatable {
    let itemIndex: Int
    let memoryVersionID: String
    let itemSnapshotHash: String
    let previewTitle: String
    let previewBody: String
    let thirdPartyReviewRequired: Bool

    init?(json: [String: Any]) {
        guard let itemIndex = PublicationDraftContract.nonnegativeInt(json["itemIndex"]),
              let memoryVersionID = PublicationDraftContract.uuid(json["memoryVersionId"] as? String),
              let itemSnapshotHash = PublicationDraftContract.sha256(json["itemSnapshotHash"] as? String),
              let preview = json["preview"] as? [String: Any],
              let previewTitle = PublicationDraftContract.text(
                preview["title"] as? String,
                maximumLength: 120
              ),
              let previewBody = PublicationDraftContract.text(
                preview["body"] as? String,
                maximumLength: 12_000
              ),
              let thirdPartyReviewRequired = json["thirdPartyReviewRequired"] as? Bool else {
            return nil
        }
        self.itemIndex = itemIndex
        self.memoryVersionID = memoryVersionID
        self.itemSnapshotHash = itemSnapshotHash
        self.previewTitle = previewTitle
        self.previewBody = previewBody
        self.thirdPartyReviewRequired = thirdPartyReviewRequired
    }
}

struct PublicationDraftReceipt: Equatable {
    let schemaVersion: String
    let vaultID: String
    let publicationID: String
    let draftID: String
    let outcome: String
    let state: String
    let expectedDraftRevision: Int
    let expectedDraftSnapshotHash: String
    let items: [PublicationDraftReceiptItem]
    let requiresSecondConfirmation: Bool
    let thirdPartyReviewRequired: Bool
    let aiDisclosureRequired: Bool

    init?(json: [String: Any]) {
        guard let schemaVersion = json["schemaVersion"] as? String,
              ["publication-authority-v1", "publication-authority-v2"].contains(schemaVersion),
              let vaultID = PublicationDraftContract.identifier(json["vaultId"] as? String),
              let publicationID = PublicationDraftContract.uuid(json["publicationId"] as? String),
              let draftID = PublicationDraftContract.uuid(json["draftId"] as? String),
              let outcome = PublicationDraftContract.value(
                json["outcome"] as? String,
                allowed: ["created", "deduplicated"]
              ),
              json["state"] as? String == "draft",
              let expectedDraftRevision = PublicationDraftContract.positiveInt(
                json["expectedDraftRevision"]
              ),
              let expectedDraftSnapshotHash = PublicationDraftContract.sha256(
                json["expectedDraftSnapshotHash"] as? String
              ),
              let requiresSecondConfirmation = json["requiresSecondConfirmation"] as? Bool,
              requiresSecondConfirmation,
              let thirdPartyReviewRequired = json["thirdPartyReviewRequired"] as? Bool,
              let aiDisclosureRequired = json["aiDisclosureRequired"] as? Bool else {
            return nil
        }
        let parsedItems: [PublicationDraftReceiptItem]
        if schemaVersion == "publication-authority-v2" {
            guard let itemCount = PublicationDraftContract.positiveInt(json["itemCount"]),
                  let rawItems = json["items"] as? [[String: Any]] else {
                return nil
            }
            parsedItems = rawItems.compactMap(PublicationDraftReceiptItem.init(json:))
            guard parsedItems.count == rawItems.count,
                  parsedItems.count == itemCount,
                  parsedItems.map(\.itemIndex) == Array(0..<itemCount),
                  Set(parsedItems.map(\.memoryVersionID)).count == itemCount else {
                return nil
            }
        } else {
            parsedItems = []
        }
        self.schemaVersion = schemaVersion
        self.vaultID = vaultID
        self.publicationID = publicationID
        self.draftID = draftID
        self.outcome = outcome
        self.state = "draft"
        self.expectedDraftRevision = expectedDraftRevision
        self.expectedDraftSnapshotHash = expectedDraftSnapshotHash
        items = parsedItems
        self.requiresSecondConfirmation = requiresSecondConfirmation
        self.thirdPartyReviewRequired = thirdPartyReviewRequired
        self.aiDisclosureRequired = aiDisclosureRequired
    }
}

struct PublicationDraftConfirmCommand: Equatable {
    let commandID: UUID
    let expectedDraftRevision: Int
    let expectedDraftSnapshotHash: String

    init(
        commandID: UUID = UUID(),
        expectedDraftRevision: Int,
        expectedDraftSnapshotHash: String,
        secondConfirmation: Bool
    ) throws {
        guard secondConfirmation,
              expectedDraftRevision > 0,
              let expectedDraftSnapshotHash = PublicationDraftContract.sha256(
                expectedDraftSnapshotHash
              ) else {
            throw PublicationDraftAccessError.invalidInput
        }
        self.commandID = commandID
        self.expectedDraftRevision = expectedDraftRevision
        self.expectedDraftSnapshotHash = expectedDraftSnapshotHash
    }

    var requestPayload: [String: Any] {
        [
            "commandId": commandID.uuidString.lowercased(),
            "expectedDraftRevision": expectedDraftRevision,
            "expectedDraftSnapshotHash": expectedDraftSnapshotHash,
            "secondConfirmation": true,
        ]
    }
}

struct PublicationDraftConfirmReceipt: Equatable {
    let schemaVersion: String
    let vaultID: String
    let publicationID: String
    let draftID: String
    let publicationVersionID: String
    let publicationVersion: Int
    let outcome: String
    let publicationState: String
    let projectionState: String
    let publicProjectionHash: String
    let itemCount: Int
    let publicProjectionItemHashes: [String]
    let aiDisclosureRequired: Bool

    init?(json: [String: Any]) {
        guard let schemaVersion = json["schemaVersion"] as? String,
              ["publication-authority-v1", "publication-authority-v2"].contains(schemaVersion),
              let vaultID = PublicationDraftContract.identifier(json["vaultId"] as? String),
              let publicationID = PublicationDraftContract.uuid(json["publicationId"] as? String),
              let draftID = PublicationDraftContract.uuid(json["draftId"] as? String),
              let publicationVersionID = PublicationDraftContract.uuid(
                json["publicationVersionId"] as? String
              ),
              let publicationVersion = PublicationDraftContract.positiveInt(
                json["publicationVersion"]
              ),
              let outcome = PublicationDraftContract.value(
                json["outcome"] as? String,
                allowed: ["created", "deduplicated"]
              ),
              json["publicationState"] as? String == "confirmed",
              json["projectionState"] as? String == "active",
              let publicProjectionHash = PublicationDraftContract.sha256(
                json["publicProjectionHash"] as? String
              ),
              let aiDisclosureRequired = json["aiDisclosureRequired"] as? Bool else {
            return nil
        }
        let itemCount: Int
        let itemHashes: [String]
        if schemaVersion == "publication-authority-v2" {
            guard let parsedItemCount = PublicationDraftContract.positiveInt(json["itemCount"]),
                  let rawHashes = json["publicProjectionItemHashes"] as? [String] else {
                return nil
            }
            itemHashes = rawHashes.compactMap(PublicationDraftContract.sha256)
            guard itemHashes.count == rawHashes.count, itemHashes.count == parsedItemCount else {
                return nil
            }
            itemCount = parsedItemCount
        } else {
            itemCount = 1
            itemHashes = []
        }
        self.schemaVersion = schemaVersion
        self.vaultID = vaultID
        self.publicationID = publicationID
        self.draftID = draftID
        self.publicationVersionID = publicationVersionID
        self.publicationVersion = publicationVersion
        self.outcome = outcome
        publicationState = "confirmed"
        projectionState = "active"
        self.publicProjectionHash = publicProjectionHash
        self.itemCount = itemCount
        publicProjectionItemHashes = itemHashes
        self.aiDisclosureRequired = aiDisclosureRequired
    }
}

protocol PublicationDraftWriterClient: AnyObject {
    func createPublicationDraft(
        vaultID: String,
        command: PublicationDraftCreateCommand,
        accountLease: AccountLease,
        completion: @escaping (Result<PublicationDraftReceipt, Error>) -> Void
    )

    func confirmPublicationDraft(
        vaultID: String,
        publicationID: String,
        draftID: String,
        command: PublicationDraftConfirmCommand,
        accountLease: AccountLease,
        completion: @escaping (Result<PublicationDraftConfirmReceipt, Error>) -> Void
    )
}

final class PublicationDraftUseCase {
    private let client: PublicationDraftWriterClient
    private let accountLeaseRuntime: AccountLeaseRuntimePort
    private let isEnabled: () -> Bool

    init(
        client: PublicationDraftWriterClient,
        accountLeaseRuntime: AccountLeaseRuntimePort = AccountLeaseRuntime.shared,
        isEnabled: @escaping () -> Bool = {
            PublicationManagementM2AccessGate.isPublicationRouteAllowed
        }
    ) {
        self.client = client
        self.accountLeaseRuntime = accountLeaseRuntime
        self.isEnabled = isEnabled
    }

    func create(
        command: PublicationDraftCreateCommand,
        accountLease: AccountLease,
        completion: @escaping (Result<PublicationDraftReceipt, Error>) -> Void
    ) {
        guard isEnabled() else {
            completion(.failure(PublicationDraftAccessError.disabled))
            return
        }
        guard accountLeaseRuntime.validate(accountLease, at: .request).allowed else {
            completion(.failure(PublicationDraftAccessError.accountLeaseInvalid))
            return
        }
        client.createPublicationDraft(
            vaultID: accountLease.vaultId,
            command: command,
            accountLease: accountLease
        ) { [weak self] result in
            guard let self else { return }
            guard self.accountLeaseRuntime.validate(accountLease, at: .commit).allowed else {
                completion(.failure(PublicationDraftAccessError.accountLeaseInvalid))
                return
            }
            guard case let .success(receipt) = result else {
                completion(result)
                return
            }
            guard receipt.vaultID == accountLease.vaultId else {
                completion(.failure(PublicationDraftAccessError.responseScopeMismatch))
                return
            }
            completion(.success(receipt))
        }
    }

    func confirm(
        draft: PublicationDraftReceipt,
        command: PublicationDraftConfirmCommand,
        accountLease: AccountLease,
        completion: @escaping (Result<PublicationDraftConfirmReceipt, Error>) -> Void
    ) {
        guard isEnabled() else {
            completion(.failure(PublicationDraftAccessError.disabled))
            return
        }
        guard accountLeaseRuntime.validate(accountLease, at: .request).allowed,
              draft.vaultID == accountLease.vaultId else {
            completion(.failure(PublicationDraftAccessError.accountLeaseInvalid))
            return
        }
        guard !draft.thirdPartyReviewRequired else {
            completion(.failure(PublicationDraftAccessError.thirdPartyReviewRequired))
            return
        }
        guard command.expectedDraftRevision == draft.expectedDraftRevision,
              command.expectedDraftSnapshotHash == draft.expectedDraftSnapshotHash else {
            completion(.failure(PublicationDraftAccessError.invalidInput))
            return
        }
        client.confirmPublicationDraft(
            vaultID: accountLease.vaultId,
            publicationID: draft.publicationID,
            draftID: draft.draftID,
            command: command,
            accountLease: accountLease
        ) { [weak self] result in
            guard let self else { return }
            guard self.accountLeaseRuntime.validate(accountLease, at: .commit).allowed else {
                completion(.failure(PublicationDraftAccessError.accountLeaseInvalid))
                return
            }
            guard case let .success(receipt) = result else {
                completion(result)
                return
            }
            guard receipt.vaultID == accountLease.vaultId,
                  receipt.publicationID == draft.publicationID,
                  receipt.draftID == draft.draftID else {
                completion(.failure(PublicationDraftAccessError.responseScopeMismatch))
                return
            }
            completion(.success(receipt))
        }
    }
}

private enum PublicationDraftContract {
    static func identifier(_ value: String?) -> String? {
        let normalized = value?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return normalized.isEmpty ? nil : normalized
    }

    static func uuid(_ value: String?) -> String? {
        guard let value = identifier(value), let uuid = UUID(uuidString: value) else { return nil }
        return uuid.uuidString.lowercased()
    }

    static func text(_ value: String?, maximumLength: Int) -> String? {
        guard let value = identifier(value), value.count <= maximumLength else { return nil }
        return value
    }

    static func value(_ value: String?, allowed: Set<String>) -> String? {
        guard let value = identifier(value), allowed.contains(value) else { return nil }
        return value
    }

    static func nonnegativeInt(_ value: Any?) -> Int? {
        guard !(value is Bool), let value = value as? Int, value >= 0 else { return nil }
        return value
    }

    static func positiveInt(_ value: Any?) -> Int? {
        guard let value = nonnegativeInt(value), value > 0 else { return nil }
        return value
    }

    static func sha256(_ value: String?) -> String? {
        guard let value = identifier(value)?.lowercased(),
              value.count == 64,
              value.allSatisfy(\.isHexDigit) else {
            return nil
        }
        return value
    }
}

protocol PublicationManagementReaderClient {
    func fetchOwnerPublications(
        vaultID: String,
        accountLease: AccountLease,
        completion: @escaping (Result<PublicationManagementPublicationList, Error>) -> Void
    )

    func fetchOwnerGrants(
        vaultID: String,
        accountLease: AccountLease,
        completion: @escaping (Result<PublicationManagementGrantList, Error>) -> Void
    )
}

final class PublicationManagementReadUseCase {
    private let client: PublicationManagementReaderClient
    private let accountLeaseRuntime: AccountLeaseRuntimePort

    init(
        client: PublicationManagementReaderClient,
        accountLeaseRuntime: AccountLeaseRuntimePort = AccountLeaseRuntime.shared
    ) {
        self.client = client
        self.accountLeaseRuntime = accountLeaseRuntime
    }

    func load(
        accountLease: AccountLease,
        completion: @escaping (Result<PublicationManagementSnapshot, Error>) -> Void
    ) {
        guard accountLeaseRuntime.validate(accountLease, at: .request).allowed else {
            completion(.failure(PublicationManagementAccessError.accountLeaseInvalid))
            return
        }

        client.fetchOwnerPublications(
            vaultID: accountLease.vaultId,
            accountLease: accountLease
        ) { [weak self] publicationsResult in
            guard let self else { return }
            guard self.accountLeaseRuntime.validate(accountLease, at: .commit).allowed else {
                completion(.failure(PublicationManagementAccessError.accountLeaseInvalid))
                return
            }
            switch publicationsResult {
            case .failure(let error):
                completion(.failure(error))
            case .success(let publications):
                guard publications.vaultID == accountLease.vaultId else {
                    completion(.failure(PublicationManagementAccessError.responseScopeMismatch))
                    return
                }
                self.loadGrants(
                    publications: publications,
                    accountLease: accountLease,
                    completion: completion
                )
            }
        }
    }

    private func loadGrants(
        publications: PublicationManagementPublicationList,
        accountLease: AccountLease,
        completion: @escaping (Result<PublicationManagementSnapshot, Error>) -> Void
    ) {
        client.fetchOwnerGrants(
            vaultID: accountLease.vaultId,
            accountLease: accountLease
        ) { [weak self] grantsResult in
            guard let self else { return }
            guard self.accountLeaseRuntime.validate(accountLease, at: .commit).allowed else {
                completion(.failure(PublicationManagementAccessError.accountLeaseInvalid))
                return
            }
            switch grantsResult {
            case .failure(let error):
                completion(.failure(error))
            case .success(let grants):
                guard grants.vaultID == accountLease.vaultId,
                      grants.vaultID == publications.vaultID else {
                    completion(.failure(PublicationManagementAccessError.responseScopeMismatch))
                    return
                }
                completion(.success(PublicationManagementSnapshot(
                    vaultID: accountLease.vaultId,
                    publications: publications.publications,
                    grants: grants.grants
                )))
            }
        }
    }
}

enum PublicationLifecycleAction: String {
    case withdraw
    case suspend
}

enum PublicationLifecycleAccessError: LocalizedError, Equatable {
    case disabled
    case accountLeaseInvalid
    case authorityEpochUnavailable
    case invalidPublicationState
    case malformedResponse
    case responseScopeMismatch
    case unavailable

    var errorDescription: String? {
        switch self {
        case .disabled:
            return "发布撤回当前未启用"
        case .accountLeaseInvalid:
            return "当前账户状态已变更"
        case .authorityEpochUnavailable:
            return "发布状态已更新，请重新读取后再试"
        case .invalidPublicationState:
            return "当前发布状态不可撤回"
        case .malformedResponse:
            return "发布撤回响应无效"
        case .responseScopeMismatch:
            return "发布撤回响应与当前账户不一致"
        case .unavailable:
            return "发布撤回暂时不可用"
        }
    }
}

struct PublicationLifecycleCommand: Equatable {
    let commandID: UUID
    let expectedAuthorityEpoch: Int

    init?(commandID: UUID, expectedAuthorityEpoch: Int) {
        guard expectedAuthorityEpoch >= 0 else { return nil }
        self.commandID = commandID
        self.expectedAuthorityEpoch = expectedAuthorityEpoch
    }

    func requestPayload() -> [String: Any] {
        [
            "commandId": commandID.uuidString.lowercased(),
            "expectedAuthorityEpoch": expectedAuthorityEpoch,
        ]
    }
}

struct PublicationLifecycleReceipt: Equatable {
    static let schemaVersion = "publication-lifecycle-v1"

    let publicationID: String
    let publicationVersionID: String
    let outcome: String
    let publicationState: String
    let projectionState: String
    let conflictHold: Bool
    let revokedGrantCount: Int
    let revokedVisitorSessionCount: Int
    let receiptID: String
    let reasonCode: String
    let accessDenyState: String
    let publicIndexCleanupState: String
    let runtimeCleanupState: String

    init?(json: [String: Any]) {
        guard json["schemaVersion"] as? String == Self.schemaVersion,
              let publicationID = Self.uuid(json["publicationId"] as? String),
              let publicationVersionID = Self.uuid(json["publicationVersionId"] as? String),
              let outcome = Self.value(json["outcome"] as? String, allowed: ["withdrawn", "suspended", "deduplicated"]),
              let publicationState = Self.value(json["publicationState"] as? String, allowed: ["withdrawn", "suspended"]),
              let projectionState = Self.value(json["projectionState"] as? String, allowed: ["withdrawn", "suspended"]),
              let conflictHold = json["conflictHold"] as? Bool,
              let revokedGrantCount = json["revokedGrantCount"] as? Int,
              revokedGrantCount >= 0,
              let revokedVisitorSessionCount = json["revokedVisitorSessionCount"] as? Int,
              revokedVisitorSessionCount >= 0,
              let receipt = json["receipt"] as? [String: Any],
              let receiptID = Self.uuid(receipt["receiptId"] as? String),
              let reasonCode = Self.identifier(receipt["reasonCode"] as? String),
              let accessDenyState = Self.value(receipt["accessDenyState"] as? String, allowed: ["completed"]),
              let publicIndexCleanupState = Self.value(receipt["publicIndexCleanupState"] as? String, allowed: ["pending"]),
              let runtimeCleanupState = Self.value(receipt["runtimeCleanupState"] as? String, allowed: ["notApplicable"]),
              Self.isConsistent(
                outcome: outcome,
                publicationState: publicationState,
                projectionState: projectionState,
                conflictHold: conflictHold
              ) else {
            return nil
        }
        self.publicationID = publicationID
        self.publicationVersionID = publicationVersionID
        self.outcome = outcome
        self.publicationState = publicationState
        self.projectionState = projectionState
        self.conflictHold = conflictHold
        self.revokedGrantCount = revokedGrantCount
        self.revokedVisitorSessionCount = revokedVisitorSessionCount
        self.receiptID = receiptID
        self.reasonCode = reasonCode
        self.accessDenyState = accessDenyState
        self.publicIndexCleanupState = publicIndexCleanupState
        self.runtimeCleanupState = runtimeCleanupState
    }

    private static func uuid(_ value: String?) -> String? {
        guard let value = value?.trimmingCharacters(in: .whitespacesAndNewlines),
              let uuid = UUID(uuidString: value) else {
            return nil
        }
        return uuid.uuidString.lowercased()
    }

    private static func identifier(_ value: String?) -> String? {
        let normalized = value?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        guard !normalized.isEmpty, normalized.count <= 128 else { return nil }
        return normalized
    }

    private static func value(_ value: String?, allowed: Set<String>) -> String? {
        guard let value = value?.trimmingCharacters(in: .whitespacesAndNewlines),
              allowed.contains(value) else {
            return nil
        }
        return value
    }

    private static func isConsistent(
        outcome: String,
        publicationState: String,
        projectionState: String,
        conflictHold: Bool
    ) -> Bool {
        guard publicationState == projectionState else { return false }
        switch outcome {
        case "withdrawn":
            return publicationState == "withdrawn" && !conflictHold
        case "suspended":
            return publicationState == "suspended" && conflictHold
        case "deduplicated":
            return (publicationState == "withdrawn" && !conflictHold)
                || (publicationState == "suspended" && conflictHold)
        default:
            return false
        }
    }
}

protocol PublicationLifecycleClient {
    func executePublicationLifecycle(
        action: PublicationLifecycleAction,
        vaultID: String,
        publicationID: String,
        command: PublicationLifecycleCommand,
        accountLease: AccountLease,
        completion: @escaping (Result<PublicationLifecycleReceipt, Error>) -> Void
    )
}

/// Keeps a retryable lifecycle command in page memory only. The command ID is
/// reused after an ambiguous transport failure, but it is never persisted.
final class PublicationLifecycleUseCase {
    private let client: PublicationLifecycleClient
    private let accountLeaseRuntime: AccountLeaseRuntimePort
    private let isRouteAllowed: () -> Bool
    private var pendingCommandIDs: [String: UUID] = [:]

    init(
        client: PublicationLifecycleClient,
        accountLeaseRuntime: AccountLeaseRuntimePort = AccountLeaseRuntime.shared,
        isRouteAllowed: @escaping () -> Bool = {
            PublicationManagementM2AccessGate.isLifecycleRouteAllowed
        }
    ) {
        self.client = client
        self.accountLeaseRuntime = accountLeaseRuntime
        self.isRouteAllowed = isRouteAllowed
    }

    func withdraw(
        publication: PublicationManagementPublication,
        accountLease: AccountLease,
        completion: @escaping (Result<PublicationLifecycleReceipt, Error>) -> Void
    ) {
        guard isRouteAllowed() else {
            completion(.failure(PublicationLifecycleAccessError.disabled))
            return
        }
        guard accountLeaseRuntime.validate(accountLease, at: .request).allowed else {
            completion(.failure(PublicationLifecycleAccessError.accountLeaseInvalid))
            return
        }
        guard publication.publicationState == "confirmed", publication.projectionState == "active" else {
            completion(.failure(PublicationLifecycleAccessError.invalidPublicationState))
            return
        }
        guard let authorityEpoch = publication.lifecycleAuthorityEpoch,
              let command = PublicationLifecycleCommand(
                commandID: pendingCommandIDs[publication.publicationID] ?? UUID(),
                expectedAuthorityEpoch: authorityEpoch
              ) else {
            completion(.failure(PublicationLifecycleAccessError.authorityEpochUnavailable))
            return
        }
        pendingCommandIDs[publication.publicationID] = command.commandID

        client.executePublicationLifecycle(
            action: .withdraw,
            vaultID: accountLease.vaultId,
            publicationID: publication.publicationID,
            command: command,
            accountLease: accountLease
        ) { [weak self] result in
            guard let self else { return }
            guard self.accountLeaseRuntime.validate(accountLease, at: .commit).allowed else {
                completion(.failure(PublicationLifecycleAccessError.accountLeaseInvalid))
                return
            }
            switch result {
            case .success(let receipt):
                guard receipt.publicationID == publication.publicationID,
                      receipt.publicationState == "withdrawn",
                      receipt.projectionState == "withdrawn" else {
                    completion(.failure(PublicationLifecycleAccessError.responseScopeMismatch))
                    return
                }
                self.pendingCommandIDs.removeValue(forKey: publication.publicationID)
                completion(.success(receipt))
            case .failure(let error):
                completion(.failure(error))
            }
        }
    }
}
