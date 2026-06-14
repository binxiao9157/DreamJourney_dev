import Foundation

private func assertCondition(_ condition: @autoclosure () -> Bool, _ message: String) {
    guard condition() else {
        fputs("FAIL: \(message)\n", stderr)
        exit(1)
    }
}

struct ConversationTurn: Codable, MemoryPrivacyScoped {
    let role: String
    let text: String
    let timestamp: Date
    let privacyMetadata: MemoryPrivacyMetadata
}

struct UserModel: Codable {
    let id: String
}

final class UserManager {
    static let shared = UserManager()
    let currentUser: UserModel? = UserModel(id: "kblite_quick_extract_verify")
}

final class KBLiteSemanticSearch {
    static let shared = KBLiteSemanticSearch()
    var isAvailable: Bool { false }

    func warmCache(people: [KBPerson], places: [KBPlace], events: [KBEvent], facts: [KBFact]) {}

    func semanticSearch(
        query: String,
        people: [KBPerson],
        places: [KBPlace],
        events: [KBEvent],
        facts: [KBFact],
        topK: Int = 5
    ) -> KBSearchResult {
        KBSearchResult()
    }
}

final class DeepSeekService {
    static let shared = DeepSeekService()

    enum StubError: LocalizedError {
        case unavailable

        var errorDescription: String? {
            "DeepSeek is intentionally unavailable in quick-extract verification"
        }
    }

    func extractKnowledge(prompt: String, completion: @escaping (Result<KBExtractionResult, StubError>) -> Void) {
        completion(.success(KBExtractionResult()))
    }
}

let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
let verifyGraph = docs.appendingPathComponent("knowledge_base/kb_graph_kblite_quick_extract_verify.json")
try? FileManager.default.removeItem(at: verifyGraph)

let metadata = MemoryPrivacyMetadata(scope: .generationAllowed)
let testText = "我叫陈建国，1968年住在绍兴越城区仓桥直街。1978年我和妻子林桂芳在杭州西湖边开过一家小照相馆。"

KBLiteManager.shared.reset()
let addedCount = KBLiteManager.shared.verifyQuickExtract(
    turns: [
        ConversationTurn(
            role: "user",
            text: testText,
            timestamp: Date(timeIntervalSince1970: 1_800_000_000),
            privacyMetadata: metadata
        )
    ],
    sessionId: 1,
    privacyMetadata: metadata
)

let graph = KBLiteManager.shared.graph
let peopleNames = Set(graph.people.map(\.name))
let placeNames = Set(graph.places.map(\.name))
let eventTitles = Set(graph.events.map(\.title))
let factText = graph.facts.map(\.statement).joined(separator: "\n")

assertCondition(addedCount >= 8, "quick extract should add concrete people, places, events and facts")
assertCondition(peopleNames.contains("陈建国"), "should extract self name 陈建国")
assertCondition(peopleNames.contains("林桂芳"), "should extract spouse name 林桂芳")
assertCondition(placeNames.contains("绍兴"), "should extract city 绍兴")
assertCondition(placeNames.contains("绍兴越城区仓桥直街"), "should extract full lived address")
assertCondition(placeNames.contains("杭州西湖边") || placeNames.contains("西湖边"), "should extract work location around 西湖边")
assertCondition(eventTitles.contains("开小照相馆") || eventTitles.contains("开照相馆"), "should extract photo studio event")
assertCondition(eventTitles.contains("居住经历"), "should extract lived event")
assertCondition(factText.contains("1968年住在绍兴越城区仓桥直街"), "should persist lived fact")
assertCondition(factText.contains("1978年我和妻子林桂芳在杭州西湖边开过一家小照相馆"), "should persist photo studio fact")
assertCondition(graph.people.allSatisfy { $0.privacyMetadata.scope == .generationAllowed }, "people should keep generation scope")
assertCondition(graph.places.allSatisfy { $0.privacyMetadata.scope == .generationAllowed }, "places should keep generation scope")
assertCondition(graph.events.allSatisfy { $0.privacyMetadata.scope == .generationAllowed }, "events should keep generation scope")
assertCondition(graph.facts.allSatisfy { $0.privacyMetadata.scope == .generationAllowed }, "facts should keep generation scope")

