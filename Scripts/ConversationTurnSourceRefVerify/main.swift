import Foundation

private func assertCondition(_ condition: @autoclosure () -> Bool, _ message: String) {
    guard condition() else {
        fputs("FAIL: \(message)\n", stderr)
        exit(1)
    }
}

final class KBLiteManager {
    static let shared = KBLiteManager()

    func extractFromTranscript(
        turns: [ConversationTurn],
        sessionId: Int,
        completion: @escaping (Int) -> Void
    ) {
        completion(0)
    }

    func extractFromTranscriptDetailed(
        turns: [ConversationTurn],
        sessionId: Int,
        completion: @escaping (KBLiteExtractionSummary) -> Void
    ) {
        completion(.empty)
    }
}

extension Notification.Name {
    static let djConversationKnowledgeExtractionFinished = Notification.Name("dj.conversation.knowledgeExtractionFinished")
}

ConversationMemoryManager.shared.resetLocalStorage()

let authorization = MemorySourceRef(
    kind: .userAuthorization,
    id: "home-dialog-generationAllowed",
    title: "可生成",
    capturedAt: Date(timeIntervalSince1970: 1_800_456_789)
)
let metadata = MemoryPrivacyMetadata(
    scope: .generationAllowed,
    sourceRefs: [authorization],
    createdAt: Date(timeIntervalSince1970: 1_800_456_789)
)

ConversationMemoryManager.shared.recordUserTurn(
    text: "我叫陈建国，1968年住在绍兴越城区仓桥直街。",
    privacyMetadata: metadata
)
ConversationMemoryManager.shared.recordAITurn(
    text: "我记住了，绍兴越城区仓桥直街是很重要的生活线索。",
    privacyMetadata: metadata
)

let transcript = ConversationMemoryManager.shared.getCurrentTranscript()
assertCondition(transcript.count == 2, "should keep both recorded turns")

let userRefs = transcript[0].privacyMetadata.sourceRefs
assertCondition(
    userRefs.contains(where: { $0.kind == .userAuthorization && $0.id == "home-dialog-generationAllowed" }),
    "user turn should preserve authorization source ref"
)
assertCondition(
    userRefs.contains(where: { $0.kind == .conversationTurn && $0.title?.contains("用户对话") == true }),
    "user turn should append conversation source ref"
)

let aiRefs = transcript[1].privacyMetadata.sourceRefs
assertCondition(
    aiRefs.contains(where: { $0.kind == .conversationTurn && $0.title?.contains("AI回复") == true }),
    "AI turn should append conversation source ref"
)

ConversationMemoryManager.shared.endSession()
assertCondition(
    ConversationMemoryManager.shared.currentMemory.lastSummary.person == "陈建国",
    "self-introduction should extract the concrete person name"
)
assertCondition(
    ConversationMemoryManager.shared.currentMemory.lastSummary.place.contains("绍兴"),
    "self-introduction should extract the concrete place"
)

ConversationMemoryManager.shared.resetLocalStorage()
ConversationMemoryManager.shared.recordUserTurn(
    text: "我妈妈喜欢做桂花糕。",
    privacyMetadata: metadata
)
ConversationMemoryManager.shared.endSession()
assertCondition(
    ConversationMemoryManager.shared.currentMemory.lastSummary.person.isEmpty,
    "generic kinship words should not become the summary person"
)

ConversationMemoryManager.shared.resetLocalStorage()
ConversationMemoryManager.shared.recordUserTurn(
    text: "1978年我和妻子林桂芳在杭州西湖边开过一家小照相馆。",
    privacyMetadata: metadata
)
ConversationMemoryManager.shared.endSession()
assertCondition(
    ConversationMemoryManager.shared.currentMemory.lastSummary.person == "林桂芳",
    "relation apposition should extract the concrete family member name"
)
assertCondition(
    ConversationMemoryManager.shared.currentMemory.lastSummary.place.contains("杭州")
        && !ConversationMemoryManager.shared.currentMemory.lastSummary.place.contains("芳"),
    "place extraction should not include trailing person-name residue"
)

ConversationMemoryManager.shared.resetLocalStorage()
print("ConversationTurnSourceRef verification passed")
