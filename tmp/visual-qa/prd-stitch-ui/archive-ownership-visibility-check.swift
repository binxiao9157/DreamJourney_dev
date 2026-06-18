import Foundation

let root = URL(fileURLWithPath: CommandLine.arguments.dropFirst().first ?? FileManager.default.currentDirectoryPath)

func read(_ relativePath: String) -> String {
    let fileURL = root.appendingPathComponent(relativePath)
    guard let content = try? String(contentsOf: fileURL, encoding: .utf8) else {
        fatalError("Unable to read \(fileURL.path)")
    }
    return content
}

func assertContains(_ haystack: String, _ needle: String, _ message: String) {
    guard haystack.contains(needle) else {
        fatalError("\(message): missing \(needle)")
    }
}

let item = read("DreamJourney/Sources/Modules/Archive/MemoryArchiveItem.swift")
let factory = read("DreamJourney/Sources/Modules/Archive/MemoryArchiveItemFactory.swift")
let repository = read("DreamJourney/Sources/Modules/Archive/MemoryArchiveRepository.swift")
let detail = read("DreamJourney/Sources/Modules/Archive/MemoryArchiveDetailViewController.swift")
let releaseQA = read("tmp/visual-qa/prd-stitch-ui/release-qa-package-check.swift")
let releaseRegression = read("tmp/visual-qa/prd-stitch-ui/run-release-regression.sh")

assertContains(item, "let ownerUserId: String", "Archive item should store uploader ownership")
assertContains(item, "case ownerUserId", "Archive item coding should persist uploader ownership")
assertContains(item, "decodeIfPresent(String.self, forKey: .ownerUserId)", "Archive item should decode legacy records safely")
assertContains(item, "func canManage(by userId: String) -> Bool", "Archive item should enforce management ownership")
assertContains(item, "func assigningOwnerIfNeeded(_ ownerUserId: String) -> MemoryArchiveItem", "Archive item should support legacy owner migration")

assertContains(factory, "private static var currentUploaderUserId: String", "Archive factory should resolve current uploader")
assertContains(factory, "ownerUserId: currentUploaderUserId", "Archive factory should assign uploader ownership")

assertContains(repository, "assignOwnerIfNeededForCurrentUser", "Archive repository should migrate legacy local owners")
assertContains(repository, "\"ownerUserId\": item.ownerUserId", "Archive backend sync should include uploader ownership")

assertContains(detail, "canManageCurrentArchiveItem", "Archive detail should centralize management visibility")
assertContains(detail, "item.canManage(by: UserManager.shared.currentUser?.id ?? \"\")", "Archive detail management should depend on current user ownership")
assertContains(detail, "shouldShowLocalAnalysisAction && canManageCurrentArchiveItem", "Archive management affordances should be owner gated")

assertContains(releaseQA, "archive-ownership-visibility-check.swift", "Release QA package should include archive ownership guard")
assertContains(releaseRegression, "archive-ownership-visibility-check.swift", "Release regression should run archive ownership guard")

print("Archive ownership visibility guard passed.")
