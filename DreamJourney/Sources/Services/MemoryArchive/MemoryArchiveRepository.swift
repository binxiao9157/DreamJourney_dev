import Foundation

enum MemoryArchiveRepositoryError: Error, Equatable {
    case invalidText
    case invalidPhotoPath
    case invalidVoicePath
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
        let voiceSampleCount = all.filter { $0.kind == .voiceSample }.count
        let analyzedPhotoCount = all.filter {
            $0.kind == .photo && $0.analysisStatus == .analyzed
        }.count
        return MemoryArchiveSummary(
            totalCount: all.count,
            photoCount: photoCount,
            voiceSampleCount: voiceSampleCount,
            textCount: all.count - photoCount - voiceSampleCount,
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
        privacyMetadata: MemoryPrivacyMetadata? = nil,
        now: Date = Date()
    ) throws -> MemoryArchiveItem {
        let cleanTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        let cleanNote = note.trimmingCharacters(in: .whitespacesAndNewlines)
        guard kind != .photo, kind != .voiceSample, !cleanNote.isEmpty else {
            throw MemoryArchiveRepositoryError.invalidText
        }
        let resolvedPrivacyMetadata = privacyMetadata
            ?? MemoryPrivacyMetadata(scope: MemoryPrivacyMigration.scopeFromLegacy(isPrivate: isPrivate))
        let resolvedIsPrivate = resolvedPrivacyMetadata.scope == .privateOnly

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
            isPrivate: resolvedIsPrivate,
            privacyMetadata: resolvedPrivacyMetadata
        )

        var all = load()
        all.insert(item, at: 0)
        save(all)
        return item
    }

    @discardableResult
    func addVoiceSample(
        localPath: String,
        title: String,
        note: String = "",
        tags: [String] = [],
        isPrivate: Bool = true,
        privacyMetadata: MemoryPrivacyMetadata? = nil,
        now: Date = Date()
    ) throws -> MemoryArchiveItem {
        let cleanPath = localPath.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleanPath.isEmpty else { throw MemoryArchiveRepositoryError.invalidVoicePath }

        let cleanTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        let cleanNote = note.trimmingCharacters(in: .whitespacesAndNewlines)
        let resolvedPrivacyMetadata = privacyMetadata
            ?? MemoryPrivacyMetadata(scope: MemoryPrivacyMigration.scopeFromLegacy(isPrivate: isPrivate))
        let resolvedIsPrivate = resolvedPrivacyMetadata.scope == .privateOnly

        let item = MemoryArchiveItem(
            id: UUID().uuidString,
            kind: .voiceSample,
            title: cleanTitle.isEmpty ? "语音样本" : cleanTitle,
            note: cleanNote.isEmpty ? "导入的长辈语音样本，用于后续声纹和语气参考。" : cleanNote,
            localPath: cleanPath,
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
            isPrivate: resolvedIsPrivate,
            privacyMetadata: resolvedPrivacyMetadata
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
        privacyMetadata: MemoryPrivacyMetadata? = nil,
        now: Date = Date()
    ) throws -> MemoryArchiveItem {
        let cleanPath = localPath.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleanPath.isEmpty else { throw MemoryArchiveRepositoryError.invalidPhotoPath }

        let cleanTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        let resolvedPrivacyMetadata = privacyMetadata
            ?? MemoryPrivacyMetadata(scope: MemoryPrivacyMigration.scopeFromLegacy(isPrivate: isPrivate))
        let resolvedIsPrivate = resolvedPrivacyMetadata.scope == .privateOnly
        let shouldAnalyze = PrivacyScopePolicy.canUse(
            metadata: resolvedPrivacyMetadata,
            surface: .remoteExtraction
        )
        let item = MemoryArchiveItem(
            id: UUID().uuidString,
            kind: .photo,
            title: cleanTitle.isEmpty ? "旧照片" : cleanTitle,
            note: note.trimmingCharacters(in: .whitespacesAndNewlines),
            localPath: cleanPath,
            createdAt: now,
            updatedAt: now,
            analysisStatus: shouldAnalyze ? .pending : .manual,
            analysisSummary: nil,
            detectedPeople: [],
            scene: nil,
            occasion: nil,
            mood: nil,
            estimatedDecade: nil,
            tags: Self.cleanTags(tags),
            isPrivate: resolvedIsPrivate,
            privacyMetadata: resolvedPrivacyMetadata
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
        guard let decoded = try? decoder.decode([MemoryArchiveItem].self, from: data) else { return [] }
        let cleaned = decoded.filter { !Self.isLegacySeedItem($0) }
        if cleaned.count != decoded.count {
            save(cleaned)
        }
        return cleaned
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
        case .voiceSample: return "语音样本"
        case .textNote: return "文字回忆"
        case .personalityNote: return "性格描述"
        case .catchphrase: return "口头禅"
        }
    }

    private static func isLegacySeedItem(_ item: MemoryArchiveItem) -> Bool {
        item.id.hasPrefix("roadshow_") ||
            item.localPath == "roadshow_demo_photo_placeholder" ||
            item.tags.contains("路演") ||
            item.note.contains("路演占位") ||
            item.note.contains("1975 年 7 月，陈树安和陈静文") ||
            item.title == "外滩合影的背景" ||
            item.title == "陈树安的习惯" ||
            item.title == "慢慢来，饭要趁热吃" ||
            item.title == "外滩老照片"
    }
}
