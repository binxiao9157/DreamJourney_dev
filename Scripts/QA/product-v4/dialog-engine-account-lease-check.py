#!/usr/bin/env python3

from pathlib import Path
import re


ROOT = Path(__file__).resolve().parents[3]
SOURCE = ROOT / "DreamJourney/Sources/Services/DialogEngineManager.swift"


def require(condition: bool, message: str) -> None:
    if not condition:
        raise AssertionError(message)


def main() -> None:
    source = SOURCE.read_text()
    require(
        source.count("func bindAccountLease(") >= 2
        and source.count("ownerId: UUID") >= 2
        and source.count(") -> DialogEngineBindingHandle?") >= 2,
        "both UIQA and production dialog engines must return owner-scoped binding handles",
    )
    require(
        source.count(
            "func unbindAccountLease(_ handle: DialogEngineBindingHandle) -> Bool"
        ) >= 2,
        "both dialog engines must release only the exact originating binding handle",
    )
    for snippet in (
        "struct DialogEngineBindingHandle: Equatable, Sendable",
        "private let ownerId: UUID",
        "private var boundBindingHandle: DialogEngineBindingHandle?",
        "isSameDialogAccountGeneration(",
        "private let accountLeaseRuntime = AccountLeaseRuntime.shared",
        "private var activeDialogAccountLease: AccountLease?",
        "private func isActiveAccountLeaseValid(",
        "validate(accountLease, at: .request).allowed",
        "validate(accountLease, at: .timer).allowed",
        "validate(accountLease, at: .runtime).allowed",
    ):
        require(snippet in source, f"dialog engine lease missing: {snippet}")

    require(
        re.search(
            r"guard accountLeaseRuntime\.validate\(accountLease, at: \.request\)\.allowed else \{\s*return nil\s*\}",
            source,
        )
        is not None,
        "invalid binding attempts must fail without destroying another owner",
    )
    for snippet in (
        "DialogEngineProviderDelegateProxy",
        "private var engineCallbackGeneration: UUID?",
        "private var activeDialogOperationId: UUID?",
        "private var providerSessionOperationId: UUID?",
        "private var requiresEngineRecreationBeforeNextDialog = false",
        "private func currentProviderCallbackContext(",
        "private func isCurrentProviderCallbackContext(",
        "private func deliverProviderCallback(",
        "private func handleProviderMessage(",
        "delegateIdentity: ObjectIdentifier(delegate)",
        "providerSessionOperationId == callbackContext.dialogOperationId",
    ):
        require(snippet in source, f"provider provenance fence missing: {snippet}")
    require(
        "extension DialogEngineManager: SpeechEngineDelegate" not in source,
        "the singleton must not receive unscoped provider callbacks directly",
    )
    require(
        source.count("delegate = nil") >= 4,
        "owner replacement and exact unbind must clear stale dialog delegates in both builds",
    )

    require(
        re.search(
            r"func startDialog\([\s\S]*?isActiveAccountLeaseValid\(at: \.request\)",
            source,
        )
        is not None,
        "dialog start must validate the bound lease",
    )
    require(
        re.search(
            r"private func resetSilenceTimer\(\)[\s\S]*?"
            r"activeDialogAccountLease[\s\S]*?at: \.timer",
            source,
        )
        is not None,
        "silence timer must retain and validate its originating lease",
    )
    require(
        re.search(
            r"func handleProviderMessage\([\s\S]*?"
            r"currentProviderCallbackContext\([\s\S]*?"
            r"providerSessionOperationId == callbackContext\.dialogOperationId",
            source,
        )
        is not None,
        "provider callbacks must validate engine, binding, operation, and session provenance",
    )
    require(
        re.search(
            r"func startDialog\([\s\S]*?"
            r"rotateProviderEngineBeforeNextDialogIfNeeded\(\)[\s\S]*?"
            r"let dialogOperationId = UUID\(\)",
            source,
        )
        is not None,
        "a new operation must rotate the provider callback generation after a prior session stops",
    )
    require(
        source.count("requiresEngineRecreationBeforeNextDialog = true") >= 2,
        "manual and provider terminal paths must retire the current engine generation",
    )

    print("Dialog engine AccountLease check passed")


if __name__ == "__main__":
    main()
