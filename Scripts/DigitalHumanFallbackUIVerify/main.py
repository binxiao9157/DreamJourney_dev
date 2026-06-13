#!/usr/bin/env python3
from pathlib import Path
import sys

vc = Path("DreamJourney/Sources/Modules/Home/AIRecordingViewController.swift").read_text()
policy = Path("DreamJourney/Sources/Services/DigitalHumanSpeechPlaybackPolicy.swift").read_text()

checks = [
    (
        "AI recording screen should own a digital human fallback card",
        "digitalHumanFallbackCard" in vc
        and "digitalHumanFallbackTitleLabel" in vc
        and "digitalHumanFallbackMessageLabel" in vc,
    ),
    (
        "fallback card should expose retry and continue actions",
        "retryDigitalHumanTapped" in vc
        and "continueVoiceFallbackTapped" in vc
        and "重试数字人" in vc
        and "继续语音" in vc,
    ),
    (
        "timeout fallback should preserve the assistant text for retry",
        "retryableDigitalHumanSpeechText" in vc
        and 'source == "timeout"' in vc
        and "retryableDigitalHumanSpeechText = currentAssistantResponseText" in vc
        and "currentAssistantResponseText ?? retryableDigitalHumanSpeechText" in vc,
    ),
    (
        "continuing voice or resetting playback should clear retry-only text",
        "continueVoiceFallbackTapped" in vc
        and "retryableDigitalHumanSpeechText = nil" in vc
        and "resetDigitalHumanSpeechPlayback" in vc,
    ),
    (
        "playback failure should show friendly fallback presentation before system TTS",
        "DigitalHumanSpeechPlaybackPolicy.fallbackPresentation" in vc
        and "showDigitalHumanFallbackPresentation" in vc
        and "startDigitalHumanSystemSpeechFallback" in vc,
    ),
    (
        "successful playback or reset should hide fallback card",
        "hideDigitalHumanFallbackPresentation()" in vc
        and "finishDigitalHumanSpeechPlayback" in vc
        and "resetDigitalHumanSpeechPlayback" in vc,
    ),
    (
        "digital human dialog errors should not toast raw technical messages",
        "showToast(error.localizedDescription" not in vc
        and "showVoiceServiceRecovery" in vc,
    ),
    (
        "policy should define non-technical user-facing fallback copy",
        "struct FallbackPresentation" in policy
        and "已切换到系统语音" in policy
        and "数字人口型暂时不可用" in policy
        and "不影响继续对话" in policy,
    ),
]

failed = [message for message, passed in checks if not passed]
if failed:
    for message in failed:
        print(f"DigitalHumanFallbackUI verification failed: {message}", file=sys.stderr)
    sys.exit(1)

print("DigitalHumanFallbackUI verification passed")
