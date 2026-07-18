import CryptoKit
import Foundation

enum InAppMessageSourceSurface: String, Codable {
    case systemNotice
    case echoReply
    case localState
    case timeLetterMailbox
}

struct InAppMessageOwnerScope: Codable, Equatable {
    static let storeSchemaVersion = 2

    let subjectId: String
    let vaultId: String
    let sessionId: String
    let generation: UInt64
    let generationId: UUID
    let authorityEpoch: String
    let resourceOwnerId: String
    let operationId: String

    init(
        accountLease: AccountLease,
        resourceOwnerId: String,
        operationId: String
    ) {
        subjectId = Self.normalized(accountLease.subjectId)
        vaultId = Self.normalized(accountLease.vaultId)
        sessionId = Self.normalized(accountLease.sessionId)
        generation = accountLease.generation
        generationId = accountLease.generationId
        authorityEpoch = Self.normalized(accountLease.authorityEpoch)
        self.resourceOwnerId = Self.normalized(resourceOwnerId)
        self.operationId = Self.normalized(operationId)
    }

    var isValid: Bool {
        !subjectId.isEmpty
            && !vaultId.isEmpty
            && !sessionId.isEmpty
            && !authorityEpoch.isEmpty
            && !resourceOwnerId.isEmpty
            && !operationId.isEmpty
    }

    func storageKey(for surface: InAppMessageSourceSurface) -> String {
        "dj.inAppMessage.\(surface.rawValue).sources.v2.\(scopeDigest)"
    }

    fileprivate var scopeDigest: String {
        let components = [
            subjectId,
            vaultId,
            String(generation),
            generationId.uuidString.lowercased(),
            authorityEpoch,
            resourceOwnerId,
            operationId,
        ]
        let canonicalIdentity = components
            .map { "\($0.utf8.count):\($0)" }
            .joined(separator: "|")
        return Self.sha256(Data(canonicalIdentity.utf8))
    }

    private static func normalized(_ value: String) -> String {
        value.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private static func sha256(_ data: Data) -> String {
        let digest = SHA256.hash(data: data)
        return digest.map { String(format: "%02x", $0) }.joined()
    }
}

struct InAppMessageSourceEnvelope<Source: Codable>: Codable {
    let storeSchemaVersion: Int
    let subjectId: String
    let vaultId: String
    let sessionId: String
    let generation: UInt64
    let generationId: UUID
    let authorityEpoch: String
    let resourceOwnerId: String
    let operationId: String
    let sources: [Source]

    init(sources: [Source], scope: InAppMessageOwnerScope) {
        storeSchemaVersion = InAppMessageOwnerScope.storeSchemaVersion
        subjectId = scope.subjectId
        vaultId = scope.vaultId
        sessionId = scope.sessionId
        generation = scope.generation
        generationId = scope.generationId
        authorityEpoch = scope.authorityEpoch
        resourceOwnerId = scope.resourceOwnerId
        operationId = scope.operationId
        self.sources = sources
    }

    func matches(_ scope: InAppMessageOwnerScope) -> Bool {
        storeSchemaVersion == InAppMessageOwnerScope.storeSchemaVersion
            && subjectId == scope.subjectId
            && vaultId == scope.vaultId
            && generation == scope.generation
            && generationId == scope.generationId
            && authorityEpoch == scope.authorityEpoch
            && resourceOwnerId == scope.resourceOwnerId
            && operationId == scope.operationId
    }
}

private struct InAppMessageLifecycleEnvelopeHeader: Decodable {
    let storeSchemaVersion: Int
    let subjectId: String
    let vaultId: String
    let generation: UInt64
    let generationId: UUID
    let authorityEpoch: String

    func matchesLifecycleLease(_ accountLease: AccountLease) -> Bool {
        storeSchemaVersion == InAppMessageOwnerScope.storeSchemaVersion
            && subjectId == accountLease.subjectId
            && vaultId == accountLease.vaultId
            && generation == accountLease.generation
            && generationId == accountLease.generationId
            && authorityEpoch == accountLease.authorityEpoch
    }
}

private func teardownInAppMessageProjections(
    surfaces: [InAppMessageSourceSurface],
    oldAccountLease: AccountLease,
    defaults: UserDefaults
) -> Bool {
    var ownedKeys: [String] = []

    for surface in surfaces {
        let prefix = "dj.inAppMessage.\(surface.rawValue).sources.v2."
        let candidateKeys = defaults.dictionaryRepresentation().keys.filter {
            $0.hasPrefix(prefix)
        }
        for key in candidateKeys {
            guard let data = defaults.data(forKey: key),
                  let header = try? JSONDecoder().decode(
                      InAppMessageLifecycleEnvelopeHeader.self,
                      from: data
                  ) else {
                return false
            }
            if header.matchesLifecycleLease(oldAccountLease) {
                ownedKeys.append(key)
            }
        }
    }

    ownedKeys.forEach(defaults.removeObject(forKey:))
    return ownedKeys.allSatisfy { defaults.object(forKey: $0) == nil }
}

final class InAppMessageLifecycleProjectionStore {
    static let shared = InAppMessageLifecycleProjectionStore()

    private let defaults: UserDefaults
    private let lock = NSLock()

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    @discardableResult
    func teardownForAccountLifecycle(oldAccountLease: AccountLease?) -> Bool {
        guard let oldAccountLease else { return false }
        lock.lock()
        defer { lock.unlock() }
        return teardownInAppMessageProjections(
            surfaces: [.systemNotice, .echoReply, .localState, .timeLetterMailbox],
            oldAccountLease: oldAccountLease,
            defaults: defaults
        )
    }
}

enum InAppMessageLegacyRetirementStatus: String, Codable, Equatable {
    case notFound
    case pending
    case quarantined
    case failed
}

struct InAppMessageLegacyRetirementReceipt: Codable, Equatable {
    let receiptSchemaVersion: Int
    let surfaceId: String
    let sourceStorageKey: String
    let quarantineStorageKey: String
    let status: InAppMessageLegacyRetirementStatus
    let ownerEvidence: String
    let sourceContentHash: String
    let sourceItemCount: Int?
    let retiredAt: Date
}

struct InAppMessageLegacyQuarantineRecord: Codable, Equatable {
    let recordSchemaVersion: Int
    let surfaceId: String
    let sourceStorageKey: String
    let ownerEvidence: String
    let sourceContentHash: String
    let payload: Data
    let quarantinedAt: Date
}

enum InAppMessageLegacyRetirementStorage {
    private static let schemaVersion = 1

