#!/usr/bin/env python3
"""Validate deterministic AccountStoreInventory lifecycle-module coverage."""

from __future__ import annotations

from collections import Counter
import json
from pathlib import Path
from typing import Any


ROOT = Path(__file__).resolve().parents[3]
INVENTORY = ROOT / "Scripts/QA/product-v4/account-store-inventory-v1.json"
REGISTRY = ROOT / "Scripts/QA/product-v4/account-lifecycle-module-registry-v1.json"

PHASE_SEQUENCE = [
    "P01_REVOKE_SESSION",
    "P02_INVALIDATE_GENERATION",
    "P03_CANCEL_ASYNC_EFFECTS",
    "P04_STOP_RUNTIME",
    "P05_UNMOUNT_PRIVATE_STORES",
    "P06_CLEAR_DERIVED_OUTPUTS",
    "P07_FINALIZE_RECEIPTS",
]
REQUIRED_MODULE_FIELDS = {
    "moduleId",
    "surfaceIds",
    "phase",
    "switchPolicy",
    "logoutPolicy",
    "deletePolicy",
    "remainingDataPolicy",
    "owner",
    "status",
    "containsExplicitDrafts",
    "localDataPresent",
    "externalDataPresent",
}
REQUIRED_ACTIVE_POLICY_FIELDS = {
    "localDisposition",
    "explicitDraftDisposition",
    "runtimeCacheExportNotificationDisposition",
    "remoteDisposition",
    "receipt",
}
REQUIRED_DELETE_POLICY_FIELDS = {
    "localDisposition",
    "remoteDisposition",
    "receipt",
}
EXPLICIT_DRAFT_SURFACES = {
    "S03::S03.archive-draft-items",
    "S04::S04.archive-media-staging",
    "S05::S05.knowledge-projection-and-outbox",
    "S08::S08.memoir-drafts-and-recordings",
    "S09::S09.legacy-memory-and-map-state",
}
EXTERNAL_ONLY_SURFACES = {
    "S07::S07.remote-delayed-reply-job",
    "S10::S10.remote-voice-profile-artifacts",
    "S12::S12.remote-digital-human-lease",
}
EXTERNAL_AFFECTED_SURFACES = EXTERNAL_ONLY_SURFACES | {
    "S01::S01.backend-auth-session-keychain",
    "S12::S12.tencent-provider-bridge-runtime",
    "S14::S14.private-runtime-log-sinks",
    "S17::S17.push-and-local-notification-registration",
}
OWNER_FREE_RECEIPT_SURFACES = {
    "S14::S14.account-lifecycle-receipts",
}
ALLOWED_SWITCH_LOGOUT_LOCAL = {
    "notApplicable",
    "clearedAndUnmounted",
    "retainedLockedAndUnmounted",
    "retainedBoundedOwnerFreeReceipt",
}
ALLOWED_SWITCH_LOGOUT_REMOTE = {
    "notApplicable",
    "ownerFenced",
    "releasedWithReceipt",
    "revokedWithReceipt",
    "cancelledOrUnregisteredWithReceipt",
    "valueMinimizedWithUnsupportedRetentionReceipt",
}
ALLOWED_DELETE_REMOTE = {
    "notApplicable",
    "deletionReceiptRequired",
    "unsupportedRetentionReceiptRequired",
}
ALLOWED_SWITCH_LOGOUT_REMAINDER = {
    "none",
    "sameOwnerExplicitDraftsRetainedLocked",
    "ownerBoundRemoteAuthority",
    "unsupportedExternalRetentionReceipt",
    "boundedValueMinimizedLifecycleReceipts",
}
ALLOWED_DELETE_REMAINDER = {
    "none",
    "externalDispositionReceiptOnly",
    "unsupportedExternalRetentionReceipt",
    "boundedValueMinimizedLifecycleReceipts",
}


def require(condition: bool, message: str) -> None:
    if not condition:
        raise AssertionError(message)


def load_json(path: Path) -> dict[str, Any]:
    return json.loads(path.read_text(encoding="utf-8"))


def surface_identity(surface: dict[str, Any]) -> str:
    return f"{surface.get('catalogId')}::{surface.get('surfaceId')}"


def require_exact_fields(payload: dict[str, Any], fields: set[str], context: str) -> None:
    missing = sorted(fields - payload.keys())
    require(not missing, f"{context} missing fields: {missing}")


