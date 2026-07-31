#!/usr/bin/env python3
"""Guard the provider-independent Echo turn reducer seam."""

from __future__ import annotations

from pathlib import Path


ROOT = Path(__file__).resolve().parents[3]
VIEW_MODEL = ROOT / "DreamJourney/Sources/Modules/Echo/EchoViewModel.swift"
VIEW_CONTROLLER = ROOT / "DreamJourney/Sources/Modules/Echo/EchoViewController.swift"
TESTS = ROOT / "DreamJourneyTests/AudioOwnerLeaseModelTests.swift"


def require(condition: bool, message: str) -> None:
    if not condition:
        raise AssertionError(message)


def source_slice(source: str, start: str, end: str) -> str:
    start_index = source.find(start)
    require(start_index >= 0, f"missing source slice start: {start}")
    end_index = source.find(end, start_index + len(start))
    require(end_index >= 0, f"missing source slice end: {end}")
    return source[start_index:end_index]


def main() -> None:
    view_model = VIEW_MODEL.read_text(encoding="utf-8")
    view_controller = VIEW_CONTROLLER.read_text(encoding="utf-8")
    tests = TESTS.read_text(encoding="utf-8")

    for required in (
        "enum EchoTurnPhase: String, Equatable",
        "enum EchoTurnIntent: Equatable",
        "struct EchoTurnTransition: Equatable",
        "struct EchoTurnIntentReducer",
        "func accepts(_ intent: EchoTurnIntent) -> Bool",
        "mutating func reduce(_ intent: EchoTurnIntent) -> EchoTurnTransition",
        "private var turnIntentReducer = EchoTurnIntentReducer()",
        "private func applyTurnIntent(",
    ):
        require(required in view_model, f"Echo turn reducer contract missing: {required}")

    for intent in (
        ".prepareVoiceInteraction",
        ".voiceCaptureStarted",
        ".userTurnAccepted",
        ".delayedReplyScheduled",
        ".delayedReplyRestored",
        ".delayedReplyDue",
        ".replyStarted",
        ".replyDelivered",
        ".reset",
        ".failure",
        ".retry",
    ):
        require(intent in view_model, f"Echo turn intent missing: {intent}")

    finish_user_voice = source_slice(
        view_model,
        "    func finishUserVoice(\n        text: String,",
        "    func receiveAIReply(_ text: String)",
    )
    reducer_guard = "guard turnIntentReducer.accepts(acceptedIntent)"
    require(reducer_guard in finish_user_voice, "user turn must be reducer-fenced before side effects")
    require(
        finish_user_voice.find(reducer_guard) < finish_user_voice.find("memoryManager.recordUserTurn"),
        "stale user turns must be rejected before memory/transcript writes",
    )
    require(
        ") -> Bool {" in finish_user_voice,
        "finishUserVoice must return whether the reducer accepted the originating turn",
    )
    require(
        "return applyTurnIntent(.userTurnAccepted, state: .thinking)" in finish_user_voice,
        "user-turn admission must return the reducer result to its caller",
    )

    asr_final = source_slice(
        view_controller,
        "    func onASRResult(text: String, isFinal: Bool)",
        "    func onTTSStarted(text: String)",
    )
    for snippet in (
        "let acceptedUserTurn = self.viewModel.finishUserVoice(",
        "guard acceptedUserTurn else",
        "userTurnRejectedBeforeRuntimeDispatch",
    ):
        require(snippet in asr_final, f"ASR final dispatch fence missing: {snippet}")
    require(
        asr_final.find("guard acceptedUserTurn else")
        < asr_final.find("self.digitalHumanConversation.startUserTurn"),
        "a rejected ASR final must not create a digital-human turn",
    )
    require(
        asr_final.find("guard acceptedUserTurn else")
        < asr_final.find("self.recordEchoContextPacketForUserTurn("),
        "a rejected ASR final must not build Context",
    )
    capture_audio_release = """self.releaseEchoAudioOwnerLease(
                expectedOwner: .echoCapture,
                reason: \"asrFinal\"
            )"""
    require(
        capture_audio_release in asr_final,
        "the accepted ASR final must release its capture audio lease",
    )
    require(
        asr_final.find("guard acceptedUserTurn else")
        < asr_final.find(capture_audio_release),
        "a rejected ASR final must not release the current capture audio lease",
    )

    receive_reply = source_slice(
        view_model,
        "    func receiveAIReply(_ text: String)",
        "    func markReplyDelivered(accountLease: AccountLease)",
    )
    require(
        receive_reply.find("applyTurnIntent(.replyStarted, state: .speaking)")
        < receive_reply.find("memoryManager.recordAITurn"),
        "stale AI replies must be reducer-fenced before transcript writes",
    )
    require(
        ") -> Bool {" in receive_reply,
        "receiveAIReply must return whether the reducer accepted runtime playback",
    )
    require(
        "return true" in receive_reply,
        "accepted AI replies must report admission to their caller",
    )

    tts_started = source_slice(
        view_controller,
        "    func onTTSStarted(text: String)",
        "    func onTTSFinished()",
    )
    for snippet in (
        "guard self.viewModel.receiveAIReply(text) else",
        "aiReplyRejectedBeforeRuntimePlayback",
    ):
        require(snippet in tts_started, f"TTS playback admission fence missing: {snippet}")
    require(
        tts_started.find("guard self.viewModel.receiveAIReply(text) else")
        < tts_started.find("self.sendEchoReplyToDigitalHumanRuntimeIfReady"),
        "a rejected AI reply must not dispatch Tencent provider playback",
    )
    require(
        tts_started.find("guard self.viewModel.receiveAIReply(text) else")
        < tts_started.find("self.acquireEchoRuntimeAudioOwner("),
        "a rejected AI reply must not acquire local playback audio ownership",
    )

    reply_delivery = source_slice(
        view_controller,
        "    private func markEchoReplyDelivered()",
        "    private func refreshDelayedReplyAnswerReconciliation",
    )
    for snippet in (
        ") -> Bool {",
        "return false",
        "return viewModel.markReplyDelivered(accountLease: echoAccountLease)",
    ):
        require(snippet in reply_delivery, f"reply delivery admission fence missing: {snippet}")

    tts_finished = source_slice(
        view_controller,
        "    func onTTSFinished()",
        "    func onChatStreaming",
    )
    for snippet in (
        "guard self.markEchoReplyDelivered() else",
        "replyDeliveryRejectedBeforeCaptureResume",
    ):
        require(snippet in tts_finished, f"TTS completion admission fence missing: {snippet}")
    require(
        tts_finished.find("guard self.markEchoReplyDelivered() else")
        < tts_finished.find("DispatchQueue.main.asyncAfter"),
        "a rejected reply delivery must not resume microphone capture",
    )

    require(
        view_model.count("updateState(") == 3,
        "Echo state transitions must flow through the reducer except the explicit safety overlay",
    )
    for test_name in (
        "func testOrdinaryTurnTransitionsFromVoiceStartToReplyDelivered()",
        "func testStaleReplyCannotResurrectAnIdleTurn()",
        "func testDelayedReplyCanBeScheduledAndDeliveredWithoutOpeningAnotherTurn()",
        "func testStoredDueReplyAwaitsServerResultAfterAppRelaunchWithoutAcceptingStaleReply()",
        "func testFailureOnlyRetriesFromFailureState()",
        "func testDuplicateFinalUserVoiceIsRejectedBeforeTranscriptSideEffects()",
        "func testDuplicateAIReplyIsRejectedBeforeTranscriptSideEffects()",
        "func testDuplicateAIReplyDeliveryIsRejectedBeforeLifecycleResume()",
    ):
        require(test_name in tests, f"Echo turn reducer test missing: {test_name}")

    print(
        "Product V4 Echo turn reducer check passed: provider-independent turn intents "
        "fence stale callback writes without changing public Echo layout"
    )


if __name__ == "__main__":
    main()
