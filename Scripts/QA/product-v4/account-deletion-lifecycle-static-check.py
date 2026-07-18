#!/usr/bin/env python3
"""Guard the WI-S0-01-08C production account-deletion orchestration contract."""

from pathlib import Path
import re
import sys


ROOT = Path(__file__).resolve().parents[3]
PROFILE = ROOT / "DreamJourney/Sources/Modules/Profile/ProfileViewController.swift"
USER_MANAGER = ROOT / "DreamJourney/Sources/Services/UserManager.swift"
RUNTIME = ROOT / "DreamJourney/Sources/App/AccountLifecycleRuntimeRegistry.swift"
COORDINATOR = ROOT / "DreamJourney/Sources/App/AccountLifecycleCoordinator.swift"


class ContractViolations:
    def __init__(self) -> None:
        self.messages: list[str] = []

    def require(self, condition: bool, message: str) -> None:
        if not condition:
            self.messages.append(message)

    def finish(self) -> None:
        if not self.messages:
            return
        print("FAIL: WI-S0-01-08C production account-deletion contract is not wired:", file=sys.stderr)
        for message in self.messages:
            print(f"  - {message}", file=sys.stderr)
        raise SystemExit(1)


def function_body(source: str, signatures: tuple[str, ...]) -> tuple[str, str]:
    for signature in signatures:
        start = source.find(signature)
        if start < 0:
            continue
        brace = source.find("{", start)
        if brace < 0:
            continue
        depth = 0
        for index in range(brace, len(source)):
            if source[index] == "{":
                depth += 1
            elif source[index] == "}":
                depth -= 1
                if depth == 0:
                    return signature, source[brace + 1 : index]
    return "", ""


def appears_in_order(body: str, snippets: tuple[str, ...]) -> bool:
    cursor = -1
    for snippet in snippets:
        cursor = body.find(snippet, cursor + 1)
        if cursor < 0:
            return False
    return True


def registration_block(source: str, module_id: str) -> str:
    marker = f'id: "{module_id}'
    start = source.find(marker)
    if start < 0:
        return ""
    next_registration = source.find("registration(", start)
    return source[start : next_registration if next_registration >= 0 else len(source)]


