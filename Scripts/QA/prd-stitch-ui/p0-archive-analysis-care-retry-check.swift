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

let archiveDisplay = read("DreamJourney/Sources/Modules/Archive/MemoryArchiveDisplayMetadata.swift")
let archiveDetail = read("DreamJourney/Sources/Modules/Archive/MemoryArchiveDetailViewController.swift")
let archiveItem = read("DreamJourney/Sources/Modules/Archive/MemoryArchiveItem.swift")
let archiveRepository = read("DreamJourney/Sources/Modules/Archive/MemoryArchiveRepository.swift")
let profileView = read("DreamJourney/Sources/Modules/Profile/ProfileViewController.swift")
let profileCareModels = read("DreamJourney/Sources/Modules/Profile/ProfileCareModels.swift")
let releaseRegression = read("Scripts/QA/prd-stitch-ui/run-release-regression.sh")
let releaseQA = read("Scripts/QA/prd-stitch-ui/release-qa-package-check.swift")

assertContains(
    archiveDisplay,
    "archiveAnalysisAvailabilityDisplayName",
    "Archive detail metadata should separate cloud sync state from AI analysis availability"
)
assertContains(
    archiveDisplay,
    "AI 分析暂不可用，可稍后重试",
    "Archive detail should show provider fallback as retryable AI analysis failure, not cloud sync failure"
)
assertContains(
    archiveDisplay,
    "(\"AI 分析\", archiveAnalysisAvailabilityDisplayName)",
    "Archive detail metadata should expose a separate AI analysis row"
)

assertContains(
    archiveDetail,
    "requestRemoteImageAnalysisRetry()",
    "Archive retry button should call the backend image-analysis retry path"
)
assertContains(
    archiveDetail,
    "DreamJourneyBackendClient.shared.requestArchiveImageAnalysis(",
    "Archive retry path should call /archive/image-analysis"
)
assertContains(
    archiveDetail,
    "UIImage(contentsOfFile:",
    "Archive retry path should use the original local image when available"
)
assertContains(
    archiveDetail,
    "showToast(\"AI 分析暂不可用，可稍后重试\"",
    "Archive retry path should surface retryable provider fallback copy"
)
assertContains(
    archiveItem,
    "analysisSummary = \"AI 分析暂不可用，可稍后重试。\"",
    "Archive item should not leave stale pending copy after retryable failed analysis"
)

assertContains(
    archiveRepository,
    "allowsArchiveContextClues",
    "Echo archive context should distinguish failed analysis from usable clue fields"
)
assertContains(
    archiveItem,
    "if analysisStatus.isRetryableFailureLike {\n                return normalizedNote.isEmpty ? nil : normalizedNote",
    "Echo archive context should still use user-written notes from failed analysis items"
)
assertContains(
    archiveRepository,
    "people: allowsContextClues ? detectedPeople : []",
    "Echo archive context must not inject people clues from failed analysis"
)
assertContains(
    archiveRepository,
    "locations: allowsContextClues ? detectedLocationClues : []",
    "Echo archive context must not inject location clues from failed analysis"
)
assertContains(
    archiveRepository,
    "scenes: allowsContextClues ? detectedSceneClues : []",
    "Echo archive context must not inject scene clues from failed analysis"
)

assertContains(
    profileCareModels,
    "var isRetryable: Bool",
    "Care data states should expose retryability for empty/stale/failed states"
)
assertContains(
    profileView,
    "makeCareRetryButton()",
    "Profile care card should provide a retry control for non-available care states"
)
assertContains(
    profileView,
    "retryCareSnapshotTapped",
    "Profile care retry control should reload the backend care snapshot"
)
assertContains(
    profileView,
    "return .failedFallback()",
    "Backend care loading failures should map to an explicit failed state"
)
assertContains(
    profileView,
    "profileCareRetryButton",
    "Care retry button should have a stable accessibility identifier for QA"
)

assertContains(
    releaseRegression,
    "p0-archive-analysis-care-retry-check.swift",
    "Release regression should run the P0 archive/care retry guard"
)
assertContains(
    releaseQA,
    "p0-archive-analysis-care-retry-check.swift",
    "Release QA package should include the P0 archive/care retry guard"
)

print("P0 archive analysis and care retry guard passed")