KBLiteManager.shared.reset()
var extractionAddedCount: Int?
KBLiteManager.shared.extractFromTranscript(
    turns: [
        ConversationTurn(
            role: "user",
            text: testText,
            timestamp: Date(timeIntervalSince1970: 1_800_000_000),
            privacyMetadata: metadata
        )
    ],
    sessionId: 1
) { addedCount in
    extractionAddedCount = addedCount
}

let legacyDeadline = Date().addingTimeInterval(2)
while extractionAddedCount == nil && Date() < legacyDeadline {
    RunLoop.current.run(mode: .default, before: Date().addingTimeInterval(0.02))
}
assertCondition(extractionAddedCount != nil, "extractFromTranscript should call completion when DeepSeek returns an empty success")
assertCondition(
    (extractionAddedCount ?? 0) >= 8,
    "extractFromTranscript should preserve deterministic local extraction even when LLM succeeds with no entities"
)

KBLiteManager.shared.reset()
var extractionSummary: KBLiteExtractionSummary?
KBLiteManager.shared.extractFromTranscriptDetailed(
    turns: [
        ConversationTurn(
            role: "user",
            text: testText,
            timestamp: Date(timeIntervalSince1970: 1_800_000_001),
            privacyMetadata: metadata
        )
    ],
    sessionId: 2
) { summary in
    extractionSummary = summary
}

let deadline = Date().addingTimeInterval(2)
while extractionSummary == nil && Date() < deadline {
    RunLoop.current.run(mode: .default, before: Date().addingTimeInterval(0.02))
}
assertCondition(extractionSummary != nil, "extractFromTranscriptDetailed should call completion with a structured summary")
assertCondition((extractionSummary?.deterministicAddedCount ?? 0) >= 8, "detailed extraction should expose deterministic local additions")
assertCondition(extractionSummary?.didAttemptLLM == true, "detailed extraction should expose whether LLM was attempted")
assertCondition(extractionSummary?.llmAddedCount == 0, "empty LLM success should expose zero LLM additions")
assertCondition((extractionSummary?.totalAddedCount ?? 0) >= (extractionSummary?.deterministicAddedCount ?? 0), "detailed extraction should expose total additions")
let graphAfterEmptyLLMSuccess = KBLiteManager.shared.graph
let emptySuccessPeople = Set(graphAfterEmptyLLMSuccess.people.map(\.name))
let emptySuccessPlaces = Set(graphAfterEmptyLLMSuccess.places.map(\.name))
let emptySuccessEvents = Set(graphAfterEmptyLLMSuccess.events.map(\.title))
let emptySuccessFacts = graphAfterEmptyLLMSuccess.facts.map(\.statement).joined(separator: "\n")

assertCondition(emptySuccessPeople.contains("陈建国"), "empty LLM success should still extract self name")
assertCondition(emptySuccessPeople.contains("林桂芳"), "empty LLM success should still extract spouse name")
assertCondition(emptySuccessPlaces.contains("绍兴越城区仓桥直街"), "empty LLM success should still extract lived address")
assertCondition(
    emptySuccessEvents.contains("开小照相馆") || emptySuccessEvents.contains("开照相馆"),
    "empty LLM success should still extract photo studio event"
)
assertCondition(
    emptySuccessFacts.contains("1978年我和妻子林桂芳在杭州西湖边开过一家小照相馆"),
    "empty LLM success should still persist explicit fact"
)
assertCondition(
    graphAfterEmptyLLMSuccess.sessionCount == 2,
    "extractFromTranscript should mark session processed after deterministic deposit"
)

KBLiteManager.shared.reset()
var firstFrequencySummary: KBLiteExtractionSummary?
KBLiteManager.shared.extractFromTranscriptDetailed(
    turns: [
        ConversationTurn(
            role: "user",
            text: testText,
            timestamp: Date(timeIntervalSince1970: 1_800_000_010),
            privacyMetadata: metadata
        )
    ],
    sessionId: 1
) { summary in
    firstFrequencySummary = summary
}

