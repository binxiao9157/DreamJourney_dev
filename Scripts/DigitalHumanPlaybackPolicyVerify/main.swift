import Foundation

func assertCondition(_ condition: @autoclosure () -> Bool, _ message: String) {
    if !condition() {
        fputs("FAIL: \(message)\n", stderr)
        exit(1)
    }
}

assertCondition(
    DigitalHumanSpeechPlaybackPolicy.action(forWebAudioEvent: "audio_ended") == .finish,
    "audio_ended should finish playback"
)
assertCondition(
    DigitalHumanSpeechPlaybackPolicy.action(forWebAudioEvent: "speech_envelope_ended") == .finish,
    "speech_envelope_ended should finish playback"
)
assertCondition(
    DigitalHumanSpeechPlaybackPolicy.action(forWebAudioEvent: "audio_error") == .fail,
    "audio_error should trigger fallback"
)
assertCondition(
    DigitalHumanSpeechPlaybackPolicy.action(forWebAudioEvent: "audio_decode_error") == .fail,
    "audio_decode_error should trigger fallback"
)
assertCondition(
    DigitalHumanSpeechPlaybackPolicy.action(forWebAudioEvent: "audio_fallback") == .fail,
    "audio_fallback should trigger fallback"
)
assertCondition(
    DigitalHumanSpeechPlaybackPolicy.action(forWebAudioEvent: "audio_buffered") == .ignore,
    "audio_buffered should not finish or fallback"
)

assertCondition(
    DigitalHumanSpeechPlaybackPolicy.shouldFinishOnSDKTTSFinished(
        isDigitalHumanSpeechPlaybackEnabled: true,
        isAwaitingDigitalHumanAudioEnd: true
    ) == false,
    "SDK TTS finish should be ignored while waiting for native digital-human audio"
)
assertCondition(
    DigitalHumanSpeechPlaybackPolicy.shouldFinishOnSDKTTSFinished(
        isDigitalHumanSpeechPlaybackEnabled: true,
        isAwaitingDigitalHumanAudioEnd: false
    ),
    "SDK TTS finish should complete when not waiting for native digital-human audio"
)
assertCondition(
    DigitalHumanSpeechPlaybackPolicy.shouldFinishOnSDKTTSFinished(
        isDigitalHumanSpeechPlaybackEnabled: false,
        isAwaitingDigitalHumanAudioEnd: true
    ),
    "SDK TTS finish should complete when digital human playback is disabled"
)

assertCondition(
    DigitalHumanSpeechPlaybackPolicy.watchdogTimeout(for: "") == 14.0,
    "watchdog timeout should have a lower bound"
)
assertCondition(
    DigitalHumanSpeechPlaybackPolicy.watchdogTimeout(for: String(repeating: "家", count: 50)) == 18.0,
    "watchdog timeout should scale with text length"
)
assertCondition(
    DigitalHumanSpeechPlaybackPolicy.watchdogTimeout(for: String(repeating: "家", count: 200)) == 28.0,
    "watchdog timeout should have an upper bound"
)

assertCondition(
    DigitalHumanSpeechPlaybackPolicy.shouldAcceptSystemSpeechCallback(
        isFallbackActive: true,
        fallbackRequestID: 7,
        currentRequestID: 7
    ),
    "matching active fallback callback should be accepted"
)
assertCondition(
    DigitalHumanSpeechPlaybackPolicy.shouldAcceptSystemSpeechCallback(
        isFallbackActive: false,
        fallbackRequestID: 7,
        currentRequestID: 7
    ) == false,
    "inactive fallback callback should be ignored"
)
assertCondition(
    DigitalHumanSpeechPlaybackPolicy.shouldAcceptSystemSpeechCallback(
        isFallbackActive: true,
        fallbackRequestID: 6,
        currentRequestID: 7
    ) == false,
    "stale fallback callback should be ignored"
)

