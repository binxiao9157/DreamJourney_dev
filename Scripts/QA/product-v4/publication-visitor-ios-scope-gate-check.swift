#!/usr/bin/env swift

import Foundation

let root = URL(fileURLWithPath: CommandLine.arguments.dropFirst().first ?? FileManager.default.currentDirectoryPath)

func read(_ relativePath: String) throws -> String {
    try String(contentsOf: root.appendingPathComponent(relativePath), encoding: .utf8)
}

func require(_ condition: @autoclosure () -> Bool, _ message: String) {
    guard condition() else {
        fputs("Publication visitor iOS scope gate failed: \(message)\n", stderr)
        exit(1)
    }
}

let featureFlags = try read("DreamJourney/Sources/App/FeatureFlagService.swift")
let backendClient = try read("DreamJourney/Sources/Services/DreamJourneyBackendClient.swift")
let visitorAccess = try read("DreamJourney/Sources/Services/PublicationVisitorAccess.swift")
let tabCoordinator = try read("DreamJourney/Sources/App/TabCoordinator.swift")
let profile = try read("DreamJourney/Sources/Modules/Profile/ProfileViewController.swift")
let project = try read("DreamJourney.xcodeproj/project.pbxproj")

require(
    featureFlags.contains("case publicationVisitorM2")
        && featureFlags.contains(".publicationVisitorM2,"),
    "M2 visitor feature must be default-off and non-persistent"
)
require(
    visitorAccess.contains("#if DEBUG || UI_QA_SIMULATOR")
        && visitorAccess.contains("static let launchArgument = \"DJEnablePublicationVisitorM2QA\"")
        && visitorAccess.contains("#else\n        false"),
    "visitor reader must remain compile-time QA gated"
)
require(
    backendClient.contains("/v2/internal/publication-access/")
        && backendClient.contains("X-DreamJourney-QA-Visitor-Access")
        && backendClient.contains("PublicationVisitorM2QAGate.isEnabled"),
    "reader transport must use the explicit QA-only backend boundary"
)
require(
    backendClient.contains("return .publicationVisitorM2"),
    "direct publication access requests must be feature-classified"
)
require(
    visitorAccess.contains("activeScope = nil")
        && visitorAccess.contains("activeProjection = nil")
        && !visitorAccess.contains("UserDefaults")
        && !visitorAccess.contains(": Codable"),
    "visitor scope must stay in memory and clear its projection with its credential"
)
require(
    visitorAccess.contains("identityDisclosureRequired")
        && visitorAccess.contains("!privateContextAllowed")
        && visitorAccess.contains("!providerCallAllowed")
        && visitorAccess.contains("unknownFallbackRequired"),
    "reader must reject a response that permits private context or provider inference"
)

for forbiddenSymbol in [
    "EchoViewController",
    "DigitalHumanContextStore",
    "DialogEngineManager",
    "TencentDigitalHuman",
    "VoiceClone",
    "KBLite",
    "MemoryRepository",
    "getPublicByOwner",
] {
    require(
        !visitorAccess.contains(forbiddenSymbol),
        "visitor reader must not depend on private runtime symbol \(forbiddenSymbol)"
    )
}

require(
    !tabCoordinator.contains("PublicationVisitor")
        && !profile.contains("PublicationVisitor"),
    "P2-S3a must not add a release navigation entry"
)
require(
    project.contains("PublicationVisitorAccess.swift in Sources")
        && project.contains("PublicationVisitorAccessTests.swift in Sources"),
    "visitor source and tests must be in Xcode targets"
)

print("Publication visitor iOS scope gate passed")
