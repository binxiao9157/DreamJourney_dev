import Foundation

struct MemoryArchiveContextEntry {
    let id: String
    let title: String
    let kindLabel: String
    let summary: String
    let note: String?
    let people: [String]
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

private struct ArchiveVisibilityContext {
    let ownerId: String
    let personaScope: String
    let digitalHumanId: String
}

final class MemoryArchiveRepository {
    static let shared = MemoryArchiveRepository()

    private let baseKey = "dj.memoryArchive.items"
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
        let items = assignOwnerIfNeededForCurrentUser(decodedItems)
        if needsOwnerMigration {
            save(items)
        }
        return items.sorted { $0.createdAt > $1.createdAt }
    }

    func add(_ item: MemoryArchiveItem, syncToBackend shouldSyncToBackend: Bool = true) {
        let ownedItem = item.assigningOwnerIfNeeded(currentUserId)
        var items = allItems()
        items.insert(ownedItem, at: 0)
        save(items)
        if shouldSyncToBackend {
            syncToBackend(ownedItem)
        }
    }

    @discardableResult
    func update(_ item: MemoryArchiveItem, syncToBackend shouldSyncToBackend: Bool = true) -> Bool {
        let ownedItem = item.assigningOwnerIfNeeded(currentUserId)
        var items = allItems()
        guard let index = items.firstIndex(where: { $0.id == ownedItem.id }) else {
            return false
        }
        items[index] = ownedItem
        save(items)
        if shouldSyncToBackend {
            syncToBackend(ownedItem)
        }
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

    private func save(_ items: [MemoryArchiveItem]) {
        let sortedItems = items.sorted { $0.createdAt > $1.createdAt }
        if let data = try? JSONEncoder().encode(sortedItems) {
            UserDefaults.standard.set(data, forKey: storageKey)
        }
    }

    private func syncToBackend(_ item: MemoryArchiveItem) {
        let archiveVisibilityContext = currentArchiveVisibilityContext
        let ownerId = archiveVisibilityContext.ownerId
        let payload: [String: Any] = [
            "userId": ownerId,
            "viewerUserId": currentUserId,
            "ownerId": ownerId,
            "id": item.id,
            "ownerUserId": item.ownerUserId,
            "kind": item.kind.rawValue,
            "title": item.title,
            "note": item.note,
            "createdAt": isoFormatter.string(from: item.createdAt),
            "updatedAt": isoFormatter.string(from: item.updatedAt),
            "analysisStatus": item.analysisStatus.rawValue,
            "tags": item.tags,
            "detectedPeople": item.detectedPeople,
            "metadata": item.metadata,
        ]
        DreamJourneyBackendClient.shared.postArchiveItem(
            payload,
            personaScope: archiveVisibilityContext.personaScope,
            digitalHumanId: archiveVisibilityContext.digitalHumanId
        ) { result in
            if case .failure(let error) = result {
                print("[Archive] backend sync failed: \(error.localizedDescription)")
            }
        }
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

private extension MemoryArchiveItem {
    var isAvailableForArchiveContext: Bool {
        switch analysisStatus {
        case .analyzed, .manual:
            return true
        case .pending, .failed:
            return false
        }
    }

    var archiveContextEntry: MemoryArchiveContextEntry {
        let normalizedNote = Self.normalizedContextText(note)
        let normalizedSummary = Self.normalizedContextText(analysisSummary ?? note)

        return MemoryArchiveContextEntry(
            id: id,
            title: Self.normalizedContextText(title),
            kindLabel: kind.archiveDisplayName,
            summary: normalizedSummary,
            note: normalizedNote.isEmpty ? nil : normalizedNote,
            people: detectedPeople,
            tags: tags,
            createdAt: createdAt
        )
    }

    static func normalizedContextText(_ text: String) -> String {
        text
            .split(whereSeparator: \.isWhitespace)
            .joined(separator: " ")
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