let wavFallback = DigitalHumanSpeechPlaybackPolicy.fallbackPresentation(
    reason: "wav_synth_failed: 数字人语音网络错误: request timed out"
)
assertCondition(wavFallback.title == "已切换到系统语音", "wav failure should show system voice fallback title")
assertCondition(wavFallback.message.contains("不影响继续对话"), "wav failure should reassure main flow continuity")
assertCondition(!wavFallback.message.contains("request timed out"), "fallback message should not expose raw technical error")
assertCondition(wavFallback.recoveryActionTitle == "重试数字人", "fallback should offer digital human retry")
assertCondition(wavFallback.continueActionTitle == "继续语音", "fallback should offer continue voice action")

let webAudioFallback = DigitalHumanSpeechPlaybackPolicy.fallbackPresentation(
    reason: "webview_audio_failed: audio_decode_error"
)
assertCondition(webAudioFallback.message.contains("数字人口型暂时不可用"), "web audio failure should explain lip sync degradation")

let timeoutFallback = DigitalHumanSpeechPlaybackPolicy.fallbackPresentation(reason: "playback_timeout")
assertCondition(timeoutFallback.title == "播放已自动收尾", "timeout should show automatic recovery title")

let evidenceChecks = DigitalHumanSpeechPlaybackPolicy.roadshowEvidenceChecks()
assertCondition(evidenceChecks.count == 3, "roadshow evidence should cover three playback outcomes")
assertCondition(
    evidenceChecks.contains { $0.source == "native_audio" && $0.expectedLog.contains("playback_finished source=native_audio") },
    "evidence checks should include native audio finish log"
)
assertCondition(
    evidenceChecks.contains { $0.source == "system_tts" && $0.expectedLog.contains("fallback=systemTTS") },
    "evidence checks should include system TTS fallback log"
)
assertCondition(
    evidenceChecks.contains { $0.source == "timeout" && $0.expectedLog.contains("playback_timeout") },
    "evidence checks should include watchdog timeout log"
)
assertCondition(
    evidenceChecks.allSatisfy { !$0.acceptance.isEmpty && !$0.expectedLog.isEmpty },
    "each evidence check should include acceptance and expected log text"
)

func makeSafetyDecision(
    riskLevel: SafetyGuardRiskLevel,
    action: SafetyGuardAction,
    reasonCode: String,
    canSendToTTS: Bool
) -> SafetyGuardResponse {
    SafetyGuardResponse(
        decisionID: "test",
        riskLevel: riskLevel,
        action: action,
        categories: [],
        policyVersion: "test",
        reasonCode: reasonCode,
        safeReplacementKey: nil,
        canPersist: true,
        canSendToLLM: false,
        canSendToTTS: canSendToTTS,
        canShowInFamilyDashboard: false,
        audit: SafetyGuardAudit(
            rawContentStored: false,
            contentHMACSHA256: nil,
            contentLength: 0,
            evaluatedAt: "2026-06-12T00:00:00Z",
            latencyMS: 0
        )
    )
}

assertCondition(
    DigitalHumanSpeechPlaybackPolicy.canSendAssistantSpeechToTTS(
        makeSafetyDecision(riskLevel: .safe, action: .allow, reasonCode: "ALLOW", canSendToTTS: true)
    ),
    "explicit safe allow should send assistant speech to TTS"
)
assertCondition(
    DigitalHumanSpeechPlaybackPolicy.canSendAssistantSpeechToTTS(
        makeSafetyDecision(riskLevel: .medium, action: .block, reasonCode: "GUARD_UNAVAILABLE", canSendToTTS: false)
    ),
    "guard-unavailable assistant speech should degrade open for TTS after local high-risk screening"
)
assertCondition(
    DigitalHumanSpeechPlaybackPolicy.canSendAssistantSpeechToTTS(
        makeSafetyDecision(riskLevel: .high, action: .escalate, reasonCode: "LOCAL_HIGH_RISK", canSendToTTS: false)
    ) == false,
    "local high-risk assistant speech must not send to TTS"
)

print("DigitalHumanPlaybackPolicy verification passed")