    static func retireIfNeeded(
        surface: InAppMessageSourceSurface,
        legacyStorageKey: String,
        sourceItemCount: Int?,
        defaults: UserDefaults,
        namespace: String? = nil
    ) -> Bool {
        guard let payload = defaults.data(forKey: legacyStorageKey) else {
            return true
        }

        let contentHash = sha256(payload)
        let quarantineKey = quarantineStorageKey(for: surface, namespace: namespace)
        let receiptKey = receiptStorageKey(for: surface, namespace: namespace)
        let record: InAppMessageLegacyQuarantineRecord

        if let existingData = defaults.data(forKey: quarantineKey) {
            guard let existing = try? JSONDecoder().decode(
                InAppMessageLegacyQuarantineRecord.self,
                from: existingData
            ), existing.surfaceId == surface.rawValue,
               existing.sourceStorageKey == legacyStorageKey,
               existing.ownerEvidence == "unverified",
               existing.sourceContentHash == contentHash,
               existing.payload == payload else {
                return false
            }
            record = existing
        } else {
            record = InAppMessageLegacyQuarantineRecord(
                recordSchemaVersion: schemaVersion,
                surfaceId: surface.rawValue,
                sourceStorageKey: legacyStorageKey,
                ownerEvidence: "unverified",
                sourceContentHash: contentHash,
                payload: payload,
                quarantinedAt: Date()
            )
            guard let recordData = try? JSONEncoder().encode(record) else { return false }
            defaults.set(recordData, forKey: quarantineKey)
            guard defaults.data(forKey: quarantineKey) == recordData else { return false }
        }

        if let existingData = defaults.data(forKey: receiptKey) {
            guard let existing = try? JSONDecoder().decode(
                InAppMessageLegacyRetirementReceipt.self,
                from: existingData
            ), existing.receiptSchemaVersion == schemaVersion,
               existing.surfaceId == surface.rawValue,
               existing.sourceStorageKey == legacyStorageKey,
               existing.quarantineStorageKey == quarantineKey,
               existing.status == .quarantined,
               existing.ownerEvidence == "unverified",
               existing.sourceContentHash == contentHash else {
                return false
            }
        } else {
            let receipt = InAppMessageLegacyRetirementReceipt(
                receiptSchemaVersion: schemaVersion,
                surfaceId: surface.rawValue,
                sourceStorageKey: legacyStorageKey,
                quarantineStorageKey: quarantineKey,
                status: .quarantined,
                ownerEvidence: "unverified",
                sourceContentHash: contentHash,
                sourceItemCount: sourceItemCount,
                retiredAt: record.quarantinedAt
            )
            guard let receiptData = try? JSONEncoder().encode(receipt) else { return false }
            defaults.set(receiptData, forKey: receiptKey)
            guard defaults.data(forKey: receiptKey) == receiptData else { return false }
        }

        defaults.removeObject(forKey: legacyStorageKey)
        return defaults.data(forKey: legacyStorageKey) == nil
    }

    static func status(
        surface: InAppMessageSourceSurface,
        legacyStorageKey: String,
        defaults: UserDefaults,
        namespace: String? = nil
    ) -> InAppMessageLegacyRetirementStatus {
        if let receipt = receipt(surface: surface, defaults: defaults, namespace: namespace) {
            return receipt.status
        }
        return defaults.data(forKey: legacyStorageKey) == nil ? .notFound : .pending
    }

    static func receipt(
        surface: InAppMessageSourceSurface,
        defaults: UserDefaults,
        namespace: String? = nil
    ) -> InAppMessageLegacyRetirementReceipt? {
        guard let data = defaults.data(forKey: receiptStorageKey(for: surface, namespace: namespace)),
              let receipt = try? JSONDecoder().decode(
                  InAppMessageLegacyRetirementReceipt.self,
                  from: data
              ), receipt.receiptSchemaVersion == schemaVersion,
              receipt.surfaceId == surface.rawValue,
              receipt.status == .quarantined,
              receipt.ownerEvidence == "unverified" else {
            return nil
        }
        return receipt
    }

    static func quarantinePayload(
        surface: InAppMessageSourceSurface,
        defaults: UserDefaults,
        namespace: String? = nil
    ) -> Data? {
        guard let data = defaults.data(forKey: quarantineStorageKey(for: surface, namespace: namespace)),
              let record = try? JSONDecoder().decode(
                  InAppMessageLegacyQuarantineRecord.self,
                  from: data
              ), record.recordSchemaVersion == schemaVersion,
              record.surfaceId == surface.rawValue,
              record.ownerEvidence == "unverified",
              record.sourceContentHash == sha256(record.payload) else {
            return nil
        }
        return record.payload
    }

    private static func quarantineStorageKey(
        for surface: InAppMessageSourceSurface,
        namespace: String?
    ) -> String {
        "dj.inAppMessage.legacyQuarantine.v1.\(surface.rawValue)\(namespaceSuffix(namespace))"
    }

    private static func receiptStorageKey(
        for surface: InAppMessageSourceSurface,
        namespace: String?
    ) -> String {
        "dj.inAppMessage.legacyRetirementReceipt.v1.\(surface.rawValue)\(namespaceSuffix(namespace))"
    }

    private static func namespaceSuffix(_ namespace: String?) -> String {
        guard let normalized = namespace?.trimmingCharacters(in: .whitespacesAndNewlines),
              !normalized.isEmpty else {
            return ""
        }
        return ".\(normalized)"
    }

    private static func sha256(_ data: Data) -> String {
        let digest = SHA256.hash(data: data)
        return "sha256:" + digest.map { String(format: "%02x", $0) }.joined()
    }
}

protocol InAppMessageResourceOwnerSource {
    var inAppMessageResourceOwnerId: String? { get }
}

private func authenticatedResourceOwnerId(_ source: Any) -> String? {
    guard let ownerSource = source as? InAppMessageResourceOwnerSource,
          let value = ownerSource.inAppMessageResourceOwnerId?.trimmingCharacters(
              in: .whitespacesAndNewlines
          ), !value.isEmpty else {
        return nil
    }
    return value
}

enum InAppMessageKind: String, Codable, CaseIterable {
    case timeLetter
    case familyInvitation
    case careSignal
    case systemNotice
    case echoReply

