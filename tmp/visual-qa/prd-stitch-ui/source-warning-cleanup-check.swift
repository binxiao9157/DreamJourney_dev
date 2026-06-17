import Foundation

let root = CommandLine.arguments.dropFirst().first ?? FileManager.default.currentDirectoryPath

func read(_ relativePath: String) -> String {
    let path = "\(root)/\(relativePath)"
    guard let content = try? String(contentsOfFile: path, encoding: .utf8) else {
        fatalError("Unable to read \(path)")
    }
    return content
}

func assertNotContains(_ haystack: String, _ needle: String, _ message: String) {
    guard !haystack.contains(needle) else {
        fatalError("\(message): unexpected \(needle)")
    }
}

let sourceChecks: [(path: String, forbidden: [String])] = [
    ("DreamJourney/Sources/Modules/Map/FootprintNotificationBanner.swift", [
        "contentEdgeInsets =",
    ]),
    ("DreamJourney/Sources/Modules/Home/Views/HomeHeaderView.swift", [
        "contentEdgeInsets =",
    ]),
    ("DreamJourney/Sources/Memoir/MemoirDetailViewController.swift", [
        "contentEdgeInsets =",
        "let hasAudio = memoir.audioFileName != nil",
    ]),
    ("DreamJourney/Sources/Modules/Memory/MemoryDetailViewController.swift", [
        "imageEdgeInsets =",
        "contentEdgeInsets =",
    ]),
    ("DreamJourney/Sources/Memoir/MemoirFlowManager.swift", [
        "contentEdgeInsets =",
    ]),
    ("DreamJourney/Sources/Common/UI/TGLoadingView.swift", [
        "UIApplication.shared.windows",
    ]),
    ("DreamJourney/Sources/Common/UI/TGToast.swift", [
        "UIApplication.shared.windows",
    ]),
    ("DreamJourney/Sources/Services/ConversationMemoryManager.swift", [
        "let exactTimePatterns =",
    ]),
]

for check in sourceChecks {
    let content = read(check.path)
    for forbidden in check.forbidden {
        assertNotContains(content, forbidden, "\(check.path) should not reintroduce low-risk source warning")
    }
}

print("Source warning cleanup checks passed")
