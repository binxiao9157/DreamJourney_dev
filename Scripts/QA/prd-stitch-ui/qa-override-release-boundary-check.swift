import Foundation

private func read(_ relativePath: String) -> String {
    let root = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
    let url = root.appendingPathComponent(relativePath)
    guard let value = try? String(contentsOf: url, encoding: .utf8) else {
        fatalError("Missing file: \(relativePath)")
    }
    return value
}

private func require(_ condition: @autoclosure () -> Bool, _ message: String) {
    guard condition() else { fatalError(message) }
}

let flags = read("DreamJourney/Sources/App/FeatureFlagService.swift")
let appDelegate = read("DreamJourney/Sources/AppDelegate.swift")
let echo = read("DreamJourney/Sources/Modules/Echo/EchoViewController.swift")
let backendClient = read("DreamJourney/Sources/Services/DreamJourneyBackendClient.swift")
let archiveReadiness = read("DreamJourney/Sources/Modules/Archive/MemoryArchiveMediaReleaseReadiness.swift")
let profileReadiness = read("DreamJourney/Sources/Modules/Profile/ProfileFamilyPersonaReleaseReadiness.swift")
let infoPlist = read("DreamJourney/Resources/Info.plist")
let artifactScanner = read("Scripts/QA/prd-stitch-ui/run-release-qa-override-artifact-scan.sh")
let releaseRegression = read("Scripts/QA/prd-stitch-ui/run-release-regression.sh")

require(
    flags.contains("#if DEBUG || UI_QA_SIMULATOR\n    func enableForCurrentLaunch"),
    "the QA setter must not exist in a production Release compilation"
)
require(
    flags.contains("private var transientEnabled: Set<DJFeature> = []"),
    "QA overrides must remain process memory only"
)
require(
    !appDelegate.contains("FeatureFlagService.shared.set(.archiveRemoteFetch, enabled: true)"),
    "UIQA launch arguments must never call the persistent setter"
)
require(
    appDelegate.contains("FeatureFlagService.shared.enableForCurrentLaunch(.archiveRemoteFetch)"),
    "remote-fetch UIQA must use the process-only setter"
)
for token in [
    "shouldShowEchoRuntimeDiagnosticsPanel",
    "shouldRunTencentDigitalHumanTextDriveSmoke",
    "shouldRunTencentDigitalHumanPCMDriveSmoke",
    "shouldRunTencentDigitalHumanBackendPCMDriveSmoke",
    "shouldRunTencentBackendPCMDriveMockSmoke",
    "shouldRunTencentDigitalHumanPCMDriveStopProbe",
] {
    guard let range = echo.range(of: "private var \(token): Bool") else {
        fatalError("Missing Echo QA boundary: \(token)")
    }
    let tail = String(echo[range.lowerBound...].prefix(800))
    require(tail.contains("#if DEBUG || UI_QA_SIMULATOR"), "\(token) must be compile-time gated")
    require(tail.contains("#else\n        return false\n        #endif"), "\(token) must return false in Release")
}
require(
    backendClient.contains("#if DEBUG || UI_QA_SIMULATOR\n        ProcessInfo.processInfo.arguments.contains(localAssetVirtualmanKeyOverrideArgument)"),
    "the local Tencent asset override must be compile-time gated"
)
require(
    backendClient.contains("ProcessInfo.processInfo.environment[localAssetVirtualmanKeyEnvironmentKey]"),
    "the local Tencent asset override must be supplied by the current QA process"
)
require(
    !infoPlist.contains("DreamJourneyDigitalHumanAssetVirtualmanKey"),
    "the local Tencent asset override must not persist in the application plist"
)
require(
    archiveReadiness.contains("#if DEBUG || UI_QA_SIMULATOR\n    static let hiddenBranchesLaunchArgument = \"DJEnableArchiveHiddenBranches\""),
    "archive QA argument must compile to an empty value in Release"
)
require(
    profileReadiness.contains("#if DEBUG || UI_QA_SIMULATOR\n    static let hiddenBranchesLaunchArgument = \"DJEnableProfileHiddenBranches\""),
    "profile QA argument must compile to an empty value in Release"
)
require(
    artifactScanner.contains("CONFIGURATION=Release"),
    "the artifact gate must build an iPhoneOS Release application"
)
require(
    artifactScanner.contains("DreamJourneyDigitalHumanAssetVirtualmanKey"),
    "the artifact gate must reject the legacy persistent Tencent asset override"
)
require(
    releaseRegression.contains("RUN_RELEASE_QA_OVERRIDE_ARTIFACT_SCAN=1"),
    "release handoff must force the QA override artifact gate"
)

print("QA override Release boundary checks passed")
