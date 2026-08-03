import Foundation

let root = URL(fileURLWithPath: CommandLine.arguments.dropFirst().first ?? FileManager.default.currentDirectoryPath)

func read(_ relativePath: String) -> String {
    let fileURL = root.appendingPathComponent(relativePath)
    guard let content = try? String(contentsOf: fileURL, encoding: .utf8) else {
        fatalError("Unable to read \(fileURL.path)")
    }
    return content
}

func assertContains(_ source: String, _ needle: String, _ message: String) {
    guard source.contains(needle) else {
        fatalError("\(message): missing \(needle)")
    }
}

func assertNotContains(_ source: String, _ needle: String, _ message: String) {
    guard !source.contains(needle) else {
        fatalError("\(message): unexpected \(needle)")
    }
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
        guard let valueRange = Range(match.range(at: 1), in: body) else { return nil }
        return String(body[valueRange])
    })
}

let flags = read("DreamJourney/Sources/App/FeatureFlagService.swift")
let archive = read("DreamJourney/Sources/Modules/Archive/MemoryArchiveViewController.swift")
let archiveOptions = read("DreamJourney/Sources/Modules/Archive/MemoryArchiveCreationOption.swift")
let archiveReadiness = read("DreamJourney/Sources/Modules/Archive/MemoryArchiveMediaReleaseReadiness.swift")
let echo = read("DreamJourney/Sources/Modules/Echo/EchoViewController.swift")
let profile = read("DreamJourney/Sources/Modules/Profile/ProfileViewController.swift")
let profileReadiness = read("DreamJourney/Sources/Modules/Profile/ProfileFamilyPersonaReleaseReadiness.swift")
let settings = read("DreamJourney/Sources/Modules/Profile/ProfileSettingsViewController.swift")
let legal = read("DreamJourney/Sources/Modules/Profile/ProfileLegalViewController.swift")
let matrix = read("docs/superpowers/status/2026-06-17-release-feature-matrix.md")
let infoPlist = read("DreamJourney/Resources/Info.plist")
let sceneDelegate = read("DreamJourney/Sources/SceneDelegate.swift")
let appCoordinator = read("DreamJourney/Sources/App/AppCoordinator.swift")
let accountLease = read("DreamJourney/Sources/App/AccountLease.swift")
let releaseRegression = read("Scripts/QA/prd-stitch-ui/run-release-regression.sh")

