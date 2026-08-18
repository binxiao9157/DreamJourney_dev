import Foundation
import UserNotifications

struct MemoryArchiveContextEntry {
    let id: String
    let title: String
    let kindLabel: String
    let summary: String
    let note: String?
    let people: [String]
    let locations: [String]
    let scenes: [String]
    let tags: [String]
    let createdAt: Date
}

struct MemoryArchiveContextSnapshot {
    let totalItemCount: Int
    let availableItemCount: Int
    let entries: [MemoryArchiveContextEntry]

    var isEmpty: Bool {
        entries.isEmpty
    }

    var promptSection: String {
        guard !entries.isEmpty else { return "" }

        let lines = entries.map { entry -> String in
            var parts = ["- \(entry.title)（\(entry.kindLabel)）：\(entry.summary)"]
            if let note = entry.note, note != entry.summary {
                parts.append("  素材说明：\(note)")
            }
            if !entry.people.isEmpty {
                parts.append("  人物线索：\(entry.people.joined(separator: "、"))")
            }
            if !entry.locations.isEmpty {
                parts.append("  地点线索：\(entry.locations.joined(separator: "、"))")
            }
            if !entry.scenes.isEmpty {
                parts.append("  场景线索：\(entry.scenes.joined(separator: "、"))")
            }
            if !entry.tags.isEmpty {
                parts.append("  标签：\(entry.tags.joined(separator: "、"))")
            }
            return parts.joined(separator: "\n")
        }

        return "\n\n【记忆档案馆素材线索】\n" + lines.joined(separator: "\n")
    }

    #if DEBUG || UI_QA_SIMULATOR
    func debugSummary(limit: Int = 3) -> String {
        let limitedEntries = entries.prefix(max(0, limit))
        guard !limitedEntries.isEmpty else {
            return "none"
        }

        return limitedEntries
            .map { "\($0.title)（\($0.kindLabel)）" }
            .joined(separator: "，")
    }
    #endif
}

struct TimeLetterMailboxReminder: Codable, Equatable {
    let id: String
    let ownerUserId: String
    let sourceArchiveItemId: String
    let title: String
    let status: String
    let deliveredAt: String
    let readAt: String?
    let archivedAt: String?
    let recipientRole: String

    private enum CodingKeys: String, CodingKey {
        case id
        case ownerUserId
        case sourceArchiveItemId
        case title
        case status
        case deliveredAt
        case readAt
        case archivedAt
        case recipientRole
    }

    init(
        id: String,
        ownerUserId: String,
        sourceArchiveItemId: String,
        title: String,
        status: String,
        deliveredAt: String,
        readAt: String? = nil,
        archivedAt: String? = nil,
        recipientRole: String
    ) {
        self.id = id
        self.ownerUserId = ownerUserId
        self.sourceArchiveItemId = sourceArchiveItemId
        self.title = title
        self.status = status
        self.deliveredAt = deliveredAt
        self.readAt = readAt
        self.archivedAt = archivedAt
        self.recipientRole = recipientRole
    }

    init?(_ json: [String: Any]) {
        let kind = (json["kind"] as? String)?.trimmingCharacters(in: .whitespacesAndNewlines)
        let sourceArchiveItemId = (json["sourceArchiveItemId"] as? String)?
            .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        guard kind == "timeLetterReminder", !sourceArchiveItemId.isEmpty else {
            return nil
        }
        self.id = (json["id"] as? String)?.trimmingCharacters(in: .whitespacesAndNewlines)
            ?? "time-letter-reminder-\(sourceArchiveItemId)"
        self.ownerUserId = (json["ownerUserId"] as? String)?.trimmingCharacters(in: .whitespacesAndNewlines)
            ?? ""
        self.sourceArchiveItemId = sourceArchiveItemId
        self.title = (json["title"] as? String)?.trimmingCharacters(in: .whitespacesAndNewlines)
            ?? "时间信件已到打开时间"
        self.status = (json["status"] as? String)?.trimmingCharacters(in: .whitespacesAndNewlines)
            ?? "unread"
        self.deliveredAt = (json["deliveredAt"] as? String)?.trimmingCharacters(in: .whitespacesAndNewlines)
            ?? ""
        self.readAt = (json["readAt"] as? String)?.trimmingCharacters(in: .whitespacesAndNewlines)
        self.archivedAt = (json["archivedAt"] as? String)?.trimmingCharacters(in: .whitespacesAndNewlines)
        self.recipientRole = (json["recipientRole"] as? String)?.trimmingCharacters(in: .whitespacesAndNewlines)
            ?? "recipient"
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        ownerUserId = try container.decodeIfPresent(String.self, forKey: .ownerUserId) ?? ""
        sourceArchiveItemId = try container.decode(String.self, forKey: .sourceArchiveItemId)
        title = try container.decode(String.self, forKey: .title)
        status = try container.decode(String.self, forKey: .status)
        deliveredAt = try container.decode(String.self, forKey: .deliveredAt)
        readAt = try container.decodeIfPresent(String.self, forKey: .readAt)
        archivedAt = try container.decodeIfPresent(String.self, forKey: .archivedAt)
        recipientRole = try container.decode(String.self, forKey: .recipientRole)
    }

    var isUnread: Bool {
        status == "unread"
    }

    var isArchived: Bool {
        status == "archived"
    }

    func markingRead(readAt: String) -> TimeLetterMailboxReminder {
        TimeLetterMailboxReminder(
            id: id,
            ownerUserId: ownerUserId,
            sourceArchiveItemId: sourceArchiveItemId,
            title: title,
            status: "read",
            deliveredAt: deliveredAt,
            readAt: readAt,
            archivedAt: archivedAt,
            recipientRole: recipientRole
        )
    }

    func markingArchived(archivedAt: String) -> TimeLetterMailboxReminder {
        TimeLetterMailboxReminder(
            id: id,
            ownerUserId: ownerUserId,
            sourceArchiveItemId: sourceArchiveItemId,
            title: title,
            status: "archived",
            deliveredAt: deliveredAt,
            readAt: readAt,
            archivedAt: archivedAt,
            recipientRole: recipientRole
        )
    }
}

private struct ArchiveVisibilityContext {
    let ownerId: String
    let personaScope: String
    let digitalHumanId: String
}

private struct ArchiveStorageLease {
    let accountLease: AccountLease
    let accountUserId: String
    let archiveOwnerId: String
    let personaScope: String
    let digitalHumanId: String
    let storageScope: ArchiveStorageScope
    let storageKey: String
}

private struct InAppMessageLocalState: Codable {
    let messageId: String
    let status: InAppMessageStatus
    let readAt: String?
    let archivedAt: String?
}

final class MemoryArchiveRepository {
    static let shared = MemoryArchiveRepository()

    private let legacyMailboxBaseKey = "dj.memoryArchive.timeLetterMailbox"
    private let legacyInAppMessageStateBaseKey = "dj.inAppMessage.localState"
    private let timeLetterMailboxOperationId = "time-letter-mailbox"
    private let accountLeaseRuntime = AccountLeaseRuntime.shared
    private let localStorage = ArchiveLocalStorage.shared
    private let mediaStore = ArchiveMediaStore.shared
    private let isoFormatter = ISO8601DateFormatter()
    private let messageStateLock = NSRecursiveLock()
    private static let personalPersonaScope = "personal"
    private static let familyPersonaScope = "family"
    private static let defaultFamilyDigitalHumanId = "family_default"

    private init() {}

    func allItems() -> [MemoryArchiveItem] {
        guard let lease = currentArchiveStorageLease,
              isCurrentArchiveStorageLease(lease, at: .request) else {
            return []
        }
        return items(for: lease).sorted { $0.createdAt > $1.createdAt }
    }

