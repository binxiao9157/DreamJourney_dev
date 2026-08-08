#!/usr/bin/env python3

from pathlib import Path


ROOT = Path(__file__).resolve().parents[3]
LEASE = ROOT / "DreamJourney/Sources/App/AccountLease.swift"
ACTOR = ROOT / "DreamJourney/Sources/App/AccountSessionActor.swift"
COORDINATOR = ROOT / "DreamJourney/Sources/App/AppCoordinator.swift"
USER_MANAGER = ROOT / "DreamJourney/Sources/Services/UserManager.swift"
BACKEND_CLIENT = ROOT / "DreamJourney/Sources/Services/DreamJourneyBackendClient.swift"
MODEL = ROOT / "Scripts/QA/product-v4/account-lease-runtime-model-smoke.swift"
RUNNER = ROOT / "Scripts/QA/product-v4/run-account-lease-runtime-gate.sh"


def require(condition: bool, message: str) -> None:
    if not condition:
        raise AssertionError(message)


def function_body(source: str, signature: str) -> str:
    start = source.find(signature)
    require(start >= 0, f"missing function: {signature}")
    opening = source.find("{", start)
    require(opening >= 0, f"missing function body: {signature}")
    depth = 0
    for index in range(opening, len(source)):
        if source[index] == "{":
            depth += 1
        elif source[index] == "}":
            depth -= 1
            if depth == 0:
                return source[opening + 1 : index]
    raise AssertionError(f"unterminated function: {signature}")


def require_ordered(body: str, snippets: tuple[str, ...], message: str) -> None:
    cursor = -1
    for snippet in snippets:
        index = body.find(snippet, cursor + 1)
        require(index >= 0, f"{message}: missing {snippet}")
        cursor = index


def main() -> None:
    require(LEASE.is_file(), "AccountLease production file is missing")
    lease = LEASE.read_text()
    actor = ACTOR.read_text()
    coordinator = COORDINATOR.read_text()
    user_manager = USER_MANAGER.read_text()
    backend_client = BACKEND_CLIENT.read_text()
    model = MODEL.read_text()
    runner = RUNNER.read_text()

    for snippet in (
        "enum AccountLeaseCheckpoint",
        "case request",
        "case commit",
        "case ui",
        "case timer",
        "case runtime",
        "struct AccountLease:",
        "let subjectId: String",
        "let vaultId: String",
        "let sessionId: String",
        "let generation: UInt64",
        "let generationId: UUID",
        "let authorityEpoch: String",
        "protocol AccountLeaseRuntimePort",
        "final class AccountLeaseRuntime",
        "func capture(forSubjectId",
        "func validate(",
        "func diagnosticsSnapshot()",
    ):
        require(snippet in lease, f"AccountLease contract missing: {snippet}")

    for snippet in (
        "private let accountLeaseRuntime: AccountLeaseRuntime",
        "accountLeaseRuntime.publish(session:",
    ):
        require(snippet in actor, f"AccountSessionActor lease publication missing: {snippet}")

    require(
        "AccountLeaseRuntime.shared.updateAuthorityEpoch(\n"
        "            RecoveryRuntimePolicyStore.shared.currentPolicy.authorityEpoch\n"
        "        )" in coordinator,
        "AppCoordinator must seed AccountLease authority epoch before account bootstrap",
    )
    logout = function_body(user_manager, "func logout()")
    suspend_private_access = function_body(user_manager, "func suspendPrivateAccess(")
    for body, label in (
        (logout, "logout"),
        (suspend_private_access, "private-access suspension"),
    ):
        require_ordered(
            body,
            (
                "AccountLeaseRuntime.shared.capture(",
                "AccountLeaseRuntime.shared.publish(session: nil)",
                "AccountLifecycleTransitionController.shared.perform",
            ),
            f"{label} must synchronously fence AccountLease before async teardown",
        )
    require(
        "AccountLeaseRuntime.shared.publish(session: nil)" not in function_body(
            coordinator,
            "private func handleLogout()",
        )
        and "AccountLeaseRuntime.shared.publish(session: nil)" not in function_body(
            coordinator,
            "private func handlePrivateAccessSuspended()",
        ),
        "AppCoordinator must not duplicate the UserManager lifecycle fence",
    )
    require(
        "accountLeaseRuntime.updateAuthorityEpoch(policy.authorityEpoch)" in backend_client,
        "backend runtime policy adoption must invalidate leases on authority epoch change",
    )
    for snippet in (
        "applicationLease: AccountLease? = nil",
        "let requestApplicationLease: AccountLease?",
        "accountLeaseRuntime.capture(forSubjectId: selectedSession.userId)",
        "accountLeaseRuntime.validate(capturedApplicationLease, at: .request).allowed",
        "applicationLease: requestApplicationLease",
        "at checkpoint: AccountLeaseCheckpoint",
        "accountLeaseRuntime.validate(applicationLease, at: checkpoint).allowed",
        "at: .commit",
        "at: .ui",
    ):
        require(snippet in backend_client, f"backend request AccountLease checkpoint missing: {snippet}")

    for scenario in (
        "same-generation token refresh must preserve business lease",
        "authority epoch change must reject old lease",
        "account switch must reject old UI callback",
        "logout must reject old timer",
    ):
        require(scenario in model, f"AccountLease model scenario missing: {scenario}")

    require("AccountLease.swift" in runner, "runner must compile production AccountLease")
    require("AccountSessionActor.swift" in runner, "runner must compile production AccountSessionActor")
    for check in (
        "archive-account-lease-static-check.py",
        "family-account-lease-static-check.py",
        "knowledge-sync-account-lease-check.py",
        "media-capture-account-lease-check.py",
        "message-notification-account-lease-check.py",
        "profile-voice-clone-account-lease-check.py",
        "voice-tts-account-lease-check.py",
        "dialog-engine-account-lease-check.py",
        "dialog-engine-provider-operation-model-smoke.swift",
        "ai-recording-dialog-account-lease-check.py",
        "echo-runtime-account-lease-check.py",
        "run-kblite-account-lease-gate.sh",
        "family-context-reconciliation-check.swift",
        "knowledge-widget-privacy-lifecycle-check.swift",
        "run-knowledge-widget-snapshot-store-model-smoke.sh",
    ):
        require(check in runner, f"AccountLease gate missing surface check: {check}")

    print("Product V4 AccountLease runtime static check passed")


if __name__ == "__main__":
    main()
