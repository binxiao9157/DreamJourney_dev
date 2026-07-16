import Foundation

let root = URL(fileURLWithPath: CommandLine.arguments.dropFirst().first ?? FileManager.default.currentDirectoryPath)

func read(_ relativePath: String) -> String {
    let url = root.appendingPathComponent(relativePath)
    guard let content = try? String(contentsOf: url, encoding: .utf8) else {
        fatalError("Unable to read \(url.path)")
    }
    return content
}

func assertContains(_ source: String, _ needle: String, _ message: String) {
    guard source.contains(needle) else {
        fatalError("\(message): missing \(needle)")
    }
}

func assertNotContains(_ source: String, _ needle: String, _ message: String) {
    guard !source.contains(needle) else {
        fatalError("\(message): unexpected \(needle)")
    }
}

let archive = read("DreamJourney/Sources/Modules/Archive/MemoryArchiveViewController.swift")
let flags = read("DreamJourney/Sources/App/FeatureFlagService.swift")
let matrix = read("docs/superpowers/status/2026-06-17-release-feature-matrix.md")
let releaseRegression = read("Scripts/QA/prd-stitch-ui/run-release-regression.sh")
let releaseQA = read("Scripts/QA/prd-stitch-ui/release-qa-package-check.swift")

assertContains(
    archive,
    "private enum ArchiveKindFilter",
    "archive should model feature cards as category filters instead of duplicate creation buttons"
)
assertContains(
    archive,
    "action: #selector(photoCardTapped)",
    "photo feature card should open the photo archive category"
)
assertNotContains(
    archive,
    "title: \"相册影像\",\n            detail: photoDetail,\n            isLarge: true,\n            action: #selector(selectPhotoTapped)",
    "photo feature card must not directly open the photo picker"
)
assertContains(
    archive,
    "@objc private func photoCardTapped()",
    "archive should have a dedicated photo category action"
)
assertContains(
    archive,
    "applyArchiveKindFilter(.photo)",
    "photo card should filter the timeline to photo memories"
)
assertContains(
    archive,
    "applyArchiveKindFilter(.audio)",
    "audio card should filter the timeline to voice archive entries"
)
assertContains(
    archive,
    "navigationController?.pushViewController(KnowledgeBaseViewController(), animated: true)",
    "persona card should open the persona/knowledge settings surface"
)
assertContains(
    archive,
    "title: \"语音档案\"",
    "voice archive card implementation should remain available for QA"
)
assertContains(
    archive,
    "if isArchiveAudioCreationEnabled {",
    "voice archive card must remain hidden unless its release/QA gate is open"
)
assertContains(
    archive,
    "title: \"人格设定\"",
    "PRD archive feature grid should include persona settings"
)
assertContains(
    archive,
    "private var activeKindFilter: ArchiveKindFilter?",
    "archive should keep timeline category state"
)
assertContains(
    archive,
    "封存新记忆",
    "archive should keep the primary creation CTA"
)
assertContains(
    flags,
    ".personaSettings",
    "persona settings should remain a declared gated capability"
)
assertContains(
    matrix,
    "| `archiveAudioUpload` | hidden |",
    "release matrix should document the voice-archive boundary"
)
assertContains(
    matrix,
    "| `personaSettings` | hidden |",
    "release matrix should document the persona-settings boundary"
)
assertContains(
    releaseRegression,
    "archive-feature-card-ia-check.swift",
    "release regression should run archive feature-card IA guard"
)
assertContains(
    releaseQA,
    "archive-feature-card-ia-check.swift",
    "release QA package should include archive feature-card IA guard"
)

print("Archive feature-card IA checks passed")
