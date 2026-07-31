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
    ):
        require(test_name in tests, f"Echo turn reducer test missing: {test_name}")

    print(
        "Product V4 Echo turn reducer check passed: provider-independent turn intents "
        "fence stale callback writes without changing public Echo layout"
    )


if __name__ == "__main__":
    main()