    var displayTitle: String {
        switch self {
        case .timeLetter:
            return "时间信件"
        case .familyInvitation:
            return "家庭邀请"
        case .careSignal:
            return "关怀提醒"
        case .systemNotice:
            return "系统通知"
        case .echoReply:
            return "回响回信"
        }
    }
}

protocol FamilyInvitationMessageSource {
    var familyMemberId: String { get }
    var familyMemberName: String { get }
    var familyMemberRelation: String { get }
    var familyMemberPhone: String? { get }
    var familyInvitationStatus: String { get }
    var familyAccessStatus: String { get }
    var familyInvitationError: String? { get }
    var familyLastUpdated: String { get }
    var isAcceptedFamilyMember: Bool { get }
}

extension FamilyInvitationMessageSource {
    var isFamilyInvitationVisibleInMessageCenter: Bool {
        guard !isAcceptedFamilyMember else {
            return false
        }
        let invitation = familyInvitationStatus.lowercased()
        let access = familyAccessStatus.lowercased()
        return invitation == "pending"
            || invitation == "failed"
            || access == "pending"
            || access == "failed"
    }
}

struct OwnerAwareFamilyInvitationMessageSource<Source: FamilyInvitationMessageSource>:
    FamilyInvitationMessageSource,
    InAppMessageResourceOwnerSource
{
    private let source: Source
    private let resourceOwnerId: String

    init(_ source: Source, resourceOwnerId: String) {
        self.source = source
        self.resourceOwnerId = resourceOwnerId
    }

    var familyMemberId: String { source.familyMemberId }
    var familyMemberName: String { source.familyMemberName }
    var familyMemberRelation: String { source.familyMemberRelation }
    var familyMemberPhone: String? { source.familyMemberPhone }
    var familyInvitationStatus: String { source.familyInvitationStatus }
    var familyAccessStatus: String { source.familyAccessStatus }
    var familyInvitationError: String? { source.familyInvitationError }
    var familyLastUpdated: String { source.familyLastUpdated }
    var isAcceptedFamilyMember: Bool { source.isAcceptedFamilyMember }
    var inAppMessageResourceOwnerId: String? { resourceOwnerId }
}

extension FamilyMember: InAppMessageResourceOwnerSource {
    var inAppMessageResourceOwnerId: String? { relationshipOwnerUserId }
}

protocol CareSignalMessageSource {
    var careSignalId: String { get }
    var careSignalTitle: String { get }
    var careSignalSummary: String { get }
    var careSignalStatus: String { get }
    var careSignalSeverity: String { get }
    var careSignalUpdatedAt: String { get }
    var careSignalOwnerUserId: String? { get }
}

extension CareSignalMessageSource {
    var isCareSignalVisibleInMessageCenter: Bool {
        let status = normalizedCareSignalToken(careSignalStatus)
        let severity = normalizedCareSignalToken(careSignalSeverity)
        return [
            "failed",
            "error",
            "stale",
            "expired",
            "needsattention",
            "attention",
            "watch",
        ].contains(status) || [
            "failed",
            "stale",
            "needsattention",
            "attention",
            "watch",
        ].contains(severity)
    }

    private func normalizedCareSignalToken(_ value: String) -> String {
        value
            .replacingOccurrences(of: "_", with: "")
            .replacingOccurrences(of: "-", with: "")
            .replacingOccurrences(of: " ", with: "")
            .lowercased()
    }
}

protocol SystemNoticeMessageSource {
    var systemNoticeId: String { get }
    var systemNoticeTitle: String { get }
    var systemNoticeSummary: String { get }
    var systemNoticeStatus: String { get }
    var systemNoticeCategory: String { get }
    var systemNoticeSeverity: String { get }
    var systemNoticeUpdatedAt: String { get }
}

extension SystemNoticeMessageSource {
    var isSystemNoticeVisibleInMessageCenter: Bool {
        let status = systemNoticeStatus.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        return status == "published" || status == "active"
    }
}

protocol EchoReplyMessageSource {
    var echoReplyId: String { get }
    var echoReplyTitle: String { get }
    var echoReplySummary: String { get }
    var echoReplyStatus: String { get }
    var echoReplyDeliveredAt: String { get }
    var echoReplyTrigger: String { get }
}

extension EchoReplyMessageSource {
    var isEchoReplyVisibleInMessageCenter: Bool {
        let status = echoReplyStatus.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        return status == "arrived" || status == "delivered" || status == "unread"
    }
}

enum InAppMessageStatus: String, Codable {
    case unread
    case read
    case archived

    var isUnread: Bool {
        self == .unread
    }

    var isArchived: Bool {
        self == .archived
    }
}

struct InAppMessage: Codable, Equatable {
    let id: String
    let kind: InAppMessageKind
    let title: String
    let summary: String
    let status: InAppMessageStatus
    let deliveredAt: String
    let readAt: String?
    let archivedAt: String?
    let sourceArchiveItemId: String?
    let ownerUserId: String?
    let familyMemberId: String?
    let careSignalId: String?
    let careSignalStatus: String?
    let careSignalSeverity: String?
    let systemNoticeId: String?
    let systemNoticeCategory: String?
    let systemNoticeSeverity: String?
    let invitationStatus: String?
    let accessStatus: String?
    let recipientRole: String?
    let metadataOnly: Bool
    let contentRedacted: Bool
    let isActionable: Bool
    let unavailableReason: String?

    var isUnread: Bool {
        status.isUnread
    }

    var isArchived: Bool {
        status.isArchived
    }

    var kindLabel: String {
        kind.displayTitle
    }

    var sortKey: String {
        deliveredAt
    }

    func markingRead(readAt: String) -> InAppMessage {
        InAppMessage(
            id: id,
            kind: kind,
            title: title,
            summary: summary,
            status: .read,
            deliveredAt: deliveredAt,
            readAt: readAt,
            archivedAt: archivedAt,
            sourceArchiveItemId: sourceArchiveItemId,
            ownerUserId: ownerUserId,
            familyMemberId: familyMemberId,
            careSignalId: careSignalId,
            careSignalStatus: careSignalStatus,
            careSignalSeverity: careSignalSeverity,
            systemNoticeId: systemNoticeId,
            systemNoticeCategory: systemNoticeCategory,
            systemNoticeSeverity: systemNoticeSeverity,
            invitationStatus: invitationStatus,
            accessStatus: accessStatus,
            recipientRole: recipientRole,
            metadataOnly: metadataOnly,
            contentRedacted: contentRedacted,
            isActionable: isActionable,
            unavailableReason: unavailableReason
        )
    }

