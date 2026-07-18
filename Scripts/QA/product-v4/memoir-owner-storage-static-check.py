#!/usr/bin/env python3

import re
from pathlib import Path


ROOT = Path(__file__).resolve().parents[3]
MODEL = ROOT / "DreamJourney/Sources/Memoir/MemoirModel.swift"
REPOSITORY = ROOT / "DreamJourney/Sources/Memoir/MemoirRepository.swift"
SERVICE = ROOT / "DreamJourney/Sources/Memoir/MemoirService.swift"
FLOW = ROOT / "DreamJourney/Sources/Memoir/MemoirFlowManager.swift"
SMOKE = ROOT / "Scripts/QA/product-v4/memoir-owner-storage-model-smoke.swift"


def require(condition: bool, message: str) -> None:
    if not condition:
        raise AssertionError(message)


def main() -> None:
    for path in (MODEL, REPOSITORY, SERVICE, FLOW, SMOKE):
        require(path.is_file(), f"missing Memoir owner-storage surface: {path}")

    model = MODEL.read_text()
    repository = REPOSITORY.read_text()
    service = SERVICE.read_text()
    flow = FLOW.read_text()

    require(
        not re.search(r'authorId:\s*String\s*=\s*"user_001"', model),
        "MemoirModel must not default new writes to user_001",
    )
    require("authorId: String," in model, "MemoirModel creation must require an explicit owner")

    for snippet in (
        "struct MemoirStorageScope",
        "struct MemoirStoreEnvelope",
        "enum MemoirQuarantineReason",
        "struct MemoirLegacyMigrationReceipt",
        "final class MemoirOwnerStorage",
        "MemoirOwnerStoragePolicy.validate(",
        "recordsDirectoryRelativePath",
        "recordingsDirectoryRelativePath",
        "scope.subjectId",
        "scope.vaultId",
        "scope.ownerId",
        "migrationReceipts()",
        "quarantineRecords()",
    ):
        require(snippet in repository, f"Memoir scoped storage contract missing: {snippet}")

    require("seedMockData" not in repository, "production Memoir startup must not write mock seed data")
    require(
        'appendingPathComponent("recordings", isDirectory: true)' not in repository
        or "scope.recordingsDirectoryRelativePath" in repository,
        "recording paths must resolve through the account-owner scope",
    )
    require(
        "func save(_ memoir: MemoirModel, accountLease: AccountLease, ownerId: String) -> Bool"
        in repository,
        "Memoir writes must accept the originally captured AccountLease and owner",
    )
    require(
        "func delete(id: String, accountLease: AccountLease, ownerId: String) -> Bool"
        in repository,
        "Memoir deletes must accept the originally captured AccountLease and owner",
    )
    require(
        repository.count("accountLeaseRuntime.validate(accountLease, at: .commit)") >= 3,
        "Memoir JSON and recording commits must reject stale leases",
    )
    for snippet in (
        "syncToMemoryRepository(",
        "normalizedOwner == accountLease.subjectId",
        "MemoryRepository.shared.get(",
        "MemoryRepository.shared.add(",
        "ownerId: ownerId",
        "accountLease: accountLease",
    ):
        require(snippet in repository, f"Memoir-to-Memory owner bridge missing: {snippet}")
    require(
        "MemoryRepository.shared.add(memory)" not in repository,
        "Memoir-to-Memory bridge must not recapture a global/current owner",
    )

    for snippet in (
        "accountLease: AccountLease",
        "ownerId: String",
        "at: .request",
        "at: .runtime",
        "at: .commit",
        "MemoirRepository.shared.save(",
        "accountLease: accountLease",
        "ownerId: ownerId",
    ):
        require(snippet in service, f"MemoirService lease pipeline missing: {snippet}")
    require(
        "parseMemoirResponse(content, ownerId: ownerId)" in service
        and "createFallbackMemoir(from: content, ownerId: ownerId)" in service
        and "private func createFallbackMemoir(from rawText: String, ownerId: String)"
        in service,
        "normal and fallback Memoir creation must bind the captured owner",
    )

    for snippet in (
        "struct MemoirGenerationRequestScope",
        "captureGenerationRequestScope()",
        "validateGenerationRequestScope(",
        "accountLease: requestScope.accountLease",
        "ownerId: requestScope.ownerId",
        "at: .request",
        "at: .runtime",
        "at: .commit",
        "at: .ui",
    ):
        require(snippet in flow, f"MemoirFlow AccountLease propagation missing: {snippet}")
    require(
        "first(where: { $0.title == memoirTitle })" not in flow,
        "ready-banner lookup must use scoped memoir id rather than a cross-owner title match",
    )

    print("Memoir owner storage static check passed")


if __name__ == "__main__":
    main()
