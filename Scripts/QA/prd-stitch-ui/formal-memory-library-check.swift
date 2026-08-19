import Foundation

let root = URL(
    fileURLWithPath: CommandLine.arguments.dropFirst().first
        ?? FileManager.default.currentDirectoryPath
)

func read(_ relativePath: String) -> String {
    let url = root.appendingPathComponent(relativePath)
    guard let value = try? String(contentsOf: url, encoding: .utf8) else {
        fatalError("Unable to read \(url.path)")
    }
    return value
}

func require(_ content: String, _ needle: String, _ reason: String) {
    guard content.contains(needle) else {
        fatalError("\(reason): missing \(needle)")
    }
}

func reject(_ content: String, _ needle: String, _ reason: String) {
    guard !content.contains(needle) else {
        fatalError("\(reason): unexpected \(needle)")
    }
}

let contract = read("DreamJourney/Sources/Domain/OwnerTruth/OwnerTruthFormalMemory.swift")
let client = read("DreamJourney/Sources/Services/DreamJourneyBackendClient.swift")
let archive = read("DreamJourney/Sources/Modules/Archive/MemoryArchiveViewController.swift")
let surface = read("DreamJourney/Sources/Modules/Archive/OwnerTruthFormalMemoryViewControllers.swift")
guard
    let editorStart = surface.range(of: "final class OwnerTruthFormalMemoryEditViewController"),
    let editorEnd = surface.range(of: "private struct OwnerTruthFormalMemoryUIQAResult")
else {
    fatalError("Unable to isolate the formal-memory editor implementation")
}
let editor = String(surface[editorStart.lowerBound..<editorEnd.lowerBound])

for token in [
    "protocol OwnerTruthFormalMemoryClient",
    "historyLimit == 3",
    "secondConfirmation: Bool",
    "guard secondConfirmation",
    "OwnerTruthFormalMemoryRevisionReceipt",
] {
    require(contract, token, "formal-memory typed contract must preserve product boundaries")
}

for token in [
    "func fetchOwnerTruthFormalMemories(",
    "func fetchOwnerTruthFormalMemory(",
    "func reviseOwnerTruthFormalMemory(",
    "/revisions",
    "extension DreamJourneyBackendClient: OwnerTruthFormalMemoryClient",
] {
    require(client, token, "backend-ready client must cover the formal-memory routes")
}
reject(client, "method: .delete,\n            path: \"/v2/vaults/", "formal memories cannot expose user deletion")

for token in [
    "private let formalMemoryButton",
    "isSelfAutobiographyMode && isOwnerTruthCandidateReviewEnabled",
    "OwnerTruthFormalMemoryListViewController",
    "archive-owner-truth-formal-memory",
] {
    require(archive, token, "Archive must expose formal memory only to its Owner")
}

for token in [
    "final class OwnerTruthFormalMemoryListViewController",
    "final class OwnerTruthFormalMemoryDetailViewController",
    "final class OwnerTruthFormalMemoryEditViewController",
    "accountLeaseRuntime.validate(accountLease, at: .request)",
    "accountLeaseRuntime.validate(accountLease, at: .commit)",
    "owner-truth-formal-memory-search",
    "owner-truth-formal-memory-load-more",
    "owner-truth-formal-memory-edit-review",
    "owner-truth-formal-memory-edit-confirm",
    "secondConfirmation: true",
    "client.reviseOwnerTruthFormalMemory(",
] {
    require(surface, token, "formal-memory UI must remain lease-fenced and double-confirmed")
}
reject(editor, "UserDefaults", "an unconfirmed edit draft must remain in memory")
reject(editor, "write(to:", "an unconfirmed edit draft must not be persisted to disk")

print("Formal memory library guard passed")
