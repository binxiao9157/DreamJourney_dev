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
let mediaStore = read("DreamJourney/Sources/Modules/Archive/ArchiveMediaStore.swift")
let localStorage = read("DreamJourney/Sources/Modules/Archive/ArchiveLocalStorage.swift")
let repository = read("DreamJourney/Sources/Modules/Archive/MemoryArchiveRepository.swift")
let detail = read("DreamJourney/Sources/Modules/Archive/MemoryArchiveDetailViewController.swift")
let archive = read("DreamJourney/Sources/Modules/Archive/MemoryArchiveViewController.swift")
let display = read("DreamJourney/Sources/Modules/Archive/MemoryArchiveDisplayMetadata.swift")
let modelSmoke = read("Scripts/QA/product-v4/archive-local-storage-model-smoke.swift")
let mediaStoreSmoke = read("Scripts/QA/product-v4/archive-media-store-model-smoke.swift")

for required in [
    "localPath: nil,",
    "removingRemoteLocalMediaMetadata",
    "resolvedLocalFilePath",
    "hasResolvedLocalFile",
    "ArchiveMediaStore.shared.resolvedFileURL",
    "archiveOwnerId: ownerUserId",
    "var needsLocalPathRecovery: Bool {\n        false",
    "func updatingRecoveredLocalPathIfNeeded() -> MemoryArchiveItem {\n        self",
] {
    assertContains(item, required, "archive item should fail closed for untrusted local paths \(required)")
}

for required in [
    ".applicationSupportDirectory",
    "scope.mediaDirectoryRelativePath",
    "UUID().uuidString",
    "guard !relativePath.hasPrefix(\"/\")",
    "Array(relativeComponents.dropLast()) == expectedDirectoryComponents",
    "relativeComponents.allSatisfy({ !$0.isEmpty && $0 != \".\" && $0 != \"..\" })",
    "Self.isUUIDFileName(fileName)",
    "Self.isDescendant(resolvedCandidateURL, of: resolvedDirectoryURL)",
    "Self.fileSize(at: fileURL, fileManager: fileManager) == metadata.sizeBytes",
    "Self.sha256(of: fileURL) == metadata.sha256",
    "ArchiveMediaStoreError.scopeMismatch",
    "ArchiveMediaStoreError.sizeMismatch",
    "ArchiveMediaStoreError.checksumMismatch",
    "currentScopeResolver(normalizedOwner)",
    "values.isExcludedFromBackup = true",
    ".protectionKey: FileProtectionType.complete",
    "func migrateLegacyOriginal(",
    "receipt.migratedItemIds.contains(item.id)",
] {
    assertContains(mediaStore, required, "archive media store must enforce scoped storage \(required)")
}

for forbidden in [
    ".documentDirectory",
    "enumerator(at:",
    "subpathsOfDirectory(atPath:",
    "archiveLocalDirectoryNames",
    "candidateDirectoryNames",
] {
    assertNotContains(mediaStore, forbidden, "archive media store must not search globally by basename")
}

for required in [
    "let validLocalItems = localItems.filter { normalizedOwner($0.ownerUserId) == expectedOwner }",
    "let validRemoteItems = remoteItems.filter { normalizedOwner($0.ownerUserId) == expectedOwner }",
    "let selected = remoteItem.updatedAt >= localItem.updatedAt ? remoteItem : localItem",
] {
    assertContains(localStorage, required, "archive merge must reject cross-owner localPath inheritance")
}

for forbidden in [
    "archiveLocalDirectoryNames",
    "candidateDirectoryNames",
    ".documentDirectory",
    "updatingRecoveredLocalPathIfNeeded()",
    "needsLocalPathRecovery",
] {
    assertNotContains(repository, forbidden, "repository must not perform implicit path recovery")
}

for forbidden in [
    "archiveLocalDirectoryNames",
    "candidateDirectoryNames",
] {
    assertNotContains(item, forbidden, "archive item must not recover by global basename")
}

for required in [
    "let sharedBasename =",
    "scopeBRelativePath",
    "scope mismatch must not recover a same-basename file",
    "let checksumMismatch = ArchiveMediaMetadata(",
    "remote localPath must be ignored",
    "ArchiveMediaStoreError.fileMissing",
] {
    assertContains(modelSmoke, required, "model smoke must cover fail-closed recovery \(required)")
}

for required in [
    "owner scope must change the media directory",
    "vault scope must change the media directory",
    "persisted media path must remain relative",
    "media file name must be a UUID",
    "persisted SHA256 must match written bytes",
    "persisted byteCount must match written bytes",
    "same basename must resolve only inside its own scope",
    "absolute paths must be rejected",
    "path traversal must be rejected",
    "symlink traversal must be rejected",
    "same-length tamper must fail SHA256 validation",
    "byteCount tamper must fail size validation",
    "cross-owner localPath must not be inherited",
    "deleted media must not recover by global basename search",
    "account purge must reject absolute directory paths",
    "account purge must reject traversal directory paths",
    "account-scoped purge must delete every A media class",
    "account-scoped purge must preserve every B media class",
] {
    assertContains(mediaStoreSmoke, required, "media store smoke must cover scoped fail-closed behavior \(required)")
}

for forbidden in [
    "item.localPath.flatMap { UIImage(contentsOfFile: $0) }",
    "guard let localPath = item.localPath,\n              let image = UIImage(contentsOfFile: localPath)",
    "guard let localPath = item.localPath else { return }",
] {
    assertNotContains(detail, forbidden, "archive detail must not load media from raw localPath")
}
assertContains(
    detail,
    "item.resolvedLocalFilePath.flatMap { UIImage(contentsOfFile: $0) }",
    "archive detail should render photos only from validated local media"
)
assertContains(
    detail,
    "guard let localPath = item.resolvedLocalFilePath",
    "archive detail should retry analysis/playback only from validated local media"
)

assertNotContains(
    archive,
    "item.localPath.flatMap { UIImage(contentsOfFile: $0) }",
    "archive list should not load photo thumbnails from raw localPath"
)
assertContains(
    archive,
    "item.resolvedLocalFilePath.flatMap { UIImage(contentsOfFile: $0) }",
    "archive list should render thumbnails only from validated local media"
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
    "archive metadata should report local saved state only for validated media"
)

print("Archive scoped local file path checks passed")
