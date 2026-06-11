import Foundation

enum MemoryArchiveRepositoryError: Error, Equatable {
    case invalidText
    case invalidPhotoPath
    case itemNotFound
}

final class MemoryArchiveRepository {
    static let shared = MemoryArchiveRepository()

    private let defaults: UserDefaults
    private let storageKey: String
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()

    init(
        defaults: UserDefaults = .standard,
        storageKey: String = "dreamjourney.memoryArchive.items"
    ) {
        self.defaults = defaults
        self.storageKey = storageKey
        encoder.dateEncodingStrategy = .iso8601
        decoder.dateDecodingStrategy = .iso8601
    }

    func items() -> [MemoryArchiveItem] {
        load().sorted { lhs, rhs in
            if lhs.updatedAt == rhs.updatedAt {
                return lhs.createdAt > rhs.createdAt
            }
            return lhs.updatedAt > rhs.updatedAt
        }
    }

    func summary() -> MemoryArchiveSummary {
        let all = load()
        let photoCount = all.filter { $0.kind == .photo }.count
        let analyzedPhotoCount = all.filter {
            $0.kind == .photo && $0.analysisStatus == .analyzed
        }.count
        return MemoryArchiveSummary(
            totalCount: all.count,
            photoCount: photoCount,
            textCount: all.count - photoCount,
            analyzedPhotoCount: analyzedPhotoCount
        )
    }

    @discardableResult
    func addText(
        kind: MemoryArchiveItemKind,
        title: String,
        note: String,
        tags: [String] = [],
        isPrivate: Bool = true,
        now: Date = Date()
    ) throws -> MemoryArchiveItem {
        let cleanTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        let cleanNote = note.trimmingCharacters(in: .whitespacesAndNewlines)
        guard kind != .photo, !cleanNote.isEmpty else {
            throw MemoryArchiveRepositoryError.invalidText
        }

        let item = MemoryArchiveItem(
            id: UUID().uuidString,
            kind: kind,
            title: cleanTitle.isEmpty ? Self.defaultTitle(for: kind) : cleanTitle,
            note: cleanNote,
            localPath: nil,
            createdAt: now,
            updatedAt: now,
            analysisStatus: .manual,
            analysisSummary: nil,
            detectedPeople: [],
            scene: nil,
            occasion: nil,
            mood: nil,
            estimatedDecade: nil,
            tags: Self.cleanTags(tags),
            isPrivate: isPrivate
        )

        var all = load()
        all.insert(item, at: 0)
        save(all)
        return item
    }

    @discardableResult
    func addPhoto(
        localPath: String,
        title: String,
        note: String = "",
        tags: [String] = [],
        isPrivate: Bool = true,
        now: Date = Date()
    ) throws -> MemoryArchiveItem {
        let cleanPath = localPath.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleanPath.isEmpty else { throw MemoryArchiveRepositoryError.invalidPhotoPath }

        let cleanTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        let item = MemoryArchiveItem(
            id: UUID().uuidString,
            kind: .photo,
            title: cleanTitle.isEmpty ? "旧照片" : cleanTitle,
            note: note.trimmingCharacters(in: .whitespacesAndNewlines),
            localPath: cleanPath,
            createdAt: now,
            updatedAt: now,
            analysisStatus: isPrivate ? .manual : .pending,
            analysisSummary: nil,
            detectedPeople: [],
            scene: nil,
            occasion: nil,
            mood: nil,
            estimatedDecade: nil,
            tags: Self.cleanTags(tags),
            isPrivate: isPrivate
        )

        var all = load()
        all.insert(item, at: 0)
        save(all)
        return item
    }

    @discardableResult
    func applyImageAnalysis(
        id: String,
        analysis: MemoryArchiveImageAnalysis,
        now: Date = Date()
    ) throws -> MemoryArchiveItem {
        try mutate(id: id) { item in
            item.analysisStatus = .analyzed
            item.analysisSummary = analysis.summary
            item.detectedPeople = analysis.detectedPeople
            item.scene = analysis.scene
            item.occasion = analysis.occasion
            item.mood = analysis.mood
            item.estimatedDecade = analysis.estimatedDecade
            item.updatedAt = now
        }
    }

    @discardableResult
    func markAnalysisFailed(id: String, now: Date = Date()) throws -> MemoryArchiveItem {
        try mutate(id: id) { item in
            item.analysisStatus = .failed
            item.updatedAt = now
        }
    }

    func delete(id: String) throws {
        var all = load()
        guard let index = all.firstIndex(where: { $0.id == id }) else {
            throw MemoryArchiveRepositoryError.itemNotFound
        }
        all.remove(at: index)
        save(all)
    }

    private func mutate(
        id: String,
        update: (inout MemoryArchiveItem) -> Void
    ) throws -> MemoryArchiveItem {
        var all = load()
        guard let index = all.firstIndex(where: { $0.id == id }) else {
            throw MemoryArchiveRepositoryError.itemNotFound
        }
        update(&all[index])
        let item = all[index]
        save(all)
        return item
    }

    private func load() -> [MemoryArchiveItem] {
        guard let data = defaults.data(forKey: storageKey) else { return [] }
        return (try? decoder.decode([MemoryArchiveItem].self, from: data)) ?? []
    }

    private func save(_ items: [MemoryArchiveItem]) {
        guard let data = try? encoder.encode(items) else { return }
        defaults.set(data, forKey: storageKey)
    }

    private static func cleanTags(_ tags: [String]) -> [String] {
        Array(Set(tags.map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }.filter { !$0.isEmpty }))
            .sorted()
    }

    private static func defaultTitle(for kind: MemoryArchiveItemKind) -> String {
        switch kind {
        case .photo: return "旧照片"
        case .textNote: return "文字回忆"
        case .personalityNote: return "性格描述"
        case .catchphrase: return "口头禅"
        }
    }
}
