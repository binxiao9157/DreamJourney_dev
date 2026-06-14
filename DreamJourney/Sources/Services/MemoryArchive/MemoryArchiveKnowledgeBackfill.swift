import Foundation

extension KBLiteArchiveBackfillMaterial {
    init(item: MemoryArchiveItem) {
        self.init(
            id: item.id,
            kind: KBLiteArchiveBackfillMaterial.Kind(itemKind: item.kind),
            title: item.title,
            note: item.note,
            createdAt: item.createdAt,
            analysisStatusRawValue: item.analysisStatus.rawValue,
            analysisSummary: item.analysisSummary,
            detectedPeople: item.detectedPeople,
            scene: item.scene,
            occasion: item.occasion,
            mood: item.mood,
            estimatedDecade: item.estimatedDecade,
            privacyMetadata: item.privacyMetadata,
            targetPersonName: item.targetPersonName,
            targetPersonId: item.targetPersonId
        )
    }
}

extension KBLiteManager {
    @discardableResult
    func backfillRestoredArchiveItemKnowledge(
        _ item: MemoryArchiveItem,
        sessionId: Int? = nil
    ) -> Int {
        backfillRestoredArchiveMaterialKnowledge(
            KBLiteArchiveBackfillMaterial(item: item),
            sessionId: sessionId
        )
    }
}

private extension KBLiteArchiveBackfillMaterial.Kind {
    init(itemKind: MemoryArchiveItemKind) {
        switch itemKind {
        case .photo:
            self = .photo
        case .screenshot:
            self = .screenshot
        case .voiceSample:
            self = .voiceSample
        case .textNote:
            self = .textNote
        case .personalityNote:
            self = .personalityNote
        case .catchphrase:
            self = .catchphrase
        }
    }
}