    @discardableResult
    func add(
        _ item: MemoryArchiveItem,
        syncToBackend shouldSyncToBackend: Bool = true,
        backendSyncCompletion: ((Result<Void, Error>) -> Void)? = nil
    ) -> Bool {
        guard let lease = currentArchiveStorageLease,
              isCurrentArchiveStorageLease(lease, at: .request),
              item.ownerUserId.trimmingCharacters(in: .whitespacesAndNewlines) == lease.archiveOwnerId else {
            print("[Archive] rejected ownerless or mismatched local insert")
            return false
        }
        let ownedItem = item.enforcingLocalOnlyPhotoTransferState()
        let shouldAttemptBackendSync = shouldSyncToBackend
            && ownedItem.isPublicBackendSyncEligible
            && DreamJourneyBackendClient.shared.isArchiveSyncConfigured
        let itemForStorage = shouldAttemptBackendSync
            ? ownedItem.updatingBackendSyncState(.pending)
            : ownedItem
        var items = items(for: lease)
        items.insert(itemForStorage, at: 0)
        guard save(items, lease: lease) else {
            return false
        }
        scheduleTimeLetterReminderIfNeeded(itemForStorage)
        if shouldAttemptBackendSync {
            syncToBackend(
                itemForStorage,
                lease: lease,
                completion: backendSyncCompletion
            )
        } else {
            backendSyncCompletion?(.success(()))
        }
        return true
    }

    @discardableResult
    func update(
        _ item: MemoryArchiveItem,
        syncToBackend shouldSyncToBackend: Bool = true,
        backendSyncCompletion: ((Result<Void, Error>) -> Void)? = nil
    ) -> Bool {
        guard let lease = currentArchiveStorageLease,
              isCurrentArchiveStorageLease(lease, at: .request),
              item.ownerUserId.trimmingCharacters(in: .whitespacesAndNewlines) == lease.archiveOwnerId else {
            print("[Archive] rejected ownerless or mismatched local update")
            return false
        }
        let ownedItem = item.enforcingLocalOnlyPhotoTransferState()
        let shouldAttemptBackendSync = shouldSyncToBackend
            && ownedItem.isPublicBackendSyncEligible
            && DreamJourneyBackendClient.shared.isArchiveSyncConfigured
        let itemForStorage = shouldAttemptBackendSync
            ? ownedItem.updatingBackendSyncState(.pending)
            : ownedItem
        var items = items(for: lease)
        guard let index = items.firstIndex(where: { $0.id == itemForStorage.id }) else {
            return false
        }
        let previousItem = items[index]
        items[index] = itemForStorage
        guard save(items, lease: lease) else { return false }
        removeReplacedMediaIfNeeded(
            previousItem: previousItem,
            updatedItem: itemForStorage,
            scope: lease.storageScope
        )
        scheduleTimeLetterReminderIfNeeded(itemForStorage)
        if shouldAttemptBackendSync {
            syncToBackend(
                itemForStorage,
                lease: lease,
                completion: backendSyncCompletion
            )
        } else {
            backendSyncCompletion?(.success(()))
        }
        return true
    }

    func syncPendingPublicArchiveItemsToBackend() {
        guard DreamJourneyBackendClient.shared.isArchiveSyncConfigured else {
            return
        }

        guard let lease = currentArchiveStorageLease,
              isCurrentArchiveStorageLease(lease, at: .request) else {
            return
        }

        var items = items(for: lease)
        var retryItems: [MemoryArchiveItem] = []
        var didUpdateItems = false

        for index in items.indices {
            let item = items[index]
            guard item.isPublicBackendSyncEligible,
                  item.backendSyncState != .synced else {
                continue
            }

            let retryItem = item.updatingBackendSyncState(.pending)
            items[index] = retryItem
            retryItems.append(retryItem)
            didUpdateItems = true
        }

        if didUpdateItems {
            save(items, lease: lease)
        }
        retryItems.forEach { syncToBackend($0, lease: lease) }
    }

    func archiveMediaUploadIntentPayload(for item: MemoryArchiveItem) -> [String: Any]? {
        guard let lease = currentArchiveStorageLease,
              isCurrentArchiveStorageLease(lease, at: .request),
              item.ownerUserId.trimmingCharacters(in: .whitespacesAndNewlines) == lease.archiveOwnerId,
              item.isMediaUploadIntentEligible,
              let fileName = item.mediaUploadFileName,
              let contentType = item.mediaUploadContentType,
              let fileSizeBytes = item.mediaUploadFileSizeBytes else {
            return nil
        }

        return item.archiveMediaUploadIntentPayload(
            userId: lease.archiveOwnerId,
            personaScope: lease.personaScope,
            digitalHumanId: lease.digitalHumanId,
            fileName: fileName,
            contentType: contentType,
            fileSizeBytes: fileSizeBytes
        )
    }

    @discardableResult
    func remove(id: String) -> Bool {
        guard let lease = currentArchiveStorageLease,
              isCurrentArchiveStorageLease(lease, at: .request) else {
            return false
        }
        var items = items(for: lease)
        guard let removedItem = items.first(where: { $0.id == id }),
              removedItem.ownerUserId.trimmingCharacters(in: .whitespacesAndNewlines)
                == lease.archiveOwnerId else {
            return false
        }
        if removedItem.isSealedTimeLetter {
            return false
        }
        items.removeAll { $0.id == id }
        guard save(items, lease: lease) else { return false }
        removeMedia(for: removedItem, scope: lease.storageScope)
        return true
    }

    @discardableResult
    func purgeLocalArchiveDataForAccountDeletion(accountLease: AccountLease) -> Bool {
        let ownerScope = ArchiveStorageScope(
            accountLease: accountLease,
            archiveOwnerId: accountLease.subjectId
        )
        guard ownerScope.isValid else {
            return false
        }
        let mediaDirectories = localStorage.mediaDirectoryRelativePaths(accountLease: accountLease)
        do {
            try mediaStore.purgeScopedDirectories(relativePaths: mediaDirectories)
            localStorage.purgeAccount(accountLease: accountLease)
            return true
        } catch {
            print("[Archive] account deletion local purge failed: \(error.localizedDescription)")
            return false
        }
    }

    func summary() -> (total: Int, photos: Int, audio: Int, text: Int) {
        let items = allItems()
        return (
            total: items.count,
            photos: items.filter { $0.kind == .photo }.count,
            audio: items.filter { $0.kind == .audio }.count,
            text: items.filter { $0.kind == .text || $0.kind == .timeLetter }.count
        )
    }

    func dueTimeLetters(now: Date = Date()) -> [MemoryArchiveItem] {
        allItems()
            .filter { item in
                guard item.isSealedTimeLetter,
                      item.timeLetterDeliveryStatus != "delivered",
                      let openAt = item.timeLetterOpenAt else {
                    return false
                }
                return openAt <= now
            }
            .sorted { ($0.timeLetterOpenAt ?? $0.createdAt) > ($1.timeLetterOpenAt ?? $1.createdAt) }
    }

    func timeLetterMailboxReminders() -> [TimeLetterMailboxReminder] {
        guard let accountLease = captureCurrentAccountLease() else { return [] }
        return timeLetterMailboxReminders(accountLease: accountLease)
    }

    private func timeLetterMailboxReminders(
        accountLease: AccountLease
    ) -> [TimeLetterMailboxReminder] {
        guard isCurrentAccountLease(accountLease, at: .request),
              let scope = timeLetterMailboxOwnerScope(accountLease: accountLease) else {
            return []
        }
        let reminders: [TimeLetterMailboxReminder]? = withMessageStateLock {
            guard retireLegacyMailboxIfNeeded(accountLease: accountLease) else { return nil }
            guard let data = UserDefaults.standard.data(
                forKey: scope.storageKey(for: .timeLetterMailbox)
            ) else {
                return []
            }
            guard let envelope = try? JSONDecoder().decode(
                InAppMessageSourceEnvelope<TimeLetterMailboxReminder>.self,
                from: data
            ), envelope.matches(scope) else {
                return nil
            }
            return envelope.sources
        }
        guard let reminders,
              isCurrentAccountLease(accountLease, at: .runtime) else {
            return []
        }
        return reminders
    }

    func timeLetterReminderCount(now: Date = Date()) -> Int {
        var sourceIds = Set(dueTimeLetters(now: now).map(\.id))
        timeLetterMailboxReminders()
            .filter(\.isUnread)
            .forEach { sourceIds.insert($0.sourceArchiveItemId) }
        return sourceIds.count
    }

