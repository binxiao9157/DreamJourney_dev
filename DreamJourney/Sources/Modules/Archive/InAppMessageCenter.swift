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
            invitationStatus: source.familyInvitationStatus,
            accessStatus: source.familyAccessStatus,
            recipientRole: "familyInvitation",
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
            familyMemberId: nil,
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
