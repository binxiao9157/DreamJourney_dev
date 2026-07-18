#!/usr/bin/env python3
"""Keep the V1 Archive-to-Owner-Truth boundary honest and additive."""

from __future__ import annotations

import sys
from pathlib import Path


ROOT = Path(__file__).resolve().parents[3]
BACKEND = ROOT.parent / "DreamJourneyBackend"


def require(condition: bool, message: str) -> None:
    if not condition:
        raise AssertionError(message)


def main() -> None:
    archive_item = ROOT / "DreamJourney/Sources/Modules/Archive/MemoryArchiveItem.swift"
    archive_repository = ROOT / "DreamJourney/Sources/Modules/Archive/MemoryArchiveRepository.swift"
    source_commands = BACKEND / "app/domain/owner_truth/source_commands.py"
    source_facade = BACKEND / "app/services/owner_truth_source.py"
    migration = BACKEND / "db/migrations/0012_owner_truth_source_commands.sql"

    for path in (archive_item, archive_repository, source_commands, source_facade, migration):
        require(path.is_file(), f"missing CreateSource compatibility artifact: {path}")

    item_source = archive_item.read_text(encoding="utf-8")
    repository_source = archive_repository.read_text(encoding="utf-8")
    command_source = source_commands.read_text(encoding="utf-8")
    facade_source = source_facade.read_text(encoding="utf-8")
    migration_source = migration.read_text(encoding="utf-8")

    require(
        "kind == .text || kind == .timeLetter" in item_source,
        "only text and time-letter records may enter the legacy archive sync lane",
    )
    require(
        "func enforcingLocalOnlyPhotoTransferState()" in item_source,
        "photo local-only transfer policy is missing",
    )
    for token in (
        "ArchiveMediaUploadStatus.localOnly.rawValue",
        "removeValue(forKey: Self.backendSyncStateMetadataKey)",
        "removeValue(forKey: Self.backendSyncErrorMetadataKey)",
        "removeValue(forKey: Self.backendSyncAttemptedAtMetadataKey)",
    ):
        require(token in item_source, f"photo transfer cleanup missing: {token}")

    require(
        repository_source.count("let ownedItem = item.enforcingLocalOnlyPhotoTransferState()") == 2,
        "Archive add/update must both enforce photo local-only transfer state",
    )
    require(
        repository_source.count("if shouldAttemptBackendSync {\n            syncToBackend") == 2,
        "Archive add/update must only call backend sync for eligible records",
    )
    require(
        "guard item.isPublicBackendSyncEligible else" in repository_source,
        "direct backend sync callers must preserve the eligibility boundary",
    )

    for token in (
        "class CreateTextSourceCommand",
        "expected_version",
        "command_id_hash",
        "receipt_id",
    ):
        require(token in command_source, f"CreateSource contract missing: {token}")
    require("_TEXT_KINDS = frozenset({\"text\", \"textnote\"})" in facade_source, "facade must be text-only")
    require("reason=\"localOnlyMedia\"" in facade_source, "media must report an explicit local-only result")
    require("owner_truth.source_command_receipts" in migration_source, "CreateSource receipt relation missing")
    require("owner_truth_sources_payload_immutable" in migration_source, "Source payload immutability guard missing")

    print("Owner Truth Archive compatibility static check passed")


if __name__ == "__main__":
    try:
        main()
    except AssertionError as exc:
        print(f"Owner Truth Archive compatibility static check failed: {exc}", file=sys.stderr)
        raise SystemExit(1)