    func inAppMessageCenterSnapshot(
        includeUnavailableCandidates: Bool = false,
        includeTimeLetters: Bool = true,
        includeEchoReplies: Bool = true,
        familyInvitationSources: [FamilyInvitationMessageSource] = [],
        careSignalSources: [CareSignalMessageSource] = [],
        echoReplySources: [EchoReplyMessageSource] = [],
        systemNoticeSources: [SystemNoticeMessageSource] = []
    ) -> InAppMessageCenterSnapshot {
        guard let accountLease = captureCurrentAccountLease() else {
            return InAppMessageCenterSnapshot(messages: [], hiddenCandidateMessages: [])
        }
        return inAppMessageCenterSnapshot(
            accountLease: accountLease,
            includeUnavailableCandidates: includeUnavailableCandidates,
            includeTimeLetters: includeTimeLetters,
            includeEchoReplies: includeEchoReplies,
            familyInvitationSources: familyInvitationSources,
            careSignalSources: careSignalSources,
            echoReplySources: echoReplySources,
            systemNoticeSources: systemNoticeSources
        )
    }

    func inAppMessageCenterSnapshot(
        accountLease: AccountLease,
        includeUnavailableCandidates: Bool = false,
        includeTimeLetters: Bool = true,
        includeEchoReplies: Bool = true,
        familyInvitationSources: [FamilyInvitationMessageSource] = [],
        careSignalSources: [CareSignalMessageSource] = [],
        echoReplySources: [EchoReplyMessageSource] = [],
        systemNoticeSources: [SystemNoticeMessageSource] = []
    ) -> InAppMessageCenterSnapshot {
        guard isCurrentAccountLease(accountLease, at: .request) else {
            return InAppMessageCenterSnapshot(messages: [], hiddenCandidateMessages: [])
        }
        let timeLetterMessages = includeTimeLetters
            ? timeLetterMailboxReminders(accountLease: accountLease)
                .map(InAppMessage.fromTimeLetterReminder)
            : []
        let familyInvitationMessages = familyInvitationSources
            .compactMap(InAppMessage.fromFamilyInvitation)
            .map { applyLocalInAppMessageStateIfNeeded($0, accountLease: accountLease) }
        let careSignalMessages = careSignalSources
            .compactMap(InAppMessage.fromCareSignal)
            .map { applyLocalInAppMessageStateIfNeeded($0, accountLease: accountLease) }
        let systemNoticeMessages = systemNoticeSources
            .compactMap(InAppMessage.fromSystemNotice)
            .map { applyLocalInAppMessageStateIfNeeded($0, accountLease: accountLease) }
        let echoReplyMessages = includeEchoReplies
            ? echoReplySources
                .compactMap(InAppMessage.fromEchoReply)
                .map { applyLocalInAppMessageStateIfNeeded($0, accountLease: accountLease) }
            : []
        let hiddenCandidates: [InAppMessage] = []
        let visibleMessages = InAppMessageCenterSnapshot.sortedMessages(
            timeLetterMessages
                + familyInvitationMessages
                + careSignalMessages
                + systemNoticeMessages
                + echoReplyMessages
        )
        let candidateMessages = includeUnavailableCandidates ? hiddenCandidates : []
        guard isCurrentAccountLease(accountLease, at: .runtime) else {
            return InAppMessageCenterSnapshot(messages: [], hiddenCandidateMessages: [])
        }
        return InAppMessageCenterSnapshot(
            messages: visibleMessages,
            hiddenCandidateMessages: candidateMessages
        )
    }

    func timeLetterMailboxReminder(for message: InAppMessage) -> TimeLetterMailboxReminder? {
        guard let accountLease = captureCurrentAccountLease() else { return nil }
        return timeLetterMailboxReminder(for: message, accountLease: accountLease)
    }

    func timeLetterMailboxReminder(
        for message: InAppMessage,
        accountLease: AccountLease
    ) -> TimeLetterMailboxReminder? {
        guard message.kind == .timeLetter else {
            return nil
        }
        guard isCurrentAccountLease(accountLease, at: .request) else { return nil }
        return timeLetterMailboxReminders(accountLease: accountLease).first { reminder in
            reminder.id == message.id || reminder.sourceArchiveItemId == message.sourceArchiveItemId
        }
    }

    func markInAppMessageRead(
        _ message: InAppMessage,
        completion: ((Result<InAppMessage, Error>) -> Void)? = nil
    ) {
        guard let accountLease = captureCurrentAccountLease() else {
            completion?(.failure(ArchiveRepositoryError.accountScopeChanged))
            return
        }
        markInAppMessageRead(message, accountLease: accountLease, completion: completion)
    }

    func markInAppMessageRead(
        _ message: InAppMessage,
        accountLease: AccountLease,
        completion: ((Result<InAppMessage, Error>) -> Void)? = nil
    ) {
        guard isCurrentAccountLease(accountLease, at: .request) else {
            completion?(.failure(ArchiveRepositoryError.accountScopeChanged))
            return
        }
        guard message.kind == .timeLetter else {
            let updatedMessage = message.markingRead(readAt: isoFormatter.string(from: Date()))
            guard updateLocalInAppMessageState(updatedMessage, accountLease: accountLease) else {
                completion?(.failure(ArchiveRepositoryError.accountScopeChanged))
                return
            }
            deliver(.success(updatedMessage), lease: accountLease, completion: completion)
            return
        }
        guard message.kind == .timeLetter,
              let reminder = timeLetterMailboxReminder(for: message, accountLease: accountLease) else {
            completion?(.failure(NSError(
                domain: "DreamJourney.InAppMessageCenter",
                code: 404,
                userInfo: [NSLocalizedDescriptionKey: "消息暂不可打开"]
            )))
            return
        }
        markTimeLetterMailboxReminderRead(reminder, accountLease: accountLease) { result in
            switch result {
            case .success(let updatedReminder):
                completion?(.success(InAppMessage.fromTimeLetterReminder(updatedReminder)))
            case .failure(let error):
                completion?(.failure(error))
            }
        }
    }

    func archiveInAppMessage(
        _ message: InAppMessage,
        completion: ((Result<InAppMessage, Error>) -> Void)? = nil
    ) {
        guard let accountLease = captureCurrentAccountLease() else {
            completion?(.failure(ArchiveRepositoryError.accountScopeChanged))
            return
        }
        archiveInAppMessage(message, accountLease: accountLease, completion: completion)
    }

    func archiveInAppMessage(
        _ message: InAppMessage,
        accountLease: AccountLease,
        completion: ((Result<InAppMessage, Error>) -> Void)? = nil
    ) {
        guard isCurrentAccountLease(accountLease, at: .request) else {
            completion?(.failure(ArchiveRepositoryError.accountScopeChanged))
            return
        }
        guard message.kind == .timeLetter else {
            let updatedMessage = message.markingArchived(archivedAt: isoFormatter.string(from: Date()))
            guard updateLocalInAppMessageState(updatedMessage, accountLease: accountLease) else {
                completion?(.failure(ArchiveRepositoryError.accountScopeChanged))
                return
            }
            deliver(.success(updatedMessage), lease: accountLease, completion: completion)
            return
        }
        guard message.kind == .timeLetter,
              let reminder = timeLetterMailboxReminder(for: message, accountLease: accountLease) else {
            completion?(.failure(NSError(
                domain: "DreamJourney.InAppMessageCenter",
                code: 404,
                userInfo: [NSLocalizedDescriptionKey: "消息暂不可归档"]
            )))
            return
        }
        markTimeLetterMailboxReminderArchived(reminder, accountLease: accountLease) { result in
            switch result {
            case .success(let updatedReminder):
                completion?(.success(InAppMessage.fromTimeLetterReminder(updatedReminder)))
            case .failure(let error):
                completion?(.failure(error))
            }
        }
    }

    func markTimeLetterMailboxReminderRead(
        _ reminder: TimeLetterMailboxReminder,
        completion: ((Result<TimeLetterMailboxReminder, Error>) -> Void)? = nil
    ) {
        guard let accountLease = captureCurrentAccountLease() else {
            completion?(.failure(ArchiveRepositoryError.accountScopeChanged))
            return
        }
        markTimeLetterMailboxReminderRead(reminder, accountLease: accountLease, completion: completion)
    }

