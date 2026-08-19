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
let visitorView = try read("DreamJourney/Sources/Modules/Profile/ProfilePublicationVisitorViewController.swift")
let tabCoordinator = try read("DreamJourney/Sources/App/TabCoordinator.swift")
let profile = try read("DreamJourney/Sources/Modules/Profile/ProfileViewController.swift")
let appCoordinator = try read("DreamJourney/Sources/App/AppCoordinator.swift")
let sceneDelegate = try read("DreamJourney/Sources/SceneDelegate.swift")
let project = try read("DreamJourney.xcodeproj/project.pbxproj")

require(
    featureFlags.contains("case publicationVisitorM2")
        && featureFlags.contains(".publicationVisitorM2,"),
    "M2 visitor feature must be default-off and non-persistent"
)
require(
    visitorAccess.contains("static let launchArgument = \"DJEnablePublicationVisitorM2QA\"")
        && visitorAccess.contains("PublicationVisitorM2AccessGate")
        && visitorAccess.contains("isServerPolicyManagedRouteAllowed"),
    "visitor must preserve QA access while requiring server policy for the formal shell"
)
require(
    backendClient.contains("/v2/internal/publication-access/")
        && backendClient.contains("/v2/publication-invitations")
        && backendClient.contains("/v2/publication-grants/")
        && backendClient.contains("/v2/publication-sessions/")
        && backendClient.contains("X-DreamJourney-QA-Visitor-Access")
        && backendClient.contains("PublicationVisitorM2AccessGate.isRouteAllowed"),
    "visitor transport must separate QA and formal closed-beta contracts"
)
require(
    backendClient.contains("return .publicationVisitorM2")
        && featureFlags.contains("return \"visitorAccess\"")
        && featureFlags.contains("return \"visitor\""),
    "formal visitor requests must map to the visitorAccess policy audience"
)
require(
    visitorAccess.contains("activeScope = nil")
        && visitorAccess.contains("activeProjection = nil")
        && visitorAccess.contains("PublicationVisitorInvitationListClient")
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
    "TencentDigitalHuman",
    "VoiceClone",
    "KBLite",
    "MemoryRepository",
    "getPublicByOwner",
] {
    require(
        !visitorAccess.contains(forbiddenSymbol)
            && !visitorView.contains(forbiddenSymbol),
        "visitor shell must not depend on private runtime symbol \(forbiddenSymbol)"
    )
}

require(
    visitorView.contains("EchoNativeSpeechCapture")
        && visitorView.contains("fetchRealtimeVoiceConfig")
        && visitorView.contains("setLocalTTSVoiceSelection(")
        && visitorView.contains("voiceProfileId: nil")
        && visitorView.contains("startTextReplyPlayback")
        && visitorView.contains("profile-publication-visitor-voice-question")
        && !visitorView.contains("TencentDigitalHuman")
        && !visitorView.contains("VoiceClone"),
    "visitor voice must use ordinary realtime playback without clone or digital-human channels"
)

require(
    tabCoordinator.contains("selectPublicationVisitor")
        && profile.contains("ProfilePublicationVisitorViewController")
        && profile.contains("profile-publication-visitor-entry")
        && profile.contains("PublicationVisitorM2AccessGate.isRouteAllowed")
        && !tabCoordinator.contains("viewControllers = [archiveNav, echoNav, profileNav,")
        && visitorView.contains("内容来自本人确认的公开副本")
        && visitorView.contains("fetchVisitorInvitations")
        && visitorView.contains("暂无受邀回忆")
        && visitorView.contains("profile-publication-visitor-shell"),
    "visitor shell must remain a neutral Profile-only surface without a fourth Tab"
)
require(
    appCoordinator.contains("publicationVisitorRuntime.stage(deepLinkURL: url)")
        && appCoordinator.contains("routePendingPublicationVisitorIfPossible")
        && sceneDelegate.contains("receiveAppDeepLink")
        && visitorAccess.contains("pendingInvitation = nil")
        && visitorAccess.contains("admissionGeneration = UUID()"),
    "deep links and stale callbacks must be process-local and account fenced"
)
require(
    project.contains("PublicationVisitorAccess.swift in Sources")
        && project.contains("PublicationVisitorAccessTests.swift in Sources")
        && project.contains("ProfilePublicationVisitorViewController.swift in Sources"),
    "visitor source and tests must be in Xcode targets"
)

print("Publication visitor iOS scope gate passed")