def main() -> None:
    violations = ContractViolations()
    for path in (PROFILE, USER_MANAGER, RUNTIME, COORDINATOR):
        violations.require(path.is_file(), f"missing production source {path.relative_to(ROOT)}")
    violations.finish()

    profile = PROFILE.read_text(encoding="utf-8")
    user_manager = USER_MANAGER.read_text(encoding="utf-8")
    runtime = RUNTIME.read_text(encoding="utf-8")
    coordinator = COORDINATOR.read_text(encoding="utf-8")

    _, profile_deletion = function_body(profile, ("private func submitAccountDeletion(",))
    violations.require(bool(profile_deletion), "Profile must retain a submitAccountDeletion entry point")
    if profile_deletion:
        violations.require(
            appears_in_order(
                profile_deletion,
                (
                    "softDeleteAccount(",
                    "case .success",
                ),
            ),
            "Profile must enter local deletion only from backend soft-delete success",
        )
        violations.require(
            "purgeLocalArchiveDataForAccountDeletion" not in profile_deletion
            and "purgeLocalDataForAccountDeletion" not in profile_deletion,
            "Profile must not purge only Archive/Conversation as a partial deletion",
        )
        violations.require(
            "UserManager.shared.logout()" not in profile_deletion,
            "Profile must not convert account deletion into ordinary logout",
        )
        violations.require(
            "UserManager.shared.completeAccountDeletion(" in profile_deletion
            or "UserManager.shared.requestAccountDeletion(" in profile_deletion
            or "UserManager.shared.deleteAccount(" in profile_deletion,
            "Profile success callback must call the dedicated UserManager account-deletion API",
        )

    deletion_signature, deletion_body = function_body(
        user_manager,
        (
            "func completeAccountDeletion(",
            "func requestAccountDeletion(",
            "func deleteAccount(",
        ),
    )
    violations.require(
        bool(deletion_body),
        "UserManager must expose completeAccountDeletion/requestAccountDeletion/deleteAccount",
    )
    if deletion_body:
        if deletion_signature != "func completeAccountDeletion(":
            violations.require(
                appears_in_order(
                    deletion_body,
                    (
                        "capture(forSubjectId:",
                        "softDeleteAccount(",
                        "case .success",
                        "performAccountDeletionAfterBackendSoftDelete",
                    ),
                ),
                f"{deletion_signature} must capture old lease, await backend success, then start lifecycle",
            )
        violations.require(
            "performAccountDeletionAfterBackendSoftDelete" in deletion_body,
            "dedicated UserManager API must use the deletion-only transition controller path",
        )
        violations.require(
            "UserManager.shared.logout()" not in deletion_body and "logout()" not in deletion_body,
            "dedicated deletion must not invoke ordinary logout",
        )
        violations.require(
            "expectedOwnerUserId" in deletion_body and "oldGeneration" in deletion_body,
            "deletion finalization must carry the captured owner and generation",
        )

    deletion_transition_signature, deletion_transition = function_body(
        runtime,
        ("func performAccountDeletionAfterBackendSoftDelete(",),
    )
    violations.require(
        bool(deletion_transition),
        "AccountLifecycleTransitionController must expose performAccountDeletionAfterBackendSoftDelete",
    )
    if deletion_transition:
        violations.require(
            appears_in_order(
                deletion_transition,
                (
                    "accountSessionActor.beginDeleting(",
                    "performAfterExistingFence(",
                    "accountSessionActor.signOut(",
                ),
            ),
            f"{deletion_transition_signature} must order beginDeleting -> 13 modules -> signOut",
        )
        violations.require(
            "event: .accountDeletion" in deletion_transition,
            "deletion transition must execute coordinator with accountDeletion event",
        )
        violations.require(
            re.search(r"moduleReceipts\.count\s*==\s*(?:expectedModuleCount|13)", deletion_transition)
            is not None,
            "deletion transition must require exactly 13 module receipts",
        )
        violations.require(
            "isTerminal" in deletion_transition,
            "deletion transition must require all lifecycle modules to reach terminal state",
        )
        violations.require(
            "remainingLocalDataCount == 0" in runtime,
            "local residual data must prevent a completed-deletion result",
        )
        violations.require(
            "hasFailures" in runtime and "cleanupCompleted" in runtime,
            "failed/pending/unsupported receipts must prevent completed-deletion status",
        )
        violations.require(
            "expectedGeneration:" in deletion_transition and ".generation" in deletion_transition,
            "final signOut must use the deleting generation as a stale-callback fence",
        )

    finalizer_signature, finalizer = function_body(
        user_manager,
        (
            "private func finalizeAccountDeletion(",
            "func finalizeAccountDeletion(",
        ),
    )
    violations.require(bool(finalizer), "UserManager must have a dedicated account-deletion finalizer")
    if finalizer:
        violations.require(
            "expectedOwnerUserId" in finalizer and "expectedGeneration" in finalizer,
            f"{finalizer_signature} must reject an old callback after owner/generation changes",
        )
        violations.require(
            "remainingLocalData" in finalizer or "cleanupCompleted" in finalizer,
            "deletion finalizer must distinguish signed-out cleanup-pending from completed deletion",
        )

    module_ids = set(re.findall(r'id:\s*"(LM-\d{2}-[^"]+)"', runtime))
    violations.require(
        len(module_ids) == 13,
        f"production deletion registry must contain exactly 13 modules (found {len(module_ids)})",
    )
    violations.require(
        "result.remainingLocalData" in coordinator
        and 'detailCode: "accountDeletionDataRemains"' in coordinator,
        "coordinator must fail closed when account-deletion local data remains",
    )
    violations.require(
        'detailCode: "voiceRightsDeletionReceiptPending"' in runtime
        and 'detailCode: "digitalHumanDeletionReceiptPending"' in runtime,
        "remote voice/digital-human deletion must remain explicit pending receipts",
    )
    for detail_code in (
        "voiceRightsDeletionReceiptPending",
        "digitalHumanDeletionReceiptPending",
        "messageRemoteDeletionReceiptPending",
    ):
        detail_index = runtime.find(f'detailCode: "{detail_code}"')
        surrounding = runtime[max(0, detail_index - 240) : detail_index + 120]
        violations.require(
            detail_index >= 0 and ".failed" in surrounding and "remainingLocalData: false" in surrounding,
            f"{detail_code} must remain explicit without masquerading as local residue",
        )

    for module_id in (
        "LM-08-owner-explicit-draft-stores",
        "LM-09-knowledge-draft-and-outbox-store",
    ):
        block = registration_block(runtime, module_id)
        violations.require(bool(block), f"missing lifecycle registration for {module_id}")
        violations.require(
            "logout: .retainedLocked" in block,
            f"ordinary logout must retain explicit drafts for {module_id}",
        )
        violations.require(
            "deletion: .purged" in block,
            f"account deletion must purge explicit drafts for {module_id}",
        )

    violations.finish()
    print(
        "PASS: WI-S0-01-08C production account-deletion lifecycle static check "
        "backendGate=ok modules=13 staleCallback=guarded residual=guarded"
    )


if __name__ == "__main__":
    main()
