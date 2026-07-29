#!/usr/bin/env python3
"""Guard the default-off live Echo Owner Truth Context shadow observer."""

from __future__ import annotations

from pathlib import Path


ROOT = Path(__file__).resolve().parents[3]
VIEW_MODEL = ROOT / "DreamJourney/Sources/Modules/Echo/EchoViewModel.swift"
VIEW_CONTROLLER = ROOT / "DreamJourney/Sources/Modules/Echo/EchoViewController.swift"
CLIENT = ROOT / "DreamJourney/Sources/Services/DreamJourneyBackendClient.swift"
CONTRACTS = ROOT / "DreamJourney/Sources/Domain/OwnerTruth/OwnerTruthContracts.swift"
TESTS = ROOT / "DreamJourneyTests/AudioOwnerLeaseModelTests.swift"


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
                return source[opening + 1 : index]
    raise AssertionError(f"unterminated function: {name}")


def type_body(source: str, marker: str) -> str:
    start = source.find(marker)
    require(start >= 0, f"missing type: {marker}")
    opening = source.find("{", start)
    require(opening >= 0, f"missing type body: {marker}")
    depth = 0
    for index in range(opening, len(source)):
        if source[index] == "{":
            depth += 1
        elif source[index] == "}":
            depth -= 1
            if depth == 0:
                return source[opening + 1 : index]
    raise AssertionError(f"unterminated type: {marker}")


def main() -> None:
    view_model = VIEW_MODEL.read_text(encoding="utf-8")
    view_controller = VIEW_CONTROLLER.read_text(encoding="utf-8")
    client = CLIENT.read_text(encoding="utf-8")
    contracts = CONTRACTS.read_text(encoding="utf-8")
    tests = TESTS.read_text(encoding="utf-8")

    for required in (
        "protocol EchoOwnerTruthContextShadowTransport",
        "struct EchoOwnerTruthContextShadowLease: Equatable",
        "enum EchoOwnerTruthContextShadowDelivery",
        "private(set) var activeOwnerTruthContextShadowLease",
        "func invalidateOwnerTruthContextShadow()",
        "func requestOwnerTruthContextShadow(",
        "expectedIdentity.isPersonal",
        "expectedIdentity.userId == accountLease.subjectId",
        "OwnerTruthVaultID(accountLease.vaultId)",
        "extension DreamJourneyBackendClient: EchoOwnerTruthContextShadowTransport {}",
    ):
        require(required in view_model or required in client, f"missing shadow observer boundary: {required}")

    transport_body = function_body(client, "observeOwnerTruthContextShadow")
    for required in (
        "buildOwnerTruthContextShadow(",
        'intent: "echo_chat"',
        "selectionMode: .projectionCitationOrder",
        "result.map { $0.traceSummary() }",
    ):
        require(required in transport_body, f"client shadow transport drift: {required}")

    for required in (
        "let queryHash: String?",
        "let queryLength: Int?",
        "static func queryFingerprint(for query: String)",
        "func matchesSubmittedQuery(_ query: String) -> Bool",
        "queryHashDigest = summary.queryHash.map(Self.digest)",
    ):
        require(required in contracts, f"shadow query correlation contract missing: {required}")

    turn_body = function_body(view_controller, "recordEchoContextPacketForUserTurn")
    request_index = turn_body.find("echoApplicationCoordinator.requestContextBuild(")
    shadow_index = turn_body.find("observeOwnerTruthContextShadowForEchoTurn(")
    require(request_index >= 0, "live Echo turn must retain public Context Packet request")
    require(shadow_index > request_index, "shadow must begin after the public Context Packet lease is established")

    observer_body = function_body(view_controller, "observeOwnerTruthContextShadowForEchoTurn")
    for required in (
        "OwnerTruthContextCitationQAGate.isEnabled",
        "context.isSelfAssistant",
        "expectedIdentity.userId == accountLease.subjectId",
        "validateEchoAccountLease(",
        "echoApplicationCoordinator.requestOwnerTruthContextShadow(",
        "recordOwnerTruthContextCitationQAEvidence(summary)",
        "ownerTruthContextShadowObserved",
        "ownerTruthContextShadowUnavailable",
    ):
        require(required in observer_body, f"live Echo shadow observer missing: {required}")
    for prohibited in (
        "submitEchoTurnKnowledgeContext(",
        "submitLocalEchoTurnKnowledgeContext(",
        "DialogEngine.shared",
        "generationContextText",
    ):
        require(prohibited not in observer_body, f"shadow observer must not affect public reply path: {prohibited}")

    coordinator_body = type_body(view_model, "final class EchoApplicationCoordinator")
    for required in (
        "summary.matchesSubmittedQuery(query)",
        "EchoOwnerTruthContextShadowCorrelationError",
        ".queryMismatch",
    ):
        require(required in coordinator_body, f"shadow query correlation guard missing: {required}")

    cancel_body = function_body(view_controller, "cancelActiveEchoContextBuild")
    require(
        "lastOwnerTruthContextCitationEvidence = nil" in cancel_body,
        "turn cancellation must clear stale shadow evidence",
    )

    for test_name in (
        "func testOwnerTruthShadowStartsOnlyForCurrentSelfOwner()",
        "func testOwnerTruthShadowDropsSupersededAndInvalidatedCallbacks()",
        "func testContextBuildInvalidationAlsoDropsOwnerTruthShadowCallback()",
        "func testOwnerTruthShadowRejectsSummaryForDifferentQuery()",
        "private final class DeferredOwnerTruthContextShadowTransport",
    ):
        require(test_name in tests, f"shadow lifecycle test missing: {test_name}")

    print(
        "Product V4 live Echo Owner Truth Context shadow check passed: default-off, "
        "self-owner-only, generation-fenced, value-free, and isolated from public reply input"
    )


if __name__ == "__main__":
    main()
