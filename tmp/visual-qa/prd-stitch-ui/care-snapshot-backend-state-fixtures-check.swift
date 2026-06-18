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

let persistence = read("tmp/visual-qa/prd-stitch-ui/backend-postgres-persistence-check.py")
let releaseLike = read("tmp/visual-qa/prd-stitch-ui/release-like-backend-acceptance-check.swift")
let gapMatrix = read("docs/superpowers/status/2026-06-18-backend-contract-gap-matrix.md")
let status = read("docs/superpowers/status/2026-06-18-release-like-backend-acceptance.md")

for phrase in [
    "careActiveRiskLevel",
    "careMissingStatus",
    "careInvalidStatus",
    "careStaleWindowEnd",
    "missing_user",
    "invalid care snapshot should be rejected",
    "stale care snapshot should preserve stale window",
] {
    assertContains(persistence, phrase, "Postgres persistence check should cover care state fixture \(phrase)")
}

for phrase in [
    "careActiveRiskLevel",
    "careMissingStatus",
    "careInvalidStatus",
    "careStaleWindowEnd",
] {
    assertContains(releaseLike, phrase, "release-like backend guard should require care state field \(phrase)")
}

for phrase in [
    "active / empty / stale / failed",
    "careActiveRiskLevel",
    "careMissingStatus",
    "careInvalidStatus",
    "careStaleWindowEnd",
] {
    assertContains(gapMatrix, phrase, "backend gap matrix should document care state fixture \(phrase)")
    assertContains(status, phrase, "release-like backend status should document care state fixture \(phrase)")
}

print("Care snapshot backend state fixture checks passed")
