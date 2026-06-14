import Foundation

private final class RecordingDelegate: DialogEngineDelegate {
    var events: [String] = []
    var finalASRText: String?
    var ttsText: String?
    var assistantFinalText: String?
    var endedReason: DialogEndReason?
    var safetyAssessment: SafetyAssessment?

    func onDialogStarted() {
        events.append("started")
    }

    func onASRResult(text: String, isFinal: Bool) {
        events.append(isFinal ? "asr-final" : "asr-partial")
        if isFinal {
            finalASRText = text
        }
    }

    func onTTSStarted(text: String) {
        events.append("tts-started")
        ttsText = text
    }

    func onTTSFinished() {
        events.append("tts-finished")
    }

    func onAssistantFinalText(text: String) {
        events.append("assistant-final")
        assistantFinalText = text
    }

    func onChatStreaming(text: String) {
        events.append("chat-streaming")
    }

    func onError(error: Error) {
        events.append("error")
    }

    func onSafetyTriggered(assessment: SafetyAssessment) {
        events.append("safety")
        safetyAssessment = assessment
    }

    func onDialogEnded(reason: DialogEndReason) {
        events.append("ended")
        endedReason = reason
    }
}

private func assertCondition(_ condition: @autoclosure () -> Bool, _ message: String) {
    guard condition() else {
        fputs("FAIL: \(message)\n", stderr)
        exit(1)
    }
}

private let delegate = RecordingDelegate()
private let engine = DialogEngineFactory.makeDefault(
    arguments: ["DreamJourney", "--use-mock-dialog-engine"],
    environment: [:]
)
engine.delegate = delegate

assertCondition(!engine.isEngineReady, "mock engine should start unready")
engine.setup()
assertCondition(engine.isEngineReady, "setup should mark mock engine ready")

engine.startDialog()
assertCondition(engine.isDialogActive, "startDialog should activate mock dialog")
assertCondition(delegate.events.contains("started"), "startDialog should notify delegate")

guard let mock = engine as? MockDialogEngine else {
    fputs("FAIL: factory default with --use-mock-dialog-engine should return MockDialogEngine\n", stderr)
    exit(1)
}

let envEngine = DialogEngineFactory.makeDefault(
    arguments: ["DreamJourney"],
    environment: ["DREAMJOURNEY_DIALOG_ENGINE": "mock"]
)
assertCondition(envEngine is MockDialogEngine, "environment should select MockDialogEngine")

let realAcceptanceType = DialogEngineFactory.selectedType(
    arguments: ["DreamJourney", "--real-acceptance", "--use-mock-dialog-engine"],
    environment: ["DREAMJOURNEY_DIALOG_ENGINE": "mock"]
)
assertCondition(realAcceptanceType == .volcengine, "real acceptance should force the real dialog engine path")

let offlineArgEngine = DialogEngineFactory.makeDefault(
    arguments: ["DreamJourney", "--roadshow-offline-mode"],
    environment: [:]
)
assertCondition(offlineArgEngine is MockDialogEngine, "roadshow offline launch arg should select MockDialogEngine")

let offlineEnvEngine = DialogEngineFactory.makeDefault(
    arguments: ["DreamJourney"],
    environment: ["DREAMJOURNEY_ROADSHOW_OFFLINE": "1"]
)
assertCondition(offlineEnvEngine is MockDialogEngine, "roadshow offline environment should select MockDialogEngine")

mock.simulateUserTurn("今天想聊聊年轻时在上海工作的事")
assertCondition(delegate.finalASRText?.contains("上海") == true, "mock should emit final ASR text")
assertCondition(delegate.assistantFinalText?.contains("上海") == true, "mock should emit final assistant text")
assertCondition(delegate.ttsText?.contains("上海") == true, "mock should emit deterministic TTS reply")
if let finalIndex = delegate.events.firstIndex(of: "assistant-final"),
   let finishIndex = delegate.events.firstIndex(of: "tts-finished") {
    assertCondition(finalIndex < finishIndex, "assistant final text should be available before TTS finishes")
} else {
    fputs("FAIL: mock turn should include assistant final and TTS finished events\n", stderr)
    exit(1)
}

mock.simulateUserTurn("我不想活了")
assertCondition(delegate.safetyAssessment?.level == .high, "mock should trigger safety for high-risk text")
if case .crisis = delegate.endedReason {
    // expected
} else {
    fputs("FAIL: high-risk mock turn should end with crisis reason\n", stderr)
    exit(1)
}
assertCondition(!engine.isDialogActive, "crisis should deactivate mock dialog")

engine.destroyEngine()
assertCondition(!engine.isEngineReady, "destroy should mark mock engine unready")

print("MockDialogEngine verification passed")