    func markTimeLetterMailboxReminderRead(
        _ reminder: TimeLetterMailboxReminder,
        accountLease: AccountLease,
        completion: ((Result<TimeLetterMailboxReminder, Error>) -> Void)? = nil
    ) {
        guard isCurrentAccountLease(accountLease, at: .request) else {
            completion?(.failure(ArchiveRepositoryError.accountScopeChanged))
            return
        }
        let readAt = isoFormatter.string(from: Date())
        let updatedReminder = reminder.markingRead(readAt: readAt)
        guard updateCachedTimeLetterMailboxReminder(updatedReminder, accountLease: accountLease) else {
            completion?(.failure(ArchiveRepositoryError.accountScopeChanged))
            return
        }

        guard DreamJourneyBackendClient.shared.isTimeLetterDispatchConfigured else {
            deliver(.success(updatedReminder), lease: accountLease, completion: completion)
            return
        }

        DreamJourneyBackendClient.shared.markMailboxLetterRead(
            userId: accountLease.subjectId,
            letterId: reminder.id,
            readAtISO: readAt
        ) { [weak self] result in
            guard let self else { return }
            guard isCurrentAccountLease(accountLease, at: .commit) else { return }
            switch result {
            case .success(let object):
                if let item = Self.timeLetterMailboxReminder(fromReadResponse: object) {
                    guard updateCachedTimeLetterMailboxReminder(item, accountLease: accountLease) else {
                        return
                    }
                    deliver(.success(item), lease: accountLease, completion: completion)
                } else {
                    deliver(.success(updatedReminder), lease: accountLease, completion: completion)
                }
            case .failure(let error):
                print("[Archive] mark mailbox reminder read failed: \(error.localizedDescription)")
                deliver(.failure(error), lease: accountLease, completion: completion)
            }
        }
    }

    func markTimeLetterMailboxReminderArchived(
        _ reminder: TimeLetterMailboxReminder,
        completion: ((Result<TimeLetterMailboxReminder, Error>) -> Void)? = nil
    ) {
        guard let accountLease = captureCurrentAccountLease() else {
            completion?(.failure(ArchiveRepositoryError.accountScopeChanged))
            return
        }
        markTimeLetterMailboxReminderArchived(reminder, accountLease: accountLease, completion: completion)
    }

    func markTimeLetterMailboxReminderArchived(
        _ reminder: TimeLetterMailboxReminder,
        accountLease: AccountLease,
        completion: ((Result<TimeLetterMailboxReminder, Error>) -> Void)? = nil
    ) {
        guard isCurrentAccountLease(accountLease, at: .request) else {
            completion?(.failure(ArchiveRepositoryError.accountScopeChanged))
            return
        }
        let archivedAt = isoFormatter.string(from: Date())
        let updatedReminder = reminder.markingArchived(archivedAt: archivedAt)
        guard updateCachedTimeLetterMailboxReminder(updatedReminder, accountLease: accountLease) else {
            completion?(.failure(ArchiveRepositoryError.accountScopeChanged))
            return
        }

        guard DreamJourneyBackendClient.shared.isTimeLetterDispatchConfigured else {
            deliver(.success(updatedReminder), lease: accountLease, completion: completion)
            return
        }

        DreamJourneyBackendClient.shared.archiveMailboxLetter(
            userId: accountLease.subjectId,
            letterId: reminder.id,
            archivedAtISO: archivedAt
        ) { [weak self] result in
            guard let self else { return }
            guard isCurrentAccountLease(accountLease, at: .commit) else { return }
            switch result {
            case .success(let object):
                if let item = Self.timeLetterMailboxReminder(fromReadResponse: object) {
                    guard updateCachedTimeLetterMailboxReminder(item, accountLease: accountLease) else {
                        return
                    }
                    deliver(.success(item), lease: accountLease, completion: completion)
                } else {
                    deliver(.success(updatedReminder), lease: accountLease, completion: completion)
                }
            case .failure(let error):
                print("[Archive] archive mailbox reminder failed: \(error.localizedDescription)")
                deliver(.failure(error), lease: accountLease, completion: completion)
            }
        }
    }

    func refreshTimeLetterMailboxReminders(
        completion: ((Result<[TimeLetterMailboxReminder], Error>) -> Void)? = nil
    ) {
        guard DreamJourneyBackendClient.shared.isTimeLetterDispatchConfigured else {
            completion?(.failure(ArchiveRepositoryError.backendNotConfigured))
            return
        }

        guard let accountLease = captureCurrentAccountLease(),
              isCurrentAccountLease(accountLease, at: .request) else {
            completion?(.failure(ArchiveRepositoryError.accountScopeChanged))
            return
        }

        DreamJourneyBackendClient.shared.listMailboxLetters(userId: accountLease.subjectId) { [weak self] result in
            guard let self else { return }
            guard isCurrentAccountLease(accountLease, at: .commit) else { return }
            switch result {
            case .success(let object):
                let reminders = Self.timeLetterMailboxReminders(from: object)
                guard replaceCachedTimeLetterMailboxReminders(
                    reminders,
                    accountLease: accountLease
                ) else {
                    deliver(
                        .failure(ArchiveRepositoryError.accountScopeChanged),
                        lease: accountLease,
                        completion: completion
                    )
                    return
                }
                deliver(.success(reminders), lease: accountLease, completion: completion)
            case .failure(let error):
                print("[Archive] timeLetter mailbox fetch failed: \(error.localizedDescription)")
                deliver(.failure(error), lease: accountLease, completion: completion)
            }
        }
    }

    func resolveTimeLetterReminderDetail(
        _ reminder: TimeLetterMailboxReminder,
        completion: @escaping (Result<MemoryArchiveItem, Error>) -> Void
    ) {
        guard let lease = currentArchiveStorageLease,
              isCurrentArchiveStorageLease(lease, at: .request) else {
            completion(.failure(ArchiveRepositoryError.accountScopeChanged))
            return
        }
        let ownerUserId = reminder.ownerUserId.trimmingCharacters(in: .whitespacesAndNewlines)
        let canFetchRemoteDetail = DreamJourneyBackendClient.shared.isTimeLetterDispatchConfigured && !ownerUserId.isEmpty

        if canFetchRemoteDetail {
            DreamJourneyBackendClient.shared.getTimeLetterDetail(
                ownerUserId: ownerUserId,
                itemId: reminder.sourceArchiveItemId,
                viewerUserId: lease.accountUserId
            ) { [weak self] result in
                guard let self else { return }
                guard isCurrentArchiveStorageLease(lease, at: .commit) else { return }
                switch result {
                case .success(let object):
                    guard let item = Self.timeLetterDetailItem(from: object),
                          isExpectedTimeLetterDetail(item, reminder: reminder, lease: lease) else {
                        deliver(
                            .failure(ArchiveRepositoryError.invalidBackendDetail),
                            lease: lease.accountLease,
                            completion: completion
                        )
                        return
                    }
                    if item.ownerUserId.trimmingCharacters(in: .whitespacesAndNewlines)
                        == lease.archiveOwnerId {
                        upsertResolvedTimeLetterDetail(item, lease: lease)
                    }
                    deliver(.success(item), lease: lease.accountLease, completion: completion)
                case .failure(let error):
                    if let localItem = localTimeLetterDetailItem(for: reminder, lease: lease) {
                        deliver(.success(localItem), lease: lease.accountLease, completion: completion)
                    } else {
                        deliver(.failure(error), lease: lease.accountLease, completion: completion)
                    }
                }
            }
            return
        }

        if let localItem = localTimeLetterDetailItem(for: reminder, lease: lease) {
            deliver(.success(localItem), lease: lease.accountLease, completion: completion)
            return
        }

        deliver(
            .failure(ArchiveRepositoryError.timeLetterDetailUnavailable),
            lease: lease.accountLease,
            completion: completion
        )
    }

    func contextSnapshot(limit: Int = 6) -> MemoryArchiveContextSnapshot {
        let items = allItems()
        let availableItems = items
            .filter(\.isAvailableForArchiveContext)
            .sorted { $0.updatedAt > $1.updatedAt }
        let limitedItems = Array(availableItems.prefix(max(0, limit)))
        let entries = limitedItems.map(\.archiveContextEntry)

        return MemoryArchiveContextSnapshot(
            totalItemCount: items.count,
            availableItemCount: availableItems.count,
            entries: entries
        )
    }

