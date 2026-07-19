import Foundation

let root = CommandLine.arguments.dropFirst().first ?? FileManager.default.currentDirectoryPath

func read(_ relativePath: String) -> String {
    let path = "\(root)/\(relativePath)"
    guard let content = try? String(contentsOfFile: path, encoding: .utf8) else {
        fatalError("Unable to read \(path)")
    }
    return content
}

func assertContains(_ haystack: String, _ needle: String, _ message: String) {
    guard haystack.contains(needle) else {
        fatalError("\(message): missing \(needle)")
    }
}

func assertNotContains(_ haystack: String, _ needle: String, _ message: String) {
    guard !haystack.contains(needle) else {
        fatalError("\(message): unexpected \(needle)")
    }
}

let echoView = read("DreamJourney/Sources/Modules/Echo/EchoViewController.swift")
let echoViewModel = read("DreamJourney/Sources/Modules/Echo/EchoViewModel.swift")
let appDelegate = read("DreamJourney/Sources/AppDelegate.swift")
let featureFlags = read("DreamJourney/Sources/App/FeatureFlagService.swift")
let releasePackageCheck = read("Scripts/QA/prd-stitch-ui/release-qa-package-check.swift")

assertContains(echoView, "private let voiceStatusView", "echo should have a compact voice state container")
assertContains(echoView, "private let voiceStatusLabel", "echo should have a compact voice state label")
assertContains(echoView, "private var voiceStatusHeightConstraint", "echo state container should collapse in idle state")
assertContains(echoView, "label.accessibilityIdentifier = \"echoVoiceStatus\"", "voice state should be stable for UI QA")
assertContains(echoView, "private func renderVoiceStatus", "echo should isolate voice state rendering")
assertContains(echoView, "voiceStatusHeightConstraint?.constant = isVisible ? 32 : 0", "voice state should collapse without shifting default Stitch layout")
assertNotContains(echoView, "timestampLabel", "echo quote bubble should not render the stray timestamp under the bubble")
assertContains(echoViewModel, "case starting", "echo state machine should distinguish startup from active listening")
assertContains(echoViewModel, "func prepareVoiceInteraction()", "echo should expose a pre-start state before the SDK confirms listening")
assertContains(echoView, "viewModel.prepareVoiceInteraction()", "echo should not render listening before DialogEngine confirms start")
assertContains(echoView, "renderVoiceStatus(text: nil, isVisible: false)", "idle state should hide the voice status capsule")
assertContains(echoView, "renderVoiceStatus(text: \"正在准备麦克风\", isVisible: true)", "starting state should show a preparing status before listening")
assertContains(echoView, "renderVoiceStatus(text: \"我在听，您慢慢说\", isVisible: true)", "listening state should show a gentle visible status")
assertContains(echoView, "renderVoiceStatus(text: \"先去窗边走走，约 \\(minutes) 分钟后我再回信\", isVisible: true)", "waiting state should show the delayed reply state")
assertContains(echoView, "renderVoiceStatus(text: \"回响正在抵达\", isVisible: true)", "speaking state should show the echo arriving state")
assertContains(echoView, "voiceStatusView.bottomAnchor.constraint(equalTo: micButton.topAnchor", "voice status should sit between the quote bubble and mic button")
assertContains(echoView, "quoteBubble.bottomAnchor.constraint(equalTo: voiceStatusView.topAnchor", "quote bubble should move up only when voice status is expanded")
assertContains(echoView, "func runUIQAEchoVoiceStatePreview()", "UIQA should be able to show a deterministic active voice state")
assertContains(echoView, "func runUIQAEchoListeningStatePreview()", "UIQA should be able to show the listening state")
assertContains(echoView, "func runUIQAEchoSpeakingStatePreview()", "UIQA should be able to show the speaking state")

assertContains(featureFlags, "DJShowEchoVoiceStatePreview", "scenario registry should expose a UIQA launch arg for voice state preview")
assertContains(featureFlags, "DJShowEchoListeningStatePreview", "scenario registry should expose a UIQA launch arg for listening preview")
assertContains(featureFlags, "DJShowEchoSpeakingStatePreview", "scenario registry should expose a UIQA launch arg for speaking preview")
assertContains(appDelegate, "case .echoVoiceStatePreview", "app delegate should route the typed voice state preview scenario")
assertContains(appDelegate, "case .echoListeningStatePreview", "app delegate should route the typed listening preview scenario")
assertContains(appDelegate, "case .echoSpeakingStatePreview", "app delegate should route the typed speaking preview scenario")
assertContains(appDelegate, "showEchoVoiceStatePreview()", "app delegate should route to the echo voice preview harness")
assertContains(appDelegate, "showEchoVoiceStatePreview(targetState: .listening)", "app delegate should route to listening preview")
assertContains(appDelegate, "showEchoVoiceStatePreview(targetState: .speaking)", "app delegate should route to speaking preview")

assertContains(releasePackageCheck, "echo-voice-state-visual-check.swift", "release QA package should include the echo voice state visual guard")
