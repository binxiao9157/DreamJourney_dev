import Foundation

let root = URL(fileURLWithPath: CommandLine.arguments.dropFirst().first ?? FileManager.default.currentDirectoryPath)

func read(_ relativePath: String) -> String {
    let fileURL = root.appendingPathComponent(relativePath)
    guard let content = try? String(contentsOf: fileURL, encoding: .utf8) else {
        fatalError("Unable to read \(fileURL.path)")
    }
    return content
}

func extractFeatures(_ source: String, marker: String) -> Set<String> {
    guard let start = source.range(of: marker)?.upperBound,
          let end = source[start...].range(of: "]")?.lowerBound else {
        fatalError("Unable to find \(marker)")
    }
    let body = String(source[start..<end])
    let regex = try! NSRegularExpression(pattern: "\\.([A-Za-z0-9_]+)")
    let range = NSRange(body.startIndex..<body.endIndex, in: body)
    return Set(regex.matches(in: body, range: range).compactMap { match in
        guard let resultRange = Range(match.range(at: 1), in: body) else { return nil }
        return String(body[resultRange])
    })
}

func require(_ condition: @autoclosure () -> Bool, _ message: String) {
    guard condition() else { fatalError(message) }
}

let flags = read("DreamJourney/Sources/App/FeatureFlagService.swift")
let profileReadiness = read("DreamJourney/Sources/Modules/Profile/ProfileFamilyPersonaReleaseReadiness.swift")
let archiveReadiness = read("DreamJourney/Sources/Modules/Archive/MemoryArchiveMediaReleaseReadiness.swift")
let echo = read("DreamJourney/Sources/Modules/Echo/EchoViewController.swift")
let matrix = read("docs/superpowers/status/2026-06-17-release-feature-matrix.md")

let defaults = extractFeatures(
    flags,
    marker: "private static let defaultEnabled: Set<DJFeature> = ["
)
let nonPersistent = extractFeatures(
    flags,
    marker: "private static let nonPersistentFeatures: Set<DJFeature> = ["
)
let expectedDefaults: Set<String> = [
    "echoTextInput",
    "profileSettings",
    "legalCenter",
    "accountDeletion",
]
let futureOrBeta: Set<String> = [
    "echoImageInput",
    "timeLetters",
    "personaSettings",
    "archiveAudioUpload",
    "archiveVideoUpload",
    "archiveRemoteFetch",
    "archiveLocalAnalysis",
    "familyManagement",
    "familySpace",
    "accountPasswordChange",
    "careDashboard",
    "careDoctorContact",
    "voiceCloneShell",
    "digitalHumanLivePanel",
]

require(defaults == expectedDefaults, "Release defaults must contain only the V4 owner core")
require(futureOrBeta.isSubset(of: nonPersistent), "Future/Beta features must never persist as release authority")
require(defaults.isDisjoint(with: futureOrBeta), "Future/Beta features must be hidden by default")
require(flags.contains("private static let currentStorageVersion = 11"), "old persisted flags must be invalidated")
require(flags.contains("#if DEBUG || UI_QA_SIMULATOR"), "QA overrides must be compile-time restricted")
require(flags.contains("func enableForCurrentLaunch(_ feature: DJFeature)"), "QA should retain a process-only override")

for feature in ["familyManagement", "familySpace", "voiceCloneShell"] {
    require(
        profileReadiness.contains("feature: .\(feature),\n        stage: .hiddenReady("),
        "\(feature) readiness must be hidden in the V4 baseline"
    )
}
require(
    archiveReadiness.contains("case .timeLetter:\n            return .hiddenReady("),
    "time letters must remain implemented but hidden"
)
require(
    echo.contains("private var isDigitalHumanQAOverrideEnabled: Bool"),
    "digital-human launch arguments must be isolated behind a QA-only helper"
)

for heading in [
    "| Feature | Public status | Internal status | Decision gate | External gate | Route policy |",
    "## V4 Closed Pilot Baseline",
    "## QA-only Overrides",
] {
    require(matrix.contains(heading), "release matrix missing \(heading)")
}
for feature in futureOrBeta {
    require(matrix.contains("| `\(feature)` | hidden |"), "release matrix must mark \(feature) hidden")
}

print("Future/Beta default-deny guard passed")
