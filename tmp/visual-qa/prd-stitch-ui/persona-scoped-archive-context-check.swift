import Foundation

let rootPath = CommandLine.arguments.dropFirst().first ?? FileManager.default.currentDirectoryPath
let rootURL = URL(fileURLWithPath: rootPath)

func read(_ relativePath: String) -> String {
    let url = rootURL.appendingPathComponent(relativePath)
    guard let text = try? String(contentsOf: url, encoding: .utf8) else {
        fatalError("Unable to read \(relativePath)")
    }
    return text
}

func assertContains(_ source: String, _ needle: String, _ message: String) {
    guard source.contains(needle) else {
        fatalError("\(message): missing `\(needle)`")
    }
}

func assertNotContains(_ source: String, _ needle: String, _ message: String) {
    guard !source.contains(needle) else {
        fatalError("\(message): unexpected `\(needle)`")
    }
}

let contextStore = read("DreamJourney/Sources/App/DigitalHumanContextStore.swift")
let archiveRepository = read("DreamJourney/Sources/Modules/Archive/MemoryArchiveRepository.swift")
let echoViewModel = read("DreamJourney/Sources/Modules/Echo/EchoViewModel.swift")

assertContains(
    contextStore,
    "var viewerUserId: String?",
    "digital human context should remember which logged-in viewer owns the selected persona"
)
assertContains(
    contextStore,
    "resolvedDisplayName",
    "digital human context should provide a safe display name fallback"
)
assertContains(
    contextStore,
    "djDigitalHumanContextDidChange",
    "digital human context changes should be observable by PRD screens"
)
assertContains(
    contextStore,
    "normalizedForCurrentViewer",
    "stored contexts should be normalized against the current logged-in viewer"
)

assertContains(
    archiveRepository,
    "private var currentArchiveOwnerId",
    "archive repository should expose selected persona owner id"
)
assertContains(
    archiveRepository,
    "DigitalHumanContextStore.shared.current.ownerId",
    "archive repository should derive owner from selected digital-human context"
)
assertContains(
    archiveRepository,
    "\"\\(baseKey).\\(currentArchiveOwnerId)\"",
    "archive repository storage key should be selected-owner scoped"
)
assertNotContains(
    archiveRepository,
    "\"\\(baseKey).\\(currentUserId)\"",
    "archive repository storage key must not be login-user scoped only"
)
assertContains(
    archiveRepository,
    "listArchiveItems(userId: currentArchiveOwnerId",
    "backend archive fetch should request the selected owner archive"
)
assertContains(
    archiveRepository,
    "\"viewerUserId\": currentUserId",
    "backend archive payload should include the logged-in viewer id"
)
assertContains(
    archiveRepository,
    "\"ownerId\": currentArchiveOwnerId",
    "backend archive payload should include the selected archive owner id"
)

assertContains(
    echoViewModel,
    "context = contextStore.current",
    "echo view model should refresh selected digital-human context before voice interaction"
)
assertContains(
    echoViewModel,
    "MemoryArchiveRepository.shared.contextSnapshot()",
    "echo context status should continue to flow through archive repository snapshot"
)

print("Persona-scoped archive context checks passed")
