#!/usr/bin/env python3
"""Static contract guard for the additive V4 identity challenge client."""

from pathlib import Path


ROOT = Path(__file__).resolve().parents[3]
CLIENT = ROOT / "DreamJourney/Sources/Services/DreamJourneyBackendClient.swift"
LOGIN = ROOT / "DreamJourney/Sources/Modules/Auth/LoginViewController.swift"
CONTRACT = ROOT / "DreamJourney/Sources/Services/BackendIdentityChallenge.swift"
PROJECT = ROOT / "DreamJourney.xcodeproj/project.pbxproj"
MODEL_RUNNER = ROOT / "Scripts/QA/product-v4/run-identity-challenge-client-model-smoke.sh"
R4_GATE = ROOT / "Scripts/QA/product-v4/run-identity-challenge-r4-client-gate.sh"
UIQA_RUNNER = ROOT / "Scripts/QA/product-v4/run-identity-challenge-login-recovery-uiqa-smoke.sh"
FEATURE_FLAGS = ROOT / "DreamJourney/Sources/App/FeatureFlagService.swift"
APP_DELEGATE = ROOT / "DreamJourney/Sources/AppDelegate.swift"


def require(condition: bool, message: str) -> None:
    if not condition:
        raise AssertionError(message)


def main() -> None:
    require(CONTRACT.is_file(), "typed identity challenge contract is missing")
    require(MODEL_RUNNER.is_file(), "identity challenge model smoke runner is missing")
    require(R4_GATE.is_file(), "identity challenge R4 client gate is missing")
    require(UIQA_RUNNER.is_file(), "identity challenge login/recovery UIQA runner is missing")
    contract = CONTRACT.read_text(encoding="utf-8")
    client = CLIENT.read_text(encoding="utf-8")
    login = LOGIN.read_text(encoding="utf-8")
    project = PROJECT.read_text(encoding="utf-8")
    model_runner = MODEL_RUNNER.read_text(encoding="utf-8")
    uiqa_runner = UIQA_RUNNER.read_text(encoding="utf-8")
    feature_flags = FEATURE_FLAGS.read_text(encoding="utf-8")
    app_delegate = APP_DELEGATE.read_text(encoding="utf-8")

    for symbol in (
        "BackendIdentityChallengeCapability",
        "BackendIdentityChallengeContract",
        "BackendIdentityChallengeStateContract",
        "BackendIdentityVerificationContract",
    ):
        require(f"struct {symbol}" in contract, f"missing typed contract: {symbol}")

    for field in (
        "challengeId",
        "expiresAt",
        "productionReady",
        "clientFlowEnabled",
        "subjectId",
        "bindingId",
        "proofReceiptId",
        "deliveryState",
        "recoveryState",
        "remainingAttempts",
        "stateContractVersion",
        "testAccountFlowEnabled",
        "testAccountTargetRestricted",
    ):
        require(field in contract, f"identity contract field missing: {field}")

    require("let identityChallenge: BackendIdentityChallengeCapability" in client, "runtime config must expose identity challenge capability")
    require("func createIdentityChallenge(" in client, "identity challenge request use case is missing")
    require("path: \"/v2/auth/challenges\"" in client, "identity challenge endpoint drift")
    require("func verifyIdentityChallenge(" in client, "identity verification use case is missing")
    require("func fetchIdentityChallengeState(" in client, "identity state recovery use case is missing")
    require("?recover=true" in client, "identity delivery recovery query is missing")
    require("/v2/auth/challenges/\(pathComponent(challengeId))/verify" in client, "identity verify endpoint drift")
    require("guard try self.adoptAuthSession(from: object) else" in client, "verified identity must yield a valid user session")
    require('"identityType": "phone"' in client, "challenge request must use the typed phone identity field")
    verify_body = client.split("func verifyIdentityChallenge(", 1)[1].split("func logoutAuthSession", 1)[0]
    require("password" not in verify_body, "typed identity verification must not transport an unused password")

    require("identityChallenge.canStartClientFlow" in login, "login must require a supported typed runtime capability")
    require(
        'providerMode == "testAllowlist"' in contract
        and "testAccountFlowEnabled" in contract
        and "testAccountTargetRestricted" in contract,
        "test allowlist mode must require explicit server-side target restriction",
    )
    require("beginIdentityChallengeLogin" in login, "login challenge use case is not wired")
    require("performLegacyLogin" not in login, "typed login must not fall back to legacy phone claim")
    require("UserManager.shared.login" not in login.split("guard DreamJourneyBackendClient.shared.isLoginSyncConfigured else {", 1)[1].split("}", 1)[0], "offline identity bypass returned")
    require("BackendIdentityChallenge.swift in Sources" in project, "identity contract is not part of the app target")
    require("-parse-as-library" in model_runner, "identity model smoke must compile production model as a library")
    require("BackendIdentityChallenge.swift" in model_runner, "identity model smoke must exercise the production typed model")
    require(
        "DJRunIdentityChallengeLoginRecoverySmoke" in feature_flags,
        "identity challenge login/recovery scenario is not registered",
    )
    require(
        "runIdentityChallengeLoginRecoverySmoke" in app_delegate,
        "identity challenge login/recovery UIQA flow is missing",
    )
    for boundary in (
        "fetchRuntimeConfig",
        "createIdentityChallenge",
        "fetchIdentityChallengeState",
        "recoverDelivery: true",
        "verifyIdentityChallenge",
        "logoutAuthSession",
    ):
        require(boundary in app_delegate, f"identity UIQA boundary missing: {boundary}")
    require(
        "IDENTITY_CHALLENGE_ADAPTER=synthetic" in uiqa_runner,
        "identity UIQA runner must use the local synthetic adapter",
    )
    require(
        "SWIFT_ACTIVE_COMPILATION_CONDITIONS='DEBUG UI_QA_SIMULATOR'" in uiqa_runner,
        "identity UIQA runner must remain simulator-only",
    )

    print("Product V4 identity challenge client check passed")


if __name__ == "__main__":
    main()
