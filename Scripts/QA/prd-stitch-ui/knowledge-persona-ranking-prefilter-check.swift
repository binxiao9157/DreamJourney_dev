import Foundation

let root = URL(fileURLWithPath: CommandLine.arguments.dropFirst().first ?? FileManager.default.currentDirectoryPath)
let sourceURL = root.appendingPathComponent("DreamJourney/Sources/Services/KBLiteManager.swift")
guard let source = try? String(contentsOf: sourceURL, encoding: .utf8) else {
    fatalError("Unable to read \(sourceURL.path)")
}

func require(_ token: String, _ message: String) {
    guard source.contains(token) else { fatalError("\(message): missing \(token)") }
}

func requireOrder(_ first: String, _ second: String, _ message: String) {
    guard let firstRange = source.range(of: first),
          let secondRange = source.range(of: second),
          firstRange.lowerBound < secondRange.lowerBound else {
        fatalError("\(message): expected \(first) before \(second)")
    }
}

require("private func semanticSearchSnapshot()", "search must capture graph and cache scope atomically")
require("private func generationSearchCandidates(", "generation context needs a persona-visible candidate graph")
require("let rankingCandidates = generationAllowedOnly", "generation context must choose prefiltered ranking candidates")
require("graphSnapshot: rankingCandidates", "semantic and keyword ranking must receive the prefiltered snapshot")
require("guard let contextScope = searchSnapshot.scope", "generation context must bind the captured account scope")
require("!isCurrentSemanticCacheScope(contextScope)", "context fallback must reject a switched account snapshot")
require("private func search(\n        query: String,\n        graphSnapshot: KBLiteGraph,", "search core must not reread mutable graph state")
require("let people = result.people.filter", "ranking results must retain defense-in-depth filtering")
requireOrder(
    "let rankingCandidates = generationAllowedOnly",
    "graphSnapshot: rankingCandidates",
    "persona/privacy/evidence candidates must be built before ranking"
)

print("Knowledge persona ranking prefilter checks passed")
