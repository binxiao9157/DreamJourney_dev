#!/usr/bin/env python3
"""Static contract guard for the additive V4 identity challenge client."""

from pathlib import Path


ROOT = Path(__file__).resolve().parents[3]
CLIENT = ROOT / "DreamJourney/Sources/Services/DreamJourneyBackendClient.swift"
LOGIN = ROOT / "DreamJourney/Sources/Modules/Auth/LoginViewController.swift"
CONTRACT = ROOT / "DreamJourney/Sources/Services/BackendIdentityChallenge.swift"
PROJECT = ROOT / "DreamJourney.xcodeproj/project.pbxproj"
MODEL_RUNNER = ROOT / "Scripts/QA/product-v4/run-identity-challenge-client-model-smoke.sh"


def require(condition: bool, message: str) -> None:
    if not condition:
        raise AssertionError(message)


def main() -> None:
    require(CONTRACT.is_file(), "typed identity challenge contract is missing")
    require(MODEL_RUNNER.is_file(), "identity challenge model smoke runner is missing")
    contract = CONTRACT.read_text(encoding="utf-8")
    client = CLIENT.read_text(encoding="utf-8")
    login = LOGIN.read_text(encoding="utf-8")
    project = PROJECT.read_text(encoding="utf-8")
    model_runner = MODEL_RUNNER.read_text(encoding="utf-8")

    for symbol in (
        "BackendIdentityChallengeCapability",
        "BackendIdentityChallengeContract",
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
    ):
        require(field in contract, f"identity contract field missing: {field}")

    require("let identityChallenge: BackendIdentityChallengeCapability" in client, "runtime config must expose identity challenge capability")
    require("func createIdentityChallenge(" in client, "identity challenge request use case is missing")
    require("path: \"/v2/auth/challenges\"" in client, "identity challenge endpoint drift")
    require("func verifyIdentityChallenge(" in client, "identity verification use case is missing")
    require("/v2/auth/challenges/\(pathComponent(challengeId))/verify" in client, "identity verify endpoint drift")
    require("guard try self.adoptAuthSession(from: object) else" in client, "verified identity must yield a valid user session")
    require('"identityType": "phone"' in client, "challenge request must use the typed phone identity field")
    verify_body = client.split("func verifyIdentityChallenge(", 1)[1].split("func logoutAuthSession", 1)[0]
    require("password" not in verify_body, "typed identity verification must not transport an unused password")

    require("identityChallenge.canStartClientFlow" in login, "login must require a supported typed runtime capability")
    require("beginIdentityChallengeLogin" in login, "login challenge use case is not wired")
    require("performLegacyLogin" not in login, "typed login must not fall back to legacy phone claim")
    require("UserManager.shared.login" not in login.split("guard DreamJourneyBackendClient.shared.isLoginSyncConfigured else {", 1)[1].split("}", 1)[0], "offline identity bypass returned")
    require("BackendIdentityChallenge.swift in Sources" in project, "identity contract is not part of the app target")
    require("-parse-as-library" in model_runner, "identity model smoke must compile production model as a library")
    require("BackendIdentityChallenge.swift" in model_runner, "identity model smoke must exercise the production typed model")

    print("Product V4 identity challenge client check passed")


if __name__ == "__main__":
    main()
