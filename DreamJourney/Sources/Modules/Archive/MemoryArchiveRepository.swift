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

private struct InAppMessageLocalState: Codable {
    let status: InAppMessageStatus
    let readAt: String?
    let archivedAt: String?
}

final class MemoryArchiveRepository {
    static let shared = MemoryArchiveRepository()

    private let baseKey = "dj.memoryArchive.items"
    private let mailboxBaseKey = "dj.memoryArchive.timeLetterMailbox"
    private let inAppMessageStateBaseKey = "dj.inAppMessage.localState"
    private let isoFormatter = ISO8601DateFormatter()
    private static let personalPersonaScope = "personal"
    private static let familyPersonaScope = "family"
    private static let defaultFamilyDigitalHumanId = "family_default"

    private init() {}

    func allItems() -> [MemoryArchiveItem] {
        guard let data = UserDefaults.standard.data(forKey: storageKey),
              let decodedItems = try? JSONDecoder().decode([MemoryArchiveItem].self, from: data) else {
            return []
        }
        let needsOwnerMigration = decodedItems.contains { item in
            item.ownerUserId == MemoryArchiveItem.legacyOwnerUserId
                || item.ownerUserId.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        }
        let ownedItems = assignOwnerIfNeededForCurrentUser(decodedItems)
        let items = ownedItems.map { $0.updatingRecoveredLocalPathIfNeeded() }
        let needsLocalPathRecovery = zip(ownedItems, items).contains { original, recovered in
            original.localPath != recovered.localPath || original.metadata != recovered.metadata
        }
        if needsOwnerMigration || needsLocalPathRecovery {
            save(items)
        }
        return items.sorted { $0.createdAt > $1.createdAt }
    }

    func add(_ item: MemoryArchiveItem, syncToBackend shouldSyncToBackend: Bool = true) {
        let ownedItem = item.assigningOwnerIfNeeded(currentUserId)
        let shouldAttemptBackendSync = shouldSyncToBackend
            && ownedItem.isPublicBackendSyncEligible
            && DreamJourneyBackendClient.shared.isArchiveSyncConfigured
        let itemForStorage = shouldAttemptBackendSync
            ? ownedItem.updatingBackendSyncState(.pending)
            : ownedItem
        var items = allItems()
        items.insert(itemForStorage, at: 0)
        save(items)
        scheduleTimeLetterReminderIfNeeded(itemForStorage)
        if shouldSyncToBackend {
            syncToBackend(itemForStorage)
        }
    }

    @discardableResult
    func update(_ item: MemoryArchiveItem, syncToBackend shouldSyncToBackend: Bool = true) -> Bool {
        let ownedItem = item.assigningOwnerIfNeeded(currentUserId)
        let shouldAttemptBackendSync = shouldSyncToBackend
            && ownedItem.isPublicBackendSyncEligible
            && DreamJourneyBackendClient.shared.isArchiveSyncConfigured
        let itemForStorage = shouldAttemptBackendSync
            ? ownedItem.updatingBackendSyncState(.pending)
            : ownedItem
        var items = allItems()
        guard let index = items.firstIndex(where: { $0.id == itemForStorage.id }) else {
            return false
        }
        items[index] = itemForStorage
        save(items)
        scheduleTimeLetterReminderIfNeeded(itemForStorage)
        if shouldSyncToBackend {
            syncToBackend(itemForStorage)
        }
        return true
    }

