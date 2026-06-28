import Foundation

let rootPath = CommandLine.arguments.dropFirst().first ?? FileManager.default.currentDirectoryPath
let rootURL = URL(fileURLWithPath: rootPath)

func read(_ relativePath: String) -> String {
    let url = rootURL.appendingPathComponent(relativePath)
    do {
        return try String(contentsOf: url, encoding: .utf8)
    } catch {
        fatalError("Unable to read \(relativePath): \(error)")
    }
}

func assertContains(_ source: String, _ needle: String, _ message: String) {
    guard source.contains(needle) else {
        fatalError(message)
    }
}

let archiveView = read("DreamJourney/Sources/Modules/Archive/MemoryArchiveViewController.swift")
let profileView = read("DreamJourney/Sources/Modules/Profile/ProfileViewController.swift")
let careModels = read("DreamJourney/Sources/Modules/Profile/ProfileCareModels.swift")

assertContains(
    archiveView,
    "remoteSyncCaptionLabel",
    "Archive page should own a visible remote sync status label"
)
assertContains(
    archiveView,
    "archiveRemoteSyncStatus",
    "Archive remote sync status should have a stable accessibility identifier for QA"
)
assertContains(
    archiveView,
    "正在同步远端档案",
    "Archive page should show an in-progress remote sync message"
)
assertContains(
    archiveView,
    "已同步远端档案",
    "Archive page should show a successful remote sync message"
)
assertContains(
    archiveView,
    "远端暂不可用，已保留本地档案",
    "Archive page should explain local fallback when backend sync fails"
)
assertContains(
    archiveView,
    "remoteSyncCaptionLabel.isHidden = true",
    "Archive remote sync status should stay hidden before remote fetch is enabled"
)
assertContains(
    archiveView,
    "setArchiveRemoteSyncStatus(.fallback",
    "Archive fetch failure should set the fallback sync status"
)

assertContains(
    profileView,
    "profileCareSyncCaption",
    "Profile care fallback caption should have a stable accessibility identifier for QA"
)
assertContains(
    careModels,
    "关怀数据暂未同步，当前显示本地安全状态。",
    "Profile care stale fallback copy should remain explicit"
)

print("Backend fallback UI checks passed")
