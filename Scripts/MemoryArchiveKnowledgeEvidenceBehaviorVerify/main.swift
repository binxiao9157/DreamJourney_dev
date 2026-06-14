import Foundation

private func require(_ condition: @autoclosure () -> Bool, _ message: String) {
    guard condition() else {
        fputs("MemoryArchiveKnowledgeEvidenceBehavior verification failed: \(message)\n", stderr)
        exit(1)
    }
}

let now = Date(timeIntervalSince1970: 1_800_777_001)

func makeArchiveItem(id: String, title: String) -> MemoryArchiveItem {
    MemoryArchiveItem(
        id: id,
        kind: .photo,
        title: title,
        note: "",
        localPath: "/tmp/\(id).jpg",
        createdAt: now,
        updatedAt: now,
        analysisStatus: .pending,
        analysisSummary: nil,
        detectedPeople: [],
        scene: nil,
        occasion: nil,
        mood: nil,
        estimatedDecade: nil,
        tags: [],
        isPrivate: false,
        privacyMetadata: MemoryPrivacyMetadata(scope: .generationAllowed)
    )
}

func archiveMetadata(id: String, title: String) -> MemoryPrivacyMetadata {
    MemoryPrivacyMetadata(
        scope: .generationAllowed,
        sourceRefs: [
            MemorySourceRef(kind: .memoryArchiveItem, id: id, title: title, capturedAt: now)
        ],
        createdBySurface: .memoirGeneration,
        createdAt: now
    )
}

let metadataOnlyItem = makeArchiveItem(id: "archive-metadata-only", title: "未分析照片")
let structuredItem = makeArchiveItem(id: "archive-structured", title: "西湖合影")

let graph = KBLiteGraph(
    lastUpdated: now,
    sessionCount: 1,
    places: [
        KBPlace(
            id: "place-1",
            name: "杭州西湖",
            category: "visited",
            sourceSessionIds: [1],
            createdAt: now,
            privacyMetadata: archiveMetadata(id: structuredItem.id, title: structuredItem.title)
        )
    ],
    facts: [
        KBFact(
            id: "metadata-only-fact",
            statement: "记忆档案馆保存照片素材《未分析照片》。",
            confidence: "confirmed",
            sourceSessionIds: [1],
            createdAt: now,
            privacyMetadata: archiveMetadata(id: metadataOnlyItem.id, title: metadataOnlyItem.title)
        ),
        KBFact(
            id: "structured-fact",
            statement: "记忆档案馆照片《西湖合影》分析摘要：一家人在西湖边合影（人物：林桂芳；年代：1970年代）。",
            confidence: "confirmed",
            sourceSessionIds: [1],
            createdAt: now,
            privacyMetadata: archiveMetadata(id: structuredItem.id, title: structuredItem.title)
        )
    ]
)

let metadataOnlyEvidence = MemoryArchiveKnowledgeEvidenceBuilder.build(for: metadataOnlyItem, in: graph)
require(metadataOnlyEvidence.totalCount == 0, "metadata-only archive source fact should not be shown as structured evidence")

let structuredEvidence = MemoryArchiveKnowledgeEvidenceBuilder.build(for: structuredItem, in: graph)
require(structuredEvidence.places == ["杭州西湖"], "structured archive evidence should include matching places")
require(structuredEvidence.facts.count == 1, "structured archive evidence should include analysis facts")
require(
    structuredEvidence.facts.allSatisfy { !$0.hasPrefix("记忆档案馆保存") },
    "structured archive evidence should exclude save-only metadata facts"
)

print("MemoryArchiveKnowledgeEvidenceBehavior verification passed")