    func markingArchived(archivedAt: String) -> InAppMessage {
        InAppMessage(
            id: id,
            kind: kind,
            title: title,
            summary: summary,
            status: .archived,
            deliveredAt: deliveredAt,
            readAt: readAt,
            archivedAt: archivedAt,
            sourceArchiveItemId: sourceArchiveItemId,
            ownerUserId: ownerUserId,
            familyMemberId: familyMemberId,
            careSignalId: careSignalId,
            careSignalStatus: careSignalStatus,
            careSignalSeverity: careSignalSeverity,
            systemNoticeId: systemNoticeId,
            systemNoticeCategory: systemNoticeCategory,
            systemNoticeSeverity: systemNoticeSeverity,
            invitationStatus: invitationStatus,
            accessStatus: accessStatus,
            recipientRole: recipientRole,
            metadataOnly: metadataOnly,
            contentRedacted: contentRedacted,
            isActionable: isActionable,
            unavailableReason: unavailableReason
        )
    }

    static func fromTimeLetterReminder(_ timeLetterReminder: TimeLetterMailboxReminder) -> InAppMessage {
        InAppMessage(
            id: timeLetterReminder.id,
            kind: .timeLetter,
            title: timeLetterReminder.title,
            summary: timeLetterReminder.recipientRole == "owner" ? "写给自己的时间信件" : "来自家人的时间信件",
            status: InAppMessageStatus(rawValue: timeLetterReminder.status) ?? .unread,
            deliveredAt: timeLetterReminder.deliveredAt,
            readAt: timeLetterReminder.readAt,
            archivedAt: timeLetterReminder.archivedAt,
            sourceArchiveItemId: timeLetterReminder.sourceArchiveItemId,
            ownerUserId: timeLetterReminder.ownerUserId,
            familyMemberId: nil,
            careSignalId: nil,
            careSignalStatus: nil,
            careSignalSeverity: nil,
            systemNoticeId: nil,
            systemNoticeCategory: nil,
            systemNoticeSeverity: nil,
            invitationStatus: nil,
            accessStatus: nil,
            recipientRole: timeLetterReminder.recipientRole,
            metadataOnly: true,
            contentRedacted: true,
            isActionable: true,
            unavailableReason: nil
        )
    }

    static func fromFamilyInvitation(_ source: FamilyInvitationMessageSource) -> InAppMessage? {
        guard source.isFamilyInvitationVisibleInMessageCenter,
              let resourceOwnerId = authenticatedResourceOwnerId(source) else {
            return nil
        }

        let invitationStatus = source.familyInvitationStatus.lowercased()
        let accessStatus = source.familyAccessStatus.lowercased()
        let isFailed = invitationStatus == "failed" || accessStatus == "failed"
        let phoneSuffix = source.familyMemberPhone.map { String($0.suffix(4)) } ?? ""
        let phoneCopy = phoneSuffix.isEmpty ? "" : "尾号 \(phoneSuffix)"
        let relationCopy = source.familyMemberRelation.trimmingCharacters(in: .whitespacesAndNewlines)
        let statusCopy = isFailed ? (source.familyInvitationError ?? "邀请失败，可稍后重试") : "等待对方加入"
        let summary = [
            relationCopy.isEmpty ? "家人" : relationCopy,
            phoneCopy,
            statusCopy,
        ]
        .filter { !$0.isEmpty }
        .joined(separator: " · ")

        return InAppMessage(
            id: "family-invitation-\(source.familyMemberId)",
            kind: .familyInvitation,
            title: isFailed ? "\(source.familyMemberName) 邀请失败" : "已邀请 \(source.familyMemberName)",
            summary: summary,
            status: .unread,
            deliveredAt: source.familyLastUpdated,
            readAt: nil,
            archivedAt: nil,
            sourceArchiveItemId: nil,
            ownerUserId: resourceOwnerId,
            familyMemberId: source.familyMemberId,
            careSignalId: nil,
            careSignalStatus: nil,
            careSignalSeverity: nil,
            systemNoticeId: nil,
            systemNoticeCategory: nil,
            systemNoticeSeverity: nil,
            invitationStatus: source.familyInvitationStatus,
            accessStatus: source.familyAccessStatus,
            recipientRole: "familyInvitation",
            metadataOnly: true,
            contentRedacted: true,
            isActionable: true,
            unavailableReason: nil
        )
    }

    static func fromCareSignal(_ source: CareSignalMessageSource) -> InAppMessage? {
        guard source.isCareSignalVisibleInMessageCenter,
              let resourceOwnerId = source.careSignalOwnerUserId?.trimmingCharacters(
                  in: .whitespacesAndNewlines
              ), !resourceOwnerId.isEmpty else {
            return nil
        }

        return InAppMessage(
            id: "care-signal-\(source.careSignalId)",
            kind: .careSignal,
            title: source.careSignalTitle,
            summary: source.careSignalSummary,
            status: .unread,
            deliveredAt: source.careSignalUpdatedAt,
            readAt: nil,
            archivedAt: nil,
            sourceArchiveItemId: nil,
            ownerUserId: resourceOwnerId,
            familyMemberId: nil,
            careSignalId: source.careSignalId,
            careSignalStatus: source.careSignalStatus,
            careSignalSeverity: source.careSignalSeverity,
            systemNoticeId: nil,
            systemNoticeCategory: nil,
            systemNoticeSeverity: nil,
            invitationStatus: nil,
            accessStatus: nil,
            recipientRole: "careSignal",
            metadataOnly: true,
            contentRedacted: true,
            isActionable: true,
            unavailableReason: nil
        )
    }

    static func fromSystemNotice(_ source: SystemNoticeMessageSource) -> InAppMessage? {
        guard source.isSystemNoticeVisibleInMessageCenter,
              let resourceOwnerId = authenticatedResourceOwnerId(source) else {
            return nil
        }

        return InAppMessage(
            id: "system-notice-\(source.systemNoticeId)",
            kind: .systemNotice,
            title: source.systemNoticeTitle,
            summary: source.systemNoticeSummary,
            status: .unread,
            deliveredAt: source.systemNoticeUpdatedAt,
            readAt: nil,
            archivedAt: nil,
            sourceArchiveItemId: nil,
            ownerUserId: resourceOwnerId,
            familyMemberId: nil,
            careSignalId: nil,
            careSignalStatus: nil,
            careSignalSeverity: nil,
            systemNoticeId: source.systemNoticeId,
            systemNoticeCategory: source.systemNoticeCategory,
            systemNoticeSeverity: source.systemNoticeSeverity,
            invitationStatus: nil,
            accessStatus: nil,
            recipientRole: "systemNotice",
            metadataOnly: true,
            contentRedacted: false,
            isActionable: true,
            unavailableReason: nil
        )
    }