let ownerCore: Set<String> = [
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

let defaults = extractFeatures(
    flags,
    marker: "private static let defaultEnabled: Set<DJFeature> = ["
)
let nonPersistent = extractFeatures(
    flags,
    marker: "private static let nonPersistentFeatures: Set<DJFeature> = ["
)

guard defaults == ownerCore else {
    fatalError("V4 owner-core defaults changed. Expected \(ownerCore.sorted()), got \(defaults.sorted())")
}
guard futureOrBeta.isSubset(of: nonPersistent) else {
    fatalError("Future/Beta flags must be process-scoped and non-persistent")
}
guard defaults.isDisjoint(with: futureOrBeta) else {
    fatalError("Future/Beta flags must be hidden by default")
}

for feature in ownerCore.union(futureOrBeta) {
    assertContains(flags, "case \(feature)", "feature enum must declare \(feature)")
}
assertContains(flags, "private static let currentStorageVersion = 11", "stale persisted public flags must be invalidated")
assertContains(flags, "subtracting(Self.nonPersistentFeatures)", "stored flags must drop future capabilities")
assertContains(flags, "#if DEBUG || UI_QA_SIMULATOR", "QA overrides must be compile-time restricted")

assertContains(archiveOptions, "var options: [MemoryArchiveCreationOption] = [\n            .text,\n            .photo,\n        ]", "archive creation baseline must remain text/photo")
for feature in ["archiveAudioUpload", "archiveVideoUpload", "archiveRemoteFetch", "timeLetters", "personaSettings"] {
    assertContains(archive, "FeatureFlagService.shared.isEnabled(.\(feature))", "archive route must remain gated by \(feature)")
}
assertContains(archive, "MemoryArchiveMediaReleaseReadiness.isCreationVisible", "archive creation must consume the shared readiness contract")
assertContains(archiveReadiness, "case .timeLetter:\n            return .hiddenReady(", "time letters must remain implemented but hidden")
assertContains(archiveReadiness, "DJEnableArchiveHiddenBranches", "archive QA branches need one explicit launch argument")

assertContains(profile, "FeatureGateService.shared.isRouteAllowed(", "profile routes must use captured policy gates")
assertContains(profile, "isFeatureRouteAllowed(.profileSettings", "profile settings route must remain gated")
assertContains(profile, "isFeatureRouteAllowed(.legalCenter", "legal route must remain gated")
assertContains(profile, "isFeatureRouteAllowed(.familyManagement", "family route must remain gated")
assertContains(profile, "isFeatureRouteAllowed(.voiceCloneShell", "voice clone route must remain gated")
assertContains(profile, "isFeatureRouteAllowed(.accountDeletion", "account deletion route must remain gated")
assertContains(profileReadiness, "DJEnableProfileHiddenBranches", "profile QA branches need one explicit launch argument")
assertContains(profileReadiness, "stage: .hiddenReady(", "family and voice capabilities must remain hidden-ready")
assertContains(profileReadiness, "V4 Closed Pilot 暂不公开音色复刻", "voice clone readiness must explain the V4 boundary")

assertContains(echo, "FeatureFlagService.shared.isEnabled(.digitalHumanLivePanel)", "digital human panel must remain feature gated")
assertContains(echo, "private var isDigitalHumanQAOverrideEnabled: Bool", "digital human QA arguments must be isolated")
assertContains(echo, "#if DEBUG || UI_QA_SIMULATOR", "digital human QA arguments must be compile-time restricted")
assertContains(echo, "自动回到普通回响", "digital human failure must retain an ordinary Echo fallback")

assertContains(settings, "ProfileSettingsViewController", "profile settings page must remain implemented")
assertContains(settings, "isPasswordChangeVisible", "password change must remain explicitly gated")
assertContains(legal, "ProfileLegalViewController", "legal center must remain implemented")
assertContains(legal, "AI 辅助说明", "legal center must retain AI disclosure")

for heading in [
    "## V4 Closed Pilot Baseline",
    "| Feature | Public status | Internal status | Decision gate | External gate | Route policy |",
    "## QA-only Overrides",
    "## Gate Interpretation",
    "## Promotion Rule",
] {
    assertContains(matrix, heading, "release matrix must contain the V4 control section")
}
for feature in ownerCore {
    assertContains(matrix, "| `\(feature)` | public-core |", "matrix must mark \(feature) as owner core")
}
for feature in futureOrBeta {
    assertContains(matrix, "| `\(feature)` | hidden |", "matrix must mark \(feature) hidden")
}
for argument in ["DJEnableArchiveHiddenBranches", "DJEnableProfileHiddenBranches", "DJShowDigitalHumanLivePanel"] {
    assertContains(matrix, argument, "matrix must document QA argument \(argument)")
}
assertNotContains(matrix, "enabled by default", "matrix must not preserve the superseded public digital-human policy")
assertNotContains(infoPlist, "CFBundleURLTypes", "Closed Pilot must not register hidden deep links")
assertContains(
    sceneDelegate,
    "receiveNotificationRuntimeDeepLink(context.url)",
    "external URL ingress must only forward to the notification runtime router"
)
assertContains(
    appCoordinator,
    "notificationRuntimeRouteInbox.ingest(deepLinkURL: url)",
    "deep-link ingress must be validated by NotificationRuntimeRouteInbox"
)
assertContains(
    accountLease,
    "payload.matches(accountLease)",
    "deep-link payloads must be account-lease scoped before routing"
)
assertContains(releaseRegression, "RUN_PUBLIC_RELEASE_SCOPE_GATE", "release regression must expose the combined public-scope gate")

print("Release feature matrix checks passed")
