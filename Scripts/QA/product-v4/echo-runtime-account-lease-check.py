#!/usr/bin/env python3

from pathlib import Path
import re


ROOT = Path(__file__).resolve().parents[3]
SOURCE = ROOT / "DreamJourney/Sources/Modules/Echo/EchoViewController.swift"
VIEW_MODEL = ROOT / "DreamJourney/Sources/Modules/Echo/EchoViewModel.swift"


def require(condition: bool, message: str) -> None:
    if not condition:
        raise AssertionError(message)


def function_body(source: str, name: str) -> str:
    marker = f"func {name}("
    start = source.find(marker)
    require(start >= 0, f"missing function: {name}")
    opening = source.find("{", start)
    require(opening >= 0, f"missing function body: {name}")
    depth = 0
    for index in range(opening, len(source)):
        if source[index] == "{":
            depth += 1
        elif source[index] == "}":
            depth -= 1
            if depth == 0:
                return source[opening + 1:index]
    raise AssertionError(f"unterminated function body: {name}")


def main() -> None:
    source = SOURCE.read_text()
    view_model = VIEW_MODEL.read_text()
    for snippet in (
        "private let accountLeaseRuntime = AccountLeaseRuntime.shared",
        "private let dialogEngineOwnerId = UUID()",
        "private var echoAccountLease: AccountLease?",
        "private var dialogEngineBindingHandle: DialogEngineBindingHandle?",
        "captureEchoAccountLease(reason:",
        "validateEchoAccountLease(at: .request",
        "validateEchoAccountLease(at: .timer",
        "validateEchoAccountLease(at: .runtime",
        "validateEchoAccountLease(at: .ui",
        "ownerId: dialogEngineOwnerId",
        "DialogEngineManager.shared.unbindAccountLease(bindingHandle)",
        "DialogEngineManager.shared.isCurrentBinding(dialogEngineBindingHandle)",
        "setDialogEngineLocalTTSPlaybackEnabled(",
        "DeferredDigitalHumanSessionRelease",
        "enqueueDeferredDigitalHumanSessionRelease(",
        "drainDeferredDigitalHumanSessionReleases(",
        "name: .djRecoveryAuthorityEpochDidChange",
        "echoAuthorityEpochDidChange",
        "performEchoAccountScopeRebindOnMain(reason: \"authorityEpochDidChange\")",
    ):
        require(snippet in source, f"Echo AccountLease missing: {snippet}")

    require(
        re.search(
            r"isCurrentDigitalHumanLifecycleToken\([\s\S]*?"
            r"validateEchoAccountLease\(at: \.runtime",
            source,
        )
        is not None,
        "digital-human lifecycle validation must include AccountLease",
    )
    require(
        re.search(
            r"scheduleDigitalHumanSessionHeartbeat\([\s\S]*?"
            r"validateEchoAccountLease\(at: \.timer",
            source,
        )
        is not None,
        "digital-human heartbeat must validate the originating account lease",
    )
    require(
        re.search(
            r"func onDialogEnded\([\s\S]*?validateEchoAccountLease\(at: \.ui",
            source,
        )
        is not None,
        "dialog end callback must not apply after account switch",
    )
    require(
        re.search(
            r"private func activeVoiceInteractionToken\([\s\S]*?"
            r"ownsCurrentDialogEngineBinding\(\)[\s\S]*?"
            r"isCurrentDigitalHumanLifecycleToken",
            source,
        )
        is not None,
        "Echo callbacks must also retain the exact dialog-engine binding owner",
    )
    require(
        "unbindAccountLease(echoAccountLease)" not in source,
        "stale Echo controllers must never unbind by account identity alone",
    )

    for function_name in (
        "suspendEchoForAppLifecycle",
        "pauseDialogEngineForTencentProviderSpeechIfNeeded",
        "submitEchoTurnKnowledgeContext",
        "enterNeutralSafetyMode",
    ):
        require(
            "ownsCurrentDialogEngineBinding()" in function_body(source, function_name),
            f"{function_name} must not mutate a dialog runtime owned by another controller",
        )

    for function_name in (
        "restoreEchoAfterAppLifecycleIfNeeded",
        "resumeDialogEngineAfterTencentProviderSpeechIfNeeded",
        "resumeVoiceCaptureAfterTencentProviderSpeech",
        "runUIQAMicrophoneSmoke",
    ):
        require(
            "bindDialogEngineToEchoAccountLease(" in function_body(source, function_name),
            f"{function_name} must reacquire the exact Echo dialog binding before use",
        )

    neutral_safety_body = function_body(source, "enterNeutralSafetyMode")
    require(
        neutral_safety_body.find("ownsCurrentDialogEngineBinding()")
        < neutral_safety_body.find("DialogEngineManager.shared.interruptAI()"),
        "neutral safety must prove dialog ownership before interrupting the shared engine",
    )

    rebind_body = function_body(source, "rebindEchoAccountScope")
    for snippet in (
        "pendingAIText = nil",
        "transcriptEntries.removeAll",
        "viewModel.resetTransientStateForAccountRebind()",
        "seedTranscriptPreview()",
    ):
        require(snippet in rebind_body, f"account rebind must reset stale Echo state: {snippet}")
    require(
        rebind_body.find("releaseDigitalHumanRuntime(")
        < rebind_body.find("releaseDialogEngineBinding()"),
        "account rebind must release the old audio route before dropping its exact binding",
    )
    require(
        rebind_body.find("bindDialogEngineToEchoAccountLease(")
        < rebind_body.find("applyEchoAudioRoutePolicy()"),
        "account rebind must reapply audio routing only after the new exact binding is active",
    )

    transient_reset = function_body(view_model, "resetTransientStateForAccountRebind")
    require(
        "updateState(.idle)" in transient_reset,
        "account rebind must recover a disabled starting UI to idle",
    )
    require(
        "EchoDelayedReplyStore.shared.clear()" not in transient_reset,
        "transient account rebind must not clear the newly active owner's delayed reply store",
    )
    account_change_body = function_body(source, "performEchoAccountScopeRebindOnMain")
    require(
        "Thread.isMainThread" in account_change_body
        and "DispatchQueue.main.async" in account_change_body,
        "account and authority notifications must marshal UIKit rebind work to the main thread",
    )

    print("Echo runtime AccountLease check passed")


if __name__ == "__main__":
    main()