    func refreshFromBackend(completion: ((Result<[MemoryArchiveItem], Error>) -> Void)? = nil) {
        guard DreamJourneyBackendClient.shared.isArchiveSyncConfigured else {
            completion?(.failure(ArchiveRepositoryError.backendNotConfigured))
            return
        }

        guard let lease = currentArchiveStorageLease,
              isCurrentArchiveStorageLease(lease, at: .request) else {
            completion?(.failure(ArchiveRepositoryError.accountScopeChanged))
            return
        }
        DreamJourneyBackendClient.shared.listArchiveItems(userId: lease.archiveOwnerId) { [weak self] result in
            guard let self else { return }
            guard isCurrentArchiveStorageLease(lease, at: .commit) else { return }
            switch result {
            case .success(let object):
                let remoteItems = Self.archiveItems(from: object)
                    .filter {
                        $0.ownerUserId.trimmingCharacters(in: .whitespacesAndNewlines)
                            == lease.archiveOwnerId
                    }
                let mergedItems = mergeRemoteItems(
                    remoteItems,
                    localItems: items(for: lease),
                    expectedArchiveOwnerId: lease.archiveOwnerId
                )
                save(mergedItems, lease: lease)
                deliver(
                    .success(mergedItems.sorted { $0.createdAt > $1.createdAt }),
                    lease: lease.accountLease,
                    completion: completion
                )
            case .failure(let error):
                print("[Archive] backend fetch failed: \(error.localizedDescription)")
                deliver(.failure(error), lease: lease.accountLease, completion: completion)
            }
        }
    }

    private var currentUserId: String {
        UserManager.shared.currentUser?.id ?? ""
    }

    private var currentArchiveOwnerId: String {
        currentArchiveVisibilityContext.ownerId
    }

    private var currentArchiveVisibilityContext: ArchiveVisibilityContext {
        let context = DigitalHumanContextStore.shared.current
        let ownerId = context.ownerId
            .trimmingCharacters(in: .whitespacesAndNewlines)
        let resolvedOwnerId = ownerId.isEmpty ? currentUserId : ownerId
        let personaScope = context.isSelfAssistant ? Self.personalPersonaScope : Self.familyPersonaScope
        let digitalHumanId = context.isSelfAssistant ? resolvedOwnerId : Self.defaultFamilyDigitalHumanId

        return ArchiveVisibilityContext(
            ownerId: resolvedOwnerId,
            personaScope: personaScope,
            digitalHumanId: digitalHumanId
        )
    }

    private var currentArchiveStorageLease: ArchiveStorageLease? {
        let accountUserId = currentUserId
        guard !accountUserId.isEmpty,
              let accountLease = accountLeaseRuntime.capture(forSubjectId: accountUserId) else {
            return nil
        }
        let visibilityContext = currentArchiveVisibilityContext
        let archiveOwnerId = visibilityContext.ownerId
        let storageScope = ArchiveStorageScope(
            accountLease: accountLease,
            archiveOwnerId: archiveOwnerId
        )
        guard storageScope.isValid else { return nil }
        return ArchiveStorageLease(
            accountLease: accountLease,
            accountUserId: accountUserId,
            archiveOwnerId: archiveOwnerId,
            personaScope: visibilityContext.personaScope,
            digitalHumanId: visibilityContext.digitalHumanId,
            storageScope: storageScope,
            storageKey: storageScope.storageKey
        )
    }

    private func isCurrentArchiveStorageLease(
        _ lease: ArchiveStorageLease,
        at checkpoint: AccountLeaseCheckpoint
    ) -> Bool {
        let visibilityContext = currentArchiveVisibilityContext
        return accountLeaseRuntime.validate(lease.accountLease, at: checkpoint).allowed
            && currentUserId == lease.accountUserId
            && visibilityContext.ownerId == lease.archiveOwnerId
            && visibilityContext.personaScope == lease.personaScope
            && visibilityContext.digitalHumanId == lease.digitalHumanId
            && ArchiveStorageScope(
                accountLease: lease.accountLease,
                archiveOwnerId: visibilityContext.ownerId
            ).storageKey == lease.storageKey
    }

    private func legacyMailboxStorageKey(for accountUserId: String) -> String {
        "\(legacyMailboxBaseKey).\(accountUserId)"
    }

    private func legacyInAppMessageStateStorageKey(for accountUserId: String) -> String {
        "\(legacyInAppMessageStateBaseKey).\(accountUserId)"
    }

    private func timeLetterMailboxOwnerScope(
        accountLease: AccountLease
    ) -> InAppMessageOwnerScope? {
        let scope = InAppMessageOwnerScope(
            accountLease: accountLease,
            resourceOwnerId: accountLease.subjectId,
            operationId: timeLetterMailboxOperationId
        )
        return scope.isValid ? scope : nil
    }

    private func retireLegacyMailboxIfNeeded(accountLease: AccountLease) -> Bool {
        let legacyStorageKey = legacyMailboxStorageKey(for: accountLease.subjectId)
        let sourceItemCount = UserDefaults.standard.data(forKey: legacyStorageKey).flatMap {
            try? JSONDecoder().decode([TimeLetterMailboxReminder].self, from: $0).count
        }
        return InAppMessageLegacyRetirementStorage.retireIfNeeded(
            surface: .timeLetterMailbox,
            legacyStorageKey: legacyStorageKey,
            sourceItemCount: sourceItemCount,
            defaults: .standard,
            namespace: legacyRetirementNamespace(accountLease.subjectId)
        )
    }

    private func retireLegacyInAppMessageStateIfNeeded(accountLease: AccountLease) -> Bool {
        let legacyStorageKey = legacyInAppMessageStateStorageKey(for: accountLease.subjectId)
        return withMessageStateLock {
            InAppMessageLegacyRetirementStorage.retireIfNeeded(
                surface: .localState,
                legacyStorageKey: legacyStorageKey,
                sourceItemCount: nil,
                defaults: .standard,
                namespace: legacyRetirementNamespace(accountLease.subjectId)
            )
        }
    }

    private func legacyRetirementNamespace(_ accountUserId: String) -> String {
        ArchiveLocalStoragePolicy.sha256("legacy-owner:\(accountUserId)")
            .replacingOccurrences(of: "sha256:", with: "")
    }

    private func withMessageStateLock<T>(_ body: () -> T) -> T {
        messageStateLock.lock()
        defer { messageStateLock.unlock() }
        return body()
    }

    private func captureCurrentAccountLease() -> AccountLease? {
        let accountUserId = currentUserId
        guard !accountUserId.isEmpty else { return nil }
        return accountLeaseRuntime.capture(forSubjectId: accountUserId)
    }

    private func isCurrentAccountLease(
        _ accountLease: AccountLease,
        at checkpoint: AccountLeaseCheckpoint
    ) -> Bool {
        accountLease.subjectId == currentUserId
            && accountLeaseRuntime.validate(accountLease, at: checkpoint).allowed
    }

    private func deliver<T>(
        _ result: Result<T, Error>,
        lease: AccountLease,
        completion: ((Result<T, Error>) -> Void)?
    ) {
        guard let completion,
              isCurrentAccountLease(lease, at: .ui) else {
            return
        }
        completion(result)
    }

    @discardableResult
    private func save(_ items: [MemoryArchiveItem]) -> Bool {
        guard let lease = currentArchiveStorageLease else { return false }
        return save(items, lease: lease)
    }

    @discardableResult
    private func save(_ items: [MemoryArchiveItem], lease: ArchiveStorageLease) -> Bool {
        guard isCurrentArchiveStorageLease(lease, at: .commit) else { return false }
        let sortedItems = items.sorted { $0.createdAt > $1.createdAt }
        do {
            try localStorage.save(items: sortedItems, scope: lease.storageScope)
            return true
        } catch {
            print("[Archive] scoped local save rejected: \(error.localizedDescription)")
            return false
        }
    }

    private func removeReplacedMediaIfNeeded(
        previousItem: MemoryArchiveItem,
        updatedItem: MemoryArchiveItem,
        scope: ArchiveStorageScope
    ) {
        if previousItem.localMediaMetadata?.relativePath != updatedItem.localMediaMetadata?.relativePath,
           let previousMetadata = previousItem.localMediaMetadata {
            try? mediaStore.remove(previousMetadata, scope: scope, storageClass: .original)
        }
        if previousItem.localThumbnailMetadata?.relativePath != updatedItem.localThumbnailMetadata?.relativePath,
           let previousThumbnailMetadata = previousItem.localThumbnailMetadata {
            try? mediaStore.remove(previousThumbnailMetadata, scope: scope, storageClass: .thumbnail)
        }
    }