    static func fromEchoReply(_ source: EchoReplyMessageSource) -> InAppMessage? {
        guard source.isEchoReplyVisibleInMessageCenter,
              let resourceOwnerId = authenticatedResourceOwnerId(source) else {
            return nil
        }

        let status = InAppMessageStatus(rawValue: source.echoReplyStatus) ?? .unread
        return InAppMessage(
            id: "echo-reply-\(source.echoReplyId)",
            kind: .echoReply,
            title: source.echoReplyTitle,
            summary: source.echoReplySummary,
            status: status,
            deliveredAt: source.echoReplyDeliveredAt,
            readAt: nil,
            archivedAt: nil,
            sourceArchiveItemId: nil,
            ownerUserId: resourceOwnerId,
            familyMemberId: nil,
            careSignalId: nil,
            careSignalStatus: nil,
            careSignalSeverity: nil,
            systemNoticeId: nil,
            systemNoticeCategory: nil,
            systemNoticeSeverity: nil,
            invitationStatus: nil,
            accessStatus: nil,
            recipientRole: "echoReply:\(source.echoReplyTrigger)",
            metadataOnly: true,
            contentRedacted: false,
            isActionable: true,
            unavailableReason: nil
        )
    }

    static func unavailableCandidate(kind: InAppMessageKind, title: String, reason: String) -> InAppMessage {
        InAppMessage(
            id: "candidate-\(kind.rawValue)",
            kind: kind,
            title: title,
            summary: reason,
            status: .read,
            deliveredAt: "",
            readAt: nil,
            archivedAt: nil,
            sourceArchiveItemId: nil,
            ownerUserId: nil,
            familyMemberId: nil,
            careSignalId: nil,
            careSignalStatus: nil,
            careSignalSeverity: nil,
            systemNoticeId: nil,
            systemNoticeCategory: nil,
            systemNoticeSeverity: nil,
            invitationStatus: nil,
            accessStatus: nil,
            recipientRole: nil,
            metadataOnly: true,
            contentRedacted: true,
            isActionable: false,
            unavailableReason: reason
        )
    }
}

struct StaticCareSignalMessageSource: CareSignalMessageSource, Codable {
    let careSignalId: String
    let careSignalTitle: String
    let careSignalSummary: String
    let careSignalStatus: String
    let careSignalSeverity: String
    let careSignalUpdatedAt: String
    let careSignalOwnerUserId: String?
}

struct StaticSystemNoticeMessageSource:
    SystemNoticeMessageSource,
    InAppMessageResourceOwnerSource,
    Codable
{
    let systemNoticeId: String
    let systemNoticeTitle: String
    let systemNoticeSummary: String
    let systemNoticeStatus: String
    let systemNoticeCategory: String
    let systemNoticeSeverity: String
    let systemNoticeUpdatedAt: String
    let resourceOwnerId: String?

    init(
        systemNoticeId: String,
        systemNoticeTitle: String,
        systemNoticeSummary: String,
        systemNoticeStatus: String,
        systemNoticeCategory: String,
        systemNoticeSeverity: String,
        systemNoticeUpdatedAt: String,
        resourceOwnerId: String? = nil
    ) {
        self.systemNoticeId = systemNoticeId
        self.systemNoticeTitle = systemNoticeTitle
        self.systemNoticeSummary = systemNoticeSummary
        self.systemNoticeStatus = systemNoticeStatus
        self.systemNoticeCategory = systemNoticeCategory
        self.systemNoticeSeverity = systemNoticeSeverity
        self.systemNoticeUpdatedAt = systemNoticeUpdatedAt
        self.resourceOwnerId = resourceOwnerId
    }

    var inAppMessageResourceOwnerId: String? { resourceOwnerId }
}

struct StaticEchoReplyMessageSource:
    EchoReplyMessageSource,
    InAppMessageResourceOwnerSource,
    Codable
{
    let echoReplyId: String
    let echoReplyTitle: String
    let echoReplySummary: String
    let echoReplyStatus: String
    let echoReplyDeliveredAt: String
    let echoReplyTrigger: String
    let resourceOwnerId: String?

    init(
        echoReplyId: String,
        echoReplyTitle: String,
        echoReplySummary: String,
        echoReplyStatus: String,
        echoReplyDeliveredAt: String,
        echoReplyTrigger: String,
        resourceOwnerId: String? = nil
    ) {
        self.echoReplyId = echoReplyId
        self.echoReplyTitle = echoReplyTitle
        self.echoReplySummary = echoReplySummary
        self.echoReplyStatus = echoReplyStatus
        self.echoReplyDeliveredAt = echoReplyDeliveredAt
        self.echoReplyTrigger = echoReplyTrigger
        self.resourceOwnerId = resourceOwnerId
    }

    var inAppMessageResourceOwnerId: String? { resourceOwnerId }
}

private struct ScopedSystemNoticeMessageSource:
    SystemNoticeMessageSource,
    InAppMessageResourceOwnerSource
{
    let source: StaticSystemNoticeMessageSource
    let resourceOwnerId: String

    var systemNoticeId: String { source.systemNoticeId }
    var systemNoticeTitle: String { source.systemNoticeTitle }
    var systemNoticeSummary: String { source.systemNoticeSummary }
    var systemNoticeStatus: String { source.systemNoticeStatus }
    var systemNoticeCategory: String { source.systemNoticeCategory }
    var systemNoticeSeverity: String { source.systemNoticeSeverity }
    var systemNoticeUpdatedAt: String { source.systemNoticeUpdatedAt }
    var inAppMessageResourceOwnerId: String? { resourceOwnerId }
}

private struct ScopedEchoReplyMessageSource:
    EchoReplyMessageSource,
    InAppMessageResourceOwnerSource
{
    let source: StaticEchoReplyMessageSource
    let resourceOwnerId: String

    var echoReplyId: String { source.echoReplyId }
    var echoReplyTitle: String { source.echoReplyTitle }
    var echoReplySummary: String { source.echoReplySummary }
    var echoReplyStatus: String { source.echoReplyStatus }
    var echoReplyDeliveredAt: String { source.echoReplyDeliveredAt }
    var echoReplyTrigger: String { source.echoReplyTrigger }
    var inAppMessageResourceOwnerId: String? { resourceOwnerId }
}

private func hasCompatibleDeclaredResourceOwner(_ source: Any, expectedOwnerId: String) -> Bool {
    guard let ownerSource = source as? InAppMessageResourceOwnerSource,
          let declaredOwnerId = ownerSource.inAppMessageResourceOwnerId else {
        return true
    }
    let normalizedOwnerId = declaredOwnerId.trimmingCharacters(in: .whitespacesAndNewlines)
    return !normalizedOwnerId.isEmpty && normalizedOwnerId == expectedOwnerId
}

final class SystemNoticeMessageStore {
    static let shared = SystemNoticeMessageStore()

