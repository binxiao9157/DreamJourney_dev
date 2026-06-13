import Foundation

// MARK: - Stage 1 Memory Facade Models

struct Stage1MailboxMemoryInput {
    let text: String
    let timestamp: Date
    let privacyMetadata: MemoryPrivacyMetadata

    init(
        text: String,
        timestamp: Date = Date(),
        privacyMetadata: MemoryPrivacyMetadata = MemoryPrivacyMetadata(scope: .localOnly)
    ) {
        self.text = text
        self.timestamp = timestamp
        self.privacyMetadata = privacyMetadata
    }

    init(
        _ text: String,
        timestamp: Date = Date(),
        privacyMetadata: MemoryPrivacyMetadata = MemoryPrivacyMetadata(scope: .localOnly)
    ) {
        self.init(text: text, timestamp: timestamp, privacyMetadata: privacyMetadata)
    }
}

#if !MEMORY_PRIVACY_INTEGRATION_VERIFY
struct Stage1ArchiveTextDepositResult {
    let metadataAddedCount: Int
    let extractionSummary: KBLiteExtractionSummary

    var totalAddedCount: Int {
        metadataAddedCount + extractionSummary.totalAddedCount
    }
}

struct Stage1MemoryDashboardSnapshot {
    let stats: String
    let isEmpty: Bool
    let lastUpdated: Date
    let sessionCount: Int
    let peopleCount: Int
    let placesCount: Int
    let eventsCount: Int
    let factsCount: Int
    let topGaps: [KBLiteGapDetector.KnowledgeGap]
    let greetingHint: String
}

// MARK: - Stage 1 Memory Facade

final class Stage1MemoryFacade {

    static let shared = Stage1MemoryFacade()

    private let conversationMemory: ConversationMemoryManager
    private let knowledgeBase: KBLiteManager
    private let gapDetector: KBLiteGapDetector

    private init(
        conversationMemory: ConversationMemoryManager = .shared,
        knowledgeBase: KBLiteManager = .shared,
        gapDetector: KBLiteGapDetector = .shared
    ) {
        self.conversationMemory = conversationMemory
        self.knowledgeBase = knowledgeBase
        self.gapDetector = gapDetector
    }

    func recordUserTurn(_ input: Stage1MailboxMemoryInput) {
        conversationMemory.recordUserTurn(text: input.text, privacyMetadata: input.privacyMetadata)
    }

    func recordUserTurn(_ text: String) {
        recordUserTurn(Stage1MailboxMemoryInput(text))
    }

    func ingestArchiveTextMaterial(
        _ input: Stage1MailboxMemoryInput,
        archiveItemID: String? = nil,
        archiveTitle: String? = nil,
        archiveMaterialKind: String = "文字素材",
        completion: @escaping (Int) -> Void = { _ in }
    ) {
        ingestArchiveTextMaterialDetailed(
            input,
            archiveItemID: archiveItemID,
            archiveTitle: archiveTitle,
            archiveMaterialKind: archiveMaterialKind
        ) { result in
            completion(result.totalAddedCount)
        }
    }

    func ingestArchiveTextMaterialDetailed(
        _ input: Stage1MailboxMemoryInput,
        archiveItemID: String? = nil,
        archiveTitle: String? = nil,
        archiveMaterialKind: String = "文字素材",
        completion: @escaping (Stage1ArchiveTextDepositResult) -> Void = { _ in }
    ) {
        let sourceRef = Self.archiveSourceRef(
            id: archiveItemID,
            title: archiveTitle,
            capturedAt: input.timestamp
        )
        let resolvedInput = input.withSourceRef(sourceRef)

        guard resolvedInput.privacyMetadata.scope != .privateOnly else {
            completion(Stage1ArchiveTextDepositResult(
                metadataAddedCount: 0,
                extractionSummary: .empty
            ))
            return
        }

        let turn = ConversationTurn(
            role: "user",
            text: resolvedInput.text,
            timestamp: resolvedInput.timestamp,
            privacyMetadata: resolvedInput.privacyMetadata
        )
        let knowledgeSessionCount = knowledgeBase.readGraph { $0.sessionCount }
        let sessionId = max(conversationMemory.currentMemory.sessionCount + 1, knowledgeSessionCount + 1)
        let metadataCount = knowledgeBase.ingestArchiveTextMaterialMetadata(
            archiveItemID: sourceRef.id,
            title: sourceRef.title ?? archiveTitle ?? "文字素材",
            note: resolvedInput.text,
            materialKind: archiveMaterialKind,
            capturedAt: input.timestamp,
            sessionId: sessionId,
            privacyMetadata: resolvedInput.privacyMetadata
        )
        knowledgeBase.extractFromTranscriptDetailed(
            turns: [turn],
            sessionId: sessionId,
            completion: { extractionSummary in
                completion(Stage1ArchiveTextDepositResult(
                    metadataAddedCount: metadataCount,
                    extractionSummary: extractionSummary
                ))
            }
        )
    }

