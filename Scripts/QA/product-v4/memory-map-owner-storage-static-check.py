#!/usr/bin/env python3

from pathlib import Path
import re


ROOT = Path(__file__).resolve().parents[3]
MODEL = ROOT / "DreamJourney/Sources/Services/MemoryModel.swift"
REPOSITORY = ROOT / "DreamJourney/Sources/Services/MemoryRepository.swift"
MAP = ROOT / "DreamJourney/Sources/Modules/Map/MapFootprintViewController.swift"
DETAIL = ROOT / "DreamJourney/Sources/Modules/Memory/MemoryDetailViewController.swift"


def require(condition: bool, message: str) -> None:
    if not condition:
        raise AssertionError(message)


def main() -> None:
    model = MODEL.read_text()
    repository = REPOSITORY.read_text()
    map_source = MAP.read_text()
    detail = DETAIL.read_text()
    production = "\n".join((model, repository, map_source, detail))

    require('"user_001"' not in production, "production Memory/Map must not contain user_001")
    require('"unknown"' not in detail, "Memory detail must not synthesize an unknown actor")
    require(
        'authorId: String = ' not in model,
        "MemoryModel authorId must be explicit",
    )

    for snippet in (
        "struct MemoryStorageScope",
        "struct MemoryStoreEnvelope",
        "enum MemoryQuarantineReason",
        "struct MemoryLegacyMigrationReceipt",
        "case quarantined",
        "contentHash",
        "MemoryMapPresentationStore",
        "accountLeaseRuntime.validate",
        "quarantineLegacyGlobalPayloadIfNeeded",
        "itemIds: [String]",
        '"memory-quarantine-v2|',
        '"memory-receipt-v2|',
    ):
        require(snippet in repository, f"Memory owner storage contract missing: {snippet}")

    require("seedMockData" not in repository, "production memory seeds must be retired")
    require("mockIdPrefix" not in repository, "mock persistence branching must be retired")
    require(
        'defaults.set(data, forKey: Self.legacyPersistKey)' not in repository,
        "the global legacy memory key must be read-only",
    )

    for mutation in (
        "update",
        "delete",
        "addComment",
        "toggleLike",
        "addSupplement",
        "togglePrivacy",
    ):
        owner_lease_signature = re.compile(
            rf"func {mutation}\([\s\S]{{0,500}}?ownerId: String,[\s\S]{{0,160}}?"
            r"accountLease: AccountLease"
        )
        require(
            owner_lease_signature.search(repository) is not None,
            f"owner-aware ID mutation missing: {mutation}",
        )

    require(
        "MemoryMapPresentationStore.shared" in map_source,
        "Map must use the owner-scoped presentation store",
    )
    require(
        "accountLease" in map_source and "validate(accountLease, at: .ui)" in map_source,
        "Map reads must retain and validate AccountLease",
    )
    require(
        '"dj.readMemoryIds"' not in map_source and '"dj.bouncedMemoryIds"' not in map_source,
        "Map controller must not read or write global presentation keys",
    )
    require(
        "defaultImageNames" not in map_source and "fallbackImageName:" not in map_source,
        "Map must not inject fixture display images",
    )

    require(
        "MemoirRepository.shared" not in detail,
        "Memory detail must not fall back to ownerless Memoir storage",
    )
    require("default_memory_" not in detail, "Memory detail fixture image fallback must be removed")
    require(
        "guard let accountLease" in detail
        and "ownerId: memory.authorId" in detail
        and "accountLease: accountLease" in detail,
        "Memory detail mutation must bind the resource owner and retained lease",
    )

    print("Memory/Map owner storage static check passed")


if __name__ == "__main__":
    main()
