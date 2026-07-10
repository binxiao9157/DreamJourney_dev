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
        fputs("Digital-human session lease check failed: \(message)\n", stderr)
        exit(1)
    }
}

func functionBody(_ signature: String, in source: String) -> String {
    guard let signatureRange = source.range(of: signature),
          let openBrace = source[signatureRange.lowerBound...].firstIndex(of: "{") else {
        return ""
    }

    var depth = 0
    var index = openBrace
    while index < source.endIndex {
        let character = source[index]
        if character == "{" {
            depth += 1
        } else if character == "}" {
            depth -= 1
            if depth == 0 {
                return String(source[openBrace...index])
            }
        }
        index = source.index(after: index)
    }
    return ""
}

let client = read("DreamJourney/Sources/Services/DreamJourneyBackendClient.swift")
let echo = read("DreamJourney/Sources/Modules/Echo/EchoViewController.swift")
let releaseRuntime = functionBody("private func releaseDigitalHumanRuntime", in: echo)
let stopCapture = functionBody("private func stopVoiceCapture", in: echo)
let handleSession = functionBody("private func handleCloudDigitalHumanSession", in: echo)

require(
    client.contains("struct DigitalHumanSessionLeaseContract")
        && client.contains("let heartbeatIntervalSeconds: Int")
        && client.contains("let heartbeatEndpoint: String")
        && client.contains("let releaseEndpoint: String"),
    "iOS must parse the backend-issued lease and its operation endpoints"
)
require(
    client.contains("let sessionLease: DigitalHumanSessionLeaseRuntimeCapability"),
    "runtime capability must expose the session-lease contract"
)
require(
    client.contains("func heartbeatDigitalHumanSession(")
        && client.contains("func releaseDigitalHumanSession("),
    "backend client must implement heartbeat and release operations"
)
require(
    echo.contains("activeDigitalHumanSessionContract")
        && echo.contains("digitalHumanSessionHeartbeatWorkItem")
        && echo.contains("scheduleDigitalHumanSessionHeartbeat"),
    "Echo must retain the active lease and schedule heartbeat work"
)
require(
    handleSession.contains("releaseDigitalHumanSessionLease(")
        && handleSession.contains("staleSessionResponse"),
    "a successful stale session response must be released instead of discarded"
)
require(
    releaseRuntime.contains("releaseActiveDigitalHumanSessionLease(reason: reason)"),
    "the unified runtime release path must release the backend lease"
)
require(
    !stopCapture.contains("releaseActiveDigitalHumanSessionLease")
        && !stopCapture.contains("releaseDigitalHumanSessionLease")
        && !stopCapture.contains("releaseDigitalHumanRuntime"),
    "user stop must end the conversation without releasing the digital-human session lease"
)
require(
    echo.contains("digital_human_session_lease_inactive")
        && echo.contains("digital_human_session_capacity_exhausted"),
    "inactive leases and backend capacity conflicts must have explicit handling"
)

print("Digital-human session lease guard passed")
