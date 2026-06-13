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
        completion: @escaping (Int) -> Void = { _ in }
    ) {
        let resolvedInput = input.withSourceRef(
            Self.archiveSourceRef(
                id: archiveItemID,
                title: archiveTitle,
                capturedAt: input.timestamp
            )
        )

        recordUserTurn(resolvedInput)

        guard resolvedInput.privacyMetadata.scope != .privateOnly else {
            completion(0)
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
        knowledgeBase.extractFromTranscript(
            turns: [turn],
            sessionId: sessionId,
            completion: completion
        )
    }

    func ingestArchiveVoiceSampleMetadata(
        title: String,
        note: String?,
        archiveItemID: String? = nil,
        timestamp: Date = Date(),
        privacyMetadata: MemoryPrivacyMetadata = MemoryPrivacyMetadata(scope: .localOnly),
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
            privacyMetadata: resolvedMetadata
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
        knowledgeBase.readGraph { $0 }
    }

    func dashboardSnapshot() -> Stage1MemoryDashboardSnapshot {
        let graph = archiveSnapshot()
        return Stage1MemoryDashboardSnapshot(
            stats: knowledgeBase.stats,
            isEmpty: knowledgeBase.isEmpty,
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

    func ingestImageAnalysis(
        _ result: KBImageAnalysisResult,
        sessionId: Int,
        privacyMetadata: MemoryPrivacyMetadata = MemoryPrivacyMetadata(scope: .localOnly),
        archiveItemID: String? = nil,
        archiveTitle: String? = nil,
        capturedAt: Date = Date()
    ) {
        let resolvedMetadata = privacyMetadata.appendingSourceRef(
            Self.archiveSourceRef(id: archiveItemID, title: archiveTitle ?? "旧照片", capturedAt: capturedAt)
        )
        knowledgeBase.ingestImageAnalysis(
            result,
            sessionId: sessionId,
            privacyMetadata: resolvedMetadata
        )
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