    private func removeMedia(for item: MemoryArchiveItem, scope: ArchiveStorageScope) {
        if let mediaMetadata = item.localMediaMetadata {
            try? mediaStore.remove(mediaMetadata, scope: scope, storageClass: .original)
        }
        if let thumbnailMetadata = item.localThumbnailMetadata {
            try? mediaStore.remove(thumbnailMetadata, scope: scope, storageClass: .thumbnail)
        }
    }

    @discardableResult
    func replaceCachedTimeLetterMailboxReminders(
        _ reminders: [TimeLetterMailboxReminder],
        accountLease: AccountLease
    ) -> Bool {
        guard isCurrentAccountLease(accountLease, at: .request),
              let scope = timeLetterMailboxOwnerScope(accountLease: accountLease),
              let data = try? JSONEncoder().encode(
                  InAppMessageSourceEnvelope(sources: reminders, scope: scope)
              ) else {
            return false
        }
        return withMessageStateLock {
            guard retireLegacyMailboxIfNeeded(accountLease: accountLease),
                  isCurrentAccountLease(accountLease, at: .commit) else {
                return false
            }
            let storageKey = scope.storageKey(for: .timeLetterMailbox)
            let previousData = UserDefaults.standard.data(forKey: storageKey)
            UserDefaults.standard.set(data, forKey: storageKey)
            guard UserDefaults.standard.data(forKey: storageKey) == data else { return false }
            guard isCurrentAccountLease(accountLease, at: .commit) else {
                if let previousData {
                    UserDefaults.standard.set(previousData, forKey: storageKey)
                } else {
                    UserDefaults.standard.removeObject(forKey: storageKey)
                }
                return false
            }
            return true
        }
    }

    private func localInAppMessageState(
        for message: InAppMessage,
        accountLease: AccountLease
    ) -> InAppMessageLocalState? {
        guard isCurrentAccountLease(accountLease, at: .request),
              retireLegacyInAppMessageStateIfNeeded(accountLease: accountLease),
              let scope = inAppMessageOwnerScope(for: message, accountLease: accountLease),
              let data = UserDefaults.standard.data(forKey: scope.storageKey(for: .localState)),
              let envelope = try? JSONDecoder().decode(
                InAppMessageSourceEnvelope<InAppMessageLocalState>.self,
                from: data
              ),
              envelope.matches(scope),
              let state = envelope.sources.first,
              state.messageId == message.id,
              isCurrentAccountLease(accountLease, at: .runtime) else {
            return nil
        }
        return state
    }

    @discardableResult
    private func updateLocalInAppMessageState(
        _ message: InAppMessage,
        accountLease: AccountLease
    ) -> Bool {
        guard message.kind != .timeLetter else {
            return false
        }
        guard isCurrentAccountLease(accountLease, at: .commit),
              retireLegacyInAppMessageStateIfNeeded(accountLease: accountLease),
              let scope = inAppMessageOwnerScope(for: message, accountLease: accountLease) else {
            return false
        }
        let state = InAppMessageLocalState(
            messageId: message.id,
            status: message.status,
            readAt: message.readAt,
            archivedAt: message.archivedAt
        )
        let envelope = InAppMessageSourceEnvelope(sources: [state], scope: scope)
        guard let data = try? JSONEncoder().encode(envelope) else { return false }
        let storageKey = scope.storageKey(for: .localState)
        return withMessageStateLock {
            let previousData = UserDefaults.standard.data(forKey: storageKey)
            UserDefaults.standard.set(data, forKey: storageKey)
            guard UserDefaults.standard.data(forKey: storageKey) == data else { return false }
            guard isCurrentAccountLease(accountLease, at: .commit) else {
                if let previousData {
                    UserDefaults.standard.set(previousData, forKey: storageKey)
                } else {
                    UserDefaults.standard.removeObject(forKey: storageKey)
                }
                return false
            }
            return true
        }
    }

    private func applyLocalInAppMessageStateIfNeeded(
        _ message: InAppMessage,
        accountLease: AccountLease
    ) -> InAppMessage {
        guard message.kind != .timeLetter,
              let state = localInAppMessageState(for: message, accountLease: accountLease) else {
            return message
        }
        switch state.status {
        case .unread:
            return message
        case .read:
            return message.markingRead(readAt: state.readAt ?? isoFormatter.string(from: Date()))
        case .archived:
            return message.markingArchived(archivedAt: state.archivedAt ?? isoFormatter.string(from: Date()))
        }
    }

    private func inAppMessageOwnerScope(
        for message: InAppMessage,
        accountLease: AccountLease
    ) -> InAppMessageOwnerScope? {
        guard let resourceOwnerId = message.ownerUserId?.trimmingCharacters(in: .whitespacesAndNewlines),
              !resourceOwnerId.isEmpty else {
            return nil
        }
        let scope = InAppMessageOwnerScope(
            accountLease: accountLease,
            resourceOwnerId: resourceOwnerId,
            operationId: message.id
        )
        return scope.isValid ? scope : nil
    }

    @discardableResult
    private func updateCachedTimeLetterMailboxReminder(
        _ reminder: TimeLetterMailboxReminder,
        accountLease: AccountLease
    ) -> Bool {
        return withMessageStateLock {
            guard isCurrentAccountLease(accountLease, at: .commit) else { return false }
            var reminders = timeLetterMailboxReminders(accountLease: accountLease)
            if let index = reminders.firstIndex(where: { $0.id == reminder.id }) {
                reminders[index] = reminder
            } else {
                reminders.insert(reminder, at: 0)
            }
            return replaceCachedTimeLetterMailboxReminders(reminders, accountLease: accountLease)
        }
    }

    private func localTimeLetterDetailItem(
        for reminder: TimeLetterMailboxReminder,
        lease: ArchiveStorageLease
    ) -> MemoryArchiveItem? {
        items(for: lease).first { item in
            isExpectedTimeLetterDetail(item, reminder: reminder, lease: lease)
        }
    }

    private func isExpectedTimeLetterDetail(
        _ item: MemoryArchiveItem,
        reminder: TimeLetterMailboxReminder,
        lease: ArchiveStorageLease
    ) -> Bool {
        let reminderOwner = reminder.ownerUserId.trimmingCharacters(in: .whitespacesAndNewlines)
        let expectedOwner = reminderOwner.isEmpty ? lease.archiveOwnerId : reminderOwner
        return item.id == reminder.sourceArchiveItemId
            && item.kind == .timeLetter
            && item.ownerUserId.trimmingCharacters(in: .whitespacesAndNewlines) == expectedOwner
    }

    private func upsertResolvedTimeLetterDetail(
        _ item: MemoryArchiveItem,
        lease: ArchiveStorageLease
    ) {
        guard isCurrentArchiveStorageLease(lease, at: .commit),
              item.ownerUserId.trimmingCharacters(in: .whitespacesAndNewlines)
                == lease.archiveOwnerId else { return }
        var items = items(for: lease)
        if let index = items.firstIndex(where: { $0.id == item.id }) {
            items[index] = item
        } else {
            items.insert(item, at: 0)
        }
        save(items, lease: lease)
    }

    private func syncToBackend(
        _ item: MemoryArchiveItem,
        lease: ArchiveStorageLease,
        completion: ((Result<Void, Error>) -> Void)? = nil
    ) {
        guard DreamJourneyBackendClient.shared.isArchiveSyncConfigured else {
            completion?(.failure(ArchiveRepositoryError.backendNotConfigured))
            return
        }

        // Media files remain device-local until a dedicated upload authority
        // is introduced. Do not let a future direct caller bypass add/update.
        guard item.isPublicBackendSyncEligible else {
            completion?(.success(()))
            return
        }

        guard isCurrentArchiveStorageLease(lease, at: .request),
              item.ownerUserId.trimmingCharacters(in: .whitespacesAndNewlines)
                == lease.archiveOwnerId else {
            completion?(.failure(ArchiveRepositoryError.accountScopeChanged))
            return
        }
        let ownerId = lease.archiveOwnerId
        let payload = item.archiveBackendPayload(
            userId: ownerId,
            viewerUserId: lease.accountUserId,
            ownerId: ownerId,
            personaScope: lease.personaScope,
            digitalHumanId: lease.digitalHumanId,
            isoFormatter: isoFormatter
        )
        DreamJourneyBackendClient.shared.postArchiveItem(
            payload
        ) { [weak self] result in
            guard let self else { return }
            guard isCurrentArchiveStorageLease(lease, at: .commit) else {
                completion?(.failure(ArchiveRepositoryError.accountScopeChanged))
                return
            }
            switch result {
            case .success:
                markBackendSyncState(item.id, state: .synced, lease: lease)
                completion?(.success(()))
            case .failure(let error):
                print("[Archive] backend sync failed: \(error.localizedDescription)")
                markBackendSyncState(
                    item.id,
                    state: .failed,
                    error: sanitizeBackendSyncError(error),
                    lease: lease
                )
                completion?(.failure(error))
            }
        }
    }

