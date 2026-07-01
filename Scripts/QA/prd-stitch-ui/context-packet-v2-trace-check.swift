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
        fputs("Context Packet v2 trace guard failed: \(message)\n", stderr)
        exit(1)
    }
}

let backendClient = read("DreamJourney/Sources/Services/DreamJourneyBackendClient.swift")
let releaseRegression = read("Scripts/QA/prd-stitch-ui/run-release-regression.sh")
let releaseQA = read("Scripts/QA/prd-stitch-ui/release-qa-package-check.swift")

for required in [
    "let contextVersion: String",
    "let selectedContextRefs: [String]",
    "let filteredContextReasons: [String]",
    "let selectedContextCount: Int",
    "let filteredContextCount: Int",
    "let rankingTraceCount: Int",
    "let selectedContextSourceCounts: [String: Int]",
    "selectedContext",
    "filteredContext",
    "rankingTrace",
] {
    require(backendClient.contains(required), "EchoContextPacket/EchoTraceRecord should preserve \(required)")
}

for required in [
    "contextVersion: packet.contextVersion",
    "selectedContextRefs: packet.selectedContextRefs",
    "filteredContextReasons: packet.filteredContextReasons",
    "rankingTraceCount: packet.rankingTraceCount",
    "selectedContextSourceCounts: packet.selectedContextSourceCounts",
] {
    require(backendClient.contains(required), "EchoTraceRecord packet initializer should copy \(required)")
}

for required in [
    "self.contextVersion = record?.contextVersion",
    "self.selectedContextRefs = record?.selectedContextRefs",
    "self.filteredContextReasons = record?.filteredContextReasons",
    "self.rankingTraceCount = record?.rankingTraceCount",
    "self.selectedContextSourceCounts = record?.selectedContextSourceCounts",
] {
    require(backendClient.contains(required), "evidence summary should export \(required)")
}

for required in [
    "kbFact",
    "persona",
    "care",
    "selectedContextSourceCounts",
] {
    require(releaseRegression.contains(required), "release regression/docs should mention V2 source signal \(required)")
}

require(
    releaseRegression.contains("context-packet-v2-trace-check.swift"),
    "release regression should run Context Packet v2 trace guard"
)

for required in [
    "RUN_ECHO_CONTEXT_BUILDER_V2_SMOKE",
    "run-echo-context-builder-v2-smoke.sh",
    "echo-context-builder-v2-smoke",
    "contextVersion=echo-context-v2",
] {
    require(releaseRegression.contains(required), "release regression should expose backend V2 smoke: \(required)")
}

require(
    releaseQA.contains("context-packet-v2-trace-check.swift"),
    "release QA package should include Context Packet v2 trace guard"
)

print("Context Packet v2 trace guard passed")