    func syncPendingPublicArchiveItemsToBackend() {
        guard DreamJourneyBackendClient.shared.isArchiveSyncConfigured else {
            return
        }

        var items = allItems()
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
            save(items)
        }
        retryItems.forEach(syncToBackend)
    }

    func archiveMediaUploadIntentPayload(for item: MemoryArchiveItem) -> [String: Any]? {
        guard item.isMediaUploadIntentEligible,
              let fileName = item.mediaUploadFileName,
              let contentType = item.mediaUploadContentType,
              let fileSizeBytes = item.mediaUploadFileSizeBytes else {
            return nil
        }

        let archiveVisibilityContext = currentArchiveVisibilityContext
        return item.archiveMediaUploadIntentPayload(
            userId: archiveVisibilityContext.ownerId,
            personaScope: archiveVisibilityContext.personaScope,
            digitalHumanId: archiveVisibilityContext.digitalHumanId,
            fileName: fileName,
            contentType: contentType,
            fileSizeBytes: fileSizeBytes
        )
    }

    @discardableResult
    func remove(id: String) -> Bool {
        var items = allItems()
        if items.contains(where: { $0.id == id && $0.isSealedTimeLetter }) {
            return false
        }
        let originalCount = items.count
        items.removeAll { $0.id == id }
        guard items.count != originalCount else {
            return false
        }
        save(items)
        return true
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
        guard let data = UserDefaults.standard.data(forKey: mailboxStorageKey),
              let decoded = try? JSONDecoder().decode([TimeLetterMailboxReminder].self, from: data) else {
            return []
        }
        return decoded
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
        familyInvitationSources: [FamilyInvitationMessageSource] = [],
        careSignalSources: [CareSignalMessageSource] = [],
        systemNoticeSources: [SystemNoticeMessageSource] = []
    ) -> InAppMessageCenterSnapshot {
        let timeLetterMessages = timeLetterMailboxReminders()
            .map(InAppMessage.fromTimeLetterReminder)
        let familyInvitationMessages = familyInvitationSources
            .compactMap(InAppMessage.fromFamilyInvitation)
            .map(applyLocalInAppMessageStateIfNeeded)
        let careSignalMessages = careSignalSources
            .compactMap(InAppMessage.fromCareSignal)
            .map(applyLocalInAppMessageStateIfNeeded)
        let systemNoticeMessages = systemNoticeSources
            .compactMap(InAppMessage.fromSystemNotice)
            .map(applyLocalInAppMessageStateIfNeeded)
        let hiddenCandidates: [InAppMessage] = []
        let visibleMessages = InAppMessageCenterSnapshot.sortedMessages(
            timeLetterMessages + familyInvitationMessages + careSignalMessages + systemNoticeMessages
        )
        let candidateMessages = includeUnavailableCandidates ? hiddenCandidates : []
        return InAppMessageCenterSnapshot(
            messages: visibleMessages,
            hiddenCandidateMessages: candidateMessages
        )
    }

    func timeLetterMailboxReminder(for message: InAppMessage) -> TimeLetterMailboxReminder? {
        guard message.kind == .timeLetter else {
            return nil
        }
        return timeLetterMailboxReminders().first { reminder in
            reminder.id == message.id || reminder.sourceArchiveItemId == message.sourceArchiveItemId
        }
    }

    func markInAppMessageRead(
        _ message: InAppMessage,
        completion: ((Result<InAppMessage, Error>) -> Void)? = nil
    ) {
        guard message.kind == .timeLetter else {
            let updatedMessage = message.markingRead(readAt: isoFormatter.string(from: Date()))
            updateLocalInAppMessageState(updatedMessage)
            completion?(.success(updatedMessage))
            return
        }
        guard message.kind == .timeLetter,
              let reminder = timeLetterMailboxReminder(for: message) else {
            completion?(.failure(NSError(
                domain: "DreamJourney.InAppMessageCenter",
                code: 404,
                userInfo: [NSLocalizedDescriptionKey: "消息暂不可打开"]
            )))
            return
        }
        markTimeLetterMailboxReminderRead(reminder) { result in
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
        guard message.kind == .timeLetter else {
            let updatedMessage = message.markingArchived(archivedAt: isoFormatter.string(from: Date()))
            updateLocalInAppMessageState(updatedMessage)
            completion?(.success(updatedMessage))
            return
        }
        guard message.kind == .timeLetter,
              let reminder = timeLetterMailboxReminder(for: message) else {
            completion?(.failure(NSError(
                domain: "DreamJourney.InAppMessageCenter",
                code: 404,
                userInfo: [NSLocalizedDescriptionKey: "消息暂不可归档"]
            )))
            return
        }
        markTimeLetterMailboxReminderArchived(reminder) { result in
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
        let readAt = isoFormatter.string(from: Date())
        let updatedReminder = reminder.markingRead(readAt: readAt)
        updateCachedTimeLetterMailboxReminder(updatedReminder)

        guard DreamJourneyBackendClient.shared.isTimeLetterDispatchConfigured else {
            completion?(.success(updatedReminder))
            return
        }

        DreamJourneyBackendClient.shared.markMailboxLetterRead(
            userId: currentUserId,
            letterId: reminder.id,
            readAtISO: readAt
        ) { [weak self] result in
            guard let self else { return }
            switch result {
            case .success(let object):
                if let item = Self.timeLetterMailboxReminder(fromReadResponse: object) {
                    updateCachedTimeLetterMailboxReminder(item)
                    completion?(.success(item))
                } else {
                    completion?(.success(updatedReminder))
                }
            case .failure(let error):
                print("[Archive] mark mailbox reminder read failed: \(error.localizedDescription)")
                completion?(.failure(error))
            }
        }
    }

    func markTimeLetterMailboxReminderArchived(
        _ reminder: TimeLetterMailboxReminder,
        completion: ((Result<TimeLetterMailboxReminder, Error>) -> Void)? = nil
    ) {
        let archivedAt = isoFormatter.string(from: Date())
        let updatedReminder = reminder.markingArchived(archivedAt: archivedAt)
        updateCachedTimeLetterMailboxReminder(updatedReminder)

        guard DreamJourneyBackendClient.shared.isTimeLetterDispatchConfigured else {
            completion?(.success(updatedReminder))
            return
        }

        DreamJourneyBackendClient.shared.archiveMailboxLetter(
            userId: currentUserId,
            letterId: reminder.id,
            archivedAtISO: archivedAt
        ) { [weak self] result in
            guard let self else { return }
            switch result {
            case .success(let object):
                if let item = Self.timeLetterMailboxReminder(fromReadResponse: object) {
                    updateCachedTimeLetterMailboxReminder(item)
                    completion?(.success(item))
                } else {
                    completion?(.success(updatedReminder))
                }
            case .failure(let error):
                print("[Archive] archive mailbox reminder failed: \(error.localizedDescription)")
                completion?(.failure(error))
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

        let fetchMailbox: () -> Void = { [weak self] in
            guard let self else { return }
            DreamJourneyBackendClient.shared.listMailboxLetters(userId: currentUserId) { [weak self] result in
                guard let self else { return }
                switch result {
                case .success(let object):
                    let reminders = Self.timeLetterMailboxReminders(from: object)
                    saveTimeLetterMailboxReminders(reminders)
                    completion?(.success(reminders))
                case .failure(let error):
                    print("[Archive] timeLetter mailbox fetch failed: \(error.localizedDescription)")
                    completion?(.failure(error))
                }
            }
        }

        DreamJourneyBackendClient.shared.dispatchDueTimeLetters(limit: 25) { result in
            if case .failure(let error) = result {
                print("[Archive] timeLetter dispatch-due failed: \(error.localizedDescription)")
            }
            fetchMailbox()
        }
    }

    func resolveTimeLetterReminderDetail(
        _ reminder: TimeLetterMailboxReminder,
        completion: @escaping (Result<MemoryArchiveItem, Error>) -> Void
    ) {
        let ownerUserId = reminder.ownerUserId.trimmingCharacters(in: .whitespacesAndNewlines)
        let canFetchRemoteDetail = DreamJourneyBackendClient.shared.isTimeLetterDispatchConfigured && !ownerUserId.isEmpty

        if canFetchRemoteDetail {
            DreamJourneyBackendClient.shared.getTimeLetterDetail(
                ownerUserId: ownerUserId,
                itemId: reminder.sourceArchiveItemId,
                viewerUserId: currentUserId
            ) { [weak self] result in
                guard let self else { return }
                switch result {
                case .success(let object):
                    guard let item = Self.timeLetterDetailItem(from: object) else {
                        completion(.failure(ArchiveRepositoryError.invalidBackendDetail))
                        return
                    }
                    upsertResolvedTimeLetterDetail(item)
                    completion(.success(item))
                case .failure(let error):
                    if let localItem = localTimeLetterDetailItem(for: reminder) {
                        completion(.success(localItem))
                    } else {
                        completion(.failure(error))
                    }
                }
            }
            return
        }

        if let localItem = localTimeLetterDetailItem(for: reminder) {
            completion(.success(localItem))
            return
        }

        completion(.failure(ArchiveRepositoryError.timeLetterDetailUnavailable))
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

        DreamJourneyBackendClient.shared.listArchiveItems(userId: currentArchiveOwnerId) { [weak self] result in
            guard let self else { return }
            switch result {
            case .success(let object):
                let remoteItems = assignOwnerIfNeededForCurrentUser(Self.archiveItems(from: object))
                let mergedItems = mergeRemoteItems(remoteItems)
                save(mergedItems)
                completion?(.success(mergedItems.sorted { $0.createdAt > $1.createdAt }))
            case .failure(let error):
                print("[Archive] backend fetch failed: \(error.localizedDescription)")
                completion?(.failure(error))
            }
        }
    }

    private var currentUserId: String {
        UserManager.shared.currentUser?.id ?? "user_001"
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

    private var storageKey: String {
        "\(baseKey).\(currentArchiveOwnerId)"
    }

    private var mailboxStorageKey: String {
        "\(mailboxBaseKey).\(currentUserId)"
    }

    private var inAppMessageStateStorageKey: String {
        "\(inAppMessageStateBaseKey).\(currentUserId)"
    }

    private func save(_ items: [MemoryArchiveItem]) {
        let sortedItems = items.sorted { $0.createdAt > $1.createdAt }
        if let data = try? JSONEncoder().encode(sortedItems) {
            UserDefaults.standard.set(data, forKey: storageKey)
        }
    }

    private func saveTimeLetterMailboxReminders(_ reminders: [TimeLetterMailboxReminder]) {
        if let data = try? JSONEncoder().encode(reminders) {
            UserDefaults.standard.set(data, forKey: mailboxStorageKey)
        }
    }

    private func localInAppMessageStates() -> [String: InAppMessageLocalState] {
        guard let data = UserDefaults.standard.data(forKey: inAppMessageStateStorageKey),
              let decoded = try? JSONDecoder().decode([String: InAppMessageLocalState].self, from: data) else {
            return [:]
        }
        return decoded
    }

    private func saveLocalInAppMessageStates(_ states: [String: InAppMessageLocalState]) {
        if let data = try? JSONEncoder().encode(states) {
            UserDefaults.standard.set(data, forKey: inAppMessageStateStorageKey)
        }
    }

    private func updateLocalInAppMessageState(_ message: InAppMessage) {
        guard message.kind != .timeLetter else {
            return
        }
        var states = localInAppMessageStates()
        states[message.id] = InAppMessageLocalState(
            status: message.status,
            readAt: message.readAt,
            archivedAt: message.archivedAt
        )
        saveLocalInAppMessageStates(states)
    }

    private func applyLocalInAppMessageStateIfNeeded(_ message: InAppMessage) -> InAppMessage {
        guard message.kind != .timeLetter,
              let state = localInAppMessageStates()[message.id] else {
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

    private func updateCachedTimeLetterMailboxReminder(_ reminder: TimeLetterMailboxReminder) {
        var reminders = timeLetterMailboxReminders()
        if let index = reminders.firstIndex(where: { $0.id == reminder.id }) {
            reminders[index] = reminder
        } else {
            reminders.insert(reminder, at: 0)
        }
        saveTimeLetterMailboxReminders(reminders)
    }

    private func localTimeLetterDetailItem(for reminder: TimeLetterMailboxReminder) -> MemoryArchiveItem? {
        allItems().first { item in
            item.id == reminder.sourceArchiveItemId && item.kind == .timeLetter
        }
    }

    private func upsertResolvedTimeLetterDetail(_ item: MemoryArchiveItem) {
        var items = allItems()
        if let index = items.firstIndex(where: { $0.id == item.id }) {
            items[index] = item
        } else {
            items.insert(item, at: 0)
        }
        save(items)
    }

    private func syncToBackend(_ item: MemoryArchiveItem) {
        guard DreamJourneyBackendClient.shared.isArchiveSyncConfigured else {
            return
        }

        let archiveVisibilityContext = currentArchiveVisibilityContext
        let ownerId = archiveVisibilityContext.ownerId
        let payload = item.archiveBackendPayload(
            userId: ownerId,
            viewerUserId: currentUserId,
            ownerId: ownerId,
            personaScope: archiveVisibilityContext.personaScope,
            digitalHumanId: archiveVisibilityContext.digitalHumanId,
            isoFormatter: isoFormatter
        )
        DreamJourneyBackendClient.shared.postArchiveItem(
            payload
        ) { [weak self] result in
            guard let self else { return }
            switch result {
            case .success:
                markBackendSyncState(item.id, state: .synced)
            case .failure(let error):
                print("[Archive] backend sync failed: \(error.localizedDescription)")
                markBackendSyncState(
                    item.id,
                    state: .failed,
                    error: sanitizeBackendSyncError(error)
                )
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
        error: String? = nil
    ) {
        var items = allItems()
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
        save(items)
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

    private func assignOwnerIfNeededForCurrentUser(_ items: [MemoryArchiveItem]) -> [MemoryArchiveItem] {
        items.map { $0.assigningOwnerIfNeeded(currentUserId) }
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

    private func mergeRemoteItems(_ remoteItems: [MemoryArchiveItem]) -> [MemoryArchiveItem] {
        var itemsById: [String: MemoryArchiveItem] = [:]
        allItems().forEach { localItem in
            guard let existingItem = itemsById[localItem.id] else {
                itemsById[localItem.id] = localItem
                return
            }
            if localItem.updatedAt > existingItem.updatedAt {
                itemsById[localItem.id] = localItem
            }
        }

        remoteItems.forEach { remoteItem in
            guard let localItem = itemsById[remoteItem.id] else {
                itemsById[remoteItem.id] = remoteItem
                return
            }

            var selectedItem = remoteItem.updatedAt >= localItem.updatedAt ? remoteItem : localItem
            if selectedItem.localPath == nil {
                selectedItem.localPath = localItem.localPath
            }
            itemsById[remoteItem.id] = selectedItem
        }

        return itemsById.values.sorted { $0.createdAt > $1.createdAt }
    }
}

private enum ArchiveRepositoryError: LocalizedError {
    case backendNotConfigured
    case invalidBackendDetail
    case timeLetterDetailUnavailable

    var errorDescription: String? {
        switch self {
        case .backendNotConfigured:
            return "后端地址未配置"
        case .invalidBackendDetail:
            return "后端时间信件详情格式异常"
        case .timeLetterDetailUnavailable:
            return "时间信件详情暂不可用"
        }
    }
}

final class TimeLetterReminderScheduler {
    static let shared = TimeLetterReminderScheduler()

    private let notificationCenter = UNUserNotificationCenter.current()

    private init() {}

    func scheduleIfNeeded(_ item: MemoryArchiveItem) {
        guard item.isSealedTimeLetter,
              let openAt = item.timeLetterOpenAt else {
            return
        }
        let identifier = "time-letter-\(item.id)"
        notificationCenter.requestAuthorization(options: [.alert, .badge, .sound]) { [weak self] granted, _ in
            guard granted else { return }
            self?.notificationCenter.removePendingNotificationRequests(withIdentifiers: [identifier])

            let content = UNMutableNotificationContent()
            content.title = "时间信件已到打开时间"
            let recipientText = item.timeLetterRecipientNames.isEmpty
                ? "你"
                : item.timeLetterRecipientNames.joined(separator: "、")
            content.body = "你封存给 \(recipientText) 的时间信件可以打开了。"
            content.sound = .default
            content.userInfo = [
                "archiveItemId": item.id,
                "kind": "timeLetter",
                "deliveryStatus": item.timeLetterDeliveryStatus,
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
            self?.notificationCenter.add(request)
        }
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