    private func scheduleTimeLetterReminderIfNeeded(_ item: MemoryArchiveItem) {
        guard item.isSealedTimeLetter,
              item.timeLetterDeliveryStatus != "delivered" else { return }
        TimeLetterReminderScheduler.shared.scheduleIfNeeded(item)
    }

    private func markBackendSyncState(
        _ itemId: String,
        state: ArchiveBackendSyncState,
        error: String? = nil,
        lease: ArchiveStorageLease
    ) {
        guard isCurrentArchiveStorageLease(lease, at: .commit) else { return }
        var items = items(for: lease)
        guard let index = items.firstIndex(where: { $0.id == itemId }),
              items[index].isPublicBackendSyncEligible else {
            return
        }

        switch state {
        case .pending:
            items[index] = items[index].updatingBackendSyncState(.pending)
        case .synced:
            items[index] = items[index].updatingBackendSyncState(.synced)
        case .failed:
            items[index] = items[index].updatingBackendSyncState(.failed, error: error)
        }
        save(items, lease: lease)
    }

    private func sanitizeBackendSyncError(_ error: Error) -> String {
        let normalized = error.localizedDescription
            .replacingOccurrences(of: "\n", with: " ")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        guard !normalized.isEmpty else {
            return "网络异常"
        }
        return String(normalized.prefix(80))
    }

    private static func archiveItems(from object: [String: Any]) -> [MemoryArchiveItem] {
        if let rawItems = rawArchiveItemObjects(from: object["items"]) {
            return rawItems.compactMap(MemoryArchiveItem.init(remoteJSON:))
        }

        if let data = object["data"] {
            if let rawItems = rawArchiveItemObjects(from: data) {
                return rawItems.compactMap(MemoryArchiveItem.init(remoteJSON:))
            }
            if let dataObject = data as? [String: Any],
               let rawItems = rawArchiveItemObjects(from: dataObject["items"]) {
                return rawItems.compactMap(MemoryArchiveItem.init(remoteJSON:))
            }
        }

        return []
    }

    private static func timeLetterMailboxReminders(from object: [String: Any]) -> [TimeLetterMailboxReminder] {
        if let items = object["items"] as? [[String: Any]] {
            return items.compactMap(TimeLetterMailboxReminder.init)
        }
        if let data = object["data"] as? [String: Any],
           let items = data["items"] as? [[String: Any]] {
            return items.compactMap(TimeLetterMailboxReminder.init)
        }
        return []
    }

    private static func timeLetterMailboxReminder(fromReadResponse object: [String: Any]) -> TimeLetterMailboxReminder? {
        if let item = object["item"] as? [String: Any] {
            return TimeLetterMailboxReminder(item)
        }
        if let data = object["data"] as? [String: Any] {
            return timeLetterMailboxReminder(fromReadResponse: data)
        }
        return nil
    }

    private static func timeLetterDetailItem(from object: [String: Any]) -> MemoryArchiveItem? {
        if let item = object["item"] as? [String: Any] {
            return MemoryArchiveItem(remoteJSON: item)
        }
        if let data = object["data"] as? [String: Any] {
            return timeLetterDetailItem(from: data)
        }
        return nil
    }

    private static func rawArchiveItemObjects(from value: Any?) -> [[String: Any]]? {
        if let objects = value as? [[String: Any]] {
            return objects
        }
        guard let values = value as? [Any] else {
            return nil
        }
        let objects = values.compactMap { $0 as? [String: Any] }
        return objects.isEmpty ? nil : objects
    }

    private func items(for lease: ArchiveStorageLease) -> [MemoryArchiveItem] {
        guard isCurrentArchiveStorageLease(lease, at: .request) else { return [] }
        let loaded = localStorage.load(scope: lease.storageScope)
        guard isCurrentArchiveStorageLease(lease, at: .commit) else { return [] }
        return migrateLegacyMediaBindingsIfNeeded(loaded.items, lease: lease)
    }

    private func migrateLegacyMediaBindingsIfNeeded(
        _ items: [MemoryArchiveItem],
        lease: ArchiveStorageLease
    ) -> [MemoryArchiveItem] {
        let candidates = items.filter {
            $0.localMediaMetadata == nil && $0.localPath?.hasPrefix("/") == true
        }
        guard !candidates.isEmpty else { return items }

        let receipts = localStorage.migrationReceipts(scope: lease.storageScope)
        guard !receipts.isEmpty else { return items }
        var migratedItems = items
        var copiedMedia: [ArchiveMediaMetadata] = []

        for candidate in candidates {
            guard isCurrentArchiveStorageLease(lease, at: .runtime),
                  let index = migratedItems.firstIndex(where: { $0.id == candidate.id }),
                  let receipt = receipts.first(where: {
                      $0.migratedItemIds.contains(candidate.id)
                          && ($0.state == .migrated || $0.state == .mixed)
                  }),
                  let migrationBinding = try? mediaStore.legacyMigrationBinding(
                      for: candidate,
                      receipt: receipt,
                      scope: lease.storageScope
                  ),
                  let mediaMetadata = try? mediaStore.migrateLegacyOriginal(
                      for: candidate,
                      receipt: receipt,
                      binding: migrationBinding,
                      scope: lease.storageScope
                  ) else {
                continue
            }
            migratedItems[index] = candidate.migratingLegacyLocalMedia(to: mediaMetadata)
            copiedMedia.append(mediaMetadata)
        }

        guard !copiedMedia.isEmpty else { return items }
        guard save(migratedItems, lease: lease) else {
            copiedMedia.forEach {
                try? mediaStore.remove($0, scope: lease.storageScope, storageClass: .original)
            }
            return items
        }
        return migratedItems
    }

    private func mergeRemoteItems(
        _ remoteItems: [MemoryArchiveItem],
        localItems: [MemoryArchiveItem],
        expectedArchiveOwnerId: String
    ) -> [MemoryArchiveItem] {
        let mergedItems = ArchiveLocalStoragePolicy.merge(
            remoteItems: remoteItems,
            localItems: localItems,
            expectedArchiveOwnerId: expectedArchiveOwnerId
        )
        let localItemsById = Dictionary(
            localItems.map { ($0.id, $0) },
            uniquingKeysWith: { existing, candidate in
                existing.updatedAt >= candidate.updatedAt ? existing : candidate
            }
        )
        return mergedItems.map { item in
            guard let localItem = localItemsById[item.id] else { return item }
            return item.preservingLocalMediaBinding(from: localItem)
        }
    }
}

private enum ArchiveRepositoryError: LocalizedError {
    case backendNotConfigured
    case invalidBackendDetail
    case timeLetterDetailUnavailable
    case accountScopeChanged

    var errorDescription: String? {
        switch self {
        case .backendNotConfigured:
            return "后端地址未配置"
        case .invalidBackendDetail:
            return "后端时间信件详情格式异常"
        case .timeLetterDetailUnavailable:
            return "时间信件详情暂不可用"
        case .accountScopeChanged:
            return "账号或回响对象已切换，旧档案结果已丢弃"
        }
    }
}

protocol TimeLetterReminderNotificationRequestCenter: AnyObject, Sendable {
    func add(
        _ request: UNNotificationRequest,
        withCompletionHandler completionHandler: (@Sendable (Error?) -> Void)?
    )
    func getPendingNotificationRequests(
        completionHandler: @escaping @Sendable ([UNNotificationRequest]) -> Void
    )
    func removePendingNotificationRequests(withIdentifiers identifiers: [String])
}

extension UNUserNotificationCenter: TimeLetterReminderNotificationRequestCenter {}

final class TimeLetterReminderScheduler: @unchecked Sendable {
    static let shared = TimeLetterReminderScheduler()