    private static let legacyStorageKey = "dj.inAppMessage.systemNotice.sources"
    private static let compatibilityOperationId = "compatibility-current-inbox"

    private let defaults: UserDefaults
    private let accountLeaseRuntime: AccountLeaseRuntimePort
    private let lock = NSRecursiveLock()

    init(
        defaults: UserDefaults = .standard,
        accountLeaseRuntime: AccountLeaseRuntimePort = AccountLeaseRuntime.shared
    ) {
        self.defaults = defaults
        self.accountLeaseRuntime = accountLeaseRuntime
    }

    func sources(
        accountLease: AccountLease,
        resourceOwnerId: String,
        operationId: String
    ) -> [SystemNoticeMessageSource] {
        let scope = InAppMessageOwnerScope(
            accountLease: accountLease,
            resourceOwnerId: resourceOwnerId,
            operationId: operationId
        )
        guard scope.isValid,
              accountLeaseRuntime.validate(accountLease, at: .request).allowed else {
            return []
        }

        let notices: [StaticSystemNoticeMessageSource]? = withLock {
            guard retireLegacyGlobalPayloadIfNeeded() else { return nil }
            let storageKey = scope.storageKey(for: .systemNotice)
            guard let data = defaults.data(forKey: storageKey) else { return [] }
            guard let envelope = try? JSONDecoder().decode(
                InAppMessageSourceEnvelope<StaticSystemNoticeMessageSource>.self,
                from: data
            ), envelope.matches(scope),
               envelope.sources.allSatisfy({
                   hasCompatibleDeclaredResourceOwner($0, expectedOwnerId: scope.resourceOwnerId)
               }) else {
                return nil
            }
            return envelope.sources
        }
        guard let notices,
              accountLeaseRuntime.validate(accountLease, at: .runtime).allowed else {
            return []
        }
        return notices.map {
            ScopedSystemNoticeMessageSource(source: $0, resourceOwnerId: scope.resourceOwnerId)
        }
    }

    @discardableResult
    func save(
        _ notices: [StaticSystemNoticeMessageSource],
        accountLease: AccountLease,
        resourceOwnerId: String,
        operationId: String
    ) -> Bool {
        let scope = InAppMessageOwnerScope(
            accountLease: accountLease,
            resourceOwnerId: resourceOwnerId,
            operationId: operationId
        )
        guard scope.isValid,
              accountLeaseRuntime.validate(accountLease, at: .request).allowed,
              notices.allSatisfy({
                  hasCompatibleDeclaredResourceOwner($0, expectedOwnerId: scope.resourceOwnerId)
              }),
              let data = try? JSONEncoder().encode(
                  InAppMessageSourceEnvelope(sources: notices, scope: scope)
              ) else {
            return false
        }

        return withLock {
            guard retireLegacyGlobalPayloadIfNeeded(),
                  accountLeaseRuntime.validate(accountLease, at: .commit).allowed else {
                return false
            }
            let storageKey = scope.storageKey(for: .systemNotice)
            let previousData = defaults.data(forKey: storageKey)
            defaults.set(data, forKey: storageKey)
            guard defaults.data(forKey: storageKey) == data else { return false }
            guard accountLeaseRuntime.validate(accountLease, at: .commit).allowed else {
                if defaults.data(forKey: storageKey) == data {
                    if let previousData {
                        defaults.set(previousData, forKey: storageKey)
                    } else {
                        defaults.removeObject(forKey: storageKey)
                    }
                }
                return false
            }
            return true
        }
    }

    @discardableResult
    func clear(
        accountLease: AccountLease,
        resourceOwnerId: String,
        operationId: String
    ) -> Bool {
        let scope = InAppMessageOwnerScope(
            accountLease: accountLease,
            resourceOwnerId: resourceOwnerId,
            operationId: operationId
        )
        guard scope.isValid,
              accountLeaseRuntime.validate(accountLease, at: .request).allowed else {
            return false
        }

        return withLock {
            guard retireLegacyGlobalPayloadIfNeeded(),
                  accountLeaseRuntime.validate(accountLease, at: .commit).allowed else {
                return false
            }
            let storageKey = scope.storageKey(for: .systemNotice)
            let previousData = defaults.data(forKey: storageKey)
            defaults.removeObject(forKey: storageKey)
            guard defaults.data(forKey: storageKey) == nil else { return false }
            guard accountLeaseRuntime.validate(accountLease, at: .commit).allowed else {
                if defaults.data(forKey: storageKey) == nil, let previousData {
                    defaults.set(previousData, forKey: storageKey)
                }
                return false
            }
            return true
        }
    }

    @discardableResult
    func teardownForAccountLifecycle(oldAccountLease: AccountLease?) -> Bool {
        guard let oldAccountLease else { return false }
        return withLock {
            teardownInAppMessageProjections(
                surfaces: [.systemNotice],
                oldAccountLease: oldAccountLease,
                defaults: defaults
            )
        }
    }

    func legacyRetirementStatus() -> InAppMessageLegacyRetirementStatus {
        withLock {
            InAppMessageLegacyRetirementStorage.status(
                surface: .systemNotice,
                legacyStorageKey: Self.legacyStorageKey,
                defaults: defaults
            )
        }
    }

    func legacyRetirementReceipt() -> InAppMessageLegacyRetirementReceipt? {
        withLock {
            InAppMessageLegacyRetirementStorage.receipt(
                surface: .systemNotice,
                defaults: defaults
            )
        }
    }

    func legacyQuarantinePayload() -> Data? {
        withLock {
            InAppMessageLegacyRetirementStorage.quarantinePayload(
                surface: .systemNotice,
                defaults: defaults
            )
        }
    }

    func sources() -> [SystemNoticeMessageSource] {
        guard let accountLease = accountLeaseRuntime.capture(forSubjectId: nil) else { return [] }
        return sources(
            accountLease: accountLease,
            resourceOwnerId: accountLease.subjectId,
            operationId: Self.compatibilityOperationId
        )
    }

    @discardableResult
    func save(_ notices: [StaticSystemNoticeMessageSource]) -> Bool {
        guard let accountLease = accountLeaseRuntime.capture(forSubjectId: nil) else { return false }
        return save(
            notices,
            accountLease: accountLease,
            resourceOwnerId: accountLease.subjectId,
            operationId: Self.compatibilityOperationId
        )
    }

