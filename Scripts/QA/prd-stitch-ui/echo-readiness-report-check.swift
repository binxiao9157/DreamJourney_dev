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
        fputs("Echo readiness report guard failed: \(message)\n", stderr)
        exit(1)
    }
}

let script = read("Scripts/QA/prd-stitch-ui/echo-readiness-report.py")
let runner = read("Scripts/QA/prd-stitch-ui/run-echo-readiness-report.sh")
let releaseRegression = read("Scripts/QA/prd-stitch-ui/run-release-regression.sh")
let releaseQA = read("Scripts/QA/prd-stitch-ui/release-qa-package-check.swift")

for required in [
    "\"schemaVersion\": 3",
    "Echo Readiness Report v3",
    "make_echo_trace_summary",
    "make_readiness_gate_result",
    "make_context_clue_summary",
    "make_digital_human_session_summary",
    "make_voice_synthesis_summary",
    "make_fallback_summary",
    "echoTrace",
    "contextClues",
    "digitalHumanSession",
    "voiceSynthesis",
    "fallbackSummary",
    "selectedContextRefsBySource",
    "selectedContextSourceCounts",
    "filteredContextReasons",
    "rankingTraceCount",
    "contextVersion",
    "providerLogId",
    "providerRequestId",
    "voiceProfileId",
    "outputMode",
    "digitalHumanSessionReady",
    "digitalHumanProviderMode",
    "backend.health",
    "backend.runtime",
    "backend.context_build",
    "backend.digital_human_session",
    "backend.voice_synthesis",
    "/context/build",
    "/digital-human/sessions",
    "/voice/synthesis",
    "RUN_READINESS_VOICE_SYNTHESIS",
    "READINESS_STRICT",
    "readinessStatus",
    "readinessReason",
    "requiredCheckNotRun",
    "notRunChecks",
    "gateResult",
    "echo-readiness-report.json",
    "echo-readiness-report.md",
    "local.apns_boundary",
    "local.kblite",
    "local.runtime_diagnostics",
] {
    require(script.contains(required), "readiness script should cover \(required)")
}

require(
    !script.contains("all(check[\"status\"] in (\"passed\", \"skipped\") for check in checks)"),
    "skipped readiness checks must not be treated as completed"
)

for required in [
    "echo-readiness-report.py",
    "BACKEND_BASE_URL",
    "BACKEND_API_TOKEN",
    "RUN_READINESS_VOICE_SYNTHESIS",
    "READINESS_STRICT",
] {
    require(runner.contains(required), "readiness runner should document \(required)")
}

require(
    releaseRegression.contains("RUN_ECHO_READINESS_REPORT") &&
        releaseRegression.contains("run-echo-readiness-report.sh") &&
        releaseRegression.contains("echo-readiness-report-check.swift"),
    "release regression should include optional Echo readiness report and static guard"
)

require(
    releaseQA.contains("run-echo-readiness-report.sh") &&
        releaseQA.contains("echo-readiness-report.py") &&
        releaseQA.contains("echo-readiness-report-check.swift") &&
        releaseQA.contains("echo-readiness-report-strict-contract-check.py"),
    "release QA package should include Echo readiness report assets"
)

print("Echo readiness report guard passed")
