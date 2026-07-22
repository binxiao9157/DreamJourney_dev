#!/usr/bin/env python3
"""Validate the derived V4 execution handoff without promoting Registry state."""

from __future__ import annotations

import hashlib
import json
from pathlib import Path


ROOT = Path(__file__).resolve().parents[3]
HANDOFF = ROOT / "docs/superpowers/status/2026-07-17-v4-current-execution-handoff.json"
REGISTRY = ROOT / "docs/product/DreamJourney_V4_路线执行注册表_V1.0.json"
ROADMAP = ROOT / "docs/superpowers/plans/2026-07-12-dreamjourney-v4-executable-development-roadmap.md"
BACKEND = ROOT.parent / "DreamJourneyBackend"

FORBIDDEN_KEYS = {
    "accessToken",
    "apiKey",
    "password",
    "rawValue",
    "secret",
    "secretKey",
    "token",
    "value",
}


def require(condition: bool, message: str) -> None:
    if not condition:
        raise AssertionError(message)


def visit_keys(value: object, path: str = "$") -> None:
    if isinstance(value, dict):
        for key, child in value.items():
            require(key not in FORBIDDEN_KEYS, f"forbidden sensitive field at {path}.{key}")
            visit_keys(child, f"{path}.{key}")
    elif isinstance(value, list):
        for index, child in enumerate(value):
            visit_keys(child, f"{path}[{index}]")


def main() -> None:
    handoff = json.loads(HANDOFF.read_text(encoding="utf-8"))
    registry = json.loads(REGISTRY.read_text(encoding="utf-8"))
    visit_keys(handoff)

    require(
        handoff.get("schemaVersion") == "dreamjourney.current-execution-handoff.v1",
        "handoff schema mismatch",
    )
    require((ROOT / handoff["plan"]).is_file(), "active plan is missing")
    require((ROOT / handoff["registry"]["path"]).resolve() == REGISTRY.resolve(), "registry path drift")
    require(
        handoff["registry"]["contract"]
        == "CONSERVATIVE_PLANNING_VIEW_DOES_NOT_SELF_CLAIM_IMPLEMENTATION",
        "registry contract must remain conservative",
    )

    roadmap_hash = hashlib.sha256(ROADMAP.read_bytes()).hexdigest()
    require(
        roadmap_hash == handoff["registry"]["sourceRoadmapSha256"],
        "handoff roadmap hash is stale",
    )
    require(registry["source"]["sha256"] == roadmap_hash, "registry source hash drift")
    require(
        all(item["lifecycle"] == "PLANNED" for item in registry["workItems"]),
        "generated Registry must not self-promote implementation",
    )

    registry_items = {item["id"]: item for item in registry["workItems"]}
    registry_ids = set(registry_items)
    evidence_items = handoff["evidenceItems"]
    evidence_ids = [item["id"] for item in evidence_items]
    require(len(evidence_ids) == len(set(evidence_ids)), "handoff evidence IDs must be unique")
    require(len(evidence_ids) >= 22, "handoff must preserve the accepted evidence baseline")
    require(set(evidence_ids) <= registry_ids, "handoff references unknown Work Item")
    for item in evidence_items:
        evidence = ROOT / item["evidence"]
        require(evidence.is_file(), f"missing evidence: {item['evidence']}")
        require(item["id"] in evidence.read_text(encoding="utf-8"), f"evidence ID mismatch: {item['id']}")

    active = handoff["activeWorkItem"]
    require(active["state"] == "IN_PROGRESS", "active Work Item must be IN_PROGRESS")
    require(active["id"] in registry_ids, "active Work Item missing from Registry")
    if active["id"] in evidence_ids:
        require(
            bool(active.get("currentSubSlice")),
            "an evidence-backed active Work Item must identify its current sub-slice",
        )
    require(
        active["authorityLock"] == registry_items[active["id"]]["authorityLock"],
        "active Authority lock drift",
    )
    for relative in active["backendPendingPaths"]:
        require((BACKEND / relative).is_file(), f"backend pending path missing: {relative}")

    next_item = handoff["nextWorkItem"]
    require(next_item["id"] in registry_ids, "next Work Item missing from Registry")
    if next_item["state"] == "RECONCILE_AFTER_CURRENT":
        require(
            next_item["id"] == active["id"],
            "a reconciliation step must stay within the active Work Item",
        )
        require(
            next_item["id"] in evidence_ids,
            "a reconciliation step requires an evidence-backed active Work Item",
        )
    else:
        require(next_item["id"] not in evidence_ids, "next Work Item already listed as evidence-complete")
        require(next_item["state"] == "PLANNED_AFTER_CURRENT", "next Work Item state drift")

    print(
        "Product V4 current handoff check passed: "
        f"evidence_items={len(evidence_items)} active={active['id']} next={next_item['id']}"
    )


if __name__ == "__main__":
    main()