    @discardableResult
    func clear() -> Bool {
        guard let accountLease = accountLeaseRuntime.capture(forSubjectId: nil) else { return false }
        return clear(
            accountLease: accountLease,
            resourceOwnerId: accountLease.subjectId,
            operationId: Self.compatibilityOperationId
        )
    }

    private func retireLegacyGlobalPayloadIfNeeded() -> Bool {
        let sourceItemCount = defaults.data(forKey: Self.legacyStorageKey).flatMap {
            try? JSONDecoder().decode([StaticSystemNoticeMessageSource].self, from: $0).count
        }
        return InAppMessageLegacyRetirementStorage.retireIfNeeded(
            surface: .systemNotice,
            legacyStorageKey: Self.legacyStorageKey,
            sourceItemCount: sourceItemCount,
            defaults: defaults
        )
    }

    private func withLock<T>(_ body: () -> T) -> T {
        lock.lock()
        defer { lock.unlock() }
        return body()
    }
}

final class EchoReplyMessageStore {
    static let shared = EchoReplyMessageStore()

    private static let legacyStorageKey = "dj.inAppMessage.echoReply.sources"
    private static let inboxOperationId = "current-inbox"

    private let defaults: UserDefaults
    private let accountLeaseRuntime: AccountLeaseRuntimePort
    private let lock = NSRecursiveLock()
    private let isoFormatter = ISO8601DateFormatter()

    init(
        defaults: UserDefaults = .standard,
        accountLeaseRuntime: AccountLeaseRuntimePort = AccountLeaseRuntime.shared
    ) {
        self.defaults = defaults
        self.accountLeaseRuntime = accountLeaseRuntime
    }

    func sources(
        accountLease: AccountLease,
        resourceOwnerId: String,
        operationId: String
    ) -> [EchoReplyMessageSource] {
        let scope = InAppMessageOwnerScope(
            accountLease: accountLease,
            resourceOwnerId: resourceOwnerId,
            operationId: operationId
        )
        guard scope.isValid,
              accountLeaseRuntime.validate(accountLease, at: .request).allowed else {
            return []
        }

        let replies: [StaticEchoReplyMessageSource]? = withLock {
            guard retireLegacyGlobalPayloadIfNeeded() else { return nil }
            let storageKey = scope.storageKey(for: .echoReply)
            guard let data = defaults.data(forKey: storageKey) else { return [] }
            guard let envelope = try? JSONDecoder().decode(
                InAppMessageSourceEnvelope<StaticEchoReplyMessageSource>.self,
                from: data
            ), envelope.matches(scope),
               envelope.sources.allSatisfy({
                   hasCompatibleDeclaredResourceOwner($0, expectedOwnerId: scope.resourceOwnerId)
               }) else {
                return nil
            }
            return envelope.sources
        }
        guard let replies,
              accountLeaseRuntime.validate(accountLease, at: .runtime).allowed else {
            return []
        }
        return replies.map {
            ScopedEchoReplyMessageSource(source: $0, resourceOwnerId: scope.resourceOwnerId)
        }
    }

    func inboxSources(
        accountLease: AccountLease,
        resourceOwnerId: String
    ) -> [EchoReplyMessageSource] {
        sources(
            accountLease: accountLease,
            resourceOwnerId: resourceOwnerId,
            operationId: Self.inboxOperationId
        )
    }

    @discardableResult
    func save(
        _ replies: [StaticEchoReplyMessageSource],
        accountLease: AccountLease,
        resourceOwnerId: String,
        operationId: String
    ) -> Bool {
        let scope = InAppMessageOwnerScope(
            accountLease: accountLease,
            resourceOwnerId: resourceOwnerId,
            operationId: operationId
        )
        guard scope.isValid,
              accountLeaseRuntime.validate(accountLease, at: .request).allowed,
              replies.allSatisfy({
                  hasCompatibleDeclaredResourceOwner($0, expectedOwnerId: scope.resourceOwnerId)
              }),
              let data = try? JSONEncoder().encode(
                  InAppMessageSourceEnvelope(sources: replies, scope: scope)
              ) else {
            return false
        }

        return withLock {
            guard retireLegacyGlobalPayloadIfNeeded(),
                  accountLeaseRuntime.validate(accountLease, at: .commit).allowed else {
                return false
            }
            let storageKey = scope.storageKey(for: .echoReply)
            let previousData = defaults.data(forKey: storageKey)
            defaults.set(data, forKey: storageKey)
            guard defaults.data(forKey: storageKey) == data else { return false }
            guard accountLeaseRuntime.validate(accountLease, at: .commit).allowed else {
                if defaults.data(forKey: storageKey) == data {
                    if let previousData {
                        defaults.set(previousData, forKey: storageKey)
                    } else {
                        defaults.removeObject(forKey: storageKey)
                    }
                }
                return false
            }
            return true
        }
    }

    @discardableResult
    func clear(
        accountLease: AccountLease,
        resourceOwnerId: String,
        operationId: String
    ) -> Bool {
        let scope = InAppMessageOwnerScope(
            accountLease: accountLease,
            resourceOwnerId: resourceOwnerId,
            operationId: operationId
        )
        guard scope.isValid,
              accountLeaseRuntime.validate(accountLease, at: .request).allowed else {
            return false
        }

        return withLock {
            guard retireLegacyGlobalPayloadIfNeeded(),
                  accountLeaseRuntime.validate(accountLease, at: .commit).allowed else {
                return false
            }
            let storageKey = scope.storageKey(for: .echoReply)
            let previousData = defaults.data(forKey: storageKey)
            defaults.removeObject(forKey: storageKey)
            guard defaults.data(forKey: storageKey) == nil else { return false }
            guard accountLeaseRuntime.validate(accountLease, at: .commit).allowed else {
                if defaults.data(forKey: storageKey) == nil, let previousData {
                    defaults.set(previousData, forKey: storageKey)
                }
                return false
            }
            return true
        }
    }

    @discardableResult
    func teardownForAccountLifecycle(oldAccountLease: AccountLease?) -> Bool {
        guard let oldAccountLease else { return false }
        return withLock {
            teardownInAppMessageProjections(
                surfaces: [.echoReply],
                oldAccountLease: oldAccountLease,
                defaults: defaults
            )
        }
    }

