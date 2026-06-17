import Foundation

enum DigitalHumanMode: String, Codable {
    case sunlight
}

struct DigitalHumanContext: Codable {
    var ownerId: String
    var displayName: String
    var relation: String?
    var mode: DigitalHumanMode
    var isSelfAssistant: Bool
}

final class DigitalHumanContextStore {
    static let shared = DigitalHumanContextStore()

    var current = DigitalHumanContext(
        ownerId: "echo_context_test",
        displayName: "",
        relation: nil,
        mode: .sunlight,
        isSelfAssistant: true
    )
}

struct ConversationMemory {
    var sessionCount: Int = 0
}

final class ConversationMemoryManager {
    static let shared = ConversationMemoryManager()

    private(set) var currentMemory = ConversationMemory()
    private(set) var recordedUserTurns: [String] = []
    private(set) var recordedAITurns: [String] = []

    func recordUserTurn(text: String) {
        recordedUserTurns.append(text)
    }

    func recordAITurn(text: String) {
        recordedAITurns.append(text)
    }
}

struct MemoryArchiveContextSnapshot {
    let totalItemCount: Int
    let availableItemCount: Int
}

final class MemoryArchiveRepository {
    static let shared = MemoryArchiveRepository()

    func contextSnapshot() -> MemoryArchiveContextSnapshot {
        MemoryArchiveContextSnapshot(totalItemCount: 0, availableItemCount: 0)
    }
}

func assertEqual(_ lhs: Int, _ rhs: Int, _ message: String) {
    guard lhs == rhs else {
        fatalError("\(message): expected \(rhs), got \(lhs)")
    }
}

func assertTrue(_ value: Bool, _ message: String) {
    guard value else {
        fatalError("\(message): expected true")
    }
}

@main
enum EchoArchiveContextStatusCheck {
    static func main() {
        var providedStatus = EchoArchiveContextStatus(totalItemCount: 4, availableItemCount: 2)
        let viewModel = EchoViewModel(
            contextStore: DigitalHumanContextStore.shared,
            memoryManager: ConversationMemoryManager.shared,
            archiveContextStatusProvider: { providedStatus }
        )

        assertEqual(viewModel.archiveContextStatus.totalItemCount, 0, "initial total count")
        assertEqual(viewModel.archiveContextStatus.availableItemCount, 0, "initial available count")

        viewModel.beginVoiceInteraction()
        assertEqual(viewModel.archiveContextStatus.totalItemCount, 4, "begin refreshes total count")
        assertEqual(viewModel.archiveContextStatus.availableItemCount, 2, "begin refreshes available count")
        assertTrue(viewModel.archiveContextStatus.hasAvailableContext, "begin exposes available archive context")

        providedStatus = EchoArchiveContextStatus(totalItemCount: 5, availableItemCount: 3)
        viewModel.finishUserVoice(text: "  想听爸爸小时候的故事  ")

        assertEqual(viewModel.archiveContextStatus.totalItemCount, 5, "finish refreshes total count")
        assertEqual(viewModel.archiveContextStatus.availableItemCount, 3, "finish refreshes available count")
    }
}
