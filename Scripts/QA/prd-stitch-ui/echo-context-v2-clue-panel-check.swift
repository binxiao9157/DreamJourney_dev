import Foundation

let root = URL(fileURLWithPath: CommandLine.arguments.dropFirst().first ?? FileManager.default.currentDirectoryPath)

func read(_ relativePath: String) -> String {
    let fileURL = root.appendingPathComponent(relativePath)
    guard let content = try? String(contentsOf: fileURL, encoding: .utf8) else {
        fatalError("Unable to read \(fileURL.path)")
    }
    return content
}

func require(_ condition: Bool, _ message: String) {
    guard condition else {
        fputs("Echo Context V2 clue panel guard failed: \(message)\n", stderr)
        exit(1)
    }
}

let backendClient = read("DreamJourney/Sources/Services/DreamJourneyBackendClient.swift")
let echo = read("DreamJourney/Sources/Modules/Echo/EchoViewController.swift")
let releaseRegression = read("Scripts/QA/prd-stitch-ui/run-release-regression.sh")
let releaseQA = read("Scripts/QA/prd-stitch-ui/release-qa-package-check.swift")
let panelSmoke = read("Scripts/QA/prd-stitch-ui/run-echo-trace-evidence-package-panel-export-smoke.sh")

for required in [
    "struct EchoContextV2ClueSummary",
    "let selectedContextRefsBySource: [String: [String]]",
    "let archiveRefs: [String]",
    "let kbFactRefs: [String]",
    "let personaRefs: [String]",
    "let careRefs: [String]",
    "let filteredContextReasons: [String]",
    "let rankingTraceCount: Int",
    "let selectedContextSourceCounts: [String: Int]",
    "let fallbacks: [String]",
    "let latencyMs: Int",
    "func panelLines(",
    "func sourceRefs(",
    "使用线索",
    "archive:",
    "kbFact:",
    "persona:",
    "care:",
    "filtered:",
    "ranking:",
    "sources:",
    "fallbacks:",
    "latencyMs:",
] {
    require(backendClient.contains(required), "backend client should preserve Context V2 clue summary: \(required)")
}

for required in [
    "clueSummary",
    "EchoContextV2ClueSummary(record:",
    "selectedContextRefsBySource: packet.selectedContextRefsBySource",
    "self.selectedContextRefsBySource = try container.decodeIfPresent([String: [String]].self",
] {
    require(backendClient.contains(required), "evidence/record coding should include \(required)")
}

for required in [
    "let contextClues = EchoContextV2ClueSummary(record: lastEchoTraceRecord)",
    "contextClues.panelLines(prefix: \"ctx\")",
    "selectedContextSourceCounts",
    "filteredContextReasons",
] {
    require(echo.contains(required), "Echo QA panel should render Context V2 clues: \(required)")
}

for required in [
    "selectedContextRefsBySource",
    "archive_panel_evidence",
    "fact_panel_evidence",
    "persona:personal:uiqa_echo_panel_evidence_user",
    "care:latest",
    "archive_panel_filtered:analysis_failed_empty_context",
    "latestArchiveClues",
    "latestKbFactClues",
    "latestPersonaClues",
    "latestCareClues",
    "latestContextVersion",
    "latestFilteredReasons",
    "latestRankingTraceCount",
] {
    require(echo.contains(required), "UIQA panel smoke data should include clue summary field \(required)")
}

for required in [
    "latestArchiveClues",
    "latestKbFactClues",
    "latestPersonaClues",
    "latestCareClues",
    "latestContextVersion",
    "latestFilteredReasons",
    "latestRankingTraceCount",
] {
    require(panelSmoke.contains(required), "panel export smoke should assert result field \(required)")
}

require(
    releaseRegression.contains("echo-context-v2-clue-panel-check.swift"),
    "release regression should run Context V2 clue panel guard"
)

require(
    releaseQA.contains("echo-context-v2-clue-panel-check.swift"),
    "release QA package should include Context V2 clue panel guard"
)

print("Echo Context V2 clue panel guard passed")