def validate_active_policy(
    policy: dict[str, Any],
    *,
    context: str,
    contains_explicit_drafts: bool,
    local_data_present: bool,
    external_data_present: bool,
    owner_free_receipt_only: bool,
) -> None:
    require_exact_fields(policy, REQUIRED_ACTIVE_POLICY_FIELDS, context)
    require(policy["receipt"] == "required", f"{context} must require a receipt")
    require(
        policy["localDisposition"] in ALLOWED_SWITCH_LOGOUT_LOCAL,
        f"{context} invalid local disposition: {policy['localDisposition']}",
    )
    require(
        "purged" not in policy["localDisposition"].lower(),
        f"{context} must not purge data during switch/logout",
    )
    if owner_free_receipt_only:
        require(
            policy["localDisposition"] == "retainedBoundedOwnerFreeReceipt",
            f"{context} must retain only the bounded owner-free receipt",
        )
    elif local_data_present:
        require(
            policy["localDisposition"] != "notApplicable",
            f"{context} must define local cleanup/unmount behavior",
        )
    else:
        require(
            policy["localDisposition"] == "notApplicable",
            f"{context} cannot claim local data behavior",
        )

    expected_draft_disposition = "retainedLocked" if contains_explicit_drafts else "notApplicable"
    require(
        policy["explicitDraftDisposition"] == expected_draft_disposition,
        f"{context} explicit draft policy must be {expected_draft_disposition}",
    )
    if contains_explicit_drafts:
        require(
            policy["localDisposition"] == "retainedLockedAndUnmounted",
            f"{context} must retain and unmount same-owner explicit drafts",
        )

    require(
        policy["runtimeCacheExportNotificationDisposition"] in {"cleared", "notApplicable"},
        f"{context} runtime/cache/export/notification policy is invalid",
    )
    if owner_free_receipt_only:
        require(
            policy["runtimeCacheExportNotificationDisposition"] == "notApplicable",
            f"{context} owner-free receipt is not runtime/cache/export/notification state",
        )
    elif local_data_present:
        require(
            policy["runtimeCacheExportNotificationDisposition"] == "cleared",
            f"{context} must clear runtime/cache/export/notification state",
        )
    require(
        policy["remoteDisposition"] in ALLOWED_SWITCH_LOGOUT_REMOTE,
        f"{context} invalid remote disposition: {policy['remoteDisposition']}",
    )
    if external_data_present:
        require(
            policy["remoteDisposition"] != "notApplicable",
            f"{context} must explicitly fence/release external data",
        )
    else:
        require(
            policy["remoteDisposition"] == "notApplicable",
            f"{context} cannot claim an external-data action",
        )


def validate_delete_policy(
    policy: dict[str, Any],
    *,
    context: str,
    local_data_present: bool,
    external_data_present: bool,
    owner_free_receipt_only: bool,
) -> None:
    require_exact_fields(policy, REQUIRED_DELETE_POLICY_FIELDS, context)
    require(policy["receipt"] == "required", f"{context} must require a receipt")
    if owner_free_receipt_only:
        expected_local = "retainedBoundedOwnerFreeReceipt"
    else:
        expected_local = "purged" if local_data_present else "notApplicable"
    require(
        policy["localDisposition"] == expected_local,
        f"{context} local account data must be {expected_local}",
    )
    require(
        policy["remoteDisposition"] in ALLOWED_DELETE_REMOTE,
        f"{context} invalid remote disposition: {policy['remoteDisposition']}",
    )
    if external_data_present:
        require(
            policy["remoteDisposition"]
            in {"deletionReceiptRequired", "unsupportedRetentionReceiptRequired"},
            f"{context} external data must produce deletion/unsupported receipt",
        )
    else:
        require(
            policy["remoteDisposition"] == "notApplicable",
            f"{context} cannot claim an external-data action",
        )