    func ingestArchiveVoiceSampleMetadata(
        title: String,
        note: String?,
        archiveItemID: String? = nil,
        timestamp: Date = Date(),
        privacyMetadata: MemoryPrivacyMetadata = MemoryPrivacyMetadata(scope: .localOnly),
        targetPersonName: String? = nil,
        targetPersonId: String? = nil,
        completion: @escaping (Int) -> Void = { _ in }
    ) {
        let resolvedMetadata = privacyMetadata.appendingSourceRef(
            Self.archiveSourceRef(id: archiveItemID, title: title, capturedAt: timestamp)
        )
        guard resolvedMetadata.scope != .privateOnly else {
            completion(0)
            return
        }
        let knowledgeSessionCount = knowledgeBase.readGraph { $0.sessionCount }
        let sessionId = max(conversationMemory.currentMemory.sessionCount + 1, knowledgeSessionCount + 1)
        let addedCount = knowledgeBase.ingestArchiveVoiceSampleMetadata(
            title: title,
            note: note,
            sessionId: sessionId,
            privacyMetadata: resolvedMetadata,
            targetPersonName: targetPersonName,
            targetPersonId: targetPersonId
        )
        completion(addedCount)
    }

    func ingestTimeMailboxLetterMetadata(
        _ letter: TimeMailboxLetter,
        completion: @escaping (Int) -> Void = { _ in }
    ) {
        guard letter.privacyMetadata.scope != .privateOnly else {
            completion(0)
            return
        }
        let addedCount = knowledgeBase.ingestTimeMailboxLetterMetadata(
            letterId: letter.id,
            recipientName: letter.recipientName,
            title: letter.title,
            deliverAt: letter.deliverAt,
            createdAt: letter.createdAt,
            privacyMetadata: letter.privacyMetadata
        )
        completion(addedCount)
    }

    func recordAssistantTurn(_ input: Stage1MailboxMemoryInput) {
        conversationMemory.recordAITurn(text: input.text, privacyMetadata: input.privacyMetadata)
    }

    func recordAssistantTurn(_ text: String) {
        recordAssistantTurn(Stage1MailboxMemoryInput(text))
    }

    func finishConversationSession() {
        conversationMemory.endSession()
    }

    func discardCurrentConversationSession() {
        conversationMemory.discardCurrentSession()
    }

    func search(_ query: String) -> KBSearchResult {
        knowledgeBase.search(query: query)
    }

    func promptContext(query: String?, includeGaps: Bool = true, maxItems: Int = 5) -> String {
        var parts: [String] = []

        let knowledgeContext = knowledgeBase.buildContextString(query: query, maxItems: maxItems)
        if !knowledgeContext.isEmpty {
            parts.append(knowledgeContext)
        }

        if includeGaps {
            let gapContext = gapDetector.detectAllGaps(surface: .prompt).buildContextString(maxGaps: maxItems)
            if !gapContext.isEmpty {
                parts.append(gapContext)
            }
        }

        return parts.joined(separator: "\n")
    }

    func greetingHint() -> String {
        knowledgeBase.buildGreetingHint()
    }