    @discardableResult
    func saveArrivedReply(
        id: String,
        deliverAt: Date,
        trigger: String,
        accountLease: AccountLease,
        resourceOwnerId: String,
        operationId: String
    ) -> Bool {
        let normalizedId = id.trimmingCharacters(in: .whitespacesAndNewlines)
        let normalizedOperationId = operationId.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !normalizedId.isEmpty,
              normalizedId == normalizedOperationId else {
            return false
        }
        return withLock {
            let source = StaticEchoReplyMessageSource(
                echoReplyId: id,
                echoReplyTitle: "回响回信已抵达",
                echoReplySummary: "之前等待的回响已经准备好，可以继续对话。",
                echoReplyStatus: "unread",
                echoReplyDeliveredAt: isoFormatter.string(from: deliverAt),
                echoReplyTrigger: trigger,
                resourceOwnerId: resourceOwnerId
            )
            var current = inboxSources(
                accountLease: accountLease,
                resourceOwnerId: resourceOwnerId
            ).compactMap { candidate -> StaticEchoReplyMessageSource? in
                if let scoped = candidate as? ScopedEchoReplyMessageSource {
                    return scoped.source
                }
                return candidate as? StaticEchoReplyMessageSource
            }
            current.removeAll { $0.echoReplyId == source.echoReplyId }
            current.insert(source, at: 0)
            return save(
                Array(current.prefix(20)),
                accountLease: accountLease,
                resourceOwnerId: resourceOwnerId,
                operationId: Self.inboxOperationId
            )
        }
    }

    @discardableResult
    func removeArrivedReply(
        id: String,
        accountLease: AccountLease,
        resourceOwnerId: String,
        operationId: String
    ) -> Bool {
        let normalizedId = id.trimmingCharacters(in: .whitespacesAndNewlines)
        let normalizedOperationId = operationId.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !normalizedId.isEmpty,
              normalizedId == normalizedOperationId else {
            return false
        }
        return withLock {
            let current = inboxSources(
                accountLease: accountLease,
                resourceOwnerId: resourceOwnerId
            ).compactMap { source -> StaticEchoReplyMessageSource? in
                if let scoped = source as? ScopedEchoReplyMessageSource {
                    return scoped.source
                }
                return source as? StaticEchoReplyMessageSource
            }
            return save(
                current.filter { $0.echoReplyId != normalizedId },
                accountLease: accountLease,
                resourceOwnerId: resourceOwnerId,
                operationId: Self.inboxOperationId
            )
        }
    }

    func legacyRetirementStatus() -> InAppMessageLegacyRetirementStatus {
        withLock {
            InAppMessageLegacyRetirementStorage.status(
                surface: .echoReply,
                legacyStorageKey: Self.legacyStorageKey,
                defaults: defaults
            )
        }
    }

    func legacyRetirementReceipt() -> InAppMessageLegacyRetirementReceipt? {
        withLock {
            InAppMessageLegacyRetirementStorage.receipt(
                surface: .echoReply,
                defaults: defaults
            )
        }
    }

    func legacyQuarantinePayload() -> Data? {
        withLock {
            InAppMessageLegacyRetirementStorage.quarantinePayload(
                surface: .echoReply,
                defaults: defaults
            )
        }
    }

    func sources() -> [EchoReplyMessageSource] {
        guard let accountLease = accountLeaseRuntime.capture(forSubjectId: nil) else { return [] }
        return sources(
            accountLease: accountLease,
            resourceOwnerId: accountLease.subjectId,
            operationId: Self.inboxOperationId
        )
    }

    @discardableResult
    func save(_ replies: [StaticEchoReplyMessageSource]) -> Bool {
        guard let accountLease = accountLeaseRuntime.capture(forSubjectId: nil) else { return false }
        return save(
            replies,
            accountLease: accountLease,
            resourceOwnerId: accountLease.subjectId,
            operationId: Self.inboxOperationId
        )
    }

    @discardableResult
    func saveArrivedReply(id: String, deliverAt: Date, trigger: String) -> Bool {
        guard let accountLease = accountLeaseRuntime.capture(forSubjectId: nil) else { return false }
        return saveArrivedReply(
            id: id,
            deliverAt: deliverAt,
            trigger: trigger,
            accountLease: accountLease,
            resourceOwnerId: accountLease.subjectId,
            operationId: id
        )
    }

    @discardableResult
    func clear() -> Bool {
        guard let accountLease = accountLeaseRuntime.capture(forSubjectId: nil) else { return false }
        return clear(
            accountLease: accountLease,
            resourceOwnerId: accountLease.subjectId,
            operationId: Self.inboxOperationId
        )
    }

    private func retireLegacyGlobalPayloadIfNeeded() -> Bool {
        let sourceItemCount = defaults.data(forKey: Self.legacyStorageKey).flatMap {
            try? JSONDecoder().decode([StaticEchoReplyMessageSource].self, from: $0).count
        }
        return InAppMessageLegacyRetirementStorage.retireIfNeeded(
            surface: .echoReply,
            legacyStorageKey: Self.legacyStorageKey,
            sourceItemCount: sourceItemCount,
            defaults: defaults
        )
    }

    private func withLock<T>(_ body: () -> T) -> T {
        lock.lock()
        defer { lock.unlock() }
        return body()
    }
}

struct InAppMessageCenterSnapshot: Equatable {
    let messages: [InAppMessage]
    let hiddenCandidateMessages: [InAppMessage]

    var inboxMessages: [InAppMessage] {
        messages.filter { !$0.isArchived }
    }

    var archivedMessages: [InAppMessage] {
        messages.filter(\.isArchived)
    }

    var unreadCount: Int {
        inboxMessages.filter(\.isUnread).count
    }

    var archivedCount: Int {
        archivedMessages.count
    }

    var totalCount: Int {
        messages.count
    }

    var selectedContextSourceCounts: [String: Int] {
        sourceCounts
    }

    var sourceCounts: [String: Int] {
        var counts: [String: Int] = [:]
        messages.forEach { message in
            counts[message.kind.rawValue, default: 0] += 1
        }
        return counts
    }

    func entryButtonTitle(timeLetterReminderCount: Int) -> String? {
        if unreadCount > 0 {
            return "\(unreadCount) 条消息待处理 · 查看"
        }
        if timeLetterReminderCount > 0 {
            return "\(timeLetterReminderCount) 封时间信件已到打开时间 · 查看"
        }
        if archivedCount > 0 {
            return "消息中心 · \(archivedCount) 条已归档"
        }
        if totalCount > 0 {
            return "消息中心 · 查看历史"
        }
        return nil
    }

    static func sortedMessages(_ messages: [InAppMessage]) -> [InAppMessage] {
        messages.sorted { lhs, rhs in
            if lhs.isUnread != rhs.isUnread {
                return lhs.isUnread && !rhs.isUnread
            }
            if lhs.isArchived != rhs.isArchived {
                return !lhs.isArchived && rhs.isArchived
            }
            return lhs.sortKey > rhs.sortKey
        }
    }
}