let firstFrequencyDeadline = Date().addingTimeInterval(2)
while firstFrequencySummary == nil && Date() < firstFrequencyDeadline {
    RunLoop.current.run(mode: .default, before: Date().addingTimeInterval(0.02))
}
assertCondition(firstFrequencySummary?.didAttemptLLM == true, "first extraction should attempt LLM")

var skippedFrequencySummary: KBLiteExtractionSummary?
KBLiteManager.shared.extractFromTranscriptDetailed(
    turns: [
        ConversationTurn(
            role: "user",
            text: "我叫赵海，1999年住在宁波老外滩。",
            timestamp: Date(timeIntervalSince1970: 1_800_000_011),
            privacyMetadata: metadata
        )
    ],
    sessionId: 2
) { summary in
    skippedFrequencySummary = summary
}
let skippedFrequencyDeadline = Date().addingTimeInterval(2)
while skippedFrequencySummary == nil && Date() < skippedFrequencyDeadline {
    RunLoop.current.run(mode: .default, before: Date().addingTimeInterval(0.02))
}
assertCondition(skippedFrequencySummary?.didSkipDueToFrequency == true, "regular second extraction should keep frequency throttle")
assertCondition(skippedFrequencySummary?.didAttemptLLM == false, "regular second extraction should not attempt LLM under throttle")

var forcedArchiveSummary: KBLiteExtractionSummary?
KBLiteManager.shared.extractFromTranscriptDetailed(
    turns: [
        ConversationTurn(
            role: "user",
            text: "档案补充：外婆王兰香年轻时在苏州观前街做过绣活。",
            timestamp: Date(timeIntervalSince1970: 1_800_000_012),
            privacyMetadata: metadata
        )
    ],
    sessionId: 3,
    forceRemoteExtraction: true
) { summary in
    forcedArchiveSummary = summary
}
let forcedArchiveDeadline = Date().addingTimeInterval(2)
while forcedArchiveSummary == nil && Date() < forcedArchiveDeadline {
    RunLoop.current.run(mode: .default, before: Date().addingTimeInterval(0.02))
}
assertCondition(forcedArchiveSummary?.didSkipDueToFrequency == false, "forced archive extraction should bypass frequency throttle")
assertCondition(forcedArchiveSummary?.didAttemptLLM == true, "forced archive extraction should attempt LLM")

let generalText = "我叫周明，1992年住在泉州鲤城区中山路。2001年我和妻子许安琪在厦门鼓浪屿开了一家茶馆。"
KBLiteManager.shared.reset()
let generalAddedCount = KBLiteManager.shared.verifyQuickExtract(
    turns: [
        ConversationTurn(
            role: "user",
            text: generalText,
            timestamp: Date(timeIntervalSince1970: 1_800_000_002),
            privacyMetadata: metadata
        )
    ],
    sessionId: 3,
    privacyMetadata: metadata
)

let generalGraph = KBLiteManager.shared.graph
let generalPeople = Set(generalGraph.people.map(\.name))
let generalPlaces = Set(generalGraph.places.map(\.name))
let generalEvents = Set(generalGraph.events.map(\.title))
let generalFacts = generalGraph.facts.map(\.statement).joined(separator: "\n")

assertCondition(generalAddedCount >= 7, "quick extract should handle non-sample archive sentences")
assertCondition(generalPeople.contains("周明"), "should extract self name from a non-sample sentence")
assertCondition(generalPeople.contains("许安琪"), "should extract spouse name from a non-sample sentence")
assertCondition(generalPlaces.contains("泉州鲤城区中山路"), "should extract lived address from a non-sample sentence")
assertCondition(generalPlaces.contains("厦门鼓浪屿"), "should extract business location from a non-sample sentence")
assertCondition(
    generalEvents.contains("开茶馆") || generalEvents.contains("开店"),
    "should extract generic opened-shop events without relying on 照相馆"
)
assertCondition(generalFacts.contains("2001年我和妻子许安琪在厦门鼓浪屿开了一家茶馆"), "should persist generic opened-shop fact")

KBLiteManager.shared.reset()
try? FileManager.default.removeItem(at: verifyGraph)
print("KBLite quick extract verification passed")
