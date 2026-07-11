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

let search = read("DreamJourney/Sources/Services/KBLiteSemanticSearch.swift")
let manager = read("DreamJourney/Sources/Services/KBLiteManager.swift")

require(search, "private let cacheLock = NSLock()", "semantic cache must serialize mutable state")
require(search, "private var activeScope: KBLiteSemanticCacheScope?", "semantic cache must bind an active scope")
require(search, "func activate(scope: KBLiteSemanticCacheScope?)", "semantic cache must expose lifecycle activation")
require(search, "KBLiteSemanticCachePolicy.accepts", "stale warm/search work must check scope")
require(search, "KBLiteSemanticCacheKey(", "cache lookup must include kind and content fingerprint")
reject(search, "private var isCacheWarm", "a process-global warm flag must not block later users")
reject(search, "embeddingCache[item.id]", "raw entity IDs must not be the complete cache key")

require(manager, "semanticCacheScopeLocked()", "KBLite must capture graph and cache scope under its lock")
require(manager, "KBLiteSemanticSearch.shared.activate(scope:", "KBLite lifecycle must activate or clear cache scope")
require(manager, "Keep manager state and cache activation in the same serialized switch", "concurrent account switches must not reorder cache activation")
require(manager, "scope: semanticScope", "warm and search must pass the captured scope")

print("Knowledge semantic cache isolation checks passed")
