import Foundation

enum DigitalHumanSpeechPlaybackPolicy {
    enum WebAudioEventAction: Equatable {
        case finish
        case fail
        case ignore
    }

    struct FallbackPresentation: Equatable {
        let title: String
        let message: String
        let recoveryActionTitle: String
        let continueActionTitle: String
    }

    struct EvidenceCheck: Equatable {
        let title: String
        let source: String
        let expectedLog: String
        let acceptance: String
    }

    static func action(forWebAudioEvent eventType: String) -> WebAudioEventAction {
        switch eventType {
        case "audio_ended", "speech_envelope_ended":
            return .finish
        case "audio_error", "audio_decode_error", "audio_fallback":
            return .fail
        default:
            return .ignore
        }
    }

    static func shouldFinishOnSDKTTSFinished(
        isDigitalHumanSpeechPlaybackEnabled: Bool,
        isAwaitingDigitalHumanAudioEnd: Bool
    ) -> Bool {
        !(isDigitalHumanSpeechPlaybackEnabled && isAwaitingDigitalHumanAudioEnd)
    }

    static func watchdogTimeout(for text: String) -> TimeInterval {
        min(max(Double(text.count) * 0.20 + 8.0, 14.0), 28.0)
    }

    static func shouldAcceptSystemSpeechCallback(
        isFallbackActive: Bool,
        fallbackRequestID: Int?,
        currentRequestID: Int
    ) -> Bool {
        isFallbackActive && fallbackRequestID == currentRequestID
    }

    static func canSendAssistantSpeechToTTS(_ decision: SafetyGuardResponse) -> Bool {
        if decision.riskLevel == .high || decision.riskLevel == .critical {
            return false
        }

        if decision.canSendToTTS && (decision.action == .allow || decision.action == .allowWithCare) {
            return true
        }

        // Digital-human speech is assistant output. If the remote guard is unavailable,
        // SafetyGuardClient has already run local high-risk screening before this response.
        return decision.reasonCode == "GUARD_UNAVAILABLE"
    }

    static func fallbackPresentation(reason: String) -> FallbackPresentation {
        let normalized = reason.lowercased()
        if normalized.contains("timeout") {
            return FallbackPresentation(
                title: "播放已自动收尾",
                message: "数字人本次讲述已结束，你可以继续说话；如果需要，可稍后重试数字人播报。",
                recoveryActionTitle: "重试数字人",
                continueActionTitle: "继续语音"
            )
        }

        if normalized.contains("webview_audio_failed")
            || normalized.contains("audio_decode")
            || normalized.contains("audio_fallback") {
            return FallbackPresentation(
                title: "已切换到系统语音",
                message: "数字人口型暂时不可用，已改用系统语音播报，不影响继续对话。",
                recoveryActionTitle: "重试数字人",
                continueActionTitle: "继续语音"
            )
        }

        return FallbackPresentation(
            title: "已切换到系统语音",
            message: "数字人语音暂时不可用，已改用系统语音播报，不影响继续对话。",
            recoveryActionTitle: "重试数字人",
            continueActionTitle: "继续语音"
        )
    }

    static func playbackEvidenceChecks() -> [EvidenceCheck] {
        [
            EvidenceCheck(
                title: "原生 WAV 数字人播报",
                source: "native_audio",
                expectedLog: "wav_synth_success -> playback_finished source=native_audio",
                acceptance: "WAV 由 iOS 原生播放器真实出声，口型动画跟随播报结束，未触发系统 TTS。"
            ),
            EvidenceCheck(
                title: "系统 TTS 兜底",
                source: "system_tts",
                expectedLog: "fallback=systemTTS -> playback_finished source=system_tts",
                acceptance: "原生音频或 WAV 合成失败时仍有声音，不双播，主按钮可继续录音。"
            ),
            EvidenceCheck(
                title: "Watchdog 超时收尾",
                source: "timeout",
                expectedLog: "playback_timeout -> playback_finished source=timeout",
                acceptance: "播放回调丢失时自动收尾，不长时间卡在正在讲述。"
            )
        ]
    }
}
