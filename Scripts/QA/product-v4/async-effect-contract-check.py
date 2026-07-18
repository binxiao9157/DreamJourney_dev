#!/usr/bin/env python3
"""Keep the V4 async-effect contract typed, fail-closed, and body-free."""

from __future__ import annotations

import sys
from pathlib import Path


ROOT = Path(__file__).resolve().parents[3]
BACKEND = ROOT.parent / "DreamJourneyBackend"


def require(condition: bool, message: str) -> None:
    if not condition:
        raise AssertionError(message)


def main() -> None:
    client = ROOT / "DreamJourney/Sources/Services/DreamJourneyBackendClient.swift"
    contracts = BACKEND / "app/async_effects/contracts.py"
    migration = BACKEND / "db/migrations/0013_async_effects_kernel.sql"
    runtime_config = BACKEND / "app/services/runtime_config.py"

    for path in (client, contracts, migration, runtime_config):
        require(path.is_file(), f"missing async effect contract artifact: {path}")

    client_source = client.read_text(encoding="utf-8")
    contract_source = contracts.read_text(encoding="utf-8")
    migration_source = migration.read_text(encoding="utf-8").lower()
    runtime_source = runtime_config.read_text(encoding="utf-8")

    for token in (
        "enum AsyncEffectOperationStatus",
        "struct AsyncEffectReceiptSummary",
        "var representsServerCompletion: Bool",
        "struct AsyncEffectRuntimeCapability",
        "let asyncEffect: AsyncEffectRuntimeCapability",
        "self.asyncEffect = AsyncEffectRuntimeCapability(json: asyncEffect)",
    ):
        require(token in client_source, f"iOS async effect receipt boundary missing: {token}")

    require(
        "var localSignalsAreServerCompletion: Bool {\n        false\n    }" in client_source,
        "local timer/notification must not be represented as server completion",
    )
    for token in (
        "class AsyncEffectIntent",
        "payload_hash",
        "resolve_async_effect_runtime_status",
        "asyncEffectV1Disabled",
    ):
        require(token in contract_source, f"backend async effect contract missing: {token}")
    require("payload jsonb" not in migration_source, "effect kernel must not persist payload bodies")
    require("credential jsonb" not in migration_source, "effect kernel must not persist credentials")
    require('"asyncEffect"' in runtime_source, "runtime contract must expose the disabled state")

    print("Async effect typed contract static check passed")


if __name__ == "__main__":
    try:
        main()
    except AssertionError as exc:
        print(f"Async effect typed contract static check failed: {exc}", file=sys.stderr)
        raise SystemExit(1)
