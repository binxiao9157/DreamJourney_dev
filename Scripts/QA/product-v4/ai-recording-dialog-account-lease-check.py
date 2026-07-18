#!/usr/bin/env python3

from pathlib import Path
import re


ROOT = Path(__file__).resolve().parents[3]
SOURCE = ROOT / "DreamJourney/Sources/Modules/Home/AIRecordingViewController.swift"


def require(condition: bool, message: str) -> None:
    if not condition:
        raise AssertionError(message)


def function_body(source: str, name: str) -> str:
    marker = f"func {name}("
    start = source.find(marker)
    require(start >= 0, f"missing function: {name}")
    opening = source.find("{", start)
    require(opening >= 0, f"missing body: {name}")
    depth = 0
    for index in range(opening, len(source)):
        if source[index] == "{":
            depth += 1
        elif source[index] == "}":
            depth -= 1
            if depth == 0:
                return source[opening + 1:index]
    raise AssertionError(f"unterminated body: {name}")


def main() -> None:
    source = SOURCE.read_text()
    for snippet in (
        "private let dialogEngineOwnerId = UUID()",
        "private var dialogAccountLease: AccountLease?",
        "private var dialogEngineBindingHandle: DialogEngineBindingHandle?",
        "captureInitialDialogAccountLease()",
        "validateDialogAccountLease(",
        "bindDialogEngine(accountLease:",
        "ownerId: dialogEngineOwnerId",
        "DialogEngineManager.shared.unbindAccountLease(bindingHandle)",
        "validateDialogEngineBinding(",
        "startSessionRecording(accountLease: accountLease)",
        "stopSessionRecording(accountLease: accountLease)",
        "discardStaleSessionRecording()",
        "name: .djRecoveryAuthorityEpochDidChange",
        "handleDialogAuthorityEpochDidChange",
    ):
        require(snippet in source, f"AIRecording dialog lease missing: {snippet}")

    require(
        source.count("captureInitialDialogAccountLease()") == 2,
        "dialog callbacks must not recapture or fall back to the current account",
    )
    require(
        re.search(
            r"requestPermission[\s\S]*?dialogAccountLease == accountLease[\s\S]*?"
            r"validateDialogAccountLease\(accountLease, at: \.ui\)",
            source,
        )
        is not None,
        "microphone permission callback must retain and validate its originating lease",
    )
    require(
        re.search(
            r"func onDialogStarted\(\)[\s\S]*?"
            r"validateDialogEngineBinding\(accountLease: accountLease, at: \.ui\)",
            source,
        )
        is not None,
        "dialog delegate UI callbacks must validate the originating owner binding",
    )
    for handler in ("handleDidEnterBackground", "handleWillEnterForeground"):
        require(
            re.search(
                rf"func {handler}\(\)[\s\S]*?"
                r"validateDialogAccountLease\(accountLease, at: \.runtime\)",
                source,
            )
            is not None,
            f"{handler} must validate the original dialog lease",
        )

    require(
        re.search(
            r"func stopRecording\(\)[\s\S]*?"
            r"validateDialogAccountLease\(accountLease, at: \.runtime\)",
            source,
        )
        is not None,
        "recording stop must be fenced by the original dialog lease",
    )
    require(
        "unbindAccountLease(dialogAccountLease)" not in source
        and "DialogEngineManager.shared.destroyEngine()" not in source,
        "stale AIRecording lifecycle must not tear down a newly rebound shared engine",
    )
    disappear_body = function_body(source, "viewWillDisappear")
    require(
        "validateDialogEngineBinding(accountLease: accountLease, at: .runtime)" in disappear_body
        and "releaseDialogEngineBinding()" in disappear_body
        and "discardStaleSessionRecording()" in disappear_body,
        "AIRecording must release only its exact engine binding when leaving the screen",
    )
    foreground_body = function_body(source, "handleWillEnterForeground")
    require(
        "view.window != nil" in foreground_body,
        "an offscreen AIRecording controller must not reacquire the shared dialog engine",
    )
    deinit_start = source.find("deinit {")
    deinit_end = source.find("}", deinit_start)
    require(
        deinit_start >= 0
        and "releaseDialogEngineBinding()" in source[deinit_start:deinit_end],
        "AIRecording deinit must release its exact binding as a final safeguard",
    )
    account_change_body = function_body(source, "performDialogAccountScopeResetOnMain")
    require(
        "Thread.isMainThread" in account_change_body
        and "DispatchQueue.main.async" in account_change_body,
        "AIRecording account and authority notifications must marshal UI reset to main",
    )

    print("AIRecording dialog AccountLease check passed")


if __name__ == "__main__":
    main()
