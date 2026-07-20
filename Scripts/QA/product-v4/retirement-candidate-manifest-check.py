#!/usr/bin/env python3
"""Keep the WI-S1-02-10 G0 retirement candidate manifest conservative.

The manifest is a cross-repository planning artifact. It intentionally reads
only checked-in source inventories; it neither observes a host nor changes any
timer, scheduler, notification, route, credential, or Provider boundary.
"""

from __future__ import annotations

import json
from pathlib import Path
from typing import Any, Mapping


ROOT = Path(__file__).resolve().parents[3]
BACKEND = ROOT.parent / "DreamJourneyBackend"
MANIFEST = ROOT / "docs/superpowers/status/2026-07-20-wi-s1-02-10-retirement-candidate-manifest-v1.json"

INVENTORY_SPECS = {
    "ios": {
        "path": ROOT / "Scripts/QA/product-v4/legacy-timer-callback-inventory-v1.json",
        "schema": "dreamjourney.ios-legacy-timer-callback-inventory.v1",
    },
    "backend": {
        "path": BACKEND / "docs/backend/legacy-timer-callback-inventory-v1.json",
        "schema": "dreamjourney.legacy-timer-callback-inventory.v1",
    },
}

FORBIDDEN_VALUE_KEYS = {
    "accessToken",
    "apiKey",
    "authorization",
    "body",
    "content",
    "credential",
    "headers",
    "payload",
    "rawValue",
    "secret",
    "secretKey",
    "token",
}
FORBIDDEN_G0_WINDOW_KEYS = {
    "approvedWindowHours",
    "durationHours",
    "observationWindowHours",
    "requiredObservationWindowHours",
    "windowHours",
}
REQUIRED_ENTRY_FIELDS = {
    "id",
    "repository",
    "inventoryRef",
    "surfaceType",
    "pathOrResource",
    "owner",
    "introducedBy",
    "version",
    "stableKeyPolicy",
    "shadowParity",
    "candidateDisposition",
    "successorAuthority",
    "status",
    "retirementDecision",
    "drainCheckpoint",
    "zeroUseWindow",
    "runtimeEvidence",
    "revoke",
    "approvers",
    "evidenceIds",
    "dependencyScan",
    "removal",
    "recoveryBoundary",
}

EXPECTED_DISPOSITIONS = {
    "ios.echo-delayed-reply-local-notification": "CANDIDATE_BLOCKED",
    "ios.time-letter-local-notification": "CANDIDATE_BLOCKED",
    "ios.voice-clone-training-poll": "CANDIDATE_BLOCKED",
    "ios.digital-human-session-heartbeat": "RETAIN_CURRENT_RUNTIME_NOT_CANDIDATE",
    "ios.dialog-engine-silence-timeout": "RETAIN_CURRENT_RUNTIME_NOT_CANDIDATE",
    "ios.digital-human-audio-level-meter": "EXCLUDED_PURE_UI_OR_PLAYBACK",
    "ios.memoir-audio-progress": "EXCLUDED_PURE_UI_OR_PLAYBACK",
    "ios.archive-audio-recording-duration": "EXCLUDED_PURE_UI_OR_PLAYBACK",
    "ios.footprint-banner-dismiss": "EXCLUDED_PURE_UI_OR_PLAYBACK",
    "backend.api-startup-store-lifecycle": "PROCESS_LIFECYCLE_NOT_CANDIDATE",
    "backend.time-letter-api-direct-dispatch": "CANDIDATE_BLOCKED",
    "backend.time-letter-cli-direct-dispatch": "CANDIDATE_BLOCKED",
    "backend.time-letter-host-scheduler-documentation": "CANDIDATE_BLOCKED",
    "backend.async-effect-scheduler-shadow": "FOUNDATION_NOT_CANDIDATE",
    "backend.digital-human-session-heartbeat-route": "RETAIN_CURRENT_RUNTIME_NOT_CANDIDATE",
    "backend.provider-effect-external-callback-boundary": "EXTERNAL_BOUNDARY_NOT_CANDIDATE",
    "backend.operations-db-backup-timer": "OPERATIONS_MAINTENANCE_NOT_CANDIDATE",
    "backend.operations-db-backup-retention-audit-timer": "OPERATIONS_MAINTENANCE_NOT_CANDIDATE",
    "backend.operations-evidence-manifest-retention-timer": "OPERATIONS_MAINTENANCE_NOT_CANDIDATE",
}
CANDIDATE_BLOCKED_IDS = {
    surface_id
    for surface_id, disposition in EXPECTED_DISPOSITIONS.items()
    if disposition == "CANDIDATE_BLOCKED"
}
PURE_UI_IDS = {
    surface_id
    for surface_id, disposition in EXPECTED_DISPOSITIONS.items()
    if disposition == "EXCLUDED_PURE_UI_OR_PLAYBACK"
}
EXPECTED_REOPEN_TRIGGERS = {
    "runtime-hit",
    "new-old-client",
    "in-flight-not-terminal",
    "unknown-in-flight",
    "restore-or-replay-failure",
    "approval-invalidated",
}
EXPECTED_G0_PROHIBITIONS = {
    "no-runtime-observation",
    "no-retirement-approval",
    "no-timer-or-worker-state-change",
    "no-route-or-script-removal",
    "no-provider-query-or-callback-enable",
    "no-credential-revoke",
}