def validate_remaining_data_policy(
    policy: dict[str, Any],
    *,
    context: str,
    contains_explicit_drafts: bool,
    delete_remote_disposition: str,
    owner_free_receipt_only: bool,
) -> None:
    expected_fields = {"afterSwitch", "afterLogout", "afterAccountDeletion"}
    require_exact_fields(policy, expected_fields, context)
    for lifecycle in ("afterSwitch", "afterLogout"):
        values = policy[lifecycle]
        require(isinstance(values, list) and values, f"{context}.{lifecycle} must be non-empty")
        require(
            len(values) == len(set(values)),
            f"{context}.{lifecycle} contains duplicate outcomes",
        )
        require(
            set(values) <= ALLOWED_SWITCH_LOGOUT_REMAINDER,
            f"{context}.{lifecycle} contains unsupported outcomes: {values}",
        )
        if contains_explicit_drafts:
            require(
                "sameOwnerExplicitDraftsRetainedLocked" in values,
                f"{context}.{lifecycle} must disclose retained locked drafts",
            )
        if owner_free_receipt_only:
            require(
                values == ["boundedValueMinimizedLifecycleReceipts"],
                f"{context}.{lifecycle} must disclose only bounded owner-free receipts",
            )

    delete_values = policy["afterAccountDeletion"]
    require(
        isinstance(delete_values, list) and delete_values,
        f"{context}.afterAccountDeletion must be non-empty",
    )
    require(
        set(delete_values) <= ALLOWED_DELETE_REMAINDER,
        f"{context}.afterAccountDeletion contains unsupported outcomes: {delete_values}",
    )
    require(
        not ({"sameOwnerExplicitDraftsRetainedLocked", "ownerBoundRemoteAuthority"} & set(delete_values)),
        f"{context}.afterAccountDeletion must not silently retain user data",
    )
    if owner_free_receipt_only:
        require(
            delete_values == ["boundedValueMinimizedLifecycleReceipts"],
            f"{context} must explicitly retain only bounded owner-free receipts",
        )
    elif delete_remote_disposition == "deletionReceiptRequired":
        require(
            "externalDispositionReceiptOnly" in delete_values,
            f"{context} must disclose external deletion receipt",
        )
    elif delete_remote_disposition == "unsupportedRetentionReceiptRequired":
        require(
            "unsupportedExternalRetentionReceipt" in delete_values,
            f"{context} must disclose unsupported external retention",
        )
    else:
        require(
            delete_values == ["none"],
            f"{context} must not report remaining data without an external obligation",
        )


