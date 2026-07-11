import Foundation

let root = URL(fileURLWithPath: CommandLine.arguments.dropFirst().first ?? FileManager.default.currentDirectoryPath)

func read(_ path: String) -> String {
    let url = root.appendingPathComponent(path)
    guard let value = try? String(contentsOf: url, encoding: .utf8) else {
        fatalError("Unable to read \(url.path)")
    }
    return value
}

func require(_ value: String, _ token: String, _ message: String) {
    guard value.contains(token) else { fatalError("\(message): missing \(token)") }
}

func reject(_ value: String, _ token: String, _ message: String) {
    guard !value.contains(token) else { fatalError("\(message): unexpected \(token)") }
}

let policy = read("DreamJourney/Sources/Services/KnowledgeLocalStoragePolicy.swift")
let manager = read("DreamJourney/Sources/Services/KBLiteManager.swift")
let multiUser = read("DreamJourney/Sources/Services/KBLiteMultiUser.swift")
let stores = read("DreamJourney/Sources/Services/KnowledgeThreeWayMerge.swift")
let project = read("DreamJourney.xcodeproj/project.pbxproj")

require(policy, "enum KnowledgeLocalStoragePolicy", "knowledge files need one storage policy")
require(policy, ".completeFileProtectionUntilFirstUserAuthentication", "writes need first-unlock protection")
require(policy, "FileProtectionType.completeUntilFirstUserAuthentication", "final files need explicit protection attributes")
require(policy, "isExcludedFromBackup = true", "knowledge files must be excluded from backup")
require(policy, "case committedWithHardeningWarning", "post-commit hardening failures need an explicit outcome")
require(policy, "postCommitHardeningFailed", "post-commit hardening failures must be observable")
require(policy, "return .committedAndHardened", "successful atomic replacement must report full hardening")

for (source, name) in [(manager, "graph"), (multiUser, "sync history"), (stores, "sync stores")] {
    require(source, "KnowledgeLocalStoragePolicy.write", "\(name) writer must use the shared policy")
    reject(source, "try data.write(to:", "\(name) writer must not bypass the shared policy")
}

require(manager, "KnowledgeLocalStoragePolicy.hardenExistingItem", "existing graph files must be hardened before load")
require(multiUser, "KnowledgeLocalStoragePolicy.hardenExistingItem", "existing sync history must be hardened before load")
require(stores, "KnowledgeLocalStoragePolicy.hardenExistingItem", "existing base/pending/outbox files must be hardened before load")
require(project, "KnowledgeLocalStoragePolicy.swift in Sources", "storage policy must belong to the app target")

print("Knowledge local storage protection checks passed")
