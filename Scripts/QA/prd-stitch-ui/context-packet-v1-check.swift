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
        fputs("Context Packet v1 guard failed: \(message)\n", stderr)
        exit(1)
    }
}

let backendClient = read("DreamJourney/Sources/Services/DreamJourneyBackendClient.swift")
let echo = read("DreamJourney/Sources/Modules/Echo/EchoViewController.swift")
let releaseRegression = read("Scripts/QA/prd-stitch-ui/run-release-regression.sh")
let releaseQA = read("Scripts/QA/prd-stitch-ui/release-qa-package-check.swift")

require(
    backendClient.contains("struct EchoContextPacket") &&
        backendClient.contains("struct EchoTraceRecord") &&
        backendClient.contains("func buildEchoContextPacket(") &&
        backendClient.contains("\"/context/build\"") &&
        backendClient.contains("let archiveItemIDs: [String]") &&
        backendClient.contains("let privacyScopeLabel: String") &&
        backendClient.contains("let canUseFamilyData: Bool") &&
        backendClient.contains("isContextBuildConfigured"),
    "backend client should expose EchoContextPacket v1, EchoTraceRecord, and /context/build client method"
)

require(
    echo.contains("recordEchoContextPacketForUserTurn(") &&
        echo.contains("lifecycleToken: lifecycleToken") &&
        echo.contains("allowsGeneration: !self.viewModel.isWaitingForDelayedReply") &&
        echo.contains("private var lastEchoTraceRecord: EchoTraceRecord?") &&
        echo.contains("lastEchoTraceRecord = record") &&
        echo.contains("[CFLite] context built") &&
        backendClient.contains("[CFLite] trace record") &&
        echo.contains("record.logLine") &&
        echo.contains("crossScopeArchiveIncluded=\\(packet.crossScopeArchiveIncluded)") &&
        echo.contains("privacyScope=\\(packet.privacyScopeLabel)") &&
        echo.contains("archiveItemIDs=\\(record.archiveItemIDs.joined(separator: \",\"))") &&
        echo.contains("voiceProfileId=\\(packet.voiceProfileId ?? \"none\")") &&
        echo.contains("latencyMs=\\(packet.latencyMs)"),
    "Echo should request context packet for each final user turn and persist a structured trace record"
)

require(
    releaseRegression.contains("context-packet-v1-check.swift"),
    "release regression should run Context Packet v1 guard"
)

require(
    releaseQA.contains("context-packet-v1-check.swift"),
    "release QA package should include Context Packet v1 guard"
)

print("Context Packet v1 guard passed")