    private let notificationCenter: UNUserNotificationCenter?
    private let requestCenter: TimeLetterReminderNotificationRequestCenter
    private let accountLeaseRuntime: AccountLeaseRuntimePort

    init(
        notificationCenter: UNUserNotificationCenter = .current(),
        requestCenter: TimeLetterReminderNotificationRequestCenter? = nil,
        accountLeaseRuntime: AccountLeaseRuntimePort = AccountLeaseRuntime.shared
    ) {
        self.notificationCenter = notificationCenter
        self.requestCenter = requestCenter ?? notificationCenter
        self.accountLeaseRuntime = accountLeaseRuntime
    }

    init(
        requestCenter: TimeLetterReminderNotificationRequestCenter,
        accountLeaseRuntime: AccountLeaseRuntimePort
    ) {
        notificationCenter = nil
        self.requestCenter = requestCenter
        self.accountLeaseRuntime = accountLeaseRuntime
    }

    func scheduleIfNeeded(_ item: MemoryArchiveItem) {
        guard item.isSealedTimeLetter,
              let openAt = item.timeLetterOpenAt,
              let accountLease = accountLeaseRuntime.capture(forSubjectId: nil),
              item.ownerUserId == accountLease.subjectId else {
            return
        }
        let accountLeaseIdentity = Self.accountLeaseIdentity(for: accountLease)
        let resourceOwnerIdentity = Self.identityDigest(["resource-owner", item.ownerUserId])
        let operationIdentity = Self.identityDigest(["operation", item.id])
        let identifier = Self.notificationIdentifier(
            itemId: item.id,
            resourceOwnerId: item.ownerUserId,
            accountLease: accountLease
        )
        guard let notificationCenter else { return }
        notificationCenter.requestAuthorization(options: [.alert, .badge, .sound]) { [weak self] granted, _ in
            guard let self,
                  granted,
                  self.accountLeaseRuntime.validate(accountLease, at: .timer).allowed else {
                return
            }
            self.requestCenter.removePendingNotificationRequests(withIdentifiers: [identifier])

            let content = UNMutableNotificationContent()
            content.title = "时间信件已到打开时间"
            let recipientText = item.timeLetterRecipientNames.isEmpty
                ? "你"
                : item.timeLetterRecipientNames.joined(separator: "、")
            content.body = "你封存给 \(recipientText) 的时间信件可以打开了。"
            content.sound = .default
            content.userInfo = [
                "kind": "timeLetter",
                "deliveryStatus": item.timeLetterDeliveryStatus,
                "accountLeaseIdentity": accountLeaseIdentity,
                "resourceOwnerIdentity": resourceOwnerIdentity,
                "operationIdentity": operationIdentity,
            ]

            let trigger: UNNotificationTrigger
            if openAt <= Date() {
                trigger = UNTimeIntervalNotificationTrigger(timeInterval: 1, repeats: false)
            } else {
                let dateComponents = Calendar.current.dateComponents(
                    [.year, .month, .day, .hour, .minute, .second],
                    from: openAt
                )
                trigger = UNCalendarNotificationTrigger(dateMatching: dateComponents, repeats: false)
            }

            let request = UNNotificationRequest(identifier: identifier, content: content, trigger: trigger)
            guard self.accountLeaseRuntime.validate(accountLease, at: .runtime).allowed else {
                return
            }
            self.requestCenter.add(request) { [weak self] _ in
                guard let self else { return }
                guard self.accountLeaseRuntime.validate(accountLease, at: .timer).allowed,
                      self.accountLeaseRuntime.validate(accountLease, at: .runtime).allowed else {
                    self.requestCenter.removePendingNotificationRequests(withIdentifiers: [identifier])
                    return
                }
            }
        }
    }

    func teardownForAccountLifecycle(
        oldAccountLease: AccountLease?,
        completion: @escaping @Sendable (Bool) -> Void
    ) {
        guard let oldAccountLease else {
            completion(false)
            return
        }
        requestCenter.getPendingNotificationRequests { [weak self] requests in
            guard let self else {
                completion(false)
                return
            }
            let identifiers = requests.compactMap { request in
                self.requestIsOwned(request, byLifecycleLease: oldAccountLease)
                    ? request.identifier
                    : nil
            }
            if !identifiers.isEmpty {
                self.requestCenter.removePendingNotificationRequests(withIdentifiers: identifiers)
            }
            self.requestCenter.getPendingNotificationRequests { [weak self] remaining in
                guard let self else {
                    completion(false)
                    return
                }
                completion(
                    !remaining.contains {
                        self.requestIsOwned($0, byLifecycleLease: oldAccountLease)
                    }
                )
            }
        }
    }

    private static func notificationIdentifier(
        itemId: String,
        resourceOwnerId: String,
        accountLease: AccountLease
    ) -> String {
        let digest = identityDigest([
            "time-letter-notification-v2",
            accountLease.subjectId,
            accountLease.vaultId,
            String(accountLease.generation),
            accountLease.generationId.uuidString,
            accountLease.authorityEpoch,
            resourceOwnerId,
            itemId,
        ])
        return "dj.timeLetter.reminder.\(digest)"
    }

    private static func accountLeaseIdentity(for accountLease: AccountLease) -> String {
        identityDigest([
            "account-lease",
            accountLease.subjectId,
            accountLease.vaultId,
            String(accountLease.generation),
            accountLease.generationId.uuidString,
            accountLease.authorityEpoch,
        ])
    }

    private func requestIsOwned(
        _ request: UNNotificationRequest,
        byLifecycleLease accountLease: AccountLease
    ) -> Bool {
        let userInfo = request.content.userInfo
        guard request.identifier.hasPrefix("dj.timeLetter.reminder."),
              userInfo["kind"] as? String == "timeLetter",
              userInfo["accountLeaseIdentity"] as? String == Self.accountLeaseIdentity(for: accountLease),
              let resourceOwnerIdentity = userInfo["resourceOwnerIdentity"] as? String,
              !resourceOwnerIdentity.isEmpty,
              let operationIdentity = userInfo["operationIdentity"] as? String,
              !operationIdentity.isEmpty else {
            return false
        }
        return true
    }

    private static func identityDigest(_ values: [String]) -> String {
        let canonical = values
            .map { "\($0.utf8.count):\($0)" }
            .joined(separator: "|")
        return ArchiveLocalStoragePolicy.sha256(canonical)
            .replacingOccurrences(of: "sha256:", with: "")
    }
}

private extension MemoryArchiveItem {
    var isAvailableForArchiveContext: Bool {
        guard !isTimeLetterDraft else { return false }
        guard let contextText = echoContextText,
              !contextText.isEmpty else {
            return false
        }
        switch analysisStatus {
        case .analyzed, .manual:
            return true
        case .pending:
            switch kind {
            case .audio:
                return true
            case .video:
                return true
            case .timeLetter:
                return false
            case .photo, .text:
                return false
            }
        case .analyzing:
            return false
        case .failed:
            return true
        case .retryable:
            return true
        }
    }

    var archiveContextEntry: MemoryArchiveContextEntry {
        let contextText = echoContextText ?? ""
        let normalizedNote = MemoryArchiveItem.normalizedArchiveText(note)
        let allowsContextClues = echoContextAllowsClues
        let contextNote: String?
        if kind == .audio && metadataTranscriptTextForDisplay != nil {
            contextNote = nil
        } else {
            contextNote = normalizedNote.isEmpty ? nil : normalizedNote
        }

        return MemoryArchiveContextEntry(
            id: id,
            title: MemoryArchiveItem.normalizedArchiveText(title),
            kindLabel: kind.archiveDisplayName,
            summary: contextText,
            note: contextNote,
            people: allowsContextClues ? detectedPeople : [],
            locations: allowsContextClues ? detectedLocationClues : [],
            scenes: allowsContextClues ? detectedSceneClues : [],
            tags: allowsContextClues ? tags : [],
            createdAt: createdAt
        )
    }

    static func normalizedContextText(_ text: String) -> String {
        MemoryArchiveItem.normalizedArchiveText(text)
    }
}

private extension MemoryArchiveAnalysisStatus {
    var allowsArchiveContextClues: Bool {
        switch self {
        case .analyzed, .manual:
            return true
        case .pending:
            return false
        case .analyzing:
            return false
        case .failed:
            return false
        case .retryable:
            return false
        }
    }
}
