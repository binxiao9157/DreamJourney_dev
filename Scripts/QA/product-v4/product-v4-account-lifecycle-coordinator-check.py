#!/usr/bin/env python3
"""Guard the WI-S0-01-08A AccountLifecycleCoordinator production contract."""

import re
from pathlib import Path


ROOT = Path(__file__).resolve().parents[3]
SOURCE = ROOT / "DreamJourney/Sources/App/AccountLifecycleCoordinator.swift"
MODEL = ROOT / "Scripts/QA/product-v4/account-lifecycle-coordinator-model-smoke.swift"
RUNNER = ROOT / "Scripts/QA/product-v4/run-account-lifecycle-coordinator-gate.sh"


def require(condition: bool, message: str) -> None:
    if not condition:
        raise AssertionError(message)


def declaration_body(source: str, declaration: str) -> str:
    match = re.search(rf"\b(?:struct|class|actor|enum)\s+{re.escape(declaration)}\b", source)
    require(match is not None, f"production contract missing declaration: {declaration}")
    brace = source.find("{", match.end())
    require(brace >= 0, f"production declaration has no body: {declaration}")
    depth = 0
    for index in range(brace, len(source)):
        if source[index] == "{":
            depth += 1
        elif source[index] == "}":
            depth -= 1
            if depth == 0:
                return source[brace + 1:index]
    raise AssertionError(f"production declaration is unterminated: {declaration}")


def function_body(source: str, signature: str) -> str:
    start = source.find(signature)
    require(start >= 0, f"production contract missing function: {signature}")
    brace = source.find("{", start)
    require(brace >= 0, f"production function has no body: {signature}")
    depth = 0
    for index in range(brace, len(source)):
        if source[index] == "{":
            depth += 1
        elif source[index] == "}":
            depth -= 1
            if depth == 0:
                return source[brace + 1:index]
    raise AssertionError(f"production function is unterminated: {signature}")


def require_all(source: str, snippets: tuple[str, ...], contract: str) -> None:
    for snippet in snippets:
        require(snippet in source, f"{contract} missing: {snippet}")


def main() -> None:
    require(SOURCE.is_file(), "AccountLifecycleCoordinator production file is missing")
    source = SOURCE.read_text(encoding="utf-8")
    model = MODEL.read_text(encoding="utf-8")
    runner = RUNNER.read_text(encoding="utf-8")

    require_all(
        source,
        (
            "enum AccountLifecycleEvent",
            "case coldStartRecovery",
            "case switchAccount",
            "case logout",
            "case privateSuspension",
            "case accountDeletion",
        ),
        "AccountLifecycleEvent",
    )
    require_all(
        source,
        (
            "enum AccountLifecyclePhase",
            "case fence",
            "case cancelEffects",
            "case unmountRuntime",
            "case clearProjection",
            "case clearNotification",
            "case retainOrPurgeDraft",
            "case finalize",
        ),
        "AccountLifecyclePhase",
    )
    require_all(
        source,
        (
            "enum AccountLifecycleModuleOutcome",
            "case retainedLocked",
            "case unmounted",
            "case cancelled",
            "case cleared",
            "case purged",
            "case skipped",
            "case failed",
        ),
        "AccountLifecycleModuleOutcome",
    )

    require("struct AccountLifecycleContext" in source, "AccountLifecycleContext production contract is missing")
    context_body = declaration_body(source, "AccountLifecycleContext")
    require("AccountLease" in context_body, "lifecycle context must be able to retain the prior AccountLease")

    descriptor_body = declaration_body(source, "AccountLifecycleModuleDescriptor")
    require_all(
        descriptor_body,
        ("moduleId", "phase", "policy"),
        "AccountLifecycleModuleDescriptor",
    )

    module_receipt = declaration_body(source, "AccountLifecycleModuleReceipt")
    require_all(
        module_receipt,
        ("operationId", "moduleId", "event", "outcome", "remainingLocalData", "detailCode"),
        "AccountLifecycleModuleReceipt",
    )
    operation_receipt = declaration_body(source, "AccountLifecycleOperationReceipt")
    require("operationId" in operation_receipt, "operation receipt must identify its non-sensitive operation")
    require("AccountLifecycleModuleReceipt" in operation_receipt, "operation receipt must aggregate module receipts")

    forbidden_receipt_identifiers = (
        "subject",
        "subjectId",
        "vault",
        "vaultId",
        "session",
        "sessionId",
        "token",
        "tokenFamilyId",
        "accessToken",
        "refreshToken",
        "credential",
    )
    combined_receipts = module_receipt + operation_receipt
    for identifier in forbidden_receipt_identifiers:
        require(
            re.search(rf"\b{re.escape(identifier)}\b", combined_receipts, re.IGNORECASE) is None,
            f"lifecycle receipts must not contain sensitive field: {identifier}",
        )

    require(
        "actor AccountLifecycleCoordinator" in source
        or "final class AccountLifecycleCoordinator" in source,
        "AccountLifecycleCoordinator must provide one serialized production boundary",
    )
    require("sorted" in source, "coordinator must establish a stable phase order before execution")
    require(
        "executionOrder" in source or "sortOrder" in source or "rawValue" in source,
        "phase sorting must use an explicit stable order",
    )
    require(
        re.search(r"(?:completed|cached|operation)\w*(?:Receipts?|Operations?)", source, re.IGNORECASE) is not None,
        "coordinator must retain completed operations for operationId idempotency",
    )
    perform_body = function_body(source, "func perform(")
    require(
        "for registration in orderedRegistrations" in perform_body,
        "coordinator must collect one receipt per ordered module",
    )
    execution_start = perform_body.index("for registration in orderedRegistrations")
    execution_end = perform_body.index("let orderedReceipts", execution_start)
    execution_loop = perform_body[execution_start:execution_end]
    require("result.outcome" in execution_loop, "module result must be copied into its receipt")
    require("break" not in execution_loop, "a failed module must not abort later module collection")
    validated_result = function_body(source, "private static func validatedResult(")
    require("result.outcome == .failed" in validated_result, "failed module outcomes must remain valid receipts")

    registration_body = declaration_body(source, "AccountLifecycleModuleRegistration")
    synchronous_handler = (
        ") -> AccountLifecycleModuleResult" in registration_body
        and "async" not in registration_body
    )
    explicit_callback_guard = (
        re.search(r"guard[^\n{]*(?:operationId|generation)", source) is not None
        and "generation" in source
    )
    require(
        explicit_callback_guard or synchronous_handler,
        "callback commits must be generation-guarded or excluded by a synchronous module boundary",
    )
    require("oldGeneration" in source, "operation identity must retain the captured account generation")
    require(
        "operationIdentityConflictReceipt" in perform_body,
        "an operationId replay with another event/generation must fail closed",
    )

    require_all(
        model,
        (
            "modules must execute in stable phase and registration order",
            "a failed module must not prevent later phases from producing receipts",
            "the same operation must return its original idempotent receipt",
            "an old generation callback must not commit into a newer operation",
            "receipts must not serialize raw identity or credential values",
        ),
        "AccountLifecycleCoordinator model smoke",
    )
    require("swiftc" in runner, "gate runner must compile the standalone Swift model")
    require(MODEL.name in runner, "gate runner must execute the lifecycle model smoke")
    require(Path(__file__).name in runner, "gate runner must execute the production static check")

    print("PASS: Product V4 AccountLifecycleCoordinator static check")


if __name__ == "__main__":
    main()
