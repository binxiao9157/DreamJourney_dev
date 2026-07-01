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
        fputs("Echo Trace export guard failed: \(message)\n", stderr)
        exit(1)
    }
}

let backendClient = read("DreamJourney/Sources/Services/DreamJourneyBackendClient.swift")
let echo = read("DreamJourney/Sources/Modules/Echo/EchoViewController.swift")
let appDelegate = read("DreamJourney/Sources/AppDelegate.swift")
let releaseRegression = read("Scripts/QA/prd-stitch-ui/run-release-regression.sh")
let releaseQA = read("Scripts/QA/prd-stitch-ui/release-qa-package-check.swift")
let uiqaSmoke = read("Scripts/QA/prd-stitch-ui/run-echo-trace-export-uiqa-smoke.sh")

require(
    backendClient.contains("final class EchoTraceStore") &&
        backendClient.contains("static let shared = EchoTraceStore()") &&
        backendClient.contains("private let maximumRecordCount = 20") &&
        backendClient.contains("func record(_ record: EchoTraceRecord)") &&
        backendClient.contains("func recentRecords() -> [EchoTraceRecord]") &&
        backendClient.contains("func exportRecentRecords(") &&
        backendClient.contains("echo-trace-records.json") &&
        backendClient.contains("JSONEncoder()") &&
        backendClient.contains("JSONDecoder()"),
    "EchoTraceStore should persist the latest 20 trace records and export JSON"
)

require(
    echo.contains("EchoTraceStore.shared.record(record)") &&
        echo.contains("runUIQAEchoTraceExportSmoke") &&
        echo.contains("EchoTraceStore.shared.exportRecentRecords") &&
        echo.contains("oldestRetainedTurnID") &&
        echo.contains("uiqa-turn-2") &&
        echo.contains("latestTurnID") &&
        echo.contains("uiqa-turn-21"),
    "Echo should record context traces and expose a UIQA export smoke"
)

require(
    appDelegate.contains("DJRunEchoTraceExportSmoke") &&
        appDelegate.contains("runEchoTraceExportSmoke") &&
        appDelegate.contains("writeEchoTraceExportSmokeResult") &&
        appDelegate.contains("echo-trace-export-smoke-result.json"),
    "AppDelegate should expose Echo trace export UIQA launch arg and result file"
)

require(
    releaseRegression.contains("echo-trace-export-check.swift"),
    "release regression should run Echo trace export guard"
)

require(
    releaseQA.contains("echo-trace-export-check.swift"),
    "release QA package should include Echo trace export guard"
)

require(
    uiqaSmoke.contains("run-installable-simulator-uiqa.sh") &&
        uiqaSmoke.contains("DJRunEchoTraceExportSmoke") &&
        uiqaSmoke.contains("echo-trace-export-smoke-result.json") &&
        uiqaSmoke.contains("echo-trace-records.json") &&
        uiqaSmoke.contains("uiqa-turn-2") &&
        uiqaSmoke.contains("uiqa-turn-21"),
    "Echo trace export UIQA smoke should install the local simulator app and verify exported trace retention"
)

print("Echo Trace export guard passed")
