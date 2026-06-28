import Foundation

let root = CommandLine.arguments.dropFirst().first ?? FileManager.default.currentDirectoryPath
let rootURL = URL(fileURLWithPath: root)

func read(_ relativePath: String) -> String {
    let url = rootURL.appendingPathComponent(relativePath)
    return (try? String(contentsOf: url, encoding: .utf8)) ?? ""
}

func fileExists(_ relativePath: String) -> Bool {
    FileManager.default.fileExists(atPath: rootURL.appendingPathComponent(relativePath).path)
}

func require(_ condition: @autoclosure () -> Bool, _ message: String) {
    if !condition() {
        fputs("digital-human-conversation-coordinator-check failed: \(message)\n", stderr)
        exit(1)
    }
}

let coordinatorPath = "DreamJourney/Sources/Modules/Echo/DigitalHumanConversationCoordinator.swift"
require(fileExists(coordinatorPath), "DigitalHumanConversationCoordinator must exist")

let coordinator = read(coordinatorPath)
require(coordinator.contains("final class DigitalHumanConversationCoordinator"), "coordinator should be a focused reference type")
require(coordinator.contains("hasProviderSpeechInFlight"), "coordinator should own provider speech in-flight state")
require(coordinator.contains("shouldInterruptOnUserStop"), "coordinator should own stop/interruption semantics")
require(coordinator.contains("beginProviderRequest"), "coordinator should own provider request lifecycle")
require(coordinator.contains("completeProviderRequest"), "coordinator should own provider completion lifecycle")
require(coordinator.contains("markPausingForProviderSpeech"), "coordinator should own provider speech pause/resume flags")
require(coordinator.contains("reset("), "coordinator should provide one reset boundary")

let echo = read("DreamJourney/Sources/Modules/Echo/EchoViewController.swift")
require(echo.contains("digitalHumanConversation"), "EchoViewController should use the coordinator")
for scatteredState in [
    "private var lastDigitalHumanReplyTextSent",
    "private var activeTencentDigitalHumanRequestID",
    "private var pendingTencentDigitalHumanReplyText",
    "private var currentEchoTurnID",
    "private var isPausingDialogForTencentDigitalHumanSpeech",
    "private var shouldResumeDialogAfterTencentDigitalHumanSpeech"
] {
    require(!echo.contains(scatteredState), "EchoViewController should not own scattered digital human state: \(scatteredState)")
}

let project = read("DreamJourney.xcodeproj/project.pbxproj")
require(project.contains("DigitalHumanConversationCoordinator.swift in Sources"), "coordinator should be in the app target")

print("digital-human-conversation-coordinator-check passed")
