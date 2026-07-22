#!/usr/bin/env python3

import json
from pathlib import Path


ROOT = Path(__file__).resolve().parents[3]
INVENTORY = ROOT / "Scripts/QA/product-v4/account-store-inventory-v1.json"
REQUIRED_FIELDS = (
    "surfaceId",
    "dataClass",
    "ownerScope",
    "storage",
    "pathOrKey",
    "writer",
    "readers",
    "cleanup",
    "migration",
    "retention",
    "testOwner",
)
REQUIRED_SOURCE_PATHS = {
    "DreamJourney/Sources/App/AccountLifecycleCoordinator.swift",
    "DreamJourney/Sources/Services/UserManager.swift",
    "DreamJourney/Sources/Services/BackendAuthSessionStore.swift",
    "DreamJourney/Sources/Services/KBLiteManager.swift",
    "DreamJourney/Sources/Services/KnowledgeSyncCoordinator.swift",
    "DreamJourney/Sources/Modules/Archive/MemoryArchiveRepository.swift",
    "DreamJourney/Sources/Services/ConversationMemoryManager.swift",
    "DreamJourney/Sources/Memoir/MemoirRepository.swift",
    "DreamJourney/Sources/Services/MemoryRepository.swift",
    "DreamJourney/Sources/Memoir/VoiceCloneService.swift",
    "DreamJourney/Sources/Services/EchoDelayedReplyStore.swift",
    "DreamJourney/Sources/Modules/Archive/InAppMessageCenter.swift",
    "DreamJourney/Sources/Services/KnowledgeWidgetSnapshotStore.swift",
    "DreamJourney/Sources/Services/KBLitePDFExporter.swift",
    "DreamJourney/Sources/Modules/Knowledge/KBSyncViewController.swift",
    "DreamJourney/Sources/Modules/Profile/ProfileVoiceCloneShellViewController.swift",
    "DreamJourney/Sources/Modules/Echo/DigitalHumanConversationCoordinator.swift",
    "DreamJourney/Sources/Services/DigitalHuman/TencentVirtualmanSDKBridge.swift",
    "DreamJourney/Sources/Memoir/MemoirModel.swift",
    "DreamJourney/Sources/Services/MemoryModel.swift",
    "DreamJourneyWidget/TodayInHistoryProvider.swift",
}


def require(condition: bool, message: str) -> None:
    if not condition:
        raise AssertionError(message)


def has_unknown(value: object) -> bool:
    if isinstance(value, str):
        return value.strip().upper() in {"", "UNKNOWN", "TBD", "TODO"}
    if isinstance(value, list):
        return not value or any(has_unknown(item) for item in value)
    if isinstance(value, dict):
        return not value or any(has_unknown(item) for item in value.values())
    return value is None


