#!/usr/bin/env python3

from pathlib import Path


ROOT = Path(__file__).resolve().parents[3]
STORAGE = ROOT / "DreamJourney/Sources/Modules/Archive/ArchiveLocalStorage.swift"
ITEM = ROOT / "DreamJourney/Sources/Modules/Archive/MemoryArchiveItem.swift"
REPOSITORY = ROOT / "DreamJourney/Sources/Modules/Archive/MemoryArchiveRepository.swift"
MEDIA_STORE = ROOT / "DreamJourney/Sources/Modules/Archive/ArchiveMediaStore.swift"
ARCHIVE_VIEW = ROOT / "DreamJourney/Sources/Modules/Archive/MemoryArchiveViewController.swift"
AUDIO_ENTRY = ROOT / "DreamJourney/Sources/Modules/Archive/MemoryArchiveAudioRecorderViewController.swift"
TEXT_ENTRY = ROOT / "DreamJourney/Sources/Modules/Archive/MemoryArchiveTextEntryViewController.swift"
DETAIL = ROOT / "DreamJourney/Sources/Modules/Archive/MemoryArchiveDetailViewController.swift"
RUNNER = ROOT / "Scripts/QA/product-v4/run-archive-local-storage-gate.sh"


def require(condition: bool, message: str) -> None:
    if not condition:
        raise AssertionError(message)


def main() -> None:
    require(STORAGE.is_file(), "ArchiveLocalStorage production contract is missing")
    storage = STORAGE.read_text()
    item = ITEM.read_text()
    repository = REPOSITORY.read_text()
    media_store = MEDIA_STORE.read_text()
    archive_view = ARCHIVE_VIEW.read_text()
    audio_entry = AUDIO_ENTRY.read_text()
    text_entry = TEXT_ENTRY.read_text()
    detail = DETAIL.read_text()
    runner = RUNNER.read_text()

    for snippet in (
        "struct ArchiveStorageScope",
        "struct ArchiveStoreEnvelope",
        "enum ArchiveQuarantineReason",
        "struct ArchiveLegacyMigrationReceipt",
        "static func partitionLegacyItems(",
        "static func validate(",
        "static func merge(",
        "mediaDirectoryRelativePath",
        "contentHash",
    ):
        require(snippet in storage, f"Archive storage contract missing: {snippet}")

    require(
        "assignOwnerIfNeededForCurrentUser" not in repository,
        "legacy archive records must not be auto-claimed by the current account",
    )
    require(
        ".assigningOwnerIfNeeded(lease.accountUserId)" not in repository,
        "lease reads must not auto-claim legacy records",
    )
    require(
        "ArchiveLocalStorage.shared" in repository,
        "repository must use the scoped archive store",
    )
    require(
        "assigningOwnerIfNeeded(_ ownerUserId: String)" not in item,
        "generic legacy owner assignment API must be retired",
    )
    for snippet in (
        ".applicationSupportDirectory",
        ".cachesDirectory",
        "scope.mediaDirectoryRelativePath",
        "UUID().uuidString",
        "FileProtectionType.complete",
        "isExcludedFromBackup = true",
        "checksumMismatch",
        "sizeMismatch",
        "migrateLegacyOriginal(",
        "receipt.migratedItemIds.contains(item.id)",
    ):
        require(snippet in media_store, f"Archive media isolation contract missing: {snippet}")

    require(
        'localPath: nil' in item,
        "remote archive JSON must never hydrate a local path",
    )
    require(
        "candidateDirectoryNames" not in item
        and "archiveLocalDirectoryNames" not in item
        and ".documentDirectory" not in item,
        "archive item must not perform global basename recovery",
    )
    require(
        "isAuthorizedForCurrentLocalMediaRead" in item
        and "AccountLeaseRuntime.shared.validate(accountLease, at: .runtime).allowed" in item
        and "DigitalHumanContextStore.shared.current" in item,
        "local media resolution must revalidate account lease and active persona authorization",
    )
    require(
        "ArchiveMediaStore.shared" in repository
        and "removeMedia(for: removedItem, scope: lease.storageScope)" in repository,
        "single-item delete must clean owner-scoped media",
    )

    for source, name in (
        (archive_view, "archive view"),
        (audio_entry, "audio entry"),
        (text_entry, "time-letter entry"),
    ):
        require(".documentDirectory" not in source, f"{name} must not write shared Documents media")
        require("ArchiveMediaStore.shared" in source, f"{name} must route media through ArchiveMediaStore")

    require(
        "guard self.repository.add(item) else" in archive_view
        and "guard repository.add(item) else" in archive_view,
        "archive creation UI must handle durable persistence failure",
    )

    require(
        "item.isMediaUploadIntentEligible && canManageCurrentArchiveItem" in detail
        and "item.analysisStatus == .failed && canManageCurrentArchiveItem" in detail,
        "read-only archive detail must not expose upload or re-analysis actions",
    )
    require(
        "guard let accountLease = detailAccountLease" in detail
        and "validateDetailAccountLease(accountLease, at: .runtime)" in detail,
        "archive detail callbacks must retain and validate their original account lease",
    )
    require(
        "ArchiveMediaStore.swift" in runner,
        "archive local storage gate must independently compile ArchiveMediaStore",
    )

    print("Archive local storage static check passed")


if __name__ == "__main__":
    main()
