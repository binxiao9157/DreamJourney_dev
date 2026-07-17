#!/usr/bin/env python3
"""Static contract guard for WI-S0-02-02 token-family client handling."""

import re
from pathlib import Path


ROOT = Path(__file__).resolve().parents[3]
STORE = ROOT / "DreamJourney/Sources/Services/BackendAuthSessionStore.swift"
CLIENT = ROOT / "DreamJourney/Sources/Services/DreamJourneyBackendClient.swift"
MODEL_SMOKE = ROOT / "Scripts/QA/product-v4/token-family-client-model-smoke.swift"
MODEL_RUNNER = ROOT / "Scripts/QA/product-v4/run-token-family-client-model-smoke.sh"


def require(condition: bool, message: str) -> None:
    if not condition:
        raise AssertionError(message)


def main() -> None:
    require(MODEL_SMOKE.is_file(), "token-family client model smoke is missing")
    require(MODEL_RUNNER.is_file(), "token-family client model smoke runner is missing")

    store = STORE.read_text(encoding="utf-8")
    client = CLIENT.read_text(encoding="utf-8")
    smoke = MODEL_SMOKE.read_text(encoding="utf-8")
    runner = MODEL_RUNNER.read_text(encoding="utf-8")

    for snippet in (
        "let tokenFamilyId: String?",
        "let sessionVersion: Int?",
        "init(from decoder: Decoder) throws",
        "func encode(to encoder: Encoder) throws",
        "case 1:",
        "case 2:",
        "sessionVersion > 0",
        "func isValidRefreshSuccessor(of captured:",
        "func replace(",
        "ifCurrentMatches captured:",
        "func clear(ifCurrentMatches captured:",
    ):
        require(snippet in store, f"auth session/store contract missing: {snippet}")

    for comparison in (
        "userId == captured.userId",
        "sessionId == captured.sessionId",
        "tokenFamilyId == captured.tokenFamilyId",
        "sessionVersion == captured.sessionVersion",
    ):
        require(comparison in store, f"session CAS identity comparison missing: {comparison}")

    require("UUID(" not in store, "client must not fabricate token-family lineage")
    require("AccountSessionActor" not in store + client, "WI-S0-01 AccountSessionActor is out of scope")

    refresh = client.split("private func refreshAuthSession(", 1)[1].split(
        "private func validatedDigitalHumanLeasePath", 1
    )[0]
    for snippet in (
        "for capturedSession:",
        "capturedSession",
        "isValidRefreshSuccessor(of: capturedSession)",
        "allowsRecoveryRefresh: false",
        "recoveryClearSession: capturedSession",
    ):
        require(snippet in refresh, f"refresh CAS flow missing: {snippet}")
    require(
        re.search(
            r"replace\(\s*session,\s*ifCurrentMatches:\s*capturedSession\s*\)",
            refresh,
        )
        is not None,
        "refresh CAS flow missing conditional session replace",
    )
    require(
        re.search(
            r"clear\(\s*ifCurrentMatches:\s*capturedSession\s*\)",
            refresh,
        )
        is not None,
        "terminal refresh flow missing conditional session clear",
    )
    require("adoptAuthSession" not in refresh, "refresh must not use unconditional session adoption")

    request = client.split("private func requestJSON(", 1)[1].split(
        "private func adoptRecoveryRuntimePolicy", 1
    )[0]
    for snippet in (
        "requiredAuthSession: BackendAuthSessionContract? = nil",
        "let requestAuthSession",
        "currentSession?.matchesCASIdentity(requiredAuthSession)",
        "refreshAuthSession(for: requestAuthSession)",
        "requiredAuthSession: refreshedSession",
        "auth_session_changed",
    ):
        require(snippet in request, f"request/session revision binding missing: {snippet}")

    for snippet in (
        "activeAuthRefreshGroup",
        "pendingAuthRefreshGroups",
        "matchesCASIdentity(capturedSession)",
        "startNextAuthRefreshIfNeeded",
    ):
        require(snippet in client, f"refresh coalescing must be scoped by session revision: {snippet}")

    terminal_errors = client.split("private static func isTerminalAuthRefreshError", 1)[1].split(
        "private func validatedDigitalHumanLeasePath", 1
    )[0]
    for code in (
        "invalid_or_expired_refresh_token",
        "legacy_session_reauth_required",
        "refresh_token_reuse_detected",
    ):
        require(code in terminal_errors, f"terminal refresh error is not handled: {code}")
    require(
        "invalidateBackendSession" in refresh,
        "terminal refresh failure must invalidate the matching local account state",
    )

    user_manager = (ROOT / "DreamJourney/Sources/Services/UserManager.swift").read_text(
        encoding="utf-8"
    )
    invalidation = user_manager.split("func invalidateBackendSession", 1)[1].split(
        "// MARK: - 持久化", 1
    )[0]
    require(
        "storedCurrentUser?.id == userId" in invalidation,
        "backend session invalidation must not sign out a replacement account",
    )
    require(
        "logoutAuthSession" not in invalidation,
        "terminal backend invalidation must not send a redundant remote logout",
    )

    recovery_adoption = client.split("private func adoptRecoveryRuntimePolicy(", 1)[1].split(
        "private static func recoveryRuntimePolicy", 1
    )[0]
    require(
        "clearSessionIfCurrentMatches capturedSession:" in recovery_adoption,
        "recovery response clear must accept the refresh captured session",
    )
    require(
        "authSessionStore.clear(ifCurrentMatches: capturedSession)" in recovery_adoption,
        "stale recovery response must not clear a replacement session",
    )

    logout = client.split("func logoutAuthSession()", 1)[1].split("func updateProfile", 1)[0]
    require(
        "clear(ifCurrentMatches: session)" in logout,
        "logout must clear only the session it captured",
    )

    for scenario in (
        "verifyLegacyKeychainDecode",
        "verifyStrictV2NetworkDecode",
        "verifyMonotonicRotation",
        "verifyRefreshAfterLogoutIsDiscarded",
        "verifyRefreshAfterLoginBIsDiscarded",
        "verifyStaleFailureDoesNotClearNewSession",
    ):
        require(scenario in smoke, f"model smoke scenario missing: {scenario}")

    require("BackendAuthSessionStore.swift" in runner, "model smoke must compile the production session model/store")
    require("token-family-client-keychain-stub.swift" in runner, "model smoke Keychain test boundary is missing")

    print("Product V4 token-family client check passed")


if __name__ == "__main__":
    main()
