import Foundation

enum InAppMessageKind: String, Codable, CaseIterable {
    case timeLetter
    case familyInvitation
    case careSignal
    case systemNotice

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
        }
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
            recipientRole: timeLetterReminder.recipientRole,
            metadataOnly: true,
            contentRedacted: true,
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
            recipientRole: nil,
            metadataOnly: true,
            contentRedacted: true,
            isActionable: false,
            unavailableReason: reason
        )
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
