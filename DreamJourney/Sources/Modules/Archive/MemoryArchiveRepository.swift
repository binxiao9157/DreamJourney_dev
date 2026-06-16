import Foundation

final class MemoryArchiveRepository {
    static let shared = MemoryArchiveRepository()

    private let baseKey = "dj.memoryArchive.items"
    private let isoFormatter = ISO8601DateFormatter()

    private init() {}

    func allItems() -> [MemoryArchiveItem] {
        guard let data = UserDefaults.standard.data(forKey: storageKey),
              let items = try? JSONDecoder().decode([MemoryArchiveItem].self, from: data) else {
            return []
        }
        return items.sorted { $0.createdAt > $1.createdAt }
    }

    func add(_ item: MemoryArchiveItem) {
        var items = allItems()
        items.insert(item, at: 0)
        save(items)
        syncToBackend(item)
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

    private var currentUserId: String {
        UserManager.shared.currentUser?.id ?? "user_001"
    }

    private var storageKey: String {
        "\(baseKey).\(currentUserId)"
    }

    private func save(_ items: [MemoryArchiveItem]) {
        let sortedItems = items.sorted { $0.createdAt > $1.createdAt }
        if let data = try? JSONEncoder().encode(sortedItems) {
            UserDefaults.standard.set(data, forKey: storageKey)
        }
    }

    private func syncToBackend(_ item: MemoryArchiveItem) {
        var payload: [String: Any] = [
            "userId": currentUserId,
            "id": item.id,
            "kind": item.kind.rawValue,
            "title": item.title,
            "note": item.note,
            "createdAt": isoFormatter.string(from: item.createdAt),
            "updatedAt": isoFormatter.string(from: item.updatedAt),
            "analysisStatus": item.analysisStatus.rawValue,
            "tags": item.tags,
            "detectedPeople": item.detectedPeople,
        ]
        DreamJourneyBackendClient.shared.postArchiveItem(payload) { result in
            if case .failure(let error) = result {
                print("[Archive] backend sync failed: \(error.localizedDescription)")
            }
        }
    }
}