def require(condition: bool, message: str) -> None:
    if not condition:
        raise AssertionError(message)


def non_empty_text(value: object) -> bool:
    return isinstance(value, str) and bool(value.strip())


def assert_value_free(value: object, path: str = "$") -> None:
    if isinstance(value, Mapping):
        for key, child in value.items():
            require(isinstance(key, str), f"manifest key must be text at {path}")
            require(key not in FORBIDDEN_VALUE_KEYS, f"forbidden value field at {path}.{key}")
            require(key not in FORBIDDEN_G0_WINDOW_KEYS, f"unapproved fixed observation window at {path}.{key}")
            assert_value_free(child, f"{path}.{key}")
    elif isinstance(value, list):
        for index, child in enumerate(value):
            assert_value_free(child, f"{path}[{index}]")


def load_json(path: Path) -> Mapping[str, Any]:
    require(path.is_file(), f"missing required artifact: {path}")
    loaded = json.loads(path.read_text(encoding="utf-8"))
    require(isinstance(loaded, Mapping), f"artifact root must be an object: {path}")
    return loaded


def inventory_entries() -> dict[tuple[str, str], Mapping[str, Any]]:
    entries: dict[tuple[str, str], Mapping[str, Any]] = {}
    for repository, spec in INVENTORY_SPECS.items():
        inventory = load_json(spec["path"])
        require(
            inventory.get("schemaVersion") == spec["schema"],
            f"{repository} inventory schema drifted",
        )
        source_entries = inventory.get("entries")
        require(isinstance(source_entries, list) and source_entries, f"{repository} inventory entries missing")
        for entry in source_entries:
            require(isinstance(entry, Mapping), f"{repository} inventory entry must be an object")
            entry_id = entry.get("id")
            require(non_empty_text(entry_id), f"{repository} inventory entry id missing")
            key = (repository, str(entry_id))
            require(key not in entries, f"duplicate source inventory entry: {key}")
            entries[key] = entry
    return entries


def source_paths(entry: Mapping[str, Any]) -> list[str]:
    sources = entry.get("sources")
    require(isinstance(sources, list) and sources, "source inventory entry sources missing")
    paths: list[str] = []
    for source in sources:
        require(isinstance(source, Mapping) and non_empty_text(source.get("path")), "inventory source path missing")
        paths.append(str(source["path"]))
    return paths


