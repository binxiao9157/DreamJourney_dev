import Foundation

let root = URL(fileURLWithPath: CommandLine.arguments.dropFirst().first ?? FileManager.default.currentDirectoryPath)

func read(_ relativePath: String) -> String {
    let url = root.appendingPathComponent(relativePath)
    guard let content = try? String(contentsOf: url, encoding: .utf8) else {
        fatalError("Unable to read \(url.path)")
    }
    return content
}

func assertContains(_ haystack: String, _ needle: String, _ message: String) {
    guard haystack.contains(needle) else {
        fatalError("\(message): missing \(needle)")
    }
}

let item = read("DreamJourney/Sources/Modules/Archive/MemoryArchiveItem.swift")
let repository = read("DreamJourney/Sources/Modules/Archive/MemoryArchiveRepository.swift")
let display = read("DreamJourney/Sources/Modules/Archive/MemoryArchiveDisplayMetadata.swift")
let archiveView = read("DreamJourney/Sources/Modules/Archive/MemoryArchiveViewController.swift")
let releaseRegression = read("tmp/visual-qa/prd-stitch-ui/run-release-regression.sh")
let releaseQA = read("tmp/visual-qa/prd-stitch-ui/release-qa-package-check.swift")
let prdCoverage = read("docs/superpowers/status/2026-06-18-prd-coverage-matrix.md")
let closureDecisions = read("docs/superpowers/status/2026-06-18-prd-full-feature-closure-decisions.md")
let statusDoc = read("docs/superpowers/status/2026-06-18-archive-sync-error-recovery.md")

for phrase in [
    "enum ArchiveBackendSyncState",
    "case pending",
    "case synced",
    "case failed",
    "backendSyncState",
    "backendSyncError",
    "backendSyncAttemptedAt",
    "isPublicBackendSyncEligible",
    "updatingBackendSyncState",
] {
    assertContains(item, phrase, "archive item should define backend sync metadata contract \(phrase)")
}

for phrase in [
    "syncPendingPublicArchiveItemsToBackend",
    "markBackendSyncState",
    "sanitizeBackendSyncError",
    "updatingBackendSyncState(.pending",
    "updatingBackendSyncState(.synced",
    "updatingBackendSyncState(.failed",
    "item.isPublicBackendSyncEligible",
    "save(items)",
    "print(\"[Archive] backend sync failed",
] {
    assertContains(repository, phrase, "archive repository should persist and retry sync state \(phrase)")
}

assertContains(
    archiveView,
    "repository.syncPendingPublicArchiveItemsToBackend()",
    "archive view should retry unsynced public items before remote refresh"
)
assertContains(
    archiveView,
    "远端暂不可用，已保留本地档案，可稍后自动重试",
    "archive fallback copy should explain local recovery and retry"
)

for phrase in [
    "archiveBackendSyncDisplayName",
    "云端已同步",
    "待同步云端",
    "同步失败，可稍后重试",
    "(\"云端状态\", archiveBackendSyncDisplayName",
] {
    assertContains(display, phrase, "archive display metadata should expose sync recovery state \(phrase)")
}

assertContains(releaseRegression, "archive-sync-error-recovery-check.swift", "release regression should run archive sync recovery guard")
assertContains(releaseQA, "archive-sync-error-recovery-check.swift", "release QA package should include archive sync recovery guard")
assertContains(prdCoverage, "档案文字 / 照片同步失败恢复", "PRD coverage should record archive sync recovery")
assertContains(closureDecisions, "上传/同步失败后的错误恢复", "PRD decisions should preserve archive sync recovery target")
assertContains(statusDoc, "Archive Sync Error Recovery", "status doc should document archive sync recovery")
assertContains(statusDoc, "公开 MVP 仅文字和照片", "status doc should preserve public MVP scope")
assertContains(statusDoc, "隐藏媒体不默认同步", "status doc should keep hidden media out of public sync recovery")
assertContains(statusDoc, "下次远端刷新前自动重试", "status doc should document retry timing")

print("Archive sync error recovery checks passed")
