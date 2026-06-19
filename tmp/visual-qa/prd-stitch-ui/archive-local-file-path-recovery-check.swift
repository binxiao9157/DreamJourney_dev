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

func assertNotContains(_ haystack: String, _ needle: String, _ message: String) {
    guard !haystack.contains(needle) else {
        fatalError("\(message): unexpected \(needle)")
    }
}

let item = read("DreamJourney/Sources/Modules/Archive/MemoryArchiveItem.swift")
let repository = read("DreamJourney/Sources/Modules/Archive/MemoryArchiveRepository.swift")
let detail = read("DreamJourney/Sources/Modules/Archive/MemoryArchiveDetailViewController.swift")
let archive = read("DreamJourney/Sources/Modules/Archive/MemoryArchiveViewController.swift")
let display = read("DreamJourney/Sources/Modules/Archive/MemoryArchiveDisplayMetadata.swift")

for required in [
    "resolvedLocalFilePath",
    "hasResolvedLocalFile",
    "archiveLocalDirectoryNames",
    "archive-images",
    "archive-audio",
    "archive-video",
    "archive-video-thumbnails",
    "FileManager.default.fileExists(atPath: candidate.path)",
] {
    assertContains(item, required, "archive item should recover stale sandbox local file paths \(required)")
}

assertContains(
    repository,
    "updatingRecoveredLocalPathIfNeeded()",
    "archive repository should migrate recovered local file paths back into persisted items"
)
assertContains(
    repository,
    "needsLocalPathRecovery",
    "archive repository should only save when recovered local paths changed"
)

for forbidden in [
    "item.localPath.flatMap { UIImage(contentsOfFile: $0) }",
    "guard let localPath = item.localPath,\n              let image = UIImage(contentsOfFile: localPath)",
    "guard let localPath = item.localPath else { return }",
] {
    assertNotContains(detail, forbidden, "archive detail should not load media from raw localPath")
}
assertContains(
    detail,
    "item.resolvedLocalFilePath.flatMap { UIImage(contentsOfFile: $0) }",
    "archive detail should render photos from recovered local file path"
)
assertContains(
    detail,
    "guard let localPath = item.resolvedLocalFilePath",
    "archive detail should retry analysis/playback from recovered local file path"
)

assertNotContains(
    archive,
    "item.localPath.flatMap { UIImage(contentsOfFile: $0) }",
    "archive list should not load photo thumbnails from raw localPath"
)
assertContains(
    archive,
    "item.resolvedLocalFilePath.flatMap { UIImage(contentsOfFile: $0) }",
    "archive list should render thumbnails from recovered local file path"
)

for forbidden in [
    "localPath == nil ? nil : \"本地已保存\"",
    "localPath == nil ? \"未保存本地文件\" : \"本地已保存\"",
] {
    assertNotContains(display, forbidden, "archive metadata should not claim saved local file without existence check")
}
assertContains(
    display,
    "hasResolvedLocalFile ? \"本地已保存\"",
    "archive metadata should report local saved state from recovered/existing file path"
)

print("Archive local file path recovery checks passed")
