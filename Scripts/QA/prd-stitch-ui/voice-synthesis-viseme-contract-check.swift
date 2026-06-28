import Foundation
import Darwin

struct CheckFailure: Error, CustomStringConvertible {
    let description: String
}

func read(_ path: String) throws -> String {
    try String(contentsOfFile: path, encoding: .utf8)
}

func require(_ condition: Bool, _ message: String) throws {
    if !condition {
        throw CheckFailure(description: message)
    }
}

do {
    let iosRoot = "/Users/yxj/Documents/Codex/Video/DreamJourney_dev"
    let backendRoot = "/Users/yxj/Documents/Codex/Video/DreamJourneyBackend"

    let backendMain = try read("\(backendRoot)/app/main.py")
    let backendTTS = try read("\(backendRoot)/app/services/tts.py")
    let backendRuntime = try read("\(backendRoot)/app/services/runtime_config.py")
    let backendTests = try read("\(backendRoot)/tests/test_core_services.py")
    let backendClient = try read("\(iosRoot)/DreamJourney/Sources/Services/DreamJourneyBackendClient.swift")
    let lipSyncTimeline = try read("\(iosRoot)/DreamJourney/Sources/Modules/Echo/DigitalHumanLipSyncTimeline.swift")
    let livePanel = try read("\(iosRoot)/DreamJourney/Sources/Modules/Echo/DigitalHumanLivePanelView.swift")

    try require(backendMain.contains("\"visemeTimeline\": result.get(\"visemeTimeline\")"),
                "/voice/synthesis must return optional visemeTimeline")
    try require(backendTTS.contains("parse_viseme_timeline"),
                "voice clone TTS proxy must sanitize provider viseme timelines")
    try require(backendRuntime.contains("\"lipSyncTimeline\""),
                "/config/runtime must expose lip sync timeline contract")
    try require(backendTests.contains("lipSyncTimeline") && backendTests.contains("visemeTimeline"),
                "backend tests must lock runtime and synthesis viseme contracts")

    try require(backendClient.contains("let visemeTimeline: DigitalHumanLipSyncTimeline?"),
                "VoiceCloneSynthesisResult must expose optional DigitalHumanLipSyncTimeline")
    try require(backendClient.contains("DigitalHumanLipSyncTimeline(json:"),
                "VoiceCloneSynthesisResult must parse visemeTimeline JSON")
    try require(backendClient.contains("\"visemeTimeline\""),
                "DreamJourneyBackendClient must consume the visemeTimeline response field")
    try require(lipSyncTimeline.contains("init?(json: [String: Any])"),
                "DigitalHumanLipSyncTimeline must support JSON parsing from backend contracts")
    try require(livePanel.contains("func applyPlaybackEvent(_ event: DigitalHumanPlaybackEvent)")
                    && livePanel.contains("setVisemeTimeline(timeline)"),
                "DigitalHumanLivePanelView must accept provider timeline playback events")

    print("voice synthesis viseme timeline contract check passed")
} catch {
    fputs("voice synthesis viseme timeline contract check failed: \(error)\n", stderr)
    exit(1)
}
