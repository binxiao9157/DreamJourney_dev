import Foundation

let root = URL(fileURLWithPath: CommandLine.arguments.dropFirst().first ?? FileManager.default.currentDirectoryPath)

func read(_ relativePath: String) -> String {
    let fileURL = root.appendingPathComponent(relativePath)
    guard let content = try? String(contentsOf: fileURL, encoding: .utf8) else {
        fatalError("Unable to read \(fileURL.path)")
    }
    return content
}

func readIfPresent(_ relativePath: String) -> String {
    let fileURL = root.appendingPathComponent(relativePath)
    return (try? String(contentsOf: fileURL, encoding: .utf8)) ?? ""
}

func require(_ condition: Bool, _ message: String) {
    guard condition else {
        fputs("Echo trace evidence package guard failed: \(message)\n", stderr)
        exit(1)
    }
}

let backendClient = read("DreamJourney/Sources/Services/DreamJourneyBackendClient.swift")
let echo = read("DreamJourney/Sources/Modules/Echo/EchoViewController.swift")
let appDelegate = read("DreamJourney/Sources/AppDelegate.swift")
let releaseRegression = read("Scripts/QA/prd-stitch-ui/run-release-regression.sh")
let releaseQA = read("Scripts/QA/prd-stitch-ui/release-qa-package-check.swift")
let uiqaSmoke = read("Scripts/QA/prd-stitch-ui/run-echo-trace-evidence-package-export-smoke.sh")
let statusDoc = readIfPresent("docs/superpowers/status/2026-07-02-echo-trace-evidence-package.md")

for required in [
    "struct EchoTraceEvidencePackage",
    "struct EchoContextBuildEvidenceSummary",
    "struct EchoDigitalHumanSessionEvidenceSummary",
    "struct EchoVoiceSynthesisEvidenceSummary",
    "final class EchoTraceEvidencePackageStore",
    "func exportRecentPackages(",
    "echo-trace-evidence-packages.json",
] {
    require(backendClient.contains(required), "backend client should define evidence package support: \(required)")
}

for field in [
    "packageId",
    "turnID",
    "traceRecord",
    "runtimeDiagnostics",
    "contextBuild",
    "digitalHumanSession",
    "voiceSynthesis",
    "redactionPolicy",
] {
    require(backendClient.contains("let \(field)"), "EchoTraceEvidencePackage should include \(field)")
}

for forbidden in [
    "audioBase64",
    "appkey",
    "accesstoken",
] {
    let evidencePackageSection = backendClient.components(separatedBy: "struct EchoTraceEvidencePackage").dropFirst().first ?? ""
    require(!evidencePackageSection.contains("let \(forbidden)"), "evidence package must not store raw secret/audio field \(forbidden)")
}

for required in [
    "private var lastDigitalHumanSessionEvidenceSummary",
    "private var lastVoiceSynthesisEvidenceSummary",
    "makeEchoTraceEvidencePackage(",
    "snapshot: EchoRuntimeDiagnosticsSnapshot?",
    "source: String",
    "EchoTraceEvidencePackageStore.shared.record(package)",
    "EchoDigitalHumanSessionEvidenceSummary(contract:",
    "EchoVoiceSynthesisEvidenceSummary(synthesis:",
    "runUIQAEchoTraceEvidencePackageExportSmoke",
    "EchoTraceEvidencePackageStore.shared.exportRecentPackages",
] {
    require(echo.contains(required), "Echo should build/export evidence package: \(required)")
}

for required in [
    "DJRunEchoTraceEvidencePackageExportSmoke",
    "runEchoTraceEvidencePackageExportSmoke",
    "writeEchoTraceEvidencePackageExportSmokeResult",
    "echo-trace-evidence-package-export-smoke-result.json",
] {
    require(appDelegate.contains(required), "AppDelegate should expose evidence package UIQA smoke: \(required)")
}

require(
    releaseRegression.contains("echo-trace-evidence-package-check.swift"),
    "release regression should run evidence package guard"
)

require(
    releaseRegression.contains("RUN_ECHO_TRACE_EVIDENCE_PACKAGE_EXPORT_SMOKE") &&
        releaseRegression.contains("run-echo-trace-evidence-package-export-smoke.sh"),
    "release regression should expose optional evidence package UIQA smoke"
)

require(
    releaseQA.contains("echo-trace-evidence-package-check.swift"),
    "release QA package should include evidence package guard"
)

require(
    releaseQA.contains("run-echo-trace-evidence-package-export-smoke.sh"),
    "release QA package should include evidence package UIQA smoke"
)

for required in [
    "run-installable-simulator-uiqa.sh",
    "DJRunEchoTraceEvidencePackageExportSmoke",
    "echo-trace-evidence-package-export-smoke-result.json",
    "echo-trace-evidence-packages.json",
    "uiqa-evidence-turn-2",
    "uiqa-evidence-turn-21",
    "audioBase64",
    "appkey",
    "accesstoken",
] {
    require(uiqaSmoke.contains(required), "evidence package UIQA smoke should verify \(required)")
}

for required in [
    "Echo trace 证据包",
    "iOS runtime diagnostics",
    "/context/build",
    "/digital-human/sessions",
    "/voice/synthesis",
    "不导出 raw audio",
    "不导出 appkey/accesstoken",
] {
    require(statusDoc.contains(required), "status doc should document \(required)")
}

print("Echo trace evidence package guard passed")