def main() -> None:
    payload = json.loads(INVENTORY.read_text())
    require(
        payload.get("schemaVersion") == "dreamjourney.account-store-inventory.v1",
        "account store inventory schema drift",
    )
    require(payload.get("inventoryName") == "AccountStoreInventory", "inventory name drift")
    require(payload.get("authority") == "WI-S0-01-01", "inventory authority drift")
    interpretation = payload.get("interpretation") or {}
    require(
        interpretation.get("registrationIsNotImplementation") is True,
        "inventory must not claim registration is implementation",
    )
    require(
        interpretation.get("cleanupAndMigrationAreObligations") is True,
        "cleanup and migration gaps must remain explicit obligations",
    )
    require(
        interpretation.get("knownGapIsNotUnknownSurface") is True,
        "known unsafe state must remain registered instead of becoming unknown",
    )
    test_carrier = payload.get("testCarrier") or {}
    require(test_carrier.get("type") == "executable shell/model gate", "test carrier drift")
    require(
        (ROOT / test_carrier.get("path", "")).is_file(),
        "account store inventory test carrier is missing",
    )
    require(
        "not simulator" in test_carrier.get("limitation", ""),
        "test carrier must disclose that it is not simulator/runtime-race proof",
    )
    require(
        test_carrier.get("futureRuntimeTestOwner", "").startswith("WI-"),
        "runtime test limitation has no future Work Item owner",
    )

    surfaces = payload.get("surfaces") or []
    require(surfaces, "account store inventory is empty")
    surface_ids = [surface.get("surfaceId") for surface in surfaces]
    require(len(surface_ids) == len(set(surface_ids)), "duplicate surfaceId")
    catalog_ids = [surface.get("catalogId") for surface in surfaces]
    expected_catalog_ids = {f"S{index:02d}" for index in range(1, 18)}
    require(
        set(catalog_ids) == expected_catalog_ids,
        "catalog categories must cover S01..S17",
    )
    require(
        all(catalog_id in expected_catalog_ids for catalog_id in catalog_ids),
        "inventory contains an unregistered catalog category",
    )
    registered_paths: set[str] = set()
    for surface in surfaces:
        surface_id = surface["surfaceId"]
        require(surface_id.startswith(f"{surface['catalogId']}.") , f"catalog mismatch: {surface_id}")
        for field in REQUIRED_FIELDS:
            require(field in surface, f"{surface_id} missing field {field}")
            require(not has_unknown(surface[field]), f"{surface_id} unresolved field {field}")
        require(surface.get("status", "").startswith("REGISTERED_"), f"{surface_id} is not registered")
        require(surface.get("nextWorkItem", "").startswith("WI-"), f"{surface_id} missing next Work Item")

        source_paths = surface.get("sourcePaths") or []
        require(source_paths, f"{surface_id} has no sourcePaths")
        for relative_path in source_paths:
            source_path = ROOT / relative_path
            require(source_path.is_file(), f"{surface_id} source missing: {relative_path}")
            registered_paths.add(relative_path)

        anchors = surface.get("sourceAnchors") or []
        require(anchors, f"{surface_id} has no source anchors")
        for anchor in anchors:
            relative_path = anchor.get("path", "")
            require(relative_path in source_paths, f"{surface_id} anchor path is not registered")
            source_text = (ROOT / relative_path).read_text()
            for snippet in anchor.get("contains") or []:
                require(snippet in source_text, f"{surface_id} source anchor missing: {snippet}")

        checks = surface.get("currentChecks") or []
        require(checks, f"{surface_id} has no executable/static check owner")
        for relative_path in checks:
            require((ROOT / relative_path).is_file(), f"{surface_id} check missing: {relative_path}")

    missing_required = sorted(REQUIRED_SOURCE_PATHS - registered_paths)
    require(not missing_required, f"required private source not inventoried: {missing_required}")

    discovery = payload.get("discovery") or {}
    markers = discovery.get("markers") or []
    roots = discovery.get("roots") or []
    exclusions: dict[str, str] = {}
    for item in discovery.get("exclusions") or []:
        relative_path = item.get("path", "")
        reason = item.get("reason", "")
        guard_path = item.get("guard")
        require(relative_path and reason, "private-surface exclusion requires path and reason")
        require(relative_path not in exclusions, f"duplicate private-surface exclusion: {relative_path}")
        if guard_path is not None:
            require(
                isinstance(guard_path, str) and (ROOT / guard_path).is_file(),
                f"private-surface exclusion guard is missing: {relative_path}",
            )
        exclusions[relative_path] = reason
    require(markers and roots, "discovery policy is incomplete")
    candidates: set[str] = set()
    for relative_root in roots:
        source_root = ROOT / relative_root
        require(source_root.is_dir(), f"discovery root missing: {relative_root}")
        for source_path in source_root.rglob("*.swift"):
            source_text = source_path.read_text(errors="ignore")
            if any(marker in source_text for marker in markers):
                candidates.add(str(source_path.relative_to(ROOT)))

    unknown = sorted(candidates - registered_paths - exclusions.keys())
    stale_exclusions = sorted(exclusions.keys() - candidates)
    require(not unknown, f"unknownPrivateSurface={len(unknown)}: {unknown}")
    require(not stale_exclusions, f"stale private-surface exclusions: {stale_exclusions}")

    print(
        "Product V4 AccountStoreInventory check passed: "
        f"catalogCategories={len(set(catalog_ids))}, registeredSurfaces={len(surfaces)}, "
        f"registeredSourceFiles={len(registered_paths)}, "
        f"discoveredPrivateSurfaceFiles={len(candidates)}, unknownPrivateSurface=0"
    )


if __name__ == "__main__":
    main()
