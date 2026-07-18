#!/usr/bin/env python3

from pathlib import Path
import re


ROOT = Path(__file__).resolve().parents[3]
STORE = ROOT / "DreamJourney/Sources/Services/AccountPrivateMediaStore.swift"
CONTROLLER = ROOT / "DreamJourney/Sources/Modules/Home/AIRecordingViewController.swift"
MEMORY_DETAIL = ROOT / "DreamJourney/Sources/Modules/Memory/MemoryDetailViewController.swift"
MEMORY_ANNOTATION = ROOT / "DreamJourney/Sources/Modules/Map/MemoryAnnotationView.swift"
MAP_CONTROLLER = ROOT / "DreamJourney/Sources/Modules/Map/MapFootprintViewController.swift"


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


def require_ordered(source: str, snippets: tuple[str, ...], label: str) -> None:
    cursor = 0
    for snippet in snippets:
        index = source.find(snippet, cursor)
        require(index >= 0, f"{label} missing or out of order: {snippet}")
        cursor = index + len(snippet)


def main() -> None:
    require(STORE.is_file(), f"missing account private media store: {STORE}")
    require(CONTROLLER.is_file(), f"missing AIRecording controller: {CONTROLLER}")
    store = STORE.read_text()
    controller = CONTROLLER.read_text()
    memory_detail = MEMORY_DETAIL.read_text()
    memory_annotation = MEMORY_ANNOTATION.read_text()
    map_controller = MAP_CONTROLLER.read_text()

    for snippet in (
        "final class AccountPrivateMediaStore",
        "static let shared = AccountPrivateMediaStore()",
        ".applicationSupportDirectory",
        ".cachesDirectory",
        '"DreamJourney"',
        '"AccountPrivateMedia"',
        '"photos"',
        '"photo-staging"',
        '"recording-staging"',
        "sourceLocatorHash",
        "sourceContentHash",
        "disposition",
        "processedAt",
        "case quarantined",
        "case discarded",
        "retireLegacyGlobalMedia()",
        "legacyRetirementReceipts()",
        "writePhotoStaging(",
        "promotePhotoStaging(",
        "persistentPhotoReference(",
        "resolvePersistentPhoto(",
        "purgeExpiredStaging(",
    ):
        require(snippet in store, f"store contract missing: {snippet}")

    scope_body = function_body(store, "scopeDigest")
    require("subjectId" in scope_body, "scope digest must include AccountLease subjectId")
    require("vaultId" in scope_body, "scope digest must include AccountLease vaultId")
    require(
        scope_body.count("lengthDelimited(") == 2,
        "scope digest must use collision-safe length-delimited subject and vault components",
    )
    for forbidden in ("sessionId", "generation", "generationId", "authorityEpoch"):
        require(
            forbidden not in scope_body,
            f"scope digest must remain stable across session/generation rotation: {forbidden}",
        )

    photo_write = function_body(store, "writePhoto")
    require_ordered(
        photo_write,
        (
            "validateLease(accountLease, at: .request)",
            "data.write(",
            "validateLease(accountLease, at: .commit)",
        ),
        "photo lease fence",
    )
    require("discard(" in photo_write, "stale photo writes must delete their output")

    prepare_recording = function_body(store, "prepareRecordingStaging")
    require(
        "validateLease(accountLease, at: .request)" in prepare_recording,
        "recording staging must validate before exposing a write target",
    )
    finalize_recording = function_body(store, "finalizeRecordingStaging")
    require(
        "validateLease(accountLease, at: .commit)" in finalize_recording,
        "recording staging must validate after AVAudioRecorder writing",
    )
    require("discard(" in finalize_recording, "stale recording staging must be deleted")

    retirement = function_body(store, "retireLegacyGlobalMedia")
    require("legacyPhotosDirectoryURL" in retirement, "legacy photos must be retired")
    require(
        "legacySessionRecordingsDirectoryURL" in retirement,
        "legacy global recordings must be retired",
    )
    require(".quarantined" in retirement, "legacy photos must use quarantine disposition")
    require(".discarded" in retirement, "legacy recordings must use discard disposition")
    require(
        store.count('appendingPathComponent("TGSessionRecordings"') == 1,
        "TGSessionRecordings may only appear in the legacy retirement locator",
    )
    require(
        store.count('appendingPathComponent("photos"') == 1,
        "the old photos component may only appear in the legacy retirement locator",
    )
    for forbidden_api in ("migrateLegacy", "claimLegacy", "mountLegacy", "resolveLegacy"):
        require(forbidden_api not in store, f"legacy media must never be mounted: {forbidden_api}")

    for snippet in (
        "private let privateMediaStore = AccountPrivateMediaStore.shared",
        "private var sessionRecordingArtifact: AccountPrivateMediaArtifact?",
        "private var lastSessionRecordingArtifact: AccountPrivateMediaArtifact?",
        "privateMediaStore.writePhotoStaging(",
        "privateMediaStore.promotePhotoStaging(",
        "privateMediaStore.prepareRecordingStaging(",
        "privateMediaStore.finalizeRecordingStaging(",
        "privateMediaStore.discard(",
        "privateMediaStore.retireLegacyGlobalMedia()",
    ):
        require(snippet in controller, f"AIRecording store integration missing: {snippet}")

    save_photo = function_body(controller, "savePhotoToLocal")
    require(
        "validateMediaPickerAccountLease(accountLease, at: .commit)" in save_photo,
        "photo integration must preserve its originating lease fence",
    )
    require(
        "privateMediaStore.writePhotoStaging(" in save_photo,
        "AIRecording photo writes must delegate to AccountPrivateMediaStore",
    )
    start_recording = function_body(controller, "startSessionRecording")
    require(
        "privateMediaStore.prepareRecordingStaging(" in start_recording,
        "AIRecording must request scoped recording staging",
    )
    stop_recording = function_body(controller, "stopSessionRecording")
    require(
        "discardStaleSessionRecording()" not in stop_recording,
        "an idempotent second stop must not delete the previously finalized recording",
    )
    require(
        "privateMediaStore.finalizeRecordingStaging(" in stop_recording,
        "AIRecording must finalize recording staging through the store",
    )
    stale_cleanup = function_body(controller, "discardStaleSessionRecording")
    require(
        "privateMediaStore.discard(" in stale_cleanup,
        "account switch and stale lease cleanup must remove this controller's staging",
    )
    legacy_retirement = function_body(controller, "retireLegacyGlobalMedia")
    require(
        "DispatchQueue.global(qos: .utility).async" in legacy_retirement,
        "legacy media hashing and quarantine must not block the Home viewDidLoad main thread",
    )

    photo_association = function_body(controller, "associatePhotoToMemory")
    require(
        re.search(
            r"func associatePhotoToMemory\([\s\S]*?accountLease:\s*AccountLease[\s\S]*?\)\s*\{",
            controller,
        )
        is not None,
        "photo association must accept the originating AccountLease",
    )
    for snippet in (
        "getAllByOwner(accountLease.subjectId, accountLease: accountLease)",
        "ownerId: accountLease.subjectId",
        "accountLease: accountLease",
    ):
        require(snippet in photo_association, f"photo owner-scoped Memory API missing: {snippet}")
    require(
        "MemoryRepository.shared.getAll()" not in photo_association
        and "MemoryRepository.shared.update(match)" not in photo_association,
        "photo association must not let MemoryRepository recapture the current account",
    )

    memoir_generation = function_body(controller, "handleMemoirGeneration")
    for snippet in (
        "MemoirRepository.shared.captureAccountLeaseAndOwner()",
        "memoirAuthorization.accountLease == accountLease",
        "MemoirRepository.shared.validateAccountLease(",
        "ownerId: memoirAuthorization.ownerId",
        "accountLease: accountLease",
    ):
        require(snippet in memoir_generation, f"explicit Memoir generation scope missing: {snippet}")
    require(
        re.search(
            r"MemoirFlowManager\.shared\.startGeneration\([\s\S]*?"
            r"accountLease:\s*accountLease,[\s\S]*?"
            r"ownerId:\s*memoirAuthorization\.ownerId",
            memoir_generation,
        )
        is not None,
        "Memoir generation must forward the original dialog lease and verified owner",
    )
    recording_transfer = function_body(controller, "persistLastSessionRecording")
    for snippet in (
        "MemoirRepository.shared.saveRecording(",
        "sessionId: recordingSessionId",
        "accountLease: accountLease",
        "ownerId: ownerId",
        "privateMediaStore.discard(stagingArtifact)",
    ):
        require(snippet in recording_transfer, f"Memoir recording transfer missing: {snippet}")
    require(
        "pendingPhotoArtifacts" in controller
        and "discardPendingPhotoArtifacts()" in controller,
        "uncommitted Home photo staging must be tracked and cleaned on scope reset",
    )
    for source, label in (
        (memory_detail, "Memory detail"),
        (memory_annotation, "Map annotation"),
    ):
        require(
            "AccountPrivateMediaStore.shared.resolvePersistentPhoto(" in source,
            f"{label} must resolve owner-scoped persistent photo references",
        )
        require(
            "memory.authorId == accountLease.subjectId" in source,
            f"{label} must not resolve another owner's local photo scope",
        )
    require(
        "accountLease: isHost ? accountLease : nil" in map_controller,
        "guest map annotations must not receive the host-only local media lease",
    )

    forbidden_controller_patterns = (
        r"\.documentDirectory\b",
        r"\.temporaryDirectory\b",
        r"\bTGSessionRecordings\b",
        r"FileManager\.default",
        r"\bdata\.write\(",
    )
    for pattern in forbidden_controller_patterns:
        require(
            re.search(pattern, controller) is None,
            f"AIRecording retains a forbidden direct/global media path: {pattern}",
        )

    print("Account private media store static check passed")


if __name__ == "__main__":
    main()
