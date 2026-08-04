#!/usr/bin/env python3
"""Guard the closed-pilot owner-authored text Source capture transport."""

from __future__ import annotations

from pathlib import Path


ROOT = Path(__file__).resolve().parents[3]
CONTRACTS = ROOT / "DreamJourney/Sources/Domain/OwnerTruth/OwnerTruthContracts.swift"
CLIENT = ROOT / "DreamJourney/Sources/Services/DreamJourneyBackendClient.swift"
FEATURE_FLAGS = ROOT / "DreamJourney/Sources/App/FeatureFlagService.swift"
ARCHIVE = ROOT / "DreamJourney/Sources/Modules/Archive/MemoryArchiveViewController.swift"
CREATION_OPTIONS = ROOT / "DreamJourney/Sources/Modules/Archive/MemoryArchiveCreationOption.swift"
TEXT_ENTRY = ROOT / "DreamJourney/Sources/Modules/Archive/MemoryArchiveTextEntryViewController.swift"
TESTS = ROOT / "DreamJourneyTests/OwnerTruthContractsTests.swift"


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


def main() -> None:
    contracts = CONTRACTS.read_text(encoding="utf-8")
    client = CLIENT.read_text(encoding="utf-8")
    feature_flags = FEATURE_FLAGS.read_text(encoding="utf-8")
    archive = ARCHIVE.read_text(encoding="utf-8")
    creation_options = CREATION_OPTIONS.read_text(encoding="utf-8")
    text_entry = TEXT_ENTRY.read_text(encoding="utf-8")
    tests = TESTS.read_text(encoding="utf-8")

    for required in (
        "struct OwnerTruthTextSourceCaptureCommand",
        "struct OwnerTruthTextSourceCaptureState",
        "struct OwnerTruthTextSourceCaptureReceipt",
        "enum OwnerTruthTextSourceCaptureOutcome",
        "protocol OwnerTruthTextSourceCaptureClient",
        "private enum OwnerTruthTextSourceCaptureContract",
        'static let schemaVersion = "owner-truth-text-capture-response-v1"',
        'static let schemaVersion = "owner-truth-text-capture-state-v1"',
        'static let sourceReceiptSchemaVersion = "owner-truth-create-source-v1"',
        "static let maximumCharacterCount = 20_000",
        '"expectedAuthorityEpoch"',
        '"candidateExtraction"',
        '"content"',
    ):
        require(required in contracts, f"text Source contract missing: {required}")

    state_body = function_body(client, "fetchOwnerTruthTextSourceCaptureState")
    capture_body = function_body(client, "captureOwnerTruthTextSource")
    for body, operation in ((state_body, "read"), (capture_body, "write")):
        require(
            "requestFeatureDecision(for: .ownerTextCaptureV1)" in body,
            f"text Source {operation} must use the separately captured release policy",
        )
        require("authPolicy: .userRequired" in body, f"text Source {operation} must require an owner session")
        require("featureDecision: decision" in body, f"captured policy must bind the {operation}")
        require(
            "X-DreamJourney-QA-Owner-Truth" not in body,
            f"text Source {operation} must not gain a QA-header bypass",
        )
    require(
        'path = "/v2/vaults/\\(pathComponent(vaultID.rawValue))/source-capture-state"' in state_body,
        "text Source state route drifted",
    )
    require(
        'path = "/v2/vaults/\\(pathComponent(vaultID.rawValue))/sources"' in capture_body,
        "text Source route drifted",
    )
    require(
        "extension DreamJourneyBackendClient: OwnerTruthTextSourceCaptureClient {}" in client,
        "backend client must conform to the typed text Source port",
    )
    require(
        "pathComponents.count == 4" in client
        and 'pathComponents[3] == "sources"' in client
        and 'pathComponents[3] == "source-capture-state"' in client
        and "return .ownerTextCaptureV1" in client,
        "request feature mapping must classify only the exact vault Source route",
    )

    require("case ownerTextCaptureV1" in feature_flags, "feature enum missing owner text capture")
    nonpersistent_start = feature_flags.find("private static let nonPersistentFeatures")
    require(nonpersistent_start >= 0, "nonpersistent feature policy missing")
    nonpersistent_end = feature_flags.find("]", nonpersistent_start)
    require(
        ".ownerTextCaptureV1" in feature_flags[nonpersistent_start:nonpersistent_end],
        "text Source feature must remain nonpersistent/default-off",
    )

    require(
        "isOwnerTruthTextCaptureEnabled: Bool = false" in creation_options
        and "isOwnerTruthMediaCaptureEnabled: Bool = false" in creation_options
        and "route: .archive(.text)" in creation_options,
        "text Source creation option must remain hidden by default",
    )
    require(
        "route: .ownerTruthTextSource" in creation_options
        and 'title: "记录文字"' in creation_options
        and "options[0] = .ownerTruthTextCapture" in creation_options,
        "closed-pilot text Source option is missing product wording",
    )
    require(
        "isOwnerTruthTextCaptureClosedPilotEnabled" in archive
        and "isServerPolicyManagedClosedPilotRouteAllowed(.ownerTextCaptureV1)" in archive
        and "isServerPolicyManagedClosedPilotRouteAllowed(.ownerTruthCandidateReview)" in archive,
        "Archive entry must require both server-authorized closed-pilot capabilities",
    )
    source_entry = function_body(archive, "presentOwnerTruthTextCaptureEntry")
    require(
        "entryMode: .ownerTruthSource" in source_entry
        and "OwnerTruthTextSourceCaptureUseCase" in source_entry
        and "onSubmitOwnerTruthSource" in source_entry
        and "onOwnerTruthSourceAccepted" in source_entry,
        "Archive must use the typed Source workflow rather than a legacy Archive write",
    )
    require(
        "if option.submitsOwnerTruthSource" in archive
        and "presentOwnerTruthTextCaptureEntry()" in archive,
        "Archive selection must route the closed-pilot option to Source capture",
    )
    require(
        "enum MemoryArchiveTextEntryMode" in text_entry
        and "case ownerTruthSource" in text_entry
        and "onSubmitOwnerTruthSource" in text_entry
        and "提交待确认" in text_entry,
        "typed closed-pilot text entry surface is missing",
    )

    for test_name in (
        "func testTextSourceCaptureCommandProducesExactClosedPilotPayload()",
        "func testTextSourceCaptureCommandRejectsInvalidAuthorityTextAndPurpose()",
        "func testTextSourceCaptureStateIsValueMinimizedAndRejectsLeakedFields()",
        "func testTextSourceCaptureReceiptIsValueMinimizedAndRejectsLeakedContent()",
        "func testTextSourceCaptureUseCaseReadsAuthorityAndCapturesClosedPilotSource()",
        "func testTextSourceCaptureUseCaseRetriesTransientFailureWithSameCommand()",
        "func testTextSourceCaptureUseCaseDropsStaleAuthorityReadAfterAccountSwitch()",
        "func testTextSourceCaptureUseCaseDoesNotExposeWhenClosedPilotPolicyIsUnavailable()",
        "func testArchiveCreationOptionsKeepOwnerTruthSourceHiddenByDefault()",
    ):
        require(test_name in tests, f"text Source test missing: {test_name}")

    print("Owner Truth text Source capture iOS contract check passed")


if __name__ == "__main__":
    main()
