#!/usr/bin/env python3
"""Guard the Stage 0 login boundary before a real identity provider is enabled."""

from pathlib import Path


ROOT = Path(__file__).resolve().parents[3]
LOGIN = ROOT / "DreamJourney/Sources/Modules/Auth/LoginViewController.swift"
CLIENT = ROOT / "DreamJourney/Sources/Services/DreamJourneyBackendClient.swift"


def require(condition: bool, message: str) -> None:
    if not condition:
        raise AssertionError(message)


def function_body(source: str, signature: str) -> str:
    start = source.find(signature)
    require(start >= 0, f"missing function: {signature}")
    brace = source.find("{", start)
    require(brace >= 0, f"missing function body: {signature}")
    depth = 0
    for index in range(brace, len(source)):
        if source[index] == "{":
            depth += 1
        elif source[index] == "}":
            depth -= 1
            if depth == 0:
                return source[brace + 1 : index]
    raise AssertionError(f"unterminated function: {signature}")


def main() -> None:
    source = LOGIN.read_text(encoding="utf-8")
    body = function_body(source, "@objc private func loginTapped()")
    guard_marker = "guard DreamJourneyBackendClient.shared.isLoginSyncConfigured else {"
    guard_start = body.find(guard_marker)
    require(guard_start >= 0, "login must fail closed when backend identity is unavailable")
    guard_body = function_body(body[guard_start:], guard_marker[:-1].rstrip())
    require("showLoginAlert" in guard_body, "signed-out fallback must explain backend unavailability")
    require("return" in guard_body, "signed-out fallback must stop login")
    require("UserManager.shared.login" not in guard_body, "offline login must not create a private user")
    require("didLogin" not in guard_body, "offline login must not enter the private application")
    require("performLegacyLogin" not in source, "runtime capability failure must not fall back to legacy login")
    require("identityChallenge.canStartClientFlow" in body, "login must require a supported typed challenge capability")
    require("let submittedPhone = rawPhone" in body, "login must snapshot the submitted identity before async work")

    client = CLIENT.read_text(encoding="utf-8")
    upsert = function_body(client, "func upsertUser(")
    require(
        "guard try self.adoptAuthSession(from: object) else" in upsert,
        "login must reject a backend response that does not contain a valid auth session",
    )

    print("Product V4 login identity boundary check passed")


if __name__ == "__main__":
    main()
