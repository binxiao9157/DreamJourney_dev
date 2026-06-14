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
        let screenshotCount = all.filter { $0.kind == .screenshot }.count
        let voiceSampleCount = all.filter { $0.kind == .voiceSample }.count
        let analyzedPhotoCount = all.filter {
            ($0.kind == .photo || $0.kind == .screenshot) && $0.analysisStatus == .analyzed
        }.count
        return MemoryArchiveSummary(
            totalCount: all.count,
            photoCount: photoCount,
            screenshotCount: screenshotCount,
            voiceSampleCount: voiceSampleCount,
            textCount: all.count - photoCount - screenshotCount - voiceSampleCount,
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
        guard kind != .photo, kind != .screenshot, kind != .voiceSample, !cleanNote.isEmpty else {
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
        targetPersonId: String? = nil,
        targetPersonName: String? = nil,
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
            privacyMetadata: resolvedPrivacyMetadata,
            targetPersonId: Self.cleanedOptional(targetPersonId),
            targetPersonName: Self.cleanedOptional(targetPersonName),
            voiceProfileId: nil
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
        try addImageMaterial(
            kind: .photo,
            localPath: localPath,
            title: title,
            note: note,
            tags: tags,
            defaultTitle: "旧照片",
            defaultNote: "",
            isPrivate: isPrivate,
            privacyMetadata: privacyMetadata,
            now: now
        )
    }

    @discardableResult
    func addScreenshot(
        localPath: String,
        title: String,
        note: String = "",
        tags: [String] = [],
        isPrivate: Bool = true,
        privacyMetadata: MemoryPrivacyMetadata? = nil,
        now: Date = Date()
    ) throws -> MemoryArchiveItem {
        try addImageMaterial(
            kind: .screenshot,
            localPath: localPath,
            title: title,
            note: note,
            tags: tags,
            defaultTitle: "聊天截图",
            defaultNote: "从相册加入的聊天记录或语音截图素材",
            isPrivate: isPrivate,
            privacyMetadata: privacyMetadata,
            now: now
        )
    }

    private func addImageMaterial(
        kind: MemoryArchiveItemKind,
        localPath: String,
        title: String,
        note: String,
        tags: [String],
        defaultTitle: String,
        defaultNote: String,
        isPrivate: Bool,
        privacyMetadata: MemoryPrivacyMetadata?,
        now: Date
    ) throws -> MemoryArchiveItem {
        let cleanPath = localPath.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleanPath.isEmpty else { throw MemoryArchiveRepositoryError.invalidPhotoPath }

        let cleanTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        let cleanNote = note.trimmingCharacters(in: .whitespacesAndNewlines)
        let resolvedPrivacyMetadata = privacyMetadata
            ?? MemoryPrivacyMetadata(scope: MemoryPrivacyMigration.scopeFromLegacy(isPrivate: isPrivate))
        let resolvedIsPrivate = resolvedPrivacyMetadata.scope == .privateOnly
        let shouldAnalyze = PrivacyScopePolicy.canUse(
            metadata: resolvedPrivacyMetadata,
            surface: .remoteExtraction
        )
        let item = MemoryArchiveItem(
            id: UUID().uuidString,
            kind: kind,
            title: cleanTitle.isEmpty ? defaultTitle : cleanTitle,
            note: cleanNote.isEmpty ? defaultNote : cleanNote,
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

    @discardableResult
    func attachVoiceProfile(id: String, voiceProfileId: String, now: Date = Date()) throws -> MemoryArchiveItem {
        let cleanProfileId = voiceProfileId.trimmingCharacters(in: .whitespacesAndNewlines)
        return try mutate(id: id) { item in
            item.voiceProfileId = cleanProfileId.isEmpty ? nil : cleanProfileId
            item.updatedAt = now
        }
    }

    @discardableResult
    func attachTargetPerson(id: String, targetPersonId: String?, now: Date = Date()) throws -> MemoryArchiveItem {
        let cleanTargetPersonId = Self.cleanedOptional(targetPersonId)
        return try mutate(id: id) { item in
            item.targetPersonId = cleanTargetPersonId
            item.updatedAt = now
        }
    }

    @discardableResult
    func updateVoiceTranscript(id: String, transcript: String, now: Date = Date()) throws -> MemoryArchiveItem {
        let cleanTranscript = transcript.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleanTranscript.isEmpty else { throw MemoryArchiveRepositoryError.invalidText }
        guard load().contains(where: { $0.id == id && $0.kind == .voiceSample }) else {
            throw MemoryArchiveRepositoryError.invalidVoicePath
        }
        return try mutate(id: id) { item in
            item.note = Self.voiceSampleNote(from: cleanTranscript)
            item.tags = Self.cleanTags(item.tags + ["语音转写"])
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

    @discardableResult
    func mergeRemoteItems(_ remoteItems: [MemoryArchiveItem]) -> Int {
        var all = load()
        var changedCount = 0

        for remoteItem in remoteItems {
            guard PrivacyScopePolicy.canUse(metadata: remoteItem.privacyMetadata, surface: .backendSync) else {
                continue
            }

            if let index = all.firstIndex(where: { $0.id == remoteItem.id }) {
                let existing = all[index]
                guard remoteItem.updatedAt >= existing.updatedAt else { continue }
                all[index] = Self.mergedRemoteItem(remoteItem, preservingLocalStateFrom: existing)
                changedCount += 1
            } else {
                all.append(Self.remoteVisibleItem(remoteItem))
                changedCount += 1
            }
        }

        if changedCount > 0 {
            save(all)
        }
        return changedCount
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

    private static func cleanedOptional(_ value: String?) -> String? {
        guard let value else { return nil }
        let cleaned = value.trimmingCharacters(in: .whitespacesAndNewlines)
        return cleaned.isEmpty ? nil : cleaned
    }

    private static func defaultTitle(for kind: MemoryArchiveItemKind) -> String {
        switch kind {
        case .photo: return "旧照片"
        case .screenshot: return "聊天截图"
        case .voiceSample: return "语音样本"
        case .textNote: return "文字回忆"
        case .personalityNote: return "性格描述"
        case .catchphrase: return "口头禅"
        }
    }

    private static func voiceSampleNote(from transcript: String) -> String {
        "导入的长辈语音样本，用于后续声纹和语气参考。\n语音转写/摘要：\(transcript)"
    }

    private static func mergedRemoteItem(
        _ remoteItem: MemoryArchiveItem,
        preservingLocalStateFrom existing: MemoryArchiveItem
    ) -> MemoryArchiveItem {
        var item = remoteVisibleItem(remoteItem)
        item.localPath = existing.localPath
        item.voiceProfileId = existing.voiceProfileId
        if item.targetPersonId == nil {
            item.targetPersonId = existing.targetPersonId
        }
        if item.targetPersonName == nil {
            item.targetPersonName = existing.targetPersonName
        }
        return item
    }

    private static func remoteVisibleItem(_ remoteItem: MemoryArchiveItem) -> MemoryArchiveItem {
        var item = remoteItem
        item.localPath = nil
        item.voiceProfileId = nil
        item.tags = cleanTags(item.tags)
        return item
    }

    private static let legacyRoadshowTextSeedFingerprints: Set<String> = [
        "外滩合影的背景\n1975 年 7 月，陈树安和陈静文在外滩拍过一张全家合影。",
        "陈树安的习惯\n说话慢，喜欢先听完别人讲完再回答。",
        "慢慢来，饭要趁热吃\n家人记得的一句口头禅，用于记忆整理，不用于冒充真实逝者。"
    ]

    private static func isLegacySeedItem(_ item: MemoryArchiveItem) -> Bool {
        if item.id.hasPrefix("roadshow_") ||
            item.localPath == "roadshow_demo_photo_placeholder" {
            return true
        }

        guard item.tags.contains("路演") else { return false }
        let fingerprint = "\(item.title)\n\(item.note)"
        return legacyRoadshowTextSeedFingerprints.contains(fingerprint)
    }
}
