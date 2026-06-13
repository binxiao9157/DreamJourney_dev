import Foundation

private func require(_ condition: @autoclosure () -> Bool, _ message: String) {
    guard condition() else {
        fputs("ConversationMemoryCareHistory verification failed: \(message)\n", stderr)
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
}

extension Notification.Name {
    static let djConversationKnowledgeExtractionFinished = Notification.Name("dj.conversation.knowledgeExtractionFinished")
}

let familyMetadata = MemoryPrivacyMetadata(
    scope: .familyCircle,
    sourceRefs: [
        MemorySourceRef(
            kind: .userAuthorization,
            id: "home-dialog-familyCircle",
            title: "亲友范围",
            capturedAt: Date(timeIntervalSince1970: 1_800_500_000)
        )
    ],
    createdAt: Date(timeIntervalSince1970: 1_800_500_000)
)

ConversationMemoryManager.shared.resetLocalStorage()
ConversationMemoryManager.shared.recordUserTurn(
    text: "第一轮亲友关怀信号：最近睡不好。",
    privacyMetadata: familyMetadata
)
ConversationMemoryManager.shared.recordAITurn(
    text: "我会提醒家人多关注您的睡眠。",
    privacyMetadata: familyMetadata
)
ConversationMemoryManager.shared.endSession()

ConversationMemoryManager.shared.recordUserTurn(
    text: "第二轮亲友关怀信号：今天还是有点孤单。",
    privacyMetadata: familyMetadata
)

let historyDuringSecondSession = ConversationMemoryManager.shared.getCareDashboardTranscriptHistory()
require(
    historyDuringSecondSession.contains(where: { $0.text.contains("第一轮亲友关怀信号") }),
    "care dashboard history should keep previous session turns"
)
require(
    historyDuringSecondSession.contains(where: { $0.text.contains("第二轮亲友关怀信号") }),
    "care dashboard history should include current in-progress turns"
)

let visibleTurns = CareDashboardInputPolicy.eligibleInputTurns(
    from: historyDuringSecondSession,
    viewerFamilyMemberID: nil
)
require(
    visibleTurns.map(\.text).contains("第一轮亲友关怀信号：最近睡不好。"),
    "care dashboard policy should receive previous family-circle turn"
)
require(
    visibleTurns.map(\.text).contains("第二轮亲友关怀信号：今天还是有点孤单。"),
    "care dashboard policy should receive current family-circle turn"
)

ConversationMemoryManager.shared.endSession()
let historyAfterSecondSession = ConversationMemoryManager.shared.getCareDashboardTranscriptHistory()
require(
    historyAfterSecondSession.filter { $0.role == "user" }.count >= 2,
    "care dashboard history should persist multiple user turns after sessions end"
)

ConversationMemoryManager.shared.resetLocalStorage()
print("ConversationMemoryCareHistory verification passed")
