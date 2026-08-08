#!/usr/bin/env python3
"""Guard owner-scoped draft/media purge after an account lease is fenced."""

from pathlib import Path
import sys


ROOT = Path(__file__).resolve().parents[3]


def read(relative: str) -> str:
    return (ROOT / relative).read_text(encoding="utf-8")


def function_body(source: str, signature: str) -> str:
    start = source.find(signature)
    if start < 0:
        return ""
    brace = source.find("{", start)
    if brace < 0:
        return ""
    depth = 0
    for index in range(brace, len(source)):
        if source[index] == "{":
            depth += 1
        elif source[index] == "}":
            depth -= 1
            if depth == 0:
                return source[brace + 1 : index]
    return ""


def require(condition: bool, message: str, failures: list[str]) -> None:
    if not condition:
        failures.append(message)


def main() -> None:
    failures: list[str] = []
    archive = read("DreamJourney/Sources/Modules/Archive/MemoryArchiveRepository.swift")
    media = read("DreamJourney/Sources/Services/AccountPrivateMediaStore.swift")
    memoir = read("DreamJourney/Sources/Memoir/MemoirRepository.swift")
    memory = read("DreamJourney/Sources/Services/MemoryRepository.swift")
    registry = read("DreamJourney/Sources/App/AccountLifecycleRuntimeRegistry.swift")

    archive_purge = function_body(
        archive,
        "func purgeLocalArchiveDataForAccountDeletion(accountLease: AccountLease)",
    )
    require(bool(archive_purge), "Archive deletion purge API is missing", failures)
    require(
        "localStorage.purgeAccount(accountLease: accountLease)" in archive_purge,
        "Archive purge must remove every subject/vault scoped archive partition",
        failures,
    )
    require(
        "UserManager.shared.currentUser" not in archive_purge
        and "accountLeaseRuntime.validate" not in archive_purge,
        "Archive purge must accept the captured old lease after the current lease is fenced",
        failures,
    )

    media_purge = function_body(
        media,
        "func purgeAccountDataForAccountDeletion(accountLease: AccountLease)",
    )
    require(bool(media_purge), "Account-private media deletion purge API is missing", failures)
    require(
        "Self.scopeDigest(for: accountLease)" in media_purge,
        "Account-private media purge must derive the exact old account scope",
        failures,
    )
    require(
        "persistentPhoto" in media_purge and "recordingStaging" in media_purge,
        "Account-private media purge must cover Application Support and Caches",
        failures,
    )

    memoir_purge = function_body(
        memoir,
        "func purgeLocalDataForAccountDeletion(accountLease: AccountLease)",
    )
    require(bool(memoir_purge), "Memoir deletion purge API is missing", failures)
    require(
        "storage.purge(scope:" in memoir_purge,
        "Memoir purge must remove only the old owner scope",
        failures,
    )

    require(
        memory.count("func purgeLocalDataForAccountDeletion(accountLease: AccountLease)") >= 2,
        "Memory items and map presentation state both need deletion purge APIs",
        failures,
    )
    require(
        "scope.storageKey" in memory
        and "scope.mapPresentationStorageKey" in memory
        and "scope.quarantineStorageKey" in memory
        and "scope.mapQuarantineStorageKey" in memory,
        "Memory deletion must cover owner data and owner-scoped quarantine keys",
        failures,
    )

    disposition = function_body(
        registry,
        "private static func explicitDraftDisposition(",
    )
    for call in (
        "OwnerTruthMediaTaskRecoveryCoordinator.shared.cancelForAccountLifecycle()",
        "purgeLocalArchiveDataForAccountDeletion",
        "purgeAccountDataForAccountDeletion",
        "MemoirRepository.shared.purgeLocalDataForAccountDeletion",
        "MemoryRepository.shared.purgeLocalDataForAccountDeletion",
        "MemoryMapPresentationStore.shared.purgeLocalDataForAccountDeletion",
    ):
        require(call in disposition, f"LM-08 registry is missing {call}", failures)
    require(
        "context.event == .accountDeletion" in disposition,
        "LM-08 must purge only for account deletion",
        failures,
    )
    require(
        "explicitDraftsRetainedOwnerLocked" in disposition,
        "ordinary logout/switch must retain old-owner drafts",
        failures,
    )

    if failures:
        print("FAIL: WI-S0-01-08C explicit draft purge contract:", file=sys.stderr)
        for failure in failures:
            print(f"  - {failure}", file=sys.stderr)
        raise SystemExit(1)
    print(
        "PASS: WI-S0-01-08C explicit draft purge "
        "archive=ownerScoped media=ownerScoped memoir=ownerScoped memoryMap=ownerScoped"
    )


if __name__ == "__main__":
    main()
