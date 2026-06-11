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
            let gapContext = gapDetector.detectAllGaps().buildContextString(maxGaps: maxItems)
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
        privacyMetadata: MemoryPrivacyMetadata = MemoryPrivacyMetadata(scope: .localOnly)
    ) {
        knowledgeBase.ingestImageAnalysis(
            result,
            sessionId: sessionId,
            privacyMetadata: privacyMetadata
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
#endif
