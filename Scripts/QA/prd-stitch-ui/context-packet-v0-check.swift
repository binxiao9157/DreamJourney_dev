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
        fputs("Context Packet v0 guard failed: \(message)\n", stderr)
        exit(1)
    }
}

let backendClient = read("DreamJourney/Sources/Services/DreamJourneyBackendClient.swift")
let echo = read("DreamJourney/Sources/Modules/Echo/EchoViewController.swift")
let releaseRegression = read("Scripts/QA/prd-stitch-ui/run-release-regression.sh")
let releaseQA = read("Scripts/QA/prd-stitch-ui/release-qa-package-check.swift")

require(
    backendClient.contains("struct EchoContextPacket") &&
        backendClient.contains("func buildEchoContextPacket(") &&
        backendClient.contains("\"/context/build\"") &&
        backendClient.contains("isContextBuildConfigured"),
    "backend client should expose EchoContextPacket and /context/build client method"
)

require(
    echo.contains("recordEchoContextPacketForUserTurn(text: text, turnID: turnID)") &&
        echo.contains("[CFLite] context built") &&
        echo.contains("crossScopeArchiveIncluded=\\(packet.crossScopeArchiveIncluded)") &&
        echo.contains("voiceProfileId=\\(packet.voiceProfileId ?? \"none\")") &&
        echo.contains("latencyMs=\\(packet.latencyMs)"),
    "Echo should request context packet for each final user turn and log core trace fields"
)

require(
    releaseRegression.contains("context-packet-v0-check.swift"),
    "release regression should run Context Packet v0 guard"
)

require(
    releaseQA.contains("context-packet-v0-check.swift"),
    "release QA package should include Context Packet v0 guard"
)

print("Context Packet v0 guard passed")