def main() -> None:
    manifest = load_json(MANIFEST)
    assert_value_free(manifest)
    require(
        manifest.get("schemaVersion") == "dreamjourney.async-effect-retirement-candidate-manifest.v1",
        "retirement candidate manifest schema mismatch",
    )
    require(manifest.get("workItem") == "WI-S1-02-10", "manifest work item mismatch")
    require(manifest.get("authorityLock") == "ASYNC_EFFECT", "manifest authority mismatch")
    require(
        manifest.get("status") == "CANDIDATES_RECORDED_NOT_AUTHORIZED",
        "G0 manifest must remain recorded but not authorized",
    )
    require(set(manifest.get("g0Prohibitions", [])) == EXPECTED_G0_PROHIBITIONS, "G0 prohibitions drifted")
    require(set(manifest.get("reopenTriggers", [])) == EXPECTED_REOPEN_TRIGGERS, "reopen triggers drifted")

    inventories = manifest.get("sourceInventories")
    require(isinstance(inventories, list) and len(inventories) == len(INVENTORY_SPECS), "source inventories drifted")
    inventory_metadata = {item.get("repository"): item for item in inventories if isinstance(item, Mapping)}
    require(set(inventory_metadata) == set(INVENTORY_SPECS), "source inventory repositories drifted")
    for repository, spec in INVENTORY_SPECS.items():
        item = inventory_metadata[repository]
        expected_path = spec["path"].relative_to(ROOT if repository == "ios" else BACKEND).as_posix()
        require(item.get("path") == expected_path, f"{repository} source inventory path drifted")
        require(item.get("schemaVersion") == spec["schema"], f"{repository} source inventory schema drifted")

    source_entries = inventory_entries()
    entries = manifest.get("entries")
    require(isinstance(entries, list) and entries, "manifest entries are required")
    by_id = {entry.get("id"): entry for entry in entries if isinstance(entry, Mapping)}
    require(len(by_id) == len(entries), "manifest contains duplicate or invalid surface ids")
    require(set(by_id) == set(EXPECTED_DISPOSITIONS), "manifest surface set drifted from inventories")
    require(len(source_entries) == len(by_id), "every source inventory entry must map to one manifest entry")

    for surface_id, entry in by_id.items():
        require(isinstance(surface_id, str), "manifest surface id must be text")
        missing = REQUIRED_ENTRY_FIELDS - set(entry)
        require(not missing, f"{surface_id} missing required fields: {sorted(missing)}")
        repository = entry["repository"]
        inventory_ref = entry["inventoryRef"]
        require(repository in INVENTORY_SPECS, f"{surface_id} repository is unsupported")
        require(non_empty_text(inventory_ref), f"{surface_id} inventoryRef missing")
        require(surface_id == f"{repository}.{inventory_ref}", f"{surface_id} must be repository-prefixed inventory ref")
        source_entry = source_entries.get((repository, str(inventory_ref)))
        require(source_entry is not None, f"{surface_id} does not resolve to source inventory")
        paths = entry["pathOrResource"]
        require(isinstance(paths, list) and paths, f"{surface_id}.pathOrResource must be non-empty")
        require(all(non_empty_text(path) and not str(path).startswith("/") for path in paths), f"{surface_id} paths must be relative")
        require(paths == source_paths(source_entry), f"{surface_id} path/resource drifted from source inventory")
        for field in (
            "surfaceType",
            "owner",
            "introducedBy",
            "version",
            "stableKeyPolicy",
            "shadowParity",
            "candidateDisposition",
            "successorAuthority",
            "status",
            "retirementDecision",
            "revoke",
            "dependencyScan",
            "recoveryBoundary",
        ):
            require(non_empty_text(entry[field]), f"{surface_id}.{field} must be non-empty text")
        require(entry["surfaceType"] == source_entry.get("surface"), f"{surface_id} surface type drifted")
        require(entry["candidateDisposition"] == EXPECTED_DISPOSITIONS[surface_id], f"{surface_id} disposition drifted")
        require(entry["status"] == "discovered", f"{surface_id} cannot leave G0 discovered state")
        require(entry["retirementDecision"] == "not_authorized", f"{surface_id} cannot self-authorize retirement")
        require(isinstance(entry["approvers"], list) and entry["approvers"], f"{surface_id}.approvers required")
        require(isinstance(entry["evidenceIds"], list) and entry["evidenceIds"], f"{surface_id}.evidenceIds required")

        drain = entry["drainCheckpoint"]
        zero_use = entry["zeroUseWindow"]
        runtime = entry["runtimeEvidence"]
        removal = entry["removal"]
        require(isinstance(drain, Mapping) and isinstance(drain.get("requirements"), list) and drain["requirements"], f"{surface_id}.drainCheckpoint incomplete")
        require(isinstance(zero_use, Mapping), f"{surface_id}.zeroUseWindow must be an object")
        require(zero_use.get("approvedWindow") == "not-set", f"{surface_id} cannot invent an observation duration")
        require(isinstance(runtime, Mapping), f"{surface_id}.runtimeEvidence must be an object")
        require(set(runtime) == {"lastObservedAt", "useCount", "inFlight", "oldClient", "restoreReplay"}, f"{surface_id} runtime evidence fields drifted")
        require(isinstance(removal, Mapping), f"{surface_id}.removal must be an object")
        require(removal.get("removalCommit") == "not-assigned", f"{surface_id} cannot have a removal commit in G0")
        require(removal.get("deployId") == "not-assigned", f"{surface_id} cannot have a removal deploy in G0")
        require(removal.get("postMonitorWindow") == "not-set", f"{surface_id} cannot invent a post-monitor window")

        if surface_id in CANDIDATE_BLOCKED_IDS:
            require(zero_use.get("state") == "not_observed", f"{surface_id} must keep zero-use unobserved")
            require(str(runtime.get("useCount", "")).startswith("unknown"), f"{surface_id} cannot claim zero use")
            require(not entry["successorAuthority"].startswith("not-applicable"), f"{surface_id} candidate needs a successor authority")
        elif surface_id in PURE_UI_IDS:
            require(zero_use.get("state") == "not-applicable", f"{surface_id} pure UI exclusion drifted")
            require(runtime.get("useCount") == "not-applicable", f"{surface_id} pure UI runtime proof drifted")
        else:
            require(zero_use.get("state") != "zero_use_observed", f"{surface_id} cannot claim zero-use at G0")

    print(
        "WI-S1-02-10 retirement candidate manifest check passed: "
        f"surfaces={len(by_id)} candidateBlocked={len(CANDIDATE_BLOCKED_IDS)} "
        f"pureUIExcluded={len(PURE_UI_IDS)} status=not-authorized"
    )


if __name__ == "__main__":
    main()
