import Foundation

let arguments = CommandLine.arguments
guard arguments.count == 2 else {
    fatalError("usage: owner-truth-media-public-admission-check.swift <repo-root>")
}

let root = URL(fileURLWithPath: arguments[1], isDirectory: true)

func source(_ path: String) -> String {
    let url = root.appendingPathComponent(path)
    guard let value = try? String(contentsOf: url, encoding: .utf8) else {
        fatalError("unable to read \(path)")
    }
    return value
}

func require(_ condition: @autoclosure () -> Bool, _ message: String) {
    guard condition() else {
        fputs("Owner Truth media public admission check failed: \(message)\n", stderr)
        exit(1)
    }
}

let runtime = source("DreamJourney/Sources/Services/OwnerTruthMediaRuntimeCapability.swift")
let client = source("DreamJourney/Sources/Services/DreamJourneyBackendClient.swift")
let archive = source("DreamJourney/Sources/Modules/Archive/MemoryArchiveViewController.swift")

require(
    runtime.contains("snapshot.provider != \"filesystem\" && snapshot.isPubliclyAvailable"),
    "public capture must require external verification and reject filesystem"
)
require(
    runtime.contains("releasePolicyReason == \"closedPilotOwnerCore\"")
        && runtime.contains("canOpenCaptureWithInternalEntitlement"),
    "internal runtime readiness must remain separate from public readiness"
)
require(
    client.contains("ownerTruthMediaAdmissionDecision(")
        && client.contains("OwnerTruthMediaRuntimeCapability.isCaptureAllowed(")
        && client.contains("OwnerTruthMediaRuntimeCapability.isProcessingAllowed("),
    "media requests must revalidate typed runtime admission"
)
require(
    archive.contains("captureServerPolicyManagedRoute(")
        && archive.contains("OwnerTruthMediaRuntimeCapability.isCaptureAllowed("),
    "ordinary archive entry must require policy and public runtime readiness"
)

print("Owner Truth media public admission check passed")