def main() -> None:
    inventory = load_json(INVENTORY)
    registry = load_json(REGISTRY)

    require(
        inventory.get("schemaVersion") == "dreamjourney.account-store-inventory.v1",
        "account store inventory schema drift",
    )
    require(
        registry.get("schemaVersion") == "dreamjourney.account-lifecycle-module-registry.v1",
        "account lifecycle module registry schema drift",
    )
    require(registry.get("authority") == "WI-S0-01-08A", "registry authority drift")
    require(
        registry.get("inventorySource") == str(INVENTORY.relative_to(ROOT)),
        "registry inventory source drift",
    )
    require(
        registry.get("surfaceIdentityFormat") == "<catalogId>::<surfaceId>",
        "registry must use composite inventory identity",
    )
    require(registry.get("phaseSequence") == PHASE_SEQUENCE, "lifecycle phase sequence drift")

    invariants = registry.get("invariants") or {}
    require(invariants.get("surfaceMappingCardinality") == "exactlyOne", "mapping cardinality drift")
    require(
        invariants.get("switchExplicitDrafts") == "retainedLockedAndUnmounted",
        "switch draft invariant drift",
    )
    require(
        invariants.get("logoutExplicitDrafts") == "retainedLockedAndUnmounted",
        "logout draft invariant drift",
    )
    require(
        invariants.get("accountDeletionLocalUserData") == "purged",
        "account deletion local-data invariant drift",
    )
    require(
        invariants.get("accountDeletionExternalData") == "receiptRequired",
        "account deletion external-data invariant drift",
    )
    require(
        invariants.get("nextAccountMountBarrier") == "allModulesTerminal",
        "next-account mount barrier drift",
    )

    inventory_surfaces = inventory.get("surfaces") or []
    require(inventory_surfaces, "account store inventory is empty")
    inventory_identities = [surface_identity(surface) for surface in inventory_surfaces]
    require(
        len(inventory_identities) == len(set(inventory_identities)),
        "duplicate catalogId::surfaceId identity in inventory",
    )
    inventory_set = set(inventory_identities)

    modules = registry.get("modules") or []
    require(modules, "account lifecycle module registry is empty")
    module_ids = [module.get("moduleId") for module in modules]
    require(len(module_ids) == len(set(module_ids)), "duplicate moduleId")
    phase_indexes = {phase: index for index, phase in enumerate(PHASE_SEQUENCE)}
    observed_phase_indexes: list[int] = []
    mapping_counts: Counter[str] = Counter()

    for module in modules:
        module_id = module.get("moduleId", "<missing-module-id>")
        require_exact_fields(module, REQUIRED_MODULE_FIELDS, module_id)
        require(isinstance(module_id, str) and module_id.startswith("LM-"), f"invalid moduleId: {module_id}")
        require(module["status"] == "MAPPED", f"{module_id} status must be MAPPED")
        require(isinstance(module["owner"], str) and module["owner"].strip(), f"{module_id} owner missing")
        require(module["phase"] in phase_indexes, f"{module_id} has unknown phase")
        observed_phase_indexes.append(phase_indexes[module["phase"]])

        surface_ids = module["surfaceIds"]
        require(isinstance(surface_ids, list) and surface_ids, f"{module_id} surfaceIds must be non-empty")
        require(len(surface_ids) == len(set(surface_ids)), f"{module_id} repeats a surface identity")
        require(
            all(isinstance(identity, str) and "::" in identity for identity in surface_ids),
            f"{module_id} must use catalogId::surfaceId identities",
        )
        mapping_counts.update(surface_ids)

        surface_set = set(surface_ids)
        expected_drafts = bool(surface_set & EXPLICIT_DRAFT_SURFACES)
        expected_local = bool(surface_set - EXTERNAL_ONLY_SURFACES)
        expected_external = bool(surface_set & EXTERNAL_AFFECTED_SURFACES)
        owner_free_receipt_only = bool(surface_set) and surface_set <= OWNER_FREE_RECEIPT_SURFACES
        require(
            not (surface_set & OWNER_FREE_RECEIPT_SURFACES) or owner_free_receipt_only,
            f"{module_id} must not mix owner-free lifecycle receipts with account data",
        )
        require(
            module["containsExplicitDrafts"] is expected_drafts,
            f"{module_id} explicit-draft classification drift",
        )
        require(module["localDataPresent"] is expected_local, f"{module_id} local-data classification drift")
        require(
            module["externalDataPresent"] is expected_external,
            f"{module_id} external-data classification drift",
        )

        for lifecycle_name in ("switchPolicy", "logoutPolicy"):
            validate_active_policy(
                module[lifecycle_name],
                context=f"{module_id}.{lifecycle_name}",
                contains_explicit_drafts=expected_drafts,
                local_data_present=expected_local,
                external_data_present=expected_external,
                owner_free_receipt_only=owner_free_receipt_only,
            )
        validate_delete_policy(
            module["deletePolicy"],
            context=f"{module_id}.deletePolicy",
            local_data_present=expected_local,
            external_data_present=expected_external,
            owner_free_receipt_only=owner_free_receipt_only,
        )
        validate_remaining_data_policy(
            module["remainingDataPolicy"],
            context=f"{module_id}.remainingDataPolicy",
            contains_explicit_drafts=expected_drafts,
            delete_remote_disposition=module["deletePolicy"]["remoteDisposition"],
            owner_free_receipt_only=owner_free_receipt_only,
        )

    require(
        observed_phase_indexes == sorted(observed_phase_indexes),
        "modules must be ordered by fixed lifecycle phase sequence",
    )
    mapped_set = set(mapping_counts)
    gaps = sorted(inventory_set - mapped_set)
    unknown = sorted(mapped_set - inventory_set)
    duplicates = sorted(identity for identity, count in mapping_counts.items() if count != 1)
    require(not gaps, f"inventory lifecycle mapping gaps={len(gaps)}: {gaps}")
    require(not unknown, f"unknown inventory surfaces={len(unknown)}: {unknown}")
    require(not duplicates, f"surface identities not mapped exactly once={len(duplicates)}: {duplicates}")

    print(
        "Product V4 account lifecycle module registry check passed: "
        f"inventorySurfaces={len(inventory_set)}, mappedSurfaces={len(mapped_set)}, "
        f"modules={len(modules)}, phases={len(set(module['phase'] for module in modules))}, "
        "gaps=0 duplicateMappings=0 unknownMappings=0"
    )


if __name__ == "__main__":
    main()
