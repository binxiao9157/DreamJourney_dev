#!/usr/bin/env python3
"""Static gate for WI-S0-02-03 iOS request authentication boundaries."""

import re
from pathlib import Path


ROOT = Path(__file__).resolve().parents[3]
CLIENT = ROOT / "DreamJourney/Sources/Services/DreamJourneyBackendClient.swift"
APP_SOURCES = ROOT / "DreamJourney/Sources"


def require(condition: bool, message: str) -> None:
    if not condition:
        raise AssertionError(message)


def balanced_end(source: str, opening_index: int, opening: str, closing: str) -> int:
    depth = 0
    for index in range(opening_index, len(source)):
        if source[index] == opening:
            depth += 1
        elif source[index] == closing:
            depth -= 1
            if depth == 0:
                return index
    raise AssertionError(f"unterminated {opening}{closing} block at offset {opening_index}")


def function_span(source: str, signature: str) -> tuple[int, int]:
    start = source.find(signature)
    require(start >= 0, f"missing function: {signature}")
    opening = source.find("{", start)
    require(opening >= 0, f"missing function body: {signature}")
    return start, balanced_end(source, opening, "{", "}") + 1


def function_body(source: str, signature: str) -> str:
    start, end = function_span(source, signature)
    return source[start:end]


def request_calls(source: str) -> list[tuple[int, str]]:
    calls: list[tuple[int, str]] = []
    for match in re.finditer(r"\brequestJSON\s*\(", source):
        line_start = source.rfind("\n", 0, match.start()) + 1
        line_prefix = source[line_start : match.start()]
        if re.search(r"\bfunc\s*$", line_prefix):
            continue
        opening = source.find("(", match.start())
        end = balanced_end(source, opening, "(", ")")
        calls.append((match.start(), source[match.start() : end + 1]))
    return calls


def contains_offset(span: tuple[int, int], offset: int) -> bool:
    return span[0] <= offset < span[1]


def main() -> None:
    client = CLIENT.read_text(encoding="utf-8")
    app_source = "\n".join(
        path.read_text(encoding="utf-8")
        for path in sorted(APP_SOURCES.rglob("*.swift"))
    )

    auth_policy = function_body(client, "private enum RequestAuthPolicy")
    cases = set(re.findall(r"^\s*case\s+(\w+)", auth_policy, flags=re.MULTILINE))
    require(
        cases == {"publicRequest", "userRequired", "refreshExchange"},
        f"request auth policy cases drifted: {sorted(cases)}",
    )
    retired_policy_use = re.search(
        r"\bauthPolicy\s*(?::|==)\s*\.(automatic|backendOnly|anonymous)\b",
        client,
    )
    require(retired_policy_use is None, "retired request auth policy remains in the client")
    require(
        "authPolicy: RequestAuthPolicy =" not in client,
        "requestJSON must not provide an implicit auth policy",
    )

    request_span = function_span(client, "private func requestJSON(")
    request = client[request_span[0] : request_span[1]]
    for snippet in (
        "case userAuthenticationRequired",
        "switch endpoint.authPolicy",
        "case .userRequired:",
        "let currentSession = authSessionStore.currentSession",
        "guard let authenticatedSession = currentSession else",
        "completion(.failure(ClientError.userAuthenticationRequired))",
        "case .publicRequest, .refreshExchange:",
        "authPolicy == .userRequired",
    ):
        require(snippet in client if snippet == "case userAuthenticationRequired" else snippet in request,
                f"local user-session preflight is missing: {snippet}")
    preflight = request.index("guard let authenticatedSession = currentSession else")
    recovery_gate = request.index("RecoveryRuntimePolicyStore.shared.requestDecision")
    network_request = request.index("AF.request(")
    require(
        preflight < recovery_gate < network_request,
        "user session preflight must run before recovery fetches and AF.request",
    )

    public_functions = {
        "func fetchRuntimeConfig(": 'path: "/config/runtime"',
        "func fetchReleasePolicy(": 'let path = "/v2/release-policy"',
        "func createIdentityChallenge(": 'path: "/v2/auth/challenges"',
        "func verifyIdentityChallenge(": "/v2/auth/challenges/\\(pathComponent(challengeId))/verify",
    }
    for signature, route in public_functions.items():
        body = function_body(client, signature)
        require(route in body, f"public route drifted in {signature}")
        require("authPolicy: .publicRequest" in body, f"{signature} must be explicitly public")

    for signature, route in (
        ("func upsertUser(", 'path: "/auth/login"'),
        ("func restoreAccount(", 'path: "/auth/restore"'),
    ):
        if route in client:
            body = function_body(client, signature)
            require(route in body, f"legacy public route moved outside {signature}")
            require("authPolicy: .publicRequest" in body, f"{signature} must remain explicitly public")

    refresh_span = function_span(client, "private func startNextAuthRefreshIfNeeded(")
    refresh = client[refresh_span[0] : refresh_span[1]]
    require('path: "/auth/refresh"' in refresh, "refresh exchange route is missing")
    require("authPolicy: .refreshExchange" in refresh, "refresh must use refreshExchange policy")

    public_spans = [function_span(client, signature) for signature in public_functions]
    for signature, route in (
        ("func upsertUser(", 'path: "/auth/login"'),
        ("func restoreAccount(", 'path: "/auth/restore"'),
    ):
        if route in client:
            public_spans.append(function_span(client, signature))

    calls = request_calls(client)
    require(calls, "requestJSON call inventory is empty")
    for offset, call in calls:
        match = re.search(r"\bauthPolicy\s*:\s*(\.\w+|authPolicy)\b", call)
        require(match is not None, f"requestJSON call at offset {offset} has no explicit auth policy")
        policy = match.group(1)
        if policy == "authPolicy":
            require(contains_offset(request_span, offset), "dynamic auth policy escaped request retry logic")
        elif policy == ".publicRequest":
            require(
                any(contains_offset(span, offset) for span in public_spans),
                f"business request at offset {offset} is incorrectly public",
            )
        elif policy == ".refreshExchange":
            require(contains_offset(refresh_span, offset), "refreshExchange escaped refresh rotation")
        else:
            require(policy == ".userRequired", f"unsupported auth policy at offset {offset}: {policy}")
            require(not contains_offset(request_span, offset), "request retry must preserve its captured policy")

    auth_headers = function_body(client, "private func authHeaders(")
    require("guard policy == .userRequired" in auth_headers, "only userRequired may emit bearer headers")
    require(
        '"Authorization": "Bearer \\(session.accessToken)"' in auth_headers,
        "userRequired must send the current user access token",
    )

    require(
        "/archive/time-letters/dispatch-due" not in app_source,
        "iOS app sources must not express the system-only time-letter dispatcher",
    )
    require(
        "func dispatchDueTimeLetters(" not in app_source,
        "system-only time-letter dispatch API must not exist in the app client",
    )

    print("Product V4 iOS client auth boundary check passed")


if __name__ == "__main__":
    main()
