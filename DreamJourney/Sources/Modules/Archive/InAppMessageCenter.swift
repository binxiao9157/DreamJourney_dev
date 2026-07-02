import Foundation

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
        guard source.isFamilyInvitationVisibleInMessageCenter else {
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
            ownerUserId: nil,
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
        guard source.isCareSignalVisibleInMessageCenter else {
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
            ownerUserId: source.careSignalOwnerUserId,
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
        guard source.isSystemNoticeVisibleInMessageCenter else {
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
            ownerUserId: nil,
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
        guard source.isEchoReplyVisibleInMessageCenter else {
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

struct StaticSystemNoticeMessageSource: SystemNoticeMessageSource, Codable {
    let systemNoticeId: String
    let systemNoticeTitle: String
    let systemNoticeSummary: String
    let systemNoticeStatus: String
    let systemNoticeCategory: String
    let systemNoticeSeverity: String
    let systemNoticeUpdatedAt: String
}

struct StaticEchoReplyMessageSource: EchoReplyMessageSource, Codable {
    let echoReplyId: String
    let echoReplyTitle: String
    let echoReplySummary: String
    let echoReplyStatus: String
    let echoReplyDeliveredAt: String
    let echoReplyTrigger: String
}

final class SystemNoticeMessageStore {
    static let shared = SystemNoticeMessageStore()

    private let storageKey = "dj.inAppMessage.systemNotice.sources"

    private init() {}

    func sources() -> [SystemNoticeMessageSource] {
        guard let data = UserDefaults.standard.data(forKey: storageKey),
              let notices = try? JSONDecoder().decode([StaticSystemNoticeMessageSource].self, from: data) else {
            return []
        }
        return notices
    }

    func save(_ notices: [StaticSystemNoticeMessageSource]) {
        guard let data = try? JSONEncoder().encode(notices) else {
            return
        }
        UserDefaults.standard.set(data, forKey: storageKey)
    }

    func clear() {
        UserDefaults.standard.removeObject(forKey: storageKey)
    }
}

final class EchoReplyMessageStore {
    static let shared = EchoReplyMessageStore()

    private let storageKey = "dj.inAppMessage.echoReply.sources"
    private let isoFormatter = ISO8601DateFormatter()

    private init() {}

    func sources() -> [EchoReplyMessageSource] {
        guard let data = UserDefaults.standard.data(forKey: storageKey),
              let replies = try? JSONDecoder().decode([StaticEchoReplyMessageSource].self, from: data) else {
            return []
        }
        return replies
    }

    func save(_ replies: [StaticEchoReplyMessageSource]) {
        guard let data = try? JSONEncoder().encode(replies) else {
            return
        }
        UserDefaults.standard.set(data, forKey: storageKey)
    }

    func saveArrivedReply(id: String, deliverAt: Date, trigger: String) {
        let source = StaticEchoReplyMessageSource(
            echoReplyId: id,
            echoReplyTitle: "回响回信已抵达",
            echoReplySummary: "之前等待的回响已经准备好，可以继续对话。",
            echoReplyStatus: "unread",
            echoReplyDeliveredAt: isoFormatter.string(from: deliverAt),
            echoReplyTrigger: trigger
        )
        var current = sources().compactMap { $0 as? StaticEchoReplyMessageSource }
        current.removeAll { $0.echoReplyId == source.echoReplyId }
        current.insert(source, at: 0)
        save(Array(current.prefix(20)))
    }

    func clear() {
        UserDefaults.standard.removeObject(forKey: storageKey)
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