    func topKnowledgeGaps(limit: Int = 5) -> [KBLiteGapDetector.KnowledgeGap] {
        gapDetector.topGaps(limit)
    }

    func archiveSnapshot() -> KBLiteGraph {
        knowledgeBase.displayGraphForLocalBrowsing()
    }

    func dashboardSnapshot() -> Stage1MemoryDashboardSnapshot {
        let graph = archiveSnapshot()
        return Stage1MemoryDashboardSnapshot(
            stats: Self.statsSummary(for: graph),
            isEmpty: Self.isEmpty(graph),
            lastUpdated: graph.lastUpdated,
            sessionCount: graph.sessionCount,
            peopleCount: graph.people.count,
            placesCount: graph.places.count,
            eventsCount: graph.events.count,
            factsCount: graph.facts.count,
            topGaps: topKnowledgeGaps(limit: 5),
            greetingHint: greetingHint()
        )
    }

    private static func statsSummary(for graph: KBLiteGraph) -> String {
        "\(graph.people.count)人 · \(graph.places.count)地 · \(graph.events.count)事 · \(graph.facts.count)实 · 共\(graph.sessionCount)次会话"
    }

    private static func isEmpty(_ graph: KBLiteGraph) -> Bool {
        graph.people.isEmpty && graph.places.isEmpty && graph.events.isEmpty && graph.facts.isEmpty
    }

    @discardableResult
    func ingestImageAnalysis(
        _ result: KBImageAnalysisResult,
        sessionId: Int,
        privacyMetadata: MemoryPrivacyMetadata = MemoryPrivacyMetadata(scope: .localOnly),
        archiveItemID: String? = nil,
        archiveTitle: String? = nil,
        capturedAt: Date = Date()
    ) -> Int {
        let resolvedMetadata = privacyMetadata.appendingSourceRef(
            Self.archiveSourceRef(id: archiveItemID, title: archiveTitle ?? "旧照片", capturedAt: capturedAt)
        )
        guard resolvedMetadata.scope != .privateOnly else {
            return 0
        }
        let sourceRef = Self.archiveSourceRef(id: archiveItemID, title: archiveTitle ?? "旧照片", capturedAt: capturedAt)
        let metadataCount: Int
        if archiveItemID?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false {
            metadataCount = knowledgeBase.ingestArchivePhotoAnalysisMetadata(
                archiveItemID: sourceRef.id,
                title: sourceRef.title ?? "旧照片",
                analysis: result,
                capturedAt: capturedAt,
                sessionId: sessionId,
                privacyMetadata: resolvedMetadata
            )
        } else {
            metadataCount = 0
        }
        knowledgeBase.ingestImageAnalysis(
            result,
            sessionId: sessionId,
            privacyMetadata: resolvedMetadata
        )
        return metadataCount
    }

    func exportKnowledgeJSON(surface: MemoryUseSurface = .export) -> String? {
        knowledgeBase.exportJSON(surface: surface)
    }

    @discardableResult
    func importKnowledgeJSON(_ jsonString: String) -> Bool {
        knowledgeBase.importJSON(jsonString)
    }
}

private extension Stage1MailboxMemoryInput {
    func withSourceRef(_ sourceRef: MemorySourceRef) -> Stage1MailboxMemoryInput {
        Stage1MailboxMemoryInput(
            text: text,
            timestamp: timestamp,
            privacyMetadata: privacyMetadata.appendingSourceRef(sourceRef)
        )
    }
}

private extension Stage1MemoryFacade {
    static func archiveSourceRef(id: String?, title: String?, capturedAt: Date) -> MemorySourceRef {
        let sourceID = id?.trimmingCharacters(in: .whitespacesAndNewlines)
        let sourceTitle = title?.trimmingCharacters(in: .whitespacesAndNewlines)
        return MemorySourceRef(
            kind: .memoryArchiveItem,
            id: sourceID?.isEmpty == false ? sourceID! : "archive-\(Int(capturedAt.timeIntervalSince1970))",
            title: sourceTitle?.isEmpty == false ? sourceTitle : "记忆档案素材",
            capturedAt: capturedAt
        )
    }
}
#endif
